-------------------------------------------------------------------------------
-- options.lua — Settings panel UI
-- Scrollable settings area with Display checkboxes, Tracking slider, and
-- per-metric bar graphs via the shared chart renderer + slider factory.
-- Lifetime stats and reset buttons are pinned to the bottom panel outside
-- the scroll region.
-------------------------------------------------------------------------------
local _, NS = ...

NS.Options = {}
NS.Options.frame = nil
NS.Options.updateBottomStats = nil
NS.Options.checkboxes = {}        -- stored refs for OnShow refresh
NS.Options.detectionSlider = nil  -- detection window slider ref
NS.Options.detectionLabel  = nil  -- detection window label ref
NS.Options.coinIconCb      = nil  -- coin icon checkbox ref

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

--- Build a slider without the deprecated OptionsSliderTemplate.
--- Returns: slider, lowText, highText (all nil-named, no globals).
local function CreateSlider(parent, minVal, maxVal, step, width)
  local slider = CreateFrame("Slider", nil, parent, "BackdropTemplate")
  slider:SetSize(width or 340, 17)
  slider:SetOrientation("HORIZONTAL")
  slider:SetBackdrop({
    bgFile   = "Interface/Buttons/UI-SliderBar-Background",
    edgeFile = "Interface/Buttons/UI-SliderBar-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 },
  })
  slider:SetThumbTexture("Interface/Buttons/UI-SliderBar-Button-Horizontal")
  slider:SetMinMaxValues(minVal, maxVal)
  slider:SetValueStep(step)
  slider:SetObeyStepOnDrag(true)
  slider:EnableMouseWheel(true)
  slider:SetScript("OnMouseWheel", function(self, delta)
    local val = self:GetValue() + (delta > 0 and step or -step)
    val = math.max(minVal, math.min(maxVal, val))
    self:SetValue(val)
  end)

  local low = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  low:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, 3)

  local high = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  high:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, 3)

  return slider, low, high
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

  -- Sections declared early so checkbox callbacks can reference them
  local graphSection
  local coinSection

  local checks = {
    { "Show Main Window", "Toggle the pickpocket haul window on/off",
      function() return not NS.Data:IsHidden() end,
      function(v) NS.Data:SetHidden(not v); NS.UI:UpdateVisibility() end },

    { "Lock Window Position", "Prevent accidental resizing",
      function() return NS.Data:IsLocked() end,
      function(v) NS.Data:SetLocked(v); NS.UI:OnLockSettingChanged() end },

    { "Show Pickpocket Icon", "Display the pickpocket ability icon in the window",
      function() return NS.Data:ShouldShowIcon() end,
      function(v) NS.Data:SetShowIcon(v); NS.UI:OnIconSettingChanged() end },

    { "Show Minimap Button", "Display the minimap button for quick access",
      function() return not NS.Data:IsMinimapHidden() end,
      function(v) NS.Data:SetMinimapHidden(not v); if NS.Minimap then NS.Minimap:Apply() end end },

    { "Log Items to Chat", "Show pickpocketed/sold item messages in chat",
      function() return NS.Data:ShouldChatLogItems() end,
      function(v) NS.Data:SetChatLogItems(v) end },

    { "Auto-sell Fence Items", "Automatically sell tracked pickpocket items when opening a vendor",
      function() return NS.Data:ShouldAutoSell() end,
      function(v) NS.Data:SetAutoSell(v) end },

    { "Show Character Graphs", "Show bar graphs comparing earnings and coins across all your rogue characters",
      function() return NS.Data:ShouldShowBarGraph() end,
      function(v)
        NS.Data:SetShowBarGraph(v)
        if graphSection then
          if v then graphSection:Show() else graphSection:Hide() end
        end
        -- Also show/hide coin graph parts inside coin section
        if self.coinSlider then
          if v then self.coinSlider:Show() else self.coinSlider:Hide() end
        end
        if self.coinGraphHolder then
          if v then self.coinGraphHolder:Show() else self.coinGraphHolder:Hide() end
        end
        NS.Options:ResizeScrollChild()
        if v then
          NS.Options:UpdateGoldGraph()
          NS.Options:UpdateCoinGraph()
        end
      end },

    { "Track Coins of Air", "Track Coins of Air currency gained from pickpocketing",
      function() return NS.Data:ShouldTrackCoins() end,
      function(v)
        NS.Data:SetTrackCoins(v)
        if NS.Coins then NS.Coins:UpdateVisibility() end
        if coinSection then
          if v then coinSection:Show() else coinSection:Hide() end
        end
        NS.Options:ResizeScrollChild()
        if v then NS.Options:UpdateCoinGraph() end
      end },
  }
  self.checkboxes = {}
  for _, info in ipairs(checks) do
    local cb = CreateCheckbox(content, info[1], info[2], info[3](), info[4])
    cb.getter = info[3]  -- store getter for OnShow refresh
    cb:SetPoint("TOPLEFT", 8, y); y = y - 28
    self.checkboxes[#self.checkboxes + 1] = cb
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
  self.detectionLabel = sliderLabel

  -- Reset to default button
  local resetBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
  resetBtn:SetSize(60, 18)
  resetBtn:SetPoint("LEFT", sliderLabel, "RIGHT", 8, 0)
  resetBtn:SetText("Default")
  resetBtn:SetNormalFontObject("GameFontHighlightSmall")
  resetBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(string.format("Reset to %.1fs", NS.Config.DEFAULT_WINDOW_SECONDS), 1, 1, 1)
    GameTooltip:Show()
  end)
  resetBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  y = y - 22

  local slider, sliderLow, sliderHigh = CreateSlider(content, 0.1, 10.0, 0.1, 340)
  slider:SetPoint("TOPLEFT", 18, y)
  slider:SetValue(NS.Tracking:GetDetectionWindow())
  sliderLow:SetText("0.1s"); sliderHigh:SetText("10.0s")
  slider:SetScript("OnValueChanged", function(_, val)
    val = math.floor(val * 10 + 0.5) / 10
    sliderLabel:SetText(string.format("Detection Window: %.1f seconds", val))
    NS.Tracking:SetDetectionWindow(val)
  end)
  self.detectionSlider = slider

  resetBtn:SetScript("OnClick", function()
    local def = NS.Config.DEFAULT_WINDOW_SECONDS
    slider:SetValue(def)  -- triggers OnValueChanged which updates label + persists
  end)

  local help = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", 18, y - 25)
  help:SetWidth(350); help:SetJustifyH("LEFT")
  help:SetText("Time after pickpocket cast to count gold/items. Increase if items are missed.")
  help:SetTextColor(0.7, 0.7, 0.7)
  y = y - 55

  ---------------------------------------------------------------------------
  -- Character Earnings Bar Graph section
  ---------------------------------------------------------------------------
  graphSection = CreateFrame("Frame", nil, content)
  graphSection:SetPoint("TOPLEFT", 0, y)
  graphSection:SetSize(380, 10)
  self.graphSection = graphSection

  -- Divider + header
  local gDivider = graphSection:CreateTexture(nil, "ARTWORK")
  gDivider:SetHeight(1)
  gDivider:SetPoint("TOPLEFT", 20, 0)
  gDivider:SetPoint("TOPRIGHT", -20, 0)
  gDivider:SetColorTexture(0.5, 0.5, 0.5, 0.3)

  local gHeader = graphSection:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  gHeader:SetPoint("TOPLEFT", 20, -18)
  gHeader:SetText("Character Earnings")
  gHeader:SetTextColor(1, 0.82, 0)

  -- Slider: Max Characters (gold graph) — shared slider factory
  local goldSlider = NS.SliderFactory:Create({
    parent   = graphSection,
    label    = "Max Characters to Display",
    getter   = function() return NS.Data:GetMaxGoldBars() end,
    setter   = function(v) NS.Data:SetMaxGoldBars(v) end,
    onChange = function() NS.Options:UpdateGoldGraph(); NS.Options:ResizeScrollChild() end,
  })
  goldSlider:SetPoint("TOPLEFT", 18, -44)
  self.goldSlider = goldSlider

  -- Graph holder
  local goldGraphHolder = CreateFrame("Frame", nil, graphSection)
  goldGraphHolder:SetPoint("TOPLEFT", 18, -100)
  goldGraphHolder:SetSize(350, 10)
  self.goldGraphHolder = goldGraphHolder

  self.graphY = y

  if NS.Data:ShouldShowBarGraph() then
    graphSection:Show()
  else
    graphSection:Hide()
  end

  ---------------------------------------------------------------------------
  -- Coins of Air section
  ---------------------------------------------------------------------------
  coinSection = CreateFrame("Frame", nil, content)
  coinSection:SetSize(380, 10)
  self.coinSection = coinSection

  local cDivider = coinSection:CreateTexture(nil, "ARTWORK")
  cDivider:SetHeight(1)
  cDivider:SetPoint("TOPLEFT", 20, 0)
  cDivider:SetPoint("TOPRIGHT", -20, 0)
  cDivider:SetColorTexture(0.5, 0.5, 0.5, 0.3)

  local cHeader = coinSection:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  cHeader:SetPoint("TOPLEFT", 20, -18)
  cHeader:SetText("Coins of Air")
  cHeader:SetTextColor(1, 0.82, 0)

  -- Icon toggle checkbox
  local coinIconCb = CreateCheckbox(coinSection, "Show Coin Icon",
    "Show or hide the Coin of Air icon in the tracking window",
    NS.Data:ShouldShowCoinIcon(),
    function(v)
      NS.Data:SetShowCoinIcon(v)
      if NS.Coins then NS.Coins:OnIconSettingChanged() end
    end)
  coinIconCb:SetPoint("TOPLEFT", 8, -38)
  self.coinIconCb = coinIconCb

  -- Coin stats text
  local coinStatsFrame = CreateFrame("Frame", nil, coinSection)
  coinStatsFrame:SetPoint("TOPLEFT", 18, -66)
  coinStatsFrame:SetSize(350, 60)
  self.coinStatsFrame = coinStatsFrame

  local function MakeCoinLine(parent, yy, label)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", 0, yy)
    lbl:SetText(label)
    lbl:SetTextColor(0.7, 0.7, 0.7)
    local val = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val:SetPoint("TOPRIGHT", 0, yy)
    val:SetJustifyH("RIGHT")
    return val, lbl
  end

  self.coinStatValues = {}
  local cy = 0
  self.coinStatValues.session, _ = MakeCoinLine(coinStatsFrame, cy, "Session:")
  cy = cy - 16
  self.coinStatValues.charLife, _ = MakeCoinLine(coinStatsFrame, cy, "Character (lifetime):")
  cy = cy - 16
  self.coinStatValues.accLife, _ = MakeCoinLine(coinStatsFrame, cy, "Account (lifetime):")
  cy = cy - 16
  self.coinStatValues.held, _ = MakeCoinLine(coinStatsFrame, cy, "Currently held:")

  coinStatsFrame:SetHeight(math.abs(cy) + 10)

  -- Slider: Max Characters (coin graph) — shared slider factory
  local coinSlider = NS.SliderFactory:Create({
    parent   = coinSection,
    label    = "Max Characters to Display",
    getter   = function() return NS.Data:GetMaxCoinBars() end,
    setter   = function(v) NS.Data:SetMaxCoinBars(v) end,
    onChange = function() NS.Options:UpdateCoinGraph(); NS.Options:ResizeScrollChild() end,
  })
  coinSlider:SetPoint("TOPLEFT", 18, -(66 + math.abs(cy) + 20))
  self.coinSlider = coinSlider

  -- Coin graph holder
  local coinGraphHolder = CreateFrame("Frame", nil, coinSection)
  coinGraphHolder:SetPoint("TOPLEFT", 18, -(66 + math.abs(cy) + 76))
  coinGraphHolder:SetSize(350, 10)
  self.coinGraphHolder = coinGraphHolder

  -- Will be positioned dynamically by ResizeScrollChild
  coinSection:SetPoint("TOPLEFT", 0, 0)

  if NS.Data:ShouldTrackCoins() then
    coinSection:Show()
  else
    coinSection:Hide()
  end

  -- Coin graph parts follow the shared "Show Character Graphs" toggle
  if NS.Data:ShouldShowBarGraph() then
    coinSlider:Show(); coinGraphHolder:Show()
  else
    coinSlider:Hide(); coinGraphHolder:Hide()
  end

  content:SetHeight(math.abs(y) + 500)
