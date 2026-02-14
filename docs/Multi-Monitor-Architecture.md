# Multi-Monitor Architecture Design Document

## BetterStartHide - Architecture Agent Deliverable

**Version:** 1.0  
**Date:** February 14, 2026  
**Author:** Architecture Agent

---

## 1. Executive Summary

This document defines the architecture for adding multi-monitor support to BetterStartHide. The design introduces a `MonitorManager` class that abstracts all monitor and taskbar detection, allowing the existing `MonitorMouse()` logic to work seamlessly across multiple monitors with minimal changes.

---

## 2. Current Implementation Analysis

### 2.1 Single-Monitor Assumptions

The current code has several assumptions that need to be addressed:

| Code Element | Current Behavior | Issue |
|--------------|------------------|-------|
| `A_ScreenHeight` | Primary monitor height only | Incorrect for multi-monitor |
| `TaskbarHwnd` | Single `Shell_TrayWnd` | Ignores secondary taskbars |
| `TaskbarHeight` | Single value | Each monitor may have different taskbar size |
| `MonitorMouse()` | Assumes bottom taskbar at `ScreenHeight` | Taskbars can be on any edge |
| `SetTaskbarOpacity()` | Single taskbar target | Needs per-monitor control |

### 2.2 Data Flow (Current)

```
┌─────────────────────────────────────────────────────────────┐
│                    Timer: MonitorMouse()                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  MouseGetPos() → Calculate distance from A_ScreenHeight     │
│  Single TaskbarHwnd → Single opacity state                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              SetTaskbarOpacity(opacity)                     │
│              WinSetTransparent on Shell_TrayWnd             │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Proposed Architecture

### 3.1 Component Overview

```
┌────────────────────────────────────────────────────────────────────────┐
│                           BetterStartHide.ahk                          │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    MonitorManager (NEW)                          │   │
│  │  ┌─────────────┐  ┌──────────────┐  ┌───────────────────────┐   │   │
│  │  │ MonitorInfo │  │ TaskbarInfo  │  │ DisplayChangeHandler  │   │   │
│  │  │   (class)   │  │   (class)    │  │      (OnMessage)      │   │   │
│  │  └─────────────┘  └──────────────┘  └───────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                   │                                    │
│                                   ▼                                    │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    Core Application Logic                        │   │
│  │  ┌───────────────┐  ┌────────────────┐  ┌──────────────────┐    │   │
│  │  │ MonitorMouse() │  │ Settings/Gui   │  │ Tray Menu/Init   │    │   │
│  │  │  (modified)    │  │  (unchanged)   │  │  (minor changes) │    │   │
│  │  └───────────────┘  └────────────────┘  └──────────────────┘    │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Class Structure

#### 3.2.1 MonitorInfo Class

Holds all information about a single monitor and its associated taskbar.

```autohotkey
class MonitorInfo {
    ; Identity
    Number          ; Integer - 1-based monitor number
    Name            ; String  - Display name from MonitorGetName()
    IsPrimary       ; Boolean - True if this is the primary monitor
    
    ; Full monitor bounds (includes taskbar area)
    Left            ; Integer
    Top             ; Integer
    Right           ; Integer
    Bottom          ; Integer
    Width           ; Integer (calculated)
    Height          ; Integer (calculated)
    
    ; Work area bounds (excludes taskbar)
    WorkLeft        ; Integer
    WorkTop         ; Integer
    WorkRight       ; Integer
    WorkBottom      ; Integer
    WorkWidth       ; Integer (calculated)
    WorkHeight      ; Integer (calculated)
    
    ; Taskbar information (derived from WorkArea vs FullArea)
    TaskbarPosition ; String  - "Top", "Bottom", "Left", "Right", or "None"
    TaskbarSize     ; Integer - Thickness in pixels
    TaskbarEdge     ; Integer - Coordinate of the inner edge of taskbar
    
    ; Taskbar window handle
    TaskbarHwnd     ; Integer - Window handle or 0 if not found
    
    ; Methods
    __New(monitorNum)
    CalculateTaskbarInfo()
    ContainsPoint(x, y)
    DistanceToTaskbar(x, y)
    IsPointOverTaskbar(x, y)
}
```

