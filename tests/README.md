# PickPocketTracker tests

A test suite that runs the addon's real Lua against a stubbed World of Warcraft
client, so logic can be checked without launching the game.

These files are **development only** — `.pkgmeta` lists `tests` under `ignore`,
so the packager leaves them out of the released addon zip.

## Running

Needs [lupa](https://pypi.org/project/lupa/) (a Lua runtime embedded in Python):

```sh
python3 -m venv .venv
.venv/bin/pip install lupa
.venv/bin/python tests/run_tests.py
```

Run a subset by passing name fragments:

```sh
.venv/bin/python tests/run_tests.py items coins
```

Exit status is 0 when every assertion passes, 1 otherwise, so it drops straight
into CI.

## Layout

| File | Covers |
|---|---|
| `wow_stub.lua` | The fake game client, plus the `H` handle tests drive it with |
| `run_tests.py` | Discovers `test_*.lua`, runs each in a fresh Lua state |
| `test_utils.lua` | Money formatting, string/table/math helpers, item cache + retry |
| `test_data.lua` | SavedVariables defaults, backfill, clamping, round-tripping |
| `test_tracking.lua` | Gold attribution via the post-cast detection window |
| `test_items.lua` | Loot attribution, fence eligibility, vendor-sale detection |
| `test_autosell.lua` | The auto-sell ticker: vendor guard, refused sells, retries |
| `test_stats.lua` | Lifetime stats, account roll-ups, resets, multi-character |
| `test_coins.lua` | Coins of Air currency deltas and the display window |
| `test_integration.lua` | All 15 TOC files loaded in TOC order, driven by real events |

## How the stub works

`wow_stub.lua` installs stand-ins for every global the addon touches
(`C_Container`, `C_Timer`, `C_Item`, `C_CurrencyInfo`, `CreateFrame`, `GetMoney`,
`GetTime`, `GameTooltip`, `Settings`, ...) and returns a handle, `H`, that a test
uses to drive the world:

```lua
local H  = dofile(TESTS_DIR .. "/wow_stub.lua")
local NS = H.newEnv({ "config.lua", "utils.lua", "data.lua" })

H.defineItem(100, "Silk Cloth", 50)   -- put an item in the fake item cache
H.put(0, 1, 100, 5)                   -- a stack of 5 in bag 0, slot 1
H.money = 1234                        -- what GetMoney() returns
H.advance(3)                          -- move GetTime() forward 3 seconds
H.merchantOpen = false                -- close the vendor window
H.tick(5)                             -- run every live C_Timer ticker 5 times
H.sellBlocked = true                  -- make sell requests silently do nothing

H.check("name", condition)            -- assertions
H.eq("name", got, want)
H.report()                            -- totals, and set TEST_FAILURES
```

Nothing reaches the network or a real client. A "sell" is a table entry being
removed from a fake bag; a "tick" is a direct function call.

`H.newEnv(files)` gives a clean slate (fresh world, empty SavedVariables).
`H.reload(files)` reloads the addon while **keeping** SavedVariables, which is
how the suite models a `/reload` or logging in on a second character.

`H.tocFiles()` reads the file list straight out of `PickPocketTracker.toc`, so
`test_integration.lua` always loads exactly what the game loads, in the same
order — adding a module to the addon cannot silently skip it here.

### Known limits

- The host Lua is newer than WoW's 5.1, so 5.1-specific syntax is not validated.
  The stub exposes the globals WoW adds (`unpack`, `time`, `date`) to match.
- The frame mock models geometry, visibility, text, scripts and events for real.
  Any other PascalCase method or template-supplied child widget becomes a
  chainable no-op, so UI *construction* is covered but pixel layout is not.
- Combat lockdown, taint and protected functions have no equivalent here. The
  one place that matters — auto-sell calling `C_Container.UseContainerItem` — is
  tested for the vendor-open guard and for refused sell requests, but whether a
  given patch restricts that call can only be confirmed in-game.
