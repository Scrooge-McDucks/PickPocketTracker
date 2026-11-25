-------------------------------------------------------------------------------
-- test_lockbox.lua — gold from opening pickpocketed lockboxes
--
-- Loads the whole addon and drives it with real events: pickpocket a junkbox,
-- wait, right-click it in the bags, loot it. Covers the on/off option, boxes
-- that were not pickpocketed, corpse loot, vendor sales and reloads.
-------------------------------------------------------------------------------
local H = dofile(TESTS_DIR .. "/wow_stub.lua")

local FILES  = H.tocFiles()
local unpack = H.unpack
local NS

local BOX, CLOTH, CLAM = 16885, 100, 5523
local ITEM_GUID  = "Item-1-0-4000000012345678"
local MOB_GUID   = "Creature-0-1-2-3-4-0000000001"

local function fire(event, args, n)
  NS.Events:OnEvent(event, unpack(args or {}, 1, n or 0))
end

local function login()
  NS = H.newEnv(FILES)
  fire("PLAYER_LOGIN")
  NS.Data:SetChatLogItems(false)
  H.defineItem(BOX, "Heavy Junkbox", 0)
  H.defineItem(CLOTH, "Silk Cloth", 50)
  H.itemDB[BOX].openable = true
  H.merchantOpen = false
  H.autoRunAfters = true        -- the close-grace timer fires straight away
  H.money = 0
  fire("PLAYER_MONEY")          -- settle the money baseline
end

--- Pickpocket `itemID` into bag 0 at `slot`, then let the window lapse.
local function pickpocket(itemID, slot)
  fire("UNIT_SPELLCAST_SUCCEEDED", { "player", "c", NS.Config.PICK_POCKET_SPELL_ID }, 3)
  local a = {}
  a[1]  = "You receive loot: |Hitem:" .. itemID .. ":0|h[Thing]|h."
  a[12] = UnitGUID("player")
  fire("CHAT_MSG_LOOT", a, 12)
  H.put(0, slot, itemID, 1)
  H.advance(60)
end

--- Right-click a bag slot and loot `copper` from a window sourced by `guid`.
local function openAndLoot(slot, copper, guid, consume)
  C_Container.UseContainerItem(0, slot)
  H.loot = { guid or ITEM_GUID }
  fire("LOOT_READY")
  fire("LOOT_OPENED")
  if copper and copper > 0 then
    H.money = H.money + copper
    fire("PLAYER_MONEY")
  end
  if consume ~= false then H.bags[0][slot] = nil end
  H.loot = {}
  fire("LOOT_CLOSED")
end

H.section("gold in a pickpocketed junkbox counts, long after the pickpocket")
login()
pickpocket(BOX, 1)
H.eq("box remembered", NS.Data:GetPocketedCount(BOX), 1)
H.eq("nothing counted yet", NS.Tracking:GetSessionGold(), 0)
openAndLoot(1, 4200)
H.eq("gold counted", NS.Tracking:GetSessionGold(), 4200)
H.eq("flagged as lockbox gold", NS.Tracking:GetSessionLockboxGold(), 4200)
H.eq("in the haul total", NS.Tracking:GetTotalValue(), 4200)
H.eq("in lifetime character gold", NS.Stats:GetCharacterGold(), 4200)
H.eq("in lifetime account gold", NS.Stats:GetAccountGold(), 4200)
H.check("haul window refreshed",
  (NS.UI.mainFrame.text:GetText() or ""):find("Haul", 1, true) ~= nil)
H.eq("tooltip breakdown cached", NS.UI.cachedLockbox, 4200)

H.section("auto-loot: money arriving just after LOOT_CLOSED still counts")
login()
pickpocket(BOX, 1)
H.autoRunAfters = false         -- let the close-grace timer wait
openAndLoot(1, 0)
H.advance(0.5)
H.money = H.money + 900
fire("PLAYER_MONEY")
H.eq("held until the bags are checked", NS.Tracking:GetSessionGold(), 0)
H.runAfters()
H.autoRunAfters = true
H.eq("late gold counted", NS.Tracking:GetSessionGold(), 900)

