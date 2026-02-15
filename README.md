# BetterStartHide

**Version 1.1** - Multi-Monitor Support

A better way to save your OLED from StartMenu burn-in.

## Overview

BetterStartHide dims the Windows taskbar to near-invisibility when not in use, and intelligently reveals it when you need it. Perfect for OLED displays where the taskbar can cause burn-in.

### Features

- **Multi-Monitor Support**: Works with all monitors and taskbars (Windows 10+)
- **Smart Taskbar Dimming**: Dims all taskbars to near-invisibility when not in use
- **Intelligent Reveal**: Taskbar brightens when you need it:
  - Mouse hover over taskbar area
  - Fast mouse movement toward taskbar edge
  - Works on any edge (bottom, top, left, right)
- **Velocity Detection**: Uses mouse speed and direction to predict intent
- **Gradual Fade**: Taskbar smoothly fades in as you approach (configurable)
- **Configuration UI**: Full settings window accessible from tray icon
- **No Dependencies**: Standalone executable - nothing else to install

## Quick Start

1. Download `BetterStartHide.exe` from [Releases](https://github.com/knightfolk/BetterStartHide/releases)
2. Place it in a folder (e.g., `C:\BetterStartHide\`)
3. Double-click to run
4. Done! Your taskbar will dim automatically

> **Note**: A `Settings.ini` file will be created in `%AppData%\BetterStartHide\` on first run to store your preferences.

## Installation

### Recommended Setup

1. Create a dedicated folder for BetterStartHide:
   ```
   C:\BetterStartHide\
   ```

2. Place `BetterStartHide.exe` in this folder

3. (Optional) Add to Windows Startup:
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

#### Trigger Settings
| Setting | Default | Description |
|---------|---------|-------------|
| Trigger Zone | 10 | Pixels from taskbar edge to trigger reveal |
| Exit Zone | 50 | Distance from taskbar before fade-out starts (hysteresis) |
| Min Velocity | 400 | Mouse speed threshold (pixels/sec) |

#### Timing
| Setting | Default | Description |
|---------|---------|-------------|
| Check Interval | 10 | Mouse polling interval (ms) |
| Hide Delay | 500 | Time before hiding again (ms) |

#### Fade In (On Approach)
| Setting | Default | Description |
|---------|---------|-------------|
| Gradual Fade | Enabled | Smoothly fade in as mouse approaches |
| Fade Distance | 100 | Distance over which fade occurs (pixels) |

#### Fade Out (On Leave)
| Setting | Default | Description |
|---------|---------|-------------|
| Fade Out | Enabled | Smooth fade-out animation when mouse leaves |
| Fade Out Duration | 300 | Duration of fade-out animation (ms) |

#### Behavior
| Setting | Default | Description |
|---------|---------|-------------|
| Independent Taskbar Control | Enabled | Each monitor's taskbar reveals/hides independently based on mouse position |

Settings are automatically saved to `%AppData%\BetterStartHide\Settings.ini`.

## Usage

| Action | How |
|--------|-----|
| Run | Double-click `BetterStartHide.exe` |
| Settings | Right-click tray icon → Settings |
| Show All Taskbars | Right-click tray icon → Show All Taskbars |
| Dim All Taskbars | Right-click tray icon → Dim All Taskbars |
| Debug Monitors | Right-click tray icon → Debug Monitors |
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

### Version 1.1 (Current) - Multi-Monitor Support
- **Multi-monitor support**: Works with all monitors and taskbars
- **Taskbar on any edge**: Supports taskbars on top, bottom, left, or right
- **Automatic display detection**: Responds to monitor connect/disconnect
- **Debug Monitors**: Tray menu option to view monitor configuration
- **Per-monitor taskbar detection**: Finds both primary (Shell_TrayWnd) and secondary (Shell_SecondaryTrayWnd) taskbars
- All features from Version 1.0

### Version 1.0 - Stable Release
- Smart taskbar dimming with intelligent reveal
- Configuration UI with all settings
- Gradual fade on mouse approach
- Custom icon support
- Works regardless of window focus

### Beta 3
- Fixed settings GUI layout (Gradual Fade section)
- Improved taskbar opacity handling with WinSetTransparent
- Added CoordMode for screen-relative mouse coordinates
- Added periodic refresh to maintain opacity

### Beta 2
- Added configuration UI accessible from tray icon
- Added Compile.ahk with AutoHotkey detection
- Added custom icon support for compiled executable
- Fixed compiler base file detection
- Fixed 32/64-bit DllCall compatibility

### Beta 1
- Initial release
- Basic taskbar dim and reveal functionality
- Velocity-based trigger detection
- Tray icon menu with basic controls

## Roadmap

### Version 1.2 (Planned)
- Per-monitor opacity settings
- Windows installer for easy setup
- Automatic startup configuration
- Taskbar auto-hide detection improvements

### Version 2.0 (Future)
- Desktop icon dimming feature

## License

MIT License