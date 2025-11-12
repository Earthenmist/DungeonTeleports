📜 Changelog - Version 1.21.2-Beta  
📅 Release Date: 12-11-2025  
  
🛠️ Changes & Improvements:  
  
✅ Combat-safety pass (Midnight beta compatibility)  
Cooldown reading is now blocked during combat to avoid “secret value” errors; it refreshes automatically on leaving combat.  
Main window Hide/Show is deferred in combat (uses DT_SafeHide / DT_SafeShow) and completes on PLAYER_REGEN_ENABLED.  
Tooltip now avoids live cooldown updates in combat and shows a friendly “cooldown info hidden in combat (beta)” line.  

✅ Minimap protections  
Left-click on the minimap button won’t open the window in combat (adds a short chat notice instead).  
Right-click (Settings) is also blocked during combat to prevent taint and protected-call issues.  
  
✅ Stability & UX  
Fixed ADDON_ACTION_BLOCKED when trying to close the window while in combat.  
Reduced unnecessary OnUpdate usage; events now include PLAYER_REGEN_ENABLED for post-combat refreshes.  
  
🧩 Compatibility  
Midnight beta changes (combat restrictions) handled gracefully.  
  
⚠️ Known Issues / Notes:  
In combat, cooldown overlays and tooltip timers are intentionally suppressed (by design under Midnight beta restrictions). They resume immediately after combat.  
The minimap button will not open the main window during combat (by design) and will notify you in chat.  
  
🚀 Thank you for using Mythic Dungeon Teleports! If you encounter any issues, please report them via our Discord. 🚀  