**Rationale:** Encapsulating all monitor data in a class allows easy access and ensures data consistency. The class calculates derived values (like taskbar position) once during construction.

#### 3.2.2 MonitorManager Class

Static class that manages all monitors and provides the primary API for the application.

```autohotkey
class MonitorManager {
    ; Static data storage
    static monitors     ; Map<monitorNum, MonitorInfo>
    static lastRefresh  ; Integer - A_TickCount of last refresh
    
    ; Configuration
    static refreshInterval := 5000  ; ms - Periodic refresh interval
    
    ; Public Methods
    static Init()                    ; Initialize on script start
    static Refresh()                 ; Rebuild all monitor info
    static GetMonitorAt(x, y)        ; Returns MonitorInfo for point
    static GetCurrentMonitor()       ; Returns MonitorInfo for mouse position
    static GetAllMonitors()          ; Returns array of all MonitorInfo
    static GetMonitorCount()         ; Returns integer count
    
    ; Internal Methods
    static OnDisplayChange()         ; Handler for WM_DISPLAYCHANGE
    static FindAllTaskbars()         ; Detect Shell_TrayWnd and Shell_SecondaryTrayWnd
    static MapTaskbarToMonitor(hwnd) ; Determine which monitor a taskbar belongs to
}
```

**Rationale:** Using a static class (rather than a global object) provides:
- Clear namespace for all monitor-related functionality
- No need to pass manager instance around
- Single point of initialization and refresh
- Easy access from anywhere in the code

---

## 4. Data Flow (Proposed)

### 4.1 Initialization Flow

```
Script Start
     │
     ▼
CoordMode("Mouse", "Screen")
     │
     ▼
LoadSettings()
     │
     ▼
MonitorManager.Init()  ◄─────────────────────────────────┐
     │                                                  │
     ├──► MonitorManager.Refresh()                      │
     │         │                                        │
     │         ├──► Loop MonitorGetCount()              │
     │         │         │                              │
     │         │         └──► Create MonitorInfo(n)     │
     │         │                   │                    │
     │         │                   ├──► MonitorGet()    │
     │         │                   ├──► MonitorGetWorkArea()
     │         │                   └──► CalculateTaskbarInfo()
     │         │                                        │
     │         └──► FindAllTaskbars()                   │
     │                   │                              │
     │                   ├──► WinExist("Shell_TrayWnd")
     │                   └──► WinGetList("Shell_SecondaryTrayWnd")
     │                                                  │
     ▼                                                  │
SetTimer(MonitorMouse, CheckInterval)                   │
     │                                                  │
     ▼                                                  │
OnMessage(0x007E, MonitorManager.OnDisplayChange) ──────┘
                                      (triggers Refresh)
```

### 4.2 Runtime Flow (MonitorMouse)

```
Timer: MonitorMouse()
     │
     ▼
MouseGetPos(&x, &y)
     │
     ▼
MonitorManager.GetMonitorAt(x, y)
     │
     ├──► MonitorFromPoint(x, y) → monitorNum
     │
     └──► Return monitors[monitorNum]
     │
     ▼
mon := Current MonitorInfo
     │
     ├──► mon.TaskbarPosition ("Bottom", "Top", etc.)
     ├──► mon.TaskbarEdge (coordinate)
     ├──► mon.TaskbarHwnd
     └──► mon.DistanceToTaskbar(x, y)
     │
     ▼
Calculate opacity based on distance and velocity
     │
     ▼
SetTaskbarOpacity(mon.TaskbarHwnd, opacity)
```

---

## 5. Caching and Refresh Strategy

### 5.1 Caching Approach

The `MonitorManager` caches all monitor information to avoid repeated API calls during the high-frequency `MonitorMouse()` timer (every 10ms by default).

**Cached Data:**
- All monitor bounds and work areas
- All taskbar positions and sizes
- All taskbar window handles

### 5.2 Refresh Triggers

| Trigger | Method | Priority |
|---------|--------|----------|
| WM_DISPLAYCHANGE (0x007E) | `OnDisplayChange()` | Immediate |
| Periodic check (every 5s) | `Refresh()` if interval exceeded | Low |
| Manual call | `Refresh()` | On-demand |

