📜 Changelog – Version 1.22.0 (Release)  
  
📅 Release Date: 13-01-2026  
  
🛠️ Changes & Improvements  
✅ Combat Safety & Midnight Compatibility  
  
Combat-safety pass for Midnight restrictions.  
Cooldown reading is now blocked during combat to avoid “secret value” errors and refreshes automatically when combat ends.  
Main window hide/show is deferred during combat using safe handlers and completes on PLAYER_REGEN_ENABLED.  
Tooltips suppress live cooldown updates in combat and display a friendly notice instead.  
  
✅ Minimap & Interaction Protections  
  
Left-click on the minimap button will no longer open the main window during combat (chat notice shown instead).  
Right-click (Settings) is also blocked during combat to prevent taint and protected-call issues.  
Added settings option to show/hide the minimap button directly from the config UI.  
  
✅ Keystone Handling Improvements  
  
Added optional Auto-insert Mythic Keystone feature (disabled by default).  
Auto-insert respects all combat restrictions and user settings.  
Reset to Defaults now correctly disables auto-insert and updates the UI immediately.  
Keystone window is now movable, with position saved between sessions.  
  
✅ Data & Version Handling  
  
Added runtime support for TeleportData-12.lua on game versions 12.0.0+, while retaining legacy data for earlier versions.  
Data selection is automatic and requires no user interaction.  
  
✅ Stability & UX  
  
Fixed ADDON_ACTION_BLOCKED errors when closing the window during combat.  
Reduced unnecessary OnUpdate usage; added event-driven refreshes post-combat.  
General cleanup and consistency improvements across Retail and Midnight clients.  
  
🧩 Compatibility  
  
Fully compatible with Retail 11.2.5 and Midnight (12.x) clients.  
Gracefully handles Midnight combat and UI restrictions.  
  
⚠️ Known Issues / Notes  
  
During combat, cooldown overlays and tooltip timers are intentionally suppressed (by design under Midnight restrictions).  
The minimap button will not open the main window during combat (by design) and will notify you in chat.  
Auto-insert Mythic Keystone is disabled by default and must be enabled manually in settings.  
  
🚀 Thank you for using Mythic Dungeon Teleports!  
If you encounter any issues or have feedback, please report them via Github. 🚀  
