-- Data management and SavedVariables
local _, NS = ...

NS.Data = {}

function NS.Data:Initialize()
  PickPocketTrackerDB = PickPocketTrackerDB or {}
  
  self:InitializeUI()
  self:InitializeMinimap()
  self:InitializeItems()
  
  self.db = PickPocketTrackerDB
end

function NS.Data:InitializeUI()
  local db = PickPocketTrackerDB
  local defaults = NS.Config.UI_DEFAULTS
  
  if db.hidden == nil then db.hidden = defaults.hidden end
  if db.locked == nil then db.locked = defaults.locked end
  if db.showIcon == nil then db.showIcon = defaults.showIcon end
  
  if db.point == nil then db.point = defaults.point end
  if db.relativePoint == nil then db.relativePoint = defaults.relativePoint end
  if db.offsetX == nil then db.offsetX = defaults.offsetX end
  if db.offsetY == nil then db.offsetY = defaults.offsetY end
  
  if db.width == nil then db.width = defaults.width end
  if db.height == nil then db.height = defaults.height end
end

function NS.Data:InitializeMinimap()
  local db = PickPocketTrackerDB
  local defaults = NS.Config.MINIMAP_DEFAULTS
  
  if db.minimap == nil then db.minimap = {} end
  
  local mm = db.minimap
  if mm.hide == nil then mm.hide = defaults.hide end
  if mm.angle == nil then mm.angle = defaults.angle end
  if mm.radius == nil then mm.radius = defaults.radius end
end

function NS.Data:InitializeItems()
  local db = PickPocketTrackerDB
  if db.items == nil then db.items = {} end
end

-- UI getters
function NS.Data:IsHidden()
  return self.db.hidden
end

function NS.Data:IsLocked()
  return self.db.locked
end

function NS.Data:ShouldShowIcon()
  return self.db.showIcon
end

function NS.Data:GetWindowPosition()
  return self.db.point, self.db.relativePoint, self.db.offsetX, self.db.offsetY
end

function NS.Data:GetWindowSize()
  return self.db.width, self.db.height
end

-- UI setters
function NS.Data:SetHidden(hidden)
  self.db.hidden = hidden
end

function NS.Data:SetLocked(locked)
  self.db.locked = locked
end

function NS.Data:SetShowIcon(show)
  self.db.showIcon = show
end

function NS.Data:SetWindowPosition(point, relPoint, x, y)
  self.db.point = point
  self.db.relativePoint = relPoint
  self.db.offsetX = math.floor(x + 0.5)
  self.db.offsetY = math.floor(y + 0.5)
end

function NS.Data:SetWindowSize(width, height)
  local defaults = NS.Config.UI_DEFAULTS
  width = math.max(defaults.minWidth, math.min(defaults.maxWidth, width))
  height = math.max(defaults.minHeight, math.min(defaults.maxHeight, height))
  
  self.db.width = math.floor(width + 0.5)
  self.db.height = math.floor(height + 0.5)
end

-- Minimap getters
function NS.Data:GetMinimapSettings()
  return self.db.minimap
end

function NS.Data:IsMinimapHidden()
  return self.db.minimap.hide
end

function NS.Data:GetMinimapPosition()
  return self.db.minimap.angle, self.db.minimap.radius
end

-- Minimap setters
function NS.Data:SetMinimapHidden(hidden)
  self.db.minimap.hide = hidden
end

function NS.Data:SetMinimapPosition(angle, radius)
  self.db.minimap.angle = angle
  self.db.minimap.radius = radius
end

function NS.Data:ResetMinimapPosition()
  local defaults = NS.Config.MINIMAP_DEFAULTS
  self.db.minimap.angle = defaults.angle
  self.db.minimap.radius = defaults.radius
end

-- Item data access
function NS.Data:GetItems()
  return self.db.items
end

function NS.Data:GetItem(itemID)
  return self.db.items[itemID]
end

function NS.Data:SetItem(itemID, itemData)
  self.db.items[itemID] = itemData
end

function NS.Data:ClearItems()
  self.db.items = {}
end

function NS.Data:GetItemCount()
  local count = 0
  for _ in pairs(self.db.items) do
    count = count + 1
  end
  return count
end

function NS.Data:ClampWindowSize(width, height)
  local defaults = NS.Config.UI_DEFAULTS
  width = math.max(defaults.minWidth, math.min(defaults.maxWidth, width))
  height = math.max(defaults.minHeight, math.min(defaults.maxHeight, height))
  return width, height
end
