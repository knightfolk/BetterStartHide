# BetterStartHide

**Version 1.0** - Stable Release

A better way to save your OLED from StartMenu burn-in.

## Features

- **Smart Taskbar Dimming**: Dims the taskbar to near-invisibility when not in use
- **Intelligent Reveal**: Taskbar brightens when you need it:
  - Mouse hover over taskbar area
  - Fast mouse movement toward bottom edge
- **Velocity Detection**: Uses mouse speed and direction to predict intent
- **Gradual Fade**: Taskbar smoothly fades in as you approach (configurable)
- **Configuration UI**: Full settings window accessible from tray icon

## Requirements

- AutoHotkey v2.0+ (only required for running as script)
- Windows 10/11

## Installation

### Option 1: Use the Compiled EXE (Recommended)
1. Download `BetterStartHide.exe` from releases
2. Double-click to run
3. No AutoHotkey installation needed!

### Option 2: Run as Script
1. Install [AutoHotkey v2](https://www.autohotkey.com/)
2. Clone this repository
3. Double-click `BetterStartHide.ahk` to run

> **Note**: The compiled .exe runs standalone without requiring AutoHotkey to be installed.

## Configuration

Right-click the tray icon and select "Settings" to open the configuration window.

### Available Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Dimmed Opacity | 10 | Opacity when dimmed (0-255, 10 ≈ 4% visible) |
| Bright Opacity | 255 | Opacity when revealed (255 = fully visible) |
| Trigger Zone | 10 | Pixels from taskbar top edge to trigger reveal |
| Min Velocity | 400 | Mouse speed threshold (pixels/sec) |
| Check Interval | 10 | Mouse polling interval (ms) |
| Hide Delay | 500 | Time before hiding again (ms) |
| Gradual Fade | Enabled | Smoothly fade in as mouse approaches |
| Fade Distance | 100 | Distance over which fade occurs (pixels) |

Settings are saved to `Settings.ini` in the same directory as the script/exe.

## Usage

- **Run**: Double-click `BetterStartHide.exe` or `BetterStartHide.ahk`
- **Settings**: Right-click tray icon → Settings
- **Show Taskbar**: Right-click tray icon → Show Taskbar
- **Dim Taskbar**: Right-click tray icon → Dim Taskbar
- **Exit**: Right-click tray icon → Exit

## Compiling to EXE

To create a standalone executable:

```ahk
; Run this in AutoHotkey v2
Ahk2Exe /in "BetterStartHide.ahk" /out "BetterStartHide.exe"
```

Or use the included `Compile.ahk` script if AutoHotkey v2 is installed.

## Version History

### Version 1.0 (Current) - Stable Release
- All features complete and tested
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

## License

MIT License
