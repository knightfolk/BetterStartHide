# AutoHotkey v2 Multi-Monitor Implementation Research

## Executive Summary

BetterStartHide currently uses `A_ScreenHeight` which only returns the primary monitor's height. This document details all AutoHotkey v2 monitor-related functions and techniques needed to support multi-monitor configurations.

---

## 1. AutoHotkey v2 Monitor Functions Reference

### 1.1 MonitorGet()

**Purpose:** Retrieves the bounding coordinates of a monitor.

**Function Signature:**
```autohotkey
MonitorGet(MonitorNumber, &Left := "", &Top := "", &Right := "", &Bottom := "")
```

**Parameters:**
- `MonitorNumber` - The monitor number (1-based index)
- `&Left` - Output variable for left coordinate
- `&Top` - Output variable for top coordinate  
- `&Right` - Output variable for right coordinate
- `&Bottom` - Output variable for bottom coordinate

**Return Value:** 
- Returns 1 on success, 0 on failure
- Throws exception if monitor doesn't exist

**Example for BetterStartHide:**
```autohotkey
; Get dimensions of monitor 2
MonitorGet(2, &Left, &Top, &Right, &Bottom)
Width := Right - Left
Height := Bottom - Top
```

---

### 1.2 MonitorGetCount()

**Purpose:** Returns the total number of monitors.

**Function Signature:**
```autohotkey
MonitorGetCount()
```

**Parameters:** None

**Return Value:** Integer count of monitors

**Example:**
```autohotkey
MonitorCount := MonitorGetCount()
MsgBox("You have " MonitorCount " monitor(s) connected")
```

---

### 1.3 MonitorGetName()

**Purpose:** Retrieves the display name of a monitor.

**Function Signature:**
```autohotkey
MonitorGetName(MonitorNumber)
```

**Parameters:**
- `MonitorNumber` - The monitor number (1-based)

**Return Value:** String containing the monitor's display name

**Example:**
```autohotkey
Loop MonitorGetCount() {
    MsgBox("Monitor " A_Index ": " MonitorGetName(A_Index))
}
```

---

### 1.4 MonitorGetPrimary()

**Purpose:** Returns the monitor number of the primary monitor.

**Function Signature:**
```autohotkey
MonitorGetPrimary()
```

**Parameters:** None

**Return Value:** Integer (1-based monitor number of primary display)

**Example:**
```autohotkey
PrimaryMon := MonitorGetPrimary()
MsgBox("Primary monitor is #" PrimaryMon)
```

---

### 1.5 MonitorGetWorkArea()

**Purpose:** Retrieves the working area coordinates of a monitor (excluding taskbar, docked windows).

**Function Signature:**
```autohotkey
MonitorGetWorkArea(MonitorNumber, &Left := "", &Top := "", &Right := "", &Bottom := "")
```

**Parameters:**
- `MonitorNumber` - The monitor number (1-based index)
- `&Left` - Output variable for left coordinate
- `&Top` - Output variable for top coordinate
- `&Right` - Output variable for right coordinate
- `&Bottom` - Output variable for bottom coordinate

**Return Value:** 1 on success, 0 on failure

**Critical for Taskbar Detection:**
```autohotkey
; The taskbar is in the difference between full area and work area
MonitorGet(1, &fullLeft, &fullTop, &fullRight, &fullBottom)
MonitorGetWorkArea(1, &workLeft, &workTop, &workRight, &workBottom)

; Calculate taskbar position
fullHeight := fullBottom - fullTop
workHeight := workBottom - workTop

if (workBottom < fullBottom) {
    ; Taskbar is at BOTTOM
    TaskbarHeight := fullBottom - workBottom
    TaskbarPosition := "Bottom"
} else if (workTop > fullTop) {
    ; Taskbar is at TOP
    TaskbarHeight := workTop - fullTop
    TaskbarPosition := "Top"
} else if (workLeft > fullLeft) {
    ; Taskbar is at LEFT
    TaskbarWidth := workLeft - fullLeft
    TaskbarPosition := "Left"
} else if (workRight < fullRight) {
    ; Taskbar is at RIGHT
    TaskbarWidth := fullRight - workRight
    TaskbarPosition := "Right"
}
```

