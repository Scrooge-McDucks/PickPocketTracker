-------------------------------------------------------------------------------
-- test_autosell.lua — the auto-sell ticker in items.lua
--
-- This is the riskiest code in the addon: it drives C_Container.UseContainerItem
-- on a timer, and away from a vendor that call *uses* an item instead of selling
-- it. These tests pin down both the safety guard and the behaviour when the
-- vendor refuses a sell request.
-------------------------------------------------------------------------------
local H = dofile(TESTS_DIR .. "/wow_stub.lua")
local MODULES = { "config.lua", "utils.lua", "data.lua", "tracking.lua",
                  "stats.lua", "items.lua" }

local NS, I, D, T, S

--- Fresh addon state with `tracked` of each item already pickpocketed.
local function fresh()
  NS = H.newEnv(MODULES)
  I, D, T, S = NS.Items, NS.Data, NS.Tracking, NS.Stats
  D:Initialize(); S:Initialize(); T:Initialize(); I:Initialize()
  D:SetChatLogItems(false)   -- keep the chat log for warnings only
end

--- Pickpocket `qty` of an item priced at `price`, and put a stack in a bag.
local function pickpocket(itemID, qty, price)
  H.defineItem(itemID, "Item" .. itemID, price)
  T:OnPickPocketCast()
  I:OnLootReceived("|Hitem:" .. itemID .. "|h", qty)
end

local maxStalls = nil

H.section("happy path: every tracked stack is sold, then the ticker stops")
fresh()
maxStalls = NS.Config.AUTOSELL_DEFAULTS.maxStalls
pickpocket(100, 5, 10)
pickpocket(200, 3, 25)
H.put(0, 1, 100, 5)
H.put(0, 2, 200, 3)
I:OnMerchantShow()
I:StartAutoSell()
H.tick(6)
H.eq("one sell call per stack", H.useCalls, 2)
H.check("both slots emptied", H.slot(0, 1) == nil and H.slot(0, 2) == nil)
H.eq("ticker stopped", H.liveTickers(), 0)
H.eq("no warning", H.chatCount(), 0)

H.merchantOpen = false
I:OnMerchantClosed()
H.eq("sales credited (5*10 + 3*25)", I:GetSessionVendorValue(), 125)
H.eq("lifetime stats credited", S:GetCharacterItemsSold(), 125)

H.section("auto-sell does nothing when the setting is off")
fresh()
pickpocket(100, 5, 10)
H.put(0, 1, 100, 5)
D:SetAutoSell(false)
I:OnMerchantShow()
I:StartAutoSell()
H.tick(5)
H.eq("no ticker created", H.liveTickers(), 0)
H.eq("no sell calls", H.useCalls, 0)
H.check("item still in the bag", H.slot(0, 1) ~= nil)

H.section("untracked items and oversized stacks are never sold")
fresh()
pickpocket(100, 2, 10)        -- only 2 pickpocketed
H.put(0, 1, 100, 5)           -- stack of 5 would oversell -> skip
H.put(0, 2, 999, 1)           -- never pickpocketed -> skip
I:OnMerchantShow()
I:StartAutoSell()
H.tick(5)
H.eq("nothing sold", H.useCalls, 0)
H.check("oversized stack untouched", H.slot(0, 1) ~= nil)
H.check("untracked item untouched",  H.slot(0, 2) ~= nil)

H.section("unsellable loot is never auto-sold")
fresh()
pickpocket(101, 1, 0)         -- vendor price 0 -> not a fence item
H.put(0, 1, 101, 1)
I:OnMerchantShow()
I:StartAutoSell()
H.tick(4)
H.eq("no sell calls", H.useCalls, 0)
H.check("item kept", H.slot(0, 1) ~= nil)

H.section("exactly-matching stacks are sold, larger ones are left")
fresh()
pickpocket(100, 3, 10)
H.put(0, 1, 100, 3)           -- equals the tracked quantity -> sellable
H.put(0, 2, 100, 4)           -- exceeds it -> must stay
I:OnMerchantShow()
I:StartAutoSell()
H.tick(5)
H.check("matching stack sold", H.slot(0, 1) == nil)
H.check("oversized stack kept", H.slot(0, 2) ~= nil)
H.eq("only one sell call", H.useCalls, 1)

