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

local math_max  = math.max
local math_abs  = math.abs
local ipairs    = ipairs
local table_sort = table.sort
local string_format = string.format

-------------------------------------------------------------------------------
-- Group data into top-X + optional "Other Characters"
-------------------------------------------------------------------------------

--- Sort entries descending by value, keep top maxBars, group the rest.
--- Returns an array of { name, value, extra, isOther }.
local function GroupData(data, maxBars)
  -- Copy and sort descending
  local sorted = {}
  for i = 1, #data do sorted[i] = data[i] end
  table_sort(sorted, function(a, b) return a.value > b.value end)

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
      name    = string_format("Other Characters (%d)", otherCount),
      value   = otherTotal,
      extra   = nil,
      isOther = true,
    }
  end

  return result
end

-------------------------------------------------------------------------------
-- Bar pool
--
-- WoW never frees frames, textures or font strings, so the renderer creates
-- each bar's widgets once per holder and reuses them on every later render.
-- Bars beyond the current data are hidden, not destroyed; the pool only grows
-- to the largest bar count ever shown in that holder.
-------------------------------------------------------------------------------

local function HitOnEnter(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  self.builder(self.entry, self)
  GameTooltip:Show()
end

local function HitOnLeave()
  GameTooltip:Hide()
end

local function AcquireBar(holder, i)
  local pool = holder.pptBars
  if not pool then
    pool = {}
    holder.pptBars = pool
  end

  local b = pool[i]
  if b then return b end

  b = {
    label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"),
    bg    = holder:CreateTexture(nil, "BACKGROUND"),
    fill  = holder:CreateTexture(nil, "ARTWORK"),
    value = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"),
    hit   = CreateFrame("Frame", nil, holder),
  }
  b.label:SetJustifyH("LEFT")
  b.value:SetPoint("LEFT", b.bg, "LEFT", 6, 0)
  b.value:SetTextColor(1, 1, 1)
  b.hit:SetScript("OnEnter", HitOnEnter)
  b.hit:SetScript("OnLeave", HitOnLeave)

  pool[i] = b
  return b
end

local function SetBarShown(b, shown)
  b.label:SetShown(shown)
  b.bg:SetShown(shown)
  b.fill:SetShown(shown)
  b.value:SetShown(shown)
  b.hit:SetShown(shown)
end

local function GetNoDataText(holder)
  local fs = holder.pptNoData
  if not fs then
    fs = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 0, 0)
    fs:SetTextColor(0.7, 0.7, 0.7)
    holder.pptNoData = fs
  end
  return fs
end

-------------------------------------------------------------------------------
-- Render bars into a holder frame
--
-- Reuses the holder's pooled bars, hiding any the data no longer needs.
-- Returns the total height consumed so the caller can resize the holder.
-------------------------------------------------------------------------------

function NS.Chart:Render(holder, config)
  local data    = config.data or {}
  local grouped = #data > 0
    and GroupData(data, config.maxBars or NS.Config.CHART_DEFAULTS.maxBars)
    or {}

  -- Hide pooled bars this render does not use
  local pool = holder.pptBars
  if pool then
    for i = #grouped + 1, #pool do SetBarShown(pool[i], false) end
  end

  local noData = GetNoDataText(holder)
  if #grouped == 0 then
    noData:SetText(config.noDataText or "No data yet.")
    noData:Show()
    holder:SetHeight(20)
    return 20
  end
  noData:Hide()

  local barColor = config.barColor or NS.Config.BAR_COLORS.default
  local bgColor  = NS.Config.BAR_COLORS.bg
  local barH     = NS.Config.CHART_DEFAULTS.barHeight
  local barW     = NS.Config.CHART_DEFAULTS.barWidth
  local spacing  = NS.Config.CHART_DEFAULTS.barSpacing
  local labelH   = NS.Config.CHART_DEFAULTS.labelHeight
  local formatter = config.formatter or tostring
  local builder   = config.tooltipBuilder

  -- Find max value for proportional sizing
  local maxVal = 0
  for _, entry in ipairs(grouped) do
    if entry.value > maxVal then maxVal = entry.value end
  end
  if maxVal <= 0 then maxVal = 1 end

  local y = 0

  for i, entry in ipairs(grouped) do
    local b = AcquireBar(holder, i)

    -- Character name label (above bar)
    b.label:ClearAllPoints()
    b.label:SetPoint("TOPLEFT", 0, y)
    b.label:SetText(entry.name)
    if entry.isOther then
      b.label:SetTextColor(0.7, 0.7, 0.7)
    else
      b.label:SetTextColor(0.9, 0.9, 0.9)
    end
    y = y - labelH

    -- Bar background (full width)
    b.bg:ClearAllPoints()
    b.bg:SetPoint("TOPLEFT", 0, y)
    b.bg:SetSize(barW, barH)
    b.bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])

    -- Filled bar (proportional to max)
    b.fill:ClearAllPoints()
    b.fill:SetPoint("TOPLEFT", 0, y)
    b.fill:SetSize(math_max(2, (entry.value / maxVal) * barW), barH)
    if entry.isOther then
      b.fill:SetColorTexture(0.5, 0.5, 0.5, 0.65)
    else
      b.fill:SetColorTexture(barColor[1], barColor[2], barColor[3], 0.85)
    end

    -- Value label on the bar (anchored to bg once, in AcquireBar)
    b.value:SetText(formatter(entry.value))

    -- Tooltip hit area covering name + bar
    b.hit:ClearAllPoints()
    b.hit:SetPoint("TOPLEFT", 0, y + labelH)
    b.hit:SetSize(barW, barH + labelH)
    b.hit.entry   = entry
    b.hit.builder = builder
    b.hit:EnableMouse(builder ~= nil)

    SetBarShown(b, true)
    y = y - (barH + spacing)
  end

  local totalHeight = math_abs(y) + 5
  holder:SetHeight(totalHeight)
  return totalHeight
end
