-------------------------------------------------------------------------------
-- test_coins.lua — Coins of Air: currency-delta attribution and the window
-------------------------------------------------------------------------------
local H = dofile(TESTS_DIR .. "/wow_stub.lua")
local MODULES = { "config.lua", "utils.lua", "data.lua", "tracking.lua",
                  "stats.lua", "coins.lua" }

local NS, Co, D, T, S, COIN_ID

local function fresh(trackCoins)
  NS = H.newEnv(MODULES)
  Co, D, T, S = NS.Coins, NS.Data, NS.Tracking, NS.Stats
  COIN_ID = NS.Config.COINS_OF_AIR_ID
  D:Initialize(); S:Initialize(); T:Initialize()
  D:SetTrackCoins(trackCoins ~= false)
  D:SetChatLogItems(false)
  H.currency[COIN_ID] = 0
  Co:Initialize()
end

H.section("the configured currency is Legion's Coins of Air")
fresh()
H.eq("currency id", COIN_ID, 1416)

H.section("Initialize snapshots the currently held amount")
fresh()
H.currency[COIN_ID] = 42
Co:Initialize()
H.eq("snapshot taken", Co.lastSnapshot, 42)
H.eq("session starts at zero", Co:GetSessionCount(), 0)

H.section("coins gained inside the window are attributed")
fresh()
T:OnPickPocketCast()
Co:OnPickPocketCast()
H.currency[COIN_ID] = 3
H.eq("delta returned", Co:OnCurrencyChanged(), 3)
H.eq("session count", Co:GetSessionCount(), 3)
H.eq("lifetime character coins", S:GetCharacterCoins(), 3)
H.eq("lifetime account coins",   S:GetAccountCoins(), 3)

H.section("coins gained outside the window are ignored")
fresh()
T:OnPickPocketCast()
Co:OnPickPocketCast()
H.advance(T:GetDetectionWindow() + 1)
H.currency[COIN_ID] = 99
H.eq("not attributed", Co:OnCurrencyChanged(), 0)
H.eq("session unchanged", Co:GetSessionCount(), 0)
H.eq("lifetime unchanged", S:GetCharacterCoins(), 0)
-- Outside the window the snapshot is deliberately NOT advanced, so the next
-- cast re-snapshots instead.
Co:OnPickPocketCast()
H.eq("re-snapshotted on the next cast", Co.lastSnapshot, 99)

H.section("spending coins is never counted as a gain")
fresh()
H.currency[COIN_ID] = 100
Co:Initialize()
T:OnPickPocketCast()
Co:OnPickPocketCast()
H.currency[COIN_ID] = 60               -- spent at the Coins of Air vendor
H.eq("negative delta returns 0", Co:OnCurrencyChanged(), 0)
H.eq("session unchanged", Co:GetSessionCount(), 0)
H.eq("snapshot follows the spend", Co.lastSnapshot, 60)
H.currency[COIN_ID] = 63
H.eq("next gain not inflated", Co:OnCurrencyChanged(), 3)

H.section("a zero-delta currency event is a no-op")
fresh()
T:OnPickPocketCast()
Co:OnPickPocketCast()
H.eq("no change returns 0", Co:OnCurrencyChanged(), 0)
H.eq("session unchanged", Co:GetSessionCount(), 0)

H.section("repeated gains accumulate")
fresh()
for i = 1, 3 do
  T:OnPickPocketCast()
  Co:OnPickPocketCast()
  H.currency[COIN_ID] = (H.currency[COIN_ID] or 0) + 2
  Co:OnCurrencyChanged()
end
H.eq("session total", Co:GetSessionCount(), 6)
H.eq("lifetime total", S:GetCharacterCoins(), 6)

H.section("chat output pluralises correctly and respects the setting")
fresh()
D:SetChatLogItems(true)
T:OnPickPocketCast(); Co:OnPickPocketCast()
H.currency[COIN_ID] = 1
Co:OnCurrencyChanged()
H.check("singular form", H.chatHas("1 Coin of Air"))