H.section("the box is spent afterwards")
H.advance(5)
H.money = H.money + 5000
fire("PLAYER_MONEY")
H.eq("unrelated gold later is ignored", NS.Tracking:GetSessionGold(), 900)
H.eq("box forgotten once opened", NS.Data:GetPocketedCount(BOX), 0)
H.defineItem(CLAM, "Small Barnacled Clam", 0)
H.itemDB[CLAM].openable = true
H.put(0, 2, CLAM, 1)            -- an openable item that wasn't pickpocketed
openAndLoot(2, 7000)
H.eq("an openable item from elsewhere is not counted", NS.Tracking:GetSessionGold(), 900)

H.section("the option switches it off, and back on")
login()
H.check("on by default", NS.Data:ShouldTrackLockboxes() == true)
pickpocket(BOX, 1)
SlashCmdList["PICKPOCKETTRACKER"]("lockbox off")
H.check("slash command turns it off", NS.Data:ShouldTrackLockboxes() == false)
openAndLoot(1, 3000, ITEM_GUID, false)
H.eq("nothing counted while off", NS.Tracking:GetSessionGold(), 0)
H.eq("box still remembered", NS.Data:GetPocketedCount(BOX), 1)
SlashCmdList["PICKPOCKETTRACKER"]("lockbox on")
H.advance(10)
openAndLoot(1, 3000)
H.eq("counted once back on", NS.Tracking:GetSessionGold(), 3000)
SlashCmdList["PICKPOCKETTRACKER"]("lockbox")
H.check("bare command toggles", NS.Data:ShouldTrackLockboxes() == false)
SlashCmdList["PICKPOCKETTRACKER"]("lockbox maybe")
H.check("bad argument explains usage", H.chatHas("Usage: /pp lockbox"))

H.section("corpse loot right after using a pickpocketed item is not lockbox gold")
login()
H.itemDB[CLOTH].openable = true   -- stays in the bag when "used"
pickpocket(CLOTH, 1)
openAndLoot(1, 8000, MOB_GUID, false)
H.eq("mob gold ignored", NS.Tracking:GetSessionGold(), 0)

H.section("another container opened while a junkbox sits in the bags is not counted")
login()
pickpocket(BOX, 1)
H.defineItem(CLAM, "Small Barnacled Clam", 0)
H.put(0, 2, CLAM, 1)
H.loot = { ITEM_GUID }          -- client can't say which item
fire("LOOT_READY")
H.money = H.money + 1000
fire("PLAYER_MONEY")
H.bags[0][2] = nil              -- the clam is used up, the box stays
H.loot = {}
fire("LOOT_CLOSED")
H.eq("clam gold not counted", NS.Tracking:GetSessionGold(), 0)
H.eq("box still remembered", NS.Data:GetPocketedCount(BOX), 1)

H.section("closing the loot window untouched keeps the box for later")
login()
pickpocket(BOX, 1)
openAndLoot(1, 0, ITEM_GUID, false)
H.advance(10)
H.check("no longer looting", NS.Lockbox:IsLooting() == false)
H.eq("still remembered", NS.Data:GetPocketedCount(BOX), 1)
openAndLoot(1, 600)
H.eq("counted on the second try", NS.Tracking:GetSessionGold(), 600)

H.section("selling at a vendor is never treated as opening")
login()
pickpocket(CLOTH, 1)
H.merchantOpen = true
fire("MERCHANT_SHOW")
H.tick(3)                       -- auto-sell uses the same UseContainerItem call
H.check("no loot window watched after a sale", NS.Lockbox.active == nil)
H.merchantOpen = false
fire("MERCHANT_CLOSED")
H.eq("sold item no longer remembered", NS.Data:GetPocketedCount(CLOTH), 0)
H.eq("sale gold is not lockbox gold", NS.Tracking:GetSessionLockboxGold(), 0)

