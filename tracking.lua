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
  NS.Utils:PrintInfo("Tracking initialized")
end

function NS.Tracking:ResetSession()
  self.sessionGold = 0
  self.lastPickPocketTime = 0
  self.lastMoneyAmount = GetMoney()
  NS.Utils:PrintWarning("Session reset")
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

function NS.Tracking:GetValueBreakdown()
  local total = self:GetTotalValue()
  local goldPercent = NS.Utils:Percentage(self.sessionGold, total)
  
  local itemValue = NS.Items and NS.Items:GetSessionVendorValue() or 0
  local itemPercent = NS.Utils:Percentage(itemValue, total)
  
  return goldPercent, itemPercent
end

function NS.Tracking:IsInDetectionWindow()
  local timeSince = GetTime() - self.lastPickPocketTime
  return timeSince <= self.detectionWindowSeconds
end

function NS.Tracking:GetTimeSinceLastPickPocket()
  return GetTime() - self.lastPickPocketTime
end

-- Formatted output
function NS.Tracking:GetSessionSummary()
  local total = self:GetTotalValue()
  local goldPercent, itemPercent = self:GetValueBreakdown()
  
  local lines = {}
  table.insert(lines, "Pickpocket haul: " .. NS.Utils:FormatMoney(total))
  table.insert(lines, string.format("  Gold: %s (%.1f%%)", 
    NS.Utils:FormatMoney(self.sessionGold), goldPercent))
  
  if NS.Items then
    local itemValue = NS.Items:GetSessionVendorValue()
    table.insert(lines, string.format("  Items sold: %s (%.1f%%)", 
      NS.Utils:FormatMoney(itemValue), itemPercent))
  end
  
  table.insert(lines, "Type /pp stats for item details")
  
  return table.concat(lines, "\n")
end
