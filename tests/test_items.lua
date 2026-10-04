-------------------------------------------------------------------------------
-- test_items.lua — loot attribution, fence eligibility, vendor-sale detection
-- (the auto-sell ticker has its own file: test_autosell.lua)
-------------------------------------------------------------------------------
local H = dofile(TESTS_DIR .. "/wow_stub.lua")
local MODULES = { "config.lua", "utils.lua", "data.lua", "tracking.lua",
                  "stats.lua", "items.lua" }

local NS = H.newEnv(MODULES)
local I, D, T, S = NS.Items, NS.Data, NS.Tracking, NS.Stats

local function fresh()
  NS = H.newEnv(MODULES)
  I, D, T, S = NS.Items, NS.Data, NS.Tracking, NS.Stats
  D:Initialize()
  S:Initialize()
  T:Initialize()
  I:Initialize()
  return NS
end

H.section("ExtractItemID pulls the id out of an item link")
fresh()
H.eq("plain link", I:ExtractItemID("|Hitem:12345|h"), 12345)
H.eq("full link",  I:ExtractItemID("|Hitem:6948:0:0:0:0:0:0:0:80:0|h"), 6948)
H.check("no link",      I:ExtractItemID("just text") == nil)
H.check("nil input",    I:ExtractItemID(nil) == nil)
H.check("spell link rejected", I:ExtractItemID("|Hspell:921|h") == nil)

H.section("Initialize starts every session clean")
fresh()
D:SetItem(1, { name = "stale", quantity = 1 })
I:Initialize()
H.eq("items cleared on login", D:GetItemCount(), 0)
H.eq("session vendor value zeroed", I:GetSessionVendorValue(), 0)

H.section("loot is only attributed inside the detection window")
fresh()
H.defineItem(100, "Silk Cloth", 50)
I:OnLootReceived("|Hitem:100|h", 2)
H.eq("no cast yet, nothing tracked", D:GetItemCount(), 0)

T:OnPickPocketCast()
I:OnLootReceived("|Hitem:100|h", 2)
H.eq("tracked after a cast", D:GetItemCount(), 1)
H.eq("quantity recorded", D:GetItem(100).quantity, 2)

H.advance(T:GetDetectionWindow() + 1)
I:OnLootReceived("|Hitem:100|h", 5)
H.eq("ignored once the window closed", D:GetItem(100).quantity, 2)

H.section("repeat loot accumulates quantity and value")
fresh()
H.defineItem(100, "Silk Cloth", 50)
T:OnPickPocketCast()
I:OnLootReceived("|Hitem:100|h", 2)
I:OnLootReceived("|Hitem:100|h", 3)
H.eq("still one unique item", D:GetItemCount(), 1)
H.eq("quantity summed", D:GetItem(100).quantity, 5)
H.eq("value summed",    D:GetItem(100).totalValue, 5 * 50)

H.section("only items with a sell price become fence items")
fresh()
H.defineItem(100, "Silk Cloth", 50)
H.defineItem(101, "Crumpled Note", 0)
T:OnPickPocketCast()
I:OnLootReceived("|Hitem:100|h", 1)
I:OnLootReceived("|Hitem:101|h", 1)
H.check("sellable is a fence item",      D:GetItem(100).isFence == true)
H.check("unsellable is not",             D:GetItem(101).isFence == false)
H.eq("unsellable still tracked",         D:GetItemCount(), 2)
H.eq("unsellable has zero value",        D:GetItem(101).totalValue, 0)
H.eq("unsold value counts fence only",   I:GetUnsoldValue(), 50)
H.eq("unique count includes both",       I:GetUniqueItemCount(), 2)

H.section("a vendor price arriving late is backfilled onto earlier loot")
fresh()
T:OnPickPocketCast()
H.defineItem(102, "Mystery Box", 0)        -- cached, but price not yet known
I:OnLootReceived("|Hitem:102|h", 4)
H.check("initially not a fence item", D:GetItem(102).isFence == false)
H.eq("initially valued at zero", D:GetItem(102).totalValue, 0)

H.defineItem(102, "Mystery Box", 25)       -- real price shows up
I:OnLootReceived("|Hitem:102|h", 1)
local box = D:GetItem(102)
H.check("promoted to fence item", box.isFence == true)
H.eq("vendor price corrected", box.vendorPrice, 25)
H.eq("quantity is 5", box.quantity, 5)
-- The earlier 4 are revalued, then the new 1 is added: 4*25 + 1*25.
H.eq("earlier loot revalued", box.totalValue, 5 * 25)
H.eq("unsold value reflects the fix", I:GetUnsoldValue(), 5 * 25)

H.section("chat logging can be turned off")
fresh()
H.defineItem(100, "Silk Cloth", 50)
D:SetChatLogItems(false)
T:OnPickPocketCast()
I:OnLootReceived("|Hitem:100|h", 1)
H.eq("silent when disabled", H.chatCount(), 0)
D:SetChatLogItems(true)
I:OnLootReceived("|Hitem:100|h", 1)
H.check("announced when enabled", H.chatHas("Pickpocketed: 1x Silk Cloth"))

