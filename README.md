# Pick Pocket Tracker

Track how much gold you're making from pickpocketing. Logs every coin looted and item grabbed, totals it up per session, and keeps lifetime stats across all your rogues.

Built for Retail (The War Within, 12.0.x). Rogue only — if you log in on a non-rogue, the addon stays out of your way. You can still check your combined haul with `/pp account` from any character.

## What it does

Pickpocket a mob, and the addon catches the gold and any items that drop. Gold shows up immediately in the haul window. Items show as "pending" until you vendor them — at that point the sale price gets added to your total.

The haul window is a small bar you can drag anywhere and resize. Hover it for a breakdown. A green `*` appears when you've got unsold pickpocketed items sitting in your bags.

The options panel has a character earnings bar graph if you want to see how your rogues stack up against each other. Toggle it on or off — it's a checkbox in the Display section.

## Install

Drop the `PickPocketTracker` folder into your addons directory:
```
World of Warcraft/_retail_/Interface/AddOns/
```
Log in on a rogue and you're good.

## Usage

`/pp` opens the options panel. That's the main thing.

| Command | What it does |
|---------|-------------|
| `/pp` | Open options |
| `/pp stats` | Item breakdown for this session |
| `/pp lifetime` | All-time stats (character + account) |
| `/pp account` | Account-wide totals (works on any class) |
| `/pp reset` | Clear current session |
| `/pp hide` / `show` | Toggle haul window |
| `/pp lock` / `unlock` | Lock window position (shift-drag still moves when locked) |
| `/pp icon on` / `off` | Pickpocket icon in the haul window |
| `/pp minimap on` / `off` / `reset` | Minimap button |
| `/pp window <seconds>` | Detection window, 0.1–10s |
| `/pp help` | All commands |

## Options panel

Open with `/pp` or click the minimap button.

**Display** — six checkboxes: show/hide the haul window, lock position, show the pickpocket icon, show the minimap button, log items to chat, and show the character earnings graph. All straightforward toggles.

**Tracking** — detection window slider. This is how long after a pickpocket cast the addon waits to attribute gold and items. Default is 2 seconds. If you're on bad latency and items are getting missed, bump it up.

**Character Earnings** — horizontal bar graph comparing total earnings across all your rogues. Bars are rogue-yellow. Hover for a tooltip with total, count, and average. The whole section hides when you uncheck it.

**Lifetime Stats** — pinned at the bottom. Per-character and account-wide totals with session/character/account reset buttons.

## How it works

**Gold** — when `PLAYER_MONEY` fires within the detection window after a pickpocket cast, the difference gets counted.

**Items** — same idea but using `CHAT_MSG_LOOT`. When WoW says "You receive loot: [item]" shortly after a pick, the addon attributes it.

**Vendor sales** — your bags are snapshotted when you open a merchant. When you close it, anything missing from the tracked items list is assumed sold and the vendor price gets credited.

**Class gating** — on login, the addon checks your class. Rogues get the full load. Non-rogues get a one-liner in chat and the account database initialized so `/pp account` works. No events registered, no frames created, no memory footprint.

## Known quirks

If you pickpocket and loot a quest mob in the same breath, the quest items might get attributed. The detection window slider lets you tune that tradeoff — shorter window means fewer false positives but more missed items.

`GetItemInfo` sometimes returns 0 for vendor price on items the server hasn't cached yet. Reopening your bags usually nudges it.

Items aren't tracked across sessions. If you log out with unsold pickpocketed stuff, it won't show as pending next time. Lifetime gold totals are fine though — those are saved immediately.

## Files

```
config.lua     Constants, defaults, colours
data.lua       SavedVariables access layer
utils.lua      Formatting, bag scanning, helpers
tracking.lua   Gold detection via PLAYER_MONEY
items.lua      Item detection via CHAT_MSG_LOOT, vendor sales
stats.lua      Lifetime stats (per-char + account-wide)
ui.lua         Haul display window
options.lua    Settings panel + bar graph
minimap.lua    Minimap button
events.lua     Event routing + rogue gating
commands.lua   Slash commands
init.lua       Bootstrap
```

## License

[MIT](LICENSE)
