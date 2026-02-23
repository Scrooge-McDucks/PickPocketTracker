-------------------------------------------------------------------------------
-- data.lua — SavedVariables access layer
-- Provides getters/setters for all persisted settings so the rest of the
-- addon never touches PickPocketTrackerDB directly.
-------------------------------------------------------------------------------
local _, NS = ...

NS.Data = {}

local math_max   = math.max
local math_min   = math.min
local math_floor = math.floor
local pairs      = pairs

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

--- Clamp a value between min and max.
local function Clamp(value, lo, hi)
  return math_max(lo, math_min(hi, value))
end

--- Round to nearest integer.
local function Round(x)
  return math_floor(x + 0.5)
end

-------------------------------------------------------------------------------
-- Initialization — called once on PLAYER_LOGIN
-------------------------------------------------------------------------------

function NS.Data:Initialize()
  PickPocketTrackerDB = PickPocketTrackerDB or {}

  self:InitializeUI()
  self:InitializeMinimap()
  self:InitializeItems()

  self.db = PickPocketTrackerDB
end

--- Backfill any missing keys with defaults (safe for existing installs).
function NS.Data:InitializeUI()
  local db = PickPocketTrackerDB
  local d  = NS.Config.UI_DEFAULTS

  local defaults = {
    hidden          = d.hidden,
    locked          = d.locked,
    showIcon        = d.showIcon,
    chatLogItems    = d.chatLogItems,
    showBarGraph    = d.showBarGraph,
    trackCoins      = false,
    coinWindowHidden = false,
    autoSell        = NS.Config.AUTOSELL_DEFAULTS.enabled,
    point           = d.point,
    relativePoint   = d.relativePoint,
    offsetX         = d.offsetX,
    offsetY         = d.offsetY,
    width           = d.width,
    height          = d.height,
    maxGoldBars     = NS.Config.CHART_DEFAULTS.maxBars,
    maxCoinBars     = NS.Config.CHART_DEFAULTS.maxBars,
    detectionWindow = NS.Config.DEFAULT_WINDOW_SECONDS,
  }

  for key, default in pairs(defaults) do
    if db[key] == nil then db[key] = default end
  end
end

function NS.Data:InitializeMinimap()
  local db = PickPocketTrackerDB
  local d  = NS.Config.MINIMAP_DEFAULTS

  if db.minimap == nil then db.minimap = {} end
  local mm = db.minimap
  if mm.hide   == nil then mm.hide   = d.hide end
  if mm.angle  == nil then mm.angle  = d.angle end
  if mm.radius == nil then mm.radius = d.radius end
end

function NS.Data:InitializeItems()
  local db = PickPocketTrackerDB
  if db.items == nil then db.items = {} end
end

-------------------------------------------------------------------------------
-- Class check
-------------------------------------------------------------------------------

--- Returns true if the current character is a Rogue.
function NS.Data:IsRogue()
  local _, classToken = UnitClass("player")
  return classToken ~= nil and classToken == NS.Config.REQUIRED_CLASS
end

-------------------------------------------------------------------------------
-- UI settings
-------------------------------------------------------------------------------

function NS.Data:IsHidden()       return self.db.hidden end
function NS.Data:IsLocked()       return self.db.locked end
function NS.Data:ShouldShowIcon() return self.db.showIcon end
function NS.Data:ShouldChatLogItems() return self.db.chatLogItems end
function NS.Data:ShouldShowBarGraph() return self.db.showBarGraph end

function NS.Data:SetHidden(v)       self.db.hidden       = v end
function NS.Data:SetLocked(v)       self.db.locked       = v end
function NS.Data:SetShowIcon(v)     self.db.showIcon     = v end
function NS.Data:SetChatLogItems(v) self.db.chatLogItems = v end
function NS.Data:SetShowBarGraph(v) self.db.showBarGraph = v end
function NS.Data:SetTrackCoins(v)   self.db.trackCoins   = v end

function NS.Data:ShouldTrackCoins()    return self.db.trackCoins end

-- Coin window visibility (independent of tracking — you can track without showing)
function NS.Data:IsCoinWindowHidden()  return self.db.coinWindowHidden end
function NS.Data:SetCoinWindowHidden(v) self.db.coinWindowHidden = v end

-- Auto-sell fence items
function NS.Data:ShouldAutoSell()    return self.db.autoSell end
function NS.Data:SetAutoSell(v)      self.db.autoSell = v end

-- Max chart bars (per-graph, independent values)
function NS.Data:GetMaxGoldBars()
  local v = self.db.maxGoldBars or NS.Config.CHART_DEFAULTS.maxBars
  return Clamp(v, NS.Config.CHART_DEFAULTS.minBars, NS.Config.CHART_DEFAULTS.maxBarsLimit)
end
function NS.Data:SetMaxGoldBars(v)
  self.db.maxGoldBars = Clamp(v, NS.Config.CHART_DEFAULTS.minBars, NS.Config.CHART_DEFAULTS.maxBarsLimit)
