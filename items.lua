-------------------------------------------------------------------------------
-- items.lua — Item detection, fence tracking, vendor-sale & auto-sell
--
-- Detection: CHAT_MSG_LOOT fires when an item enters the player's bags.
-- If the message arrives within the detection window after a Pick Pocket
-- cast, the item is attributed to pickpocketing. Same time-window approach
-- used by gold tracking — no bag-snapshot race conditions.
--
-- Fence eligibility: only items with a vendor sell price > 0 are marked as
-- fence items (eligible for autosell). Quest items or other unsellable
-- pickpocket loot are tracked for stats but excluded from fence/autosell.
--
-- Vendor sales: Bags are snapshotted on MERCHANT_SHOW. On MERCHANT_CLOSED
-- we diff the snapshot to detect which tracked items were sold.
--
-- Auto-sell: when enabled, opens a queue/ticker that sells fence items one
-- at a time, with graceful handling of items already sold by other addons.
--
-- Session lifecycle: Initialize() clears items so every login/reload starts
-- a fresh session, matching the behaviour of session gold in tracking.lua.
-------------------------------------------------------------------------------
local _, NS = ...

NS.Items = {}

-- Session-only state
NS.Items.vendorSnapshot     = nil
NS.Items.sessionVendorValue = 0
NS.Items.autoSellTicker     = nil
NS.Items.autoSellPending    = nil  -- { [itemID] = count sold so far this vendor session }

function NS.Items:Initialize()
  self.vendorSnapshot     = nil
  self.sessionVendorValue = 0
  self.autoSellPending    = nil
  -- BUG FIX: clear session items on login/reload so both session gold and
  -- session items start fresh together.  Previously items persisted across
  -- reloads via SavedVariables while session gold did not.
  NS.Data:ClearItems()
end

function NS.Items:ResetSession()
  self.sessionVendorValue = 0
  self.autoSellPending    = nil
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

--- Record a pickpocketed item.  If vendorPrice == 0 the item is tracked for
--- display/stats but is NOT marked as a fence item (isFence = false) and
--- will never be auto-sold.
function NS.Items:RecordPickpocketedItem(itemID, itemName, itemTexture, quantity)
  local vendorPrice = NS.Utils:GetVendorPrice(itemID)
  local isFence     = vendorPrice > 0
  local itemData    = NS.Data:GetItem(itemID)

  if not itemData then
    itemData = {
      name         = itemName,
      texture      = itemTexture,
      quantity     = 0,
      vendorPrice  = vendorPrice,
      isFence      = isFence,
      totalValue   = 0,
      soldQuantity = 0,
      soldValue    = 0,
    }
  else
    -- Update vendor price if it was previously unknown (deferred cache)
    if itemData.vendorPrice == 0 and vendorPrice > 0 then
      itemData.vendorPrice = vendorPrice
      itemData.isFence     = true
      -- Recompute totalValue for existing quantity at the corrected price
      itemData.totalValue  = vendorPrice * itemData.quantity
    end
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
      NS.Utils:PrintNote(string.format("Pickpocketed: %dx %s (unsellable)", quantity, itemName))
    end
  end

  if NS.UI then NS.UI:UpdateDisplay() end
end

-------------------------------------------------------------------------------
-- Vendor sale detection (snapshot diff)
-------------------------------------------------------------------------------

function NS.Items:OnMerchantShow()
  self.vendorSnapshot  = NS.Utils:CreateBagSnapshot()
  self.autoSellPending = {}
end

function NS.Items:OnMerchantClosed()
  -- Cancel any running autosell ticker
  self:StopAutoSell()
  self.autoSellPending = nil

  if not self.vendorSnapshot then return end

  local after   = NS.Utils:CreateBagSnapshot()
  local tracked = NS.Data:GetItems()

  for itemID, itemData in pairs(tracked) do
    if itemData.quantity > 0 and itemData.isFence then
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
-- Auto-sell fence items (queue/ticker approach)
--
-- Sells one item per tick to avoid conflicts with other autosell addons.
-- Each tick re-scans bags to gracefully skip items already sold.
-------------------------------------------------------------------------------

function NS.Items:StartAutoSell()
  if self.autoSellTicker then return end  -- already running
  if not NS.Data:ShouldAutoSell() then return end

  local interval = NS.Config.AUTOSELL_DEFAULTS.tickInterval

  self.autoSellTicker = C_Timer.NewTicker(interval, function()
    local bag, slot, itemID = self:FindNextFenceSlot()
    if not bag then
      self:StopAutoSell()
      return
    end
    -- Re-check the slot (another addon may have sold it between find and sell)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info or info.itemID ~= itemID then return end
    -- Track how many of this item we've queued for sale this vendor session
    -- so we never sell more than the tracked pickpocket quantity.
    local pending = self.autoSellPending or {}
    pending[itemID] = (pending[itemID] or 0) + (info.stackCount or 1)
    self.autoSellPending = pending
    C_Container.UseContainerItem(bag, slot)
  end)
end

function NS.Items:StopAutoSell()
  if self.autoSellTicker then
    self.autoSellTicker:Cancel()
    self.autoSellTicker = nil
  end
end

--- Find the next bag slot containing a tracked fence item that we haven't
--- already queued for sale this vendor session.  Skips any slot whose stack
--- size exceeds the remaining tracked quantity (UseContainerItem sells the
--- whole stack — we must not oversell non-pickpocketed items).
--- Returns bag, slot, itemID or nil if nothing to sell.
function NS.Items:FindNextFenceSlot()
  local tracked = NS.Data:GetItems()
  local pending = self.autoSellPending or {}

  for bag = 0, NUM_BAG_SLOTS do
    local numSlots = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, numSlots do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID then
        local itemData = tracked[info.itemID]
        if itemData
          and itemData.isFence
          and itemData.vendorPrice > 0 then
          -- Only sell up to the tracked pickpocket quantity, minus what
          -- we've already sent to the vendor this session.
          local remaining = itemData.quantity - (pending[info.itemID] or 0)
          local stackCount = info.stackCount or 1
          -- Only sell if the entire stack fits within the remaining count.
          -- UseContainerItem sells the whole stack; we can't partial-sell.
          if remaining > 0 and stackCount <= remaining then
            return bag, slot, info.itemID
          end
        end
      end
    end
  end
  return nil
end

-------------------------------------------------------------------------------
-- Queries
-------------------------------------------------------------------------------

function NS.Items:GetSessionVendorValue() return self.sessionVendorValue end

function NS.Items:GetUnsoldValue()
  local total = 0
  for _, d in pairs(NS.Data:GetItems()) do
    if d.isFence then
      total = total + (d.quantity * d.vendorPrice)
    end
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
      if d.isFence then
        lines[#lines + 1] = string.format("  %s: %d looted, %d sold (%s), %d unsold (%s)",
          d.name, d.quantity + d.soldQuantity, d.soldQuantity,
          NS.Utils:FormatMoney(d.soldValue), d.quantity,
          NS.Utils:FormatMoney(d.vendorPrice * d.quantity))
      else
        lines[#lines + 1] = string.format("  %s [unsellable]: %d looted, %d in bags",
          d.name, d.quantity + d.soldQuantity, d.quantity)
      end
    end
  else
    lines[#lines + 1] = ""
    lines[#lines + 1] = "No items tracked yet. Go pickpocket something!"
  end

  return table.concat(lines, "\n")
end
