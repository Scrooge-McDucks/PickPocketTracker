-------------------------------------------------------------------------------
-- utils.lua — Shared helpers: chat output, money formatting, bag scanning,
-- item info with retry, and general-purpose math/string utilities
-------------------------------------------------------------------------------
local _, NS = ...

NS.Utils = {}

-------------------------------------------------------------------------------
-- Chat output
-------------------------------------------------------------------------------
local function ColorText(hex, text)
  return "|cff" .. hex .. tostring(text) .. "|r"
end

local function GetAddonTag()
  return ColorText(NS.Config:GetColor("TAG"), NS.Config.ADDON_NAME .. ":") .. " "
end

function NS.Utils:Print(hex, text)
  if hex then
    print(GetAddonTag() .. ColorText(hex, text))
  else
    print(GetAddonTag() .. tostring(text))
  end
end

function NS.Utils:PrintInfo(text)    self:Print(NS.Config:GetColor("INFO"), text) end
function NS.Utils:PrintSuccess(text) self:Print(NS.Config:GetColor("GOOD"), text) end
function NS.Utils:PrintWarning(text) self:Print(NS.Config:GetColor("WARN"), text) end
function NS.Utils:PrintError(text)   self:Print(NS.Config:GetColor("BAD"),  text) end
function NS.Utils:PrintNote(text)    self:Print(NS.Config:GetColor("NOTE"), text) end

-------------------------------------------------------------------------------
-- Money formatting
-------------------------------------------------------------------------------

--- Full format with gold/silver/copper icons: "5[G] 20[S] 30[C]"
function NS.Utils:FormatMoney(copper)
  local gold   = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local cop    = copper % 100

  local sz = NS.Config.MONEY_ICONS.size
  local fmt = "|T%s:%d:%d:0:0|t"
  local gI = fmt:format(NS.Config.MONEY_ICONS.goldIcon,   sz, sz)
  local sI = fmt:format(NS.Config.MONEY_ICONS.silverIcon, sz, sz)
  local cI = fmt:format(NS.Config.MONEY_ICONS.copperIcon, sz, sz)

  return string.format("%d%s %d%s %d%s", gold, gI, silver, sI, cop, cI)
end

--- Compact text-only format: "5g 20s" or "50s 10c" or "25c"
function NS.Utils:FormatMoneyCompact(copper)
  local gold   = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local cop    = copper % 100

  if gold > 0 then
    return string.format("%dg %ds", gold, silver)
  elseif silver > 0 then
    return string.format("%ds %dc", silver, cop)
  else
    return string.format("%dc", cop)
  end
end

-------------------------------------------------------------------------------
-- String helpers
-------------------------------------------------------------------------------

function NS.Utils:TrimString(str)
  return str:match("^%s*(.-)%s*$")
end

-------------------------------------------------------------------------------
-- Table helpers
-------------------------------------------------------------------------------

