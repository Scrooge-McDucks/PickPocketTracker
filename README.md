# Pick Pocket Tracker

Tracks your pickpocket earnings in WoW — gold looted, items grabbed, vendor sales — across sessions and characters.

Built for Retail (The War Within, 12.0.x).

## What it does

When you pickpocket a mob, the addon logs the gold and any items you receive. Items show up as "pending" in the haul window until you vendor them. Everything feeds into lifetime stats that persist across sessions, characters, and accounts.

The haul window is a small draggable/resizable bar. Hover it for a breakdown. A green `*` appears when you have unsold items in your bags.

## Install

Drop the `PickPocketTracker` folder into:
```
World of Warcraft/_retail_/Interface/AddOns/
```
Reload or restart the client.

## Usage

`/pp` opens the options panel. That's the main one you need.

Other commands if you prefer chat:
- `/pp stats` — session item breakdown
- `/pp lifetime` — all-time stats for this character + account
- `/pp reset` — clear current session
- `/pp hide` / `/pp show` — toggle the haul window
- `/pp lock` / `/pp unlock` — lock window position (shift-drag still moves it when locked)
- `/pp help` — full command list

## Options

- **Hide/Show/Lock** the haul window
- **Show/hide** the pickpocket icon, minimap button
- **Log Items to Chat** — toggle the "Pickpocketed: 2x Worn Junkbox" messages (on by default)
- **Detection Window** — how long after a pickpocket cast to attribute gold/items (default 2s, increase if you're missing loot on high latency)

## How tracking works

Gold detection uses `PLAYER_MONEY` — when your gold changes within a few seconds of a pickpocket cast, it gets counted.

Item detection uses `CHAT_MSG_LOOT` — same time-window approach. When WoW tells you "You receive loot: [item]" shortly after a pickpocket, the addon attributes it.

Vendor detection snapshots your bags when you open a merchant. When you close the merchant, it checks what's missing and credits the sale value for any tracked items you sold.

## Stats

The addon keeps two layers of stats:

**Session** — resets when you `/pp reset` or log out. Shows in the haul window and `/pp stats`.

**Lifetime** — persists forever in SavedVariables. Per-character and account-wide totals. Tracks gold looted, items sold, pickpocket count, averages, first/last timestamps. Visible in the options panel and via `/pp lifetime`.

## Known quirks

- If you pickpocket and immediately loot a quest mob in the same second, the quest items might get attributed to pickpocket. The detection window setting lets you tune this.
- Item vendor prices come from `GetItemInfo` which occasionally returns 0 for items that do have vendor value (server hasn't cached the item yet). Reopening your bags usually fixes it.
- The addon doesn't track items across sessions — if you log out with unsold pickpocketed items, they won't appear as "pending" next login. Gold totals are fine though.

## Files

```
config.lua     — constants, defaults, colors
data.lua       — SavedVariables access layer
utils.lua      — formatting, bag scanning, helpers
tracking.lua   — gold detection (PLAYER_MONEY + time window)
items.lua      — item detection (CHAT_MSG_LOOT) + vendor sales
stats.lua      — lifetime stats (per-char + account-wide)
ui.lua         — haul display window
options.lua    — settings panel
minimap.lua    — minimap button
events.lua     — event routing
commands.lua   — slash commands
init.lua       — bootstrap
```

## License

All rights reserved. Feel free to fork for personal use.
