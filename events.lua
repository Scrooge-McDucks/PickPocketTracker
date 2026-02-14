-- Event handling and routing
local _, NS = ...

NS.Events = {}

local eventFrame = CreateFrame("Frame")

function NS.Events:Register()
  eventFrame:RegisterEvent("PLAYER_LOGIN")
  eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  eventFrame:RegisterEvent("PLAYER_MONEY")
  eventFrame:RegisterEvent("MERCHANT_SHOW")
  eventFrame:RegisterEvent("MERCHANT_CLOSED")
  
  eventFrame:SetScript("OnEvent", function(_, event, ...)
    NS.Events:OnEvent(event, ...)
  end)
end

function NS.Events:OnEvent(event, ...)
  if event == "PLAYER_LOGIN" then
    self:OnPlayerLogin()
    
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    self:OnUnitSpellCastSucceeded(...)
    
  elseif event == "PLAYER_MONEY" then
    self:OnPlayerMoney()
    
  elseif event == "MERCHANT_SHOW" then
    self:OnMerchantShow()
    
  elseif event == "MERCHANT_CLOSED" then
    self:OnMerchantClosed()
  end
end

-- Event handlers
function NS.Events:OnPlayerLogin()
  -- Initialize modules in order
  NS.Data:Initialize()
  NS.Tracking:Initialize()
  NS.Items:Initialize()
  
  if NS.Stats then
    NS.Stats:Initialize()
  end
  
  if NS.Options then
    NS.Options:RegisterDialogs()
  end
  
  NS.UI:Initialize()
  
  -- Create minimap button
  if NS.Minimap then
    NS.Minimap:Create(function()
      local hidden = NS.Data:IsHidden()
      NS.Data:SetHidden(not hidden)
      NS.UI:UpdateVisibility()
    end)
  end
  
  local version = NS.Config.VERSION
  NS.Utils:PrintInfo(string.format("v%s loaded. Type /pp for options.", version))
end

function NS.Events:OnUnitSpellCastSucceeded(unit, castGUID, spellID)
  if unit ~= "player" then return end
  if spellID ~= NS.Config.PICK_POCKET_SPELL_ID then return end
  
  NS.Tracking:OnPickPocketCast()
  NS.Items:OnPickPocketCast()
end

function NS.Events:OnPlayerMoney()
  local goldGained = NS.Tracking:OnMoneyChanged()
  
  if goldGained > 0 then
    NS.UI:UpdateDisplay()
  end
end

function NS.Events:OnMerchantShow()
  NS.Items:OnMerchantShow()
end

function NS.Events:OnMerchantClosed()
  NS.Items:OnMerchantClosed()
  NS.UI:UpdateDisplay()
end
