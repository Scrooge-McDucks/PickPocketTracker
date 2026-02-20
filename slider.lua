-------------------------------------------------------------------------------
-- slider.lua — Shared slider factory
--
-- Creates a "Max Characters to Display" slider used by both the gold and
-- Coin of Air bar graphs.  The factory produces one slider per call with
-- its own independent stored value, redraw callback, and visibility
-- predicate.  No slider logic is duplicated between graphs.
--
-- Config table fields:
--   parent      (Frame)    Parent frame to attach slider to
--   label       (string)   Display label (default "Max Characters to Display")
--   min         (number)   Minimum value (default 1)
--   max         (number)   Maximum value (default 10)
--   step        (number)   Step size (default 1)
--   width       (number)   Slider width (default 340)
--   getter      (function) Returns current saved value
--   setter      (function) Called with new value to persist
--   onChange    (function) Called after value change (e.g. redraw graph)
-------------------------------------------------------------------------------
local _, NS = ...

NS.SliderFactory = {}

function NS.SliderFactory:Create(config)
  local parent = config.parent
  local labelText = config.label or "Max Characters to Display"
  local minVal = config.min or NS.Config.CHART_DEFAULTS.minBars
  local maxVal = config.max or NS.Config.CHART_DEFAULTS.maxBarsLimit
  local step   = config.step or 1
  local width  = config.width or 340

  -- Container frame (holds label + slider as a unit)
  local container = CreateFrame("Frame", nil, parent)
  container:SetSize(width, 50)

  -- Label with current value
  local sliderLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sliderLabel:SetPoint("TOPLEFT", 0, 0)

  -- Build slider without deprecated OptionsSliderTemplate
  local slider = CreateFrame("Slider", nil, container, "BackdropTemplate")
  slider:SetSize(width, 17)
  slider:SetOrientation("HORIZONTAL")
  slider:SetPoint("TOPLEFT", 0, -18)
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

  -- Min/max labels
  local low = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  low:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, 3)
  low:SetText(tostring(minVal))

  local high = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  high:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, 3)
  high:SetText(tostring(maxVal))

  -- Read initial value from getter, clamp to range
  local initial = minVal
  if config.getter then
    initial = config.getter()
    initial = math.max(minVal, math.min(maxVal, initial))
  end

  sliderLabel:SetText(string.format("%s: %d", labelText, initial))
  slider:SetValue(initial)

  -- OnValueChanged: persist + redraw
  slider:SetScript("OnValueChanged", function(_, val)
    val = math.floor(val + 0.5)
    val = math.max(minVal, math.min(maxVal, val))
    sliderLabel:SetText(string.format("%s: %d", labelText, val))
    if config.setter then config.setter(val) end
    if config.onChange then config.onChange() end
  end)

  -- Public handles
  container.slider      = slider
  container.sliderLabel = sliderLabel

  return container
end