---

### 1.6 MonitorFromPoint()

**Purpose:** Returns the monitor number that contains a specified point.

**Function Signature:**
```autohotkey
MonitorFromPoint(X, Y, Mode := "Default")
```

**Parameters:**
- `X` - The X coordinate
- `Y` - The Y coordinate
- `Mode` (optional) - One of:
  - `"Default"` (or 0) - Returns 0 if point not on any monitor
  - `"Nearest"` (or 1) - Returns nearest monitor if point not on any

**Return Value:** Monitor number (1-based), or 0 if not on any monitor

**Example for BetterStartHide:**
```autohotkey
MouseGetPos(&mouseX, &mouseY)
CurrentMonitor := MonitorFromPoint(mouseX, mouseY, "Nearest")
MsgBox("Mouse is on monitor #" CurrentMonitor)
```

---

### 1.7 MonitorFromWindow()

**Purpose:** Returns the monitor number that has the largest intersection with a window.

**Function Signature:**
```autohotkey
MonitorFromWindow(WinTitle, Mode := "Default")
```

**Parameters:**
- `WinTitle` - The title/hwnd of the window
- `Mode` (optional) - Same as MonitorFromPoint

**Return Value:** Monitor number, or 0

**Example:**
```autohotkey
; Find which monitor the active window is on
ActiveMonitor := MonitorFromWindow("A")
MsgBox("Active window is on monitor #" ActiveMonitor)
```

---

### 1.8 SysGet Commands for Monitor Info

**Function Signature:**
```autohotkey
SysGet(Subcommand)
```

**Relevant Subcommands:**

| Subcommand | Description | Returns |
|------------|-------------|---------|
| `MonitorCount` | Number of monitors | Integer |
| `MonitorPrimary` | Primary monitor number | Integer |
| `Monitor` | Monitor coordinates | Object with Left, Top, Right, Bottom |
| `MonitorWorkArea` | Work area coordinates | Object with Left, Top, Right, Bottom |
| `SM_CXVIRTUALSCREEN` | Virtual screen width | Integer |
| `SM_CYVIRTUALSCREEN` | Virtual screen height | Integer |
| `SM_XVIRTUALSCREEN` | Virtual screen left | Integer |
| `SM_YVIRTUALSCREEN` | Virtual screen top | Integer |

**Virtual Screen Example:**
```autohotkey
; Virtual screen encompasses all monitors
VirtualWidth := SysGet(78)   ; SM_CXVIRTUALSCREEN
VirtualHeight := SysGet(79)  ; SM_CYVIRTUALSCREEN
VirtualLeft := SysGet(76)    ; SM_XVIRTUALSCREEN  
VirtualTop := SysGet(77)     ; SM_YVIRTUALSCREEN

MsgBox("Virtual screen: " VirtualWidth "x" VirtualHeight " at (" VirtualLeft "," VirtualTop ")")
```

---

## 2. Enumerating All Monitors

### 2.1 Basic Enumeration Pattern

```autohotkey
EnumerateMonitors() {
    monitors := Map()
    
    Loop MonitorGetCount() {
        monNum := A_Index
        
        ; Get full monitor area
        MonitorGet(monNum, &Left, &Top, &Right, &Bottom)
        
        ; Get work area (excluding taskbar)
        MonitorGetWorkArea(monNum, &workLeft, &workTop, &workRight, &workBottom)
        
        ; Store monitor info
        monitors[monNum] := {
            Left: Left,
            Top: Top,
            Right: Right,
            Bottom: Bottom,
            Width: Right - Left,
            Height: Bottom - Top,
            WorkLeft: workLeft,
            WorkTop: workTop,
            WorkRight: workRight,
            WorkBottom: workBottom,
            IsPrimary: (monNum = MonitorGetPrimary())
        }
    }
    
    return monitors
}
```

### 2.2 Detailed Monitor Information Structure

