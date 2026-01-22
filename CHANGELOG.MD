📜 Changelog – Version 1.22.4 (Release)  
  
📅 Release Date: 22-01-2026  
🎯 Expansion: The War Within / Midnight  
  
🛠️ Fixes & Improvements  
⏱️ Midnight Cooldown Crash Fix (Updated)  
  
Fixed a Midnight-specific error that could occur when starting boss encounters in M+.  
Addresses Blizzard returning “secret” cooldown values that can error when compared or used in arithmetic.  
Cooldown handling is now fully secret-safe, avoiding direct comparisons on protected values and safely handling cooldown updates.  
Eliminates errors such as:  
attempt to compare local 'start' (a secret value)  
Applies to dungeon teleport cooldown overlays and internal cooldown logic.  
  
Fixed a Midnight-specific error that could occur when starting boss encounters in raids.  
Addresses Blizzard returning “secret” cooldown values that can error when compared or used in arithmetic.  
Cooldown handling is now fully secret-safe, avoiding direct comparisons on protected values and safely handling cooldown updates.  
Eliminates errors such as:  
attempt to compare local 'start' (a secret value)  
Applies to dungeon teleport cooldown overlays and internal cooldown logic.  
  
✅ Stability & Compatibility  
  
Further hardened cooldown update logic for Midnight’s protected API behaviour.  
Added additional safeguards to prevent cooldown frame updates during encounter start / boss pulls.  
No UI layout or settings changes required.  
Verified compatibility with Retail 11.2.7 and Midnight 12.x clients.  
  
⚠️ Notes  
  
During combat, cooldown overlays and tooltip timers remain intentionally suppressed due to Midnight restrictions.  
  
The minimap button will not open the main window during combat (by design).  
No configuration reset required.  
Safe to update mid-session.  
  
🚀 Thank you for using Mythic Dungeon Teleports!  
If you encounter any issues or have feedback, please report them via GitHub.  

