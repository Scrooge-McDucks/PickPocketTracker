-------------------------------------------------------------------------------
-- chart.lua — Shared bar chart renderer
--
-- A reusable module that draws horizontal bar charts inside a holder frame.
-- Both the gold earnings graph and the Coin of Air graph use this renderer
-- so there is zero duplicated chart code.
--
-- The renderer is metric-agnostic: callers supply data, colours, and
-- formatting via a configuration table.  No metric-specific logic lives
-- inside this module.
--
-- Config table fields:
--   data           (table)    Array of { name, value, extra } entries
--   maxBars        (number)   Max individual bars; remainder grouped as "Other Characters"
--   barColor       (table)    { r, g, b } 0-1 colour for filled bars
--   formatter      (function) value → display string (e.g. FormatMoney or tostring)
--   noDataText     (string)   Text when data is empty
--   tooltipBuilder (function) Optional (entry, frame) → populate GameTooltip
-------------------------------------------------------------------------------
local _, NS = ...

NS.Chart = {}

-------------------------------------------------------------------------------
-- Group data into top-X + optional "Other Characters"
-------------------------------------------------------------------------------

--- Sort entries descending by value, keep top maxBars, group the rest.
--- Returns an array of { name, value, extra, isOther }.
local function GroupData(data, maxBars)
  -- Copy and sort descending
  local sorted = {}
  for i = 1, #data do sorted[i] = data[i] end
  table.sort(sorted, function(a, b) return a.value > b.value end)

  if #sorted <= maxBars then
    return sorted
  end

  local result = {}
  for i = 1, maxBars do
    result[i] = sorted[i]
  end

  -- Sum remainder into "Other Characters"
  local otherTotal = 0
  local otherCount = 0
  for i = maxBars + 1, #sorted do
    otherTotal = otherTotal + sorted[i].value
    otherCount = otherCount + 1
  end

  if otherCount > 0 then
    result[#result + 1] = {
      name    = string.format("Other Characters (%d)", otherCount),
      value   = otherTotal,
      extra   = nil,
      isOther = true,
    }
  end

  return result
end

-------------------------------------------------------------------------------
-- Render bars into a holder frame
--
-- Clears all previous children/regions of the holder, then draws bars.
-- Returns the total height consumed so the caller can resize the holder.
-------------------------------------------------------------------------------

function NS.Chart:Render(holder, config)
  -- Clear previous content
  for _, child in pairs({ holder:GetChildren() }) do child:Hide() end
  for _, region in pairs({ holder:GetRegions() }) do region:Hide() end

  local data = config.data or {}
  if #data == 0 then
    local noData = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noData:SetPoint("TOPLEFT", 0, 0)
    noData:SetText(config.noDataText or "No data yet.")
    noData:SetTextColor(0.7, 0.7, 0.7)
    holder:SetHeight(20)
    return 20
  end

  local maxBars  = config.maxBars or NS.Config.CHART_DEFAULTS.maxBars
  local grouped  = GroupData(data, maxBars)

  local barColor = config.barColor or NS.Config.BAR_COLORS.default
  local bgColor  = NS.Config.BAR_COLORS.bg
  local barH     = NS.Config.CHART_DEFAULTS.barHeight
  local barW     = NS.Config.CHART_DEFAULTS.barWidth
  local spacing  = NS.Config.CHART_DEFAULTS.barSpacing
  local labelH   = NS.Config.CHART_DEFAULTS.labelHeight
  local formatter = config.formatter or tostring

  -- Find max value for proportional sizing
  local maxVal = 0
  for _, entry in ipairs(grouped) do
    if entry.value > maxVal then maxVal = entry.value end
  end
  if maxVal <= 0 then maxVal = 1 end

  local y = 0

  for _, entry in ipairs(grouped) do
    -- Character name label (above bar)
    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", 0, y)
    label:SetJustifyH("LEFT")
    label:SetText(entry.name)
    if entry.isOther then
      label:SetTextColor(0.7, 0.7, 0.7)
    else
      label:SetTextColor(0.9, 0.9, 0.9)
    end
    y = y - labelH

    -- Bar background (full width)
    local barBg = holder:CreateTexture(nil, "BACKGROUND")
    barBg:SetPoint("TOPLEFT", 0, y)
    barBg:SetSize(barW, barH)
    barBg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])

    -- Filled bar (proportional to max)
    local fillWidth = math.max(2, (entry.value / maxVal) * barW)
    local bar = holder:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", 0, y)
    bar:SetSize(fillWidth, barH)
    if entry.isOther then
      bar:SetColorTexture(0.5, 0.5, 0.5, 0.65)
    else
      bar:SetColorTexture(barColor[1], barColor[2], barColor[3], 0.85)
    end

    -- Value label on the bar
    local valText = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valText:SetPoint("LEFT", barBg, "LEFT", 6, 0)
    valText:SetText(formatter(entry.value))
    valText:SetTextColor(1, 1, 1)

    -- Tooltip hit area covering name + bar
    local hitFrame = CreateFrame("Frame", nil, holder)
    hitFrame:SetPoint("TOPLEFT", 0, y + labelH)
    hitFrame:SetSize(barW, barH + labelH)
    hitFrame:EnableMouse(true)

    if config.tooltipBuilder then
      local tipEntry = entry
      hitFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        config.tooltipBuilder(tipEntry, self)
        GameTooltip:Show()
      end)
      hitFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    y = y - (barH + spacing)
  end

  local totalHeight = math.abs(y) + 5
  holder:SetHeight(totalHeight)
  return totalHeight
end