end

--------------------------------------------------------------------------------
-- Refresh all controls to match current data state
-- Called on OnShow so checkboxes, sliders, and sections stay in sync
-- with changes made via slash commands while the panel was closed.
--------------------------------------------------------------------------------

function NS.Options:RefreshControls()
  -- Main checkboxes
  for _, cb in ipairs(self.checkboxes or {}) do
    if cb.getter then cb:SetChecked(cb.getter()) end
  end

  -- Coin icon checkbox
  if self.coinIconCb then
    self.coinIconCb:SetChecked(NS.Data:ShouldShowCoinIcon())
  end

  -- Detection window slider + label
  if self.detectionSlider and self.detectionLabel then
    local val = NS.Tracking:GetDetectionWindow()
    self.detectionSlider:SetValue(val)
    self.detectionLabel:SetText(string.format("Detection Window: %.1f seconds", val))
  end

  -- Graph section visibility
  local showGraphs = NS.Data:ShouldShowBarGraph()
  if self.graphSection then
    if showGraphs then self.graphSection:Show() else self.graphSection:Hide() end
  end
  -- Coin graph parts also follow the graphs toggle
  if self.coinSlider then
    if showGraphs then self.coinSlider:Show() else self.coinSlider:Hide() end
  end
  if self.coinGraphHolder then
    if showGraphs then self.coinGraphHolder:Show() else self.coinGraphHolder:Hide() end
  end
  -- Coin section visibility
  if self.coinSection then
    if NS.Data:ShouldTrackCoins() then self.coinSection:Show() else self.coinSection:Hide() end
  end
