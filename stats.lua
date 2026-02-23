-------------------------------------------------------------------------------
-- stats.lua — Lifetime statistics (per-character and account-wide)
--
-- Per-character data lives in PickPocketTrackerAccountDB.characters[key]
-- Account totals are maintained in parallel for O(1) lookups.
-- Character key format: "RealmName-CharacterName"
-------------------------------------------------------------------------------
local _, NS = ...

NS.Stats = {}

local math_max      = math.max
local math_floor    = math.floor
local pairs         = pairs
local time          = time
local date          = date
local table_concat  = table.concat

-- Cached after Initialize — realm+name never change during a session.
local cachedCharKey = nil

--- Unique key for this character, stable across sessions.
function NS.Stats:GetCharacterKey()
  if not cachedCharKey then
    cachedCharKey = GetRealmName() .. "-" .. UnitName("player")
  end
  return cachedCharKey
end

function NS.Stats:Initialize()
  PickPocketTrackerAccountDB = PickPocketTrackerAccountDB or {}
  self.db = PickPocketTrackerAccountDB

  self.db.totalGold        = self.db.totalGold        or 0
  self.db.totalItemsSold   = self.db.totalItemsSold   or 0
  self.db.totalPickpockets = self.db.totalPickpockets  or 0
  self.db.totalCoinsOfAir  = self.db.totalCoinsOfAir  or 0
  self.db.characters       = self.db.characters       or {}

  local key = self:GetCharacterKey()
  if not self.db.characters[key] then
    self.db.characters[key] = {
      name            = UnitName("player"),
      class           = UnitClass("player"),
      goldLooted      = 0,
      itemsSold       = 0,
      pickpocketCount = 0,
      coinsOfAir      = 0,
      firstPickpocket = nil,
      lastPickpocket  = nil,
    }
  end

  -- Backfill coinsOfAir for existing characters
  local char = self.db.characters[key]
  if char.coinsOfAir == nil then char.coinsOfAir = 0 end
end

-------------------------------------------------------------------------------
-- Recording
-------------------------------------------------------------------------------

function NS.Stats:RecordGoldLooted(amount)
  if amount <= 0 then return end
  local char = self.db.characters[self:GetCharacterKey()]
  char.goldLooted     = char.goldLooted + amount
  char.lastPickpocket = time()
  if not char.firstPickpocket then char.firstPickpocket = time() end
  self.db.totalGold = self.db.totalGold + amount
end

function NS.Stats:RecordItemsSold(amount)
  if amount <= 0 then return end
  local char = self.db.characters[self:GetCharacterKey()]
  char.itemsSold = char.itemsSold + amount
  self.db.totalItemsSold = self.db.totalItemsSold + amount
end

function NS.Stats:RecordPickpocket()
  local char = self.db.characters[self:GetCharacterKey()]
  char.pickpocketCount = char.pickpocketCount + 1
  char.lastPickpocket  = time()
  if not char.firstPickpocket then char.firstPickpocket = time() end
  self.db.totalPickpockets = self.db.totalPickpockets + 1
end

function NS.Stats:RecordCoinsOfAir(amount)
  if amount <= 0 then return end
  local char = self.db.characters[self:GetCharacterKey()]
  char.coinsOfAir = (char.coinsOfAir or 0) + amount
  self.db.totalCoinsOfAir = (self.db.totalCoinsOfAir or 0) + amount
end

-------------------------------------------------------------------------------
-- Character getters
-------------------------------------------------------------------------------

local function charData(self)
  return self.db.characters[self:GetCharacterKey()]
end

function NS.Stats:GetCharacterGold()            return charData(self).goldLooted end
function NS.Stats:GetCharacterItemsSold()        return charData(self).itemsSold end
function NS.Stats:GetCharacterPickpocketCount()  return charData(self).pickpocketCount end
function NS.Stats:GetCharacterTotal()            return self:GetCharacterGold() + self:GetCharacterItemsSold() end
function NS.Stats:GetCharacterCoins()            return charData(self).coinsOfAir or 0 end

-------------------------------------------------------------------------------
-- Account getters
-------------------------------------------------------------------------------

