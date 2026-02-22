-------------------------------------------------------------------------------
-- events.lua — Central event hub
-- Registers all WoW events in one place and routes them to the appropriate
-- module. Keeps individual modules decoupled from the event system.
--
-- Non-rogue characters get a minimal load: only PLAYER_LOGIN fires to
-- initialize the account DB (so /pp account stats still work), but no
-- tracking events are registered and no UI is created.
-------------------------------------------------------------------------------
local _, NS = ...

NS.Events = {}

local CreateFrame  = CreateFrame
local UnitGUID     = UnitGUID

local eventFrame = CreateFrame("Frame")

function NS.Events:Register()
  -- Always register PLAYER_LOGIN so we can check class and init account DB
  eventFrame:RegisterEvent("PLAYER_LOGIN")

  eventFrame:SetScript("OnEvent", function(_, event, ...)
    NS.Events:OnEvent(event, ...)
  end)
end

-------------------------------------------------------------------------------
-- Router
-------------------------------------------------------------------------------

local handlers = {}

function NS.Events:OnEvent(event, ...)
  local fn = handlers[event]
  if fn then fn(self, ...) end
end

--- Register rogue-only tracking events after class check passes.
local function RegisterTrackingEvents()
  eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  eventFrame:RegisterEvent("PLAYER_MONEY")
  eventFrame:RegisterEvent("CHAT_MSG_LOOT")
  eventFrame:RegisterEvent("MERCHANT_SHOW")
  eventFrame:RegisterEvent("MERCHANT_CLOSED")
  eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
end

-------------------------------------------------------------------------------
-- PLAYER_LOGIN — one-time init
-------------------------------------------------------------------------------

handlers.PLAYER_LOGIN = function()
  NS.Data:Initialize()

  -- Account DB always initializes (for account-wide stats on any character)
  if NS.Stats then NS.Stats:Initialize() end

  -- Register the add-on panel in Blizzard's Settings UI for all characters
  if NS.Options then NS.Options:RegisterBlizzardOptions() end

  -- Non-rogues: minimal load, no UI, no tracking
  if not NS.Data:IsRogue() then
    NS.Utils:PrintInfo(string.format("v%s loaded (non-rogue — tracking disabled, /pp account for stats).",
      NS.Config.VERSION))
    return
  end

  -- Rogue: full initialization
  RegisterTrackingEvents()

  NS.Tracking:Initialize()
  -- Items:Initialize clears session items (consistent with sessionGold reset)
  NS.Items:Initialize()

  if NS.Coins then
    NS.Coins:Initialize()
    NS.Coins:UpdateVisibility()
  end

  if NS.Options then NS.Options:RegisterDialogs() end

  NS.UI:Initialize()

  if NS.Minimap then
    NS.Minimap:Create(function()
      NS.Data:SetHidden(not NS.Data:IsHidden())
      NS.UI:UpdateVisibility()
    end)
  end

  NS.Utils:PrintInfo(string.format("v%s loaded. Type /pp for options.", NS.Config.VERSION))
end

-------------------------------------------------------------------------------
-- Pick Pocket cast succeeded
-------------------------------------------------------------------------------

handlers.UNIT_SPELLCAST_SUCCEEDED = function(_, unit, _, spellID)
  if unit ~= "player" or spellID ~= NS.Config.PICK_POCKET_SPELL_ID then return end
  NS.Tracking:OnPickPocketCast()
  if NS.Coins then NS.Coins:OnPickPocketCast() end
end

-------------------------------------------------------------------------------
-- Gold change
-------------------------------------------------------------------------------

handlers.PLAYER_MONEY = function()
  if NS.Tracking:OnMoneyChanged() > 0 then
    NS.UI:UpdateDisplay()
  end
end

-------------------------------------------------------------------------------
-- Item loot — parse CHAT_MSG_LOOT for item link + quantity
-- Args: message, playerName, ..., senderGUID (arg 12)
-------------------------------------------------------------------------------

handlers.CHAT_MSG_LOOT = function(_, msg, _, _, _, _, _, _, _, _, _, _, senderGUID)
  local myGUID = UnitGUID("player")
  if senderGUID and myGUID and senderGUID ~= myGUID then return end

  local itemLink = msg:match("|H(item:%d+.-)|h")
  if not itemLink then return end

  itemLink = "|H" .. itemLink .. "|h"
  local quantity = tonumber(msg:match("|rx(%d+)")) or 1

  NS.Items:OnLootReceived(itemLink, quantity)
end

-------------------------------------------------------------------------------
-- Vendor open/close — snapshot + autosell
-------------------------------------------------------------------------------

handlers.MERCHANT_SHOW = function()
  NS.Items:OnMerchantShow()
  -- Start autosell queue if enabled (sells items one at a time)
  NS.Items:StartAutoSell()
end

handlers.MERCHANT_CLOSED = function()
  NS.Items:OnMerchantClosed()
  NS.UI:UpdateDisplay()
end

-------------------------------------------------------------------------------
-- Currency change — Coins of Air tracking
-------------------------------------------------------------------------------

handlers.CURRENCY_DISPLAY_UPDATE = function()
  if NS.Coins and NS.Data:ShouldTrackCoins() then
    NS.Coins:OnCurrencyChanged()
  end
end