H.section("a refused sell retries, then stops with a warning")
fresh()
pickpocket(100, 5, 10)
H.put(0, 1, 100, 5)
H.sellBlocked = true
I:OnMerchantShow()
I:StartAutoSell()
H.tick(12)
H.eq("retried exactly maxStalls times", H.useCalls, maxStalls)
H.eq("ticker stopped", H.liveTickers(), 0)
H.check("player was warned", H.chatHas("Auto-sell stopped"))
H.check("item still in the bag", H.slot(0, 1) ~= nil)
H.eq("nothing credited", I:GetSessionVendorValue(), 0)

H.section("a transient refusal recovers and the sale still completes")
fresh()
pickpocket(100, 5, 10)
H.put(0, 1, 100, 5)
H.sellBlocked = true
I:OnMerchantShow()
I:StartAutoSell()
H.tick(2)                     -- one refused attempt, one stall detected
H.check("still unsold", H.slot(0, 1) ~= nil)
H.sellBlocked = false         -- vendor starts responding
H.tick(3)
H.check("stack eventually sold", H.slot(0, 1) == nil)
H.check("no give-up warning", not H.chatHas("Auto-sell stopped"))
H.eq("ticker stopped cleanly", H.liveTickers(), 0)

H.section("the stall counter resets after a success, so it is not cumulative")
fresh()
pickpocket(100, 1, 10)
pickpocket(200, 1, 10)
pickpocket(300, 1, 10)
H.put(0, 1, 100, 1)
H.put(0, 2, 200, 1)
H.put(0, 3, 300, 1)
I:OnMerchantShow()
I:StartAutoSell()
for _ = 1, 3 do               -- alternate: refuse once, then succeed
  H.sellBlocked = true;  H.tick(1)
  H.sellBlocked = false; H.tick(2)
end
H.check("all three sold despite repeated stalls",
  H.slot(0, 1) == nil and H.slot(0, 2) == nil and H.slot(0, 3) == nil)
H.check("never gave up", not H.chatHas("Auto-sell stopped"))

H.section("the vendor closing mid-run never uses an item outside the vendor")
fresh()
pickpocket(100, 5, 10)
pickpocket(200, 5, 10)
H.put(0, 1, 100, 5)
H.put(0, 2, 200, 5)
I:OnMerchantShow()
I:StartAutoSell()
H.tick(1)
H.merchantOpen = false        -- player walks away; ticker not yet cancelled
H.tick(5)
H.check("no UseContainerItem away from a vendor", H.usedOutsideMerchant == false)
H.check("second stack untouched", H.slot(0, 2) ~= nil)
H.eq("ticker self-cancelled", H.liveTickers(), 0)

H.section("MERCHANT_CLOSED cancels the ticker and clears its bookkeeping")
fresh()
pickpocket(100, 5, 10)
pickpocket(200, 5, 10)
H.put(0, 1, 100, 5)
H.put(0, 2, 200, 5)
I:OnMerchantShow()
I:StartAutoSell()
H.tick(1)
H.eq("ticker was running", H.liveTickers(), 1)
H.merchantOpen = false
I:OnMerchantClosed()
H.eq("ticker cancelled", H.liveTickers(), 0)
H.check("pending cleared", I.autoSellPending == nil)
H.check("last attempt cleared", I.autoSellLast == nil)
H.eq("stall counter reset", I.autoSellStalls, 0)

H.section("StartAutoSell is idempotent")
fresh()
pickpocket(100, 5, 10)
H.put(0, 1, 100, 5)
I:OnMerchantShow()
I:StartAutoSell()
I:StartAutoSell()
I:StartAutoSell()
H.eq("only one ticker", H.liveTickers(), 1)
H.tick(3)
H.eq("stack sold once", H.useCalls, 1)

H.section("StopAutoSell is safe to call when nothing is running")
fresh()
I:StopAutoSell()
I:StopAutoSell()
H.check("no ticker", H.liveTickers() == 0)
H.check("state clean", I.autoSellLast == nil and I.autoSellStalls == 0)