```autohotkey
class MonitorInfo {
    __New(num) {
        this.Number := num
        this.Name := MonitorGetName(num)
        this.IsPrimary := (num = MonitorGetPrimary())
        
        ; Full dimensions
        MonitorGet(num, &L, &T, &R, &B)
        this.Left := L
        this.Top := T
        this.Right := R
        this.Bottom := B
        this.Width := R - L
        this.Height := B - T
        
        ; Work area (excludes taskbar)
        MonitorGetWorkArea(num, &WL, &WT, &WR, &WB)
        this.WorkLeft := WL
        this.WorkTop := WT
        this.WorkRight := WR
        this.WorkBottom := WB
        this.WorkWidth := WR - WL
        this.WorkHeight := WB - WT
        
        ; Calculate taskbar info
        this.CalculateTaskbar()
    }
    
    CalculateTaskbar() {
        ; Bottom taskbar
        if (this.WorkBottom < this.Bottom) {
            this.TaskbarPosition := "Bottom"
            this.TaskbarSize := this.Bottom - this.WorkBottom
            this.TaskbarTop := this.WorkBottom
            this.TaskbarLeft := this.Left
            this.TaskbarRight := this.Right
            this.TaskbarBottom := this.Bottom
        }
        ; Top taskbar
        else if (this.WorkTop > this.Top) {
            this.TaskbarPosition := "Top"
            this.TaskbarSize := this.WorkTop - this.Top
            this.TaskbarTop := this.Top
            this.TaskbarLeft := this.Left
            this.TaskbarRight := this.Right
            this.TaskbarBottom := this.WorkTop
        }
        ; Left taskbar
        else if (this.WorkLeft > this.Left) {
            this.TaskbarPosition := "Left"
            this.TaskbarSize := this.WorkLeft - this.Left
            this.TaskbarTop := this.Top
            this.TaskbarLeft := this.Left
            this.TaskbarRight := this.WorkLeft
            this.TaskbarBottom := this.Bottom
        }
        ; Right taskbar
        else if (this.WorkRight < this.Right) {
            this.TaskbarPosition := "Right"
            this.TaskbarSize := this.Right - this.WorkRight
            this.TaskbarTop := this.Top
            this.TaskbarLeft := this.WorkRight
            this.TaskbarRight := this.Right
            this.TaskbarBottom := this.Bottom
        }
        ; No taskbar (or auto-hidden)
        else {
            this.TaskbarPosition := "None"
            this.TaskbarSize := 0
        }
    }
    
    ContainsPoint(x, y) {
        return (x >= this.Left && x <= this.Right && 
                y >= this.Top && y <= this.Bottom)
    }
    
    DistanceFromEdge(x, y) {
        ; Returns distance from the taskbar edge
        switch this.TaskbarPosition {
            case "Bottom": return this.TaskbarTop - y
            case "Top": return y - this.TaskbarBottom
            case "Left": return x - this.TaskbarRight
            case "Right": return this.TaskbarLeft - x
            default: return 9999
        }
    }
}
```

---

## 3. Monitor Arrangement Handling

### 3.1 Horizontal Arrangement (Side by Side)

```
[Monitor 1] [Monitor 2] [Monitor 3]
```

**Detection:** Monitors have different Left/Right coordinates but similar Top/Bottom

```autohotkey
IsHorizontalArrangement(mon1, mon2) {
    ; Check if monitors are horizontally adjacent
    return (mon1.Right = mon2.Left) || (mon2.Right = mon1.Left)
}
```

### 3.2 Vertical Arrangement (Stacked)

```
[Monitor 1]
[Monitor 2]
```

**Detection:** Monitors have different Top/Bottom but similar Left/Right

```autohotkey
IsVerticalArrangement(mon1, mon2) {
    ; Check if monitors are vertically stacked
    return (mon1.Bottom = mon2.Top) || (mon2.Bottom = mon1.Top)
}
```

### 3.3 Mixed/Complex Arrangements

```
[Monitor 1] [Monitor 2]
             [Monitor 3]
```

**Handling:** No assumptions about arrangement; always use actual coordinates

---

## 4. Taskbar Detection Per Monitor

### 4.1 Primary Monitor Taskbar

The main taskbar (`Shell_TrayWnd`) is always on the primary monitor:

