-------------------------------------------------------------------------------
-- ui.lua — Main haul display window
--
-- A small draggable/resizable bar showing "Haul: 5g 20s 30c" with an
-- optional pickpocket ability icon. A green asterisk (*) appears when
-- there are unsold items in bags. Hovering shows a tooltip breakdown.
--
-- Text auto-scales to fit the window width. Window position, size, and
-- visibility are persisted in SavedVariables via NS.Data.
-------------------------------------------------------------------------------
local _, NS = ...

NS.UI = {}

NS.UI.mainFrame      = nil
NS.UI.iconTexture    = nil
NS.UI.textFontString = nil

-- Cached for tooltip (avoids recalculating on hover)
NS.UI.cachedGold   = 0
NS.UI.cachedSold   = 0
NS.UI.cachedUnsold = 0

function NS.UI:Initialize()
  self.mainFrame = self:CreateMainWindow()
  self:ApplyWindowSettings()
  self:UpdateVisibility()
  self:UpdateDisplay()
end

-------------------------------------------------------------------------------
-- Window construction
-------------------------------------------------------------------------------

function NS.UI:CreateMainWindow()
  local width, height = NS.Data:GetWindowSize()
  local d = NS.Config.UI_DEFAULTS

  local frame = CreateFrame("Frame", "PickPocketTrackerMainFrame", UIParent, "BackdropTemplate")
  frame:SetSize(width, height)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)

  -- 10.0+ requires SetResizeBounds instead of the removed SetMinResize/SetMaxResize
  frame:SetResizable(true)
  frame:SetResizeBounds(d.minWidth, d.minHeight, d.maxWidth, d.maxHeight)

  self:ApplySkin(frame)
  self.iconTexture    = self:CreateIcon(frame)
  self.textFontString = self:CreateText(frame)

  self:SetupDragging(frame)
  self:SetupResizing(frame)
  self:SetupTooltip(frame)

  return frame
end

function NS.UI:CreateIcon(parent)
  local size = NS.Config.UI_DEFAULTS.iconSize
  local icon = parent:CreateTexture(nil, "OVERLAY")
  icon:SetSize(size, size)
  icon:SetPoint("LEFT", NS.Config.UI_DEFAULTS.leftPadding, 0)
  icon:SetDrawLayer("OVERLAY", 2)

  -- Try the modern API first, fall back to legacy
  local spellID = NS.Config.PICK_POCKET_SPELL_ID
  local tex = "Interface/Icons/Ability_Rogue_PickPocket"
  if C_Spell and C_Spell.GetSpellTexture then
    tex = C_Spell.GetSpellTexture(spellID) or tex
  elseif GetSpellTexture then
    tex = GetSpellTexture(spellID) or tex
  end
  icon:SetTexture(tex)

  return icon
end

function NS.UI:CreateText(parent)
  local d    = NS.Config.UI_DEFAULTS
  local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetJustifyH("LEFT")
  text:SetWordWrap(false)
  text:SetTextColor(1, 1, 1, 1)
  text:SetPoint("LEFT",  parent, "LEFT",  d.leftPadding,  0)
  text:SetPoint("RIGHT", parent, "RIGHT", -d.rightPadding, 0)
  return text
end

-------------------------------------------------------------------------------
-- Text positioning and auto-scaling
-------------------------------------------------------------------------------

--- Re-anchor text left edge depending on whether the icon is visible.
function NS.UI:AnchorText()
  if not self.textFontString then return end
  local d = NS.Config.UI_DEFAULTS

  self.textFontString:ClearAllPoints()
  if NS.Data:ShouldShowIcon() then
    self.iconTexture:Show()
    self.textFontString:SetPoint("LEFT", self.iconTexture, "RIGHT", d.iconGap, 0)
  else
    self.iconTexture:Hide()
    self.textFontString:SetPoint("LEFT", self.mainFrame, "LEFT", d.leftPadding, 0)
  end
  self.textFontString:SetPoint("RIGHT", self.mainFrame, "RIGHT", -d.rightPadding, 0)
end

--- Scale the font so the text string fits the available window width.
function NS.UI:ScaleTextToFit()
  if not self.textFontString or not self.mainFrame then return end
  local d = NS.Config.UI_DEFAULTS

  local font, _, flags = self.textFontString:GetFont()
  if not font then return end

  -- Reset to base size before measuring
  self.textFontString:SetFont(font, d.baseFontSize, flags)
  self.textFontString:SetScale(1)

  local padding   = self:CalculatePadding()
  local available = self.mainFrame:GetWidth() - padding
  if available <= 1 then
    self.textFontString:SetScale(d.minFontScale)
    return
  end

  local textWidth = self.textFontString:GetStringWidth() or 0
  if textWidth <= 0 then return end

  local scale = NS.Utils:Clamp(available / textWidth, d.minFontScale, d.maxFontScale)
  self.textFontString:SetScale(scale)
end

function NS.UI:CalculatePadding()
  local d = NS.Config.UI_DEFAULTS
  local iconSpace = NS.Data:ShouldShowIcon() and (d.iconSize + d.iconGap) or 0
  return d.leftPadding + iconSpace + d.rightPadding
end

-------------------------------------------------------------------------------
-- Dragging
-------------------------------------------------------------------------------

