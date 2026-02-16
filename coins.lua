-------------------------------------------------------------------------------
-- coins.lua — Coins of Air tracking + display window
--
-- Coins of Air (currency 1416) are a pickpocket currency. Detection uses
-- the same time-window approach as gold: on a pickpocket cast we snapshot
-- the currency count, and when CURRENCY_DISPLAY_UPDATE fires within the
-- window we record the delta.
--
-- Built on the shared CreateDisplayBar factory (utils.lua) which handles
-- drag, resize grip, lock, and icon toggle — same as the gold haul window.
-------------------------------------------------------------------------------
local _, NS = ...

NS.Coins = {}

local C_CurrencyInfo = C_CurrencyInfo
local CURRENCY_ID    = 1416   -- Coins of Air
local ICON_PATH      = "Interface/Icons/INV_Misc_Coin_17"

-- Session state
NS.Coins.sessionCount = 0
NS.Coins.lastSnapshot = 0
NS.Coins.frame        = nil

-------------------------------------------------------------------------------
-- Currency helper
-------------------------------------------------------------------------------

local function GetCoinCount()
  local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(CURRENCY_ID)
  return info and info.quantity or 0
end

-------------------------------------------------------------------------------
-- Tracking
-------------------------------------------------------------------------------

function NS.Coins:Initialize()
  self.sessionCount = 0
  self.lastSnapshot = GetCoinCount()
end

function NS.Coins:OnPickPocketCast()
  self.lastSnapshot = GetCoinCount()
end

--- Called on CURRENCY_DISPLAY_UPDATE. Returns delta if coins gained
--- within the detection window, 0 otherwise.
function NS.Coins:OnCurrencyChanged()
  if not NS.Tracking:IsInDetectionWindow() then return 0 end

  local current = GetCoinCount()
  local delta   = current - self.lastSnapshot
  self.lastSnapshot = current

  if delta <= 0 then return 0 end

  self.sessionCount = self.sessionCount + delta
  if NS.Stats then NS.Stats:RecordCoinsOfAir(delta) end

  if NS.Data:ShouldChatLogItems() then
    NS.Utils:PrintSuccess(string.format("Pickpocketed: %d Coin%s of Air",
      delta, delta > 1 and "s" or ""))
  end

  self:UpdateDisplay()
  return delta
end

function NS.Coins:ResetSession()
  self.sessionCount = 0
  self.lastSnapshot = GetCoinCount()
  self:UpdateDisplay()
end

function NS.Coins:GetSessionCount()
  return self.sessionCount
end

-------------------------------------------------------------------------------
-- Display window — uses shared CreateDisplayBar factory
-------------------------------------------------------------------------------

function NS.Coins:CreateWindow()
  if self.frame then return end
  if not NS.Data:ShouldTrackCoins() then return end

  local d = NS.Config.COIN_WINDOW_DEFAULTS
  local w, h = NS.Data:GetCoinWindowSize()

  local f = NS.Utils:CreateDisplayBar({
    name        = "PickPocketTrackerCoinFrame",
    width       = w,
    height      = h,
    iconTexture = ICON_PATH,
    iconSize    = d.iconSize,
    iconCoords  = { 0.08, 0.92, 0.08, 0.92 },
    getSavedPos = function() return NS.Data:GetCoinWindowPosition() end,
    onSavePos   = function(p, rp, x, y) NS.Data:SetCoinWindowPosition(p, rp, x, y) end,
    isLocked    = function() return NS.Data:IsLocked() end,
    resizable   = {
      minW = d.minWidth,  minH = d.minHeight,
      maxW = d.maxWidth,  maxH = d.maxHeight,
      onSaveSize = function(w2, h2) NS.Data:SetCoinWindowSize(w2, h2) end,
    },
  })

  -- Tooltip
  f:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Coins of Air")

    GameTooltip:AddDoubleLine("Session:", NS.Coins.sessionCount, 1,1,1, 1,1,1)
    GameTooltip:AddDoubleLine("Total held:", GetCoinCount(), 1,1,1, 1,1,1)

    if NS.Stats then
      local charCoins = NS.Stats:GetCharacterCoins()
      local accCoins  = NS.Stats:GetAccountCoins()
      if charCoins > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Lifetime (char):", charCoins, 0.7,0.7,0.7, 1,1,1)
      end
      if accCoins > 0 then
        GameTooltip:AddDoubleLine("Lifetime (account):", accCoins, 0.7,0.7,0.7, 1,1,1)
      end
    end

    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)

  self.frame = f
  f:SetIconVisible(NS.Data:ShouldShowCoinIcon())
  f:SetLockState(NS.Data:IsLocked())
  self:UpdateDisplay()
end

function NS.Coins:OnIconSettingChanged()
  if not self.frame then return end
  self.frame:SetIconVisible(NS.Data:ShouldShowCoinIcon())
end

function NS.Coins:UpdateDisplay()
  if not self.frame then return end
  if not NS.Data:ShouldTrackCoins() then
    self.frame:Hide()
    return
  end

  self.frame.text:SetText(string.format("Coins of Air: %d", self.sessionCount))
  self.frame:Show()
end

function NS.Coins:UpdateVisibility()
  if not NS.Data:ShouldTrackCoins() then
    if self.frame then self.frame:Hide() end
    return
  end

  if not self.frame then
    self:CreateWindow()
  else
    self:UpdateDisplay()
  end
end
