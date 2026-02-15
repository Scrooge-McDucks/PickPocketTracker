-------------------------------------------------------------------------------
-- options.lua — Settings panel UI
-- Scrollable settings area with Display checkboxes, Tracking slider, and
-- a character earnings bar graph. Lifetime stats and reset buttons are
-- pinned to the bottom panel outside the scroll region.
-------------------------------------------------------------------------------
local _, NS = ...

NS.Options = {}
NS.Options.frame = nil
NS.Options.updateBottomStats = nil
NS.Options.barGraphFrame = nil

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

local FRAME_WIDTH         = 420
local FRAME_HEIGHT        = 560
local HEADER_HEIGHT       = 50
local BOTTOM_PANEL_HEIGHT = 140
local BOTTOM_MARGIN       = 10

function NS.Options:Initialize()
  if self.frame then return end
  self.frame = self:CreateOptionsFrame()
  self:CreateScrollableContent()
  self:CreateBottomPanel()
end

function NS.Options:CreateOptionsFrame()
  local f = CreateFrame("Frame", "PickPocketTrackerOptionsFrame", UIParent, "BackdropTemplate")
  f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:Hide()

  f:SetBackdrop({
    bgFile  = "Interface/DialogFrame/UI-DialogBox-Background",
    edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
  })

  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(s) s:StartMoving() end)
  f:SetScript("OnDragStop",  function(s) s:StopMovingOrSizing() end)

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
-- Scrollable settings area
--------------------------------------------------------------------------------

function NS.Options:CreateScrollableContent()
  local parent = self.frame

  local scrollTop    = -(HEADER_HEIGHT + 5)
  local scrollBottom = BOTTOM_PANEL_HEIGHT + BOTTOM_MARGIN + 5

  local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT",     12, scrollTop)
  sf:SetPoint("BOTTOMRIGHT", -30, scrollBottom)
  self.scrollFrame = sf

  local scrollBar = sf.ScrollBar
  if scrollBar then
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPLEFT", sf, "TOPRIGHT", 2, -16)
    scrollBar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 2, 16)
  end

  local child = CreateFrame("Frame", nil, sf)
  child:SetWidth(FRAME_WIDTH - 44)
  sf:SetScrollChild(child)
  self.scrollChild = child

  self:PopulateSettings(child)
end

