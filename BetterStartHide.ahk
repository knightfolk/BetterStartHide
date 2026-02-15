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
; VERSION
; ============================================================================
global VERSION := "1.1"

; ============================================================================
; DEFAULT CONFIGURATION (overridden by Settings.ini if present)
; ============================================================================
global DimmedOpacity := 10      ; Opacity when dimmed (0-255, 10 = ~4% visible)
global BrightOpacity := 255     ; Opacity when revealed (255 = fully visible)
global TriggerPixels := 10      ; Pixels from taskbar top edge to trigger reveal
global ExitZone := 50           ; Distance from taskbar before fade-out starts (hysteresis)
global MinVelocity := 400       ; Mouse speed threshold for reveal (reduced by 50%)
global CheckInterval := 10      ; Mouse check interval in ms
global EdgeThreshold := 5       ; Pixels from bottom to always trigger
global HideDelay := 500         ; ms to wait before hiding again
global GradualFade := true      ; Enable gradual fade on approach
global FadeDistance := 100      ; Pixels over which to fade in
global FadeOutEnabled := true   ; Enable smooth fade-out when leaving zone
global FadeOutDuration := 300   ; Duration of fade-out animation (ms)
global IndependentMode := true  ; Each taskbar operates independently based on mouse position

; ============================================================================
; GLOBAL VARIABLES
; ============================================================================
global LastX := 0
global LastY := 0
global LastTime := 0
global SettingsGui := 0
global SettingsPath := A_AppData "\BetterStartHide\Settings.ini"
global EnabledMonitors := "*"  ; "*" = all monitors, or comma-separated list like "1,2"

; Per-monitor state tracking (used when IndependentMode is true)
global MonitorStates := Map()  ; monNum -> MonitorState object

; Legacy global state (used when IndependentMode is false)
global IsRevealed := false
global LastRevealTime := 0
global CurrentOpacity := 255
global IsFadingOut := false
global FadeOutStartTime := 0
global FadeOutStartOpacity := 255

; ============================================================================
; MULTI-MONITOR SUPPORT CLASSES
; ============================================================================

; Helper function to check if a monitor is enabled
IsMonitorEnabled(monNum) {
    global EnabledMonitors
    if (EnabledMonitors = "*") {
        return true  ; All monitors enabled
    }
    ; Parse comma-separated list
    Loop Parse, EnabledMonitors, "," {
        if (A_LoopField = String(monNum)) {
            return true
        }
    }
    return false
}

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
; MonitorState Class - Per-monitor state for independent mode
; -----------------------------------------------------------------------------
class MonitorState {
    __New() {
        this.IsRevealed := false
        this.LastRevealTime := 0
        this.CurrentOpacity := 255
        this.IsFadingOut := false
        this.FadeOutStartTime := 0
        this.FadeOutStartOpacity := 255
    }
}

; Helper functions for per-monitor state management
GetMonitorState(monNum) {
    global MonitorStates
    if (!MonitorStates.Has(monNum)) {
        MonitorStates[monNum] := MonitorState()
    }
    return MonitorStates[monNum]
}

