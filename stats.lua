-- Lifetime statistics tracking
local _, NS = ...

NS.Stats = {}

function NS.Stats:GetCharacterKey()
  local name = UnitName("player")
  local realm = GetRealmName()
  return realm .. "-" .. name
end

function NS.Stats:Initialize()
  -- Initialize account-wide database
  PickPocketTrackerAccountDB = PickPocketTrackerAccountDB or {}
  PickPocketTrackerAccountDB.totalGold = PickPocketTrackerAccountDB.totalGold or 0
  PickPocketTrackerAccountDB.totalItemsSold = PickPocketTrackerAccountDB.totalItemsSold or 0
  PickPocketTrackerAccountDB.totalPickpockets = PickPocketTrackerAccountDB.totalPickpockets or 0
  PickPocketTrackerAccountDB.characters = PickPocketTrackerAccountDB.characters or {}
  
  -- Initialize this character
  local charKey = self:GetCharacterKey()
  if not PickPocketTrackerAccountDB.characters[charKey] then
    PickPocketTrackerAccountDB.characters[charKey] = {
      name = UnitName("player"),
      class = UnitClass("player"),
      goldLooted = 0,
      itemsSold = 0,
      pickpocketCount = 0,
      firstPickpocket = nil,
      lastPickpocket = nil,
    }
  end
end

-- Recording functions
function NS.Stats:RecordGoldLooted(amount)
  if amount <= 0 then return end
  
  local charKey = self:GetCharacterKey()
  local charData = PickPocketTrackerAccountDB.characters[charKey]
  
  charData.goldLooted = charData.goldLooted + amount
  charData.lastPickpocket = time()
  
  if not charData.firstPickpocket then
    charData.firstPickpocket = time()
  end
  
  PickPocketTrackerAccountDB.totalGold = PickPocketTrackerAccountDB.totalGold + amount
end

function NS.Stats:RecordItemsSold(amount)
  if amount <= 0 then return end
  
  local charKey = self:GetCharacterKey()
  local charData = PickPocketTrackerAccountDB.characters[charKey]
  
  charData.itemsSold = charData.itemsSold + amount
  PickPocketTrackerAccountDB.totalItemsSold = PickPocketTrackerAccountDB.totalItemsSold + amount
end

function NS.Stats:RecordPickpocket()
  local charKey = self:GetCharacterKey()
  local charData = PickPocketTrackerAccountDB.characters[charKey]
  
  charData.pickpocketCount = charData.pickpocketCount + 1
  charData.lastPickpocket = time()
  
  if not charData.firstPickpocket then
    charData.firstPickpocket = time()
  end
  
  PickPocketTrackerAccountDB.totalPickpockets = PickPocketTrackerAccountDB.totalPickpockets + 1
end

-- Character getters
function NS.Stats:GetCharacterGold()
  local charKey = self:GetCharacterKey()
  return PickPocketTrackerAccountDB.characters[charKey].goldLooted
end

function NS.Stats:GetCharacterItemsSold()
  local charKey = self:GetCharacterKey()
  return PickPocketTrackerAccountDB.characters[charKey].itemsSold
end

function NS.Stats:GetCharacterPickpocketCount()
  local charKey = self:GetCharacterKey()
  return PickPocketTrackerAccountDB.characters[charKey].pickpocketCount
end

function NS.Stats:GetCharacterTotal()
  return self:GetCharacterGold() + self:GetCharacterItemsSold()
end

function NS.Stats:GetCharacterFirstPickpocket()
  local charKey = self:GetCharacterKey()
  return PickPocketTrackerAccountDB.characters[charKey].firstPickpocket
end

function NS.Stats:GetCharacterLastPickpocket()
  local charKey = self:GetCharacterKey()
  return PickPocketTrackerAccountDB.characters[charKey].lastPickpocket
end

-- Account getters
function NS.Stats:GetAccountGold()
  return PickPocketTrackerAccountDB.totalGold
end

function NS.Stats:GetAccountItemsSold()
  return PickPocketTrackerAccountDB.totalItemsSold
end

function NS.Stats:GetAccountPickpocketCount()
  return PickPocketTrackerAccountDB.totalPickpockets
end

function NS.Stats:GetAccountTotal()
  return self:GetAccountGold() + self:GetAccountItemsSold()
end

function NS.Stats:GetCharacterCount()
  local count = 0
  for _ in pairs(PickPocketTrackerAccountDB.characters) do
    count = count + 1
  end
  return count
