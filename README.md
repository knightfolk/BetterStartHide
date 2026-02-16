# BetterStartHide

**Version 1.3.1** - Production Ready

A better way to save your OLED from StartMenu burn-in.

## Overview

BetterStartHide dims the Windows taskbar to near-invisibility when not in use, and intelligently reveals it when you need it. Perfect for OLED displays where the taskbar can cause burn-in.

### Features

- **Multi-Monitor Support**: Works with all monitors and taskbars (Windows 10+)
- **Smart Taskbar Dimming**: Dims all taskbars to near-invisibility when not in use
- **Intelligent Reveal**: Taskbar brightens when you approach it:
  - Mouse proximity to taskbar area
  - Works on any edge (bottom, top, left, right)
- **Smooth Gradual Fade**: Taskbar smoothly fades in/out based on distance
- **Simple & Reliable**: Pure distance-based opacity - no complex velocity detection
- **Configuration UI**: Full settings window accessible from tray icon
- **Dark Mode Support**: Settings UI adapts to your system theme
- **No Dependencies**: Standalone executable - nothing else to install

## Quick Start

### Option 1: Installer (Recommended)

1. Download `BetterStartHide-1.3.1-Setup.exe` from [Releases](https://github.com/knightfolk/BetterStartHide/releases)
2. Run the installer
3. (Optional) Check "Launch when Windows starts" during installation
4. Done! Your taskbar will dim automatically

### Option 2: Portable

1. Download `BetterStartHide.exe` from [Releases](https://github.com/knightfolk/BetterStartHide/releases)
2. Place it in a folder (e.g., `C:\BetterStartHide\`)
3. Double-click to run
4. Done! Your taskbar will dim automatically

> **Note**: A `Settings.ini` file will be created in `%AppData%\BetterStartHide\` on first run to store your preferences.

## Installation

### Using the Installer

The installer provides the easiest setup experience:
- Installs to your Program Files folder (or choose a custom location)
- Optional: Start Menu shortcuts (on by default)
- Optional: Desktop shortcut (off by default)
- Optional: Launch when Windows starts (off by default)
- Includes uninstaller

### Portable Setup

For portable use (e.g., on a USB drive):

1. Create a dedicated folder:
   ```
   C:\BetterStartHide\
   ```

2. Place `BetterStartHide.exe` in this folder

3. (Optional) Add to Windows Startup manually:
   - Press `Win + R`, type `shell:startup`, press Enter
   - Create a shortcut to `BetterStartHide.exe` in the Startup folder
   - The app will now start automatically when you log in

### Files Created on First Run

| File | Description |
|------|-------------|
| `Settings.ini` | Stores your configuration preferences |

## Requirements

- **Windows 10/11**
- **No additional software required!**

The standalone executable (`BetterStartHide.exe`) runs without any dependencies.

## Configuration

Right-click the tray icon and select **Settings** to open the configuration window.

### Available Settings

#### Opacity
| Setting | Default | Description |
|---------|---------|-------------|
| Dimmed Opacity | 10 | Opacity when dimmed (0-255, 10 ≈ 4% visible) |
| Bright Opacity | 255 | Opacity when revealed (255 = fully visible) |

#### Trigger & Fade
| Setting | Default | Description |
|---------|---------|-------------|
| Trigger Zone | 10 | Pixels from taskbar edge that are always bright |
| Fade Distance | 100 | Distance over which gradual fade occurs |
| Edge Threshold | 5 | Pixels from screen edge that trigger immediate reveal |

#### Timing
| Setting | Default | Description |
|---------|---------|-------------|
| Check Interval | 10 | Mouse polling interval (ms) |

#### Behavior
| Setting | Default | Description |
|---------|---------|-------------|
| Independent Taskbar Control | Enabled | Each monitor's taskbar reveals/hides independently based on mouse position |
| Enabled Monitors | * (All) | Which monitors to control (* for all, or comma-separated list like "1,2,3") |

#### Appearance
| Setting | Default | Description |
|---------|---------|-------------|
| Theme | Auto | Settings UI theme (Auto/Light/Dark) |

Settings are automatically saved to `%AppData%\BetterStartHide\Settings.ini`.

## Usage

| Action | How |
|--------|-----|
| Run | Double-click `BetterStartHide.exe` |
| Settings | Right-click tray icon → Settings |
| Show All Taskbars | Right-click tray icon → Show All Taskbars |
| Dim All Taskbars | Right-click tray icon → Dim All Taskbars |
| Debug Monitors | Right-click tray icon → Debug Monitors |
| Donate | Right-click tray icon → Donate |
| Exit | Right-click tray icon → Exit |

### Multi-Monitor Notes

- **Independent Taskbar Control**: By default, each monitor's taskbar reveals/hides independently based on mouse position (can be disabled in Settings to control all taskbars together)
- **Works with any taskbar position**: Taskbars can be on the bottom, top, left, or right edge of any monitor
- **Automatic detection**: The app automatically detects when monitors are connected or disconnected
- **Debug info**: Use "Debug Monitors" from the tray menu to see detailed information about detected monitors and taskbars

## For Developers

### Building from Source

If you want to modify BetterStartHide or compile it yourself:

1. Install [AutoHotkey v2](https://www.autohotkey.com/)
2. Clone this repository
3. Run `Compile.ahk` to compile the executable

The `Compile.ahk` script will:
- Auto-detect your AutoHotkey installation
- Allow you to select a custom icon
- Create `BetterStartHide.exe`

### Running as Script

```
# Requires AutoHotkey v2.0+
BetterStartHide.ahk
```

## Version History

### Version 1.3.1 (Current) - Production Ready
- **Build system improvements**: Environment-aware AutoHotkey path detection
- **Documentation updates**: Added EnabledMonitors and EdgeThreshold settings to documentation
- **Auto-hide detection**: Improved detection for auto-hidden taskbars
- **Tray icon state**: Dynamic tooltip showing current dim/reveal state
- **Donate link**: Now links to GitHub Sponsors
- **Debug info**: Shows auto-hide status in Debug Monitors output

### Version 1.3 - Simplified & Refined
- **Simplified reveal logic**: Removed velocity detection - now uses pure distance-based opacity
- **Streamlined settings**: Removed Exit Zone, Min Velocity, Hide Delay, Gradual Fade, Fade Out options
- **Distance-based opacity**: Taskbar brightness smoothly transitions based on mouse distance
- **Dark mode support**: Settings UI now supports Auto/Light/Dark themes
- **Restore Defaults**: Added button to reset all settings to defaults
- **Donate option**: Added placeholder for future donation support
- Cleaner, more maintainable codebase

### Version 1.2 - Installer & Polish
- Windows installer for easy setup
- Automatic startup configuration
- Per-monitor opacity settings

### Version 1.1 - Multi-Monitor Support
- **Multi-monitor support**: Works with all monitors and taskbars
- **Taskbar on any edge**: Supports taskbars on top, bottom, left, or right
- **Automatic display detection**: Responds to monitor connect/disconnect
- **Debug Monitors**: Tray menu option to view monitor configuration
- **Per-monitor taskbar detection**: Finds both primary (Shell_TrayWnd) and secondary (Shell_SecondaryTrayWnd) taskbars

### Version 1.0 - Stable Release
- Smart taskbar dimming with intelligent reveal
- Configuration UI with all settings
- Custom icon support
- Works regardless of window focus

## Roadmap

### Version 1.4 (Planned)
- Performance optimizations
- Additional multi-monitor configuration options

### Version 2.0 (Future)
- Desktop icon dimming feature

## Troubleshooting

### Taskbar not dimming
- Ensure no other taskbar utilities are running that might conflict
- Try "Dim All Taskbars" from the tray menu
- Check if the taskbar is set to auto-hide in Windows Settings (auto-hidden taskbars may behave differently)

### App not starting on Windows boot
- If using the portable version, manually add a shortcut to the Startup folder:
  - Press `Win + R`, type `shell:startup`, press Enter
  - Create a shortcut to `BetterStartHide.exe` in this folder
- For the installed version, reinstall and check "Launch when Windows starts"

### Multi-monitor detection issues
- Use "Debug Monitors" from the tray menu to see what monitors and taskbars are detected
- Try clicking "Dim All Taskbars" then moving your mouse to each taskbar
- Ensure your monitor arrangement is correct in Windows Settings → Display

### Settings not saving
- Check that `%AppData%\BetterStartHide\` folder exists and is writable
- Use the "Reset" button in Settings to restore defaults
- Try deleting the `Settings.ini` file and restarting the app

### Settings file corrupted
- Delete `%AppData%\BetterStartHide\Settings.ini`
- Restart the app - it will create a new settings file with defaults

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.