```autohotkey
FindPrimaryTaskbar() {
    ; Shell_TrayWnd is the main taskbar on primary monitor
    return WinExist("ahk_class Shell_TrayWnd")
}
```

### 4.2 Secondary Monitor Taskbars

Secondary monitor taskbars use a different window class:

```autohotkey
FindAllTaskbars() {
    taskbars := []
    
    ; Find primary taskbar
    primaryHwnd := WinExist("ahk_class Shell_TrayWnd")
    if (primaryHwnd) {
        taskbars.Push({Hwnd: primaryHwnd, IsPrimary: true})
    }
    
    ; Find secondary taskbars (Shell_SecondaryTrayWnd)
    try {
        DetectHiddenWindows(true)
        hwnd := 0
        Loop {
            hwnd := WinExist("ahk_class Shell_SecondaryTrayWnd",,, hwnd)
            if (!hwnd)
                break
            taskbars.Push({Hwnd: hwnd, IsPrimary: false})
        }
        DetectHiddenWindows(false)
    }
    
    return taskbars
}
```

### 4.3 Mapping Taskbars to Monitors

```autohotkey
MapTaskbarsToMonitors() {
    monitors := []
    
    ; Build monitor list with taskbar info
    Loop MonitorGetCount() {
        mon := MonitorInfo(A_Index)
        
        ; Find taskbar on this monitor
        if (mon.IsPrimary) {
            mon.TaskbarHwnd := WinExist("ahk_class Shell_TrayWnd")
        } else {
            ; Find secondary taskbar by position
            DetectHiddenWindows(true)
            WinGetPos(&tbX, &tbY, &tbW, &tbH, "ahk_class Shell_SecondaryTrayWnd")
            ; Match position to monitor
            ; ... position matching logic
            DetectHiddenWindows(false)
        }
        
        monitors.Push(mon)
    }
    
    return monitors
}
```

---

## 5. Mouse Position Handling

### 5.1 Determine Current Monitor

```autohotkey
GetCurrentMonitor() {
    MouseGetPos(&x, &y)
    return MonitorFromPoint(x, y, "Nearest")
}
```

### 5.2 Get Monitor from Any Point

```autohotkey
GetMonitorFromPoint(x, y) {
    monNum := MonitorFromPoint(x, y, "Nearest")
    if (monNum = 0) {
        return MonitorGetPrimary()  ; Fallback to primary
    }
    return monNum
}
```

### 5.3 Edge Detection for Current Monitor

```autohotkey
IsMouseNearTaskbarEdge(threshold := 10) {
    MouseGetPos(&x, &y)
    monNum := MonitorFromPoint(x, y, "Nearest")
    mon := MonitorInfo(monNum)
    
    switch mon.TaskbarPosition {
        case "Bottom":
            return (y >= mon.TaskbarTop - threshold && y <= mon.Bottom)
        case "Top":
            return (y >= mon.Top && y <= mon.TaskbarBottom + threshold)
        case "Left":
            return (x >= mon.Left && x <= mon.TaskbarRight + threshold)
        case "Right":
            return (x >= mon.TaskbarLeft - threshold && x <= mon.Right)
        default:
            return false
    }
}
```

---

## 6. Edge Cases and Solutions

### 6.1 Different DPI/Scale Settings Per Monitor

**Problem:** Monitors can have different scaling (100%, 125%, 150%, etc.)

**AutoHotkey v2 Solution:**
```autohotkey
; AHK v2 handles DPI automatically for coordinates
; Ensure CoordMode is set correctly
CoordMode("Mouse", "Screen")
CoordMode("Pixel", "Screen")

; For DPI-aware calculations, use the actual monitor dimensions
; which AHK returns in virtualized coordinates

; If you need actual physical coordinates, use DllCall:
GetDPIForMonitor(monitorNum) {
    ; This requires obtaining the HMONITOR handle first
    ; AHK doesn't expose this directly, but we can use
    ; the ratio of reported vs expected sizes
    MonitorGet(monitorNum, &L, &T, &R, &B)
    ; DPI ratio is implicit in the coordinates
    return {Width: R-L, Height: B-T}
}
```

