-------------------------------------------------------------------------------
-- lockbox.lua — Gold from pickpocketed lockboxes / junkboxes
--
-- A junkbox is pickpocketed, then Pick Locked, then opened — often minutes or
-- days later, far outside the post-cast detection window in tracking.lua, so
-- its gold would never be counted.
--
-- Detection is based on the bags, not on how the box was opened, so it works
-- with Blizzard's bags, bag addons and /use macros alike:
--   1. When a loot window opens (LOOT_READY / LOOT_OPENED) that isn't from a
--      corpse or world object, and a candidate box is in the bags, the bags
--      are snapshotted. A candidate is a box we saw pickpocketed, or any
--      junkbox (junkboxes only come from pickpocketing).
--   2. Gold gained while that loot window is open is held, not yet credited.
--   3. Shortly after LOOT_CLOSED the bags are checked again. If a candidate
--      box has gone, the loot was that box and the held gold is credited.
--      Otherwise the gold came from something else and is dropped.
-- Where the client can say which item the loot comes from
-- (C_Item.GetItemIDByGUID), that confirms the box straight away, which also
-- covers taking the gold but leaving items inside the box.
-------------------------------------------------------------------------------
local _, NS = ...

NS.Lockbox = {}

local GetTime       = GetTime
local type          = type
local pairs         = pairs
local tostring      = tostring
local string_format = string.format

-- Session-only state
--   active = { before = {[itemID]=count}, confirmedID, held, closeAt, openedAt }
NS.Lockbox.active = nil
NS.Lockbox.debug  = false

function NS.Lockbox:Initialize()
  self.active = nil
end

function NS.Lockbox:Debug(fmt, ...)
  if self.debug then NS.Utils:PrintInfo("[lockbox] " .. string_format(fmt, ...)) end
end

-------------------------------------------------------------------------------
-- Which items count as pickpocketed boxes
-------------------------------------------------------------------------------

--- A box we saw pickpocketed, or any junkbox. The name check is English-only;
--- in other languages, boxes pickpocketed since v1.11.0 are still known.
function NS.Lockbox:IsPickpocketBox(itemID)
  if not itemID then return false end
  if NS.Data:GetPocketedCount(itemID) > 0 then return true end
  local name = NS.Utils:GetItemName(itemID)
  return type(name) == "string" and name:find("Junkbox", 1, true) ~= nil
end

--- { [itemID] = count } of candidate boxes currently in the bags.
function NS.Lockbox:CountBoxes()
  local boxes, total = {}, 0
  for itemID, count in pairs(NS.Utils:CreateBagSnapshot()) do
    if self:IsPickpocketBox(itemID) then
      boxes[itemID] = count
      total = total + count
    end
  end
  return boxes, total
end

-------------------------------------------------------------------------------
-- Loot window opens
-------------------------------------------------------------------------------

-- Loot from these sources is never from a box in the bags.
local WORLD_SOURCES = { "^Creature%-", "^GameObject%-", "^Vehicle%-", "^Pet%-" }

--- Returns sourceKind, itemID:
---   "world" — corpse, chest, herb, ore... not ours
---   "item"  — an item; itemID is set if the client can map the GUID
---   nil     — the client gave no usable source; the bag check decides
local function InspectLootSource()
  if not GetLootSourceInfo or not GetNumLootItems then return nil end
  for i = 1, GetNumLootItems() do
    local guid = GetLootSourceInfo(i)
    if type(guid) == "string" then
      for _, pattern in ipairs(WORLD_SOURCES) do
        if guid:find(pattern) then return "world" end
      end
      if guid:find("^Item%-") then
        local id = C_Item and C_Item.GetItemIDByGUID and C_Item.GetItemIDByGUID(guid)
        return "item", id
      end
    end
  end
  return nil
end

function NS.Lockbox:OnLootOpened()
  local a = self.active
  if a then
    -- LOOT_READY then LOOT_OPENED for the same window: nothing more to do.
    if not a.closeAt then return end
    -- A new window before the last one was checked: settle the last one.
    self:Finish()
  end

  if not NS.Data.db or not NS.Data:ShouldTrackLockboxes() then return end

  local kind, itemID = InspectLootSource()
  -- Corpses, chests and herbs are most loot windows: skip the bag scan.
  if kind == "world" then
    self:Debug("loot opened: from the world, ignored")
    return
  end

  local before, total = self:CountBoxes()
  self:Debug("loot opened: source=%s item=%s boxes in bags=%d",
    tostring(kind), tostring(itemID), total)
  if total == 0 then return end
  -- The client named the item and it isn't one of our boxes.
  if itemID and not self:IsPickpocketBox(itemID) then return end

  local active = {
    before      = before,
    confirmedID = itemID,          -- known box straight away, if the client said so
    held        = 0,
    openedAt    = GetTime(),
  }
  self.active = active
end

-------------------------------------------------------------------------------
-- Gold arrives, the window closes, the bags are checked
-------------------------------------------------------------------------------

--- True while a loot window that may be a pickpocketed box is being looted.
function NS.Lockbox:IsLooting()
  local a = self.active
  if not a then return false end
  if a.closeAt then
    -- Normally the timer from OnLootClosed settles it; this covers a lost timer.
    if GetTime() > a.closeAt + 5 then self:Finish() end
  elseif GetTime() - a.openedAt > NS.Config.LOCKBOX_DEFAULTS.maxOpen then
    -- Failsafe: never hold gold for a loot window left open indefinitely.
    self:Debug("loot window open too long; stopped watching")
    self.active = nil
  end
  return self.active ~= nil
end

--- Called by tracking.lua for gold gained while IsLooting() is true.
function NS.Lockbox:Hold(amount)
  if self.active and amount > 0 then
    self.active.held = self.active.held + amount
  end
end

function NS.Lockbox:OnLootClosed()
  local a = self.active
  if not a or a.closeAt then return end
  -- With auto-loot, PLAYER_MONEY and the box leaving the bags can arrive
  -- just after LOOT_CLOSED, so check a moment later.
  a.closeAt = GetTime() + NS.Config.LOCKBOX_DEFAULTS.closeGrace
  C_Timer.After(NS.Config.LOCKBOX_DEFAULTS.closeGrace, function()
    if self.active == a then self:Finish() end
  end)
end

--- Settle the current loot window: credit the held gold if it came from a
--- pickpocketed box, and forget boxes that have left the bags.
function NS.Lockbox:Finish()
  local a = self.active
  self.active = nil
  if not a then return end

  local after = self:CountBoxes()
  local gone  = false
  for itemID, count in pairs(a.before) do
    local left = after[itemID] or 0
    if left < count then
      gone = true
      NS.Data:RemovePocketed(itemID, count - left)
    end
  end

  local confirmed = gone or a.confirmedID ~= nil
  self:Debug("loot closed: box gone=%s item=%s gold=%d -> %s",
    tostring(gone), tostring(a.confirmedID), a.held,
    confirmed and "counted" or "not a box, ignored")

  if confirmed and a.held > 0 then
    NS.Tracking:CreditLockboxGold(a.held)
    if NS.Data:ShouldChatLogItems() then
      NS.Utils:PrintInfo(string_format("Lockbox gold: %s", NS.Utils:FormatMoney(a.held)))
    end
    if NS.UI then NS.UI:UpdateDisplay() end
  end
end
