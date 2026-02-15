-------------------------------------------------------------------------------
-- config.lua — Constants, defaults, and addon metadata
-- All magic numbers and tuning values live here. Nothing else should
-- hard-code sizes, timings, or texture paths.
-------------------------------------------------------------------------------
local _, NS = ...

NS.Config = {}

-- Addon metadata
NS.Config.ADDON_NAME = NS.name or "PickPocketTracker"
NS.Config.VERSION = "1.2.0"

-- Pick Pocket spell ID (unchanged since Classic)
NS.Config.PICK_POCKET_SPELL_ID = 921

-- Only rogues can pickpocket
NS.Config.REQUIRED_CLASS = "ROGUE"

-- Detection window: seconds after a pickpocket cast during which
-- gold changes and loot messages are attributed to pickpocketing
NS.Config.DEFAULT_WINDOW_SECONDS = 2.0
NS.Config.MIN_WINDOW_SECONDS     = 0.1
NS.Config.MAX_WINDOW_SECONDS     = 10.0

-- How long to wait before retrying GetItemInfo on a cache miss (seconds)
NS.Config.ITEM_CACHE_RETRY_DELAY = 0.1
NS.Config.ITEM_CACHE_MAX_RETRIES = 10

-- Main haul window defaults
NS.Config.UI_DEFAULTS = {
  point         = "CENTER",
  relativePoint = "CENTER",
  offsetX       = 0,
  offsetY       = 180,
  width         = 165,
  height        = 26,
  minWidth      = 90,
  maxWidth      = 420,
  minHeight     = 20,
  maxHeight     = 80,
  hidden        = false,
  locked        = false,
  showIcon      = true,
  chatLogItems  = true,
  baseFontSize  = 12,
  minFontScale  = 0.05,
  maxFontScale  = 2.00,
  iconSize      = 16,
  leftPadding   = 6,
  rightPadding  = 3,
  iconGap       = 4,
  showBarGraph  = true,
}

-- Minimap defaults
NS.Config.MINIMAP_DEFAULTS = {
  hide   = false,
  angle  = 220,
  radius = 80,
}

-- Chat message colours (hex, no leading |cff)
NS.Config.COLORS = {
  TAG  = "00ff66",  -- green addon prefix
  INFO = "aaaaaa",  -- grey informational
  GOOD = "66ffcc",  -- teal success
  WARN = "ffcc66",  -- amber warning
  BAD  = "ff6666",  -- red error
}

-- Inline money icon textures
NS.Config.MONEY_ICONS = {
  size       = 14,
  goldIcon   = "Interface/MoneyFrame/UI-GoldIcon",
  silverIcon = "Interface/MoneyFrame/UI-SilverIcon",
  copperIcon = "Interface/MoneyFrame/UI-CopperIcon",
}

-- Resize grip (bottom-right corner of haul window)
NS.Config.RESIZE_GRIP = {
  size         = 16,
  texture      = "Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up",
  alpha        = 0.7,
  hitRectInset = -6,
}

-- Bar graph colours
NS.Config.BAR_COLORS = {
  rogue   = { 1.0, 0.96, 0.41 },   -- RAID_CLASS_COLORS ROGUE yellow
  default = { 0.5, 0.5, 0.5 },      -- grey for non-rogue (shouldn't happen)
  bg      = { 0.1, 0.1, 0.1, 0.6 }, -- bar background
}

-- Convenience accessor
function NS.Config:GetColor(name)
  return self.COLORS[name] or self.COLORS.INFO
end
