-- Utility functions
local _, NS = ...

NS.Utils = {}

-- Chat output
local function ColorText(hex, text)
  return "|cff" .. hex .. tostring(text) .. "|r"
end

local function GetAddonTag()
  local tagColor = NS.Config:GetColor("TAG")
  local addonName = NS.Config.ADDON_NAME
  return ColorText(tagColor, addonName .. ":") .. " "
end

function NS.Utils:Print(hex, text)
  if hex then
    print(GetAddonTag() .. ColorText(hex, text))
  else
    print(GetAddonTag() .. tostring(text))
  end
end

function NS.Utils:PrintInfo(text)
  self:Print(NS.Config:GetColor("INFO"), text)
end

function NS.Utils:PrintSuccess(text)
  self:Print(NS.Config:GetColor("GOOD"), text)
end

function NS.Utils:PrintWarning(text)
  self:Print(NS.Config:GetColor("WARN"), text)
end

function NS.Utils:PrintError(text)
  self:Print(NS.Config:GetColor("BAD"), text)
end

-- Money formatting
function NS.Utils:FormatMoney(copper)
  local gold = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local cop = copper % 100
  
  local iconSize = NS.Config.MONEY_ICONS.size
  local goldIcon = NS.Config.MONEY_ICONS.goldIcon
  local silverIcon = NS.Config.MONEY_ICONS.silverIcon
  local copperIcon = NS.Config.MONEY_ICONS.copperIcon
  
  local gIcon = ("|T%s:%d:%d:0:0|t"):format(goldIcon, iconSize, iconSize)
  local sIcon = ("|T%s:%d:%d:0:0|t"):format(silverIcon, iconSize, iconSize)
  local cIcon = ("|T%s:%d:%d:0:0|t"):format(copperIcon, iconSize, iconSize)
  
  return string.format("%d%s %d%s %d%s", gold, gIcon, silver, sIcon, cop, cIcon)
end

function NS.Utils:FormatMoneyCompact(copper)
  local gold = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local cop = copper % 100
  
  if gold > 0 then
    return string.format("%dg %ds", gold, silver)
  elseif silver > 0 then
    return string.format("%ds %dc", silver, cop)
  else
    return string.format("%dc", cop)
  end
end

-- String helpers
function NS.Utils:TrimString(str)
  return str:match("^%s*(.-)%s*$")
end

-- Table helpers
function NS.Utils:TableCount(tbl)
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  return count
end

function NS.Utils:TableSortBy(tbl, keyFunc)
  local array = {}
  for key, value in pairs(tbl) do
    table.insert(array, {key = key, value = value})
  end
  
  table.sort(array, function(a, b)
    return keyFunc(a.value) > keyFunc(b.value)
  end)
  
  return array
end

-- Math helpers
function NS.Utils:Round(number)
  return math.floor(number + 0.5)
end

function NS.Utils:Clamp(value, min, max)
  return math.max(min, math.min(max, value))
end

function NS.Utils:Percentage(part, total)
  if total == 0 then return 0 end
  return (part / total) * 100
end

-- Item helpers
local function SafeGetItemInfo(itemID)
  if C_Item and C_Item.GetItemInfo then
    return C_Item.GetItemInfo(itemID)
  elseif GetItemInfo then
    return GetItemInfo(itemID)
  end
  return nil
end

function NS.Utils:GetItemInfo(itemID, callback, retries)
  retries = retries or 0
  local itemName, _, _, _, _, _, _, _, _, itemTexture = SafeGetItemInfo(itemID)
  
  if itemName then
    callback(itemID, itemName, itemTexture)
  elseif retries < 10 then
    C_Timer.After(NS.Config.ITEM_CACHE_RETRY_DELAY, function()
      self:GetItemInfo(itemID, callback, retries + 1)
    end)
  end
end

function NS.Utils:GetVendorPrice(itemID)
  local vendorPrice = select(11, SafeGetItemInfo(itemID))
  return vendorPrice or 0
end

-- Bag scanning
function NS.Utils:CreateBagSnapshot()
  local snapshot = {}
  
  for bag = 0, NUM_BAG_SLOTS do
    local numSlots = C_Container.GetContainerNumSlots(bag) or 0
    
    for slot = 1, numSlots do
      local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
      
      if itemInfo and itemInfo.itemID then
        local itemID = itemInfo.itemID
        local count = itemInfo.stackCount or 1
        snapshot[itemID] = (snapshot[itemID] or 0) + count
      end
    end
  end
  
  return snapshot
end

function NS.Utils:CompareBagSnapshots(oldSnapshot, newSnapshot)
  local differences = {}
  
  for itemID, newCount in pairs(newSnapshot) do
    local oldCount = oldSnapshot[itemID] or 0
    local gained = newCount - oldCount
    
    if gained > 0 then
      differences[itemID] = gained
    end
  end
  
  return differences
end