### 5.3 Refresh Implementation

```autohotkey
static Refresh() {
    this.monitors := Map()
    
    ; Build monitor info for all monitors
    Loop MonitorGetCount() {
        mon := MonitorInfo(A_Index)
        this.monitors[A_Index] := mon
    }
    
    ; Find and map all taskbars
    this.FindAllTaskbars()
    
    this.lastRefresh := A_TickCount
}

static OnDisplayChange(wParam, lParam, msg, hwnd) {
    ; WM_DISPLAYCHANGE received - refresh immediately
    MonitorManager.Refresh()
    return 0
}
```

### 5.4 Lazy Refresh Check

```autohotkey
static GetMonitorAt(x, y) {
    ; Check if refresh is needed (lazy refresh)
    if (A_TickCount - this.lastRefresh > this.refreshInterval) {
        this.Refresh()
    }
    
    monNum := MonitorFromPoint(x, y, "Nearest")
    return this.monitors.Get(monNum, this.monitors[1])
}
```

---

## 6. Integration Points

### 6.1 Changes to Global Variables

**Remove:**
```autohotkey
global ScreenHeight := A_ScreenHeight  ; REMOVE
global TaskbarHwnd := 0                ; REMOVE (moved to MonitorInfo)
global TaskbarHeight := 48             ; REMOVE (moved to MonitorInfo)
```

**Add:**
```autohotkey
; None - MonitorManager handles all monitor state
```

**Keep Unchanged:**
```autohotkey
global LastX, LastY, LastTime
global IsRevealed, LastRevealTime, CurrentOpacity
global DimmedOpacity, BrightOpacity, TriggerPixels, MinVelocity
global CheckInterval, EdgeThreshold, HideDelay, GradualFade, FadeDistance
```

### 6.2 Changes to Initialization

```autohotkey
; BEFORE:
TaskbarHwnd := WinExist("ahk_class Shell_TrayWnd")
UpdateTaskbarInfo()

; AFTER:
MonitorManager.Init()  ; Handles all initialization
```

### 6.3 Changes to MonitorMouse()

**Key Changes:**

1. **Replace `A_ScreenHeight`** with per-monitor bounds
2. **Replace single `TaskbarHwnd`** with per-monitor handle from `MonitorInfo`
3. **Replace fixed bottom-edge logic** with edge-aware logic based on `TaskbarPosition`

**Before (simplified):**
```autohotkey
distanceFromBottom := ScreenHeight - currentY
taskbarTop := ScreenHeight - TaskbarHeight
distanceFromTaskbarTop := taskbarTop - currentY
```

**After (simplified):**
```autohotkey
mon := MonitorManager.GetMonitorAt(currentX, currentY)
distanceFromTaskbar := mon.DistanceToTaskbar(currentX, currentY)
isOverTaskbar := mon.IsPointOverTaskbar(currentX, currentY)
```

### 6.4 Changes to SetTaskbarOpacity()

**Before:**
```autohotkey
SetTaskbarOpacity(opacity) {
    global TaskbarHwnd, CurrentOpacity
    ; ... always targets TaskbarHwnd (primary only)
}
```

**After:**
```autohotkey
SetTaskbarOpacity(hwnd, opacity) {
    ; hwnd is passed as parameter
    ; Handles both primary and secondary taskbars
    WinSetTransparent(opacity, "ahk_id " hwnd)
}

; Or overload for convenience:
SetTaskbarOpacityForMonitor(monNum, opacity) {
    mon := MonitorManager.monitors[monNum]
    if (mon && mon.TaskbarHwnd) {
        SetTaskbarOpacity(mon.TaskbarHwnd, opacity)
    }
}
```

### 6.5 Changes to RefreshTaskbarOpacity()

```autohotkey
RefreshTaskbarOpacity() {
    ; Re-apply current opacity to ALL taskbars
    for monNum, mon in MonitorManager.monitors {
        if (mon.TaskbarHwnd) {
            WinSetTransparent(CurrentOpacity, "ahk_id " mon.TaskbarHwnd)
        }
    }
}
```

