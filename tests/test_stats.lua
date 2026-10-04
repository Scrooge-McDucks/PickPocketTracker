-------------------------------------------------------------------------------
-- test_stats.lua — lifetime stats: per-character records, account roll-ups,
-- and resets that keep the two in agreement
-------------------------------------------------------------------------------
local H = dofile(TESTS_DIR .. "/wow_stub.lua")
local MODULES = { "config.lua", "utils.lua", "data.lua", "stats.lua" }

local NS = H.newEnv(MODULES)
local S  = NS.Stats

H.section("Initialize creates the account DB and this character's record")
S:Initialize()
H.check("account DB created", PickPocketTrackerAccountDB ~= nil)
H.eq("character key", S:GetCharacterKey(), "TestRealm-Sneaky")
H.eq("account gold starts at 0",      S:GetAccountGold(), 0)
H.eq("account items start at 0",      S:GetAccountItemsSold(), 0)
H.eq("account casts start at 0",      S:GetAccountPickpocketCount(), 0)
H.eq("account coins start at 0",      S:GetAccountCoins(), 0)
H.eq("one character known",           S:GetCharacterCount(), 1)
H.eq("character gold starts at 0",    S:GetCharacterGold(), 0)
H.check("no first-pickpocket stamp yet",
  PickPocketTrackerAccountDB.characters[S:GetCharacterKey()].firstPickpocket == nil)

H.section("recording updates character and account in lockstep")
S:RecordGoldLooted(500)
S:RecordItemsSold(200)
S:RecordPickpocket()
S:RecordCoinsOfAir(3)
H.eq("character gold",   S:GetCharacterGold(), 500)
H.eq("character items",  S:GetCharacterItemsSold(), 200)
H.eq("character casts",  S:GetCharacterPickpocketCount(), 1)
H.eq("character coins",  S:GetCharacterCoins(), 3)
H.eq("character total",  S:GetCharacterTotal(), 700)
H.eq("account gold",     S:GetAccountGold(), 500)
H.eq("account items",    S:GetAccountItemsSold(), 200)
H.eq("account casts",    S:GetAccountPickpocketCount(), 1)
H.eq("account coins",    S:GetAccountCoins(), 3)
H.eq("account total",    S:GetAccountTotal(), 700)

H.section("non-positive amounts are rejected")
S:RecordGoldLooted(0)
S:RecordGoldLooted(-100)
S:RecordItemsSold(0)
S:RecordItemsSold(-50)
S:RecordCoinsOfAir(0)
S:RecordCoinsOfAir(-2)
H.eq("gold unchanged",  S:GetCharacterGold(), 500)
H.eq("items unchanged", S:GetCharacterItemsSold(), 200)
H.eq("coins unchanged", S:GetCharacterCoins(), 3)
H.eq("account gold unchanged", S:GetAccountGold(), 500)

H.section("timestamps are stamped once for first, every time for last")
local char = PickPocketTrackerAccountDB.characters[S:GetCharacterKey()]
local firstStamp = char.firstPickpocket
H.check("first stamped", firstStamp ~= nil)
H.check("last stamped",  char.lastPickpocket ~= nil)
S:RecordPickpocket()
H.eq("first never moves", char.firstPickpocket, firstStamp)

H.section("a second character accumulates separately but shares the account")
H.playerName = "Shanker"
local NS2 = H.reload(MODULES)       -- new login, same SavedVariables
local S2 = NS2.Stats
S2:Initialize()
H.eq("new character key", S2:GetCharacterKey(), "TestRealm-Shanker")
H.eq("two characters known", S2:GetCharacterCount(), 2)
H.eq("new character starts empty", S2:GetCharacterGold(), 0)
H.eq("account gold carried over",  S2:GetAccountGold(), 500)
S2:RecordGoldLooted(1000)
S2:RecordPickpocket()
H.eq("second character gold", S2:GetCharacterGold(), 1000)
H.eq("account gold is the sum", S2:GetAccountGold(), 1500)
H.eq("account casts are the sum", S2:GetAccountPickpocketCount(), 3)

H.section("ResetCharacter subtracts only that character from the account")
S2:ResetCharacter()
H.eq("reset character zeroed", S2:GetCharacterGold(), 0)
H.eq("reset character casts zeroed", S2:GetCharacterPickpocketCount(), 0)
H.eq("account keeps the other character's gold", S2:GetAccountGold(), 500)
H.eq("account keeps the other character's casts", S2:GetAccountPickpocketCount(), 2)
H.eq("other character untouched",
  PickPocketTrackerAccountDB.characters["TestRealm-Sneaky"].goldLooted, 500)
