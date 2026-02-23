# Pick Pocket Tracker

Track how much gold you're making from pickpocketing. Logs every coin looted, item grabbed, and Coin of Air earned — totals it up per session and keeps lifetime stats across all your rogues.

Built for Retail (The War Within, 12.0.x). Rogue only — if you log in on a non-rogue, the addon stays out of your way. You can still check your combined haul with `/pp account` from any character.

## What it does

Pickpocket a mob and the addon catches the gold and any items that drop. Gold shows up immediately in the haul window. Items show as "pending" until you vendor them — at that point the sale price gets added to your total.

The haul window is a small bar you can drag anywhere and resize. The text auto-scales to fit the window width. Hover it for a tooltip breakdown of gold looted, items sold, and pending vendor value. A green `*` appears when you've got unsold pickpocketed items sitting in your bags.

The addon distinguishes between fence items (items with a vendor sell price) and unsellable loot (quest items, etc). Both are tracked for display and stats, but only fence items count toward your pending vendor value and are eligible for auto-sell.

### Auto-sell

When enabled, opening a vendor automatically sells your tracked pickpocket fence items one at a time. The queue/ticker approach avoids conflicts with other auto-sell addons and only sells items the addon is actually tracking — it won't touch non-pickpocketed items even if they share the same item ID. If a stack in your bags is larger than the tracked pickpocket quantity, it's skipped to avoid overselling.

### Coins of Air

Enable Coins of Air tracking in the Display settings and a second small window appears with your session count. Hover it for session total, currently held, and lifetime stats. Both windows share the same capabilities: drag, resize, lock, icon toggle.

### Bar graphs

The options panel has two bar graphs comparing your rogues against each other:

- **Character Earnings** — horizontal bars in rogue-yellow showing total gold + item sales per character. Hover for total, pickpocket count, and average per pick.
- **Coins of Air** — horizontal bars in monk-green showing lifetime coins earned per character.

Both graphs have independent "Max Characters to Display" sliders (1–10). Characters beyond the limit are grouped into an "Other Characters" bar. Toggle both graphs on or off with the "Show Character Graphs" checkbox.

### Blizzard integration

The addon registers in two places in the Blizzard UI:

- **Addon Compartment** — the minimap addon list (11.0+). Shows the addon with a coin icon for quick access without a standalone minimap button.
- **Settings panel** — Game Menu → Options → AddOns → Pick Pocket Tracker. Has a button that opens the main options window.

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
| `/pp` | Open options panel |
| `/pp options` | Same as above (also: `config`, `settings`) |
| `/pp stats` | Item breakdown for this session (also: `items`) |
| `/pp lifetime` | All-time stats (character + account) |
| `/pp account` | Account-wide totals (works on any class) |
| `/pp reset` | Clear current session |
| `/pp hide` / `show` | Toggle haul window |
| `/pp lock` / `unlock` | Lock both windows (shift-drag still moves) |
| `/pp icon on` / `off` | Pickpocket icon in the haul window |
| `/pp minimap on` / `off` / `reset` | Standalone minimap button |
| `/pp window <seconds>` | Detection window, 0.1–10s |
| `/pp coins` | Toggle Coins of Air tracking |
| `/pp coins on` / `off` | Explicit enable/disable |
| `/pp coins icon on` / `off` | Coin icon in the tracking window |
| `/pp coins reset` | Reset coin session count |
| `/pp autosell` | Toggle auto-sell fence items |
| `/pp autosell on` / `off` | Explicit enable/disable |
| `/pp help` | All commands |

## Options panel

Open with `/pp`, click the minimap button (left-click), the Addon Compartment entry, or go through Game Menu → AddOns.

**Display** — eight checkboxes:
- Show Main Window — toggle the haul bar on/off
- Lock Window Position — prevent dragging and resizing (shift-drag bypasses the lock for repositioning)
- Show Pickpocket Icon — the ability icon in the haul bar
- Show Standalone Minimap Button — a separate draggable button around the minimap edge (off by default, the Addon Compartment is always available)
- Log Items to Chat — prints pickpocketed/sold item messages
- Auto-sell Fence Items — automatically sell tracked pickpocket loot at vendors
- Show Character Graphs — toggle the earnings and coins bar graphs
- Track Coins of Air — enable the second tracking window

**Tracking** — detection window slider. This is how long after a pickpocket cast the addon waits to attribute gold and items. Default is 2 seconds. If you're on bad latency and items are getting missed, bump it up. A "Default" button resets it to 2.0s.

**Character Earnings** — horizontal bar graph comparing total earnings (gold + item sales) across all your rogues. Each bar has a hover tooltip with total earned, pickpocket count, and average per pick. The "Max Characters to Display" slider controls how many individual bars show before the rest are grouped into "Other Characters." Only visible when "Show Character Graphs" is checked.

