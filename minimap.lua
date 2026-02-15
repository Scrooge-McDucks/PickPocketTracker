-------------------------------------------------------------------------------
-- minimap.lua — Minimap button with drag-to-reposition
--
-- Coin icon with a standard tracking-ring border. Left-click opens options,
-- right-click toggles the haul window. Dragging repositions around the
-- minimap edge using polar coordinates saved in PickPocketTrackerDB.minimap.
--
-- Uses its own ensureDB() because the minimap frame may be created before
-- PLAYER_LOGIN fires (early TOC load order).
-------------------------------------------------------------------------------
local _, NS = ...

NS.Minimap = NS.Minimap or {}

--- Safety net: ensure minimap SV subtable exists even before Data:Initialize.
local function ensureDB()
  PickPocketTrackerDB = PickPocketTrackerDB or {}
  if PickPocketTrackerDB.minimap == nil then PickPocketTrackerDB.minimap = {} end
  local mm = PickPocketTrackerDB.minimap
  if mm.hide   == nil then mm.hide   = false end
  if mm.angle  == nil then mm.angle  = 220 end
  if mm.radius == nil then mm.radius = 80 end
  return mm
end

--- Position button around minimap edge using polar coordinates.
local function posFromAngle(btn, angleDeg, radius)
  local a = math.rad(angleDeg or 0)
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", Minimap, "CENTER",
    math.cos(a) * (radius or 80),
    math.sin(a) * (radius or 80))
end

--- Calculate angle from minimap centre to cursor position.
local function angleFromCursor()
  local mx, my = Minimap:GetCenter()
  local cx, cy = GetCursorPosition()
  local s = Minimap:GetEffectiveScale()
  return math.deg(math.atan2(cy / s - my, cx / s - mx)) % 360
end

function NS.Minimap:Create(onToggle)
  if self.button then
    self.onToggle = onToggle or self.onToggle
    self:Apply()
    return self.button
  end

  local mm  = ensureDB()
  local btn = CreateFrame("Button", "PickPocketTrackerMinimapButton", Minimap)
  btn:SetSize(31, 31)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel(8)
  btn:SetClampedToScreen(true)
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:RegisterForDrag("LeftButton")
  btn:SetMovable(true)
  btn:EnableMouse(true)

  -- Coin icon (sits inside the ring)
  local icon = btn:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
  icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
  icon:SetPoint("TOPLEFT", 7, -5)
  icon:SetAlpha(0.8)
  btn.icon = icon

  -- Standard tracking-ring border (TOPLEFT anchor per WoW convention)
  local border = btn:CreateTexture(nil, "OVERLAY")
  border:SetSize(54, 54)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetPoint("TOPLEFT", 0, 0)

  -- Hover: brighten icon + show tooltip
  btn:SetScript("OnEnter", function(f)
    f.icon:SetAlpha(1.0)
    GameTooltip:SetOwner(f, "ANCHOR_LEFT")
    GameTooltip:AddLine("Pick Pocket Tracker")
    GameTooltip:AddLine("Left-click: Options", 1, 1, 1)
    GameTooltip:AddLine("Right-click: Toggle window", 1, 1, 1)
    GameTooltip:AddLine("Drag: Move icon", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function(f)
    f.icon:SetAlpha(0.8)
    GameTooltip:Hide()
  end)

  -- Click
  btn:SetScript("OnClick", function(_, button)
    if button == "LeftButton" then
      if NS.Options then NS.Options:Toggle() end
    else
      if NS.Minimap.onToggle then NS.Minimap.onToggle() end
    end
  end)

  -- Drag around minimap edge
  btn:SetScript("OnDragStart", function(f)
    if mm.hide then return end
    f:SetScript("OnUpdate", function()
      mm.angle = angleFromCursor()
      posFromAngle(f, mm.angle, mm.radius)
    end)
  end)
  btn:SetScript("OnDragStop", function(f)
    f:SetScript("OnUpdate", nil)
  end)

  self.button   = btn
  self.onToggle = onToggle
  posFromAngle(btn, mm.angle, mm.radius)
  self:Apply()
  return btn
end

--- Show or hide the button and snap to saved position.
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

-- Aliases used by commands.lua
NS.Minimap.UpdateVisibility = NS.Minimap.Apply
NS.Minimap.UpdatePosition   = NS.Minimap.Apply
