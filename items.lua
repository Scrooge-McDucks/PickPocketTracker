-- Item tracking logic
local _, NS = ...

NS.Items = {}

-- Runtime state
NS.Items.bagSnapshot = {}
NS.Items.expectingItems = false
NS.Items.sessionVendorValue = 0

function NS.Items:Initialize()
  self.bagSnapshot = NS.Utils:CreateBagSnapshot()
  self.sessionVendorValue = 0
  self.expectingItems = false
end

function NS.Items:ResetSession()
  self.sessionVendorValue = 0
  self.expectingItems = false
  NS.Data:ClearItems()
end

function NS.Items:OnPickPocketCast()
  self.expectingItems = true
  
  C_Timer.After(NS.Config.ITEM_CHECK_DELAY, function()
    self:CheckForNewItems()
  end)
end

function NS.Items:CheckForNewItems()
  if not self.expectingItems then return end
  self.expectingItems = false
  
  local newSnapshot = NS.Utils:CreateBagSnapshot()
  local newItems = NS.Utils:CompareBagSnapshots(self.bagSnapshot, newSnapshot)
  
  for itemID, quantity in pairs(newItems) do
    self:TrackItem(itemID, quantity)
  end
  
  self.bagSnapshot = newSnapshot
end

function NS.Items:TrackItem(itemID, quantity)
  NS.Utils:GetItemInfo(itemID, function(id, name, texture)
    self:OnItemInfoLoaded(id, name, texture, quantity)
  end)
end

function NS.Items:OnItemInfoLoaded(itemID, itemName, itemTexture, quantity)
  local vendorPrice = NS.Utils:GetVendorPrice(itemID)
  
  local itemData = NS.Data:GetItem(itemID)
  
  if not itemData then
    itemData = {
      name = itemName,
      texture = itemTexture,
      quantity = 0,
      vendorPrice = vendorPrice,
      totalValue = 0,
      soldQuantity = 0,
      soldValue = 0,
    }
  end
  
  itemData.quantity = itemData.quantity + quantity
  itemData.totalValue = itemData.totalValue + (vendorPrice * quantity)
  
  NS.Data:SetItem(itemID, itemData)
  
  if vendorPrice > 0 then
    NS.Utils:PrintInfo(string.format("Pickpocketed: %dx %s (Vendor: %s)", 
      quantity, itemName, NS.Utils:FormatMoney(vendorPrice * quantity)))
  else
    NS.Utils:PrintInfo(string.format("Pickpocketed: %dx %s (No vendor value)", 
      quantity, itemName))
  end
end

-- Vendor interaction
function NS.Items:OnMerchantShow()
  self.bagSnapshot = NS.Utils:CreateBagSnapshot()
end

function NS.Items:OnMerchantClosed()
  local newSnapshot = NS.Utils:CreateBagSnapshot()
  
  for itemID, itemData in pairs(NS.Data:GetItems()) do
    local oldCount = self.bagSnapshot[itemID] or 0
    local newCount = newSnapshot[itemID] or 0
    local sold = oldCount - newCount
    
    if sold > 0 and itemData.quantity >= sold then
      self:OnItemSold(itemID, itemData, sold)
    end
  end
  
  self.bagSnapshot = newSnapshot
end

function NS.Items:OnItemSold(itemID, itemData, quantitySold)
  local soldValue = itemData.vendorPrice * quantitySold
  
  itemData.quantity = itemData.quantity - quantitySold
  itemData.soldQuantity = itemData.soldQuantity + quantitySold
  itemData.soldValue = itemData.soldValue + soldValue
  
  NS.Data:SetItem(itemID, itemData)
  
  self.sessionVendorValue = self.sessionVendorValue + soldValue
  
  if NS.Stats then
    NS.Stats:RecordItemsSold(soldValue)
  end
  
  NS.Utils:PrintSuccess(string.format("Sold %dx %s for %s", 
    quantitySold, itemData.name, NS.Utils:FormatMoney(soldValue)))
end

-- Statistics
function NS.Items:GetSessionVendorValue()
  return self.sessionVendorValue
end

function NS.Items:GetUnsoldValue()
  local total = 0
  
  for _, itemData in pairs(NS.Data:GetItems()) do
    total = total + (itemData.quantity * itemData.vendorPrice)
  end
  
  return total
end

function NS.Items:GetTotalItemValue()
  return self.sessionVendorValue + self:GetUnsoldValue()
end

function NS.Items:GetUniqueItemCount()
  return NS.Data:GetItemCount()
end

-- Formatted output
function NS.Items:GetDetailedStats()
  local lines = {}
  
  table.insert(lines, "=== Pickpocket Session Stats ===")
  
  if NS.Tracking then
    table.insert(lines, string.format("Gold looted: %s", 
      NS.Utils:FormatMoney(NS.Tracking:GetSessionGold())))
  end
  table.insert(lines, string.format("Items sold: %s", 
    NS.Utils:FormatMoney(self.sessionVendorValue)))
  
  local unsoldValue = self:GetUnsoldValue()
  if unsoldValue > 0 then
    table.insert(lines, string.format("Unsold items: %s", 
      NS.Utils:FormatMoney(unsoldValue)))
  end
  
  if NS.Tracking then
    table.insert(lines, string.format("Total value: %s", 
      NS.Utils:FormatMoney(NS.Tracking:GetTotalValue())))
  end
  
  local itemCount = self:GetUniqueItemCount()
  if itemCount > 0 then
    table.insert(lines, "")
    table.insert(lines, string.format("Items tracked (%d unique):", itemCount))
    
    local sortedItems = NS.Utils:TableSortBy(NS.Data:GetItems(), function(item)
      return item.totalValue
    end)
    
    for _, entry in ipairs(sortedItems) do
      local itemData = entry.value
      local unsoldValue = itemData.vendorPrice * itemData.quantity
      
      local line = string.format("  %s: %d looted, %d sold (%s), %d unsold (%s)",
        itemData.name,
        itemData.quantity + itemData.soldQuantity,
        itemData.soldQuantity,
        NS.Utils:FormatMoney(itemData.soldValue),
        itemData.quantity,
        NS.Utils:FormatMoney(unsoldValue)
      )
      
      table.insert(lines, line)
    end
  else
    table.insert(lines, "")
    table.insert(lines, "No items tracked yet. Go pickpocket something!")
  end
  
  return table.concat(lines, "\n")
end

function NS.Items:GetBriefSummary()
  local itemCount = self:GetUniqueItemCount()
  local unsoldValue = self:GetUnsoldValue()
  
  if itemCount == 0 then
    return "No items tracked"
  end
  
  return string.format("%d items (%s unsold)", 
    itemCount, NS.Utils:FormatMoney(unsoldValue))
end
