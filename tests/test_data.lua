-------------------------------------------------------------------------------
-- test_data.lua — SavedVariables layer: defaults, clamping, persistence
-------------------------------------------------------------------------------
local H  = dofile(TESTS_DIR .. "/wow_stub.lua")
local NS = H.newEnv({ "config.lua", "utils.lua", "data.lua" })
local D  = NS.Data
local C  = NS.Config

H.section("Initialize creates the DB and backfills defaults")
D:Initialize()
H.check("global DB created", PickPocketTrackerDB ~= nil)
H.check("db handle set",     D.db == PickPocketTrackerDB)
H.eq("hidden default",       D:IsHidden(),            C.UI_DEFAULTS.hidden)
H.eq("locked default",       D:IsLocked(),            C.UI_DEFAULTS.locked)
H.eq("showIcon default",     D:ShouldShowIcon(),      C.UI_DEFAULTS.showIcon)
H.eq("chatLog default",      D:ShouldChatLogItems(),  C.UI_DEFAULTS.chatLogItems)
H.eq("barGraph default",     D:ShouldShowBarGraph(),  C.UI_DEFAULTS.showBarGraph)
H.eq("autoSell default",     D:ShouldAutoSell(),      C.AUTOSELL_DEFAULTS.enabled)
H.eq("hideInCombat default", D:ShouldHideInCombat(),  true)
H.eq("trackCoins default",   D:ShouldTrackCoins(),    false)
H.check("minimap table created", type(D.db.minimap) == "table")
H.eq("minimap hidden default", D:IsMinimapHidden(), C.MINIMAP_DEFAULTS.hide)
H.check("items table created", type(D:GetItems()) == "table")

H.section("existing settings survive re-initialization")
D:SetHidden(true)
D:SetMaxGoldBars(3)
D:SetDetectionWindow(4.5)
D:Initialize()                      -- simulates a /reload
H.eq("hidden preserved",   D:IsHidden(), true)
H.eq("maxGoldBars kept",   D:GetMaxGoldBars(), 3)
H.eq("window kept",        D:GetDetectionWindow(), 4.5)

H.section("a partially-populated DB is backfilled, not overwritten")
PickPocketTrackerDB = { hidden = true, locked = true }   -- old install
D:Initialize()
H.eq("existing key untouched", D:IsHidden(), true)
H.eq("existing locked kept",   D:IsLocked(), true)
H.eq("missing key filled",     D:ShouldShowIcon(), C.UI_DEFAULTS.showIcon)
H.check("missing minimap filled", type(D.db.minimap) == "table")

H.section("boolean setters round-trip")
D:Initialize()
local flags = {
  { "Hidden",         D.SetHidden,         D.IsHidden },
  { "Locked",         D.SetLocked,         D.IsLocked },
  { "ShowIcon",       D.SetShowIcon,       D.ShouldShowIcon },
  { "ChatLogItems",   D.SetChatLogItems,   D.ShouldChatLogItems },
  { "ShowBarGraph",   D.SetShowBarGraph,   D.ShouldShowBarGraph },
  { "TrackCoins",     D.SetTrackCoins,     D.ShouldTrackCoins },
  { "AutoSell",       D.SetAutoSell,       D.ShouldAutoSell },
  { "HideInCombat",   D.SetHideInCombat,   D.ShouldHideInCombat },
  { "CoinWindowHidden", D.SetCoinWindowHidden, D.IsCoinWindowHidden },
  { "MinimapHidden",  D.SetMinimapHidden,  D.IsMinimapHidden },
}
for _, f in ipairs(flags) do
  local name, set, get = f[1], f[2], f[3]
  set(D, true)
  local onTrue = get(D)
  set(D, false)
  local onFalse = get(D)
  H.check(name .. " round-trips", onTrue == true and onFalse == false,
    tostring(onTrue) .. "/" .. tostring(onFalse))
end

H.section("detection window is clamped to the configured range")
D:SetDetectionWindow(999)
H.eq("above max clamps", D:GetDetectionWindow(), C.MAX_WINDOW_SECONDS)
D:SetDetectionWindow(-5)
H.eq("below min clamps", D:GetDetectionWindow(), C.MIN_WINDOW_SECONDS)
D:SetDetectionWindow(2.5)
H.eq("in range kept",    D:GetDetectionWindow(), 2.5)
D.db.detectionWindow = nil
H.eq("nil falls back to default", D:GetDetectionWindow(), C.DEFAULT_WINDOW_SECONDS)

