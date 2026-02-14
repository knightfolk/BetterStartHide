#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================================
; BetterStartHide - Smart Taskbar Dim & Reveal
; ============================================================================
; Dims the taskbar to near-invisibility and reveals it on mouse proximity
; or fast mouse movement toward the bottom edge.
; Supports multi-monitor configurations.
; ============================================================================

; ============================================================================
; DEFAULT CONFIGURATION (overridden by Settings.ini if present)
; ============================================================================
global DimmedOpacity := 10      ; Opacity when dimmed (0-255, 10 = ~4% visible)
global BrightOpacity := 255     ; Opacity when revealed (255 = fully visible)
global TriggerPixels := 10      ; Pixels from taskbar top edge to trigger reveal
global MinVelocity := 400       ; Mouse speed threshold for reveal (reduced by 50%)
global CheckInterval := 10      ; Mouse check interval in ms
global EdgeThreshold := 5       ; Pixels from bottom to always trigger
global HideDelay := 500         ; ms to wait before hiding again
global GradualFade := true      ; Enable gradual fade on approach
global FadeDistance := 100      ; Pixels over which to fade in

; ============================================================================
; GLOBAL VARIABLES
; ============================================================================
global LastX := 0
global LastY := 0
global LastTime := 0
global IsRevealed := false
global LastRevealTime := 0
global CurrentOpacity := 255
global SettingsGui := 0
global SettingsPath := A_ScriptDir "\Settings.ini"

; ============================================================================
; MULTI-MONITOR SUPPORT CLASSES
; ============================================================================

; Helper function to find which monitor contains a point (avoids scope issues with built-in)
GetMonitorFromPoint(x, y) {
    ; Iterate through all monitors to find which contains the point
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &L, &T, &R, &B)
        if (x >= L && x <= R && y >= T && y <= B) {
            return A_Index
        }
    }
    ; If not found, return primary monitor
    return MonitorGetPrimary()
}

; -----------------------------------------------------------------------------
; MonitorInfo Class - Holds all information about a single monitor
; -----------------------------------------------------------------------------
class MonitorInfo {
    __New(monitorNum) {
        ; Identity
        this.Number := monitorNum
        this.Name := MonitorGetName(monitorNum)
        this.IsPrimary := (monitorNum = MonitorGetPrimary())
        
        ; Get full monitor bounds
        MonitorGet(monitorNum, &L, &T, &R, &B)
        this.Left := L
        this.Top := T
        this.Right := R
        this.Bottom := B
        this.Width := R - L
        this.Height := B - T
        
        ; Get work area (excludes taskbar)
        MonitorGetWorkArea(monitorNum, &WL, &WT, &WR, &WB)
        this.WorkLeft := WL
        this.WorkTop := WT
        this.WorkRight := WR
        this.WorkBottom := WB
        this.WorkWidth := WR - WL
        this.WorkHeight := WB - WT
        
        ; Taskbar information (derived from WorkArea vs FullArea)
        this.TaskbarPosition := "None"
        this.TaskbarSize := 0
        this.TaskbarEdge := -1
        this.TaskbarHwnd := 0
        
        ; Calculate taskbar info
        this.CalculateTaskbarInfo()
    }
    
    CalculateTaskbarInfo() {
        ; Determine taskbar position by comparing work area to full area
        if (this.WorkBottom < this.Bottom) {
            this.TaskbarPosition := "Bottom"
            this.TaskbarSize := this.Bottom - this.WorkBottom
            this.TaskbarEdge := this.WorkBottom  ; Y coordinate of taskbar top
        } else if (this.WorkTop > this.Top) {
            this.TaskbarPosition := "Top"
            this.TaskbarSize := this.WorkTop - this.Top
            this.TaskbarEdge := this.WorkTop  ; Y coordinate of taskbar bottom
        } else if (this.WorkLeft > this.Left) {
            this.TaskbarPosition := "Left"
            this.TaskbarSize := this.WorkLeft - this.Left
            this.TaskbarEdge := this.WorkLeft  ; X coordinate of taskbar right
        } else if (this.WorkRight < this.Right) {
            this.TaskbarPosition := "Right"
            this.TaskbarSize := this.Right - this.WorkRight
            this.TaskbarEdge := this.WorkRight  ; X coordinate of taskbar left
        } else {
            this.TaskbarPosition := "None"
            this.TaskbarSize := 0
            this.TaskbarEdge := -1
        }
    }
    