T:OnPickPocketCast(); Co:OnPickPocketCast()
H.currency[COIN_ID] = 4
Co:OnCurrencyChanged()
H.check("plural form", H.chatHas("3 Coins of Air"))

local before = H.chatCount()
D:SetChatLogItems(false)
T:OnPickPocketCast(); Co:OnPickPocketCast()
H.currency[COIN_ID] = 10
Co:OnCurrencyChanged()
H.eq("silent when logging is off", H.chatCount(), before)
H.eq("but still counted", Co:GetSessionCount(), 1 + 3 + 6)

H.section("ResetSession clears the session and re-snapshots")
fresh()
T:OnPickPocketCast(); Co:OnPickPocketCast()
H.currency[COIN_ID] = 5
Co:OnCurrencyChanged()
H.check("accrued", Co:GetSessionCount() == 5)
Co:ResetSession()
H.eq("session cleared", Co:GetSessionCount(), 0)
H.eq("re-snapshotted", Co.lastSnapshot, 5)
H.check("lifetime kept", S:GetCharacterCoins() == 5)

H.section("a missing currency API degrades to zero instead of erroring")
fresh()
local saved = C_CurrencyInfo.GetCurrencyInfo
C_CurrencyInfo.GetCurrencyInfo = function() return nil end
Co:Initialize()
H.eq("snapshot is zero", Co.lastSnapshot, 0)
T:OnPickPocketCast(); Co:OnPickPocketCast()
H.eq("no delta, no error", Co:OnCurrencyChanged(), 0)
C_CurrencyInfo.GetCurrencyInfo = saved

H.section("the window is not created while coin tracking is off")
fresh(false)
Co:UpdateVisibility()
H.check("no frame built", Co.frame == nil)
Co:CreateWindow()
H.check("CreateWindow is gated too", Co.frame == nil)

H.section("enabling tracking builds the window on the next visibility pass")
fresh(true)
Co:UpdateVisibility()
H.check("frame built", Co.frame ~= nil)
H.check("frame shown", Co.frame:IsShown() == true)
H.check("text set", (Co.frame.text:GetText() or ""):find("Coins of Air", 1, true) ~= nil)

H.section("the window is hidden when the user hides it")
D:SetCoinWindowHidden(true)
Co:UpdateVisibility()
H.check("hidden", Co.frame:IsShown() == false)
D:SetCoinWindowHidden(false)
Co:UpdateVisibility()
H.check("shown again", Co.frame:IsShown() == true)

H.section("combat visibility defers to the shared combat rule")
NS.Events = {
  inCombat = true,
  ShouldHideForCombat = function(self) return self.inCombat and D:ShouldHideInCombat() end,
}
D:SetHideInCombat(true)
Co:UpdateVisibility()
H.check("hidden in combat", Co.frame:IsShown() == false)
NS.Events.inCombat = false
Co:UpdateVisibility()
H.check("shown out of combat", Co.frame:IsShown() == true)
NS.Events.inCombat = true
D:SetHideInCombat(false)
Co:UpdateVisibility()
H.check("opted out: visible in combat", Co.frame:IsShown() == true)
NS.Events = nil

H.section("the display reflects the live session count")
D:SetHideInCombat(true)
T:OnPickPocketCast(); Co:OnPickPocketCast()
H.currency[COIN_ID] = (H.currency[COIN_ID] or 0) + 11
Co:OnCurrencyChanged()
H.check("count rendered",
  (Co.frame.text:GetText() or ""):find("Coins of Air: 11", 1, true) ~= nil,
  Co.frame.text:GetText())

H.section("the icon toggle is applied without rebuilding the window")
local frameBefore = Co.frame
D:SetShowCoinIcon(false)
Co:OnIconSettingChanged()
H.check("same frame reused", Co.frame == frameBefore)
Co:UpdateVisibility()
H.check("still one frame", Co.frame == frameBefore)

H.report()