H.section("chart bar counts are clamped independently")
D:SetMaxGoldBars(999)
H.eq("gold bars clamp high", D:GetMaxGoldBars(), C.CHART_DEFAULTS.maxBarsLimit)
D:SetMaxGoldBars(0)
H.eq("gold bars clamp low",  D:GetMaxGoldBars(), C.CHART_DEFAULTS.minBars)
D:SetMaxCoinBars(7)
D:SetMaxGoldBars(2)
H.eq("coin bars independent of gold", D:GetMaxCoinBars(), 7)
H.eq("gold bars unaffected",          D:GetMaxGoldBars(), 2)

H.section("window size clamps and rounds")
local w, h = D:ClampWindowSize(1, 1)
H.eq("width clamps to min",  w, C.UI_DEFAULTS.minWidth)
H.eq("height clamps to min", h, C.UI_DEFAULTS.minHeight)
w, h = D:ClampWindowSize(99999, 99999)
H.eq("width clamps to max",  w, C.UI_DEFAULTS.maxWidth)
H.eq("height clamps to max", h, C.UI_DEFAULTS.maxHeight)
D:SetWindowSize(200.4, 30.6)
w, h = D:GetWindowSize()
H.eq("width rounded",  w, 200)
H.eq("height rounded", h, 31)

H.section("window position rounds offsets")
D:SetWindowPosition("TOPLEFT", "CENTER", 10.4, -20.5)
local p, rp, x, y = D:GetWindowPosition()
H.eq("point",    p,  "TOPLEFT")
H.eq("relative", rp, "CENTER")
H.eq("x rounded", x, 10)
H.eq("y rounded", y, -20)

H.section("coin window falls back to defaults until set")
D:Initialize()
local cp, crp, cx, cy = D:GetCoinWindowPosition()
H.eq("default coin point", cp,  C.COIN_WINDOW_DEFAULTS.point)
H.eq("default coin x",     cx,  C.COIN_WINDOW_DEFAULTS.offsetX)
H.eq("default coin y",     cy,  C.COIN_WINDOW_DEFAULTS.offsetY)
H.eq("default coin relative", crp, C.COIN_WINDOW_DEFAULTS.relativePoint)
local cw, ch = D:GetCoinWindowSize()
H.eq("default coin width",  cw, C.COIN_WINDOW_DEFAULTS.width)
H.eq("default coin height", ch, C.COIN_WINDOW_DEFAULTS.height)
H.eq("default coin icon",   D:ShouldShowCoinIcon(), C.COIN_WINDOW_DEFAULTS.showIcon)

D:SetCoinWindowPosition("BOTTOM", "BOTTOM", 5.7, 9.2)
cp, crp, cx, cy = D:GetCoinWindowPosition()
H.eq("saved coin point", cp, "BOTTOM")
H.eq("saved coin x",     cx, 6)
H.eq("saved coin y",     cy, 9)
D:SetCoinWindowSize(99999, 1)
cw, ch = D:GetCoinWindowSize()
H.eq("coin width clamps",  cw, C.COIN_WINDOW_DEFAULTS.maxWidth)
H.eq("coin height clamps", ch, C.COIN_WINDOW_DEFAULTS.minHeight)
D:SetShowCoinIcon(false)
H.eq("coin icon round-trips", D:ShouldShowCoinIcon(), false)

H.section("item storage")
D:Initialize()
H.eq("starts empty", D:GetItemCount(), 0)
D:SetItem(100, { name = "A", quantity = 1 })
D:SetItem(200, { name = "B", quantity = 2 })
H.eq("two items", D:GetItemCount(), 2)
H.eq("fetch by id", D:GetItem(100).name, "A")
H.check("missing id is nil", D:GetItem(999) == nil)
D:SetItem(100, { name = "A", quantity = 5 })
H.eq("overwrite does not duplicate", D:GetItemCount(), 2)
H.eq("overwritten value", D:GetItem(100).quantity, 5)
D:ClearItems()
H.eq("cleared", D:GetItemCount(), 0)

H.section("IsRogue gates on the class token, not the localised name")
H.classToken = "ROGUE"
H.check("rogue detected", D:IsRogue() == true)
H.classToken = "MAGE"
H.check("mage rejected", D:IsRogue() == false)
H.classToken = nil
H.check("nil class rejected", D:IsRogue() == false)

H.section("minimap position reset")
H.classToken = "ROGUE"
D.db.minimap.angle, D.db.minimap.radius = 1, 2
D:ResetMinimapPosition()
H.eq("angle restored",  D.db.minimap.angle,  C.MINIMAP_DEFAULTS.angle)
H.eq("radius restored", D.db.minimap.radius, C.MINIMAP_DEFAULTS.radius)

H.report()