function NS.Stats:GetAccountGold()            return self.db.totalGold end
function NS.Stats:GetAccountItemsSold()        return self.db.totalItemsSold end
function NS.Stats:GetAccountPickpocketCount()  return self.db.totalPickpockets end
function NS.Stats:GetAccountTotal()            return self:GetAccountGold() + self:GetAccountItemsSold() end
function NS.Stats:GetAccountCoins()            return self.db.totalCoinsOfAir or 0 end

function NS.Stats:GetCharacterCount()
  local n = 0
  for _ in pairs(self.db.characters) do n = n + 1 end
  return n
end

-------------------------------------------------------------------------------
-- Resets
-------------------------------------------------------------------------------

function NS.Stats:ResetCharacter()
  local char = self.db.characters[self:GetCharacterKey()]

  -- Subtract from account totals (clamp to zero in case of data corruption)
  self.db.totalGold        = math_max(0, self.db.totalGold        - char.goldLooted)
  self.db.totalItemsSold   = math_max(0, self.db.totalItemsSold   - char.itemsSold)
  self.db.totalPickpockets = math_max(0, self.db.totalPickpockets  - char.pickpocketCount)
  self.db.totalCoinsOfAir  = math_max(0, (self.db.totalCoinsOfAir or 0) - (char.coinsOfAir or 0))

  char.goldLooted      = 0
  char.itemsSold       = 0
  char.pickpocketCount = 0
  char.coinsOfAir      = 0
  char.firstPickpocket = nil
  char.lastPickpocket  = nil

  NS.Utils:PrintWarning("Character lifetime stats reset")
end

function NS.Stats:ResetAccount()
  self.db.totalGold        = 0
  self.db.totalItemsSold   = 0
  self.db.totalPickpockets = 0
  self.db.totalCoinsOfAir  = 0

  for _, char in pairs(self.db.characters) do
    char.goldLooted      = 0
    char.itemsSold       = 0
    char.pickpocketCount = 0
    char.coinsOfAir      = 0
    char.firstPickpocket = nil
    char.lastPickpocket  = nil
  end

  NS.Utils:PrintWarning("Account-wide lifetime stats reset for ALL characters")
end

-------------------------------------------------------------------------------
-- Formatted chat output
-------------------------------------------------------------------------------

local function fmtAvg(total, count)
  return NS.Utils:FormatMoney(count > 0 and math_floor(total / count) or 0)
end

function NS.Stats:GetCharacterStatsFormatted()
  local c = charData(self)
  local total = c.goldLooted + c.itemsSold
  local lines = {
    "=== " .. UnitName("player") .. " (This Character) ===",
    "Gold looted: "            .. NS.Utils:FormatMoney(c.goldLooted),
    "Items sold: "             .. NS.Utils:FormatMoney(c.itemsSold),
    "Total earned: "           .. NS.Utils:FormatMoney(total),
    "Pickpockets: "            .. c.pickpocketCount,
    "Average per pickpocket: " .. fmtAvg(total, c.pickpocketCount),
  }
  if (c.coinsOfAir or 0) > 0 then
    lines[#lines + 1] = "Coins of Air: " .. (c.coinsOfAir or 0)
  end
  if c.firstPickpocket then
    lines[#lines + 1] = "First pickpocket: " .. date("%Y-%m-%d %H:%M", c.firstPickpocket)
  end
  if c.lastPickpocket then
    lines[#lines + 1] = "Last pickpocket: "  .. date("%Y-%m-%d %H:%M", c.lastPickpocket)
  end
  return table_concat(lines, "\n")
end

function NS.Stats:GetAccountStatsFormatted()
  local total = self.db.totalGold + self.db.totalItemsSold
  local lines = {
    "=== Account-Wide Statistics ===",
    "Total gold looted: "      .. NS.Utils:FormatMoney(self.db.totalGold),
    "Total items sold: "       .. NS.Utils:FormatMoney(self.db.totalItemsSold),
    "Total earned: "           .. NS.Utils:FormatMoney(total),
    "Total pickpockets: "      .. self.db.totalPickpockets,
    "Characters: "             .. self:GetCharacterCount(),
    "Average per pickpocket: " .. fmtAvg(total, self.db.totalPickpockets),
  }
  if (self.db.totalCoinsOfAir or 0) > 0 then
    lines[#lines + 1] = "Total Coins of Air: " .. (self.db.totalCoinsOfAir or 0)
  end
  return table_concat(lines, "\n")
end
