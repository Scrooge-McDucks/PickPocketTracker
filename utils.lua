-- utils.lua
-- Shared helpers + UI for Pick Pocket Tracker
--
-- Efficiency notes:
--  - UI elements (frame, textures, fontstrings) are created ONCE at login.
--  - We only update the displayed text when money actually increases via pickpocket window logic.
--  - Resizing updates skin/text only while actively resizing (OnSizeChanged during drag).

local _, NS = ...

-- =========================================================
-- SavedVariables (persist between sessions)
-- =========================================================
PickPocketTrackerDB = PickPocketTrackerDB or {}

-- UI toggles
if PickPocketTrackerDB.hidden == nil then PickPocketTrackerDB.hidden = false end
if PickPocketTrackerDB.usePlumberSkin == nil then PickPocketTrackerDB.usePlumberSkin = true end
if PickPocketTrackerDB.locked == nil then PickPocketTrackerDB.locked = false end
if PickPocketTrackerDB.showIcon == nil then PickPocketTrackerDB.showIcon = true end

-- Minimap button settings
if PickPocketTrackerDB.minimap == nil then PickPocketTrackerDB.minimap = {} end
if PickPocketTrackerDB.minimap.hide == nil then PickPocketTrackerDB.minimap.hide = false end
if PickPocketTrackerDB.minimap.angle == nil then PickPocketTrackerDB.minimap.angle = 220 end
if PickPocketTrackerDB.minimap.radius == nil then PickPocketTrackerDB.minimap.radius = 80 end

-- Saved position
if PickPocketTrackerDB.point == nil then PickPocketTrackerDB.point = "CENTER" end
if PickPocketTrackerDB.relPoint == nil then PickPocketTrackerDB.relPoint = "CENTER" end
if PickPocketTrackerDB.x == nil then PickPocketTrackerDB.x = 0 end
if PickPocketTrackerDB.y == nil then PickPocketTrackerDB.y = 180 end

-- Saved size (compact defaults because the frame is resizable)
if PickPocketTrackerDB.w == nil then PickPocketTrackerDB.w = 165 end
if PickPocketTrackerDB.h == nil then PickPocketTrackerDB.h = 26 end

-- =========================================================
-- Colours + chat helpers
-- =========================================================
NS.COL = {
  TAG  = "00ff66",
  INFO = "aaaaaa",
  GOOD = "66ffcc",
  WARN = "ffcc66",
  BAD  = "ff6666",
}

local function color(hex, text)
  return "|cff" .. hex .. tostring(text) .. "|r"
end

NS.tag = color(NS.COL.TAG, (NS.name or "PickPocketTracker") .. ":") .. " "

function NS.msg(hex, text)
  if hex then
    print(NS.tag .. color(hex, text))
  else
    print(NS.tag .. tostring(text))
  end
end

function NS.info(text) NS.msg(NS.COL.INFO, text) end
function NS.ok(text)   NS.msg(NS.COL.GOOD, text) end
function NS.warn(text) NS.msg(NS.COL.WARN, text) end
function NS.err(text)  NS.msg(NS.COL.BAD,  text) end

-- =========================================================
-- Money formatting (copper -> "9999g 99s 99c")
-- =========================================================
function NS.formatGSC(copper)
  local gold = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local cop = copper % 100

  local size = 14
  local gIcon = ("|TInterface/MoneyFrame/UI-GoldIcon:%d:%d:0:0|t"):format(size, size)
  local sIcon = ("|TInterface/MoneyFrame/UI-SilverIcon:%d:%d:0:0|t"):format(size, size)
  local cIcon = ("|TInterface/MoneyFrame/UI-CopperIcon:%d:%d:0:0|t"):format(size, size)

  -- Keep it compact: if 0g, still show 0g so its obvious whats going on
  return string.format("%d%s %d%s %d%s", gold, gIcon, silver, sIcon, cop, cIcon)
end

-- =========================================================
-- Optional dependency: Plumber
-- =========================================================
local function IsPlumberLoaded()
  if C_AddOns and C_AddOns.IsAddOnLoaded then
    return C_AddOns.IsAddOnLoaded("Plumber")
  end
  return IsAddOnLoaded and IsAddOnLoaded("Plumber")
end

-- =========================================================
-- Drag + Save Position
-- =========================================================
local function ApplySavedPosition(frame)
  frame:ClearAllPoints()
  frame:SetPoint(
    PickPocketTrackerDB.point or "CENTER",
    UIParent,
    PickPocketTrackerDB.relPoint or "CENTER",
    PickPocketTrackerDB.x or 0,
    PickPocketTrackerDB.y or 0
  )
end