    ContainsPoint(x, y) {
        return (x >= this.Left && x <= this.Right && 
                y >= this.Top && y <= this.Bottom)
    }
    
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
                return 9999  ; No taskbar or unknown
        }
    }
    
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
    
    ; Check if approaching taskbar (for velocity-based reveal)
    IsApproachingTaskbar(deltaX, deltaY) {
        switch this.TaskbarPosition {
            case "Bottom":
                return deltaY > 0  ; Moving down toward bottom taskbar
            case "Top":
                return deltaY < 0  ; Moving up toward top taskbar
            case "Left":
                return deltaX < 0  ; Moving left toward left taskbar
            case "Right":
                return deltaX > 0  ; Moving right toward right taskbar
            default:
                return false
        }
    }
    
    ; Get distance from the edge where taskbar is located
    GetEdgeDistance(x, y) {
        switch this.TaskbarPosition {
            case "Bottom":
                return this.Bottom - y
            case "Top":
                return y - this.Top
            case "Left":
                return x - this.Left
            case "Right":
                return this.Right - x
            default:
                return 9999
        }
    }
}

; -----------------------------------------------------------------------------
; MonitorManager Class - Manages all monitors and taskbars
; -----------------------------------------------------------------------------
class MonitorManager {
    static monitors := Map()
    static lastRefresh := 0
    static refreshInterval := 5000  ; ms - Periodic refresh interval
    
    static Init() {
        this.Refresh()
        ; Register for display change notifications (WM_DISPLAYCHANGE = 0x007E)
        OnMessage(0x007E, (w, l, m, h) => this.OnDisplayChange())
    }
    
    static OnDisplayChange() {
        this.Refresh()
        return 0
    }
    
    static Refresh() {
        this.monitors := Map()
        
        ; Build monitor info for all monitors
        Loop MonitorGetCount() {
            try {
                mon := MonitorInfo(A_Index)
                this.monitors[A_Index] := mon
            }
        }
        
        ; Find and map all taskbars
        this.FindAllTaskbars()
        
        this.lastRefresh := A_TickCount
    }
    
    static FindAllTaskbars() {
        ; Find primary taskbar (Shell_TrayWnd)
        primaryHwnd := WinExist("ahk_class Shell_TrayWnd")
        if (primaryHwnd) {
            primaryNum := MonitorGetPrimary()
            if (this.monitors.Has(primaryNum)) {
                this.monitors[primaryNum].TaskbarHwnd := primaryHwnd
            }
        }
        
        ; Find secondary taskbars (Shell_SecondaryTrayWnd) - Windows 10+
        DetectHiddenWindows(true)
        try {
            secondaryList := WinGetList("ahk_class Shell_SecondaryTrayWnd")
            for hwnd in secondaryList {
                this.MapTaskbarToMonitor(hwnd)
            }
        }
        DetectHiddenWindows(false)
    }
    
    static MapTaskbarToMonitor(hwnd) {
        try {
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            
            ; Check each monitor to see which contains this taskbar
            for monNum, mon in this.monitors {
                ; For bottom taskbar: matches if at monitor bottom
                if (Abs((y + h) - mon.Bottom) < 10 && x >= mon.Left && (x + w) <= mon.Right) {
                    mon.TaskbarHwnd := hwnd
                    return monNum
                }
                ; For top taskbar: matches if at monitor top
                if (Abs(y - mon.Top) < 10 && x >= mon.Left && (x + w) <= mon.Right) {
                    mon.TaskbarHwnd := hwnd
                    return monNum
                }
                ; For left taskbar: matches if at monitor left
                if (Abs(x - mon.Left) < 10 && y >= mon.Top && (y + h) <= mon.Bottom) {
                    mon.TaskbarHwnd := hwnd
                    return monNum
                }
                ; For right taskbar: matches if at monitor right
                if (Abs((x + w) - mon.Right) < 10 && y >= mon.Top && (y + h) <= mon.Bottom) {
                    mon.TaskbarHwnd := hwnd
                    return monNum
                }
            }
        }
        return 0
    }
    
