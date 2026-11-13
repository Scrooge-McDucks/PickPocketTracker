-------------------------------------------------------------------------------
-- minimap.lua — Minimap button with drag-to-reposition
--
-- Coin icon with a standard tracking-ring border. Left-click opens options,
-- right-click toggles the haul window. Dragging repositions around the
-- outside edge of the minimap; the angle is saved in PickPocketTrackerDB.minimap
-- and the distance is derived from the minimap's current size and shape.
--
-- Uses its own ensureDB() because the minimap frame may be created before
-- PLAYER_LOGIN fires (early TOC load order).
-------------------------------------------------------------------------------
local _, NS = ...

NS.Minimap = NS.Minimap or {}

local math_rad  = math.rad
local math_deg  = math.deg
local math_cos  = math.cos
local math_sin  = math.sin
local math_atan2 = math.atan2
local math_max  = math.max
local math_min  = math.min
local math_sqrt = math.sqrt

--- Safety net: ensure minimap SV subtable exists even before Data:Initialize.
--- References NS.Config.MINIMAP_DEFAULTS as single source of truth.
local function ensureDB()
  PickPocketTrackerDB = PickPocketTrackerDB or {}
  if PickPocketTrackerDB.minimap == nil then PickPocketTrackerDB.minimap = {} end
  local mm = PickPocketTrackerDB.minimap
  local d  = NS.Config.MINIMAP_DEFAULTS
  if mm.hide   == nil then mm.hide   = d.hide end
  if mm.angle  == nil then mm.angle  = d.angle end
  return mm
end

-- Which quadrants of the minimap are rounded, per GetMinimapShape() — the
-- community convention minimap-reshaping addons declare so buttons can follow
-- their outline. Order: upper-left, lower-left, upper-right, lower-right.
local MINIMAP_SHAPES = {
  ["ROUND"]                 = { true,  true,  true,  true  },
  ["SQUARE"]                = { false, false, false, false },
  ["CORNER-TOPLEFT"]        = { true,  false, false, false },
  ["CORNER-TOPRIGHT"]       = { false, false, true,  false },
  ["CORNER-BOTTOMLEFT"]     = { false, true,  false, false },
  ["CORNER-BOTTOMRIGHT"]    = { false, false, false, true  },
  ["SIDE-LEFT"]             = { true,  true,  false, false },
  ["SIDE-RIGHT"]            = { false, false, true,  true  },
  ["SIDE-TOP"]              = { true,  false, true,  false },
  ["SIDE-BOTTOM"]           = { false, true,  false, true  },
  ["TRICORNER-TOPLEFT"]     = { true,  true,  true,  false },
  ["TRICORNER-TOPRIGHT"]    = { true,  false, true,  true  },
  ["TRICORNER-BOTTOMLEFT"]  = { true,  true,  false, true  },
  ["TRICORNER-BOTTOMRIGHT"] = { false, true,  true,  true  },
}

--- Position the button on the outside edge of the minimap at `angleDeg`.
--- The distance comes from the minimap's real size (half its width plus a
--- small offset — the same rule LibDBIcon uses), so the button sits on the
--- rim on every client. In a squared-off quadrant the button follows the
--- straight sides instead of the circle.
local function posFromAngle(btn, angleDeg)
  local a      = math_rad(angleDeg or 0)
  local x, y   = math_cos(a), math_sin(a)
  local d      = NS.Config.MINIMAP_DEFAULTS
  local w = (Minimap:GetWidth()  or 140) / 2 + d.edgeOffset
  local h = (Minimap:GetHeight() or 140) / 2 + d.edgeOffset

  local q = 1
  if y < 0 then q = q + 1 end   -- lower half
  if x > 0 then q = q + 2 end   -- right half
  local shape   = GetMinimapShape and GetMinimapShape() or "ROUND"
  local rounded = (MINIMAP_SHAPES[shape] or MINIMAP_SHAPES.ROUND)[q]

  if rounded then
    x, y = x * w, y * h
  else
    local dw = math_sqrt(2 * w * w) - d.cornerRounding
    local dh = math_sqrt(2 * h * h) - d.cornerRounding
    x = math_max(-w, math_min(x * dw, w))
    y = math_max(-h, math_min(y * dh, h))
  end

  btn:ClearAllPoints()
  btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

--- Calculate angle from minimap centre to cursor position.
local function angleFromCursor()
  local mx, my = Minimap:GetCenter()
  local cx, cy = GetCursorPosition()
  local s = Minimap:GetEffectiveScale()
  return math_deg(math_atan2(cy / s - my, cx / s - mx)) % 360
end

function NS.Minimap:Create(onToggle)
  if self.button then
    self.onToggle = onToggle or self.onToggle
    self:Apply()
    return self.button
  end

  local mm  = ensureDB()
  local btn = CreateFrame("Button", nil, Minimap)
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
      posFromAngle(f, mm.angle)
    end)
  end)
  btn:SetScript("OnDragStop", function(f)
    f:SetScript("OnUpdate", nil)
  end)

  self.button   = btn
  self.onToggle = onToggle
  posFromAngle(btn, mm.angle)
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
    posFromAngle(self.button, mm.angle)
  end
end

-- Aliases used by commands.lua
NS.Minimap.UpdateVisibility = NS.Minimap.Apply
NS.Minimap.UpdatePosition   = NS.Minimap.Apply