**Coins of Air** — icon toggle checkbox, four stat lines (session, character lifetime, account lifetime, currently held), a separate "Max Characters to Display" slider, and a Coins of Air bar graph. The graph and slider follow the "Show Character Graphs" toggle. The whole section only appears when "Track Coins of Air" is checked.

**Lifetime Stats** — pinned at the bottom outside the scroll region. Shows per-character and account-wide totals with averages. Three reset buttons:
- Reset Session — clears current session data, lifetime stats preserved
- Reset Character — clears this character's lifetime stats (confirmation dialog)
- Reset Account — clears all characters' lifetime stats (confirmation dialog)

A Refresh button updates the stats and graphs without closing the panel.

## Minimap access

**Addon Compartment (default)** — the addon registers with Blizzard's native addon list (the grid icon on the minimap edge, added in 11.0). It appears as "Pick Pocket Tracker" with a coin icon. Left-click opens options, right-click toggles the haul window. The tooltip shows your current session haul. This is always available and cannot be disabled.

**Standalone minimap button (optional)** — a draggable coin icon with a tracking-ring border, positioned around the minimap edge. Hidden by default. Enable it with `/pp minimap on` or the "Show Standalone Minimap Button" checkbox in Display settings.

Both buttons behave the same:
- **Left-click** — open/close the options panel
- **Right-click** — toggle the haul window
- **Drag** (standalone only) — reposition around the minimap edge

Standalone button position is saved between sessions. Use `/pp minimap reset` to snap it back to the default position.

## How it works

**Gold** — when `PLAYER_MONEY` fires within the detection window after a pickpocket cast, the difference gets counted.

**Items** — same idea but using `CHAT_MSG_LOOT`. When WoW says "You receive loot: [item]" shortly after a pick, the addon attributes it. Items with a vendor sell price > 0 are marked as fence items (eligible for auto-sell and vendor tracking). Items with no vendor price (quest items, etc) are tracked for display but excluded from fence logic.

**Coins of Air** — `CURRENCY_DISPLAY_UPDATE` fires when any currency changes. If it happens within the detection window and Coins of Air (currency 1416) increased, the delta is recorded.

**Vendor sales** — your bags are snapshotted when you open a merchant. When you close it, anything missing from the tracked items list is assumed sold and the vendor price gets credited. Auto-sell (if enabled) runs a ticker that sells one fence item per tick to avoid conflicts with other addons.

**Lifetime stats** — per-character data and account-wide totals are stored in `PickPocketTrackerAccountDB` (account-wide SavedVariable). Character key format is `RealmName-CharacterName`. Account totals are maintained in parallel for fast lookups.

**Window architecture** — both display windows (gold haul + coins) are built from a shared `CreateDisplayBar` factory. Drag, resize grip, lock-aware shift-drag, icon toggle, and position save are handled once. Each window just adds its own tooltip and display logic.

**Class gating** — on login, the addon checks your class. Rogues get the full load. Non-rogues get a one-liner in chat and the account database initialized so `/pp account` works. No events registered, no frames created, no memory footprint.

## Known quirks

If you pickpocket and loot a quest mob in the same breath, the quest items might get attributed. The detection window slider lets you tune that tradeoff — shorter window means fewer false positives but more missed items.

`GetItemInfo` sometimes returns 0 for vendor price on items the server hasn't cached yet. If a previously-unknown price is discovered on a later pickpocket of the same item, the addon retroactively corrects the tracked value and marks it as a fence item.

Items aren't tracked across sessions. If you log out with unsold pickpocketed stuff, it won't show as pending next time. Lifetime gold totals are fine though — those are saved immediately.

Auto-sell only sells stacks that fit entirely within the tracked pickpocket quantity. If you had 3 of an item from pickpocketing but your bags contain a stack of 10 (from other sources mixed in), that stack is skipped to avoid selling non-pickpocketed items.

## Files

```
config.lua     Constants, defaults, colours
data.lua       SavedVariables access layer
utils.lua      Formatting, bag scanning, shared display bar factory
tracking.lua   Gold detection via PLAYER_MONEY
items.lua      Item detection, fence tracking, vendor sales, auto-sell
coins.lua      Coins of Air tracking + display window
stats.lua      Lifetime stats (per-char + account-wide)
chart.lua      Shared bar chart renderer (gold + coin graphs)
slider.lua     Shared slider factory (max chars + detection window)
ui.lua         Haul display window (built on shared bar factory)
options.lua    Settings panel, bar graphs, coin stats, Blizzard registration
minimap.lua    Minimap button with drag-to-reposition
events.lua     Event routing + rogue gating
commands.lua   Slash commands
init.lua       Bootstrap + Addon Compartment handlers
```

## License

[MIT](LICENSE)
