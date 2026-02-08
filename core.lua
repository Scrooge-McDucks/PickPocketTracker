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

    NS.info("loaded. /pp shows total, /pp hide/show toggles window.")
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