H.eq("both characters still listed", S2:GetCharacterCount(), 2)
H.check("timestamps cleared",
  PickPocketTrackerAccountDB.characters["TestRealm-Shanker"].firstPickpocket == nil)
H.check("reset announced in chat", H.chatHas("Character lifetime stats reset"))

H.section("account totals never go negative on corrupted data")
PickPocketTrackerAccountDB.totalGold = 10       -- character claims more than the account holds
PickPocketTrackerAccountDB.characters["TestRealm-Shanker"].goldLooted = 9999
S2:ResetCharacter()
H.eq("clamped at zero", S2:GetAccountGold(), 0)

H.section("ResetAccount clears every character")
local NS3 = H.newEnv(MODULES)
local S3  = NS3.Stats
H.playerName = "Sneaky"
S3:Initialize()
S3:RecordGoldLooted(300)
S3:RecordItemsSold(100)
S3:RecordPickpocket()
S3:RecordCoinsOfAir(5)
PickPocketTrackerAccountDB.characters["Other-Alt"] =
  { goldLooted = 900, itemsSold = 50, pickpocketCount = 4, coinsOfAir = 2 }
S3:ResetAccount()
H.eq("account gold zeroed",  S3:GetAccountGold(), 0)
H.eq("account items zeroed", S3:GetAccountItemsSold(), 0)
H.eq("account casts zeroed", S3:GetAccountPickpocketCount(), 0)
H.eq("account coins zeroed", S3:GetAccountCoins(), 0)
H.eq("this character zeroed", S3:GetCharacterGold(), 0)
H.eq("other character zeroed",
  PickPocketTrackerAccountDB.characters["Other-Alt"].goldLooted, 0)
H.eq("other character casts zeroed",
  PickPocketTrackerAccountDB.characters["Other-Alt"].pickpocketCount, 0)
H.eq("character list preserved", S3:GetCharacterCount(), 2)
H.check("reset announced in chat", H.chatHas("Account-wide lifetime stats reset"))

H.section("coinsOfAir is backfilled for records written before it existed")
local NS4 = H.newEnv(MODULES)
PickPocketTrackerAccountDB = {
  totalGold = 100, totalItemsSold = 0, totalPickpockets = 1, characters = {
    ["TestRealm-Sneaky"] = { name = "Sneaky", goldLooted = 100, itemsSold = 0,
                             pickpocketCount = 1 },   -- no coinsOfAir key
  },
}
NS4.Stats:Initialize()
H.eq("backfilled to zero", NS4.Stats:GetCharacterCoins(), 0)
H.eq("existing gold preserved", NS4.Stats:GetCharacterGold(), 100)
H.eq("missing account coins defaulted", NS4.Stats:GetAccountCoins(), 0)
NS4.Stats:RecordCoinsOfAir(4)
H.eq("recording works after backfill", NS4.Stats:GetCharacterCoins(), 4)

H.section("formatted output reports the real numbers")
local NS5 = H.newEnv(MODULES)
NS5.Stats:Initialize()
NS5.Stats:RecordGoldLooted(20000)
NS5.Stats:RecordItemsSold(10000)
NS5.Stats:RecordPickpocket()
NS5.Stats:RecordPickpocket()
local charText = NS5.Stats:GetCharacterStatsFormatted()
H.check("names the character", charText:find("Sneaky", 1, true) ~= nil)
H.check("reports 2 pickpockets", charText:find("Pickpockets: 2", 1, true) ~= nil)
H.check("has an average line",   charText:find("Average per pickpocket", 1, true) ~= nil)
H.check("omits coins when zero", charText:find("Coins of Air", 1, true) == nil)
NS5.Stats:RecordCoinsOfAir(7)
H.check("shows coins once earned",
  NS5.Stats:GetCharacterStatsFormatted():find("Coins of Air: 7", 1, true) ~= nil)

local accText = NS5.Stats:GetAccountStatsFormatted()
H.check("account header", accText:find("Account%-Wide") ~= nil)
H.check("character count", accText:find("Characters: 1", 1, true) ~= nil)
H.check("total pickpockets", accText:find("Total pickpockets: 2", 1, true) ~= nil)

H.section("averages do not divide by zero")
local NS6 = H.newEnv(MODULES)
NS6.Stats:Initialize()
local zeroText = NS6.Stats:GetCharacterStatsFormatted()
H.check("renders with no activity", type(zeroText) == "string" and #zeroText > 0)
H.check("account renders with no activity",
  type(NS6.Stats:GetAccountStatsFormatted()) == "string")

H.report()
