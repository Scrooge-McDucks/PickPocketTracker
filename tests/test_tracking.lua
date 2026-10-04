-------------------------------------------------------------------------------
-- test_tracking.lua — gold attribution via the post-cast detection window
-------------------------------------------------------------------------------
local H  = dofile(TESTS_DIR .. "/wow_stub.lua")
local NS = H.newEnv({ "config.lua", "utils.lua", "data.lua", "tracking.lua" })
local T, D, C = NS.Tracking, NS.Data, NS.Config

local G = 10000

D:Initialize()
H.money = 5 * G
T:Initialize()

H.section("Initialize snapshots money and loads the persisted window")
H.eq("money baseline", T.lastMoneyAmount, 5 * G)
H.eq("session starts at zero", T:GetSessionGold(), 0)
H.eq("window from SavedVariables", T:GetDetectionWindow(), D:GetDetectionWindow())
H.check("not in a window before any cast", T:IsInDetectionWindow() == false)

H.section("gold gained inside the window is attributed")
T:OnPickPocketCast()
H.money = H.money + 250
H.eq("delta returned", T:OnMoneyChanged(), 250)
H.eq("session gold accrued", T:GetSessionGold(), 250)

H.section("gold gained outside the window is ignored")
T:OnPickPocketCast()
H.advance(T:GetDetectionWindow() + 0.01)
H.money = H.money + 9999
H.eq("not attributed", T:OnMoneyChanged(), 0)
H.eq("session gold unchanged", T:GetSessionGold(), 250)
H.eq("baseline still advanced", T.lastMoneyAmount, H.money)

H.section("the window boundary is inclusive")
T:OnPickPocketCast()
H.advance(T:GetDetectionWindow())
H.check("exactly at the limit still counts", T:IsInDetectionWindow() == true)
H.advance(0.001)
H.check("just past the limit does not", T:IsInDetectionWindow() == false)

H.section("spending money is never counted as a haul")
T:OnPickPocketCast()
H.money = H.money - 1000
H.eq("negative delta returns 0", T:OnMoneyChanged(), 0)
H.eq("session gold unchanged",   T:GetSessionGold(), 250)
H.eq("baseline tracks the loss", T.lastMoneyAmount, H.money)
-- The regression this guards: if a loss did not update the baseline, the next
-- gain would be inflated by the amount spent.
H.money = H.money + 500
H.eq("next gain is not inflated", T:OnMoneyChanged(), 500)
H.eq("session gold now 750", T:GetSessionGold(), 750)

H.section("a zero-delta money event is a no-op")
T:OnPickPocketCast()
H.eq("no change returns 0", T:OnMoneyChanged(), 0)
H.eq("session gold unchanged", T:GetSessionGold(), 750)

H.section("each cast re-opens the window")
H.advance(60)
H.check("window long expired", T:IsInDetectionWindow() == false)
T:OnPickPocketCast()
H.check("re-opened by a new cast", T:IsInDetectionWindow() == true)
H.money = H.money + 100
H.eq("attributed again", T:OnMoneyChanged(), 100)

H.section("SetDetectionWindow validates and persists")
H.check("accepts mid-range", T:SetDetectionWindow(3.0) == true)
H.eq("applied", T:GetDetectionWindow(), 3.0)
H.eq("persisted to SavedVariables", D:GetDetectionWindow(), 3.0)
H.check("rejects above max", T:SetDetectionWindow(C.MAX_WINDOW_SECONDS + 1) == false)
H.check("rejects below min", T:SetDetectionWindow(C.MIN_WINDOW_SECONDS - 0.01) == false)
H.check("rejects nil",       T:SetDetectionWindow(nil) == false)
H.eq("unchanged after rejections", T:GetDetectionWindow(), 3.0)
H.check("accepts exact min", T:SetDetectionWindow(C.MIN_WINDOW_SECONDS) == true)
H.check("accepts exact max", T:SetDetectionWindow(C.MAX_WINDOW_SECONDS) == true)

H.section("GetTotalValue combines looted gold with sold-item value")
T:SetDetectionWindow(2.0)
H.eq("gold only when Items is absent", T:GetTotalValue(), T:GetSessionGold())
NS.Items = { GetSessionVendorValue = function() return 1234 end }
H.eq("adds vendor value", T:GetTotalValue(), T:GetSessionGold() + 1234)
NS.Items = nil

H.section("ResetSession clears the session but re-baselines money")
T:ResetSession()
H.eq("session gold zeroed", T:GetSessionGold(), 0)
H.eq("cast time cleared",   T.lastPickPocketTime, 0)
H.eq("money re-baselined",  T.lastMoneyAmount, H.money)
H.check("no stale window", T:IsInDetectionWindow() == false)
H.money = H.money + 777
H.eq("post-reset gain outside a window is ignored", T:OnMoneyChanged(), 0)

H.section("pickpocket casts feed lifetime stats")
local counted = 0
NS.Stats = { RecordPickpocket = function() counted = counted + 1 end,
             RecordGoldLooted = function() end }
T:OnPickPocketCast()
T:OnPickPocketCast()
H.eq("each cast recorded once", counted, 2)

local recordedGold = 0
NS.Stats.RecordGoldLooted = function(_, amount) recordedGold = recordedGold + amount end
H.money = H.money + 420
T:OnMoneyChanged()
H.eq("attributed gold recorded", recordedGold, 420)
H.advance(60)
H.money = H.money + 420
T:OnMoneyChanged()
H.eq("unattributed gold not recorded", recordedGold, 420)

H.report()
