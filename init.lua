-- Namespace initialization
local ADDON_NAME, NS = ...
NS.name = ADDON_NAME

-- Initialize addon
function NS:Initialize()
  if NS.Commands then
    NS.Commands:Register()
  end
  
  if NS.Events then
    NS.Events:Register()
  end
end

NS:Initialize()