end

--------------------------------------------------------------------------------
-- Gold Earnings Bar Graph — uses shared chart renderer
--------------------------------------------------------------------------------

function NS.Options:UpdateGoldGraph()
  if not self.goldGraphHolder then return end
  if not NS.Data:ShouldShowBarGraph() then return end

  if not NS.Stats or not PickPocketTrackerAccountDB or not PickPocketTrackerAccountDB.characters then
    return
  end

  -- Gather character data
  local data = {}
  for key, charInfo in pairs(PickPocketTrackerAccountDB.characters) do
    local total = (charInfo.goldLooted or 0) + (charInfo.itemsSold or 0)
    if total > 0 then
      data[#data + 1] = {
        name  = charInfo.name or key,
        value = total,
        extra = { count = charInfo.pickpocketCount or 0 },
      }
    end
  end

  NS.Chart:Render(self.goldGraphHolder, {
    data       = data,
    maxBars    = NS.Data:GetMaxGoldBars(),
    barColor   = NS.Config.BAR_COLORS.rogue,
    formatter  = function(v) return NS.Utils:FormatMoney(v) end,
    noDataText = "No character data yet.",
    tooltipBuilder = function(entry)
      GameTooltip:AddLine(entry.name)
      GameTooltip:AddDoubleLine("Total earned:", NS.Utils:FormatMoney(entry.value), 1,1,1, 1,1,1)
      if entry.extra and entry.extra.count then
        GameTooltip:AddDoubleLine("Pickpockets:", entry.extra.count, 1,1,1, 1,1,1)
        if entry.extra.count > 0 then
          GameTooltip:AddDoubleLine("Average:", NS.Utils:FormatMoney(math.floor(entry.value / entry.extra.count)), 1,1,1, 1,1,1)
        end
      end
    end,
  })