InitializeMonitorStates() {
    global MonitorStates, DimmedOpacity
    MonitorStates := Map()
    
    for monNum, mon in MonitorManager.GetAllMonitors() {
        state := MonitorState()
        state.CurrentOpacity := DimmedOpacity
        MonitorStates[monNum] := state
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

; Initialize per-monitor states
InitializeMonitorStates()

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
    global IndependentMode, CurrentOpacity
    
    if (IndependentMode) {
        ; Re-apply per-monitor opacity in independent mode
        for monNum, mon in MonitorManager.GetAllMonitors() {
            if (mon.TaskbarHwnd && DllCall("IsWindow", "Ptr", mon.TaskbarHwnd) && IsMonitorEnabled(monNum)) {
                state := GetMonitorState(monNum)
                WinSetTransparent(state.CurrentOpacity, "ahk_id " mon.TaskbarHwnd)
            }
        }
    } else {
        ; Re-apply global opacity to all enabled taskbars
        for monNum, mon in MonitorManager.GetAllMonitors() {
            if (mon.TaskbarHwnd && DllCall("IsWindow", "Ptr", mon.TaskbarHwnd) && IsMonitorEnabled(monNum)) {
                WinSetTransparent(CurrentOpacity, "ahk_id " mon.TaskbarHwnd)
            }
        }
    }
}

; ============================================================================
; SETTINGS MANAGEMENT
; ============================================================================

LoadSettings() {
    global SettingsPath
    global DimmedOpacity, BrightOpacity, TriggerPixels, ExitZone, MinVelocity
    global CheckInterval, EdgeThreshold, HideDelay, GradualFade, FadeDistance
    global FadeOutEnabled, FadeOutDuration, IndependentMode
    global EnabledMonitors
    
    if (!FileExist(SettingsPath)) {
        return
    }
    
    try {
        ; Ensure all values are properly typed
        DimmedOpacity := Integer(IniRead(SettingsPath, "Settings", "DimmedOpacity", DimmedOpacity))
        BrightOpacity := Integer(IniRead(SettingsPath, "Settings", "BrightOpacity", BrightOpacity))
        TriggerPixels := Integer(IniRead(SettingsPath, "Settings", "TriggerPixels", TriggerPixels))
        ExitZone := Integer(IniRead(SettingsPath, "Settings", "ExitZone", ExitZone))
        MinVelocity := Integer(IniRead(SettingsPath, "Settings", "MinVelocity", MinVelocity))
        CheckInterval := Integer(IniRead(SettingsPath, "Settings", "CheckInterval", CheckInterval))
        EdgeThreshold := Integer(IniRead(SettingsPath, "Settings", "EdgeThreshold", EdgeThreshold))
        HideDelay := Integer(IniRead(SettingsPath, "Settings", "HideDelay", HideDelay))
        GradualFade := IniRead(SettingsPath, "Settings", "GradualFade", "true") = "true"
        FadeDistance := Integer(IniRead(SettingsPath, "Settings", "FadeDistance", FadeDistance))
        FadeOutEnabled := IniRead(SettingsPath, "Settings", "FadeOutEnabled", "true") = "true"
        FadeOutDuration := Integer(IniRead(SettingsPath, "Settings", "FadeOutDuration", FadeOutDuration))
        IndependentMode := IniRead(SettingsPath, "Settings", "IndependentMode", "true") = "true"
        EnabledMonitors := IniRead(SettingsPath, "Settings", "EnabledMonitors", "*")
    }
}

SaveSettings() {
    global SettingsPath
    global DimmedOpacity, BrightOpacity, TriggerPixels, ExitZone, MinVelocity
    global CheckInterval, EdgeThreshold, HideDelay, GradualFade, FadeDistance
    global FadeOutEnabled, FadeOutDuration, IndependentMode
    global EnabledMonitors
    
    ; Ensure AppData directory exists
    SplitPath(SettingsPath, , &settingsDir)
    if (!DirExist(settingsDir)) {
        DirCreate(settingsDir)
    }
    
    IniWrite(DimmedOpacity, SettingsPath, "Settings", "DimmedOpacity")
    IniWrite(BrightOpacity, SettingsPath, "Settings", "BrightOpacity")
    IniWrite(TriggerPixels, SettingsPath, "Settings", "TriggerPixels")
    IniWrite(ExitZone, SettingsPath, "Settings", "ExitZone")
    IniWrite(MinVelocity, SettingsPath, "Settings", "MinVelocity")
    IniWrite(CheckInterval, SettingsPath, "Settings", "CheckInterval")
    IniWrite(EdgeThreshold, SettingsPath, "Settings", "EdgeThreshold")
    IniWrite(HideDelay, SettingsPath, "Settings", "HideDelay")
    IniWrite(GradualFade ? "true" : "false", SettingsPath, "Settings", "GradualFade")
    IniWrite(FadeDistance, SettingsPath, "Settings", "FadeDistance")
    IniWrite(FadeOutEnabled ? "true" : "false", SettingsPath, "Settings", "FadeOutEnabled")
    IniWrite(FadeOutDuration, SettingsPath, "Settings", "FadeOutDuration")
    IniWrite(IndependentMode ? "true" : "false", SettingsPath, "Settings", "IndependentMode")
    IniWrite(EnabledMonitors, SettingsPath, "Settings", "EnabledMonitors")
}

; ============================================================================
; SETTINGS GUI
; ============================================================================

OpenSettings(*) {
    global SettingsGui
    global DimmedOpacity, BrightOpacity, TriggerPixels, ExitZone, MinVelocity
    global CheckInterval, EdgeThreshold, HideDelay, GradualFade, FadeDistance
    global FadeOutEnabled, FadeOutDuration, IndependentMode
    
    ; Close existing settings window if open
    if (IsObject(SettingsGui)) {
        SettingsGui.Destroy()
    }
    
    SettingsGui := Gui()
    SettingsGui.Title := "BetterStartHide Settings v" . VERSION
    SettingsGui.SetFont("s10")
    
    ; Track current Y position for dynamic layout
    currentY := 10
    sectionSpacing := 15
    
    ; ============================================
    ; Opacity settings
    ; ============================================
    SettingsGui.Add("GroupBox", "x10 y" . currentY . " w370 r2.5", "Opacity (0-255)")
    currentY += 25
    SettingsGui.Add("Text", "x20 y" . currentY . " w150", "Dimmed Opacity:")
    edtDimmed := SettingsGui.Add("Edit", "x200 y" . (currentY - 3) . " w60 Number", DimmedOpacity)
    SettingsGui.Add("UpDown", "Range0-255", DimmedOpacity)
    SettingsGui.Add("Text", "x270 y" . currentY . " w100", "(0 = invisible)")
    currentY += 28
    SettingsGui.Add("Text", "x20 y" . currentY . " w150", "Bright Opacity:")
    edtBright := SettingsGui.Add("Edit", "x200 y" . (currentY - 3) . " w60 Number", BrightOpacity)
    SettingsGui.Add("UpDown", "Range0-255", BrightOpacity)
    SettingsGui.Add("Text", "x270 y" . currentY . " w100", "(255 = visible)")
    currentY += 30 + sectionSpacing
    
    ; ============================================
    ; Trigger settings
    ; ============================================
    SettingsGui.Add("GroupBox", "x10 y" . currentY . " w370 r3.5", "Trigger Settings")
    currentY += 25
    SettingsGui.Add("Text", "x20 y" . currentY . " w150", "Trigger Zone (px):")
    edtTrigger := SettingsGui.Add("Edit", "x200 y" . (currentY - 3) . " w60 Number", TriggerPixels)
    SettingsGui.Add("Text", "x270 y" . currentY . " w100", "from taskbar")
    currentY += 28
    SettingsGui.Add("Text", "x20 y" . currentY . " w150", "Exit Zone (px):")
    edtExitZone := SettingsGui.Add("Edit", "x200 y" . (currentY - 3) . " w60 Number", ExitZone)
    SettingsGui.Add("Text", "x270 y" . currentY . " w100", "fade-out starts")
    currentY += 28
    SettingsGui.Add("Text", "x20 y" . currentY . " w150", "Min Velocity:")
    edtVelocity := SettingsGui.Add("Edit", "x200 y" . (currentY - 3) . " w60 Number", MinVelocity)
    SettingsGui.Add("Text", "x270 y" . currentY . " w100", "pixels/sec")
    currentY += 30 + sectionSpacing
    
    ; ============================================
    ; Timing settings
    ; ============================================
    SettingsGui.Add("GroupBox", "x10 y" . currentY . " w370 r2.5", "Timing")
    currentY += 25
    SettingsGui.Add("Text", "x20 y" . currentY . " w150", "Check Interval (ms):")
    edtInterval := SettingsGui.Add("Edit", "x200 y" . (currentY - 3) . " w60 Number", CheckInterval)
    currentY += 28
    SettingsGui.Add("Text", "x20 y" . currentY . " w150", "Hide Delay (ms):")
    edtDelay := SettingsGui.Add("Edit", "x200 y" . (currentY - 3) . " w60 Number", HideDelay)
    currentY += 30 + sectionSpacing
    
    ; ============================================
    ; Fade In settings (Gradual Fade)
    ; ============================================
    SettingsGui.Add("GroupBox", "x10 y" . currentY . " w370 r2.5", "Fade In (On Approach)")
    currentY += 25
    chkGradual := SettingsGui.Add("CheckBox", "x20 y" . currentY . " w340 Checked" . (GradualFade ? 1 : 0), "Enable gradual fade on approach")
    currentY += 28
    SettingsGui.Add("Text", "x20 y" . currentY . " w150", "Fade Distance (px):")
    edtFadeDist := SettingsGui.Add("Edit", "x200 y" . (currentY - 3) . " w60 Number", FadeDistance)
    currentY += 30 + sectionSpacing
    
    ; ============================================
    ; Fade Out settings (NEW)
    ; ============================================
    SettingsGui.Add("GroupBox", "x10 y" . currentY . " w370 r2.5", "Fade Out (On Leave)")
    currentY += 25
    chkFadeOut := SettingsGui.Add("CheckBox", "x20 y" . currentY . " w340 Checked" . (FadeOutEnabled ? 1 : 0), "Enable smooth fade-out animation")
    currentY += 28
    SettingsGui.Add("Text", "x20 y" . currentY . " w150", "Fade Out Duration (ms):")
    edtFadeOutDur := SettingsGui.Add("Edit", "x200 y" . (currentY - 3) . " w60 Number", FadeOutDuration)
    currentY += 30 + sectionSpacing
    
    ; ============================================
    ; Behavior settings
    ; ============================================
    SettingsGui.Add("GroupBox", "x10 y" . currentY . " w370 r2", "Behavior")
    currentY += 25
    chkIndependent := SettingsGui.Add("CheckBox", "x20 y" . currentY . " w340 Checked" . (IndependentMode ? 1 : 0), "Independent Taskbar Control")
    currentY += 25
    SettingsGui.Add("Text", "x30 y" . currentY . " w340", "(Each monitor's taskbar reveals/hides independently)")
    currentY += 30 + sectionSpacing
    
    ; ============================================
    ; Monitor selection settings
    ; ============================================
    monCount := MonitorManager.GetMonitorCount()
    monitorChecks := []
    
    if (monCount > 1) {
        ; Calculate box height based on monitor count
        boxHeight := monCount + 1.5
        SettingsGui.Add("GroupBox", "x10 y" . currentY . " w370 r" . boxHeight, "Monitor Selection")
        currentY += 25
        chkAllMonitors := SettingsGui.Add("CheckBox", "x20 y" . currentY . " w340 Checked" . (EnabledMonitors = "*" ? 1 : 0) . " vchkAllMonitors", "All Monitors")
        chkAllMonitors.OnEvent("Click", OnAllMonitorsClick)
        currentY += 28
        
        for monNum, mon in MonitorManager.GetAllMonitors() {
            isEnabled := (EnabledMonitors = "*" || InStr(EnabledMonitors, String(monNum)))
            chk := SettingsGui.Add("CheckBox", "x30 y" . currentY . " w340 Checked" . (isEnabled ? 1 : 0) . " vchkMon" . monNum, 
                "Monitor " . monNum . (mon.IsPrimary ? " (Primary)" : "") . " - " . mon.TaskbarPosition)
            monitorChecks.Push({chk: chk, num: monNum})
            currentY += 25
        }
        currentY += sectionSpacing
    }
    
    ; ============================================
    ; Buttons
    ; ============================================
    currentY += 5
    SettingsGui.Add("Button", "x100 y" . currentY . " w100 Default", "Save").OnEvent("Click", (*) => SaveAndClose())
    SettingsGui.Add("Button", "x210 y" . currentY . " w100", "Cancel").OnEvent("Click", (*) => SettingsGui.Destroy())
    currentY += 35
    
    guiHeight := currentY + 5
    SettingsGui.Show("w395 h" . guiHeight)
    
    OnAllMonitorsClick(ctrl, *) {
        global EnabledMonitors
        if (ctrl.Value = 1) {
            ; Enable all monitors
            EnabledMonitors := "*"
        }
    }
    
    SaveAndClose() {
        global EnabledMonitors, FadeOutEnabled, FadeOutDuration, IndependentMode, ExitZone
        ; Validate and save settings
        try {
            DimmedOpacity := Integer(edtDimmed.Value)
            BrightOpacity := Integer(edtBright.Value)
            TriggerPixels := Integer(edtTrigger.Value)
            ExitZone := Integer(edtExitZone.Value)
            MinVelocity := Integer(edtVelocity.Value)
            CheckInterval := Integer(edtInterval.Value)
            HideDelay := Integer(edtDelay.Value)
            GradualFade := chkGradual.Value = 1
            FadeDistance := Integer(edtFadeDist.Value)
            FadeOutEnabled := chkFadeOut.Value = 1
            FadeOutDuration := Integer(edtFadeOutDur.Value)
            IndependentMode := chkIndependent.Value = 1
            
            ; Clamp values
            DimmedOpacity := Max(0, Min(255, DimmedOpacity))
            BrightOpacity := Max(0, Min(255, BrightOpacity))
            FadeOutDuration := Max(50, Min(2000, FadeOutDuration))
            
            ; Read monitor selection
            if (monCount > 1) {
                if (chkAllMonitors.Value = 1) {
                    EnabledMonitors := "*"
                } else {
                    ; Build list from individual checkboxes
                    enabledList := ""
                    for mc in monitorChecks {
                        if (mc.chk.Value = 1) {
                            if (enabledList != "") {
                                enabledList .= ","
                            }
                            enabledList .= String(mc.num)
                        }
                    }
                    EnabledMonitors := enabledList = "" ? "*" : enabledList
                }
            }
            
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

; Set opacity for a specific monitor's taskbar (used in independent mode)
SetMonitorOpacity(monNum, opacity) {
    global MonitorStates
    mon := MonitorManager.GetAllMonitors().Get(monNum, "")
    if (mon && mon.TaskbarHwnd && IsMonitorEnabled(monNum)) {
        SetTaskbarOpacity(mon.TaskbarHwnd, opacity)
        state := GetMonitorState(monNum)
        state.CurrentOpacity := opacity
    }
}

; Set opacity for all taskbars (respects IndependentMode)
SetAllTaskbarsOpacity(opacity) {
    global CurrentOpacity, IndependentMode
    
    if (IndependentMode) {
        ; In independent mode, update all monitors but track per-monitor state
        for monNum, mon in MonitorManager.GetAllMonitors() {
            if (mon.TaskbarHwnd && IsMonitorEnabled(monNum)) {
                SetTaskbarOpacity(mon.TaskbarHwnd, opacity)
                state := GetMonitorState(monNum)
                state.CurrentOpacity := opacity
            }
        }
    } else {
        ; In unified mode, use global state
        CurrentOpacity := opacity
        for monNum, mon in MonitorManager.GetAllMonitors() {
            if (mon.TaskbarHwnd && IsMonitorEnabled(monNum)) {
                SetTaskbarOpacity(mon.TaskbarHwnd, opacity)
            }
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

; Gradual opacity for use with Exit Zone offset
; This calculates fade from BrightOpacity (at ExitZone) to DimmedOpacity (at FadeDistance)
CalculateGradualOpacityWithOffset(adjustedDistance, adjustedFadeDistance) {
    global DimmedOpacity, BrightOpacity
    
    if (adjustedFadeDistance <= 0) {
        return DimmedOpacity
    }
    
    if (adjustedDistance >= adjustedFadeDistance) {
        return DimmedOpacity
    }
    
    ; Ease-out interpolation
    ratio := 1 - (adjustedDistance / adjustedFadeDistance)
    ratio := ratio * ratio  ; Square for ease-out curve
    
    return Round(DimmedOpacity + (BrightOpacity - DimmedOpacity) * ratio)
}

; ============================================================================
; FADE OUT ANIMATION
; ============================================================================

; Legacy global fade-out state (used when IndependentMode is false)
global IsFadingOut := false
global FadeOutStartTime := 0
global FadeOutStartOpacity := 255

; Start the fade-out animation (respects IndependentMode)
StartFadeOut(monNum := 0) {
    global IsFadingOut, FadeOutStartTime, FadeOutStartOpacity
    global CurrentOpacity, FadeOutEnabled, IndependentMode
    
    if (!FadeOutEnabled) {
        ; If fade-out is disabled, just set to dimmed immediately
        if (IndependentMode && monNum > 0) {
            SetMonitorOpacity(monNum, DimmedOpacity)
        } else {
            SetAllTaskbarsOpacity(DimmedOpacity)
        }
        return
    }
    
    if (IndependentMode && monNum > 0) {
        ; Per-monitor fade-out
        state := GetMonitorState(monNum)
        state.IsFadingOut := true
        state.FadeOutStartTime := A_TickCount
        state.FadeOutStartOpacity := state.CurrentOpacity
    } else {
        ; Global fade-out
        IsFadingOut := true
        FadeOutStartTime := A_TickCount
        FadeOutStartOpacity := CurrentOpacity
    }
}

; Check and update fade-out animation (respects IndependentMode)
UpdateFadeOut(monNum := 0) {
    global IsFadingOut, FadeOutStartTime, FadeOutStartOpacity
    global CurrentOpacity, DimmedOpacity, FadeOutDuration, FadeOutEnabled
    global IsRevealed, IndependentMode
    
    if (!FadeOutEnabled) {
        return false  ; Not fading out
    }
    
    if (IndependentMode && monNum > 0) {
        ; Per-monitor fade-out
        state := GetMonitorState(monNum)
        if (!state.IsFadingOut) {
            return false
        }
        
        elapsed := A_TickCount - state.FadeOutStartTime
        progress := elapsed / FadeOutDuration
        
        if (progress >= 1.0) {
            ; Fade complete
            SetMonitorOpacity(monNum, DimmedOpacity)
            state.IsFadingOut := false
            state.IsRevealed := false
            return true
        }
        
        ; Calculate current opacity with ease-out curve
        easeProgress := 1 - ((1 - progress) ** 2)  ; Ease-out quadratic
        newOpacity := Round(state.FadeOutStartOpacity - (state.FadeOutStartOpacity - DimmedOpacity) * easeProgress)
        
        if (newOpacity != state.CurrentOpacity) {
            SetMonitorOpacity(monNum, newOpacity)
        }
        
        return true
    } else {
        ; Global fade-out
        if (!IsFadingOut) {
            return false
        }
        
        elapsed := A_TickCount - FadeOutStartTime
        progress := elapsed / FadeOutDuration
        
        if (progress >= 1.0) {
            ; Fade complete
            SetAllTaskbarsOpacity(DimmedOpacity)
            IsFadingOut := false
            IsRevealed := false
            return true
        }
        
        ; Calculate current opacity with ease-out curve
        easeProgress := 1 - ((1 - progress) ** 2)  ; Ease-out quadratic
        newOpacity := Round(FadeOutStartOpacity - (FadeOutStartOpacity - DimmedOpacity) * easeProgress)
        
        if (newOpacity != CurrentOpacity) {
            SetAllTaskbarsOpacity(newOpacity)
        }
        
        return true
    }
}

; Cancel fade-out (when mouse returns to taskbar area)
CancelFadeOut(monNum := 0) {
    global IsFadingOut, IndependentMode
    
    if (IndependentMode && monNum > 0) {
        state := GetMonitorState(monNum)
        state.IsFadingOut := false
    } else {
        IsFadingOut := false
    }
}

; Check if a monitor is fading out
IsMonitorFadingOut(monNum) {
    global IsFadingOut, IndependentMode
    
    if (IndependentMode) {
        state := GetMonitorState(monNum)
        return state.IsFadingOut
    } else {
        return IsFadingOut
    }
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
    global IsFadingOut, IndependentMode
    
    MouseGetPos(&currentX, &currentY)
    currentTime := A_TickCount
    
    ; Get current monitor info
    mon := MonitorManager.GetMonitorAt(currentX, currentY)
    if (!mon) {
        return
    }
    
    monNum := mon.Number
    
    ; Calculate distance from taskbar using per-monitor info
    distanceFromTaskbar := mon.DistanceToTaskbar(currentX, currentY)
    isOverTaskbar := mon.IsPointOverTaskbar(currentX, currentY)
    edgeDistance := mon.GetEdgeDistance(currentX, currentY)
    
    ; Get per-monitor or global state based on mode
    if (IndependentMode) {
        state := GetMonitorState(monNum)
        isRevealed := state.IsRevealed
        lastReveal := state.LastRevealTime
        currentOp := state.CurrentOpacity
        isFading := state.IsFadingOut
    } else {
        isRevealed := IsRevealed
        lastReveal := LastRevealTime
        currentOp := CurrentOpacity
        isFading := IsFadingOut
    }
    
    ; Check if mouse is over taskbar area
    if (isOverTaskbar) {
        ; Cancel any ongoing fade-out
        if (isFading) {
            CancelFadeOut(monNum)
        }
        
        if (!isRevealed || currentOp != BrightOpacity) {
            if (IndependentMode) {
                SetMonitorOpacity(monNum, BrightOpacity)
                state.IsRevealed := true
            } else {
                SetAllTaskbarsOpacity(BrightOpacity)
                IsRevealed := true
            }
        }
        
        if (IndependentMode) {
            state.LastRevealTime := currentTime
        } else {
            LastRevealTime := currentTime
        }
        
        ; Update last position and return
        LastX := currentX
        LastY := currentY
        LastTime := currentTime
        return
    }
    
    ; Update fade-out animation if in progress
    if (isFading) {
        UpdateFadeOut(monNum)
        ; Update last position and return during fade
        LastX := currentX
        LastY := currentY
        LastTime := currentTime
        return
    }
    
    ; Check if we should hide the taskbar (mouse left and delay passed)
    if (isRevealed && (currentTime - lastReveal > HideDelay)) {
        ; Mouse is not over taskbar, check if it left beyond the exit zone
        if (distanceFromTaskbar > ExitZone) {
            ; Start fade-out animation (or instant if disabled)
            if (GradualFade && distanceFromTaskbar > 0 && distanceFromTaskbar < FadeDistance) {
                ; Gradual fade-in will handle this zone
            } else {
                StartFadeOut(monNum)
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
    
    ; Exit Zone hysteresis - keep taskbar FULLY BRIGHT within Exit Zone
    ; Exit Zone is measured from the TOP of the taskbar (taskbar edge, distance = 0)
    if (distanceFromTaskbar > 0 && distanceFromTaskbar <= ExitZone) {
        ; Within Exit Zone - always keep bright (hysteresis prevents flickering)
        if (currentOp != BrightOpacity) {
            if (IndependentMode) {
                SetMonitorOpacity(monNum, BrightOpacity)
            } else {
                SetAllTaskbarsOpacity(BrightOpacity)
            }
        }
        
        ; Mark as revealed
        if (!isRevealed) {
            if (IndependentMode) {
                state.IsRevealed := true
                state.LastRevealTime := currentTime
            } else {
                IsRevealed := true
                LastRevealTime := currentTime
            }
        }
    }
    ; Gradual fade - only applies BEYOND Exit Zone (distance > ExitZone)
    else if (GradualFade && distanceFromTaskbar > ExitZone && distanceFromTaskbar < FadeDistance) {
        ; Calculate target opacity based on distance (adjusted for Exit Zone)
        adjustedDistance := distanceFromTaskbar - ExitZone
        adjustedFadeDistance := FadeDistance - ExitZone
        newOpacity := CalculateGradualOpacityWithOffset(adjustedDistance, adjustedFadeDistance)
        
        ; Apply the calculated opacity
        if (currentOp != newOpacity) {
            if (IndependentMode) {
                SetMonitorOpacity(monNum, newOpacity)
            } else {
                SetAllTaskbarsOpacity(newOpacity)
            }
        }
    }
    ; Beyond both Exit Zone and Fade Distance - start fade out
    else if (GradualFade && distanceFromTaskbar >= FadeDistance && currentOp > DimmedOpacity && !isFading) {
        if (isRevealed && (currentTime - lastReveal > HideDelay)) {
            StartFadeOut(monNum)
        }
    }
    ; Non-gradual fade mode - just use Exit Zone for hysteresis
    else if (!GradualFade && distanceFromTaskbar > ExitZone && currentOp > DimmedOpacity && !isFading) {
        if (isRevealed && (currentTime - lastReveal > HideDelay)) {
            StartFadeOut(monNum)
        }
    }
    
    ; Reveal taskbar if conditions met
    if ((inTriggerZone && fastEnough && approachingTaskbar) || atEdge) {
        if (!isRevealed) {
            ; Cancel any fade-out in progress
            if (isFading) {
                CancelFadeOut(monNum)
            }
            if (IndependentMode) {
                SetMonitorOpacity(monNum, BrightOpacity)
                state.IsRevealed := true
                state.LastRevealTime := currentTime
            } else {
                SetAllTaskbarsOpacity(BrightOpacity)
                IsRevealed := true
                LastRevealTime := currentTime
            }
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