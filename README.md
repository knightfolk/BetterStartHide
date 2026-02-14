# BetterStartHide

**Version 1.0** - Stable Release

A better way to save your OLED from StartMenu burn-in.

## Overview

BetterStartHide dims the Windows taskbar to near-invisibility when not in use, and intelligently reveals it when you need it. Perfect for OLED displays where the taskbar can cause burn-in.

### Features

- **Smart Taskbar Dimming**: Dims the taskbar to near-invisibility when not in use
- **Intelligent Reveal**: Taskbar brightens when you need it:
  - Mouse hover over taskbar area
  - Fast mouse movement toward bottom edge
- **Velocity Detection**: Uses mouse speed and direction to predict intent
- **Gradual Fade**: Taskbar smoothly fades in as you approach (configurable)
- **Configuration UI**: Full settings window accessible from tray icon
- **No Dependencies**: Standalone executable - nothing else to install

## Quick Start

1. Download `BetterStartHide.exe`
2. Place it in a folder (e.g., `C:\BetterStartHide\`)
3. Double-click to run
4. Done! Your taskbar will dim automatically

> **Note**: A `Settings.ini` file will be created in the same folder on first run to store your preferences.

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

Settings are automatically saved to `Settings.ini`.

## Usage

| Action | How |
|--------|-----|
| Run | Double-click `BetterStartHide.exe` |
| Settings | Right-click tray icon → Settings |
| Show Taskbar | Right-click tray icon → Show Taskbar |
| Dim Taskbar | Right-click tray icon → Dim Taskbar |
| Exit | Right-click tray icon → Exit |

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

## Roadmap

### Version 1.1 (Planned)
- Multi-monitor support
- Windows installer for easy setup
- Automatic startup configuration

## License

MIT License