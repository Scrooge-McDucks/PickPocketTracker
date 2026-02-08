-- Print messages only when stealth state changes (no spam).
local _, NS = ...

local lastStealthed = false

local function getStealthState()
  return IsStealthed and IsStealthed() or false
end

local function handleLogin()
  -- Set initial state so we don’t print ON/OFF on login.
  lastStealthed = getStealthState()
  NS.msg("aaaaaa", "loaded")
end

local function handleStealthUpdate()
  local now = getStealthState()
  if now == lastStealthed then return end

  NS.msg(now and "66ffcc" or "ffcc66", now and "Stealth ON" or "Stealth OFF")
  lastStealthed = now
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("UPDATE_STEALTH")
f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    handleLogin()
  else
    handleStealthUpdate()
  end
end)
