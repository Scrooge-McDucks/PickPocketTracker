-- Slash command handling
local _, NS = ...

NS.Commands = {}

function NS.Commands:Register()
  SLASH_PICKPOCKETTRACKER1 = "/pp"
  
  SlashCmdList["PICKPOCKETTRACKER"] = function(msg)
    NS.Commands:HandleCommand(msg)
  end
end

function NS.Commands:HandleCommand(msg)
  msg = NS.Utils:TrimString(msg:lower())
  
  if msg == "" then
    self:HandleOptions()
    
  elseif msg == "config" or msg == "options" or msg == "settings" then
    self:HandleOptions()
    
  elseif msg == "help" then
    self:HandleHelp()
    
  elseif msg == "stats" or msg == "items" then
    self:HandleStats()
    
  elseif msg == "lifetime" then
    self:HandleLifetime()
    
  elseif msg == "reset" then
    self:HandleReset()
    
  elseif msg == "hide" then
    self:HandleHide()
    
  elseif msg == "show" then
    self:HandleShow()
    
  elseif msg == "lock" then
    self:HandleLock()
    
  elseif msg == "unlock" then
    self:HandleUnlock()
    
  elseif msg:match("^minimap") then
    self:HandleMinimapCommand(msg)
    
  elseif msg:match("^icon") then
    self:HandleIconCommand(msg)
    
  elseif msg:match("^window") then
    self:HandleWindowCommand(msg)
    
  else
    NS.Utils:PrintError("Unknown command: " .. msg)
    NS.Utils:PrintInfo("Type /pp help for available commands")
  end
end

-- Command handlers
function NS.Commands:HandleOptions()
  if NS.Options then
    NS.Options:Show()
  else
    NS.Utils:PrintError("Options module not loaded")
  end
end

function NS.Commands:HandleHelp()
  NS.Utils:PrintInfo("Available Commands:")
  NS.Utils:Print(nil, "  /pp - Open options window")
  NS.Utils:Print(nil, "  /pp options - Open options window")
  NS.Utils:Print(nil, "  /pp stats - Show detailed item breakdown")
  NS.Utils:Print(nil, "  /pp lifetime - Show lifetime statistics")
  NS.Utils:Print(nil, "  /pp reset - Reset session (clear all data)")
  NS.Utils:Print(nil, "  /pp hide - Hide the display window")
  NS.Utils:Print(nil, "  /pp show - Show the display window")
  NS.Utils:Print(nil, "  /pp lock - Lock window (prevent resize)")
  NS.Utils:Print(nil, "  /pp unlock - Unlock window (allow resize)")
  NS.Utils:Print(nil, "  /pp icon on|off - Show/hide icon")
  NS.Utils:Print(nil, "  /pp minimap on|off|reset - Minimap button")
  NS.Utils:Print(nil, "  /pp window <seconds> - Detection window (0.1-10)")
  NS.Utils:Print(nil, "  /pp help - Show this help")
end

function NS.Commands:HandleStats()
  if not NS.Items then
    NS.Utils:PrintError("Items module not loaded")
    return
  end
  
  local stats = NS.Items:GetDetailedStats()
  print(stats)
end

function NS.Commands:HandleLifetime()
  if not NS.Stats then
    NS.Utils:PrintError("Stats module not loaded")
    return
  end
  
  print(NS.Stats:GetCharacterStatsFormatted())
  print("")
  print(NS.Stats:GetAccountStatsFormatted())
end

function NS.Commands:HandleReset()
  if NS.Tracking then NS.Tracking:ResetSession() end
  if NS.Items then NS.Items:ResetSession() end
  if NS.UI then NS.UI:UpdateDisplay() end
  NS.Utils:PrintWarning("Session reset - all data cleared")
end

function NS.Commands:HandleHide()
  NS.Data:SetHidden(true)
  NS.UI:UpdateVisibility()
  NS.Utils:PrintWarning("Window hidden")
end

function NS.Commands:HandleShow()
  NS.Data:SetHidden(false)
  NS.UI:UpdateVisibility()
  NS.Utils:PrintWarning("Window shown")
end

function NS.Commands:HandleLock()
  NS.Data:SetLocked(true)
  NS.UI:OnLockSettingChanged()
  NS.Utils:PrintWarning("Window locked (Shift-drag still moves)")
end

function NS.Commands:HandleUnlock()
  NS.Data:SetLocked(false)
  NS.UI:OnLockSettingChanged()
  NS.Utils:PrintWarning("Window unlocked (drag and resize enabled)")
end

function NS.Commands:HandleMinimapCommand(msg)
  local subCmd = msg:match("^minimap%s+(%S+)$")
  
  if not subCmd then
    NS.Utils:PrintError("Usage: /pp minimap on|off|reset")
    return
  end
  
  if subCmd == "on" then
    NS.Data:SetMinimapHidden(false)
    if NS.Minimap then
      NS.Minimap:UpdateVisibility()
    end
    NS.Utils:PrintWarning("Minimap icon shown")
    
  elseif subCmd == "off" then
    NS.Data:SetMinimapHidden(true)
    if NS.Minimap then
      NS.Minimap:UpdateVisibility()
    end
    NS.Utils:PrintWarning("Minimap icon hidden")
    
  elseif subCmd == "reset" then
    NS.Data:ResetMinimapPosition()
    if NS.Minimap then
      NS.Minimap:UpdatePosition()
    end
    NS.Utils:PrintWarning("Minimap icon position reset")
    
  else
    NS.Utils:PrintError("Usage: /pp minimap on|off|reset")
  end
end

function NS.Commands:HandleIconCommand(msg)
  local subCmd = msg:match("^icon%s+(%S+)$")
  
  if not subCmd then
    NS.Utils:PrintError("Usage: /pp icon on|off")
    return
  end
  
  if subCmd == "on" then
    NS.Data:SetShowIcon(true)
    NS.UI:OnIconSettingChanged()
    NS.Utils:PrintWarning("Icon shown")
    
  elseif subCmd == "off" then
    NS.Data:SetShowIcon(false)
    NS.UI:OnIconSettingChanged()
    NS.Utils:PrintWarning("Icon hidden")
    
  else
    NS.Utils:PrintError("Usage: /pp icon on|off")
  end
end

function NS.Commands:HandleWindowCommand(msg)
  local seconds = msg:match("^window%s+(%d+%.?%d*)$")
  
  if not seconds then
    NS.Utils:PrintError("Usage: /pp window <seconds> (0.1 to 10)")
    return
  end
  
  seconds = tonumber(seconds)
  
  if not seconds then
    NS.Utils:PrintError("Invalid number")
    return
  end
  
  if NS.Tracking:SetDetectionWindow(seconds) then
    NS.Utils:PrintWarning(string.format("Detection window set to %.1fs", seconds))
  else
    local min = NS.Config.MIN_WINDOW_SECONDS
    local max = NS.Config.MAX_WINDOW_SECONDS
    NS.Utils:PrintError(string.format("Window must be between %.1f and %.1f seconds", min, max))
  end
end


