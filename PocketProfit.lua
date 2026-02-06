-- PocketProfit
-- Tracks gold gained from Pick Pocket per login session
-- Window rules:
--   - Full visible in stealth
--   - Full visible in combat (even if not stealthed)
--   - Dim when out of stealth and not in combat
-- Persists window hidden/shown state across login/reload via SavedVariables

local PP_SPELL_ID = 921       -- Pick Pocket
local WINDOW_SECONDS = 2.0    -- seconds after Pick Pocket to attribute gold
local DIM_ALPHA = 0.55        -- dim level when visible and not in combat

-- --------------------
-- SavedVariables
-- --------------------
PocketProfitDB = PocketProfitDB or {}

-- default values
if PocketProfitDB.hidden == nil then PocketProfitDB.hidden = false end

-- --------------------
-- Session state (resets on login/reload)
-- --------------------
local sessionCopper = 0
local lastPPTime = 0
local lastMoney = 0

-- --------------------
-- Helpers
-- --------------------
local function formatGSC(copper)
  local gold = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local cop = copper % 100
  return string.format("%dg %ds %dc", gold, silver, cop)
end

local function isStealthed()
  return IsStealthed and IsStealthed()
end

local function inCombat()
  return InCombatLockdown and InCombatLockdown()
end

-- --------------------
-- UI Frame
-- --------------------
local frame = CreateFrame("Frame", "PocketProfitFrame", UIParent, "BackdropTemplate")
frame:SetSize(290, 74) -- slightly wider to prevent text overflow
frame:SetBackdrop({
  bgFile = "Interface/Tooltips/UI-Tooltip-Background",
  edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
frame:SetBackdropColor(0.02, 0.02, 0.02, 0.88)

-- Dragging (simple for now; not saving position in this version)
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetPoint("CENTER")

-- Icon
local icon = frame:CreateTexture(nil, "ARTWORK")
icon:SetSize(18, 18)
icon:SetPoint("TOPLEFT", 10, -10)
icon:SetTexture("Interface/Icons/Ability_Rogue_PickPocket")

-- Title
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
title:SetText("|cff00ff66PocketProfit|r")

-- Accent line
local accent = frame:CreateTexture(nil, "BACKGROUND")
accent:SetHeight(1)
accent:SetPoint("TOPLEFT", 10, -32)
accent:SetPoint("TOPRIGHT", -10, -32)
accent:SetColorTexture(0.0, 1.0, 0.4, 0.35)

-- Main text (short label to prevent overflow)
local haulText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
haulText:SetPoint("TOPLEFT", 12, -40)
haulText:SetPoint("TOPRIGHT", -12, -40) -- constrain within frame
haulText:SetJustifyH("LEFT")
haulText:SetWordWrap(false)
haulText:SetText("Haul: 0g 0s 0c")

-- Status text
local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
statusText:SetPoint("TOPLEFT", 12, -58)
statusText:SetPoint("TOPRIGHT", -12, -58)
statusText:SetJustifyH("LEFT")
statusText:SetWordWrap(false)
statusText:SetText("Status: ...")

-- --------------------
-- Visibility rules (single source of truth)
-- --------------------
local function applyVisibilityRules()
  if inCombat() or isStealthed() then
    frame:SetAlpha(1.0)
  else
    frame:SetAlpha(DIM_ALPHA)
  end
end

local function updateWindow()
  haulText:SetText("Haul: " .. formatGSC(sessionCopper))

  if inCombat() then
    statusText:SetText("|cffff6666Status: In combat|r")
  elseif isStealthed() then
    statusText:SetText("|cff66ffccStatus: Stealthed|r")
  else
    statusText:SetText("|cffffcc66Status: Visible|r")
  end

  applyVisibilityRules()
end

-- --------------------
-- Events
-- --------------------
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
f:RegisterEvent("PLAYER_MONEY")
f:RegisterEvent("PLAYER_FLAGS_CHANGED")      -- stealth changes
f:RegisterEvent("PLAYER_REGEN_DISABLED")     -- enter combat
f:RegisterEvent("PLAYER_REGEN_ENABLED")      -- leave combat
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")

f:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    lastMoney = GetMoney()
    updateWindow()

    -- Apply persisted hidden state
    if PocketProfitDB.hidden then
      frame:Hide()
    else
      frame:Show()
    end

    print("|cff00ff66PocketProfit loaded.|r /pp toggles, /pp reset resets session.")

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
      updateWindow()
    end

  else
    -- Refresh alpha/status on stealth/combat/zone events
    updateWindow()
  end
end)

-- --------------------
-- Slash command
-- --------------------
SLASH_POCKETPROFIT1 = "/pp"
SlashCmdList["POCKETPROFIT"] = function(msg)
  msg = (msg or ""):lower()

  if msg == "reset" then
    sessionCopper = 0
    updateWindow()
    print("|cff00ff66PocketProfit:|r session reset.")
    return
  end

  if frame:IsShown() then
    frame:Hide()
    PocketProfitDB.hidden = true
    print("|cff00ff66PocketProfit:|r window hidden.")
  else
    frame:Show()
    PocketProfitDB.hidden = false
    updateWindow()
    print("|cff00ff66PocketProfit:|r window shown.")
  end
end