function NS.Options:PopulateSettings(content)
  local y = 0

  ---------------------------------------------------------------------------
  -- Display
  ---------------------------------------------------------------------------
  CreateHeader(content, "Display", y); y = y - 28

  -- graphSection declared early so the checkbox callback can reference it
  local graphSection

  local checks = {
    { "Show Main Window", "Toggle the pickpocket haul window on/off",
      not NS.Data:IsHidden(),
      function(v) NS.Data:SetHidden(not v); NS.UI:UpdateVisibility() end },

    { "Lock Window Position", "Prevent accidental resizing (Shift-drag still moves)",
      NS.Data:IsLocked(),
      function(v) NS.Data:SetLocked(v); NS.UI:OnLockSettingChanged() end },

    { "Show Pickpocket Icon", "Display the pickpocket ability icon in the window",
      NS.Data:ShouldShowIcon(),
      function(v) NS.Data:SetShowIcon(v); NS.UI:OnIconSettingChanged() end },

    { "Show Minimap Button", "Display the minimap button for quick access",
      not NS.Data:IsMinimapHidden(),
      function(v) NS.Data:SetMinimapHidden(not v); if NS.Minimap then NS.Minimap:Apply() end end },

    { "Log Items to Chat", "Show pickpocketed/sold item messages in chat",
      NS.Data:ShouldChatLogItems(),
      function(v) NS.Data:SetChatLogItems(v) end },

    { "Show Character Earnings", "Display a bar graph comparing earnings across all your rogue characters",
      NS.Data:ShouldShowBarGraph(),
      function(v)
        NS.Data:SetShowBarGraph(v)
        if graphSection then
          if v then graphSection:Show() else graphSection:Hide() end
        end
        NS.Options:ResizeScrollChild()
        if v then NS.Options:UpdateBarGraph() end
      end },
  }
  for _, info in ipairs(checks) do
    local cb = CreateCheckbox(content, info[1], info[2], info[3], info[4])
    cb:SetPoint("TOPLEFT", 8, y); y = y - 28
  end
  y = y - 8

  CreateDivider(content, y); y = y - 18

  ---------------------------------------------------------------------------
  -- Tracking
  ---------------------------------------------------------------------------
  CreateHeader(content, "Tracking", y); y = y - 32

  local sliderLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sliderLabel:SetPoint("TOPLEFT", 18, y)
  sliderLabel:SetText(string.format("Detection Window: %.1f seconds", NS.Tracking:GetDetectionWindow()))
  y = y - 22

  local slider = CreateFrame("Slider", "PPTDetectionSlider", content, "OptionsSliderTemplate")
  slider:SetPoint("TOPLEFT", 18, y)
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

  local help = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", 18, y - 25)
  help:SetWidth(350); help:SetJustifyH("LEFT")
  help:SetText("Time after pickpocket cast to count gold/items. Increase if items are missed.")
  help:SetTextColor(0.7, 0.7, 0.7)
  y = y - 55

  ---------------------------------------------------------------------------
  -- Character Earnings Bar Graph (entire section hidden when toggled off)
  ---------------------------------------------------------------------------
  graphSection = CreateFrame("Frame", nil, content)
  graphSection:SetPoint("TOPLEFT", 0, y)
  graphSection:SetSize(380, 10)
  self.graphSection = graphSection

  -- Divider + header inside the section so they hide together
  local gDivider = graphSection:CreateTexture(nil, "ARTWORK")
  gDivider:SetHeight(1)
  gDivider:SetPoint("TOPLEFT", 20, 0)
  gDivider:SetPoint("TOPRIGHT", -20, 0)
  gDivider:SetColorTexture(0.5, 0.5, 0.5, 0.3)

  local gHeader = graphSection:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  gHeader:SetPoint("TOPLEFT", 20, -18)
  gHeader:SetText("Character Earnings")
  gHeader:SetTextColor(1, 0.82, 0)

  local graphHolder = CreateFrame("Frame", nil, graphSection)
  graphHolder:SetPoint("TOPLEFT", 18, -46)
  graphHolder:SetSize(350, 10)
  self.barGraphFrame = graphHolder

  self.graphY = y
  content:SetHeight(math.abs(y) + 250)

  if NS.Data:ShouldShowBarGraph() then
    graphSection:Show()
  else
    graphSection:Hide()
  end
end

--------------------------------------------------------------------------------
-- Bar Graph — shows each character's total earnings
--------------------------------------------------------------------------------

