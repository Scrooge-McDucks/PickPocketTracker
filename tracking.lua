-------------------------------------------------------------------------------
-- tracking.lua — Gold detection via PLAYER_MONEY + time-window attribution
-- When gold increases within `detectionWindowSeconds` of a Pick Pocket cast,
-- the delta is attributed to pickpocketing.
-------------------------------------------------------------------------------
local _, NS = ...

NS.Tracking = {}

-- Session-only state (not persisted)
NS.Tracking.sessionGold             = 0
NS.Tracking.lastPickPocketTime      = 0
NS.Tracking.lastMoneyAmount         = 0
NS.Tracking.detectionWindowSeconds  = NS.Config.DEFAULT_WINDOW_SECONDS

function NS.Tracking:Initialize()
  self.lastMoneyAmount        = GetMoney()
  self.detectionWindowSeconds = NS.Config.DEFAULT_WINDOW_SECONDS
end

function NS.Tracking:ResetSession()
  self.sessionGold        = 0
  self.lastPickPocketTime = 0
  self.lastMoneyAmount    = GetMoney()
end

--- Validate and apply a new detection window (seconds). Returns false if
--- the value is out of range.
function NS.Tracking:SetDetectionWindow(seconds)
  if not seconds
    or seconds < NS.Config.MIN_WINDOW_SECONDS
    or seconds > NS.Config.MAX_WINDOW_SECONDS then
    return false
  end
  self.detectionWindowSeconds = seconds
  return true
end

--- Called on UNIT_SPELLCAST_SUCCEEDED for Pick Pocket.
function NS.Tracking:OnPickPocketCast()
  self.lastPickPocketTime = GetTime()
  if NS.Stats then NS.Stats:RecordPickpocket() end
end

--- Called on PLAYER_MONEY. Returns the gold delta if it was attributed
--- to pickpocketing, or 0 otherwise.
function NS.Tracking:OnMoneyChanged()
  local current = GetMoney()
  local delta   = current - self.lastMoneyAmount
  self.lastMoneyAmount = current

  if delta <= 0 or not self:IsInDetectionWindow() then
    return 0
  end

  self.sessionGold = self.sessionGold + delta
  if NS.Stats then NS.Stats:RecordGoldLooted(delta) end
  return delta
end

--- True if we're still within the detection window after the last cast.
function NS.Tracking:IsInDetectionWindow()
  return (GetTime() - self.lastPickPocketTime) <= self.detectionWindowSeconds
end

-- Public getters
function NS.Tracking:GetDetectionWindow() return self.detectionWindowSeconds end
function NS.Tracking:GetSessionGold()     return self.sessionGold end

--- Confirmed session value = looted gold + sold items.
function NS.Tracking:GetTotalValue()
  local itemValue = NS.Items and NS.Items:GetSessionVendorValue() or 0
  return self.sessionGold + itemValue
end
