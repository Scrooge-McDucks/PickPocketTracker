# Pick Pocket Tracker

A WoW addon for tracking pickpocket gold, items, and lifetime statistics.

## Features

- **Session Tracking** - Track gold and items per session
- **Lifetime Statistics** - Per-character and account-wide totals
- **Item Tracking** - Automatically track pickpocketed items and vendor sales
- **Character Leaderboard** - See which character earns the most
- **Modern UI** - Toggle switches and clean interface
- **Resizable Display** - Drag, resize, and position the window anywhere
- **Minimap Button** - Quick access to settings

## Installation

1. Download the addon
2. Extract to `World of Warcraft\_retail_\Interface\AddOns\`
3. Restart WoW or type `/reload`

## Commands

- `/pp` - Open options window
- `/pp options` - Open options window
- `/pp stats` - Show session item statistics
- `/pp lifetime` - Show lifetime statistics
- `/pp reset` - Reset current session
- `/pp hide` - Hide the display window
- `/pp show` - Show the display window
- `/pp help` - Show all commands

## Options Window

Type `/pp` to open the modern options interface with:

- **Display Settings** - Hide/show window, lock position, toggle icon
- **Tracking Settings** - Adjust pickpocket detection window
- **Appearance** - Plumber skin support
- **Statistics** - View character and account-wide stats
- **Character Leaderboard** - Rankings by total earned
- **Reset Options** - Reset session, character, or account data

## Lifetime Statistics

The addon tracks:
- Gold looted from pickpockets
- Items sold to vendors
- Total pickpocket attempts
- Per-character totals
- Account-wide totals across all characters
- First and last pickpocket timestamps
- Average gold per pickpocket

## Reset Options

**Session Reset** - Clears current session only (safe, use anytime)  
**Character Reset** - Clears this character's lifetime stats (account total adjusts automatically)  
**Account Reset** - Clears ALL characters' lifetime stats (requires confirmation)

## Compatibility

- WoW Retail (The War Within)
- Interface version: 120000
- Optional: Plumber addon for enhanced visuals

## Features

- Modular architecture for easy maintenance
- Minimal performance impact
- No continuous background scanning
- Efficient event handling
- Clean, professional codebase

## Support

For issues or suggestions, please report via:
- GitHub Issues
- CurseForge comments
- WoWInterface comments

## Version

Current version: 1.0.0

## License

All rights reserved.