function NS.UI:SetupDragging(frame)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")

  frame:SetScript("OnDragStart", function(f)
    -- Shift-drag bypasses lock
    if NS.Data:IsLocked() and not IsShiftKeyDown() then return end
    f:StartMoving()
  end)

  frame:SetScript("OnDragStop", function(f)
    f:StopMovingOrSizing()
    local point, _, relPoint, x, y = f:GetPoint(1)
    NS.Data:SetWindowPosition(point, relPoint, x, y)
  end)
end

-------------------------------------------------------------------------------
-- Resizing
-------------------------------------------------------------------------------

function NS.UI:SetupResizing(frame)
  local cfg  = NS.Config.RESIZE_GRIP
  local grip = CreateFrame("Button", nil, frame)
  grip:SetSize(cfg.size, cfg.size)
  grip:SetPoint("BOTTOMRIGHT", -1, 1)
  grip:EnableMouse(true)
  grip:SetFrameLevel(frame:GetFrameLevel() + 50)
  grip:SetHitRectInsets(cfg.hitRectInset, cfg.hitRectInset, cfg.hitRectInset, cfg.hitRectInset)

  local tex = grip:CreateTexture(nil, "OVERLAY")
  tex:SetAllPoints()
  tex:SetTexture(cfg.texture)
  tex:SetAlpha(cfg.alpha)

  frame.resizeGrip = grip

  grip:SetScript("OnMouseDown", function()
    if NS.Data:IsLocked() then return end
    frame:StartSizing("BOTTOMRIGHT")
    frame:SetScript("OnSizeChanged", function() NS.UI:ScaleTextToFit() end)
  end)

  grip:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
    frame:SetScript("OnSizeChanged", nil)
    NS.UI:FinalizeResize()
  end)

  if NS.Data:IsLocked() then grip:Hide() end
end

function NS.UI:FinalizeResize()
  local w, h = self.mainFrame:GetWidth(), self.mainFrame:GetHeight()
  w, h = NS.Data:ClampWindowSize(w, h)
  self.mainFrame:SetSize(w, h)
  NS.Data:SetWindowSize(w, h)
  self:ScaleTextToFit()
end

-------------------------------------------------------------------------------
-- Skin (tooltip-style backdrop)
-------------------------------------------------------------------------------

function NS.UI:ApplySkin(frame)
  frame:SetBackdrop({
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  frame:SetBackdropColor(0.06, 0.06, 0.06, 0.50)
end

-------------------------------------------------------------------------------
-- Apply persisted position/size on login
-------------------------------------------------------------------------------

function NS.UI:ApplyWindowSettings()
  if not self.mainFrame then return end

  local point, relPoint, x, y = NS.Data:GetWindowPosition()
  self.mainFrame:ClearAllPoints()
  self.mainFrame:SetPoint(point, UIParent, relPoint, x, y)
  self.mainFrame:SetSize(NS.Data:GetWindowSize())

  self:AnchorText()
  if NS.Data:IsLocked() and self.mainFrame.resizeGrip then
    self.mainFrame.resizeGrip:Hide()
  end
end

-------------------------------------------------------------------------------
-- Display update
-------------------------------------------------------------------------------

function NS.UI:UpdateDisplay()
  if not self.textFontString then return end

  local gold   = NS.Tracking and NS.Tracking:GetSessionGold()        or 0
  local sold   = NS.Items    and NS.Items:GetSessionVendorValue()     or 0
  local unsold = NS.Items    and NS.Items:GetUnsoldValue()            or 0

  local confirmed = gold + sold
  if unsold > 0 then
    self.textFontString:SetText("Haul: " .. NS.Utils:FormatMoney(confirmed) .. " |cff66ffaa*|r")
  else
    self.textFontString:SetText("Haul: " .. NS.Utils:FormatMoney(confirmed))
  end

  self.cachedGold   = gold
  self.cachedSold   = sold
  self.cachedUnsold = unsold
  self:ScaleTextToFit()
end

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------

function NS.UI:SetupTooltip(frame)
  frame:SetScript("OnEnter", function(f)
    GameTooltip:SetOwner(f, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Pick Pocket Tracker")

    local g, s, u = NS.UI.cachedGold, NS.UI.cachedSold, NS.UI.cachedUnsold
    if g > 0 then
      GameTooltip:AddDoubleLine("Gold looted:",   NS.Utils:FormatMoneyCompact(g), 1,1,1, 1,1,1)
    end
    if s > 0 then
      GameTooltip:AddDoubleLine("Items sold:",    NS.Utils:FormatMoneyCompact(s), 1,1,1, 1,1,1)
    end
    if u > 0 then
      GameTooltip:AddDoubleLine("Pending vendor:", NS.Utils:FormatMoneyCompact(u), 0.4,1,0.67, 0.4,1,0.67)
    end
    if g == 0 and s == 0 and u == 0 then
      GameTooltip:AddLine("No loot yet", 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
  end)

  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-------------------------------------------------------------------------------
-- Visibility and setting-change callbacks
-------------------------------------------------------------------------------

function NS.UI:UpdateVisibility()
  if not self.mainFrame then return end
  if NS.Data:IsHidden() then self.mainFrame:Hide() else self.mainFrame:Show() end
end

function NS.UI:OnIconSettingChanged()
  self:AnchorText()
  self:ScaleTextToFit()
end

function NS.UI:OnLockSettingChanged()
  if not self.mainFrame or not self.mainFrame.resizeGrip then return end
  if NS.Data:IsLocked() then
    self.mainFrame.resizeGrip:Hide()
  else
    self.mainFrame.resizeGrip:Show()
  end
end
