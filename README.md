# BetterStartHide

A better way to save your OLED from StartMenu burn-in.

## Features

- **Smart Taskbar Dimming**: Dims the taskbar to near-invisibility when not in use
- **Intelligent Reveal**: Taskbar brightens when you need it:
  - Mouse hover over taskbar area
  - Fast mouse movement toward bottom edge
- **Velocity Detection**: Uses mouse speed and direction to predict intent

## Requirements

- AutoHotkey v2.0+
- Windows 10/11

## Installation

1. Install [AutoHotkey v2](https://www.autohotkey.com/)
2. Clone this repository
3. Double-click `BetterStartHide.ahk` to run

## Configuration

Edit the configuration section at the top of `BetterStartHide.ahk`:

```autohotkey
global DimmedOpacity := 10      ; Opacity when dimmed (0-255)
global BrightOpacity := 255     ; Opacity when revealed (0-255)
global TriggerZone := 0.10      ; Bottom 10% of screen triggers reveal
global MinVelocity := 800       ; Mouse speed threshold
global HideDelay := 500         ; ms before hiding again
```

## Usage

- **Run**: Double-click `BetterStartHide.ahk`
- **Exit**: Right-click tray icon → Exit

## License

MIT License