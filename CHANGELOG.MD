📜 Changelog – Version 1.22.1 (Release)  
  
📅 Release Date: 14-01-2026  
  
🛠️ Changes & Improvements  
✅ Settings & Minimap Fixes  
  
Fixed an issue on Midnight Beta where right-clicking the minimap icon caused a Settings API error.  
Restored correct behaviour on Retail, where opening settings via the minimap now jumps directly to the Dungeon Teleports addon page (as before).  
Settings access is now handled correctly across Retail (11.x) and Midnight (12.x) clients.  
  
✅ Keystone Handling  
  
Auto-insert Mythic Keystone remains disabled by default.  
Reset to Defaults now correctly disables auto-insert and applies immediately without requiring a toggle.  
Keystone insertion logic now respects the setting state consistently on all clients.  
  
✅ Data & Version Handling  
  
Automatic runtime selection between TeleportData.lua and TeleportData-12.lua based on game version (12.0.0+).  
No user configuration required; the correct data set is chosen automatically.  
  
✅ Stability & Compatibility  
  
Improved Blizzard Settings API handling to prevent invalid category ID errors.  
Verified compatibility with Retail 11.2.5 and Midnight 12.x.  
General polish and robustness improvements.  
  
⚠️ Known Issues / Notes  
  
During combat, cooldown overlays and tooltip timers remain intentionally suppressed due to Midnight restrictions.  
The minimap button will not open the main window during combat (by design).  
  
🚀 Thank you for using Mythic Dungeon Teleports!  
If you encounter any issues or have feedback, please report them via Github. 🚀  

