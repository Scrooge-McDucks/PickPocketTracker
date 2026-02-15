-------------------------------------------------------------------------------
-- items.lua — Item detection and vendor-sale tracking
--
-- Detection: CHAT_MSG_LOOT fires when an item enters the player's bags.
-- If the message arrives within the detection window after a Pick Pocket
-- cast, the item is attributed to pickpocketing. Same time-window approach
-- used by gold tracking — no bag-snapshot race conditions.
--
-- Vendor sales: Bags are snapshotted on MERCHANT_SHOW. On MERCHANT_CLOSED
-- we diff the snapshot to detect which tracked items were sold. This is
-- race-condition-free because MERCHANT_SHOW fires well before any selling.
-------------------------------------------------------------------------------
local _, NS = ...

NS.Items = {}

-- Session-only state
NS.Items.vendorSnapshot     = nil
NS.Items.sessionVendorValue = 0

function NS.Items:Initialize()
  self.vendorSnapshot     = nil
  self.sessionVendorValue = 0
end

function NS.Items:ResetSession()
  self.sessionVendorValue = 0
  NS.Data:ClearItems()
end

-------------------------------------------------------------------------------
-- Pickpocket item detection (via CHAT_MSG_LOOT)
-------------------------------------------------------------------------------

--- Called by events.lua when the player receives loot.
--- @param itemLink string  Partial item link ("|Hitem:12345:...|h")
--- @param quantity number  Stack count from the loot message
function NS.Items:OnLootReceived(itemLink, quantity)
  if not NS.Tracking or not NS.Tracking:IsInDetectionWindow() then
    return
  end

  local itemID = self:ExtractItemID(itemLink)
  if not itemID then return end

  -- GetItemInfo may need an async retry if the item isn't cached
  NS.Utils:GetItemInfo(itemID, function(id, name, texture)
    self:RecordPickpocketedItem(id, name, texture, quantity)
  end)
end

function NS.Items:ExtractItemID(itemLink)
  if not itemLink then return nil end
  local id = itemLink:match("item:(%d+)")
  return id and tonumber(id) or nil
end

function NS.Items:RecordPickpocketedItem(itemID, itemName, itemTexture, quantity)
  local vendorPrice = NS.Utils:GetVendorPrice(itemID)
  local itemData    = NS.Data:GetItem(itemID)

  if not itemData then
    itemData = {
      name         = itemName,
      texture      = itemTexture,
      quantity     = 0,
      vendorPrice  = vendorPrice,
      totalValue   = 0,
      soldQuantity = 0,
      soldValue    = 0,
    }
  end

  itemData.quantity   = itemData.quantity   + quantity
  itemData.totalValue = itemData.totalValue + (vendorPrice * quantity)
  NS.Data:SetItem(itemID, itemData)

  -- Optional chat message
  if NS.Data:ShouldChatLogItems() then
    if vendorPrice > 0 then
      NS.Utils:PrintInfo(string.format("Pickpocketed: %dx %s (Vendor: %s)",
        quantity, itemName, NS.Utils:FormatMoney(vendorPrice * quantity)))
    else
      NS.Utils:PrintInfo(string.format("Pickpocketed: %dx %s", quantity, itemName))
    end
  end

  if NS.UI then NS.UI:UpdateDisplay() end
end

-------------------------------------------------------------------------------
-- Vendor sale detection (snapshot diff)
-------------------------------------------------------------------------------

function NS.Items:OnMerchantShow()
  self.vendorSnapshot = NS.Utils:CreateBagSnapshot()
end

function NS.Items:OnMerchantClosed()
  if not self.vendorSnapshot then return end

  local after   = NS.Utils:CreateBagSnapshot()
  local tracked = NS.Data:GetItems()

  for itemID, itemData in pairs(tracked) do
    if itemData.quantity > 0 then
      local sold = (self.vendorSnapshot[itemID] or 0) - (after[itemID] or 0)
      if sold > 0 then
        -- Don't credit more than we're tracking
        self:RecordSale(itemID, itemData, math.min(sold, itemData.quantity))
      end
    end
  end

  self.vendorSnapshot = nil
end

function NS.Items:RecordSale(itemID, itemData, qty)
  local value = itemData.vendorPrice * qty

  itemData.quantity     = itemData.quantity     - qty
  itemData.soldQuantity = itemData.soldQuantity + qty
  itemData.soldValue    = itemData.soldValue    + value
  NS.Data:SetItem(itemID, itemData)

  self.sessionVendorValue = self.sessionVendorValue + value
  if NS.Stats then NS.Stats:RecordItemsSold(value) end

  if NS.Data:ShouldChatLogItems() then
    NS.Utils:PrintSuccess(string.format("Sold %dx %s for %s",
      qty, itemData.name, NS.Utils:FormatMoney(value)))
  end
end

-------------------------------------------------------------------------------
-- Queries
-------------------------------------------------------------------------------

function NS.Items:GetSessionVendorValue() return self.sessionVendorValue end

function NS.Items:GetUnsoldValue()
  local total = 0
  for _, d in pairs(NS.Data:GetItems()) do
    total = total + (d.quantity * d.vendorPrice)
  end
  return total
end

function NS.Items:GetUniqueItemCount()
  return NS.Data:GetItemCount()
end

--- Chat-formatted breakdown for /pp stats
function NS.Items:GetDetailedStats()
  local lines = {}
  lines[#lines + 1] = "=== Pickpocket Session Stats ==="

  if NS.Tracking then
    lines[#lines + 1] = "Gold looted: " .. NS.Utils:FormatMoney(NS.Tracking:GetSessionGold())
  end
  lines[#lines + 1] = "Items sold: " .. NS.Utils:FormatMoney(self.sessionVendorValue)

  local unsold = self:GetUnsoldValue()
  if unsold > 0 then
    lines[#lines + 1] = "Unsold items: " .. NS.Utils:FormatMoney(unsold)
  end

  if NS.Tracking then
    lines[#lines + 1] = "Total value: " .. NS.Utils:FormatMoney(NS.Tracking:GetTotalValue())
  end

  local count = self:GetUniqueItemCount()
  if count > 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format("Items tracked (%d unique):", count)

    local sorted = NS.Utils:TableSortBy(NS.Data:GetItems(), function(i) return i.totalValue end)
    for _, entry in ipairs(sorted) do
      local d = entry.value
      lines[#lines + 1] = string.format("  %s: %d looted, %d sold (%s), %d unsold (%s)",
        d.name, d.quantity + d.soldQuantity, d.soldQuantity,
        NS.Utils:FormatMoney(d.soldValue), d.quantity,
        NS.Utils:FormatMoney(d.vendorPrice * d.quantity))
    end
  else
    lines[#lines + 1] = ""
    lines[#lines + 1] = "No items tracked yet. Go pickpocket something!"
  end

  return table.concat(lines, "\n")
end
