-- Options Window UI
local _, NS = ...

NS.Options = {}
NS.Options.frame = nil
NS.Options.updateBottomStats = nil

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function CreateCheckbox(parent, text, tooltip, checked, onChange)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(26, 26)
  cb:SetChecked(checked)
  cb.text:SetText(text)
  cb.text:SetFontObject("GameFontNormal")
  cb:SetScript("OnClick", function(self) onChange(self:GetChecked()) end)
  if tooltip then
    cb:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  return cb
end

local function CreateHeader(parent, text, y)
  local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  h:SetPoint("TOPLEFT", 20, y)
  h:SetText(text)
  h:SetTextColor(1, 0.82, 0)
  return h
end

local function CreateDivider(parent, y)
  local l = parent:CreateTexture(nil, "ARTWORK")
  l:SetHeight(1)
  l:SetPoint("LEFT", 20, 0)
  l:SetPoint("RIGHT", -20, 0)
  l:SetPoint("TOP", 0, y)
  l:SetColorTexture(0.5, 0.5, 0.5, 0.3)
  return l
end

local function MakeResetBtn(parent, label, yOff, tooltipLines, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(140, 25)
  b:SetPoint("TOPRIGHT", -15, yOff)
  b:SetText(label)
  b:SetScript("OnClick", onClick)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    for _, line in ipairs(tooltipLines) do
      GameTooltip:AddLine(line[1], line[2], line[3], line[4], true)
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

--------------------------------------------------------------------------------
-- Main Frame
--------------------------------------------------------------------------------
function NS.Options:Initialize()
  if self.frame then return end
  self.frame = self:CreateOptionsFrame()
  self:CreateContent()
end

function NS.Options:CreateOptionsFrame()
  local f = CreateFrame("Frame", "PickPocketTrackerOptionsFrame", UIParent, "BackdropTemplate")
  f:SetSize(420, 500)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:Hide()

  f:SetBackdrop({
    bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
    edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
  })

  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(s) s:StartMoving() end)
  f:SetScript("OnDragStop", function(s) s:StopMovingOrSizing() end)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -15)
  title:SetText("Pick Pocket Tracker")

  local ver = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ver:SetPoint("TOP", 0, -35)
  ver:SetText("v" .. NS.Config.VERSION)
  ver:SetTextColor(0.7, 0.7, 0.7)

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -5, -5)

  table.insert(UISpecialFrames, "PickPocketTrackerOptionsFrame")
  return f
end

--------------------------------------------------------------------------------
-- Content
--------------------------------------------------------------------------------
function NS.Options:CreateContent()
  local parent = self.frame
  local y = -55

  -- Display Settings
  CreateHeader(parent, "Display", y); y = y - 28

  local checks = {
    { "Hide Main Window", "Toggle the pickpocket display window on/off",
      NS.Data:IsHidden(), function(v) NS.Data:SetHidden(v); NS.UI:UpdateVisibility() end },
    { "Lock Window Position", "Prevent accidental resizing (Shift-drag still moves)",
      NS.Data:IsLocked(), function(v) NS.Data:SetLocked(v); NS.UI:OnLockSettingChanged() end },
    { "Show Pickpocket Icon", "Display the pickpocket ability icon in the window",
      NS.Data:ShouldShowIcon(), function(v) NS.Data:SetShowIcon(v); NS.UI:OnIconSettingChanged() end },
    { "Show Minimap Button", "Display the minimap button for quick access",
      not NS.Data:IsMinimapHidden(), function(v) NS.Data:SetMinimapHidden(not v); if NS.Minimap then NS.Minimap:Apply() end end },
    { "Log Items to Chat", "Show pickpocketed/sold item messages in chat",
      NS.Data:ShouldChatLogItems(), function(v) NS.Data:SetChatLogItems(v) end },
  }
  for _, info in ipairs(checks) do
    local cb = CreateCheckbox(parent, info[1], info[2], info[3], info[4])
    cb:SetPoint("TOPLEFT", 20, y); y = y - 28
  end
  y = y - 8

  CreateDivider(parent, y); y = y - 18

  -- Tracking Settings
  CreateHeader(parent, "Tracking", y); y = y - 32

  local sliderLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sliderLabel:SetPoint("TOPLEFT", 30, y)
  sliderLabel:SetText(string.format("Detection Window: %.1f seconds", NS.Tracking:GetDetectionWindow()))
  y = y - 22

  local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  slider:SetPoint("TOPLEFT", 30, y)
  slider:SetWidth(340)
  slider:SetMinMaxValues(0.1, 10.0)
  slider:SetValue(NS.Tracking:GetDetectionWindow())
  slider:SetValueStep(0.1)
  slider:SetObeyStepOnDrag(true)
  slider.Low:SetText("0.1s"); slider.High:SetText("10.0s")
  slider:SetScript("OnValueChanged", function(_, val)
    val = math.floor(val * 10 + 0.5) / 10
    sliderLabel:SetText(string.format("Detection Window: %.1f seconds", val))
    NS.Tracking:SetDetectionWindow(val)
  end)

  local help = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", 30, y - 25)
  help:SetWidth(350); help:SetJustifyH("LEFT")
  help:SetText("Time after pickpocket cast to count gold/items. Increase if items are missed.")
  help:SetTextColor(0.7, 0.7, 0.7)

  -- Bottom panel
  self:CreateBottomPanel()
end