    static GetMonitorAt(x, y) {
        ; Lazy refresh check
        if (A_TickCount - this.lastRefresh > this.refreshInterval) {
            this.Refresh()
        }
        
        ; Use module-level helper to avoid scope warning
        monNum := GetMonitorFromPoint(x, y)
        if (this.monitors.Has(monNum)) {
            return this.monitors[monNum]
        }
        ; Fallback to first monitor
        if (this.monitors.Count > 0) {
            for _, mon in this.monitors {
                return mon
            }
        }
        return ""
    }
    
    static GetCurrentMonitor() {
        MouseGetPos(&x, &y)
        return this.GetMonitorAt(x, y)
    }
    
    static GetMonitorCount() {
        return this.monitors.Count
    }
    
    static GetAllMonitors() {
        return this.monitors
    }
}

; ============================================================================
; INITIALIZATION
; ============================================================================

; Ensure mouse coordinates are always in screen mode (not relative to active window)
CoordMode("Mouse", "Screen")

; Load settings from INI file
LoadSettings()

; Set up tray menu
A_TrayMenu.Delete()
A_TrayMenu.Add("Settings", OpenSettings)
A_TrayMenu.Add("Show All Taskbars", (*) => SetAllTaskbarsOpacity(BrightOpacity))
A_TrayMenu.Add("Dim All Taskbars", (*) => SetAllTaskbarsOpacity(DimmedOpacity))
A_TrayMenu.Add()
A_TrayMenu.Add("Debug Monitors", DebugMonitors)
A_TrayMenu.Add()
A_TrayMenu.Add("Exit", ExitScript)
A_IconTip := "BetterStartHide`nSmart Taskbar Reveal (Multi-Monitor)"

; Initialize multi-monitor support
MonitorManager.Init()

; Check if we found any taskbars
anyTaskbar := false
for monNum, mon in MonitorManager.GetAllMonitors() {
    if (mon.TaskbarHwnd) {
        anyTaskbar := true
        break
    }
}

if (!anyTaskbar) {
    MsgBox("Could not find any taskbars!", "Error", 16)
    ExitApp()
}

; Get initial mouse position
MouseGetPos(&initX, &initY)
LastX := initX
LastY := initY
LastTime := A_TickCount

; Dim all taskbars initially
CurrentOpacity := BrightOpacity
SetAllTaskbarsOpacity(DimmedOpacity)

; Start monitoring
SetTimer(MonitorMouse, CheckInterval)

; Start periodic refresh to maintain opacity (Windows may reset it)
SetTimer(RefreshTaskbarOpacity, 100)

TrayTip("BetterStartHide", "Taskbar dimmed. Move mouse toward taskbar edge to reveal.`nRight-click tray icon for settings.")

; ============================================================================
; PERIODIC REFRESH
; ============================================================================

RefreshTaskbarOpacity() {
    global CurrentOpacity
    
    ; Re-apply current opacity to ALL taskbars
    for monNum, mon in MonitorManager.GetAllMonitors() {
        if (mon.TaskbarHwnd && DllCall("IsWindow", "Ptr", mon.TaskbarHwnd)) {
            WinSetTransparent(CurrentOpacity, "ahk_id " mon.TaskbarHwnd)
        }
    }
}

; ============================================================================
; SETTINGS MANAGEMENT
; ============================================================================

LoadSettings() {
    global SettingsPath
    global DimmedOpacity, BrightOpacity, TriggerPixels, MinVelocity
    global CheckInterval, EdgeThreshold, HideDelay, GradualFade, FadeDistance
    
    if (!FileExist(SettingsPath)) {
        return
    }
    
    try {
        ; Ensure all values are properly typed
        DimmedOpacity := Integer(IniRead(SettingsPath, "Settings", "DimmedOpacity", DimmedOpacity))
        BrightOpacity := Integer(IniRead(SettingsPath, "Settings", "BrightOpacity", BrightOpacity))
        TriggerPixels := Integer(IniRead(SettingsPath, "Settings", "TriggerPixels", TriggerPixels))
        MinVelocity := Integer(IniRead(SettingsPath, "Settings", "MinVelocity", MinVelocity))
        CheckInterval := Integer(IniRead(SettingsPath, "Settings", "CheckInterval", CheckInterval))
        EdgeThreshold := Integer(IniRead(SettingsPath, "Settings", "EdgeThreshold", EdgeThreshold))
        HideDelay := Integer(IniRead(SettingsPath, "Settings", "HideDelay", HideDelay))
        GradualFade := IniRead(SettingsPath, "Settings", "GradualFade", "true") = "true"
        FadeDistance := Integer(IniRead(SettingsPath, "Settings", "FadeDistance", FadeDistance))
    }
}

