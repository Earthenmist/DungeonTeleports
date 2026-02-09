# MythicDungeonTeleports

A World of Warcraft addon for quick and easy **dungeon and raid teleports** — with expansion coverage, cooldown tracking, and clean Blizzard-style UI integration.

---

## ✨ Features
- Clean, modern UI styled to match the default Blizzard interface
- Expansion-based dropdown selector
- Supports all expansions, including **The War Within** and **Midnight (12.x)**
- Displays learned and unlearned teleport spells (greyed out if not known)
- Cooldown tracking overlay on teleport buttons
- Tooltips showing cooldown status (**Ready / On Cooldown**)
- Optional **auto-insert Mythic Keystone** (disabled by default)
- Movable keystone window with saved position
- Minimap button with configurable visibility
- Fully localised with multi-language support
- Combat-safe behaviour (Midnight restrictions handled gracefully)

## ⚔️ Combat Safety (Midnight Compatible)
MythicDungeonTeleports is designed to respect modern combat restrictions:
- Cooldown data is suppressed during combat to avoid protected “secret value” errors
- UI show/hide actions are safely deferred until combat ends
- Tooltips display a friendly notice when cooldown info is unavailable
- Minimap interactions are blocked during combat to prevent taint
- All functionality resumes automatically after combat

## ⚙️ Configuration
Accessible via `/dtpconfig` or the Blizzard Settings menu.

Options include:
- Show / hide minimap button
- Default expansion selection
- Auto-insert Mythic Keystone (optional, off by default)
- UI behaviour and display preferences

Settings open correctly on **Retail (11.x)** and **Midnight (12.x)** clients.

## 📜 Slash Commands
| Command | Function |
|--------|----------|
| `/dungeonteleports` or `/dtp` | Toggle the main teleport UI |
| `/dtpconfig` | Open the addon settings |

## 🗺️ How to Use
1. Open the UI via the minimap button or `/dtp`
2. Select an expansion from the dropdown
3. Click a teleport spell to travel instantly (if learned)
4. View cooldowns via overlays or tooltips
5. Configure behaviour via `/dtpconfig`

## 🌍 Localization
MythicDungeonTeleports supports multiple languages and is fully localised.

Available languages:
- 🇺🇸 English (enUS)
- 🇩🇪 German (deDE)
- 🇪🇸 Spanish (esES, esMX)
- 🇫🇷 French (frFR)
- 🇮🇹 Italian (itIT)
- 🇰🇷 Korean (koKR)
- 🇧🇷 Portuguese (ptBR)
- 🇷🇺 Russian (ruRU)

Community translations are welcome and appreciated!

## 📦 Install
### CurseForge
- Install via the CurseForge app or download the latest release.

### Manual
1. Download the latest release `.zip`.
2. Extract into: `World of Warcraft/_retail_/Interface/AddOns/`
3. Ensure the folder name is `DungeonTeleports` (not nested).
4. Relaunch the game.

## 🧩 Compatibility
- **Game:** Retail
- **Era:** The War Within / Midnight-ready
- **Dependencies:** None (bundled libraries where required)

## 💬 Support & Community
For bug reports, feature requests, release notes, and beta builds, join the official Discord:

**LanniOfAlonsus • Addon Hub**  
https://discord.gg/U8mKfHpeeP

## 📜 License
All Rights Reserved.

## ❤️ Credits
- **Author:** LanniOfAlonsus