H.section("a box pickpocketed in an earlier session still counts after a reload")
login()
pickpocket(BOX, 1)
NS = H.reload(FILES)
fire("PLAYER_LOGIN")
NS.Data:SetChatLogItems(false)
H.eq("session items were cleared", NS.Data:GetItemCount(), 0)
H.eq("box survived the reload", NS.Data:GetPocketedCount(BOX), 1)
H.advance(5)
openAndLoot(1, 1500)
H.eq("gold counted after reload", NS.Tracking:GetSessionGold(), 1500)

H.section("works on the WoW Forever client (interface 16001)")
H.resetWorld()
PickPocketTrackerDB, PickPocketTrackerAccountDB = nil, nil
H.tocVersion = 16001
NS = H.reload(FILES)
fire("PLAYER_LOGIN")
NS.Data:SetChatLogItems(false)
H.check("client detected as pre-Legion", NS.Config.HAS_COINS_OF_AIR == false)
H.defineItem(BOX, "Heavy Junkbox", 0)
H.itemDB[BOX].openable = true
H.merchantOpen = false
pickpocket(BOX, 1)
openAndLoot(1, 2500)
H.eq("lockbox gold counted on Forever", NS.Tracking:GetSessionGold(), 2500)

H.section("a client without GetLootSourceInfo still counts the box")
login()
local savedSource = GetLootSourceInfo
GetLootSourceInfo = nil
NS = H.reload(FILES)            -- lockbox.lua reads the global at call time
fire("PLAYER_LOGIN")
NS.Data:SetChatLogItems(false)
pickpocket(BOX, 1)
openAndLoot(1, 300)
GetLootSourceInfo = savedSource
H.eq("counted without a loot source API", NS.Tracking:GetSessionGold(), 300)

H.section("box opened by a bag addon or macro (no Blizzard bag click) still counts")
login()
pickpocket(BOX, 1)
H.guidItems[ITEM_GUID] = BOX
H.loot = { ITEM_GUID }          -- loot window opens without UseContainerItem
fire("LOOT_READY")
fire("LOOT_OPENED")
H.money = H.money + 1800
fire("PLAYER_MONEY")
H.bags[0][1] = nil
H.loot = {}
fire("LOOT_CLOSED")
H.eq("counted from the loot window alone", NS.Tracking:GetSessionGold(), 1800)
H.advance(5)
H.check("looting ended", NS.Lockbox:IsLooting() == false)
H.eq("box spent", NS.Data:GetPocketedCount(BOX), 0)

H.section("a junkbox pickpocketed before lockbox tracking existed still counts")
login()
H.put(0, 3, BOX, 1)             -- never seen by CHAT_MSG_LOOT
H.eq("not on the remembered list", NS.Data:GetPocketedCount(BOX), 0)
H.guidItems[ITEM_GUID] = BOX
H.loot = { ITEM_GUID }
fire("LOOT_READY")
H.money = H.money + 2200
fire("PLAYER_MONEY")
H.loot = {}
fire("LOOT_CLOSED")
H.eq("old junkbox counted by name", NS.Tracking:GetSessionGold(), 2200)
H.advance(5)
NS.Lockbox:IsLooting()
H.eq("count never goes negative", NS.Data:GetPocketedCount(BOX), 0)

H.section("an item that isn't a pickpocketed box is ignored even when mapped")
login()
H.defineItem(CLAM, "Small Barnacled Clam", 0)
H.guidItems[ITEM_GUID] = CLAM
H.loot = { ITEM_GUID }
fire("LOOT_READY")
H.money = H.money + 999
fire("PLAYER_MONEY")
H.loot = {}
fire("LOOT_CLOSED")
H.eq("clam gold not counted", NS.Tracking:GetSessionGold(), 0)

H.section("bag addon + client that can't name the item: the box leaving the bags confirms it")
login()
pickpocket(BOX, 1)
H.loot = { ITEM_GUID }          -- no GUID mapping, no Blizzard bag click
fire("LOOT_READY")
fire("LOOT_OPENED")
H.money = H.money + 3300
fire("PLAYER_MONEY")
H.bags[0][1] = nil
H.loot = {}
fire("LOOT_CLOSED")
H.eq("counted from the bag check alone", NS.Tracking:GetSessionGold(), 3300)
H.eq("box forgotten", NS.Data:GetPocketedCount(BOX), 0)