SaveSettings() {
    global SettingsPath
    global DimmedOpacity, BrightOpacity, TriggerPixels, MinVelocity
    global CheckInterval, EdgeThreshold, HideDelay, GradualFade, FadeDistance
    
    IniWrite(DimmedOpacity, SettingsPath, "Settings", "DimmedOpacity")
    IniWrite(BrightOpacity, SettingsPath, "Settings", "BrightOpacity")
    IniWrite(TriggerPixels, SettingsPath, "Settings", "TriggerPixels")
    IniWrite(MinVelocity, SettingsPath, "Settings", "MinVelocity")
    IniWrite(CheckInterval, SettingsPath, "Settings", "CheckInterval")
    IniWrite(EdgeThreshold, SettingsPath, "Settings", "EdgeThreshold")
    IniWrite(HideDelay, SettingsPath, "Settings", "HideDelay")
    IniWrite(GradualFade ? "true" : "false", SettingsPath, "Settings", "GradualFade")
    IniWrite(FadeDistance, SettingsPath, "Settings", "FadeDistance")
}

; ============================================================================
; SETTINGS GUI
; ============================================================================

OpenSettings(*) {
    global SettingsGui
    global DimmedOpacity, BrightOpacity, TriggerPixels, MinVelocity
    global CheckInterval, EdgeThreshold, HideDelay, GradualFade, FadeDistance
    
    ; Close existing settings window if open
    if (IsObject(SettingsGui)) {
        SettingsGui.Destroy()
    }
    
    SettingsGui := Gui()
    SettingsGui.Title := "BetterStartHide Settings"
    SettingsGui.SetFont("s10")
    
    ; Opacity settings
    SettingsGui.Add("GroupBox", "x10 y10 w280 r2", "Opacity (0-255)")
    SettingsGui.Add("Text", "x20 y35 w120", "Dimmed Opacity:")
    edtDimmed := SettingsGui.Add("Edit", "x150 y32 w60 Number", DimmedOpacity)
    SettingsGui.Add("UpDown", "Range0-255", DimmedOpacity)
    
    SettingsGui.Add("Text", "x20 y60 w120", "Bright Opacity:")
    edtBright := SettingsGui.Add("Edit", "x150 y57 w60 Number", BrightOpacity)
    SettingsGui.Add("UpDown", "Range0-255", BrightOpacity)
    
    ; Trigger settings
    SettingsGui.Add("GroupBox", "x10 y95 w280 r2", "Trigger Settings")
    SettingsGui.Add("Text", "x20 y120 w120", "Trigger Zone (px):")
    edtTrigger := SettingsGui.Add("Edit", "x150 y117 w60 Number", TriggerPixels)
    SettingsGui.Add("Text", "x220 y120", "from taskbar")
    
    SettingsGui.Add("Text", "x20 y145 w120", "Min Velocity:")
    edtVelocity := SettingsGui.Add("Edit", "x150 y142 w60 Number", MinVelocity)
    SettingsGui.Add("Text", "x220 y145", "pixels/sec")
    
    ; Timing settings
    SettingsGui.Add("GroupBox", "x10 y180 w280 r2", "Timing")
    SettingsGui.Add("Text", "x20 y205 w120", "Check Interval (ms):")
    edtInterval := SettingsGui.Add("Edit", "x150 y202 w60 Number", CheckInterval)
    
    SettingsGui.Add("Text", "x20 y230 w120", "Hide Delay (ms):")
    edtDelay := SettingsGui.Add("Edit", "x150 y227 w60 Number", HideDelay)
    
    ; Gradual fade settings
    SettingsGui.Add("GroupBox", "x10 y265 w280 r3", "Gradual Fade")
    chkGradual := SettingsGui.Add("CheckBox", "x20 y290 w250 Checked" . (GradualFade ? 1 : 0), "Enable gradual fade on approach")
    SettingsGui.Add("Text", "x20 y320 w120", "Fade Distance (px):")
    edtFadeDist := SettingsGui.Add("Edit", "x150 y317 w60 Number", FadeDistance)
    
    ; Buttons
    SettingsGui.Add("Button", "x50 y365 w100 Default", "Save").OnEvent("Click", (*) => SaveAndClose())
    SettingsGui.Add("Button", "x160 y365 w100", "Cancel").OnEvent("Click", (*) => SettingsGui.Destroy())
    
    SettingsGui.Show("w300 h410")
    
    SaveAndClose() {
        ; Validate and save settings
        try {
            DimmedOpacity := Integer(edtDimmed.Value)
            BrightOpacity := Integer(edtBright.Value)
            TriggerPixels := Integer(edtTrigger.Value)
            MinVelocity := Integer(edtVelocity.Value)
            CheckInterval := Integer(edtInterval.Value)
            HideDelay := Integer(edtDelay.Value)
            GradualFade := chkGradual.Value = 1
            FadeDistance := Integer(edtFadeDist.Value)
            
            ; Clamp values
            DimmedOpacity := Max(0, Min(255, DimmedOpacity))
            BrightOpacity := Max(0, Min(255, BrightOpacity))
            
            SaveSettings()
            
            ; Restart timer with new interval
            SetTimer(MonitorMouse, CheckInterval)
            
            MsgBox("Settings saved!", "Success", 64)
            SettingsGui.Destroy()
        } catch as e {
            MsgBox("Invalid settings: " e.Message, "Error", 16)
        }
    }
}

