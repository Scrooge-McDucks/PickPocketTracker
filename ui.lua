-------------------------------------------------------------------------------
-- ui.lua — Main haul display window
--
-- A small draggable/resizable bar showing "Haul: 5g 20s 30c" with an
-- optional pickpocket ability icon. A green asterisk (*) appears when
-- there are unsold items in bags. Hovering shows a tooltip breakdown.
--
-- Built on the shared CreateDisplayBar factory (utils.lua) which handles
-- drag, resize grip, lock, and icon toggle. This file only adds text
-- auto-scaling (unique to the money format) and the haul-specific tooltip.
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
  self:AnchorText()
  self.mainFrame:SetLockState(NS.Data:IsLocked())
  self:UpdateVisibility()
  self:UpdateDisplay()
end

-------------------------------------------------------------------------------
-- Window construction
-------------------------------------------------------------------------------

function NS.UI:CreateMainWindow()
  local width, height = NS.Data:GetWindowSize()
  local d = NS.Config.UI_DEFAULTS

  -- Get the pickpocket icon texture
  local spellID = NS.Config.PICK_POCKET_SPELL_ID
  local tex = "Interface/Icons/Ability_Rogue_PickPocket"
  if C_Spell and C_Spell.GetSpellTexture then
    tex = C_Spell.GetSpellTexture(spellID) or tex
  elseif GetSpellTexture then
    tex = GetSpellTexture(spellID) or tex
  end

  local frame = NS.Utils:CreateDisplayBar({
    name         = "PickPocketTrackerMainFrame",
    width        = width,
    height       = height,
    iconTexture  = tex,
    iconSize     = d.iconSize,
    leftPadding  = d.leftPadding,
    rightPadding = d.rightPadding,
    iconGap      = d.iconGap,
    getSavedPos  = function() return NS.Data:GetWindowPosition() end,
    onSavePos    = function(p, rp, x, y) NS.Data:SetWindowPosition(p, rp, x, y) end,
    isLocked     = function() return NS.Data:IsLocked() end,
    onResize     = function() NS.UI:ScaleTextToFit() end,
    resizable    = {
      minW = d.minWidth,  minH = d.minHeight,
      maxW = d.maxWidth,  maxH = d.maxHeight,
      onSaveSize = function(w, h) NS.Data:SetWindowSize(w, h) end,
    },
  })

  self.iconTexture    = frame.icon
  self.textFontString = frame.text

  self:SetupTooltip(frame)
  return frame
end

-------------------------------------------------------------------------------
-- Text positioning and auto-scaling
-------------------------------------------------------------------------------

function NS.UI:AnchorText()
  if not self.mainFrame then return end
  self.mainFrame:SetIconVisible(NS.Data:ShouldShowIcon())
end

function NS.UI:ScaleTextToFit()
  if not self.textFontString or not self.mainFrame then return end
  local d = NS.Config.UI_DEFAULTS

  local font, _, flags = self.textFontString:GetFont()
  if not font then return end

  self.textFontString:SetFont(font, d.baseFontSize, flags)
  self.textFontString:SetScale(1)

  local iconSpace = NS.Data:ShouldShowIcon() and (d.iconSize + d.iconGap) or 0
  local padding   = d.leftPadding + iconSpace + d.rightPadding
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

-------------------------------------------------------------------------------
-- Display update
-------------------------------------------------------------------------------

function NS.UI:UpdateDisplay()
  if not self.textFontString then return end

  local gold   = NS.Tracking and NS.Tracking:GetSessionGold()    or 0
  local sold   = NS.Items    and NS.Items:GetSessionVendorValue() or 0
  local unsold = NS.Items    and NS.Items:GetUnsoldValue()        or 0

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
  if not self.mainFrame then return end
  local locked = NS.Data:IsLocked()
  self.mainFrame:SetLockState(locked)
  -- Coin window shares the same lock
  if NS.Coins and NS.Coins.frame then
    NS.Coins.frame:SetLockState(locked)
  end
end