---

## 7. Taskbar Detection Details

### 7.1 Primary Taskbar

```autohotkey
; Always Shell_TrayWnd class
primaryHwnd := WinExist("ahk_class Shell_TrayWnd")
```

### 7.2 Secondary Taskbars

```autohotkey
; Shell_SecondaryTrayWnd class (Windows 10+)
DetectHiddenWindows(true)
secondaryList := WinGetList("ahk_class Shell_SecondaryTrayWnd")
DetectHiddenWindows(false)
```

### 7.3 Mapping Taskbar to Monitor

Secondary taskbars must be mapped to their monitors by position:

```autohotkey
MapTaskbarToMonitor(hwnd) {
    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    
    ; Check each monitor to see which contains this taskbar
    for monNum, mon in this.monitors {
        ; For bottom taskbar: matches if at monitor bottom
        if (Abs((y + h) - mon.Bottom) < 10 && x >= mon.Left && (x + w) <= mon.Right) {
            return monNum
        }
        ; Similar checks for Top, Left, Right positions
    }
    return 0
}
```

---

## 8. Edge-Aware Distance Calculation

### 8.1 MonitorInfo.DistanceToTaskbar()

```autohotkey
DistanceToTaskbar(x, y) {
    switch this.TaskbarPosition {
        case "Bottom":
            ; Positive = above taskbar, Negative = over taskbar
            return this.TaskbarEdge - y
        case "Top":
            ; Positive = below taskbar, Negative = over taskbar
            return y - this.TaskbarEdge
        case "Left":
            ; Positive = right of taskbar, Negative = over taskbar
            return x - this.TaskbarEdge
        case "Right":
            ; Positive = left of taskbar, Negative = over taskbar
            return this.TaskbarEdge - x
        default:
            return 9999  ; No taskbar
    }
}
```

### 8.2 MonitorInfo.IsPointOverTaskbar()

```autohotkey
IsPointOverTaskbar(x, y) {
    if (!this.ContainsPoint(x, y)) {
        return false
    }
    
    switch this.TaskbarPosition {
        case "Bottom":
            return y >= this.TaskbarEdge
        case "Top":
            return y <= this.TaskbarEdge
        case "Left":
            return x <= this.TaskbarEdge
        case "Right":
            return x >= this.TaskbarEdge
        default:
            return false
    }
}
```

---

## 9. Design Decisions and Rationale

### 9.1 Static Class vs Global Object

**Decision:** Use static class (`MonitorManager`) instead of global object.

**Rationale:**
- Clearer namespace organization
- No initialization order issues
- Methods callable without instance
- AutoHotkey v2 idiom for singleton-like patterns

### 9.2 Per-Monitor State Tracking

**Decision:** Track `IsRevealed` and `CurrentOpacity` globally, not per-monitor.

**Rationale:**
- Simplifies state management
- User interacts with one taskbar at a time
- All taskbars dim/reveal together (consistent UX)
- Can be extended to per-monitor tracking in future if needed

**Future Option:**
```autohotkey
; Per-monitor opacity (not in initial implementation)
global CurrentOpacities := Map()  ; monNum -> opacity
```

### 9.3 Immediate Refresh on Display Change

**Decision:** Refresh immediately on `WM_DISPLAYCHANGE` message.

**Rationale:**
- Ensures immediate response to monitor connect/disconnect
- Prevents stale data when user changes display settings
- Low overhead (refresh is fast)

### 9.4 Periodic Refresh as Fallback

**Decision:** Also refresh every 5 seconds as a safety net.

**Rationale:**
- `WM_DISPLAYCHANGE` may not fire in all edge cases
- Catches any missed display changes
- Minimal performance impact (only when `GetMonitorAt` is called)

### 9.5 Velocity-Based Reveal Preserved

**Decision:** Keep existing velocity-based reveal logic.

**Rationale:**
- Core feature of BetterStartHide
- Works independently of monitor count
- Only the coordinate calculations change

### 9.6 Gradual Fade Per Monitor

**Decision:** Calculate gradual fade based on current monitor's taskbar distance.