end

--------------------------------------------------------------------------------
-- Coin of Air Bar Graph — uses shared chart renderer
--------------------------------------------------------------------------------

function NS.Options:UpdateCoinGraph()
  if not self.coinGraphHolder then return end
  if not NS.Data:ShouldTrackCoins() then return end
  if not NS.Data:ShouldShowBarGraph() then return end

  if not NS.Stats or not PickPocketTrackerAccountDB or not PickPocketTrackerAccountDB.characters then
    return
  end

  -- Gather character coin data
  local data = {}
  for key, charInfo in pairs(PickPocketTrackerAccountDB.characters) do
    local coins = charInfo.coinsOfAir or 0
    if coins > 0 then
      data[#data + 1] = {
        name  = charInfo.name or key,
        value = coins,
        extra = { count = charInfo.pickpocketCount or 0 },
      }
    end
  end

  NS.Chart:Render(self.coinGraphHolder, {
    data       = data,
    maxBars    = NS.Data:GetMaxCoinBars(),
    barColor   = NS.Config.BAR_COLORS.monk,
    formatter  = function(v) return tostring(v) end,
    noDataText = "No Coin of Air data yet.",
    tooltipBuilder = function(entry)
      GameTooltip:AddLine(entry.name)
      GameTooltip:AddDoubleLine("Coins of Air:", entry.value, 1,1,1, 1,1,1)
      if entry.extra and entry.extra.count and entry.extra.count > 0 then
        GameTooltip:AddDoubleLine("Pickpockets:", entry.extra.count, 1,1,1, 1,1,1)
      end
    end,
  })
end

--------------------------------------------------------------------------------
-- Scroll child sizing — stacks graph and coin sections dynamically
--------------------------------------------------------------------------------

