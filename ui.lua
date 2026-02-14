-- Main display window UI
local _, NS = ...

NS.UI = {}

-- Frame references
NS.UI.mainFrame = nil
NS.UI.iconTexture = nil
NS.UI.textFontString = nil

function NS.UI:Initialize()
  self.mainFrame = self:CreateMainWindow()
  self:ApplyWindowSettings()
  self:UpdateVisibility()
  self:UpdateDisplay()
end

-- Main window creation
function NS.UI:CreateMainWindow()
  local width, height = NS.Data:GetWindowSize()
  
  local frame = CreateFrame("Frame", "PickPocketTrackerMainFrame", UIParent, "BackdropTemplate")
  frame:SetSize(width, height)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  
  self:ApplySkin(frame)
  self.iconTexture = self:CreateIcon(frame)
  self.textFontString = self:CreateText(frame)
  
  self:EnableDragging(frame)
  self:EnableResizing(frame)
  self:SetupTooltip(frame)
  
  return frame
end

function NS.UI:CreateIcon(parentFrame)
  local iconSize = NS.Config.UI_DEFAULTS.iconSize
  
  local icon = parentFrame:CreateTexture(nil, "OVERLAY")
  icon:SetSize(iconSize, iconSize)
  icon:SetPoint("LEFT", NS.Config.UI_DEFAULTS.leftPadding, 0)
  icon:SetDrawLayer("OVERLAY", 2)
  
  local spellID = NS.Config.PICK_POCKET_SPELL_ID
  local iconTexture = "Interface/Icons/Ability_Rogue_PickPocket"
  
  if C_Spell and C_Spell.GetSpellTexture then
    iconTexture = C_Spell.GetSpellTexture(spellID) or iconTexture
  elseif GetSpellTexture then
    iconTexture = GetSpellTexture(spellID) or iconTexture
  end
  
  icon:SetTexture(iconTexture)
  icon:SetAlpha(1)
  
  return icon
end

function NS.UI:CreateText(parentFrame)
  local text = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetJustifyH("LEFT")
  text:SetWordWrap(false)
  text:SetTextColor(1, 1, 1, 1)
  text:SetPoint("LEFT", parentFrame, "LEFT", NS.Config.UI_DEFAULTS.leftPadding, 0)
  text:SetPoint("RIGHT", parentFrame, "RIGHT", -NS.Config.UI_DEFAULTS.rightPadding, 0)
  
  return text
end

-- Text positioning
function NS.UI:AnchorText()
  if not self.textFontString then return end
  
  self.textFontString:ClearAllPoints()
  
  if NS.Data:ShouldShowIcon() then
    self.iconTexture:Show()
    self.textFontString:SetPoint("LEFT", self.iconTexture, "RIGHT", 
      NS.Config.UI_DEFAULTS.iconGap, 0)
  else
    self.iconTexture:Hide()
    self.textFontString:SetPoint("LEFT", self.mainFrame, "LEFT", 
      NS.Config.UI_DEFAULTS.leftPadding, 0)
  end
  
  self.textFontString:SetPoint("RIGHT", self.mainFrame, "RIGHT", 
    -NS.Config.UI_DEFAULTS.rightPadding, 0)
end

-- Text scaling to fit window
function NS.UI:ScaleTextToFit()
  if not self.textFontString or not self.mainFrame then return end
  
  local width = self.mainFrame:GetWidth()
  local font, _, flags = self.textFontString:GetFont()
  if not font then return end
  
  local baseSize = NS.Config.UI_DEFAULTS.baseFontSize
  self.textFontString:SetFont(font, baseSize, flags)
  self.textFontString:SetScale(1)
  
  local padding = self:CalculatePadding()
  local availableWidth = width - padding
  
  if availableWidth <= 1 then
    self.textFontString:SetScale(NS.Config.UI_DEFAULTS.minFontScale)
    return
  end
  
  local textWidth = self.textFontString:GetStringWidth() or 0
  if textWidth <= 0 then return end
  
  local scale = availableWidth / textWidth
  local minScale = NS.Config.UI_DEFAULTS.minFontScale
  local maxScale = NS.Config.UI_DEFAULTS.maxFontScale
  scale = NS.Utils:Clamp(scale, minScale, maxScale)
  
  self.textFontString:SetScale(scale)
end

function NS.UI:CalculatePadding()
  local leftPad = NS.Config.UI_DEFAULTS.leftPadding
  local rightPad = NS.Config.UI_DEFAULTS.rightPadding
  
  local iconWidth = 0
  local iconGap = 0
  
  if NS.Data:ShouldShowIcon() then
    iconWidth = NS.Config.UI_DEFAULTS.iconSize
    iconGap = NS.Config.UI_DEFAULTS.iconGap
  end
  
  return leftPad + iconWidth + iconGap + rightPad
end

-- Dragging
function NS.UI:EnableDragging(frame)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  
  frame:SetScript("OnDragStart", function(self)
    if NS.Data:IsLocked() and not IsShiftKeyDown() then
      return
    end
    self:StartMoving()
  end)
  
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint(1)
    NS.Data:SetWindowPosition(point, relPoint, x, y)
  end)
