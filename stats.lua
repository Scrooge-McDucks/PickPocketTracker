-------------------------------------------------------------------------------
-- stats.lua — Lifetime statistics (per-character and account-wide)
--
-- Per-character data lives in PickPocketTrackerAccountDB.characters[key]
-- Account totals are maintained in parallel for O(1) lookups.
-- Character key format: "RealmName-CharacterName"
-------------------------------------------------------------------------------
local _, NS = ...

NS.Stats = {}

--- Unique key for this character, stable across sessions.
function NS.Stats:GetCharacterKey()
  return GetRealmName() .. "-" .. UnitName("player")
end

function NS.Stats:Initialize()
  PickPocketTrackerAccountDB = PickPocketTrackerAccountDB or {}
  local db = PickPocketTrackerAccountDB

  db.totalGold       = db.totalGold       or 0
  db.totalItemsSold  = db.totalItemsSold  or 0
  db.totalPickpockets = db.totalPickpockets or 0
  db.characters      = db.characters      or {}

  local key = self:GetCharacterKey()
  if not db.characters[key] then
    db.characters[key] = {
      name            = UnitName("player"),
      class           = UnitClass("player"),
      goldLooted      = 0,
      itemsSold       = 0,
      pickpocketCount = 0,
      firstPickpocket = nil,
      lastPickpocket  = nil,
    }
  end
end

-------------------------------------------------------------------------------
-- Recording
-------------------------------------------------------------------------------

function NS.Stats:RecordGoldLooted(amount)
  if amount <= 0 then return end
  local char = PickPocketTrackerAccountDB.characters[self:GetCharacterKey()]
  char.goldLooted     = char.goldLooted + amount
  char.lastPickpocket = time()
  if not char.firstPickpocket then char.firstPickpocket = time() end
  PickPocketTrackerAccountDB.totalGold = PickPocketTrackerAccountDB.totalGold + amount
end

function NS.Stats:RecordItemsSold(amount)
  if amount <= 0 then return end
  local char = PickPocketTrackerAccountDB.characters[self:GetCharacterKey()]
  char.itemsSold = char.itemsSold + amount
  PickPocketTrackerAccountDB.totalItemsSold = PickPocketTrackerAccountDB.totalItemsSold + amount
end

function NS.Stats:RecordPickpocket()
  local char = PickPocketTrackerAccountDB.characters[self:GetCharacterKey()]
  char.pickpocketCount = char.pickpocketCount + 1
  char.lastPickpocket  = time()
  if not char.firstPickpocket then char.firstPickpocket = time() end
  PickPocketTrackerAccountDB.totalPickpockets = PickPocketTrackerAccountDB.totalPickpockets + 1
end

-------------------------------------------------------------------------------
-- Character getters
-------------------------------------------------------------------------------

local function charData(self)
  return PickPocketTrackerAccountDB.characters[self:GetCharacterKey()]
end

function NS.Stats:GetCharacterGold()            return charData(self).goldLooted end
function NS.Stats:GetCharacterItemsSold()        return charData(self).itemsSold end
function NS.Stats:GetCharacterPickpocketCount()  return charData(self).pickpocketCount end
function NS.Stats:GetCharacterTotal()            return self:GetCharacterGold() + self:GetCharacterItemsSold() end

-------------------------------------------------------------------------------
-- Account getters
-------------------------------------------------------------------------------

function NS.Stats:GetAccountGold()            return PickPocketTrackerAccountDB.totalGold end
function NS.Stats:GetAccountItemsSold()        return PickPocketTrackerAccountDB.totalItemsSold end
function NS.Stats:GetAccountPickpocketCount()  return PickPocketTrackerAccountDB.totalPickpockets end
function NS.Stats:GetAccountTotal()            return self:GetAccountGold() + self:GetAccountItemsSold() end

function NS.Stats:GetCharacterCount()
  local n = 0
  for _ in pairs(PickPocketTrackerAccountDB.characters) do n = n + 1 end
  return n
end

-------------------------------------------------------------------------------
-- Resets
-------------------------------------------------------------------------------

function NS.Stats:ResetCharacter()
  local db   = PickPocketTrackerAccountDB
  local char = db.characters[self:GetCharacterKey()]

  -- Subtract from account totals (clamp to zero in case of data corruption)
  db.totalGold        = math.max(0, db.totalGold        - char.goldLooted)
  db.totalItemsSold   = math.max(0, db.totalItemsSold   - char.itemsSold)
  db.totalPickpockets = math.max(0, db.totalPickpockets  - char.pickpocketCount)

  char.goldLooted      = 0
  char.itemsSold       = 0
  char.pickpocketCount = 0
  char.firstPickpocket = nil
  char.lastPickpocket  = nil

  NS.Utils:PrintWarning("Character lifetime stats reset")
end

function NS.Stats:ResetAccount()
  local db = PickPocketTrackerAccountDB
  db.totalGold        = 0
  db.totalItemsSold   = 0
  db.totalPickpockets = 0

  for _, char in pairs(db.characters) do
    char.goldLooted      = 0
    char.itemsSold       = 0
    char.pickpocketCount = 0
    char.firstPickpocket = nil
    char.lastPickpocket  = nil
  end

  NS.Utils:PrintWarning("Account-wide lifetime stats reset for ALL characters")
end

-------------------------------------------------------------------------------
-- Formatted chat output
-------------------------------------------------------------------------------

local function fmtAvg(total, count)
  return NS.Utils:FormatMoney(count > 0 and (total / count) or 0)
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
  if c.firstPickpocket then
    lines[#lines + 1] = "First pickpocket: " .. date("%Y-%m-%d %H:%M", c.firstPickpocket)
  end
  if c.lastPickpocket then
    lines[#lines + 1] = "Last pickpocket: "  .. date("%Y-%m-%d %H:%M", c.lastPickpocket)
  end
  return table.concat(lines, "\n")
end

function NS.Stats:GetAccountStatsFormatted()
  local db = PickPocketTrackerAccountDB
  local total = db.totalGold + db.totalItemsSold
  return table.concat({
    "=== Account-Wide Statistics ===",
    "Total gold looted: "      .. NS.Utils:FormatMoney(db.totalGold),
    "Total items sold: "       .. NS.Utils:FormatMoney(db.totalItemsSold),
    "Total earned: "           .. NS.Utils:FormatMoney(total),
    "Total pickpockets: "      .. db.totalPickpockets,
    "Characters: "             .. self:GetCharacterCount(),
    "Average per pickpocket: " .. fmtAvg(total, db.totalPickpockets),
  }, "\n")
end