function NS.Options:UpdateBarGraph()
  if not self.barGraphFrame then return end
  if not NS.Data:ShouldShowBarGraph() then return end
  local holder = self.barGraphFrame

  -- Clear previous elements
  for _, child in pairs({ holder:GetChildren() }) do child:Hide() end
  for _, region in pairs({ holder:GetRegions() }) do region:Hide() end

  if not NS.Stats or not PickPocketTrackerAccountDB or not PickPocketTrackerAccountDB.characters then
    return
  end

  -- Gather character data, sorted by total descending
  local chars = {}
  for key, data in pairs(PickPocketTrackerAccountDB.characters) do
    local total = (data.goldLooted or 0) + (data.itemsSold or 0)
    if total > 0 then
      chars[#chars + 1] = {
        key   = key,
        name  = data.name or key,
        class = data.class or "Unknown",
        total = total,
        count = data.pickpocketCount or 0,
      }
    end
  end

  if #chars == 0 then
    local noData = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noData:SetPoint("TOPLEFT", 0, 0)
    noData:SetText("No character data yet.")
    noData:SetTextColor(0.7, 0.7, 0.7)
    holder:SetHeight(20)
    self:ResizeScrollChild()
    return
  end

  table.sort(chars, function(a, b) return a.total > b.total end)

  local maxTotal    = chars[1].total
  local barHeight   = 18
  local barWidth    = 350
  local rogueColor  = NS.Config.BAR_COLORS.rogue
  local bgColor     = NS.Config.BAR_COLORS.bg
  local y           = 0

  for _, char in ipairs(chars) do
    -- Character name label (above bar)
    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", 0, y)
    label:SetJustifyH("LEFT")
    label:SetText(char.name)
    label:SetTextColor(0.9, 0.9, 0.9)
    y = y - 14

    -- Bar background (full width)
    local barBg = holder:CreateTexture(nil, "BACKGROUND")
    barBg:SetPoint("TOPLEFT", 0, y)
    barBg:SetSize(barWidth, barHeight)
    barBg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])

    -- Filled bar (proportional to max)
    local fillWidth = math.max(2, (char.total / maxTotal) * barWidth)
    local bar = holder:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", 0, y)
    bar:SetSize(fillWidth, barHeight)
    bar:SetColorTexture(rogueColor[1], rogueColor[2], rogueColor[3], 0.85)

    -- Value label on the bar
    local valText = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valText:SetPoint("LEFT", barBg, "LEFT", 6, 0)
    valText:SetText(NS.Utils:FormatMoney(char.total))
    valText:SetTextColor(1, 1, 1)

    -- Tooltip hit area covering name + bar
    local hitFrame = CreateFrame("Frame", nil, holder)
    hitFrame:SetPoint("TOPLEFT", 0, y + 14)
    hitFrame:SetSize(barWidth, barHeight + 14)
    hitFrame:EnableMouse(true)

    local tipTotal = char.total
    local tipCount = char.count
    local tipName  = char.name
    hitFrame:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(tipName)
      GameTooltip:AddDoubleLine("Total earned:", NS.Utils:FormatMoney(tipTotal), 1,1,1, 1,1,1)
      GameTooltip:AddDoubleLine("Pickpockets:", tipCount, 1,1,1, 1,1,1)
      if tipCount > 0 then
        GameTooltip:AddDoubleLine("Average:", NS.Utils:FormatMoney(math.floor(tipTotal / tipCount)), 1,1,1, 1,1,1)
      end
      GameTooltip:Show()
    end)
    hitFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    y = y - (barHeight + 8)
  end

  local totalHeight = math.abs(y) + 5
  holder:SetHeight(totalHeight)
  self:ResizeScrollChild()
end

function NS.Options:ResizeScrollChild()
  if not self.scrollChild then return end
  if self.graphSection and self.graphSection:IsShown() and self.barGraphFrame then
    local graphBottom = math.abs(self.graphY) + self.barGraphFrame:GetHeight() + 15
    self.scrollChild:SetHeight(graphBottom)
  else
    -- Graph hidden: just enough for the checkbox below the divider
    self.scrollChild:SetHeight(math.abs(self.graphY) + 30)
  end
end

--------------------------------------------------------------------------------
-- Bottom Panel (Stats + Reset) — fixed at the bottom, not scrolled
--------------------------------------------------------------------------------

function NS.Options:CreateBottomPanel()
  local bp = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
  bp:SetPoint("BOTTOMLEFT",  10, BOTTOM_MARGIN)
  bp:SetPoint("BOTTOMRIGHT", -10, BOTTOM_MARGIN)
  bp:SetHeight(BOTTOM_PANEL_HEIGHT)
  bp:SetFrameLevel(self.frame:GetFrameLevel() + 5)
  bp:SetBackdrop({
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
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

    -- Also refresh the bar graph
    NS.Options:UpdateBarGraph()
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

  -- Vertical divider
  local div = bp:CreateTexture(nil, "ARTWORK")
  div:SetWidth(1)
  div:SetPoint("TOP",    bp, "TOP",    20, -5)
  div:SetPoint("BOTTOM", bp, "BOTTOM", 20,  5)
  div:SetColorTexture(0.5, 0.5, 0.5, 0.4)

  -- Refresh button
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
    text     = "Reset all lifetime statistics for this character?\n\nThis cannot be undone!",
    button1  = "Reset", button2 = "Cancel",
    OnAccept = function() if NS.Stats then NS.Stats:ResetCharacter(); refreshAll() end end,
    timeout  = 0, whileDead = true, hideOnEscape = true,
  }

  StaticPopupDialogs["PPT_CONFIRM_RESET_ACCOUNT"] = {
    text     = "Reset ALL lifetime statistics for ALL characters?\n\nThis cannot be undone!",
    button1  = "Reset All", button2 = "Cancel",
    OnAccept = function() if NS.Stats then NS.Stats:ResetAccount(); refreshAll() end end,
    timeout  = 0, whileDead = true, hideOnEscape = true,
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
