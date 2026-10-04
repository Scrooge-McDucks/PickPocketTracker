-------------------------------------------------------------------------------
-- test_utils.lua — money formatting, string/table/math helpers, item lookup
-------------------------------------------------------------------------------
local H  = dofile(TESTS_DIR .. "/wow_stub.lua")
local NS = H.newEnv({ "config.lua", "utils.lua" })
local U  = NS.Utils

local G, S = 10000, 100   -- copper per gold / per silver

H.section("FormatMoneyCompact picks the largest meaningful unit")
H.eq("25 copper",            U:FormatMoneyCompact(25),            "25c")
H.eq("50s 10c",              U:FormatMoneyCompact(50 * S + 10),   "50s 10c")
H.eq("5g 20s drops copper",  U:FormatMoneyCompact(5 * G + 20 * S + 30), "5g 20s")
H.eq("zero",                 U:FormatMoneyCompact(0),             "0c")
H.eq("exactly 1 gold",       U:FormatMoneyCompact(G),             "1g 0s")
H.eq("1 silver boundary",    U:FormatMoneyCompact(S),             "1s 0c")
H.eq("99c stays copper",     U:FormatMoneyCompact(99),            "99c")

H.section("FormatMoney embeds the three coin icons")
local full = U:FormatMoney(5 * G + 20 * S + 30)
H.check("starts with gold amount", full:match("^5|T") ~= nil, full)
H.check("has three |T textures",   select(2, full:gsub("|T", "")) == 3, full)
H.check("includes silver 20",      full:find("20|T", 1, true) ~= nil, full)
H.check("includes copper 30",      full:find("30|T", 1, true) ~= nil, full)
H.check("zero renders without error", U:FormatMoney(0):find("0|T", 1, true) ~= nil)

H.section("TrimString")
H.eq("both ends",      U:TrimString("  hello  "), "hello")
H.eq("inner space kept", U:TrimString("  a b  "), "a b")
H.eq("already trimmed", U:TrimString("x"),        "x")
H.eq("all whitespace",  U:TrimString("    "),     "")

H.section("Clamp")
H.eq("below range", U:Clamp(-5, 0, 10), 0)
H.eq("above range", U:Clamp(99, 0, 10), 10)
H.eq("in range",    U:Clamp(7,  0, 10), 7)
H.eq("on lower bound", U:Clamp(0, 0, 10), 0)
H.eq("on upper bound", U:Clamp(10, 0, 10), 10)

H.section("TableSortBy orders highest score first")
local sorted = U:TableSortBy(
  { a = { v = 5 }, b = { v = 50 }, c = { v = 25 } },
  function(e) return e.v end)
H.eq("three entries", #sorted, 3)
H.eq("1st is b",      sorted[1].key, "b")
H.eq("2nd is c",      sorted[2].key, "c")
H.eq("3rd is a",      sorted[3].key, "a")
H.eq("empty table",   #U:TableSortBy({}, function(e) return e end), 0)

H.section("GetVendorPrice reads sell price from the item cache")
H.defineItem(100, "Shiny Trinket", 250)
H.eq("known item",   U:GetVendorPrice(100), 250)
H.eq("unknown item is 0", U:GetVendorPrice(404), 0)
H.defineItem(101, "Quest Letter", 0)
H.eq("unsellable item is 0", U:GetVendorPrice(101), 0)

H.section("GetItemInfo retries on a cache miss, then gives up")
H.autoRunAfters = false
local got = nil
U:GetItemInfo(900, function(id, name) got = { id = id, name = name } end)
H.check("no callback while uncached", got == nil)
H.check("a retry was scheduled", #H.afters == 1, #H.afters)
H.defineItem(900, "Late Arrival", 10)   -- cache fills in
H.runAfters(1)
H.check("callback fires once cached", got ~= nil)
H.eq("callback item id",   got and got.id,   900)
H.eq("callback item name", got and got.name, "Late Arrival")

local never = false
U:GetItemInfo(901, function() never = true end)
H.runAfters(NS.Config.ITEM_CACHE_MAX_RETRIES + 2)
H.check("never-cached item never calls back", never == false)
H.check("retries stop (queue drained)", #H.afters == 0, #H.afters)
H.autoRunAfters = true

H.section("CreateBagSnapshot totals stacks per item across all bags")
H.put(0, 1, 100, 5)
H.put(0, 2, 100, 3)   -- same item, second stack
H.put(2, 4, 200, 1)   -- different bag
local snap = U:CreateBagSnapshot()
H.eq("item 100 totals both stacks", snap[100], 8)
H.eq("item 200 counted",            snap[200], 1)
H.check("absent item is nil",       snap[999] == nil)

H.section("chat helpers route through the addon tag")
U:PrintInfo("hello world")
H.check("message captured",      H.chatHas("hello world"))
H.check("prefixed with addon name", H.chatHas("PickPocketTracker:"))
U:PrintError("bad thing")
H.check("error colour applied",  H.chatHas(NS.Config.COLORS.BAD))

H.report()
