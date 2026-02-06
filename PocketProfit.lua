-- PocketProfit
-- Tracks gold gained from Pick Pocket per login session
-- Displays a small rogue-themed window that fades when not stealthed

local PP_SPELL_ID = 921       -- Pick Pocket
local WINDOW_SECONDS = 2.0    -- seconds after Pick Pocket to attribute gold

-- --------------------
-- Session state
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

-- --------------------
-- UI Frame
-- --------------------
local frame = CreateFrame("Frame", "PocketProfitFrame", UIParent, "BackdropTemplate")
frame:SetSize(260, 74)
frame:SetBackdrop({
  bgFile = "Interface/Tooltips/UI-Tooltip-Background",
  edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
frame:SetBackdropColor(0.02, 0.02, 0.02, 0.88)

-- Dragging
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

-- Main text
local haulText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
haulText:SetPoint("TOPLEFT", 12, -40)
haulText:SetText("Pickpocket gold this session: 0g 0s 0c")

-- Status text
local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
statusText:SetPoint("TOPLEFT", 12, -58)
statusText:SetText("Status: ...")

-- --------------------
-- Fade logic (single source of truth)
-- --------------------
local function applyStealthFade()
  if isStealthed() then
    frame:SetAlpha(1.0)
  else
    frame:SetAlpha(0.45)
  end
end

local function updateWindow()
  haulText:SetText("Pickpocket gold this session: " .. formatGSC(sessionCopper))
  statusText:SetText(
    isStealthed()
      and "|cff66ffccStatus: Stealthed|r"
      or  "|cffffcc66Status: Visible|r"
  )
  applyStealthFade()
end

frame:Show()

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
    print("|cff00ff66PocketProfit loaded.|r /pp to toggle, /pp reset to reset session.")

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
    -- Any other registered event: refresh fade/status
    applyStealthFade()
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
  else
    if frame:IsShown() then
      frame:Hide()
      print("|cff00ff66PocketProfit:|r window hidden.")
    else
      frame:Show()
      updateWindow()
      print("|cff00ff66PocketProfit:|r window shown.")
    end
  end
end
