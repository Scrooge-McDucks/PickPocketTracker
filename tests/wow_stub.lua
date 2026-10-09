-------------------------------------------------------------------------------
-- wow_stub.lua — a fake World of Warcraft client, good enough to run the addon
--
-- The real game is not available in CI, so this file installs stand-ins for
-- every global the addon touches (C_Container, C_Timer, C_Item, C_CurrencyInfo,
-- CreateFrame, GetMoney, GetTime, ...) and exposes a handle, H, that tests use
-- to drive the world: move the clock, change the player's money, put items in
-- bags, open and close the vendor, and step timers forward.
--
-- Nothing here reaches the network, the filesystem (beyond reading the addon's
-- own .lua files), or a real game client. A "sell" is a table entry being
-- removed from a fake bag; a "tick" is a direct function call.
--
-- Usage from a test file:
--     local H  = dofile(TESTS_DIR .. "/wow_stub.lua")
--     local NS = H.newEnv({ "config.lua", "utils.lua", "data.lua" })
--     H.check("something", cond)
--     H.report()
--
-- ADDON_DIR and TESTS_DIR are injected by run_tests.py.
-------------------------------------------------------------------------------

local H = {}

H.out = print   -- keep the real print before the addon's chat output hijacks it

-- Lua 5.1/LuaJIT expose a global `unpack`; 5.2+ moved it to `table.unpack`.
-- The bundled interpreter depends on which lupa wheel is installed, so accept
-- either and hand the addon the global it expects (WoW's Lua 5.1 has one).
local tunpack = table.unpack or unpack
H.unpack = tunpack

-------------------------------------------------------------------------------
-- Assertions
-------------------------------------------------------------------------------

H.passed, H.failed = 0, 0

function H.section(name)
  H.out("\n  " .. name)
end

function H.check(name, cond, extra)
  if cond then
    H.passed = H.passed + 1
    H.out("    PASS  " .. name)
  else
    H.failed = H.failed + 1
    H.out("    FAIL  " .. name .. (extra ~= nil and ("  [" .. tostring(extra) .. "]") or ""))
  end
end

--- Equality assertion that prints both sides on failure.
function H.eq(name, got, want)
  H.check(name, got == want, "got " .. tostring(got) .. ", want " .. tostring(want))
end

function H.report()
  H.out(string.format("\n  %d passed, %d failed", H.passed, H.failed))
  TEST_FAILURES = (TEST_FAILURES or 0) + H.failed
end

-------------------------------------------------------------------------------
-- Mutable world state (tests poke these directly)
-------------------------------------------------------------------------------

H.SLOTS_PER_BAG = 4

function H.resetWorld()
  H.now        = 1000.0          -- GetTime()
  H.money      = 0               -- GetMoney(), in copper
  H.currency   = {}              -- [currencyID] = quantity
  H.bags       = { [0]={}, [1]={}, [2]={}, [3]={}, [4]={} }
  H.itemDB     = {}              -- [itemID] = { name=, texture=, price= }
  H.chat       = {}              -- captured addon chat output
  H.tickers    = {}              -- C_Timer.NewTicker handles
  H.afters     = {}              -- pending C_Timer.After callbacks
  H.frames     = {}              -- every CreateFrame result
  H.tooltip    = {}              -- GameTooltip lines
  H.categories = {}              -- Settings.RegisterAddOnCategory calls
  H.useCalls            = 0
  H.sellBlocked         = false
  H.usedOutsideMerchant = false
  H.merchantOpen        = true
  H.realm       = "TestRealm"
  H.playerName  = "Sneaky"
  H.className   = "Rogue"
  H.classToken  = "ROGUE"
  H.inCombat    = false
  H.tocVersion  = 120105         -- GetBuildInfo() interface; read when config.lua loads
  H.autoRunAfters = true         -- run C_Timer.After callbacks immediately
end

H.resetWorld()

-------------------------------------------------------------------------------
-- Bag helpers
-------------------------------------------------------------------------------

--- Register an item in the fake item cache so C_Item.GetItemInfo knows it.
function H.defineItem(itemID, name, price, texture)
  H.itemDB[itemID] = { name = name, price = price, texture = texture or "icon" }
end

--- Place a stack in a bag slot.
function H.put(bag, slot, itemID, stackCount)
  H.bags[bag][slot] = { itemID = itemID, stackCount = stackCount or 1 }
end

function H.slot(bag, slot)
  return H.bags[bag][slot]
end

function H.bagTotal(itemID)
  local n = 0
  for bag = 0, NUM_BAG_SLOTS do
    for s = 1, H.SLOTS_PER_BAG do
      local e = H.bags[bag][s]
      if e and e.itemID == itemID then n = n + e.stackCount end
    end
  end
  return n
end

-------------------------------------------------------------------------------
-- Clock / timers
-------------------------------------------------------------------------------

function H.advance(seconds)
  H.now = H.now + seconds
end

--- Run every live ticker n times, in registration order.
function H.tick(n)
  for _ = 1, (n or 1) do
    for _, t in ipairs(H.tickers) do
      if not t.cancelled then t.fn() end
    end
  end
end

function H.liveTickers()
  local c = 0
  for _, t in ipairs(H.tickers) do
    if not t.cancelled then c = c + 1 end
  end
  return c
end

--- Drain queued C_Timer.After callbacks (used when autoRunAfters is false).
function H.runAfters(rounds)
  for _ = 1, (rounds or 1) do
    local queue = H.afters
    H.afters = {}
    for _, fn in ipairs(queue) do fn() end
  end
end

-------------------------------------------------------------------------------
-- Chat capture
-------------------------------------------------------------------------------

--- True if any captured chat line contains `needle` (plain substring).
function H.chatHas(needle)
  for _, line in ipairs(H.chat) do
    if line:find(needle, 1, true) then return true end
  end
  return false
end

function H.chatCount()
  return #H.chat
end

-------------------------------------------------------------------------------
-- Frame mock
-------------------------------------------------------------------------------

-- A do-nothing object that tolerates any use: call it, index it, chain it.
-- Stands in for unmodelled frame methods and template-supplied child widgets.
local chainMeta
chainMeta = {
  __call  = function(self) return self end,
  __index = function() return setmetatable({}, chainMeta) end,
}
function H.chainStub()
  return setmetatable({}, chainMeta)
end

-- Methods we model with real return values; everything else PascalCase becomes
-- a chainable no-op. Lowercase keys stay nil so addon code that probes its own
-- fields (`if frame.text then`) still behaves correctly.
local function mockFrame(frameType, name, parent, template)
  local f = {
    __type = frameType or "Frame", __name = name, __parent = parent,
    __template = template, __shown = true, __w = 120, __h = 24,
    __scripts = {}, __points = {}, __children = {}, __regions = {},
    __events = {}, __text = nil, __value = 0, __checked = false,
  }

  function f:SetScript(e, fn) self.__scripts[e] = fn end
  function f:GetScript(e) return self.__scripts[e] end
  function f:HookScript(e, fn)
    local prev = self.__scripts[e]
    self.__scripts[e] = function(...)
      if prev then prev(...) end
      fn(...)
    end
  end
  --- Test helper: invoke a registered script handler.
  function f:Fire(e, ...)
    local fn = self.__scripts[e]
    if fn then return fn(self, ...) end
  end

  function f:RegisterEvent(ev) self.__events[ev] = true end
  function f:UnregisterEvent(ev) self.__events[ev] = nil end
  function f:UnregisterAllEvents() self.__events = {} end
  function f:IsEventRegistered(ev) return self.__events[ev] == true end

  function f:Show() self.__shown = true end
  function f:Hide() self.__shown = false end
  function f:SetShown(v) self.__shown = v and true or false end
  function f:IsShown() return self.__shown end
  function f:IsVisible() return self.__shown end

  function f:SetWidth(w) self.__w = w end
  function f:SetHeight(h) self.__h = h end
  function f:GetWidth() return self.__w end
  function f:GetHeight() return self.__h end
  function f:SetSize(w, h) self.__w, self.__h = w, h end
  function f:GetSize() return self.__w, self.__h end

  function f:SetPoint(p, rel, rp, x, y)
    self.__points[#self.__points + 1] = { p, rel, rp, x, y }
  end
  function f:ClearAllPoints() self.__points = {} end
  function f:GetNumPoints() return #self.__points end
  function f:GetPoint(i)
    local pt = self.__points[i or 1]
    if not pt then return "CENTER", self.__parent, "CENTER", 0, 0 end
    return pt[1], pt[2], pt[3], pt[4], pt[5]
  end
  function f:GetCenter() return 400, 300 end
  function f:GetEffectiveScale() return 1 end
  function f:GetFrameLevel() return 1 end
  function f:GetObjectType() return self.__type end
  function f:GetName() return self.__name end
  function f:GetParent() return self.__parent end

  function f:SetText(t) self.__text = t end
  function f:GetText() return self.__text end
  function f:GetStringWidth() return #tostring(self.__text or "") * 6 end
  function f:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end

  function f:SetValue(v) self.__value = v end
  function f:GetValue() return self.__value end
  function f:SetChecked(v) self.__checked = v and true or false end
  function f:GetChecked() return self.__checked end

  function f:GetChildren() return tunpack(self.__children) end
  function f:GetRegions() return tunpack(self.__regions) end

  function f:CreateFontString(n, layer, tmpl)
    local fs = mockFrame("FontString", n, self, tmpl)
    self.__regions[#self.__regions + 1] = fs
    return fs
  end
  function f:CreateTexture(n, layer, tmpl)
    local tx = mockFrame("Texture", n, self, tmpl)
    self.__regions[#self.__regions + 1] = tx
    return tx
  end

  -- Widgets that real Blizzard templates attach to the frame. These are
  -- lowercase in some cases (UICheckButtonTemplate's .text), so the PascalCase
  -- fallback below would not cover them.
  if type(template) == "string" then
    if template:find("CheckButton", 1, true) then
      f.text = mockFrame("FontString", nil, f)
    end
    if template:find("ScrollFrame", 1, true) then
      f.ScrollBar = mockFrame("Slider", nil, f)
    end
  end

  setmetatable(f, { __index = function(t, k)
    -- Anything else PascalCase is either a frame method we have not modelled or
    -- a child widget a template would have supplied (sf.ScrollBar, and friends).
    -- Hand back a stub that is both callable and indexable so chained use of
    -- either shape works. Lowercase keys stay nil, so addon code that probes
    -- its own fields (`if frame.text then`) still behaves correctly.
    if type(k) == "string" and k:match("^%u") then
      local stub = H.chainStub()
      t[k] = stub
      return stub
    end
    return nil
  end })

  return f
end

H.mockFrame = mockFrame

-------------------------------------------------------------------------------
-- Global API installation
-------------------------------------------------------------------------------

NUM_BAG_SLOTS = 4
unpack = tunpack           -- WoW's Lua 5.1 exposes this as a global
time   = os.time
date   = os.date

-- Capture the addon's chat output instead of printing it.
print = function(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
  H.chat[#H.chat + 1] = table.concat(parts, " ")
end

GetTime  = function() return H.now end
GetBuildInfo = function() return "12.0.5", "0", "", H.tocVersion end
GetMoney = function() return H.money end

GetRealmName = function() return H.realm end
UnitName     = function() return H.playerName end
UnitClass    = function() return H.className, H.classToken end
UnitGUID     = function(unit) return unit == "player" and "Player-1-00000001" or "Creature-0-1" end
UnitAffectingCombat = function() return H.inCombat end

C_Item = {
  -- Real signature returns 11+ values; name is 1, texture is 10, sellPrice 11.
  GetItemInfo = function(itemID)
    local it = H.itemDB[itemID]
    if not it then return nil end
    return it.name, "|Hitem:" .. itemID .. "|h", 1, 1, 1, "", "", 1, "", it.texture, it.price
  end,
}

C_Spell = {
  GetSpellTexture = function(spellID) return "Interface/Icons/Spell_" .. tostring(spellID) end,
}

C_CurrencyInfo = {
  GetCurrencyInfo = function(id)
    return { quantity = H.currency[id] or 0, name = "Currency" .. id }
  end,
}

C_Container = {
  GetContainerNumSlots = function(bag)
    return H.bags[bag] and H.SLOTS_PER_BAG or 0
  end,
  GetContainerItemInfo = function(bag, slot)
    local e = H.bags[bag] and H.bags[bag][slot]
    if not e then return nil end
    return { itemID = e.itemID, stackCount = e.stackCount }
  end,
  UseContainerItem = function(bag, slot)
    H.useCalls = H.useCalls + 1
    if not H.merchantOpen then H.usedOutsideMerchant = true end
    if H.sellBlocked then return end
    local e = H.bags[bag] and H.bags[bag][slot]
    if e then
      -- Selling at a vendor credits the player and empties the slot.
      local it = H.itemDB[e.itemID]
      if H.merchantOpen and it then H.money = H.money + it.price * e.stackCount end
      H.bags[bag][slot] = nil
    end
  end,
}

C_Timer = {
  NewTicker = function(_, fn)
    local t = { fn = fn, cancelled = false }
    t.Cancel = function(self) self.cancelled = true end
    H.tickers[#H.tickers + 1] = t
    return t
  end,
  After = function(_, fn)
    if H.autoRunAfters then fn() else H.afters[#H.afters + 1] = fn end
  end,
}

UIParent = mockFrame("Frame", "UIParent")
Minimap  = mockFrame("Frame", "Minimap")

MerchantFrame = mockFrame("Frame", "MerchantFrame")
MerchantFrame.IsShown = function() return H.merchantOpen end

SettingsPanel = mockFrame("Frame", "SettingsPanel")
SettingsPanel.IsShown = function() return false end

Settings = {
  RegisterCanvasLayoutCategory = function(panel, name)
    return { panel = panel, name = name }
  end,
  RegisterAddOnCategory = function(category)
    H.categories[#H.categories + 1] = category
  end,
  OpenToCategory = function() end,
}

GameTooltip = mockFrame("Frame", "GameTooltip")
GameTooltip.SetOwner      = function() end
GameTooltip.AddLine       = function(_, t) H.tooltip[#H.tooltip + 1] = tostring(t) end
GameTooltip.AddDoubleLine = function(_, l, r)
  H.tooltip[#H.tooltip + 1] = tostring(l) .. "\t" .. tostring(r)
end
GameTooltip.Show = function() end
GameTooltip.Hide = function() end

CreateFrame = function(frameType, name, parent, template)
  local f = mockFrame(frameType, name, parent, template)
  if name then _G[name] = f end
  if parent and parent.__children then
    parent.__children[#parent.__children + 1] = f
  end
  H.frames[#H.frames + 1] = f
  return f
end

StaticPopupDialogs = {}
SlashCmdList       = {}
UISpecialFrames    = {}   -- frames closed by Escape; options.lua registers itself
GetCursorPosition  = function() return 400, 300 end
HideUIPanel        = function() end
ShowUIPanel        = function() end
RAID_CLASS_COLORS  = { ROGUE = { r = 1, g = 0.96, b = 0.41 } }

-------------------------------------------------------------------------------
-- Addon loading
-------------------------------------------------------------------------------

--- Read the TOC's file list so tests load exactly what the game loads, in the
--- same order. Keeps the suite honest if the TOC changes.
function H.tocFiles()
  local list = {}
  -- The loop variable is const in newer Lua, so trim into a separate local.
  for raw in io.lines(ADDON_DIR .. "/PickPocketTracker.toc") do
    local line = raw:gsub("\r", ""):match("^%s*(.-)%s*$")
    if line ~= "" and not line:match("^#") then
      list[#list + 1] = line
    end
  end
  return list
end

--- Load the given addon files into a fresh namespace, exactly as the game
--- does: each file is a chunk receiving (addonName, NS). World state and
--- SavedVariables are left alone, so this models a /reload -- or a login on a
--- different character, once H.playerName has been changed.
function H.reload(files)
  local NS = { name = "PickPocketTracker" }
  for _, name in ipairs(files) do
    local path = ADDON_DIR .. "/" .. name
    local fh = assert(io.open(path, "r"), "cannot open " .. path)
    local src = fh:read("a")
    fh:close()
    local chunk, err = load(src, name)
    if not chunk then
      error("load error in " .. name .. ": " .. tostring(err), 0)
    end
    chunk("PickPocketTracker", NS)
  end
  return NS
end

--- A clean slate: fresh world, empty SavedVariables, freshly loaded addon.
function H.newEnv(files)
  H.resetWorld()
  PickPocketTrackerDB        = nil
  PickPocketTrackerAccountDB = nil
  return H.reload(files)
end

return H
