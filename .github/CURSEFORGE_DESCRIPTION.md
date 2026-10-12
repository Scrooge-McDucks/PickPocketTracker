# Pick Pocket Tracker

**Find out exactly how much your rogue's sticky fingers are worth.**

Pickpocketing is one of the oldest rogue pastimes, but the base game never tells you what it actually earns. Gold drops straight into your purse with no record, junk items pile up in your bags, and when you finally visit a vendor you have no idea which of those coins came from picking pockets. Pick Pocket Tracker fixes that. It watches every Pick Pocket you cast, records the gold, items and Coins of Air it brings in, credits the vendor value when you sell the loot, and keeps lifetime totals for every rogue on your account.

Install it, log in on a rogue, and start picking pockets. There is nothing to set up.

---

## What changes in your game

Without the addon, pickpocketing gives you a "You receive loot" line in chat and a slowly growing gold count. With it, you get:

- **A live haul counter on screen.** A small bar shows the total value of the current session (gold looted plus item sales) and updates the moment a pick lands. You can see your earnings climb while you work through a city or dungeon.
- **Item loot that turns into real numbers.** Pickpocketed items are tracked as *pending* until you sell them. When you do, their vendor price is added to your haul automatically, so the total reflects what you really made rather than just the coins.
- **Automatic selling of pickpocket junk.** Open any vendor and the addon sells your tracked pickpocket items for you, one at a time. It only sells items it saw you pickpocket, so your other gear and materials are safe.
- **Lifetime statistics for every rogue.** Each character's total earnings, pickpocket count and average gold per pick are saved forever, along with combined account-wide totals.
- **Bar graphs that compare your rogues.** See at a glance which of your rogues has earned the most from pickpocketing, and which has collected the most Coins of Air.

### Example

You spend twenty minutes pickpocketing humanoids in a dungeon. Your haul bar reads **14g 32s** from coins alone and shows a green `*`, meaning there are unsold pickpocket items in your bags. Hovering the bar shows the breakdown: gold looted, items already sold, and **6g 80s** of pending vendor value. You walk to a vendor, the addon sells the trinkets and junk you lifted, and the haul updates to **21g 12s**. That total is added to your character's lifetime record and the account graph in the options panel.

---

## Features

### Haul window
- Small, movable, resizable bar that shows your session total in gold, silver and copper.
- Text scales to fit whatever width you drag the window to.
- Hover tooltip: gold looted, items sold, and pending vendor value of unsold loot.
- A green `*` marker appears whenever pickpocketed items are still sitting unsold in your bags.
- Optional Pick Pocket icon, position lock (Shift-drag still moves a locked window), and a toggle to hide it completely.

### Item tracking and fence items
- Every item you pickpocket is recorded, with optional chat messages for each item picked and sold.
- Items are sorted into **fence items** (anything with a vendor price) and **unsellable loot** (quest items and similar). Only fence items count toward pending vendor value or get auto-sold.
- If the game hasn't cached an item's price yet, the addon corrects the value later when the price becomes known, so totals don't drift.
- `/pp stats` prints a breakdown of every item you've picked this session.

### Auto-sell (on by default)
- Sells tracked pickpocket items when you open a merchant, one item per short tick so it doesn't fight with other auto-sell or bag addons.
- Never sells an item it didn't see you pickpocket, even if it shares an item ID with something you got elsewhere.
- If a stack in your bags is bigger than the number you pickpocketed (for example, you merged it with items from another source), that stack is left alone so nothing is oversold.
- Turn it off with one checkbox or `/pp autosell off` if you prefer to sell by hand. Sales are still credited to your haul either way.

### Coins of Air (Legion pickpocket currency)
- Optional second window counting the Coins of Air earned this session.
- Tooltip shows session total, how many you currently hold, and character and account lifetime totals.
- A separate bar graph ranks your rogues by lifetime Coins of Air.
- Turn it on in the options panel or with `/pp coins`. It is hidden automatically on game versions that don't have the currency.

### Lifetime and account statistics
- Per-character totals: gold looted, item sales, number of pickpockets, and average earned per pickpocket.
- Account-wide totals across every rogue you play.
- `/pp account` works from any class, so you can check your combined haul from your main even if it isn't a rogue.
- Reset the current session, one character, or the whole account. Character and account resets ask for confirmation first.

### Character comparison graphs
- **Character Earnings** graph: one rogue-yellow bar per character showing total earnings. Hover a bar for the total, pickpocket count and average per pick.
- **Coins of Air** graph: one monk-green bar per character showing lifetime coins.
- Each graph has its own "Max Characters to Display" slider (1 to 10). Characters past the limit are grouped into a single "Other Characters" bar so the graph stays readable.

### Options panel and easy access
- `/pp` opens a full options panel with display toggles, the detection window slider, both graphs and your lifetime stats.
- Listed in Blizzard's **Addon Compartment** on the minimap: left-click opens options, right-click shows or hides the haul window, and the tooltip shows your current haul.
- Optional standalone minimap button you can drag around the minimap edge.
- Also reachable from Game Menu → Options → AddOns → Pick Pocket Tracker.

### Adjustable detection window
- The addon credits gold, items and coins that arrive within a short window after each Pick Pocket cast (2 seconds by default).
- Raise it (up to 10 seconds) if you play on high latency and see loot being missed; lower it (down to 0.1 seconds) if you often pickpocket and loot a corpse at the same moment and want fewer false matches.

### Light footprint
- Rogue only. On any other class the addon prints a single line, registers no events and creates no frames. The only thing it does is keep `/pp account` working.
- No library dependencies.

---

## Slash commands

| Command | What it does |
|---|---|
| `/pp` | Open the options panel |
| `/pp stats` | Item breakdown for this session |
| `/pp lifetime` | Character and account lifetime stats |
| `/pp account` | Account-wide totals (works on any class) |
| `/pp reset` | Clear the current session |
| `/pp hide` / `/pp show` | Hide or show the haul window |
| `/pp lock` / `/pp unlock` | Lock or unlock the windows |
| `/pp icon on` / `off` | Pick Pocket icon in the haul window |
| `/pp minimap on` / `off` / `reset` | Standalone minimap button |
| `/pp window <seconds>` | Set the detection window (0.1 to 10) |
| `/pp coins` | Toggle Coins of Air tracking |
| `/pp coins icon on` / `off` | Icon in the coin window |
| `/pp coins reset` | Reset the coin session count |
| `/pp autosell` | Toggle auto-sell |
| `/pp help` | List every command |

---

## Good to know

- Pending items are tracked per play session. If you log out with unsold pickpocket loot, it won't show as pending next time, but all gold and sales already recorded stay in your lifetime stats.
- If you pickpocket a mob and loot a quest item from a corpse within the detection window, the quest item may be counted. Shorten the detection window if this happens often.

Found a bug or have an idea? Open an issue on [GitHub](https://github.com/Scrooge-McDucks/PickPocketTracker).
