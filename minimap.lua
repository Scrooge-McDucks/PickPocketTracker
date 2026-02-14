-- Minimap button
local _, NS = ...

NS.Minimap = NS.Minimap or {}

local function ensureDB()
  PickPocketTrackerDB = PickPocketTrackerDB or {}
  if PickPocketTrackerDB.minimap == nil then PickPocketTrackerDB.minimap = {} end
  local mm = PickPocketTrackerDB.minimap
  if mm.hide == nil then mm.hide = false end
  if mm.angle == nil then mm.angle = 220 end
  if mm.radius == nil then mm.radius = 80 end
  return mm
end

local function posFromAngle(btn, angleDeg, radius)
  local a = math.rad(angleDeg or 0)
  local x = math.cos(a) * (radius or 80)
  local y = math.sin(a) * (radius or 80)
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function angleFromCursor()
  local mx, my = Minimap:GetCenter()
  local cx, cy = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  cx, cy = cx / scale, cy / scale
  return math.deg(math.atan2(cy - my, cx - mx)) % 360
end

function NS.Minimap:Create(onToggle)
  if self.button then
    self.onToggle = onToggle or self.onToggle
    self:Apply()
    return self.button
  end

  local mm = ensureDB()

  local btn = CreateFrame("Button", "PickPocketTrackerMinimapButton", Minimap)
  btn:SetSize(31, 31)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel(8)
  btn:SetClampedToScreen(true)
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:RegisterForDrag("LeftButton")
  btn:SetMovable(true)
  btn:EnableMouse(true)

  -- Icon (sits inside the ring)
  local icon = btn:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
  icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
  icon:SetPoint("TOPLEFT", 7, -5)
  btn.icon = icon

  -- Border ring (MiniMap-TrackingBorder is designed to anchor at TOPLEFT of a ~31px button)
  local border = btn:CreateTexture(nil, "OVERLAY")
  border:SetSize(56, 56)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetPoint("TOPLEFT", 0, 0)

  -- Highlight
  local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetSize(24, 24)
  highlight:SetPoint("TOPLEFT", 5, -3)
  highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  -- Tooltip
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Pick Pocket Tracker")
    GameTooltip:AddLine("Left-click: Options", 1, 1, 1)
    GameTooltip:AddLine("Right-click: Toggle window", 1, 1, 1)
    GameTooltip:AddLine("Drag: Move icon", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Click
  btn:SetScript("OnClick", function(_, button)
    if button == "LeftButton" then
      if NS.Options then NS.Options:Toggle() end
    else
      if NS.Minimap.onToggle then NS.Minimap.onToggle() end
    end
  end)

  -- Drag
  btn:SetScript("OnDragStart", function(self)
    if mm.hide then return end
    self.isDragging = true
    self:SetScript("OnUpdate", function()
      mm.angle = angleFromCursor()
      posFromAngle(self, mm.angle, mm.radius)
    end)
  end)

  btn:SetScript("OnDragStop", function(self)
    self.isDragging = false
    self:SetScript("OnUpdate", nil)
  end)

  self.button = btn
  self.onToggle = onToggle
  posFromAngle(btn, mm.angle, mm.radius)
  self:Apply()
  return btn
end

function NS.Minimap:Apply()
  local mm = ensureDB()
  if not self.button then return end
  if mm.hide then
    self.button:Hide()
  else
    self.button:Show()
    posFromAngle(self.button, mm.angle, mm.radius)
  end
end

NS.Minimap.UpdateVisibility = NS.Minimap.Apply
NS.Minimap.UpdatePosition = NS.Minimap.Apply