--- Sort a key/value table by a scoring function, returning an array of
--- {key=k, value=v} sorted highest-score-first.
function NS.Utils:TableSortBy(tbl, keyFunc)
  local array = {}
  for key, value in pairs(tbl) do
    array[#array + 1] = { key = key, value = value }
  end
  table.sort(array, function(a, b)
    return keyFunc(a.value) > keyFunc(b.value)
  end)
  return array
end

-------------------------------------------------------------------------------
-- Math helpers
-------------------------------------------------------------------------------

function NS.Utils:Clamp(value, min, max)
  return math.max(min, math.min(max, value))
end

-------------------------------------------------------------------------------
-- Item info (with async retry on cache miss)
-------------------------------------------------------------------------------

--- Wrapper that handles the C_Item vs legacy GetItemInfo API split.
local function SafeGetItemInfo(itemID)
  if C_Item and C_Item.GetItemInfo then
    return C_Item.GetItemInfo(itemID)
  elseif GetItemInfo then
    return GetItemInfo(itemID)
  end
  return nil
end

--- Fetch item name + texture. If the item isn't cached yet, retries up to
--- ITEM_CACHE_MAX_RETRIES times with a short delay between attempts.
function NS.Utils:GetItemInfo(itemID, callback, retries)
  retries = retries or 0
  local itemName, _, _, _, _, _, _, _, _, itemTexture = SafeGetItemInfo(itemID)

  if itemName then
    callback(itemID, itemName, itemTexture)
  elseif retries < NS.Config.ITEM_CACHE_MAX_RETRIES then
    C_Timer.After(NS.Config.ITEM_CACHE_RETRY_DELAY, function()
      self:GetItemInfo(itemID, callback, retries + 1)
    end)
  end
end

--- Return the vendor sell price for an item, or 0 if unknown.
function NS.Utils:GetVendorPrice(itemID)
  local vendorPrice = select(11, SafeGetItemInfo(itemID))
  return vendorPrice or 0
end

-------------------------------------------------------------------------------
-- Bag scanning (used for vendor-sale detection)
-------------------------------------------------------------------------------

--- Snapshot all bag contents as { [itemID] = totalCount }.
function NS.Utils:CreateBagSnapshot()
  local snapshot = {}
  for bag = 0, NUM_BAG_SLOTS do
    local numSlots = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, numSlots do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID then
        snapshot[info.itemID] = (snapshot[info.itemID] or 0) + (info.stackCount or 1)
      end
    end
  end
  return snapshot
end

-------------------------------------------------------------------------------
-- Shared display bar factory
--
-- Creates a small movable frame with tooltip-style backdrop, an icon, and
-- a text label. Both the gold haul window and the Coins of Air window are
-- built on this base so they share drag, resize, lock, and icon behaviour.
--
-- opts fields:
--   name         (string)   Global frame name (nil for anonymous)
--   width        (number)   Initial width
--   height       (number)   Initial height
--   iconTexture  (string)   Icon texture path
--   iconSize     (number)   Icon width/height (default 16)
--   iconCoords   (table)    Optional {l,r,t,b} for SetTexCoord
--   leftPadding  (number)   Left padding for icon/text (default 6)
--   rightPadding (number)   Right padding for text (default 4)
--   iconGap      (number)   Gap between icon and text (default 4)
--   getSavedPos  (function) Returns point, relPoint, x, y
--   onSavePos    (function) Called with (point, relPoint, x, y) on drag stop
--   edgeSize     (number)   Backdrop edge size (default 14)
--   bgAlpha      (number)   Background alpha (default 0.50)
--   isLocked     (function) Returns true if locked (grip hidden, drag blocked)
--   resizable    (table)    { minW, minH, maxW, maxH, onSaveSize(w,h) }
--   onResize     (function) Called during live resize (OnSizeChanged)
-------------------------------------------------------------------------------

function NS.Utils:CreateDisplayBar(opts)
  local f = CreateFrame("Frame", opts.name, UIParent, "BackdropTemplate")
  f:SetSize(opts.width, opts.height)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)

  local leftPad  = opts.leftPadding  or 6
  local rightPad = opts.rightPadding or 4
  local iconGap  = opts.iconGap      or 4

  -- Tooltip-style backdrop (shared skin)
  local edge = opts.edgeSize or 14
  f:SetBackdrop({
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = edge,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  f:SetBackdropColor(0.06, 0.06, 0.06, opts.bgAlpha or 0.50)

  ---------------------------------------------------------------------------
  -- Drag (lock-aware, shift bypasses lock)
  ---------------------------------------------------------------------------
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(s)
    if opts.isLocked and opts.isLocked() and not IsShiftKeyDown() then return end
    s:StartMoving()
  end)
  f:SetScript("OnDragStop", function(s)
    s:StopMovingOrSizing()
    if opts.onSavePos then
      local p, _, rp, x, y = s:GetPoint(1)
      opts.onSavePos(p, rp, x, y)
    end
  end)

  ---------------------------------------------------------------------------
  -- Icon
  ---------------------------------------------------------------------------
  local iconSz = opts.iconSize or 16
  local icon = f:CreateTexture(nil, "OVERLAY")
  icon:SetSize(iconSz, iconSz)
  icon:SetPoint("LEFT", leftPad, 0)
  icon:SetDrawLayer("OVERLAY", 2)
  if opts.iconTexture then icon:SetTexture(opts.iconTexture) end
  if opts.iconCoords then icon:SetTexCoord(unpack(opts.iconCoords)) end
  f.icon = icon

  ---------------------------------------------------------------------------
  -- Text label
  ---------------------------------------------------------------------------
  local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetJustifyH("LEFT")
  text:SetWordWrap(false)
  text:SetTextColor(1, 1, 1, 1)
  text:SetPoint("LEFT", icon, "RIGHT", iconGap, 0)
  text:SetPoint("RIGHT", f, "RIGHT", -rightPad, 0)
  f.text = text

  ---------------------------------------------------------------------------
  -- Icon show/hide with text re-anchor
  ---------------------------------------------------------------------------
  function f:SetIconVisible(show)
    if show then
      self.icon:Show()
      self.text:ClearAllPoints()
      self.text:SetPoint("LEFT", self.icon, "RIGHT", iconGap, 0)
      self.text:SetPoint("RIGHT", self, "RIGHT", -rightPad, 0)
    else
      self.icon:Hide()
      self.text:ClearAllPoints()
      self.text:SetPoint("LEFT", self, "LEFT", leftPad, 0)
      self.text:SetPoint("RIGHT", self, "RIGHT", -rightPad, 0)
    end
  end

  ---------------------------------------------------------------------------
  -- Resize grip (optional)
  ---------------------------------------------------------------------------
  if opts.resizable then
    local r = opts.resizable
    f:SetResizable(true)
    f:SetResizeBounds(r.minW, r.minH, r.maxW, r.maxH)

    local cfg  = NS.Config.RESIZE_GRIP
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(cfg.size, cfg.size)
    grip:SetPoint("BOTTOMRIGHT", -1, 1)
    grip:EnableMouse(true)
    grip:SetFrameLevel(f:GetFrameLevel() + 50)
    grip:SetHitRectInsets(cfg.hitRectInset, cfg.hitRectInset, cfg.hitRectInset, cfg.hitRectInset)

    local gripTex = grip:CreateTexture(nil, "OVERLAY")
    gripTex:SetAllPoints()
    gripTex:SetTexture(cfg.texture)
    gripTex:SetAlpha(cfg.alpha)

    grip:SetScript("OnMouseDown", function()
      if opts.isLocked and opts.isLocked() then return end
      f:StartSizing("BOTTOMRIGHT")
      if opts.onResize then
        f:SetScript("OnSizeChanged", function() opts.onResize() end)
      end
    end)

    grip:SetScript("OnMouseUp", function()
      f:StopMovingOrSizing()
      f:SetScript("OnSizeChanged", nil)
      local w, h = f:GetWidth(), f:GetHeight()
      -- Clamp to bounds
      w = math.max(r.minW, math.min(r.maxW, w))
      h = math.max(r.minH, math.min(r.maxH, h))
      f:SetSize(w, h)
      if r.onSaveSize then r.onSaveSize(w, h) end
      if opts.onResize then opts.onResize() end
    end)

    f.resizeGrip = grip

    -- Respect initial lock state
    if opts.isLocked and opts.isLocked() then grip:Hide() end
  end

  ---------------------------------------------------------------------------
  -- Lock state toggle (shows/hides grip)
  ---------------------------------------------------------------------------
  function f:SetLockState(locked)
    if self.resizeGrip then
      if locked then self.resizeGrip:Hide() else self.resizeGrip:Show() end
    end
  end

  ---------------------------------------------------------------------------
  -- Restore saved position
  ---------------------------------------------------------------------------
  if opts.getSavedPos then
    local p, rp, x, y = opts.getSavedPos()
    f:ClearAllPoints()
    f:SetPoint(p, UIParent, rp, x, y)
  end

  return f
end