**Rationale:**
- Natural extension of existing gradual fade
- Works seamlessly as mouse moves between monitors
- Each monitor's taskbar fades independently based on mouse proximity

---

## 10. Risk Assessment

### 10.1 Identified Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Secondary taskbar not found | Medium | Medium | Fall back to work-area detection; log warning |
| DPI scaling issues | Low | Medium | AHK v2 handles DPI; use virtualized coordinates |
| Auto-hidden taskbars | Medium | Low | Detect via work area equality; show warning |
| Monitor during disconnect | Low | High | Validate hwnd with `IsWindow()` before use |
| Performance degradation | Low | Medium | Profile; cache aggressively; minimize refreshes |

### 10.2 Backward Compatibility

The architecture maintains full backward compatibility:
- Single-monitor setups work exactly as before
- Existing settings file format unchanged
- No changes to user-facing behavior on single monitor

---

## 11. Implementation Phases

### Phase 1: Core Infrastructure
- Implement `MonitorInfo` class
- Implement `MonitorManager` class with basic Refresh/Init
- Add display change handler

### Phase 2: Integration
- Update global variable initialization
- Modify `MonitorMouse()` to use `MonitorManager`
- Modify `SetTaskbarOpacity()` for hwnd parameter

### Phase 3: Edge Cases
- Handle all four taskbar positions
- Handle auto-hidden taskbars
- Handle monitor disconnect/reconnect

### Phase 4: Testing & Polish
- Test on various multi-monitor configs
- Add debug logging
- Performance optimization

---

## 12. API Reference (For Implementation Agent)

### 12.1 MonitorManager.Init()
```
Description: Initialize the monitor manager. Call once at script start.
Parameters: None
Returns: None
Side Effects: 
  - Populates MonitorManager.monitors
  - Registers WM_DISPLAYCHANGE handler
```

### 12.2 MonitorManager.Refresh()
```
Description: Rebuild all monitor and taskbar information.
Parameters: None
Returns: None
Side Effects: Updates MonitorManager.monitors Map
```

### 12.3 MonitorManager.GetMonitorAt(x, y)
```
Description: Get monitor info for a screen coordinate.
Parameters:
  x - Integer, X coordinate
  y - Integer, Y coordinate
Returns: MonitorInfo object for the monitor containing (x, y)
         Falls back to first monitor if not found
```

### 12.4 MonitorManager.GetCurrentMonitor()
```
Description: Get monitor info for current mouse position.
Parameters: None
Returns: MonitorInfo object
```

### 12.5 MonitorInfo.DistanceToTaskbar(x, y)
```
Description: Calculate distance from point to taskbar edge.
Parameters:
  x - Integer, X coordinate
  y - Integer, Y coordinate
Returns: Integer distance (positive = away from taskbar, negative = over taskbar)
```

### 12.6 MonitorInfo.IsPointOverTaskbar(x, y)
```
Description: Check if point is within taskbar bounds.
Parameters:
  x - Integer, X coordinate
  y - Integer, Y coordinate
Returns: Boolean
```

---

## 13. Collaboration Notes

### For Implementation Agent:
- Start with `MonitorInfo` class, then `MonitorManager`
- Modify `MonitorMouse()` incrementally, testing after each change
- Use the debug helper from the research doc: `DebugMonitors()`

### For Testing Agent:
- Test matrix provided in research document section 8.1
- Key scenarios: dual horizontal, dual vertical, triple, mixed DPI
- Verify no regression on single-monitor setups

### For Edge Cases Agent:
- Focus on sections 6.4 (auto-hidden taskbars) and 6.5 (different edges)
- Handle monitor disconnect gracefully
- Consider taskbar moved to different edge at runtime

---

## 14. Conclusion

This architecture provides a clean, maintainable approach to multi-monitor support by:

1. **Encapsulating** all monitor/taskbar complexity in dedicated classes
2. **Minimizing** changes to existing application logic
3. **Caching** aggressively for performance
4. **Refreshing** intelligently on display changes
5. **Supporting** all taskbar positions and monitor configurations

The design is ready for implementation by the Implementation Agent, with clear integration points and API definitions provided.

---

*End of Architecture Document*