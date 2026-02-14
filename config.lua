-- Configuration and constants
local _, NS = ...

NS.Config = {}

-- Addon info
NS.Config.ADDON_NAME = NS.name or "PickPocketTracker"
NS.Config.VERSION = "1.0.1"

-- Game constants
NS.Config.PICK_POCKET_SPELL_ID = 921

-- Tracking settings
NS.Config.DEFAULT_WINDOW_SECONDS = 2.0
NS.Config.MIN_WINDOW_SECONDS = 0.1
NS.Config.MAX_WINDOW_SECONDS = 10.0
NS.Config.ITEM_CHECK_DELAY = 0.5
NS.Config.ITEM_CACHE_RETRY_DELAY = 0.1

-- UI defaults
NS.Config.UI_DEFAULTS = {
  point = "CENTER",
  relativePoint = "CENTER",
  offsetX = 0,
  offsetY = 180,
  width = 165,
  height = 26,
  minWidth = 90,
  maxWidth = 420,
  minHeight = 20,
  maxHeight = 80,
  hidden = false,
  locked = false,
  showIcon = true,
  baseFontSize = 12,
  minFontScale = 0.05,
  maxFontScale = 2.00,
  iconSize = 16,
  leftPadding = 6,
  rightPadding = 3,
  iconGap = 4,
}

-- Minimap defaults
NS.Config.MINIMAP_DEFAULTS = {
  hide = false,
  angle = 220,
  radius = 80,
}

-- Colors
NS.Config.COLORS = {
  TAG  = "00ff66",
  INFO = "aaaaaa",
  GOOD = "66ffcc",
  WARN = "ffcc66",
  BAD  = "ff6666",
}

-- Money icons
NS.Config.MONEY_ICONS = {
  size = 14,
  goldIcon = "Interface/MoneyFrame/UI-GoldIcon",
  silverIcon = "Interface/MoneyFrame/UI-SilverIcon",
  copperIcon = "Interface/MoneyFrame/UI-CopperIcon",
}

-- Resize grip
NS.Config.RESIZE_GRIP = {
  size = 16,
  texture = "Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up",
  alpha = 0.7,
  hitRectInset = -6,
}

-- Helper functions
function NS.Config:GetUIDefault(key)
  return self.UI_DEFAULTS[key]
end

function NS.Config:GetColor(colorName)
  return self.COLORS[colorName] or self.COLORS.INFO
end