local function EnableDragging(frame)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")

  frame:SetScript("OnDragStart", function(self)
    -- Locked: allow move only while holding Shift
    if PickPocketTrackerDB.locked and not IsShiftKeyDown() then return end
    self:StartMoving()
  end)

  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()

    local point, _, relPoint, x, y = self:GetPoint(1)
    PickPocketTrackerDB.point = point
    PickPocketTrackerDB.relPoint = relPoint
    PickPocketTrackerDB.x = math.floor((x or 0) + 0.5)
    PickPocketTrackerDB.y = math.floor((y or 0) + 0.5)
  end)
end

-- =========================================================
-- Resize + Save Size (live update while dragging)
-- =========================================================
local function EnableResizing(frame, onSizeChanged)
  frame:SetResizable(true)

  local grip = CreateFrame("Button", nil, frame)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -1, 1)
  grip:EnableMouse(true)

  -- Keep clickable above textures
  grip:SetFrameLevel((frame:GetFrameLevel() or 0) + 50)
  grip:SetHitRectInsets(-6, -6, -6, -6)

  local tex = grip:CreateTexture(nil, "OVERLAY")
  tex:SetAllPoints(grip)
  tex:SetTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
  tex:SetAlpha(0.7)

  local function clampAndSave()
    local w = math.floor(frame:GetWidth() + 0.5)
    local h = math.floor(frame:GetHeight() + 0.5)

    -- Small min to avoid "snap back bigger", but still sane.
    w = math.max(90,  math.min(420, w))
    h = math.max(20,  math.min(80,  h))

    frame:SetSize(w, h)

    PickPocketTrackerDB.w = w
    PickPocketTrackerDB.h = h

    if onSizeChanged then onSizeChanged(w, h) end
  end

  grip:SetScript("OnMouseDown", function()
    if PickPocketTrackerDB.locked then return end
    frame:StartSizing("BOTTOMRIGHT")

    -- Only do work while user is actively resizing
    frame:SetScript("OnSizeChanged", function()
      if onSizeChanged then
        onSizeChanged(frame:GetWidth(), frame:GetHeight())
      end
    end)
  end)

  grip:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
    frame:SetScript("OnSizeChanged", nil)
    clampAndSave()
  end)

  frame.ResizeGrip = grip
  if PickPocketTrackerDB.locked then grip:Hide() end
end

-- =========================================================
-- Plumber-style backdrop (PNG background + borders)
-- =========================================================
function NS.ApplyPlumberBackdrop(frame, width, height, alpha)
  local file = "Interface/AddOns/Plumber/Art/LootUI/LootUI.png"

  -- Create once; resize/reuse forever.
  if not frame.PB then
    frame.PB = {}

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    local top = frame:CreateTexture(nil, "BORDER")
    local left = frame:CreateTexture(nil, "BORDER")
    local right = frame:CreateTexture(nil, "BORDER")
    local bottom = frame:CreateTexture(nil, "BORDER")

    bg:SetTexture(file)
    top:SetTexture(file)
    left:SetTexture(file)
    right:SetTexture(file)
    bottom:SetTexture(file)

    left:SetTexCoord(504/1024, 0.5, 0, 1)
    top:SetTexCoord(0, 0.5, 504/512, 1)
    right:SetTexCoord(0.5, 504/1024, 0, 1)
    bottom:SetTexCoord(0, 0.5, 1, 504/512)

    frame.PB.bg = bg
    frame.PB.top = top
    frame.PB.left = left
    frame.PB.right = right
    frame.PB.bottom = bottom
  end

  local pb = frame.PB
  local lineWeight = 4
  local lineOffset = 1
  local bgExtrude = 5

  pb.bg:ClearAllPoints()
  pb.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", -bgExtrude, bgExtrude)
  pb.bg:SetSize(width + bgExtrude * 2, height + bgExtrude * 2)
  pb.bg:SetAlpha(alpha or 0.50)

  local maxBgSize = 512
  local bgW = width + bgExtrude
  local bgH = height + bgExtrude
  pb.bg:SetTexCoord(0.5, 0.5 + 0.5 * (bgW / maxBgSize), 0, 1 * (bgH / maxBgSize))

  pb.top:ClearAllPoints()
  pb.top:SetPoint("TOPLEFT", frame, "TOPLEFT", -lineOffset, 0)
  pb.top:SetSize(width + lineOffset, lineWeight)
  pb.top:SetAlpha(0.55)

  pb.left:ClearAllPoints()
  pb.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, lineOffset)
  pb.left:SetSize(lineWeight, height + lineOffset)
  pb.left:SetAlpha(0.55)

  pb.bottom:ClearAllPoints()
  pb.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -lineOffset, 0)
  pb.bottom:SetSize(width + lineOffset, lineWeight)
  pb.bottom:SetAlpha(0.20)

  pb.right:ClearAllPoints()
  pb.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, lineOffset)
  pb.right:SetSize(lineWeight, height + lineOffset)
  pb.right:SetAlpha(0.20)

  pb.bg:Show()
  pb.top:Show()
  pb.left:Show()
  pb.bottom:Show()
  pb.right:Show()
