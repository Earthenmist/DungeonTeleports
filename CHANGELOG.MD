📜 Mythic Dungeon Teleports – Latest Release Changelog  
Version 1.22.16  
  
🎉 New Feature – Group Reminder Module  
- Added a new optional Group Reminder module.  
- Displays a pop-up when you accept a Mythic+ group invite.  
- Shows:  
  - Dungeon name (from LFG)  
  - Group name  
  - Applied role  
  - Teleport availability  
- Includes a teleport button if the spell is known.  
- Cooldown swipe overlay now appears when the teleport is on cooldown.  
- Module can be enabled or disabled in Settings.  
- Popup layout refined for better readability and spacing.  
  
🛠️ Improvements  
- Applied role detection improved to ensure the accepted role displays correctly.  
- Popup now preserves original LFG dungeon names while resolving teleports internally.  
- Added alias handling for dungeons with multiple LFG naming variants.  
- Tazavesh split wings now resolve correctly:  
  - Tazavesh Streets (Mythic Keystone)  
  - Tazavesh Gambit (Mythic Keystone)  
  Both map to the shared teleport: Tazavesh, the Veiled Market.  
- Improved teleport resolution logic to prevent false “Teleport not known” messages.  
- Updated spell-known and cooldown checks for modern API compatibility.  
  
🎨 UI Improvements  
- Popup title spacing adjusted to prevent overlap with the close button.  
- Teleport label repositioned to avoid overlapping the teleport button.  
- Cooldown visuals now match the main teleport panel style.  
  
✅ Stability & Compatibility  
- Restored the auto-insert keystone safeguard: if the UI reports the keystone is for a different dungeon, the addon stops further insertion retries (prevents warning spam / retry loops).  
- Fixed Lua errors that could prevent the Group Reminder module from loading.  
- Improved handling of protected cooldown values introduced in Midnight.  
- Verified compatibility with Retail and Midnight clients.  
- No configuration reset required.  
  
🚀 Thank you for using Mythic Dungeon Teleports!  
  