; ============================================================================
; DEBUG HELPERS
; ============================================================================

DebugMonitors(*) {
    text := "=== Multi-Monitor Debug Info ===`n`n"
    text .= "Monitor Count: " MonitorManager.GetMonitorCount() "`n`n"
    
    for monNum, mon in MonitorManager.GetAllMonitors() {
        text .= "Monitor " mon.Number ": " mon.Name "`n"
        text .= "  Primary: " (mon.IsPrimary ? "Yes" : "No") "`n"
        text .= "  Full: (" mon.Left "," mon.Top ") to (" mon.Right "," mon.Bottom ") [" mon.Width "x" mon.Height "]`n"
        text .= "  Work: (" mon.WorkLeft "," mon.WorkTop ") to (" mon.WorkRight "," mon.WorkBottom ") [" mon.WorkWidth "x" mon.WorkHeight "]`n"
        text .= "  Taskbar: " mon.TaskbarPosition " (" mon.TaskbarSize "px)`n"
        text .= "  Taskbar Edge: " mon.TaskbarEdge "`n"
        text .= "  Taskbar Hwnd: " (mon.TaskbarHwnd ? mon.TaskbarHwnd : "Not found") "`n`n"
    }
    
    MsgBox(text, "Monitor Debug Info", 64)
}

; ============================================================================
; TASKBAR OPACITY CONTROL
; ============================================================================

SetTaskbarOpacity(hwnd, opacity) {
    if (!hwnd || !DllCall("IsWindow", "Ptr", hwnd)) {
        return
    }
    WinSetTransparent(opacity, "ahk_id " hwnd)
}

SetAllTaskbarsOpacity(opacity) {
    global CurrentOpacity
    CurrentOpacity := opacity
    
    for monNum, mon in MonitorManager.GetAllMonitors() {
        if (mon.TaskbarHwnd) {
            SetTaskbarOpacity(mon.TaskbarHwnd, opacity)
        }
    }
}

; Gradual opacity based on distance
CalculateGradualOpacity(distance) {
    global DimmedOpacity, BrightOpacity, FadeDistance
    
    if (distance >= FadeDistance) {
        return DimmedOpacity
    }
    
    ; Ease-out interpolation (faster brightening as you get closer)
    ratio := 1 - (distance / FadeDistance)
    ratio := ratio * ratio  ; Square for ease-out curve
    
    return Round(DimmedOpacity + (BrightOpacity - DimmedOpacity) * ratio)
}

; ============================================================================
; SMART TASKBAR REVEAL (Multi-Monitor Aware)
; ============================================================================

