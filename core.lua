local _, NS = ...

local function printSessionTotal()
  NS.msg("66ffcc", "Pickpocket gold this session: " .. NS.formatGSC(NS.PP.sessionCopper))
end

-- ---------- Events ----------
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
f:RegisterEvent("PLAYER_MONEY")

f:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    NS.PP:OnLogin()
    NS.msg("aaaaaa", "loaded. Use /pp to print session total.")
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
    -- keep it quiet by default; uncomment if you want per-hit spam while learning
    -- if added > 0 then NS.msg("aaaaaa", "Picked: +" .. NS.formatGSC(added)) end
    return
  end
end)

-- ---------- Slash commands ----------
SLASH_PICKPOCKETTRACKER1 = "/pp"
SlashCmdList["PICKPOCKETTRACKER"] = function(msg)
  msg = (msg or ""):lower()

  if msg == "reset" then
    NS.PP:ResetSession()
    NS.msg("ffcc66", "Session reset.")
    printSessionTotal()
    return
  end

  local sec = msg:match("^window%s+(%d+%.?%d*)$")
  if sec then
    sec = tonumber(sec)
    if sec and sec > 0 and sec <= 10 then
      NS.PP:SetWindowSeconds(sec)
      NS.msg("ffcc66", string.format("Window set to %.1fs", sec))
    else
      NS.msg("ff6666", "Usage: /pp window 2.0  (0.1 to 10)")
    end
    return
  end

  -- default: print session total
  printSessionTotal()
end
