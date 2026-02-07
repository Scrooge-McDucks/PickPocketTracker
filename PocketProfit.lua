-- PocketStealth: prints a message when the player enters/exits stealth.

local ADDON_TAG = "|cff00ff66PocketStealth:|r"

local lastStealthed -- last known stealth state (boolean)

local function isStealthed()
  -- Defensive: IsStealthed should exist in retail, but keep it safe.
  return IsStealthed and IsStealthed() or false
end

local function onStealthChanged()
  local now = isStealthed()
  if now == lastStealthed then return end

  if now then
    print(ADDON_TAG .. " Stealth ON")
  else
    print(ADDON_TAG .. " Stealth OFF")
  end

  lastStealthed = now
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("UPDATE_STEALTH")
f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    -- Initialize state so we don’t print on login unless you want that behaviour.
    lastStealthed = isStealthed()
    print(ADDON_TAG .. " loaded")
    return
  end

  onStealthChanged()
end)
