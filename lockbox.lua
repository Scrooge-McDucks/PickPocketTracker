-------------------------------------------------------------------------------
-- lockbox.lua — Gold from pickpocketed lockboxes / junkboxes
--
-- A junkbox is pickpocketed, then Pick Locked, then opened — often minutes or
-- days later, far outside the post-cast detection window in tracking.lua, so
-- its gold was never counted.
--
-- Detection, in three steps:
--   1. A post-hook on C_Container.UseContainerItem notices the player using a
--      bag item that data.lua remembers as pickpocketed (and still unopened).
--   2. LOOT_READY / LOOT_OPENED must follow within a few seconds, and the loot
--      must come from an item (source GUID "Item-...") rather than a corpse.
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
  if NS.Data:GetPocketedCount(info.itemID) <= 0 then return end

  self.pending = { itemID = info.itemID, bag = bag, slot = slot, at = GetTime() }
end

-------------------------------------------------------------------------------
-- Step 2 — a loot window opens
-------------------------------------------------------------------------------

--- True if the open loot comes from an item. If the client can't tell us the
--- source at all, give the benefit of the doubt: the player did just click a
--- pickpocketed item. A corpse or chest (Creature-/GameObject- GUID) is refused.
local function LootIsFromItem()
  if not GetLootSourceInfo or not GetNumLootItems then return true end
  local sawSource = false
  for i = 1, GetNumLootItems() do
    local guid = GetLootSourceInfo(i)
    if type(guid) == "string" then
      if guid:find("^Item%-") then return true end
      sawSource = true
    end
  end
  return not sawSource
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

  if not p then return end
  if GetTime() - p.at > NS.Config.LOCKBOX_DEFAULTS.openWindow then return end
  if not LootIsFromItem() then return end

  self.active = { itemID = p.itemID, bag = p.bag, slot = p.slot }
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

  local info = C_Container.GetContainerItemInfo(a.bag, a.slot)
  if a.credited or not info or info.itemID ~= a.itemID then
    NS.Data:RemovePocketed(a.itemID, 1)
  end
end
