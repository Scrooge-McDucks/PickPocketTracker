local _, NS = ...

-- ---------- Chat helpers ----------
local function color(hex, text)
  return "|cff" .. hex .. tostring(text) .. "|r"
end

NS.tag = color("00ff66", NS.name .. ":") .. " "

function NS.msg(hex, text)
  if hex then
    print(NS.tag .. color(hex, text))
  else
    print(NS.tag .. tostring(text))
  end
end

-- ---------- Money formatting ----------
function NS.formatGSC(copper)
  local gold = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local cop = copper % 100
  return string.format("%dg %ds %dc", gold, silver, cop)
end

-- ---------- Pick Pocket tracker (the “pick pocket function” lives here) ----------
-- This module tracks “pickpocket-attributed copper” for the current session.
-- Core calls:
--   NS.PP:OnLogin()
--   NS.PP:OnPickPocketCast()
--   NS.PP:OnMoneyChanged()
-- and reads:
--   NS.PP.sessionCopper

NS.PP = NS.PP or {}
NS.PP.PICK_POCKET_SPELL_ID = 921
NS.PP.windowSeconds = 2.0

NS.PP.sessionCopper = 0
NS.PP._lastPPTime = 0
NS.PP._lastMoney = 0

function NS.PP:OnLogin()
  self._lastMoney = GetMoney()
end

function NS.PP:ResetSession()
  self.sessionCopper = 0
end

function NS.PP:SetWindowSeconds(sec)
  self.windowSeconds = sec
end

function NS.PP:OnPickPocketCast()
  self._lastPPTime = GetTime()
end

-- Returns the copper delta attributed to pick pocket (0 if not attributed)
function NS.PP:OnMoneyChanged()
  local money = GetMoney()
  local delta = money - self._lastMoney
  self._lastMoney = money

  if delta <= 0 then return 0 end

  local withinWindow = (GetTime() - self._lastPPTime) <= self.windowSeconds
  if not withinWindow then return 0 end

  self.sessionCopper = self.sessionCopper + delta
  return delta
end