--------------------------------------------------------------------------------
-- Bottom Panel (Stats + Reset)
--------------------------------------------------------------------------------
function NS.Options:CreateBottomPanel()
  local bp = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
  bp:SetPoint("BOTTOMLEFT", 10, 10)
  bp:SetPoint("BOTTOMRIGHT", -10, 10)
  bp:SetHeight(140)
  bp:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  bp:SetBackdropColor(0, 0, 0, 0.5)
  bp:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

  -- Left: stats
  local sTitle = bp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sTitle:SetPoint("TOPLEFT", 12, -8)
  sTitle:SetText("Lifetime Stats"); sTitle:SetTextColor(1, 0.82, 0)

  local charSummary = bp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  charSummary:SetPoint("TOPLEFT", 12, -26)
  charSummary:SetJustifyH("LEFT"); charSummary:SetWidth(200)

  local accSummary = bp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  accSummary:SetPoint("TOPLEFT", 12, -72)
  accSummary:SetJustifyH("LEFT"); accSummary:SetWidth(200)

  local function UpdateBottomStats()
    if not NS.Stats then return end
    local cT, cC = NS.Stats:GetCharacterTotal(), NS.Stats:GetCharacterPickpocketCount()
    local cA = cC > 0 and (cT / cC) or 0
    charSummary:SetText(string.format(
      "This Character:\n%s (%d pickpockets)\nAvg: %s",
      NS.Utils:FormatMoney(cT), cC, NS.Utils:FormatMoney(cA)))

    local aT, aC = NS.Stats:GetAccountTotal(), NS.Stats:GetAccountPickpocketCount()
    local aA = aC > 0 and (aT / aC) or 0
    accSummary:SetText(string.format(
      "Account-Wide:\n%s (%d pickpockets)\nAvg: %s",
      NS.Utils:FormatMoney(aT), aC, NS.Utils:FormatMoney(aA)))
  end
  self.updateBottomStats = UpdateBottomStats

  -- Right: reset buttons
  local rTitle = bp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  rTitle:SetPoint("TOPRIGHT", -12, -8)
  rTitle:SetText("Reset"); rTitle:SetTextColor(1, 0.82, 0)

  MakeResetBtn(bp, "Reset Session", -28,
    { {"Clears current session data.", 0.7, 0.7, 0.7}, {"Lifetime stats preserved.", 0.5, 1, 0.5} },
    function()
      if NS.Tracking then NS.Tracking:ResetSession() end
      if NS.Items then NS.Items:ResetSession() end
      if NS.UI then NS.UI:UpdateDisplay() end
      UpdateBottomStats()
      NS.Utils:PrintWarning("Session reset")
    end)

  MakeResetBtn(bp, "Reset Character", -58,
    { {"Clears THIS character's lifetime stats.", 1, 0.5, 0}, {"Requires confirmation.", 1, 0.3, 0.3} },
    function() StaticPopup_Show("PPT_CONFIRM_RESET_CHARACTER") end)

  MakeResetBtn(bp, "Reset Account", -88,
    { {"Clears ALL characters' stats!", 1, 0, 0}, {"Requires confirmation.", 1, 0.3, 0.3} },
    function() StaticPopup_Show("PPT_CONFIRM_RESET_ACCOUNT") end)

  -- Divider
  local div = bp:CreateTexture(nil, "ARTWORK")
  div:SetWidth(1)
  div:SetPoint("TOP", bp, "TOP", 20, -5)
  div:SetPoint("BOTTOM", bp, "BOTTOM", 20, 5)
  div:SetColorTexture(0.5, 0.5, 0.5, 0.4)

  -- Refresh
  local refresh = CreateFrame("Button", nil, bp, "UIPanelButtonTemplate")
  refresh:SetSize(80, 18)
  refresh:SetPoint("BOTTOMLEFT", 12, 8)
  refresh:SetText("Refresh")
  refresh:SetNormalFontObject("GameFontHighlightSmall")
  refresh:SetScript("OnClick", function() UpdateBottomStats() end)

  self.frame:SetScript("OnShow", function() UpdateBottomStats() end)
end

--------------------------------------------------------------------------------
-- Confirmation Dialogs
--------------------------------------------------------------------------------
function NS.Options:RegisterDialogs()
  local function refreshAll()
    if NS.Options.updateBottomStats then NS.Options.updateBottomStats() end
  end

  StaticPopupDialogs["PPT_CONFIRM_RESET_CHARACTER"] = {
    text = "Reset all lifetime statistics for this character?\n\nThis cannot be undone!",
    button1 = "Reset", button2 = "Cancel",
    OnAccept = function() if NS.Stats then NS.Stats:ResetCharacter(); refreshAll() end end,
    timeout = 0, whileDead = true, hideOnEscape = true,
  }

  StaticPopupDialogs["PPT_CONFIRM_RESET_ACCOUNT"] = {
    text = "Reset ALL lifetime statistics for ALL characters?\n\nThis cannot be undone!",
    button1 = "Reset All", button2 = "Cancel",
    OnAccept = function() if NS.Stats then NS.Stats:ResetAccount(); refreshAll() end end,
    timeout = 0, whileDead = true, hideOnEscape = true,
  }
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------
function NS.Options:Show()
  if not self.frame then self:Initialize() end
  self.frame:Show()
end

function NS.Options:Hide()
  if self.frame then self.frame:Hide() end
end

function NS.Options:Toggle()
  if not self.frame then
    self:Initialize()
    self.frame:Show()
  elseif self.frame:IsShown() then
    self.frame:Hide()
  else
    self.frame:Show()
  end
end
