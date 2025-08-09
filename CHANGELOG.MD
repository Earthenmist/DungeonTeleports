📜 Changelog - Version 1.19.1    
  
📅 Release Date: 09-08-2025  
  
🛠️ Changes & Improvements:  
  
✅ Added the shim.lua file - missed in 1.19  
✅ Added Wago Analytics integration with safe initialization (no errors if not installed)  
✅ Analytics events added for main window, config window, minimap clicks, expansion selection, teleport clicks/success/failure, and setting changes  
✅ Reordered .toc so LibStub loads before Wago Analytics shim for proper initialization  
✅ Removed duplicate ui_visibility events by relying on OnShow / OnHide hooks only  
✅ Fixed double-firing teleport_click events by using PostClick with LeftButtonUp only  
✅ Cleaned up code for better readability and maintainability in analytics-enabled functions  
  
⚠️ Known Issues / Notes:  
  
🚀 Thank you for using Mythic Dungeon Teleports! If you encounter any issues, please report them via our Discord 🚀  