**BetterStartHide Impact:**
- Mouse coordinates from `MouseGetPos` are in the same coordinate space as `MonitorGet`
- No special handling needed for most cases
- Pixel-based thresholds (TriggerPixels, FadeDistance) may need adjustment per monitor

### 6.2 Disconnected/Reconnected Monitors

**Problem:** Monitor configuration can change at runtime

**Solution - WM_DISPLAYCHANGE Message:**
```autohotkey
; Register for display change notifications
OnMessage(0x007E, DisplayChanged)

DisplayChanged(wParam, lParam, msg, hwnd) {
    ; WM_DISPLAYCHANGE received
    ; wParam = bits per pixel
    ; lParam = LOWORD = horizontal resolution, HIWORD = vertical resolution
    
    ; Rebuild monitor cache
    global monitorsNeedRefresh := true
    
    ; Signal to refresh taskbar info
    RefreshMonitorInfo()
}

RefreshMonitorInfo() {
    global g_Monitors
    g_Monitors := []
    
    Loop MonitorGetCount() {
        g_Monitors.Push(MonitorInfo(A_Index))
    }
}
```

**Periodic Check Alternative:**
```autohotkey
; Compare cached count vs current count
CheckMonitorChanges() {
    global cachedMonitorCount
    
    currentCount := MonitorGetCount()
    if (currentCount != cachedMonitorCount) {
        cachedMonitorCount := currentCount
        RefreshMonitorInfo()
        return true
    }
    return false
}
```

### 6.3 Monitor Configuration Changes During Runtime

**Events that trigger changes:**
1. Monitor connected/disconnected
2. Resolution changed
3. Display scaling changed
4. Monitor rearranged in settings
5. Primary monitor changed

**Comprehensive Solution:**
```autohotkey
class MonitorManager {
    static monitors := []
    static lastRefresh := 0
    static refreshInterval := 5000  ; ms
    
    static Init() {
        this.Refresh()
        OnMessage(0x007E, (*) => this.Refresh())  ; WM_DISPLAYCHANGE
    }
    
    static Refresh() {
        this.monitors := []
        
        Loop MonitorGetCount() {
            this.monitors.Push(MonitorInfo(A_Index))
        }
        
        this.lastRefresh := A_TickCount
    }
    
    static GetMonitorAt(x, y) {
        ; Ensure fresh data
        if (A_TickCount - this.lastRefresh > this.refreshInterval) {
            this.Refresh()
        }
        
        monNum := MonitorFromPoint(x, y, "Nearest")
        for mon in this.monitors {
            if (mon.Number = monNum) {
                return mon
            }
        }
        return this.monitors[1]  ; Fallback to first
    }
    
    static GetAllTaskbars() {
        taskbars := []
        
        ; Primary taskbar
        primary := WinExist("ahk_class Shell_TrayWnd")
        if (primary) {
            taskbars.Push({Hwnd: primary, MonitorNum: MonitorGetPrimary()})
        }
        
        ; Secondary taskbars
        DetectHiddenWindows(true)
        WinGetPos(&x, &y, &w, &h, "ahk_class Shell_SecondaryTrayWnd")
        ; ... map to monitors
        DetectHiddenWindows(false)
        
        return taskbars
    }
}
```

### 6.4 Monitors With No Taskbar (Auto-hidden)

**Detection:**
```autohotkey
; When taskbar is auto-hidden, WorkArea equals full area
IsTaskbarAutoHidden(mon) {
    return (mon.WorkBottom = mon.Bottom && 
            mon.WorkTop = mon.Top &&
            mon.WorkLeft = mon.Left &&
            mon.WorkRight = mon.Right)
}
```

**Handling Auto-hidden Taskbars:**
```autohotkey
; For auto-hidden taskbars, the taskbar appears when mouse hits edge
; We need to detect this differently

GetTaskbarInfoWithAutoHide(mon) {
    if (IsTaskbarAutoHidden(mon)) {
        ; Query the actual taskbar window size
        if (mon.IsPrimary) {
            hwnd := WinExist("ahk_class Shell_TrayWnd")
        } else {
            hwnd := WinExist("ahk_class Shell_SecondaryTrayWnd")
        }
        
        if (hwnd) {
            WinGetPos(,, &width, &height, "ahk_id " hwnd)
            ; Determine position by comparing to monitor bounds
            ; ... position determination logic
        }
    }
}
```