end

-- Reset functions
function NS.Stats:ResetCharacter()
  local charKey = self:GetCharacterKey()
  local charData = PickPocketTrackerAccountDB.characters[charKey]
  
  -- Subtract from account totals
  PickPocketTrackerAccountDB.totalGold = PickPocketTrackerAccountDB.totalGold - charData.goldLooted
  PickPocketTrackerAccountDB.totalItemsSold = PickPocketTrackerAccountDB.totalItemsSold - charData.itemsSold
  PickPocketTrackerAccountDB.totalPickpockets = PickPocketTrackerAccountDB.totalPickpockets - charData.pickpocketCount
  
  -- Ensure no negatives
  PickPocketTrackerAccountDB.totalGold = math.max(0, PickPocketTrackerAccountDB.totalGold)
  PickPocketTrackerAccountDB.totalItemsSold = math.max(0, PickPocketTrackerAccountDB.totalItemsSold)
  PickPocketTrackerAccountDB.totalPickpockets = math.max(0, PickPocketTrackerAccountDB.totalPickpockets)
  
  -- Reset character
  charData.goldLooted = 0
  charData.itemsSold = 0
  charData.pickpocketCount = 0
  charData.firstPickpocket = nil
  charData.lastPickpocket = nil
  
  NS.Utils:PrintWarning("Character lifetime stats reset")
end

function NS.Stats:ResetAccount()
  PickPocketTrackerAccountDB.totalGold = 0
  PickPocketTrackerAccountDB.totalItemsSold = 0
  PickPocketTrackerAccountDB.totalPickpockets = 0
  
  for _, charData in pairs(PickPocketTrackerAccountDB.characters) do
    charData.goldLooted = 0
    charData.itemsSold = 0
    charData.pickpocketCount = 0
    charData.firstPickpocket = nil
    charData.lastPickpocket = nil
  end
  
  NS.Utils:PrintWarning("Account-wide lifetime stats reset for ALL characters")
end

-- Formatted output
function NS.Stats:GetCharacterStatsFormatted()
  local lines = {}
  
  table.insert(lines, "=== " .. UnitName("player") .. " (This Character) ===")
  table.insert(lines, string.format("Gold looted: %s", 
    NS.Utils:FormatMoney(self:GetCharacterGold())))
  table.insert(lines, string.format("Items sold: %s", 
    NS.Utils:FormatMoney(self:GetCharacterItemsSold())))
  table.insert(lines, string.format("Total earned: %s", 
    NS.Utils:FormatMoney(self:GetCharacterTotal())))
  table.insert(lines, string.format("Pickpockets: %d", 
    self:GetCharacterPickpocketCount()))
  
  local avgGold = self:GetCharacterPickpocketCount() > 0 and 
    (self:GetCharacterTotal() / self:GetCharacterPickpocketCount()) or 0
  table.insert(lines, string.format("Average per pickpocket: %s", 
    NS.Utils:FormatMoney(avgGold)))
  
  local first = self:GetCharacterFirstPickpocket()
  if first then
    table.insert(lines, string.format("First pickpocket: %s", 
      date("%Y-%m-%d %H:%M", first)))
  end
  
  local last = self:GetCharacterLastPickpocket()
  if last then
    table.insert(lines, string.format("Last pickpocket: %s", 
      date("%Y-%m-%d %H:%M", last)))
  end
  
  return table.concat(lines, "\n")
end

function NS.Stats:GetAccountStatsFormatted()
  local lines = {}
  
  table.insert(lines, "=== Account-Wide Statistics ===")
  table.insert(lines, string.format("Total gold looted: %s", 
    NS.Utils:FormatMoney(self:GetAccountGold())))
  table.insert(lines, string.format("Total items sold: %s", 
    NS.Utils:FormatMoney(self:GetAccountItemsSold())))
  table.insert(lines, string.format("Total earned: %s", 
    NS.Utils:FormatMoney(self:GetAccountTotal())))
  table.insert(lines, string.format("Total pickpockets: %d", 
    self:GetAccountPickpocketCount()))
  table.insert(lines, string.format("Characters: %d", 
    self:GetCharacterCount()))
  
  local avgGold = self:GetAccountPickpocketCount() > 0 and 
    (self:GetAccountTotal() / self:GetAccountPickpocketCount()) or 0
  table.insert(lines, string.format("Average per pickpocket: %s", 
    NS.Utils:FormatMoney(avgGold)))
  
  return table.concat(lines, "\n")
end
