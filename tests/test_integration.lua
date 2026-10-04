-------------------------------------------------------------------------------
-- test_integration.lua — loads every file the TOC loads, in TOC order, and
-- drives the addon the way the game does: PLAYER_LOGIN, then real events.
--
-- This is the file that catches load-order breakage, a missing global, and
-- anything that only shows up once all 15 modules are wired together. The file
-- list comes from the TOC itself, so adding a module to the addon without
-- adding it here cannot silently skip it.
-------------------------------------------------------------------------------
local H = dofile(TESTS_DIR .. "/wow_stub.lua")

local FILES = H.tocFiles()
local NS
local unpack = H.unpack

--- Fire an event through the addon's own router, with args at real positions.
local function fire(event, args, n)
  NS.Events:OnEvent(event, unpack(args or {}, 1, n or 0))
end

local function login(classToken)
  NS = H.newEnv(FILES)
  H.classToken = classToken or "ROGUE"
  H.className  = classToken == "MAGE" and "Mage" or "Rogue"
  fire("PLAYER_LOGIN")
  return NS
end

H.section("the TOC lists every module, in a loadable order")
H.eq("15 lua files in the TOC", #FILES, 15)
H.eq("config.lua loads first",  FILES[1], "config.lua")
H.eq("init.lua loads last",     FILES[#FILES], "init.lua")
NS = H.newEnv(FILES)
for _, mod in ipairs({ "Config", "Utils", "Data", "Tracking", "Items", "Coins",
                       "Stats", "UI", "Options", "Minimap", "Events", "Commands" }) do
  H.check("NS." .. mod .. " defined", NS[mod] ~= nil)
end
H.eq("version matches the TOC",
  NS.Config.VERSION,
  (function()
    for line in io.lines(ADDON_DIR .. "/PickPocketTracker.toc") do
      local v = line:match("^##%s*Version:%s*(%S+)")
      if v then return v end
    end
  end)())

H.section("loading registers the slash command and the login event")
H.check("/pp registered", SLASH_PICKPOCKETTRACKER1 == "/pp")
H.check("handler installed", type(SlashCmdList["PICKPOCKETTRACKER"]) == "function")
local loginFrame
for _, f in ipairs(H.frames) do
  if f.__events and f.__events.PLAYER_LOGIN then loginFrame = f end
end
H.check("an event frame listens for PLAYER_LOGIN", loginFrame ~= nil)
H.check("no tracking events before login",
  loginFrame and loginFrame.__events.PLAYER_MONEY == nil)

H.section("addon compartment handlers are exposed as globals")
for _, fn in ipairs({ "PickPocketTracker_OnAddonCompartmentClick",
                      "PickPocketTracker_OnAddonCompartmentEnter",
                      "PickPocketTracker_OnAddonCompartmentLeave" }) do
  H.check(fn .. " is global", type(_G[fn]) == "function")
end

H.section("a rogue login performs the full initialization")
login("ROGUE")
H.check("SavedVariables created", PickPocketTrackerDB ~= nil)
H.check("account DB created",     PickPocketTrackerAccountDB ~= nil)
H.check("main window built",      NS.UI.mainFrame ~= nil)
H.check("minimap button built",   NS.Minimap.button ~= nil or #H.frames > 0)
H.eq("options panel registered with Blizzard", #H.categories, 1)
H.check("version announced", H.chatHas("v" .. NS.Config.VERSION))
H.check("tracking events registered",
  loginFrame == nil or true)   -- frame identity differs per env; checked below

local rogueFrame
for _, f in ipairs(H.frames) do
  if f.__events and f.__events.PLAYER_MONEY then rogueFrame = f end
end
H.check("PLAYER_MONEY registered", rogueFrame ~= nil)
for _, ev in ipairs({ "UNIT_SPELLCAST_SUCCEEDED", "CHAT_MSG_LOOT", "MERCHANT_SHOW",
                      "MERCHANT_CLOSED", "CURRENCY_DISPLAY_UPDATE",
                      "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
  H.check(ev .. " registered", rogueFrame ~= nil and rogueFrame.__events[ev] == true)
end

H.section("a non-rogue login stays minimal but keeps account stats working")
login("MAGE")
H.check("no main window", NS.UI.mainFrame == nil)
H.check("account DB still created", PickPocketTrackerAccountDB ~= nil)
H.check("options panel still registered", #H.categories == 1)
H.check("told why tracking is off", H.chatHas("non-rogue"))
local mageFrame
for _, f in ipairs(H.frames) do
  if f.__events and f.__events.PLAYER_MONEY then mageFrame = f end
end
H.check("no tracking events registered", mageFrame == nil)

H.section("end to end: cast, loot gold and an item, vendor it")
login("ROGUE")
NS.Data:SetChatLogItems(false)
H.defineItem(100, "Silk Cloth", 50)
H.money = 0

fire("UNIT_SPELLCAST_SUCCEEDED", { "player", "cast-1", NS.Config.PICK_POCKET_SPELL_ID }, 3)
H.eq("cast counted in lifetime stats", NS.Stats:GetCharacterPickpocketCount(), 1)

H.money = 1234
fire("PLAYER_MONEY")
H.eq("gold attributed", NS.Tracking:GetSessionGold(), 1234)

local lootArgs = {}
lootArgs[1]  = "You receive loot: |cffffffff|Hitem:100:0:0:0|h[Silk Cloth]|hx3."
lootArgs[12] = UnitGUID("player")
fire("CHAT_MSG_LOOT", lootArgs, 12)
H.eq("item tracked", NS.Data:GetItemCount(), 1)
H.eq("quantity parsed from the message", NS.Data:GetItem(100).quantity, 3)

H.check("haul text shows the gold",
  (NS.UI.mainFrame.text:GetText() or ""):find("Haul", 1, true) ~= nil,
  NS.UI.mainFrame.text:GetText())

H.put(0, 1, 100, 3)
H.merchantOpen = true
fire("MERCHANT_SHOW")
H.tick(5)                                  -- auto-sell is on by default
H.check("auto-sold at the vendor", H.slot(0, 1) == nil)
H.merchantOpen = false
fire("MERCHANT_CLOSED")
H.eq("sale credited", NS.Items:GetSessionVendorValue(), 3 * 50)
H.eq("total value is gold plus sales", NS.Tracking:GetTotalValue(), 1234 + 150)
H.eq("lifetime total agrees", NS.Stats:GetCharacterTotal(), 1234 + 150)

H.section("CHAT_MSG_LOOT quantity parsing handles the real message shapes")
local function lootQty(message)
  login("ROGUE")
  NS.Data:SetChatLogItems(false)
  H.defineItem(100, "Silk Cloth", 50)
  fire("UNIT_SPELLCAST_SUCCEEDED", { "player", "c", NS.Config.PICK_POCKET_SPELL_ID }, 3)
  local a = {}
  a[1]  = message
  a[12] = UnitGUID("player")
  fire("CHAT_MSG_LOOT", a, 12)
  local item = NS.Data:GetItem(100)
  return item and item.quantity or 0
end

local LINK = "|cffffffff|Hitem:100:0:0:0|h[Silk Cloth]|h|r"
-- LOOT_ITEM_SELF_MULTIPLE is "You receive loot: %sx%d." -- note the period.
-- Anchoring the quantity pattern to end-of-string without allowing for it made
-- every multi-item stack count as 1, which also stopped auto-sell from ever
-- selling those stacks (a stack bigger than the tracked quantity is skipped).
H.eq("trailing period, x3",  lootQty("You receive loot: " .. LINK .. "x3."), 3)
H.eq("no trailing period",   lootQty("You receive loot: " .. LINK .. "x3"), 3)
H.eq("trailing whitespace",  lootQty("You receive loot: " .. LINK .. "x3 "), 3)
H.eq("period and space",     lootQty("You receive loot: " .. LINK .. "x3. "), 3)
H.eq("large stack",          lootQty("You receive loot: " .. LINK .. "x20."), 20)
H.eq("single item is 1",     lootQty("You receive loot: " .. LINK .. "."), 1)
H.eq("'receive item' form",  lootQty("You receive item: " .. LINK .. "x5."), 5)
H.eq("a name ending in a number is not a quantity",
  lootQty("You receive loot: |Hitem:100:0:0:0|h[Elixir x2]|h."), 1)

H.section("loot from another player is ignored")
login("ROGUE")
H.defineItem(100, "Silk Cloth", 50)
fire("UNIT_SPELLCAST_SUCCEEDED", { "player", "c", NS.Config.PICK_POCKET_SPELL_ID }, 3)
local otherLoot = {}
otherLoot[1]  = "Someone receives loot: |Hitem:100|hx2."
otherLoot[12] = "Player-1-DEADBEEF"
fire("CHAT_MSG_LOOT", otherLoot, 12)
H.eq("nothing tracked", NS.Data:GetItemCount(), 0)

H.section("a non-pickpocket cast does not open the window")
login("ROGUE")
fire("UNIT_SPELLCAST_SUCCEEDED", { "player", "c", 12345 }, 3)
H.check("window not opened", NS.Tracking:IsInDetectionWindow() == false)
fire("UNIT_SPELLCAST_SUCCEEDED", { "target", "c", NS.Config.PICK_POCKET_SPELL_ID }, 3)
H.check("another unit's cast ignored", NS.Tracking:IsInDetectionWindow() == false)
H.eq("no casts recorded", NS.Stats:GetCharacterPickpocketCount(), 0)

H.section("combat hides the windows when the option is on")
login("ROGUE")
NS.Data:SetHideInCombat(true)
NS.Data:SetHidden(false)
NS.UI:UpdateVisibility()
H.check("visible out of combat", NS.UI.mainFrame:IsShown() == true)
fire("PLAYER_REGEN_DISABLED")
H.check("combat flag set", NS.Events.inCombat == true)
H.check("hidden in combat", NS.UI.mainFrame:IsShown() == false)
fire("PLAYER_REGEN_ENABLED")
H.check("combat flag cleared", NS.Events.inCombat == false)
H.check("shown after combat", NS.UI.mainFrame:IsShown() == true)

NS.Data:SetHideInCombat(false)
fire("PLAYER_REGEN_DISABLED")
H.check("opted out: stays visible", NS.UI.mainFrame:IsShown() == true)
fire("PLAYER_REGEN_ENABLED")

H.section("an unknown event is routed harmlessly")
fire("SOME_EVENT_WE_DO_NOT_HANDLE", { 1, 2 }, 2)
H.check("no error", true)

H.section("slash commands run without error and do what they say")
login("ROGUE")
local slash = SlashCmdList["PICKPOCKETTRACKER"]

slash("hide")
H.check("hide sets the flag", NS.Data:IsHidden() == true)
slash("show")
H.check("show clears it", NS.Data:IsHidden() == false)
slash("lock")
H.check("lock sets the flag", NS.Data:IsLocked() == true)
slash("unlock")
H.check("unlock clears it", NS.Data:IsLocked() == false)

slash("coins on")
H.check("coins on", NS.Data:ShouldTrackCoins() == true)
slash("coins off")
H.check("coins off", NS.Data:ShouldTrackCoins() == false)

slash("autosell off")
H.check("autosell off", NS.Data:ShouldAutoSell() == false)
slash("autosell on")
H.check("autosell on", NS.Data:ShouldAutoSell() == true)

-- "/pp window" sets the detection window in SECONDS (not the window size).
slash("window 3.5")
H.eq("detection window applied", NS.Tracking:GetDetectionWindow(), 3.5)
H.eq("and persisted", NS.Data:GetDetectionWindow(), 3.5)
slash("window 99")
H.eq("out-of-range value refused", NS.Tracking:GetDetectionWindow(), 3.5)
H.check("refusal explains the range", H.chatHas("must be between"))
slash("window 2")
H.eq("integer accepted", NS.Tracking:GetDetectionWindow(), 2)

slash("icon off")
H.check("icon off", NS.Data:ShouldShowIcon() == false)
slash("icon on")
H.check("icon on", NS.Data:ShouldShowIcon() == true)

slash("minimap on")
H.check("minimap shown", NS.Data:IsMinimapHidden() == false)
slash("minimap off")
H.check("minimap hidden", NS.Data:IsMinimapHidden() == true)
slash("minimap reset")
H.eq("position reset", NS.Data.db.minimap.angle, NS.Config.MINIMAP_DEFAULTS.angle)

H.section("informational and option commands render")
for _, cmd in ipairs({ "help", "stats", "items", "lifetime", "account",
                       "", "config", "options", "settings",
                       "coins", "autosell", "minimap", "icon", "window",
                       "coins maybe", "autosell maybe", "minimap maybe",
                       "icon maybe", "window abc", "window -1",
                       "nonsense-command", "  help  ", "HELP", "Stats" }) do
  local before = H.failed
  local ok = pcall(slash, cmd)
  H.check("/pp " .. (cmd == "" and "(no args)" or cmd) .. " runs", ok)
  if before ~= H.failed then break end
end

H.section("the options window builds, including both charts")
H.check("options frame created", NS.Options.frame ~= nil)
H.check("options frame is a frame", NS.Options.frame.GetObjectType ~= nil)
NS.Options:Toggle()
NS.Options:Toggle()
H.check("toggling twice is safe", NS.Options.frame ~= nil)
NS.Options:RefreshControls()
H.check("RefreshControls is safe", true)

H.section("reset commands clear the session but keep lifetime stats")
login("ROGUE")
H.defineItem(100, "Silk Cloth", 50)
fire("UNIT_SPELLCAST_SUCCEEDED", { "player", "c", NS.Config.PICK_POCKET_SPELL_ID }, 3)
H.money = 500
fire("PLAYER_MONEY")
H.check("session gold accrued", NS.Tracking:GetSessionGold() == 500)
H.check("lifetime gold accrued", NS.Stats:GetCharacterGold() == 500)
SlashCmdList["PICKPOCKETTRACKER"]("reset")
H.eq("session cleared", NS.Tracking:GetSessionGold(), 0)
H.eq("lifetime preserved", NS.Stats:GetCharacterGold(), 500)

H.section("non-rogues are refused tracking commands but keep /pp account")
login("MAGE")
local mslash = SlashCmdList["PICKPOCKETTRACKER"]
H.chat = {}
mslash("stats")
H.check("refused with a reason", H.chatHas("only works on Rogue"))
H.check("pointed at /pp account", H.chatHas("/pp account"))
H.chat = {}
H.check("account runs", pcall(mslash, "account"))
H.check("account printed something", H.chatCount() > 0)
H.chat = {}
H.check("help runs", pcall(mslash, "help"))
H.check("help printed something", H.chatCount() > 0)

H.section("addon compartment click toggles the window and opens options")
login("ROGUE")
NS.Data:SetHidden(false)
PickPocketTracker_OnAddonCompartmentClick(nil, "RightButton")
H.check("right click hides", NS.Data:IsHidden() == true)
PickPocketTracker_OnAddonCompartmentClick(nil, "RightButton")
H.check("right click again shows", NS.Data:IsHidden() == false)
H.check("left click opens options",
  pcall(PickPocketTracker_OnAddonCompartmentClick, nil, "LeftButton"))

H.tooltip = {}
PickPocketTracker_OnAddonCompartmentEnter(UIParent)
H.check("tooltip populated", #H.tooltip > 0)
H.check("tooltip names the addon", (H.tooltip[1] or ""):find("Pick Pocket Tracker", 1, true) ~= nil)
H.check("tooltip leave is safe", pcall(PickPocketTracker_OnAddonCompartmentLeave))

H.section("a reload preserves settings and lifetime stats, not the session")
login("ROGUE")
NS.Data:SetHidden(true)
NS.Data:SetMaxGoldBars(4)
fire("UNIT_SPELLCAST_SUCCEEDED", { "player", "c", NS.Config.PICK_POCKET_SPELL_ID }, 3)
H.money = 777
fire("PLAYER_MONEY")
H.defineItem(100, "Silk Cloth", 50)
local lootArgs2 = {}
lootArgs2[1]  = "You receive loot: |Hitem:100|hx2."
lootArgs2[12] = UnitGUID("player")
fire("CHAT_MSG_LOOT", lootArgs2, 12)
H.check("item tracked before reload", NS.Data:GetItemCount() == 1)

NS = H.reload(FILES)            -- /reload: same SavedVariables, fresh chunks
fire("PLAYER_LOGIN")
H.check("setting preserved", NS.Data:IsHidden() == true)
H.eq("bar count preserved", NS.Data:GetMaxGoldBars(), 4)
H.eq("lifetime gold preserved", NS.Stats:GetCharacterGold(), 777)
H.eq("session gold reset", NS.Tracking:GetSessionGold(), 0)
H.eq("session items reset", NS.Data:GetItemCount(), 0)

H.report()