### 6.5 Taskbar on Different Edges Per Monitor

**Scenario:** Primary monitor has taskbar on bottom, secondary on left.

**Solution:** Store and check per-monitor taskbar position:

```autohotkey
GetTaskbarEdgeForMonitor(mon) {
    ; Work area tells us where the taskbar is
    if (mon.WorkBottom < mon.Bottom)
        return "Bottom"
    if (mon.WorkTop > mon.Top)
        return "Top"  
    if (mon.WorkLeft > mon.Left)
        return "Left"
    if (mon.WorkRight < mon.Right)
        return "Right"
    return "None"
}
```

---

## 7. Proposed Implementation for BetterStartHide

### 7.1 Multi-Monitor Monitor Class

```autohotkey
; ============================================================
; MULTI-MONITOR SUPPORT
; ============================================================

class MultiMonitorManager {
    static monitors := Map()
    static taskbars := Map()
    static lastRefresh := 0
    
    ; Initialize on script start
    static Init() {
        this.Refresh()
        
        ; Listen for display changes
        OnMessage(0x007E, (w, l, m, h) => this.OnDisplayChange())
    }
    
    static OnDisplayChange() {
        this.Refresh()
    }
    
    static Refresh() {
        this.monitors := Map()
        this.taskbars := Map()
        
        ; Enumerate all monitors
        Loop MonitorGetCount() {
            monNum := A_Index
            
            ; Get full bounds
            MonitorGet(monNum, &L, &T, &R, &B)
            
            ; Get work area
            MonitorGetWorkArea(monNum, &WL, &WT, &WR, &WB)
            
            ; Build monitor info
            this.monitors[monNum] := {
                Number: monNum,
                Left: L, Top: T, Right: R, Bottom: B,
                Width: R - L, Height: B - T,
                WorkLeft: WL, WorkTop: WT, WorkRight: WR, WorkBottom: WB,
                IsPrimary: (monNum = MonitorGetPrimary())
            }
            
            ; Calculate taskbar info for this monitor
            this.CalculateTaskbarInfo(monNum)
        }
        
        ; Find all taskbar windows
        this.FindAllTaskbars()
        
        this.lastRefresh := A_TickCount
    }
    
    static CalculateTaskbarInfo(monNum) {
        mon := this.monitors[monNum]
        
        ; Determine taskbar position by comparing work area to full area
        if (mon.WorkBottom < mon.Bottom) {
            mon.TaskbarPosition := "Bottom"
            mon.TaskbarSize := mon.Bottom - mon.WorkBottom
            mon.TaskbarEdge := mon.WorkBottom  ; Y coordinate of taskbar top
        } else if (mon.WorkTop > mon.Top) {
            mon.TaskbarPosition := "Top"
            mon.TaskbarSize := mon.WorkTop - mon.Top
            mon.TaskbarEdge := mon.WorkTop  ; Y coordinate of taskbar bottom
        } else if (mon.WorkLeft > mon.Left) {
            mon.TaskbarPosition := "Left"
            mon.TaskbarSize := mon.WorkLeft - mon.Left
            mon.TaskbarEdge := mon.WorkLeft  ; X coordinate of taskbar right
        } else if (mon.WorkRight < mon.Right) {
            mon.TaskbarPosition := "Right"
            mon.TaskbarSize := mon.Right - mon.WorkRight
            mon.TaskbarEdge := mon.WorkRight  ; X coordinate of taskbar left
        } else {
            mon.TaskbarPosition := "None"
            mon.TaskbarSize := 0
            mon.TaskbarEdge := -1
        }
    }
    
    static FindAllTaskbars() {
        ; Primary taskbar
        primaryHwnd := WinExist("ahk_class Shell_TrayWnd")
        if (primaryHwnd) {
            primaryMon := MonitorGetPrimary()
            this.taskbars[primaryMon] := primaryHwnd
        }
        
        ; Secondary taskbars
        DetectHiddenWindows(true)
        
        try {
            Loop {
                ; Find each secondary taskbar
                static secondaryTaskbars := WinGetList("ahk_class Shell_SecondaryTrayWnd")
                for hwnd in secondaryTaskbars {
                    ; Determine which monitor this taskbar is on
                    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
                    monNum := this.GetMonitorFromRect(x, y, x+w, y+h)
                    if (monNum) {
                        this.taskbars[monNum] := hwnd
                    }
                }
            }
        }
        
        DetectHiddenWindows(false)
    }
    
    static GetMonitorFromRect(x1, y1, x2, y2) {
        ; Find which monitor contains most of this rectangle
        for monNum, mon in this.monitors {
            ; Check if rect bottom matches monitor bottom (bottom taskbar)
            if (Abs(y2 - mon.Bottom) < 10 && x1 >= mon.Left && x2 <= mon.Right) {
                return monNum
            }
            ; Check other edges similarly...
        }
        return 0
    }
    
    static GetMonitorAt(x, y) {
        monNum := MonitorFromPoint(x, y, "Nearest")
        return this.monitors.Has(monNum) ? this.monitors[monNum] : this.monitors[1]
    }
    
    static GetTaskbarForMonitor(monNum) {
        return this.taskbars.Get(monNum, 0)
    }
    
    static GetCurrentMonitor() {
        MouseGetPos(&x, &y)
        return this.GetMonitorAt(x, y)
    }
    
    static IsNearTaskbar(x, y, threshold := 10) {
        mon := this.GetMonitorAt(x, y)
        
        switch mon.TaskbarPosition {
            case "Bottom":
                return (y >= mon.TaskbarEdge - threshold && y <= mon.Bottom)
            case "Top":
                return (y >= mon.Top && y <= mon.TaskbarEdge + threshold)
            case "Left":
                return (x >= mon.Left && x <= mon.TaskbarEdge + threshold)
            case "Right":
                return (x >= mon.TaskbarEdge - threshold && x <= mon.Right)
            default:
                return false
        }
    }
    
    static DistanceToTaskbar(x, y) {
        mon := this.GetMonitorAt(x, y)
        
        switch mon.TaskbarPosition {
            case "Bottom":
                return mon.TaskbarEdge - y
            case "Top":
                return y - mon.TaskbarEdge
            case "Left":
                return x - mon.TaskbarEdge
            case "Right":
                return mon.TaskbarEdge - x
            default:
                return 9999
        }
    }
    
    static IsMouseOverTaskbar(x, y) {
        mon := this.GetMonitorAt(x, y)
        
        switch mon.TaskbarPosition {
            case "Bottom":
                return (y >= mon.TaskbarEdge && y <= mon.Bottom)
            case "Top":
                return (y >= mon.Top && y <= mon.TaskbarEdge)
            case "Left":
                return (x >= mon.Left && x <= mon.TaskbarEdge)
            case "Right":
                return (x >= mon.TaskbarEdge && x <= mon.Right)
            default:
                return false
        }
    }
}
```

