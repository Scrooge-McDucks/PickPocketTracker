-- minimap.lua
-- Minimap button for Pick Pocket Tracker.
-- Left-click toggles the gold window. Right-click prints help.
-- Drag to reposition around the minimap.

local _, NS = ...

NS.Minimap = NS.Minimap or {}

local function ensureDB()
  PickPocketTrackerDB = PickPocketTrackerDB or {}
  if PickPocketTrackerDB.minimap == nil then PickPocketTrackerDB.minimap = {} end
  local mm = PickPocketTrackerDB.minimap
  if mm.hide == nil then mm.hide = false end
  if mm.angle == nil then mm.angle = 220 end -- degrees
  if mm.radius == nil then mm.radius = 80 end
  return mm
end

local function posFromAngle(btn, angleDeg, radius)
  local a = math.rad(angleDeg or 0)
  local x = math.cos(a) * (radius or 80)
  local y = math.sin(a) * (radius or 80)
  btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function angleFromCursor(radius)
  local mx, my = Minimap:GetCenter()
  local cx, cy = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  cx, cy = cx / scale, cy / scale
  local dx, dy = cx - mx, cy - my
  local a = math.deg(math.atan2(dy, dx))
  if a < 0 then a = a + 360 end
  return a
end

function NS.Minimap:Create(onToggle)
  if self.button then
    -- update callback and visibility
    self.onToggle = onToggle or self.onToggle
    self:Apply()
    return self.button
  end

  local mm = ensureDB()

  local btn = CreateFrame("Button", "PickPocketTrackerMinimapButton", Minimap)
  btn:SetSize(32, 32)
  btn:SetFrameStrata("MEDIUM")
  btn:SetClampedToScreen(true)

  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:RegisterForDrag("LeftButton")
  btn:SetMovable(true)
  btn:EnableMouse(true)

  -- ring/background
  local bg = btn:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  bg:SetSize(56, 56)
  bg:SetPoint("CENTER", 11, -12)

  -- icon
  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  icon:SetSize(18, 18)
  icon:SetPoint("CENTER", 0, 1)

  btn.icon = icon

  -- tooltip
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Pick Pocket Tracker")
    GameTooltip:AddLine("Left-click: Toggle window", 1, 1, 1)
    GameTooltip:AddLine("Drag: Move icon", 1, 1, 1)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  -- click
  btn:SetScript("OnClick", function(_, button)
    if button == "LeftButton" then
      if NS.Minimap.onToggle then NS.Minimap.onToggle() end
    else
      NS.info("Commands: /pp hide|show, /pp lock|unlock, /pp reset, /pp icon on|off, /pp minimap on|off")
    end
  end)

  -- drag
  btn:SetScript("OnDragStart", function(self)
    if mm.hide then return end
    self.isDragging = true
    self:SetScript("OnUpdate", function()
      local a = angleFromCursor(mm.radius)
      mm.angle = a
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