H.defineItem(101, "Crumpled Note", 0)
I:OnLootReceived("|Hitem:101|h", 1)
H.check("unsellable loot is flagged as such", H.chatHas("unsellable"))

H.section("vendor sales are detected by diffing the bag snapshot")
fresh()
H.defineItem(100, "Silk Cloth", 50)
T:OnPickPocketCast()
I:OnLootReceived("|Hitem:100|h", 5)
H.put(0, 1, 100, 5)

I:OnMerchantShow()
H.bags[0][1] = nil                 -- player sells the stack by hand
I:OnMerchantClosed()
H.eq("sold quantity recorded",  D:GetItem(100).soldQuantity, 5)
H.eq("remaining quantity drops", D:GetItem(100).quantity, 0)
H.eq("sold value recorded",      D:GetItem(100).soldValue, 5 * 50)
H.eq("session vendor value",     I:GetSessionVendorValue(), 5 * 50)
H.eq("lifetime items-sold recorded", S:GetCharacterItemsSold(), 5 * 50)
H.eq("nothing left unsold",      I:GetUnsoldValue(), 0)

H.section("a partial sale credits only what actually left the bags")
fresh()
H.defineItem(100, "Silk Cloth", 50)
T:OnPickPocketCast()
I:OnLootReceived("|Hitem:100|h", 5)
H.put(0, 1, 100, 3)
H.put(0, 2, 100, 2)
I:OnMerchantShow()
H.bags[0][2] = nil                 -- only the stack of 2 is sold
I:OnMerchantClosed()
H.eq("two credited",     D:GetItem(100).soldQuantity, 2)
H.eq("three remaining",  D:GetItem(100).quantity, 3)
H.eq("value for two",    I:GetSessionVendorValue(), 2 * 50)

H.section("buying or looting during a vendor visit is never credited as a sale")
fresh()
H.defineItem(100, "Silk Cloth", 50)
T:OnPickPocketCast()
I:OnLootReceived("|Hitem:100|h", 2)
H.put(0, 1, 100, 2)
I:OnMerchantShow()
H.put(0, 3, 100, 10)               -- bag count goes UP
I:OnMerchantClosed()
H.eq("no sale recorded", D:GetItem(100).soldQuantity, 0)
H.eq("quantity untouched", D:GetItem(100).quantity, 2)
H.eq("no vendor value", I:GetSessionVendorValue(), 0)

H.section("selling untracked items of a tracked id never over-credits")
fresh()
H.defineItem(100, "Silk Cloth", 50)
T:OnPickPocketCast()
I:OnLootReceived("|Hitem:100|h", 2)   -- only 2 were pickpocketed
H.put(0, 1, 100, 20)                   -- but 20 are in the bag (bought/farmed)
I:OnMerchantShow()
H.bags[0][1] = nil                     -- all 20 sold
I:OnMerchantClosed()
H.eq("credited only the tracked 2", D:GetItem(100).soldQuantity, 2)
H.eq("value for 2 only", I:GetSessionVendorValue(), 2 * 50)

H.section("unsellable items are excluded from sale detection")
fresh()
H.defineItem(101, "Crumpled Note", 0)
T:OnPickPocketCast()
I:OnLootReceived("|Hitem:101|h", 1)
H.put(0, 1, 101, 1)
I:OnMerchantShow()
H.bags[0][1] = nil
I:OnMerchantClosed()
H.eq("no sale credited", D:GetItem(101).soldQuantity, 0)
H.eq("no vendor value",  I:GetSessionVendorValue(), 0)

H.section("MERCHANT_CLOSED without a snapshot is harmless")
fresh()
I.vendorSnapshot = nil
I:OnMerchantClosed()
H.eq("no crash, no value", I:GetSessionVendorValue(), 0)

H.section("ResetSession clears tracked items and session value")
fresh()
H.defineItem(100, "Silk Cloth", 50)
T:OnPickPocketCast()
I:OnLootReceived("|Hitem:100|h", 5)
H.put(0, 1, 100, 5)
I:OnMerchantShow()
H.bags[0][1] = nil
I:OnMerchantClosed()
H.check("value accrued before reset", I:GetSessionVendorValue() > 0)
I:ResetSession()
H.eq("items cleared", D:GetItemCount(), 0)
H.eq("session value cleared", I:GetSessionVendorValue(), 0)
H.eq("unsold value cleared",  I:GetUnsoldValue(), 0)
H.check("lifetime stats are NOT cleared", S:GetCharacterItemsSold() > 0)

H.section("GetDetailedStats renders without error")
fresh()
H.defineItem(100, "Silk Cloth", 50)
T:OnPickPocketCast()
I:OnLootReceived("|Hitem:100|h", 3)
local text = I:GetDetailedStats()
H.check("returns a string", type(text) == "string" and #text > 0)
H.check("mentions the item", text:find("Silk Cloth", 1, true) ~= nil)
fresh()
H.check("renders when empty", type(I:GetDetailedStats()) == "string")

H.report()