### 7.2 Updated MonitorMouse Function

```autohotkey
MonitorMouse() {
    global LastX, LastY, LastTime
    global TriggerPixels, MinVelocity, EdgeThreshold
    global IsRevealed, LastRevealTime, HideDelay
    global GradualFade, FadeDistance, CurrentOpacity
    global DimmedOpacity, BrightOpacity
    
    ; Refresh monitor info periodically
    static lastRefresh := 0
    if (A_TickCount - lastRefresh > 5000) {
        MultiMonitorManager.Refresh()
        lastRefresh := A_TickCount
    }
    
    MouseGetPos(&currentX, &currentY)
    currentTime := A_TickCount
    
    ; Get current monitor info
    currentMon := MultiMonitorManager.GetMonitorAt(currentX, currentY)
    taskbarHwnd := MultiMonitorManager.GetTaskbarForMonitor(currentMon.Number)
    
    ; Calculate distance from taskbar using per-monitor info
    distanceFromTaskbar := MultiMonitorManager.DistanceToTaskbar(currentX, currentY)
    isOverTaskbar := MultiMonitorManager.IsMouseOverTaskbar(currentX, currentY)
    
    ; Check if mouse is over taskbar
    if (isOverTaskbar) {
        if (!IsRevealed || CurrentOpacity != BrightOpacity) {
            SetTaskbarOpacityForMonitor(currentMon.Number, BrightOpacity)
            IsRevealed := true
        }
        LastRevealTime := currentTime
        ; Update position and return...
        return
    }
    
    ; Rest of logic using per-monitor taskbar info...
    ; (Similar to original but using MultiMonitorManager methods)
}
```

