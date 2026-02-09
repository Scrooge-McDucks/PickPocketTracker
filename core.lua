-- core.lua
-- Event wiring + slash commands for Pick Pocket Tracker
--
-- Efficiency notes:
--  - We only update the UI when pickpocket-related money increases.
--  - We avoid extra work during events that don't matter.

local _, NS = ...

local goldFrame

local function applyVisibility()
  if not goldFrame then return end
  if PickPocketTrackerDB.hidden then
    goldFrame:Hide()
  else
    goldFrame:Show()
  end
end

local function updateWindow()
  if goldFrame then
    goldFrame:SetCopper(NS.PP.sessionCopper)
  end
end

-- ---------- Events ----------
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
f:RegisterEvent("PLAYER_MONEY")

f:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    NS.PP:OnLogin()

    goldFrame = NS.CreateGoldWindow()
    updateWindow()
    applyVisibility()

    -- minimap icon
    if NS.Minimap and NS.Minimap.Create then
      NS.Minimap:Create(function()
        PickPocketTrackerDB.hidden = not PickPocketTrackerDB.hidden
        applyVisibility()
      end)
    end

    NS.info("loaded. /pp prints total. /pp hide|show toggles window. /pp lock|unlock toggles resize (Shift-drag still moves). /pp icon on|off.")
    return
  end

  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, _, spellID = ...
    if unit == "player" and spellID == NS.PP.PICK_POCKET_SPELL_ID then
      NS.PP:OnPickPocketCast()
    end
    return
  end

  if event == "PLAYER_MONEY" then
    local added = NS.PP:OnMoneyChanged()
    if added > 0 then
      updateWindow()
    end
    return
  end
end)

-- ---------- Slash commands ----------
SLASH_PICKPOCKETTRACKER1 = "/pp"
SlashCmdList["PICKPOCKETTRACKER"] = function(msg)
  msg = (msg or ""):lower()

  if msg == "hide" then
    PickPocketTrackerDB.hidden = true
    applyVisibility()
    NS.warn("window hidden")
    return
  end

  if msg == "show" then
    PickPocketTrackerDB.hidden = false
    applyVisibility()
    NS.warn("window shown")
    return
  end

  if msg == "lock" then
    PickPocketTrackerDB.locked = true
    if goldFrame and goldFrame.ResizeGrip then goldFrame.ResizeGrip:Hide() end
    NS.warn("window locked (resize disabled; Shift-drag still moves)")
    return
  end

  if msg == "unlock" then
    PickPocketTrackerDB.locked = false
    if goldFrame and goldFrame.ResizeGrip then goldFrame.ResizeGrip:Show() end
    NS.warn("window unlocked (drag+resize enabled)")
    return
  end

  -- /pp minimap on|off
  local mmArg = msg:match("^minimap%s+(%S+)$")
  if mmArg then
    PickPocketTrackerDB.minimap = PickPocketTrackerDB.minimap or {}
    if mmArg == "on" then
      PickPocketTrackerDB.minimap.hide = false
      if NS.Minimap and NS.Minimap.Apply then NS.Minimap:Apply() end
      NS.warn("minimap icon shown")
      return
    end
    if mmArg == "off" then
      PickPocketTrackerDB.minimap.hide = true
      if NS.Minimap and NS.Minimap.Apply then NS.Minimap:Apply() end
      NS.warn("minimap icon hidden")
      return
    end
    if mmArg == "reset" then
      PickPocketTrackerDB.minimap.angle = 220
      PickPocketTrackerDB.minimap.radius = 80
      if NS.Minimap and NS.Minimap.Apply then NS.Minimap:Apply() end
      NS.warn("minimap icon position reset")
      return
    end
    NS.err("usage: /pp minimap on | /pp minimap off | /pp minimap reset")
    return
  end


  -- /pp icon on|off
  local iconArg = msg:match("^icon%s+(%S+)$")
  if iconArg then
    if iconArg == "on" then
      PickPocketTrackerDB.showIcon = true
      if goldFrame and goldFrame.ApplyIconSetting then goldFrame:ApplyIconSetting() end
      NS.warn("icon shown")
      return
    end
    if iconArg == "off" then
      PickPocketTrackerDB.showIcon = false
      if goldFrame and goldFrame.ApplyIconSetting then goldFrame:ApplyIconSetting() end
      NS.warn("icon hidden")
      return
    end
    NS.err("usage: /pp icon on | /pp icon off")
    return
  end

  if msg == "reset" then
    NS.PP:ResetSession()
    updateWindow()
    NS.warn("session reset")
    return
  end

  local sec = msg:match("^window%s+(%d+%.?%d*)$")
  if sec then
    sec = tonumber(sec)
    if sec and sec > 0 and sec <= 10 then
      NS.PP:SetWindowSeconds(sec)
      NS.warn(string.format("window set to %.1fs", sec))
    else
      NS.err("usage: /pp window 2.0 (0.1 to 10)")
    end
    return
  end

  if msg == "skin plumber" then
    PickPocketTrackerDB.usePlumberSkin = true
    NS.info("Plumber skin enabled (reload UI to apply)")
    return
  end

  if msg == "skin default" then
    PickPocketTrackerDB.usePlumberSkin = false
    NS.info("Default skin enabled (reload UI to apply)")
    return
  end

  -- Default: print total to chat
  NS.ok("Pickpocket haul this session: " .. NS.formatGSC(NS.PP.sessionCopper))
end