end

-- Resizing
function NS.UI:EnableResizing(frame)
  frame:SetResizable(true)
  
  local grip = CreateFrame("Button", nil, frame)
  local gripSize = NS.Config.RESIZE_GRIP.size
  grip:SetSize(gripSize, gripSize)
  grip:SetPoint("BOTTOMRIGHT", -1, 1)
  grip:EnableMouse(true)
  grip:SetFrameLevel(frame:GetFrameLevel() + 50)
  
  local inset = NS.Config.RESIZE_GRIP.hitRectInset
  grip:SetHitRectInsets(inset, inset, inset, inset)
  
  local tex = grip:CreateTexture(nil, "OVERLAY")
  tex:SetAllPoints(grip)
  tex:SetTexture(NS.Config.RESIZE_GRIP.texture)
  tex:SetAlpha(NS.Config.RESIZE_GRIP.alpha)
  
  frame.resizeGrip = grip
  
  grip:SetScript("OnMouseDown", function()
    if NS.Data:IsLocked() then return end
    
    frame:StartSizing("BOTTOMRIGHT")
    frame:SetScript("OnSizeChanged", function()
      NS.UI:ScaleTextToFit()
    end)
  end)
  
  grip:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
    frame:SetScript("OnSizeChanged", nil)
    NS.UI:FinalizeResize()
  end)
  
  if NS.Data:IsLocked() then
    grip:Hide()
  end
end

function NS.UI:FinalizeResize()
  local width = self.mainFrame:GetWidth()
  local height = self.mainFrame:GetHeight()
  
  width, height = NS.Data:ClampWindowSize(width, height)
  self.mainFrame:SetSize(width, height)
  NS.Data:SetWindowSize(width, height)
  
  self:ScaleTextToFit()
end

-- Skin
function NS.UI:ApplySkin(frame)
  frame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, 
    tileSize = 16, 
    edgeSize = 14,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  frame:SetBackdropColor(0.06, 0.06, 0.06, 0.50)
end

-- Window settings
function NS.UI:ApplyWindowSettings()
  if not self.mainFrame then return end
  
  local point, relPoint, x, y = NS.Data:GetWindowPosition()
  self.mainFrame:ClearAllPoints()
  self.mainFrame:SetPoint(point, UIParent, relPoint, x, y)
  
  local width, height = NS.Data:GetWindowSize()
  self.mainFrame:SetSize(width, height)
  
  self:AnchorText()
  
  if NS.Data:IsLocked() and self.mainFrame.resizeGrip then
    self.mainFrame.resizeGrip:Hide()
  end
end

-- Display update
function NS.UI:UpdateDisplay()
  if not self.textFontString then return end
  
  local goldValue = 0
  local soldValue = 0
  local unsoldValue = 0
  
  if NS.Tracking then
    goldValue = NS.Tracking:GetSessionGold()
  end
  if NS.Items then
    soldValue = NS.Items:GetSessionVendorValue()
    unsoldValue = NS.Items:GetUnsoldValue()
  end
  
  local confirmedTotal = goldValue + soldValue
  
  if unsoldValue > 0 then
    self.textFontString:SetText("Haul: " .. NS.Utils:FormatMoney(confirmedTotal) .. " |cff66ffaa*|r")
  else
    self.textFontString:SetText("Haul: " .. NS.Utils:FormatMoney(confirmedTotal))
  end
  
  -- Store for tooltip
  self.cachedGold = goldValue
  self.cachedSold = soldValue
  self.cachedUnsold = unsoldValue
  
  self:ScaleTextToFit()
end

-- Tooltip on hover
function NS.UI:SetupTooltip(frame)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Pick Pocket Tracker")
    
    local gold = NS.UI.cachedGold or 0
    local sold = NS.UI.cachedSold or 0
    local unsold = NS.UI.cachedUnsold or 0
    
    if gold > 0 then
      GameTooltip:AddDoubleLine("Gold looted:", NS.Utils:FormatMoneyCompact(gold), 1,1,1, 1,1,1)
    end
    if sold > 0 then
      GameTooltip:AddDoubleLine("Items sold:", NS.Utils:FormatMoneyCompact(sold), 1,1,1, 1,1,1)
    end
    if unsold > 0 then
      GameTooltip:AddDoubleLine("Pending vendor:", NS.Utils:FormatMoneyCompact(unsold), 0.4,1,0.67, 0.4,1,0.67)
    end
    if gold == 0 and sold == 0 and unsold == 0 then
      GameTooltip:AddLine("No loot yet", 0.7, 0.7, 0.7)
    end
    
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
end

-- Visibility
function NS.UI:UpdateVisibility()
  if not self.mainFrame then return end
  
  if NS.Data:IsHidden() then
    self.mainFrame:Hide()
  else
    self.mainFrame:Show()
  end
end

-- Setting changes
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