MonitorMouse() {
    global LastX, LastY, LastTime
    global TriggerPixels, MinVelocity, EdgeThreshold
    global IsRevealed, LastRevealTime, HideDelay
    global GradualFade, FadeDistance, CurrentOpacity
    global DimmedOpacity, BrightOpacity
    
    MouseGetPos(&currentX, &currentY)
    currentTime := A_TickCount
    
    ; Get current monitor info
    mon := MonitorManager.GetMonitorAt(currentX, currentY)
    if (!mon) {
        return
    }
    
    ; Calculate distance from taskbar using per-monitor info
    distanceFromTaskbar := mon.DistanceToTaskbar(currentX, currentY)
    isOverTaskbar := mon.IsPointOverTaskbar(currentX, currentY)
    edgeDistance := mon.GetEdgeDistance(currentX, currentY)
    
    ; Check if mouse is over taskbar area
    if (isOverTaskbar) {
        if (!IsRevealed || CurrentOpacity != BrightOpacity) {
            SetAllTaskbarsOpacity(BrightOpacity)
            IsRevealed := true
        }
        LastRevealTime := currentTime
        
        ; Update last position and return
        LastX := currentX
        LastY := currentY
        LastTime := currentTime
        return
    }
    
    ; Check if we should hide the taskbar (mouse left and delay passed)
    if (IsRevealed && (currentTime - LastRevealTime > HideDelay)) {
        ; Mouse is not over taskbar, check if it left the taskbar area significantly
        if (distanceFromTaskbar > 50) {  ; Mouse is well away from taskbar
            ; Handle fade out if gradual fade is enabled
            if (GradualFade && distanceFromTaskbar > 0 && distanceFromTaskbar < FadeDistance) {
                ; Gradual fade will handle this below
            } else {
                SetAllTaskbarsOpacity(DimmedOpacity)
                IsRevealed := false
            }
        }
    }
    
    ; Calculate velocity
    timeDelta := (currentTime - LastTime) / 1000.0
    
    if (timeDelta < 0.005) {
        ; Still update position even if time is too short
        LastX := currentX
        LastY := currentY
        LastTime := currentTime
        return
    }
    
    deltaX := currentX - LastX
    deltaY := currentY - LastY
    
    velocity := Sqrt(deltaX * deltaX + deltaY * deltaY) / timeDelta
    
    ; Trigger zone: within TriggerPixels of taskbar edge
    inTriggerZone := distanceFromTaskbar <= TriggerPixels && distanceFromTaskbar >= -mon.TaskbarSize
    approachingTaskbar := mon.IsApproachingTaskbar(deltaX, deltaY)
    fastEnough := velocity >= MinVelocity
    atEdge := edgeDistance <= EdgeThreshold
    
    ; Gradual fade - bidirectional based on distance from taskbar
    if (GradualFade && distanceFromTaskbar > 0 && distanceFromTaskbar < FadeDistance) {
        ; Calculate target opacity based on distance
        newOpacity := CalculateGradualOpacity(distanceFromTaskbar)
        
        ; Apply the calculated opacity (handles both fade in and fade out)
        if (CurrentOpacity != newOpacity) {
            SetAllTaskbarsOpacity(newOpacity)
        }
        
        ; Update revealed state based on whether we're significantly visible
        if (newOpacity > DimmedOpacity + 10 && !IsRevealed) {
            IsRevealed := true
            LastRevealTime := currentTime
        }
    } else if (GradualFade && distanceFromTaskbar >= FadeDistance && CurrentOpacity > DimmedOpacity) {
        ; Mouse is outside fade zone but opacity is still elevated - fade out
        SetAllTaskbarsOpacity(DimmedOpacity)
        if (IsRevealed && (currentTime - LastRevealTime > HideDelay)) {
            IsRevealed := false
        }
    }
    
    ; Reveal taskbar if conditions met
    if ((inTriggerZone && fastEnough && approachingTaskbar) || atEdge) {
        if (!IsRevealed) {
            SetAllTaskbarsOpacity(BrightOpacity)
            IsRevealed := true
            LastRevealTime := currentTime
        }
    }
    
    LastX := currentX
    LastY := currentY
    LastTime := currentTime
}

; ============================================================================
; CLEANUP ON EXIT
; ============================================================================

ExitScript(*) {
    ; Restore full opacity on all taskbars before exiting
    SetAllTaskbarsOpacity(BrightOpacity)
    
    Sleep(200)
    ExitApp()
}

OnExit(ExitScript)