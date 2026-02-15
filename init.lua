-------------------------------------------------------------------------------
-- init.lua — Bootstrap (loaded last in the TOC)
-- Registers slash commands and hooks up the event frame. Everything else
-- happens on PLAYER_LOGIN inside events.lua.
-------------------------------------------------------------------------------
local ADDON_NAME, NS = ...
NS.name = ADDON_NAME

if NS.Commands then NS.Commands:Register() end
if NS.Events   then NS.Events:Register()   end