H.section("gold taken but items left in the box")
login()
pickpocket(BOX, 1)
H.guidItems[ITEM_GUID] = BOX    -- client names the item
H.loot = { ITEM_GUID }
fire("LOOT_READY")
H.money = H.money + 700
fire("PLAYER_MONEY")
H.loot = {}
fire("LOOT_CLOSED")             -- box still in the bags
H.eq("counted when the client names the box", NS.Tracking:GetSessionGold(), 700)
H.eq("box kept for its remaining items", NS.Data:GetPocketedCount(BOX), 1)

H.section("a loot window left open is not watched forever")
login()
pickpocket(BOX, 1)
H.loot = { ITEM_GUID }
fire("LOOT_READY")
H.check("watching", NS.Lockbox:IsLooting())
H.advance(NS.Config.LOCKBOX_DEFAULTS.maxOpen + 1)
H.money = H.money + 500
fire("PLAYER_MONEY")
H.check("stopped watching", NS.Lockbox.active == nil)
H.eq("later gold not held", NS.Tracking:GetSessionGold(), 0)

H.section("no box in the bags means nothing is watched")
login()
H.loot = { ITEM_GUID }
fire("LOOT_READY")
H.check("nothing watched", NS.Lockbox.active == nil)

H.section("lockbox debug prints what it sees")
login()
SlashCmdList["PICKPOCKETTRACKER"]("lockbox debug")
H.check("debug switched on", NS.Lockbox.debug == true)
pickpocket(BOX, 1)
H.guidItems[ITEM_GUID] = BOX
H.loot = { ITEM_GUID }
fire("LOOT_READY")
H.check("debug line printed", H.chatHas("[lockbox] loot opened"))
H.loot = {}
fire("LOOT_CLOSED")
H.check("debug reports the result", H.chatHas("[lockbox] loot closed"))
H.loot = { MOB_GUID }
fire("LOOT_READY")
H.check("corpse loot reported as ignored", H.chatHas("from the world, ignored"))
H.loot = {}
fire("LOOT_CLOSED")
SlashCmdList["PICKPOCKETTRACKER"]("lockbox debug")
H.check("debug switched off", NS.Lockbox.debug == false)

H.section("gold inside the pickpocket window is ordinary pickpocket gold")
login()
fire("UNIT_SPELLCAST_SUCCEEDED", { "player", "c", NS.Config.PICK_POCKET_SPELL_ID }, 3)
H.money = H.money + 250
fire("PLAYER_MONEY")
H.eq("counted", NS.Tracking:GetSessionGold(), 250)
H.eq("not as lockbox gold", NS.Tracking:GetSessionLockboxGold(), 0)

H.section("session reset clears lockbox gold; lifetime timestamps untouched")
login()
pickpocket(BOX, 1)
local key  = NS.Stats:GetCharacterKey()
local last = PickPocketTrackerAccountDB.characters[key].lastPickpocket
PickPocketTrackerAccountDB.characters[key].lastPickpocket = 111
openAndLoot(1, 800)
H.eq("opening a box does not move 'last pickpocket'",
  PickPocketTrackerAccountDB.characters[key].lastPickpocket, 111)
H.check("it had been set by the pickpocket", last ~= nil)
NS.Tracking:ResetSession()
H.eq("lockbox gold zeroed", NS.Tracking:GetSessionLockboxGold(), 0)

H.section("chat line and /pp stats breakdown")
login()
NS.Data:SetChatLogItems(true)
pickpocket(BOX, 1)
openAndLoot(1, 1200)
H.check("chat reports lockbox gold", H.chatHas("Lockbox gold"))
H.check("/pp stats shows the breakdown",
  NS.Items:GetDetailedStats():find("from lockboxes", 1, true) ~= nil)

H.report()