function NS.Options:ResizeScrollChild()
  if not self.scrollChild then return end

  -- graphY is the negative Y offset where the graph section starts
  local bottom = math.abs(self.graphY)

  -- Graph section: anchored at graphY
  if self.graphSection then
    self.graphSection:ClearAllPoints()
    self.graphSection:SetPoint("TOPLEFT", 0, self.graphY)

    if self.graphSection:IsShown() and self.goldGraphHolder then
      -- slider (50) + gap (6) + graph height + section header (46)
      bottom = bottom + self.goldGraphHolder:GetHeight() + 106
    end
  end

  -- Coin section: stacks below graph (or directly below tracking if graph hidden)
  if self.coinSection then
    self.coinSection:ClearAllPoints()
    self.coinSection:SetPoint("TOPLEFT", 0, -bottom)

    if self.coinSection:IsShown() then
      local statsH = self.coinStatsFrame and self.coinStatsFrame:GetHeight() or 60
      -- Always include header + checkboxes + stats
      bottom = bottom + statsH + 100

      -- Only add coin graph height if it's visible
      if self.coinGraphHolder and self.coinGraphHolder:IsShown() then
        local coinGraphH = self.coinGraphHolder:GetHeight() or 10
        bottom = bottom + coinGraphH + 80
      end
    end
  end

  self.scrollChild:SetHeight(bottom + 20)
end

function NS.Options:UpdateCoinStats()
  if not self.coinStatValues then return end
  local v = self.coinStatValues

  local session   = NS.Coins and NS.Coins:GetSessionCount() or 0
  local charCoins = NS.Stats and NS.Stats:GetCharacterCoins() or 0
  local accCoins  = NS.Stats and NS.Stats:GetAccountCoins() or 0

  -- Get current held count via C_CurrencyInfo
  local held = 0
  if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
    local info = C_CurrencyInfo.GetCurrencyInfo(NS.Config.COINS_OF_AIR_ID)
    held = info and info.quantity or 0
  end

  v.session:SetText(tostring(session))
  v.charLife:SetText(tostring(charCoins))
  v.accLife:SetText(tostring(accCoins))
  v.held:SetText(tostring(held))
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

    -- Refresh graphs, coin stats, then resize once (not per-graph)
    NS.Options:UpdateGoldGraph()
    NS.Options:UpdateCoinGraph()
    NS.Options:UpdateCoinStats()
    NS.Options:ResizeScrollChild()
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
      if NS.Coins then NS.Coins:ResetSession() end
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

  self.frame:SetScript("OnShow", function()
    NS.Options:RefreshControls()
    UpdateBottomStats()
  end)
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

--------------------------------------------------------------------------------
-- Blizzard Add-On Options Registration
-- Registers a simple panel in the Blizzard Settings UI (Game Menu → AddOns)
-- containing a single button that opens the main PickPocketTracker window.
-- Registered for all characters so the entry is always visible in the list.
--------------------------------------------------------------------------------

function NS.Options:RegisterBlizzardOptions()
  local panel = CreateFrame("Frame")
  panel.name = "Pick Pocket Tracker"

  -- Title
  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Pick Pocket Tracker")
  title:SetTextColor(1, 0.82, 0)

  local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  subtitle:SetText("v" .. NS.Config.VERSION .. "  •  Track your pickpocket gold and items")
  subtitle:SetTextColor(0.7, 0.7, 0.7)

  -- Divider
  local divider = panel:CreateTexture(nil, "ARTWORK")
  divider:SetHeight(1)
  divider:SetPoint("TOPLEFT",  subtitle, "BOTTOMLEFT",  0, -12)
  divider:SetPoint("TOPRIGHT", panel,    "TOPRIGHT",   -16, 0)
  divider:SetColorTexture(0.5, 0.5, 0.5, 0.4)

  -- Open button
  local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  btn:SetSize(220, 30)
  btn:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -20)
  btn:SetText("Open Pick Pocket Tracker")
  btn:SetScript("OnClick", function()
    -- Dismiss the Settings panel first so the main window isn't hidden behind it
    if SettingsPanel and SettingsPanel:IsShown() then
      HideUIPanel(SettingsPanel)
    end
    NS.Options:Show()
  end)

  -- Hint line
  local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 4, -8)
  hint:SetText("You can also type |cffffd700/pp|r or click the minimap button.")
  hint:SetTextColor(0.6, 0.6, 0.6)

  -- Register with the modern Settings API (10.0 / War Within+)
  local category = Settings.RegisterCanvasLayoutCategory(panel, "Pick Pocket Tracker")
  category.ID = "PickPocketTracker"
  Settings.RegisterAddOnCategory(category)

  self.blizzardCategory = category
end
