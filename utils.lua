-------------------------------------------------------------------------------
-- utils.lua — Shared helpers: chat output, money formatting, bag scanning,
-- item info with retry, and general-purpose math/string utilities
-------------------------------------------------------------------------------
local _, NS = ...

NS.Utils = {}

-------------------------------------------------------------------------------
-- Chat output
-------------------------------------------------------------------------------
local function ColorText(hex, text)
  return "|cff" .. hex .. tostring(text) .. "|r"
end

local function GetAddonTag()
  return ColorText(NS.Config:GetColor("TAG"), NS.Config.ADDON_NAME .. ":") .. " "
end

function NS.Utils:Print(hex, text)
  if hex then
    print(GetAddonTag() .. ColorText(hex, text))
  else
    print(GetAddonTag() .. tostring(text))
  end
end

function NS.Utils:PrintInfo(text)    self:Print(NS.Config:GetColor("INFO"), text) end
function NS.Utils:PrintSuccess(text) self:Print(NS.Config:GetColor("GOOD"), text) end
function NS.Utils:PrintWarning(text) self:Print(NS.Config:GetColor("WARN"), text) end
function NS.Utils:PrintError(text)   self:Print(NS.Config:GetColor("BAD"),  text) end

-------------------------------------------------------------------------------
-- Money formatting
-------------------------------------------------------------------------------

--- Full format with gold/silver/copper icons: "5[G] 20[S] 30[C]"
function NS.Utils:FormatMoney(copper)
  local gold   = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local cop    = copper % 100

  local sz = NS.Config.MONEY_ICONS.size
  local fmt = "|T%s:%d:%d:0:0|t"
  local gI = fmt:format(NS.Config.MONEY_ICONS.goldIcon,   sz, sz)
  local sI = fmt:format(NS.Config.MONEY_ICONS.silverIcon, sz, sz)
  local cI = fmt:format(NS.Config.MONEY_ICONS.copperIcon, sz, sz)

  return string.format("%d%s %d%s %d%s", gold, gI, silver, sI, cop, cI)
end

--- Compact text-only format: "5g 20s" or "50s 10c" or "25c"
function NS.Utils:FormatMoneyCompact(copper)
  local gold   = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local cop    = copper % 100

  if gold > 0 then
    return string.format("%dg %ds", gold, silver)
  elseif silver > 0 then
    return string.format("%ds %dc", silver, cop)
  else
    return string.format("%dc", cop)
  end
end

-------------------------------------------------------------------------------
-- String helpers
-------------------------------------------------------------------------------

function NS.Utils:TrimString(str)
  return str:match("^%s*(.-)%s*$")
end

-------------------------------------------------------------------------------
-- Table helpers
-------------------------------------------------------------------------------

--- Sort a key/value table by a scoring function, returning an array of
--- {key=k, value=v} sorted highest-score-first.
function NS.Utils:TableSortBy(tbl, keyFunc)
  local array = {}
  for key, value in pairs(tbl) do
    array[#array + 1] = { key = key, value = value }
  end
  table.sort(array, function(a, b)
    return keyFunc(a.value) > keyFunc(b.value)
  end)
  return array
end

-------------------------------------------------------------------------------
-- Math helpers
-------------------------------------------------------------------------------

function NS.Utils:Clamp(value, min, max)
  return math.max(min, math.min(max, value))
end

-------------------------------------------------------------------------------
-- Item info (with async retry on cache miss)
-------------------------------------------------------------------------------

--- Wrapper that handles the C_Item vs legacy GetItemInfo API split.
local function SafeGetItemInfo(itemID)
  if C_Item and C_Item.GetItemInfo then
    return C_Item.GetItemInfo(itemID)
  elseif GetItemInfo then
    return GetItemInfo(itemID)
  end
  return nil
end

--- Fetch item name + texture. If the item isn't cached yet, retries up to
--- ITEM_CACHE_MAX_RETRIES times with a short delay between attempts.
function NS.Utils:GetItemInfo(itemID, callback, retries)
  retries = retries or 0
  local itemName, _, _, _, _, _, _, _, _, itemTexture = SafeGetItemInfo(itemID)

  if itemName then
    callback(itemID, itemName, itemTexture)
  elseif retries < NS.Config.ITEM_CACHE_MAX_RETRIES then
    C_Timer.After(NS.Config.ITEM_CACHE_RETRY_DELAY, function()
      self:GetItemInfo(itemID, callback, retries + 1)
    end)
  end
end

--- Return the vendor sell price for an item, or 0 if unknown.
function NS.Utils:GetVendorPrice(itemID)
  local vendorPrice = select(11, SafeGetItemInfo(itemID))
  return vendorPrice or 0
end

-------------------------------------------------------------------------------
-- Bag scanning (used for vendor-sale detection)
-------------------------------------------------------------------------------

--- Snapshot all bag contents as { [itemID] = totalCount }.
function NS.Utils:CreateBagSnapshot()
  local snapshot = {}
  for bag = 0, NUM_BAG_SLOTS do
    local numSlots = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, numSlots do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID then
        snapshot[info.itemID] = (snapshot[info.itemID] or 0) + (info.stackCount or 1)
      end
    end
  end
  return snapshot
end
