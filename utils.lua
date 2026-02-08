local _, NS = ...

-- ---------- SavedVariables ----------
PickPocketTrackerDB = PickPocketTrackerDB or {}
if PickPocketTrackerDB.hidden == nil then PickPocketTrackerDB.hidden = false end
if PickPocketTrackerDB.usePlumberSkin == nil then PickPocketTrackerDB.usePlumberSkin = true end

-- ---------- Colours ----------
NS.COL = {
  TAG  = "00ff66", -- addon prefix
  INFO = "aaaaaa", -- neutral/loaded text
  GOOD = "66ffcc", -- success/positive
  WARN = "ffcc66", -- toggles/warnings
  BAD  = "ff6666", -- errors
}

-- ---------- Chat helpers ----------
local function color(hex, text)
  return "|cff" .. hex .. tostring(text) .. "|r"
end

NS.tag = color(NS.COL.TAG, NS.name .. ":") .. " "

function NS.msg(hex, text)
  if hex then
    print(NS.tag .. color(hex, text))
  else
    print(NS.tag .. tostring(text))
  end
end

-- Optional semantic wrappers (makes core.lua nicer to read)
function NS.info(text) NS.msg(NS.COL.INFO, text) end
function NS.ok(text)   NS.msg(NS.COL.GOOD, text) end
function NS.warn(text) NS.msg(NS.COL.WARN, text) end
function NS.err(text)  NS.msg(NS.COL.BAD,  text) end

-- ---------- Money formatting ----------
function NS.formatGSC(copper)
  local gold = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local cop = copper % 100
  return string.format("%dg %ds %dc", gold, silver, cop)
end

-- ---------- Addon availability ----------
local function IsPlumberLoaded()
  if C_AddOns and C_AddOns.IsAddOnLoaded then
    return C_AddOns.IsAddOnLoaded("Plumber")
  end
  return IsAddOnLoaded and IsAddOnLoaded("Plumber")
end

-- ---------- UI: static window ----------
function NS.CreateGoldWindow()
  local usePlumber = PickPocketTrackerDB.usePlumberSkin and IsPlumberLoaded()

  local f = CreateFrame("Frame", "PickPocketTrackerGoldFrame", UIParent, "BackdropTemplate")
  f:SetSize(260, 44)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 180)

  local icon = f:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetPoint("LEFT", 10, 0)
  icon:SetTexture("Interface/Icons/Ability_Rogue_PickPocket")

  local font = usePlumber and "PlumberLootUIFont" or "GameFontHighlight"
  local txt = f:CreateFontString(nil, "OVERLAY", font)
  txt:SetPoint("LEFT", icon, "RIGHT", 8, 0)
  txt:SetPoint("RIGHT", f, "RIGHT", -10, 0)
  txt:SetJustifyH("LEFT")
  txt:SetWordWrap(false)

  if usePlumber then
    f:SetBackdrop({
      bgFile = "Interface\\AddOns\\Plumber\\Art\\LootUI\\LootUI.png",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = false, edgeSize = 16,
      insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    f:SetBackdropColor(1, 1, 1, 0.90)
  else
    f:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
  end

  function f:SetCopper(copper)
    txt:SetText("Haul: " .. NS.formatGSC(copper))
  end

  f:SetCopper(0)
  return f
end

-- ---------- Pick Pocket tracker ----------
NS.PP = NS.PP or {}
NS.PP.PICK_POCKET_SPELL_ID = 921
NS.PP.windowSeconds = 2.0

NS.PP.sessionCopper = 0
NS.PP._lastPPTime = 0
NS.PP._lastMoney = 0

function NS.PP:OnLogin()
  self._lastMoney = GetMoney()
end

function NS.PP:ResetSession()
  self.sessionCopper = 0
end

function NS.PP:SetWindowSeconds(sec)
  self.windowSeconds = sec
end

function NS.PP:OnPickPocketCast()
  self._lastPPTime = GetTime()
end

-- Returns copper added that we attribute to Pick Pocket, or 0
function NS.PP:OnMoneyChanged()
  local money = GetMoney()
  local delta = money - self._lastMoney
  self._lastMoney = money

  if delta <= 0 then return 0 end
  if (GetTime() - self._lastPPTime) > self.windowSeconds then return 0 end

  self.sessionCopper = self.sessionCopper + delta
  return delta
end
