-- Item tracking logic
-- Uses CHAT_MSG_LOOT to detect pickpocketed items (same time-window approach as gold tracking)
local _, NS = ...

NS.Items = {}

-- Runtime state
NS.Items.vendorSnapshot = nil
NS.Items.sessionVendorValue = 0

function NS.Items:Initialize()
  self.vendorSnapshot = nil
  self.sessionVendorValue = 0
end

function NS.Items:ResetSession()
  self.sessionVendorValue = 0
  NS.Data:ClearItems()
end

-- Called from CHAT_MSG_LOOT when player receives an item
function NS.Items:OnLootReceived(itemLink, quantity)
  -- Only attribute to pickpocket if within the detection window
  if not NS.Tracking or not NS.Tracking:IsInDetectionWindow() then
    return
  end

  -- Extract itemID from the item link: |Hitem:ITEMID:...|h
  local itemID = self:ExtractItemID(itemLink)
  if not itemID then return end

  self:TrackItem(itemID, quantity)
end

function NS.Items:ExtractItemID(itemLink)
  if not itemLink then return nil end
  local id = itemLink:match("item:(%d+)")
  if id then return tonumber(id) end
  return nil
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

  if NS.Data:ShouldChatLogItems() then
    if vendorPrice > 0 then
      NS.Utils:PrintInfo(string.format("Pickpocketed: %dx %s (Vendor: %s)",
        quantity, itemName, NS.Utils:FormatMoney(vendorPrice * quantity)))
    else
      NS.Utils:PrintInfo(string.format("Pickpocketed: %dx %s",
        quantity, itemName))
    end
  end

  if NS.UI then
    NS.UI:UpdateDisplay()
  end
end

-- Vendor interaction (snapshot approach is fine here - no race condition)
function NS.Items:OnMerchantShow()
  self.vendorSnapshot = NS.Utils:CreateBagSnapshot()
end

function NS.Items:OnMerchantClosed()
  if not self.vendorSnapshot then return end

  local newSnapshot = NS.Utils:CreateBagSnapshot()
  local trackedItems = NS.Data:GetItems()

  for itemID, itemData in pairs(trackedItems) do
    local oldCount = self.vendorSnapshot[itemID] or 0
    local newCount = newSnapshot[itemID] or 0
    local sold = oldCount - newCount

    if sold > 0 then
      local countToAttribute = math.min(sold, itemData.quantity)
      if countToAttribute > 0 then
        self:OnItemSold(itemID, itemData, countToAttribute)
      end
    end
  end

  self.vendorSnapshot = nil
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

  if NS.Data:ShouldChatLogItems() then
    NS.Utils:PrintSuccess(string.format("Sold %dx %s for %s",
      quantitySold, itemData.name, NS.Utils:FormatMoney(soldValue)))
  end
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

function NS.Items:GetUniqueItemCount()
  return NS.Data:GetItemCount()
end

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
      local unsoldVal = itemData.vendorPrice * itemData.quantity

      local line = string.format("  %s: %d looted, %d sold (%s), %d unsold (%s)",
        itemData.name,
        itemData.quantity + itemData.soldQuantity,
        itemData.soldQuantity,
        NS.Utils:FormatMoney(itemData.soldValue),
        itemData.quantity,
        NS.Utils:FormatMoney(unsoldVal)
      )

      table.insert(lines, line)
    end
  else
    table.insert(lines, "")
    table.insert(lines, "No items tracked yet. Go pickpocket something!")
  end

  return table.concat(lines, "\n")
end
