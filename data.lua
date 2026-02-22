-------------------------------------------------------------------------------
-- data.lua — SavedVariables access layer
-- Provides getters/setters for all persisted settings so the rest of the
-- addon never touches PickPocketTrackerDB directly.
-------------------------------------------------------------------------------
local _, NS = ...

NS.Data = {}

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

  if db.hidden       == nil then db.hidden       = d.hidden end
  if db.locked       == nil then db.locked       = d.locked end
  if db.showIcon     == nil then db.showIcon     = d.showIcon end
  if db.chatLogItems == nil then db.chatLogItems = d.chatLogItems end
  if db.showBarGraph == nil then db.showBarGraph = d.showBarGraph end
  if db.trackCoins   == nil then db.trackCoins   = false end
  if db.autoSell     == nil then db.autoSell     = NS.Config.AUTOSELL_DEFAULTS.enabled end
  if db.point         == nil then db.point         = d.point end
  if db.relativePoint == nil then db.relativePoint = d.relativePoint end
  if db.offsetX       == nil then db.offsetX       = d.offsetX end
  if db.offsetY       == nil then db.offsetY       = d.offsetY end
  if db.width         == nil then db.width         = d.width end
  if db.height        == nil then db.height        = d.height end
  if db.maxGoldBars   == nil then db.maxGoldBars   = NS.Config.CHART_DEFAULTS.maxBars end
  if db.maxCoinBars   == nil then db.maxCoinBars   = NS.Config.CHART_DEFAULTS.maxBars end
  if db.detectionWindow == nil then db.detectionWindow = NS.Config.DEFAULT_WINDOW_SECONDS end
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
  return classToken == NS.Config.REQUIRED_CLASS
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

-- Auto-sell fence items
function NS.Data:ShouldAutoSell()    return self.db.autoSell end
function NS.Data:SetAutoSell(v)      self.db.autoSell = v end

-- Max chart bars (per-graph, independent values)
function NS.Data:GetMaxGoldBars()
  local v = self.db.maxGoldBars or NS.Config.CHART_DEFAULTS.maxBars
  return math.max(NS.Config.CHART_DEFAULTS.minBars, math.min(NS.Config.CHART_DEFAULTS.maxBarsLimit, v))
end
function NS.Data:SetMaxGoldBars(v)
  self.db.maxGoldBars = math.max(NS.Config.CHART_DEFAULTS.minBars, math.min(NS.Config.CHART_DEFAULTS.maxBarsLimit, v))
end

function NS.Data:GetMaxCoinBars()
  local v = self.db.maxCoinBars or NS.Config.CHART_DEFAULTS.maxBars
  return math.max(NS.Config.CHART_DEFAULTS.minBars, math.min(NS.Config.CHART_DEFAULTS.maxBarsLimit, v))
end
function NS.Data:SetMaxCoinBars(v)
  self.db.maxCoinBars = math.max(NS.Config.CHART_DEFAULTS.minBars, math.min(NS.Config.CHART_DEFAULTS.maxBarsLimit, v))
end

-- Detection window (seconds) — persisted so it survives reload/logout
function NS.Data:GetDetectionWindow()
  local v = self.db.detectionWindow or NS.Config.DEFAULT_WINDOW_SECONDS
  return math.max(NS.Config.MIN_WINDOW_SECONDS, math.min(NS.Config.MAX_WINDOW_SECONDS, v))
end
function NS.Data:SetDetectionWindow(v)
  self.db.detectionWindow = math.max(NS.Config.MIN_WINDOW_SECONDS, math.min(NS.Config.MAX_WINDOW_SECONDS, v))
end

function NS.Data:GetWindowPosition()
  return self.db.point, self.db.relativePoint, self.db.offsetX, self.db.offsetY
end

function NS.Data:SetWindowPosition(point, relPoint, x, y)
  self.db.point         = point
  self.db.relativePoint = relPoint
  self.db.offsetX       = math.floor(x + 0.5)
  self.db.offsetY       = math.floor(y + 0.5)
end

function NS.Data:GetWindowSize()
  return self.db.width, self.db.height
end

function NS.Data:SetWindowSize(width, height)
  width, height = self:ClampWindowSize(width, height)
  self.db.width  = math.floor(width  + 0.5)
  self.db.height = math.floor(height + 0.5)
end

function NS.Data:ClampWindowSize(width, height)
  local d = NS.Config.UI_DEFAULTS
  width  = math.max(d.minWidth,  math.min(d.maxWidth,  width))
  height = math.max(d.minHeight, math.min(d.maxHeight, height))
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
  self.db.coinWindow.offsetX       = math.floor(x + 0.5)
  self.db.coinWindow.offsetY       = math.floor(y + 0.5)
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
  w = math.max(d.minWidth,  math.min(d.maxWidth,  w))
  h = math.max(d.minHeight, math.min(d.maxHeight, h))
  self.db.coinWindow = self.db.coinWindow or {}
  self.db.coinWindow.width  = math.floor(w + 0.5)
  self.db.coinWindow.height = math.floor(h + 0.5)
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
