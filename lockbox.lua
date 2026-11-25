-------------------------------------------------------------------------------
-- lockbox.lua — Gold from pickpocketed lockboxes / junkboxes
--
-- A junkbox is pickpocketed, then Pick Locked, then opened — often minutes or
-- days later, far outside the post-cast detection window in tracking.lua, so
-- its gold was never counted.
--
-- Detection:
--   1. On LOOT_READY / LOOT_OPENED, the loot's source GUID ("Item-...") is
--      mapped to an item ID. If that item is a box we pickpocketed (or any
--      junkbox), the box is being opened. This works whatever opened it:
--      Blizzard's bags, a bag addon, or a /use macro.
--   2. Fallback for clients that can't map a GUID to an item: a post-hook on
--      C_Container.UseContainerItem notices the player clicking such a box,
--      and an item-sourced loot window must follow within a few seconds.
--   3. Until shortly after LOOT_CLOSED, IsLooting() is true and tracking.lua
--      attributes any gold gained to pickpocketing.
--
-- Using an item at a vendor sells it, so uses while the merchant window is
-- open are ignored (that is also how auto-sell calls the same function).
-------------------------------------------------------------------------------
local _, NS = ...

NS.Lockbox = {}

local GetTime       = GetTime
local type          = type
local string_format = string.format

-- Session-only state
NS.Lockbox.pending = nil   -- { itemID, bag, slot, at }  box clicked, loot not yet open
NS.Lockbox.active  = nil   -- { itemID, bag, slot, closeAt, credited }  box being looted
NS.Lockbox.hooked  = false

function NS.Lockbox:Initialize()
  self.pending = nil
  self.active  = nil

  if not self.hooked and hooksecurefunc and C_Container and C_Container.UseContainerItem then
    hooksecurefunc(C_Container, "UseContainerItem", function(bag, slot)
      NS.Lockbox:OnUseContainerItem(bag, slot)
    end)
    self.hooked = true
  end
end

-------------------------------------------------------------------------------
-- Step 1 — the player uses a bag item
-------------------------------------------------------------------------------

function NS.Lockbox:OnUseContainerItem(bag, slot)
  if not NS.Data.db or not NS.Data:ShouldTrackLockboxes() then return end
  if MerchantFrame and MerchantFrame:IsShown() then return end  -- that's a sale
  if not bag or not slot then return end

  local info = C_Container.GetContainerItemInfo(bag, slot)
  if not info or not info.itemID then return end
  if not self:IsPickpocketBox(info.itemID) then return end

  self.pending = { itemID = info.itemID, bag = bag, slot = slot, at = GetTime() }
end

-------------------------------------------------------------------------------
-- Step 2 — a loot window opens
-------------------------------------------------------------------------------

--- Whether an item is a box we should count: one remembered as pickpocketed,
--- or a junkbox (only ever obtained by pickpocketing, so boxes picked before
--- this addon tracked them still count). The name check is English-only.
function NS.Lockbox:IsPickpocketBox(itemID)
  if not itemID then return false end
  if NS.Data:GetPocketedCount(itemID) > 0 then return true end
  local name = NS.Utils.GetItemName and NS.Utils:GetItemName(itemID)
  return type(name) == "string" and name:find("Junkbox", 1, true) ~= nil
end

--- Look at where the open loot comes from. Returns:
---   itemID  of the item being looted, when the client can tell us (nil if not)
---   fromItem  true if any loot comes from an item
---   sawSource true if the client reported any source at all
local function InspectLootSource()
  if not GetLootSourceInfo or not GetNumLootItems then return nil, false, false end
  local sawSource = false
  for i = 1, GetNumLootItems() do
    local guid = GetLootSourceInfo(i)
    if type(guid) == "string" then
      sawSource = true
      if guid:find("^Item%-") then
        local id = C_Item and C_Item.GetItemIDByGUID and C_Item.GetItemIDByGUID(guid)
        return id, true, true
      end
    end
  end
  return nil, false, sawSource
end

function NS.Lockbox:Debug(fmt, ...)
  if self.debug then NS.Utils:PrintInfo("[lockbox] " .. string_format(fmt, ...)) end
end

function NS.Lockbox:OnLootOpened()
  local p = self.pending
  self.pending = nil

  if self.active then
    -- LOOT_READY and LOOT_OPENED both land here; the second is a no-op.
    if not self.active.closeAt then return end
    -- Previous box already closed: wrap it up before starting the next one.
    self:Finish()
  end

  if not NS.Data.db or not NS.Data:ShouldTrackLockboxes() then return end

  local itemID, fromItem, sawSource = InspectLootSource()
  self:Debug("loot opened: item=%s fromItem=%s source=%s clicked=%s",
    tostring(itemID), tostring(fromItem), tostring(sawSource), tostring(p and p.itemID))

  -- Main path: the loot window itself says which item is being opened. This
  -- works however the box was opened: Blizzard bags, a bag addon, a macro.
  if itemID then
    if self:IsPickpocketBox(itemID) then
      local bag, slot
      if p and p.itemID == itemID then bag, slot = p.bag, p.slot end
      self.active = { itemID = itemID, bag = bag, slot = slot }
      self:Debug("counting gold from item %d", itemID)
    end
    return
  end

  -- Fallback for clients that can't map the loot to an item: rely on the
  -- player having just clicked a pickpocketed item in Blizzard's bags.
  if not p then return end
  if GetTime() - p.at > NS.Config.LOCKBOX_DEFAULTS.openWindow then return end
  if sawSource and not fromItem then return end   -- a corpse or chest
  self.active = { itemID = p.itemID, bag = p.bag, slot = p.slot }
  self:Debug("counting gold from clicked item %d", p.itemID)
end

-------------------------------------------------------------------------------
-- Step 3 — gold arrives, the window closes
-------------------------------------------------------------------------------

function NS.Lockbox:OnLootClosed()
  if self.active and not self.active.closeAt then
    self.active.closeAt = GetTime() + NS.Config.LOCKBOX_DEFAULTS.closeGrace
  end
end

--- True while gold gains should be attributed to a pickpocketed lockbox.
function NS.Lockbox:IsLooting()
  local a = self.active
  if a and a.closeAt and GetTime() > a.closeAt then
    self:Finish()
  end
  return self.active ~= nil
end

--- Called by tracking.lua after it attributes lockbox gold.
function NS.Lockbox:OnGoldCredited(amount)
  if self.active then self.active.credited = true end
  if NS.Data:ShouldChatLogItems() then
    NS.Utils:PrintInfo(string_format("Lockbox gold: %s", NS.Utils:FormatMoney(amount)))
  end
end

--- End the current box. It is spent if it paid out or has left its bag slot;
--- a box whose loot window was closed untouched stays remembered.
function NS.Lockbox:Finish()
  local a = self.active
  self.active = nil
  if not a then return end

  local spent = a.credited
  if not spent and a.bag and a.slot then
    local info = C_Container.GetContainerItemInfo(a.bag, a.slot)
    spent = not info or info.itemID ~= a.itemID
  end
  if spent then NS.Data:RemovePocketed(a.itemID, 1) end
end
