-------------------------------------------------------------------------------
-- init.lua — Bootstrap (loaded last in the TOC)
-- Registers slash commands, hooks up the event frame, and exposes the
-- global handlers required by the Blizzard Addon Compartment API.
-- Everything else happens on PLAYER_LOGIN inside events.lua.
-------------------------------------------------------------------------------
local ADDON_NAME, NS = ...
NS.name = ADDON_NAME

if NS.Commands then NS.Commands:Register() end
if NS.Events   then NS.Events:Register()   end

-------------------------------------------------------------------------------
-- Addon Compartment handlers (must be global — looked up by name in _G)
-- These let the addon appear in the minimap addon list (11.0+).
-------------------------------------------------------------------------------

function PickPocketTracker_OnAddonCompartmentClick(_, button)
  if button == "RightButton" then
    -- Right-click: toggle haul window (same as minimap right-click)
    if NS.Data and NS.Data.db and NS.UI then
      NS.Data:SetHidden(not NS.Data:IsHidden())
      NS.UI:UpdateVisibility()
    end
  else
    -- Left-click: open options panel
    if NS.Options then NS.Options:Toggle() end
  end
end

function PickPocketTracker_OnAddonCompartmentEnter(addonFrame)
  GameTooltip:SetOwner(addonFrame, "ANCHOR_NONE")
  GameTooltip:SetPoint("TOPRIGHT", addonFrame, "BOTTOMRIGHT", 0, 0)
  GameTooltip:AddLine("Pick Pocket Tracker")
  GameTooltip:AddLine("Left-click: Options", 1, 1, 1)
  GameTooltip:AddLine("Right-click: Toggle window", 1, 1, 1)
  if NS.Tracking and NS.Tracking.sessionGold then
    local gold = NS.Tracking:GetTotalValue()
    if gold > 0 then
      GameTooltip:AddLine(" ")
      GameTooltip:AddDoubleLine("Session haul:", NS.Utils:FormatMoneyCompact(gold), 0.7, 0.7, 0.7, 1, 1, 1)
    end
  end
  GameTooltip:Show()
end

function PickPocketTracker_OnAddonCompartmentLeave()
  GameTooltip:Hide()
end
