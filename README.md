Gource-QuartzComposer-PlugIn
============================

Gource Quartz Composer Plugin for Mac OSX  
  
Started a project to get Gource to run as a screen saver on Mac OSX - the easiest way to do that is through Quartz Composer, included with Apple's XCode Tools. Ofcourse you will need to have gource installed on your system first. I'd reccomend doing that with brew.  
  
You can use this same technique to capture/record any window in Mac OSX through Quartz Composer  

This plugin is still a bit buggy (WIP), its alpha quality at best
  
Instructions to make a Gource Screen Saver:  

1. Build  
2. Gource.plugin -> /Library/Graphics/Quartz Composer Plug-Ins/  
3. Open "Quartz Composer.app"  
4. New from Template -> Screen Saver"  
5. Delete all except "Billboard" and "Clear"  
6. Click "Viewer" -> Click "Stop"  
7. Click "Patch Library"  
8. Dropdown Menu -> "Plug In"  
9. Drag and drop "Gource Screensaver" to main window  
10. Click (Highlight) "Gource Screensaver" Macro Patch in main window  
11. Click "Patch Inspector"  
12. Dropdown Menu -> "Settings"  
13. Enter desiered settings  
14. Connect "Gource Screensaver" "Image" output to "Image" input on billboard  
    14. To Test Settings Click "Viewer"  
    14. Click "Run"  
    14. (Make sure everything runs)  
    14. Click "Stop"  
    14. Rinse and repeat till it works  
15. "File" -> "Save" -> ~/Library/Screen Savers/  
16. Open "System Preferences", choose your gource screen saver and enjoy!  
