local PP_SPELL_ID = 921       -- Pick Pocket spellID
local WINDOW_SECONDS = 2.0    -- attribute gold gained within this many seconds of pick pocket

-- session state (resets on login/reload)
local sessionCopper = 0
local lastPPTime = 0
local lastMoney = 0

local function formatGSC(copper)
  local gold = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local cop = copper % 100
  return string.format("%dg %ds %dc", gold, silver, cop)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
f:RegisterEvent("PLAYER_MONEY")

f:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    lastMoney = GetMoney()
    print("|cff00ff00PocketProfit loaded.|r Use /pp to print session pickpocket gold.")

  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, _, spellID = ...
    if unit == "player" and spellID == PP_SPELL_ID then
      lastPPTime = GetTime()
    end

  elseif event == "PLAYER_MONEY" then
    local money = GetMoney()
    local delta = money - lastMoney
    lastMoney = money

    if delta > 0 and (GetTime() - lastPPTime) <= WINDOW_SECONDS then
      sessionCopper = sessionCopper + delta
    end
  end
end)

SLASH_POCKETPROFIT1 = "/pp"
SlashCmdList["POCKETPROFIT"] = function(msg)
  msg = (msg or ""):lower()

  if msg == "reset" then
    sessionCopper = 0
    print("|cff00ff00PocketProfit:|r session reset.")
  else
    print("|cff00ff00PocketProfit:|r session pickpocket gold = " .. formatGSC(sessionCopper))
  end
end