### 7.3 Per-Monitor Opacity Control

```autohotkey
SetTaskbarOpacityForMonitor(monNum, opacity) {
    global CurrentOpacities
    
    ; Initialize map if needed
    if (!IsObject(CurrentOpacities)) {
        CurrentOpacities := Map()
    }
    
    CurrentOpacities[monNum] := opacity
    
    ; Get the taskbar handle for this monitor
    hwnd := MultiMonitorManager.GetTaskbarForMonitor(monNum)
    
    if (hwnd) {
        WinSetTransparent(opacity, "ahk_id " hwnd)
    }
}
```

---

## 8. Testing Scenarios

### 8.1 Test Matrix

| Scenario | Test Method | Expected Behavior |
|----------|-------------|-------------------|
| Single monitor | Basic usage | Works as before |
| Dual horizontal | Left + Right monitors | Each taskbar dims/reveals independently |
| Dual vertical | Stacked monitors | Each taskbar dims/reveals independently |
| Triple monitor | 3 horizontal | All 3 taskbars work |
| Mixed DPI | 1080p + 4K | Coordinates scale correctly |
| Primary change | Swap primary in settings | Refreshes correctly |
| Disconnect | Unplug monitor | Remaining monitors work |
| Reconnect | Plug monitor back | Detected and works |
| Taskbar moved | Move taskbar to top | Reveals from top edge |
| Auto-hide | Enable auto-hide | Works or gracefully degrades |

### 8.2 Debug Helpers

```autohotkey
; Debug function to show all monitor info
DebugMonitors() {
    text := ""
    Loop MonitorGetCount() {
        mon := MultiMonitorManager.monitors[A_Index]
        text .= "Monitor " A_Index ":`n"
        text .= "  Position: (" mon.Left "," mon.Top ") to (" mon.Right "," mon.Bottom ")`n"
        text .= "  Size: " mon.Width "x" mon.Height "`n"
        text .= "  Taskbar: " mon.TaskbarPosition " (" mon.TaskbarSize "px)`n"
        text .= "  Primary: " (mon.IsPrimary ? "Yes" : "No") "`n`n"
    }
    MsgBox(text, "Monitor Debug Info")
}
```

---

## 9. Summary of Changes Required

### Files to Modify:
1. `BetterStartHide.ahk` - Main script

### Changes Required:

1. **Replace `A_ScreenHeight`** with per-monitor dimensions from `MonitorGet()`

2. **Add MultiMonitorManager class** to:
   - Track all monitors
   - Find all taskbars (primary + secondary)
   - Provide per-monitor taskbar info

3. **Update `MonitorMouse()`** to:
   - Determine current monitor from mouse position
   - Use that monitor's taskbar dimensions
   - Support taskbars on any edge

4. **Update `SetTaskbarOpacity()`** to:
   - Target specific taskbar by monitor number
   - Handle multiple taskbar windows

5. **Add display change detection** via `OnMessage(0x007E)`

6. **Test on various multi-monitor configurations**

---

## 10. References

- [AutoHotkey v2 Documentation - Monitor Functions](https://www.autohotkey.com/docs/v2/lib/Monitor.htm)
- [AutoHotkey v2 Documentation - SysGet](https://www.autohotkey.com/docs/v2/lib/SysGet.htm)
- [Windows Display Settings API](https://docs.microsoft.com/en-us/windows/win32/gdi/multiple-display-monitors-functions)