end

-- =========================================================
-- UI: Create the haul window
-- =========================================================
function NS.CreateGoldWindow()
  local usePlumberSkin = PickPocketTrackerDB.usePlumberSkin and IsPlumberLoaded()

  local W = PickPocketTrackerDB.w or 165
  local H = PickPocketTrackerDB.h or 26

  local f = CreateFrame("Frame", "PickPocketTrackerGoldFrame", UIParent, "BackdropTemplate")
  f:SetSize(W, H)

  ApplySavedPosition(f)
  EnableDragging(f)

  -- ---- Icon (spell texture is the most reliable)
  local icon = f:CreateTexture(nil, "OVERLAY")
  icon:SetSize(16, 16)
  icon:SetPoint("LEFT", 6, 0)
  icon:SetDrawLayer("OVERLAY", 2)

  local spellId = (NS.PP and NS.PP.PICK_POCKET_SPELL_ID) or 921
  local iconTex =
    (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellId))
    or (GetSpellTexture and GetSpellTexture(spellId))
    or "Interface/Icons/Ability_Rogue_PickPocket"

  icon:SetTexture(iconTex)
  icon:SetAlpha(1)

  -- ---- Text
  local fontObj = (usePlumberSkin and _G.PlumberLootUIFont) and "PlumberLootUIFont" or "GameFontHighlight"
  local txt = f:CreateFontString(nil, "OVERLAY", fontObj)
  txt:SetJustifyH("LEFT")
  txt:SetWordWrap(false)
  txt:SetTextColor(1, 1, 1, 1)

  local function anchorTextWithIcon()
    txt:ClearAllPoints()
    if PickPocketTrackerDB.showIcon then

-- Minimap button settings
if PickPocketTrackerDB.minimap == nil then PickPocketTrackerDB.minimap = {} end
if PickPocketTrackerDB.minimap.hide == nil then PickPocketTrackerDB.minimap.hide = false end
if PickPocketTrackerDB.minimap.angle == nil then PickPocketTrackerDB.minimap.angle = 220 end
if PickPocketTrackerDB.minimap.radius == nil then PickPocketTrackerDB.minimap.radius = 80 end
      icon:Show()
      txt:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    else
      icon:Hide()
      txt:SetPoint("LEFT", f, "LEFT", 6, 0)
    end
    txt:SetPoint("RIGHT", f, "RIGHT", -3, 0)
  end

  anchorTextWithIcon()

  -- ---- Skin (called on create + resize)
  local function applySkin()
    if usePlumberSkin then
      NS.ApplyPlumberBackdrop(f, W, H, 0.50)
    else
      f:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
      })
      f:SetBackdropColor(0.06, 0.06, 0.06, 0.50)
    end
  end

  applySkin()

  -- ---- Font fitting (scale-based so it keeps shrinking/growing smoothly)
  local baseSize = 12
  local minScale = 0.05
  local maxScale = 2.00

  local function fitText()
    local font, _, flags = txt:GetFont()
    if not font then return end

    txt:SetFont(font, baseSize, flags)
    txt:SetScale(1)

    -- Padding: left pad + optional icon + gap + right pad
    local leftPad = 6
    local rightPad = 3
    local iconW = (PickPocketTrackerDB.showIcon and 16 or 0)
    local gap = (PickPocketTrackerDB.showIcon and 4 or 0)

    local padding = leftPad + iconW + gap + rightPad
    local maxWidth = W - padding

    local textWidth = txt:GetStringWidth() or 0
    if textWidth <= 0 then return end

    if maxWidth <= 1 then
      txt:SetScale(minScale)
      return
    end

    local scale = maxWidth / textWidth
    if scale < minScale then scale = minScale end
    if scale > maxScale then scale = maxScale end
    txt:SetScale(scale)
  end

  -- Public: update displayed value
  function f:SetCopper(copper)
    txt:SetText("Haul: " .. NS.formatGSC(copper))
    fitText()
  end

  -- Public: apply icon setting immediately
  function f:ApplyIconSetting()
    anchorTextWithIcon()
    fitText()
  end

  -- Resizing updates W/H + re-applies skin + re-fits text
  EnableResizing(f, function(newW, newH)
    W, H = newW, newH
    applySkin()
    fitText()
  end)

  f:SetCopper(0)
  return f
end

-- =========================================================
-- Pick Pocket tracker (session logic)
-- =========================================================
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

function NS.PP:OnMoneyChanged()
  local money = GetMoney()
  local delta = money - self._lastMoney
  self._lastMoney = money

  -- Fast exits: most money events aren't pickpocket
  if delta <= 0 then return 0 end
  if (GetTime() - self._lastPPTime) > self.windowSeconds then return 0 end

  self.sessionCopper = self.sessionCopper + delta
  return delta
end