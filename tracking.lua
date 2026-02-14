-- Gold tracking logic
local _, NS = ...

NS.Tracking = {}

-- Session state
NS.Tracking.sessionGold = 0
NS.Tracking.lastPickPocketTime = 0
NS.Tracking.lastMoneyAmount = 0
NS.Tracking.detectionWindowSeconds = NS.Config.DEFAULT_WINDOW_SECONDS

function NS.Tracking:Initialize()
  self.lastMoneyAmount = GetMoney()
  self.detectionWindowSeconds = NS.Config.DEFAULT_WINDOW_SECONDS
end

function NS.Tracking:ResetSession()
  self.sessionGold = 0
  self.lastPickPocketTime = 0
  self.lastMoneyAmount = GetMoney()
end

function NS.Tracking:SetDetectionWindow(seconds)
  if not seconds or seconds < NS.Config.MIN_WINDOW_SECONDS or 
     seconds > NS.Config.MAX_WINDOW_SECONDS then
    return false
  end
  
  self.detectionWindowSeconds = seconds
  return true
end

function NS.Tracking:OnPickPocketCast()
  self.lastPickPocketTime = GetTime()
  
  if NS.Stats then
    NS.Stats:RecordPickpocket()
  end
end

function NS.Tracking:OnMoneyChanged()
  local currentMoney = GetMoney()
  local moneyDelta = currentMoney - self.lastMoneyAmount
  self.lastMoneyAmount = currentMoney
  
  if not self:IsPickPocketRelated(moneyDelta) then
    return 0
  end
  
  self.sessionGold = self.sessionGold + moneyDelta
  
  if NS.Stats then
    NS.Stats:RecordGoldLooted(moneyDelta)
  end
  
  return moneyDelta
end

function NS.Tracking:IsPickPocketRelated(moneyDelta)
  if moneyDelta <= 0 then return false end
  
  local timeSince = GetTime() - self.lastPickPocketTime
  if timeSince > self.detectionWindowSeconds then
    return false
  end
  
  return true
end

-- Getters
function NS.Tracking:GetDetectionWindow()
  return self.detectionWindowSeconds
end

function NS.Tracking:GetSessionGold()
  return self.sessionGold
end

function NS.Tracking:GetTotalValue()
  local itemValue = NS.Items and NS.Items:GetSessionVendorValue() or 0
  return self.sessionGold + itemValue
end

function NS.Tracking:IsInDetectionWindow()
  local timeSince = GetTime() - self.lastPickPocketTime
  return timeSince <= self.detectionWindowSeconds
end