H.section("auto-sell and manual selling agree on the final credit")
fresh()
pickpocket(100, 4, 30)
H.put(0, 1, 100, 4)
I:OnMerchantShow()
I:StartAutoSell()
H.tick(4)
H.merchantOpen = false
I:OnMerchantClosed()
H.eq("credited once, not twice", I:GetSessionVendorValue(), 4 * 30)
H.eq("sold quantity exact", D:GetItem(100).soldQuantity, 4)
H.eq("remaining quantity zero", D:GetItem(100).quantity, 0)

H.section("keep list: a kept item is never auto-sold")
fresh()
pickpocket(100, 5, 10)      -- junk
pickpocket(300, 2, 40)      -- a potion the player wants
H.put(0, 1, 100, 5)
H.put(0, 2, 300, 2)
D:SetKeptItem(300, "Potion")
H.eq("kept item is not pending vendor value", I:GetUnsoldValue(), 50)
I:OnMerchantShow()
I:StartAutoSell()
H.tick(6)
H.check("junk sold", H.slot(0, 1) == nil)
H.check("kept item still in bags", H.slot(0, 2) ~= nil)
H.eq("only one sell call", H.useCalls, 1)
H.eq("ticker stopped", H.liveTickers(), 0)
H.eq("no stall warning", H.chatCount(), 0)
H.check("stats mark it as kept", I:GetDetailedStats():find("[kept]", 1, true) ~= nil)

H.section("keep list: selling a kept item by hand is still credited")
H.bags[0][2] = nil          -- player sells it manually
H.merchantOpen = false
I:OnMerchantClosed()
H.eq("junk + manual sale credited", I:GetSessionVendorValue(), 5 * 10 + 2 * 40)

H.section("keep list: removing an item lets auto-sell take it again")
fresh()
pickpocket(300, 2, 40)
H.put(0, 1, 300, 2)
D:SetKeptItem(300)
D:RemoveKeptItem(300)
I:OnMerchantShow()
I:StartAutoSell()
H.tick(4)
H.check("sold once un-kept", H.slot(0, 1) == nil)

H.section("junk only: grey items sell, better ones are kept")
fresh()
pickpocket(100, 5, 10)
pickpocket(300, 2, 40)
H.itemDB[100].quality = 0   -- poor
H.itemDB[300].quality = 1   -- common
H.put(0, 1, 100, 5)
H.put(0, 2, 300, 2)
D:SetAutoSellJunkOnly(true)
I:OnMerchantShow()
I:StartAutoSell()
H.tick(6)
H.check("grey item sold", H.slot(0, 1) == nil)
H.check("white item kept", H.slot(0, 2) ~= nil)
H.eq("ticker stopped", H.liveTickers(), 0)

H.section("junk only: an item of unknown quality is kept, not sold")
H.check("unknown quality refused", I:MayAutoSell(100, nil) == false)
D:SetAutoSellJunkOnly(false)
H.check("with junk-only off it may sell", I:MayAutoSell(100, nil) == true)

H.section("junk only: non-junk items are not pending vendor value")
fresh()
H.defineItem(100, "Item100", 10, nil, 0)   -- grey
H.defineItem(300, "Item300", 40, nil, 1)   -- white
T:OnPickPocketCast()
I:OnLootReceived("|Hitem:100|h", 5)
I:OnLootReceived("|Hitem:300|h", 2)
H.eq("quality recorded with the item", D:GetItem(300).quality, 1)
H.eq("junk-only off: both pending", I:GetUnsoldValue(), 5 * 10 + 2 * 40)
D:SetAutoSellJunkOnly(true)
H.eq("junk-only on: only the grey item pending", I:GetUnsoldValue(), 5 * 10)
H.eq("confirmed haul total never includes pending items", T:GetTotalValue(), 0)
H.check("stats mark the white item as kept", I:GetDetailedStats():find("Item300 [kept]", 1, true) ~= nil)
H.check("grey item not marked", I:GetDetailedStats():find("Item100 [kept]", 1, true) == nil)
D:SetAutoSellJunkOnly(false)
H.eq("switching it off restores pending", I:GetUnsoldValue(), 5 * 10 + 2 * 40)

H.section("keep list survives a reload")
D:SetKeptItem(300, "Potion")
NS = H.reload(MODULES)
NS.Data:Initialize()
H.check("still kept after reload", NS.Data:IsKeptItem(300))
H.eq("name preserved", NS.Data:GetKeptItems()[300], "Potion")

H.report()
