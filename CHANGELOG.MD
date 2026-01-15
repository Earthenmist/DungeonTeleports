📜 Changelog – Version 1.22.2 (Release)  
  
📅 Release Date: 15-01-2026  
  
🛠️ Changes & Improvements  
✅ Keystone Handling Improvements  
  
Fixed an issue where auto-insert Mythic Keystone would repeatedly retry when attempting to insert a keystone for the wrong dungeon.  
The addon now detects the Blizzard UI error “That Keystone is for a different dungeon” and immediately stops further insertion attempts.  
Prevents repeated warning spam and unintended retry loops when the incorrect keystone is present.  
Behaviour applies consistently across Retail (11.x) and Midnight (12.x) clients.  
  
🌍 Localisation Updates  
  
Updated ruRU localisation strings.  
Improvements supplied via Pull Request #15 by Hollicsh — thank you for the contribution! ❤️  
Ensures clearer and more accurate Russian language support throughout the addon.  
  
✅ Stability & Compatibility  
  
Improved resilience of keystone handling logic during Challenge Mode interactions.  
Further hardened retry safeguards to prevent unintended behaviour during dungeon setup.  
Verified compatibility with Retail 11.2.7 and Midnight 12.x clients.  
  
⚠️ Known Issues / Notes  
  
During combat, cooldown overlays and tooltip timers remain intentionally suppressed due to Midnight restrictions.  
The minimap button will not open the main window during combat (by design).  
  
🚀 Thank you for using Mythic Dungeon Teleports!  
If you encounter any issues or have feedback, please report them via GitHub.  
  