end

function NS.Data:GetMaxCoinBars()
  local v = self.db.maxCoinBars or NS.Config.CHART_DEFAULTS.maxBars
  return Clamp(v, NS.Config.CHART_DEFAULTS.minBars, NS.Config.CHART_DEFAULTS.maxBarsLimit)
end
function NS.Data:SetMaxCoinBars(v)
  self.db.maxCoinBars = Clamp(v, NS.Config.CHART_DEFAULTS.minBars, NS.Config.CHART_DEFAULTS.maxBarsLimit)
end

-- Detection window (seconds) — persisted so it survives reload/logout
function NS.Data:GetDetectionWindow()
  local v = self.db.detectionWindow or NS.Config.DEFAULT_WINDOW_SECONDS
  return Clamp(v, NS.Config.MIN_WINDOW_SECONDS, NS.Config.MAX_WINDOW_SECONDS)
end
function NS.Data:SetDetectionWindow(v)
  self.db.detectionWindow = Clamp(v, NS.Config.MIN_WINDOW_SECONDS, NS.Config.MAX_WINDOW_SECONDS)
end

function NS.Data:GetWindowPosition()
  return self.db.point, self.db.relativePoint, self.db.offsetX, self.db.offsetY
end

function NS.Data:SetWindowPosition(point, relPoint, x, y)
  self.db.point         = point
  self.db.relativePoint = relPoint
  self.db.offsetX       = Round(x)
  self.db.offsetY       = Round(y)
end

function NS.Data:GetWindowSize()
  return self.db.width, self.db.height
end

function NS.Data:SetWindowSize(width, height)
  width, height = self:ClampWindowSize(width, height)
  self.db.width  = Round(width)
  self.db.height = Round(height)
end

function NS.Data:ClampWindowSize(width, height)
  local d = NS.Config.UI_DEFAULTS
  width  = Clamp(width,  d.minWidth,  d.maxWidth)
  height = Clamp(height, d.minHeight, d.maxHeight)
  return width, height
end

-------------------------------------------------------------------------------
-- Minimap settings
-------------------------------------------------------------------------------

function NS.Data:IsMinimapHidden() return self.db.minimap.hide end

function NS.Data:SetMinimapHidden(hidden)
  self.db.minimap.hide = hidden
end

function NS.Data:ResetMinimapPosition()
  local d = NS.Config.MINIMAP_DEFAULTS
  self.db.minimap.angle  = d.angle
  self.db.minimap.radius = d.radius
end

-------------------------------------------------------------------------------
-- Item data (session-scoped, stored in per-character SV)
-------------------------------------------------------------------------------

function NS.Data:GetItems()        return self.db.items end
function NS.Data:GetItem(id)       return self.db.items[id] end
function NS.Data:SetItem(id, data) self.db.items[id] = data end
function NS.Data:ClearItems()      self.db.items = {} end

function NS.Data:GetItemCount()
  local n = 0
  for _ in pairs(self.db.items) do n = n + 1 end
  return n
end

-------------------------------------------------------------------------------
-- Coin window position
-------------------------------------------------------------------------------

function NS.Data:GetCoinWindowPosition()
  local cw = self.db.coinWindow
  if cw then
    return cw.point, cw.relativePoint, cw.offsetX, cw.offsetY
  end
  local d = NS.Config.COIN_WINDOW_DEFAULTS
  return d.point, d.relativePoint, d.offsetX, d.offsetY
end

function NS.Data:SetCoinWindowPosition(point, relPoint, x, y)
  self.db.coinWindow = self.db.coinWindow or {}
  self.db.coinWindow.point         = point
  self.db.coinWindow.relativePoint = relPoint
  self.db.coinWindow.offsetX       = Round(x)
  self.db.coinWindow.offsetY       = Round(y)
end

function NS.Data:GetCoinWindowSize()
  local cw = self.db.coinWindow
  local d  = NS.Config.COIN_WINDOW_DEFAULTS
  if cw and cw.width then
    return cw.width, cw.height or d.height
  end
  return d.width, d.height
end

function NS.Data:SetCoinWindowSize(w, h)
  local d = NS.Config.COIN_WINDOW_DEFAULTS
  w = Clamp(w, d.minWidth,  d.maxWidth)
  h = Clamp(h, d.minHeight, d.maxHeight)
  self.db.coinWindow = self.db.coinWindow or {}
  self.db.coinWindow.width  = Round(w)
  self.db.coinWindow.height = Round(h)
end

function NS.Data:ShouldShowCoinIcon()
  if self.db.coinWindow and self.db.coinWindow.showIcon ~= nil then
    return self.db.coinWindow.showIcon
  end
  return NS.Config.COIN_WINDOW_DEFAULTS.showIcon
end

function NS.Data:SetShowCoinIcon(v)
  self.db.coinWindow = self.db.coinWindow or {}
  self.db.coinWindow.showIcon = v
end
