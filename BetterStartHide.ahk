#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================================
; BetterStartHide - Smart Taskbar Dim & Reveal
; ============================================================================
; Dims the taskbar to near-invisibility and reveals it on mouse proximity.
; Supports multi-monitor configurations.
; ============================================================================

; ============================================================================
; VERSION
; ============================================================================
global VERSION := "1.3"

; ============================================================================
; DEFAULT CONFIGURATION VALUES (used for Restore Defaults)
; ============================================================================
global DEFAULT_DimmedOpacity := 10
global DEFAULT_BrightOpacity := 255
global DEFAULT_TriggerZone := 10
global DEFAULT_FadeDistance := 100
global DEFAULT_CheckInterval := 10
global DEFAULT_EdgeThreshold := 5
global DEFAULT_IndependentMode := true
global DEFAULT_DarkMode := "auto"
global DEFAULT_EnabledMonitors := "*"

; ============================================================================
; ACTIVE CONFIGURATION (overridden by Settings.ini if present)
; ============================================================================
global DimmedOpacity := DEFAULT_DimmedOpacity
global BrightOpacity := DEFAULT_BrightOpacity
global TriggerZone := DEFAULT_TriggerZone
global FadeDistance := DEFAULT_FadeDistance
global CheckInterval := DEFAULT_CheckInterval
global EdgeThreshold := DEFAULT_EdgeThreshold
global IndependentMode := DEFAULT_IndependentMode
global DarkMode := DEFAULT_DarkMode
global EnabledMonitors := DEFAULT_EnabledMonitors

; ============================================================================
; OTHER GLOBAL VARIABLES
; ============================================================================
global LastX := 0
global LastY := 0
global SettingsGui := 0
global SettingsPath := A_AppData "\BetterStartHide\Settings.ini"
global DonateURL := ""  ; Placeholder - update with actual URL when ready

; Per-monitor state tracking (used when IndependentMode is true)
global MonitorStates := Map()  ; monNum -> current opacity

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

; Helper function to find which monitor contains a point
GetMonitorFromPoint(x, y) {
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &L, &T, &R, &B)
        if (x >= L && x <= R && y >= T && y <= B) {
            return A_Index
        }
    }
    return MonitorGetPrimary()
}

; -----------------------------------------------------------------------------
; MonitorInfo Class - Holds all information about a single monitor
; -----------------------------------------------------------------------------
class MonitorInfo {
    __New(monitorNum) {
        this.Number := monitorNum
        this.Name := MonitorGetName(monitorNum)
        this.IsPrimary := (monitorNum = MonitorGetPrimary())
        
        MonitorGet(monitorNum, &L, &T, &R, &B)
        this.Left := L
        this.Top := T
        this.Right := R
        this.Bottom := B
        this.Width := R - L
        this.Height := B - T
        
        MonitorGetWorkArea(monitorNum, &WL, &WT, &WR, &WB)
        this.WorkLeft := WL
        this.WorkTop := WT
        this.WorkRight := WR
        this.WorkBottom := WB
        this.WorkWidth := WR - WL
        this.WorkHeight := WB - WT
        
        this.TaskbarPosition := "None"
        this.TaskbarSize := 0
        this.TaskbarEdge := -1
        this.TaskbarHwnd := 0
        
        this.CalculateTaskbarInfo()
    }
    
    CalculateTaskbarInfo() {
        if (this.WorkBottom < this.Bottom) {
            this.TaskbarPosition := "Bottom"
            this.TaskbarSize := this.Bottom - this.WorkBottom
            this.TaskbarEdge := this.WorkBottom
        } else if (this.WorkTop > this.Top) {
            this.TaskbarPosition := "Top"
            this.TaskbarSize := this.WorkTop - this.Top
            this.TaskbarEdge := this.WorkTop
        } else if (this.WorkLeft > this.Left) {
            this.TaskbarPosition := "Left"
            this.TaskbarSize := this.WorkLeft - this.Left
            this.TaskbarEdge := this.WorkLeft
        } else if (this.WorkRight < this.Right) {
            this.TaskbarPosition := "Right"
            this.TaskbarSize := this.Right - this.WorkRight
            this.TaskbarEdge := this.WorkRight
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
                return this.TaskbarEdge - y
            case "Top":
                return y - this.TaskbarEdge
            case "Left":
                return x - this.TaskbarEdge
            case "Right":
                return this.TaskbarEdge - x
            default:
                return 9999
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
    static refreshInterval := 5000
    
    static Init() {
        this.Refresh()
        OnMessage(0x007E, (w, l, m, h) => this.OnDisplayChange())
    }
    
    static OnDisplayChange() {
        this.Refresh()
        return 0
    }
    
    static Refresh() {
        this.monitors := Map()
        Loop MonitorGetCount() {
            try {
                mon := MonitorInfo(A_Index)
                this.monitors[A_Index] := mon
            }
        }
        this.FindAllTaskbars()
        this.lastRefresh := A_TickCount
    }
    
    static FindAllTaskbars() {
        primaryHwnd := WinExist("ahk_class Shell_TrayWnd")
        if (primaryHwnd) {
            primaryNum := MonitorGetPrimary()
            if (this.monitors.Has(primaryNum)) {
                this.monitors[primaryNum].TaskbarHwnd := primaryHwnd
            }
        }
        
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
            for monNum, mon in this.monitors {
                if (Abs((y + h) - mon.Bottom) < 10 && x >= mon.Left && (x + w) <= mon.Right) {
                    mon.TaskbarHwnd := hwnd
                    return monNum
                }
                if (Abs(y - mon.Top) < 10 && x >= mon.Left && (x + w) <= mon.Right) {
                    mon.TaskbarHwnd := hwnd
                    return monNum
                }
                if (Abs(x - mon.Left) < 10 && y >= mon.Top && (y + h) <= mon.Bottom) {
                    mon.TaskbarHwnd := hwnd
                    return monNum
                }
                if (Abs((x + w) - mon.Right) < 10 && y >= mon.Top && (y + h) <= mon.Bottom) {
                    mon.TaskbarHwnd := hwnd
                    return monNum
                }
            }
        }
        return 0
    }
    
    static GetMonitorAt(x, y) {
        if (A_TickCount - this.lastRefresh > this.refreshInterval) {
            this.Refresh()
        }
        monNum := GetMonitorFromPoint(x, y)
        if (this.monitors.Has(monNum)) {
            return this.monitors[monNum]
        }
        if (this.monitors.Count > 0) {
            for _, mon in this.monitors {
                return mon
            }
        }
        return ""
    }
    
    static GetAllMonitors() {
        return this.monitors
    }
    
    static GetMonitorCount() {
        return this.monitors.Count
    }
}

; ============================================================================
; UI THEMING SUPPORT - Windows 11 Control Panel Style
; ============================================================================

; Light mode colors (default) - matches Windows Settings app
global LIGHT_THEME := {
    bgWindow: 0xF3F3F3,        ; Window background (light gray)
    bgCard: 0xFFFFFF,          ; Card/section background
    textPrimary: 0x1A1A1A,     ; Primary text
    textSecondary: 0x5C5C5C,   ; Secondary/hint text
    textLink: 0x0078D4,        ; Link/accent text
    border: 0xE5E5E5,          ; Border color
    separator: 0xEBEBEB,       ; Separator lines
}

; Dark mode colors - designed to work with AutoHotkey's white controls
; We use a medium-dark gray that doesn't clash with white input fields
global DARK_THEME := {
    bgWindow: 0x3A3A3A,        ; Window background (medium-dark, works with white controls)
    bgCard: 0x484848,          ; Card/section background
    textPrimary: 0xF0F0F0,     ; Primary text (bright)
    textSecondary: 0xC0C0C0,   ; Secondary/hint text
    textLink: 0x60CDFF,        ; Link/accent text
    border: 0x555555,          ; Border color
    separator: 0x505050,       ; Separator lines
}

IsSystemDarkMode() {
    try {
        value := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "SystemUsesLightTheme", 1)
        return (value = 0)
    }
    return false
}

GetEffectiveDarkMode() {
    global DarkMode
    switch DarkMode {
        case "dark":
            return true
        case "light":
            return false
        case "auto":
        default:
            return IsSystemDarkMode()
    }
}

; Apply theme to GUI - Windows 11 style
ApplyGuiTheme(gui) {
    isDark := GetEffectiveDarkMode()
    theme := isDark ? DARK_THEME : LIGHT_THEME
    
    static DWMWA_USE_IMMERSIVE_DARK_MODE := 20
    static DWMWA_USE_IMMERSIVE_DARK_MODE_WIN10 := 19
    
    guiHwnd := gui.Hwnd
    
    ; Set title bar to match theme
    value := isDark ? 1 : 0
    result := DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", guiHwnd, "Int", DWMWA_USE_IMMERSIVE_DARK_MODE, "Int*", value, "Int", 4, "Int")
    if (result != 0) {
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", guiHwnd, "Int", DWMWA_USE_IMMERSIVE_DARK_MODE_WIN10, "Int*", value, "Int", 4, "Int")
    }
    
    ; Set window background
    gui.BackColor := theme.bgWindow
}

; ============================================================================
; DONATE FUNCTIONALITY
; ============================================================================

OpenDonate(*) {
    global DonateURL
    if (DonateURL != "") {
        try {
            Run(DonateURL)
        } catch as e {
            MsgBox("Could not open donate link.`n`nError: " e.Message, "Error", 16)
        }
    } else {
        MsgBox("Donate functionality coming soon!`n`nThank you for supporting BetterStartHide.", "Donate", 64)
    }
}

; ============================================================================
; SIMPLIFIED OPACITY CALCULATION
; ============================================================================

; Pure distance-based opacity - no state, no animation
; TriggerZone = full bright zone right next to taskbar
; FadeDistance = gradual fade zone beyond TriggerZone
GetOpacityForDistance(distance) {
    global TriggerZone, FadeDistance, DimmedOpacity, BrightOpacity
    
    if (distance <= TriggerZone) {
        return BrightOpacity  ; In the bright zone
    }
    if (distance >= TriggerZone + FadeDistance) {
        return DimmedOpacity  ; Beyond fade range
    }
    ; In fade zone - interpolate with ease-out curve
    ratio := (distance - TriggerZone) / FadeDistance
    ratio := ratio * ratio  ; Ease-out curve (faster brightening as you get closer)
    return Round(BrightOpacity - (BrightOpacity - DimmedOpacity) * ratio)
}

; ============================================================================
; INITIALIZATION
; ============================================================================

CoordMode("Mouse", "Screen")
LoadSettings()

A_TrayMenu.Delete()
A_TrayMenu.Add("Settings", OpenSettings)
A_TrayMenu.Add("Show All Taskbars", (*) => SetAllTaskbarsOpacity(BrightOpacity))
A_TrayMenu.Add("Dim All Taskbars", (*) => SetAllTaskbarsOpacity(DimmedOpacity))
A_TrayMenu.Add()
A_TrayMenu.Add("Debug Monitors", DebugMonitors)
A_TrayMenu.Add()
A_TrayMenu.Add("Donate", OpenDonate)
A_TrayMenu.Add()
A_TrayMenu.Add("Exit", ExitScript)
A_IconTip := "BetterStartHide`nSmart Taskbar Reveal (Multi-Monitor)"

MonitorManager.Init()

; Initialize per-monitor opacity tracking
global MonitorStates := Map()
for monNum, mon in MonitorManager.GetAllMonitors() {
    MonitorStates[monNum] := DimmedOpacity
}

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

MouseGetPos(&initX, &initY)
LastX := initX
LastY := initY

; Dim all taskbars initially
SetAllTaskbarsOpacity(DimmedOpacity)

; Start monitoring
SetTimer(MonitorMouse, CheckInterval)

; Periodic refresh to maintain opacity
SetTimer(RefreshTaskbarOpacity, 100)

TrayTip("BetterStartHide", "Taskbar dimmed. Move mouse toward taskbar to reveal.")

; ============================================================================
; PERIODIC REFRESH
; ============================================================================

RefreshTaskbarOpacity() {
    global MonitorStates, IndependentMode, DimmedOpacity
    
    for monNum, mon in MonitorManager.GetAllMonitors() {
        if (mon.TaskbarHwnd && DllCall("IsWindow", "Ptr", mon.TaskbarHwnd) && IsMonitorEnabled(monNum)) {
            if (IndependentMode) {
                WinSetTransparent(MonitorStates.Get(monNum, DimmedOpacity), "ahk_id " mon.TaskbarHwnd)
            }
        }
    }
}

; ============================================================================
; SETTINGS MANAGEMENT
; ============================================================================

LoadSettings() {
    global SettingsPath
    global DimmedOpacity, BrightOpacity, TriggerZone, FadeDistance
    global CheckInterval, EdgeThreshold, IndependentMode, DarkMode, EnabledMonitors
    
    if (!FileExist(SettingsPath)) {
        return
    }
    
    try {
        DimmedOpacity := Integer(IniRead(SettingsPath, "Settings", "DimmedOpacity", DimmedOpacity))
        BrightOpacity := Integer(IniRead(SettingsPath, "Settings", "BrightOpacity", BrightOpacity))
        TriggerZone := Integer(IniRead(SettingsPath, "Settings", "TriggerZone", TriggerZone))
        FadeDistance := Integer(IniRead(SettingsPath, "Settings", "FadeDistance", FadeDistance))
        CheckInterval := Integer(IniRead(SettingsPath, "Settings", "CheckInterval", CheckInterval))
        EdgeThreshold := Integer(IniRead(SettingsPath, "Settings", "EdgeThreshold", EdgeThreshold))
        IndependentMode := IniRead(SettingsPath, "Settings", "IndependentMode", "true") = "true"
        DarkMode := IniRead(SettingsPath, "Settings", "DarkMode", "auto")
        EnabledMonitors := IniRead(SettingsPath, "Settings", "EnabledMonitors", "*")
    }
}

SaveSettings() {
    global SettingsPath
    global DimmedOpacity, BrightOpacity, TriggerZone, FadeDistance
    global CheckInterval, EdgeThreshold, IndependentMode, DarkMode, EnabledMonitors
    
    SplitPath(SettingsPath, , &settingsDir)
    if (!DirExist(settingsDir)) {
        DirCreate(settingsDir)
    }
    
    IniWrite(DimmedOpacity, SettingsPath, "Settings", "DimmedOpacity")
    IniWrite(BrightOpacity, SettingsPath, "Settings", "BrightOpacity")
    IniWrite(TriggerZone, SettingsPath, "Settings", "TriggerZone")
    IniWrite(FadeDistance, SettingsPath, "Settings", "FadeDistance")
    IniWrite(CheckInterval, SettingsPath, "Settings", "CheckInterval")
    IniWrite(EdgeThreshold, SettingsPath, "Settings", "EdgeThreshold")
    IniWrite(IndependentMode ? "true" : "false", SettingsPath, "Settings", "IndependentMode")
    IniWrite(DarkMode, SettingsPath, "Settings", "DarkMode")
    IniWrite(EnabledMonitors, SettingsPath, "Settings", "EnabledMonitors")
}

RestoreDefaultSettings() {
    global DimmedOpacity, BrightOpacity, TriggerZone, FadeDistance
    global CheckInterval, EdgeThreshold, IndependentMode, DarkMode, EnabledMonitors
    
    DimmedOpacity := DEFAULT_DimmedOpacity
    BrightOpacity := DEFAULT_BrightOpacity
    TriggerZone := DEFAULT_TriggerZone
    FadeDistance := DEFAULT_FadeDistance
    CheckInterval := DEFAULT_CheckInterval
    EdgeThreshold := DEFAULT_EdgeThreshold
    IndependentMode := DEFAULT_IndependentMode
    DarkMode := DEFAULT_DarkMode
    EnabledMonitors := DEFAULT_EnabledMonitors
}

; ============================================================================
; SETTINGS GUI
; ============================================================================

OpenSettings(*) {
    global SettingsGui
    global DimmedOpacity, BrightOpacity, TriggerZone, FadeDistance
    global CheckInterval, IndependentMode, DarkMode
    
    if (IsObject(SettingsGui)) {
        SettingsGui.Destroy()
    }
    
    SettingsGui := Gui()
    SettingsGui.Title := "BetterStartHide Settings v" . VERSION
    SettingsGui.SetFont("s10")
    
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
    ; Trigger & Fade settings (unified)
    ; ============================================
    SettingsGui.Add("GroupBox", "x10 y" . currentY . " w370 r2.5", "Trigger & Fade (px)")
    currentY += 25
    SettingsGui.Add("Text", "x20 y" . currentY . " w150", "Trigger Zone:")
    edtTrigger := SettingsGui.Add("Edit", "x200 y" . (currentY - 3) . " w60 Number", TriggerZone)
    SettingsGui.Add("Text", "x270 y" . currentY . " w100", "full bright zone")
    currentY += 28
    SettingsGui.Add("Text", "x20 y" . currentY . " w150", "Fade Distance:")
    edtFadeDist := SettingsGui.Add("Edit", "x200 y" . (currentY - 3) . " w60 Number", FadeDistance)
    SettingsGui.Add("Text", "x270 y" . currentY . " w100", "gradual fade zone")
    currentY += 30 + sectionSpacing
    
    ; ============================================
    ; Timing settings
    ; ============================================
    SettingsGui.Add("GroupBox", "x10 y" . currentY . " w370 r1.5", "Timing")
    currentY += 25
    SettingsGui.Add("Text", "x20 y" . currentY . " w150", "Check Interval (ms):")
    edtInterval := SettingsGui.Add("Edit", "x200 y" . (currentY - 3) . " w60 Number", CheckInterval)
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
    ; Appearance settings (Dark Mode)
    ; ============================================
    SettingsGui.Add("GroupBox", "x10 y" . currentY . " w370 r2", "Appearance")
    currentY += 25
    SettingsGui.Add("Text", "x20 y" . currentY . " w150", "Theme:")
    cboDarkMode := SettingsGui.Add("ComboBox", "x200 y" . (currentY - 3) . " w170", ["Auto (System Default)", "Light Mode", "Dark Mode"])
    switch DarkMode {
        case "auto":
            cboDarkMode.Choose(1)
        case "light":
            cboDarkMode.Choose(2)
        case "dark":
            cboDarkMode.Choose(3)
        default:
            cboDarkMode.Choose(1)
    }
    currentY += 30 + sectionSpacing
    
    ; ============================================
    ; Monitor selection settings
    ; ============================================
    monCount := MonitorManager.GetMonitorCount()
    monitorChecks := []
    
    if (monCount > 1) {
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
    SettingsGui.Add("Button", "x10 y" . currentY . " w85 Default", "Save").OnEvent("Click", (*) => SaveAndClose())
    SettingsGui.Add("Button", "x100 y" . currentY . " w85", "Cancel").OnEvent("Click", (*) => SettingsGui.Destroy())
    SettingsGui.Add("Button", "x190 y" . currentY . " w85", "Reset").OnEvent("Click", (*) => RestoreDefaultsClick())
    SettingsGui.Add("Button", "x290 y" . currentY . " w85", "Donate").OnEvent("Click", OpenDonate)
    currentY += 35
    
    guiHeight := currentY + 5
    
    ; Apply theme (title bar and background)
    ApplyGuiTheme(SettingsGui)
    
    SettingsGui.Show("w395 h" . guiHeight)
    
    OnAllMonitorsClick(ctrl, *) {
        global EnabledMonitors
        if (ctrl.Value = 1) {
            EnabledMonitors := "*"
        }
    }
    
    RestoreDefaultsClick() {
        edtDimmed.Value := DEFAULT_DimmedOpacity
        edtBright.Value := DEFAULT_BrightOpacity
        edtTrigger.Value := DEFAULT_TriggerZone
        edtFadeDist.Value := DEFAULT_FadeDistance
        edtInterval.Value := DEFAULT_CheckInterval
        chkIndependent.Value := DEFAULT_IndependentMode ? 1 : 0
        cboDarkMode.Choose(1)
        
        if (monCount > 1) {
            chkAllMonitors.Value := 1
            for mc in monitorChecks {
                mc.chk.Value := 1
            }
        }
        
        MsgBox("Defaults restored. Click Save to apply.", "Reset", 64)
    }
    
    SaveAndClose() {
        global EnabledMonitors, IndependentMode, DarkMode
        try {
            DimmedOpacity := Integer(edtDimmed.Value)
            BrightOpacity := Integer(edtBright.Value)
            TriggerZone := Integer(edtTrigger.Value)
            FadeDistance := Integer(edtFadeDist.Value)
            CheckInterval := Integer(edtInterval.Value)
            IndependentMode := chkIndependent.Value = 1
            
            switch cboDarkMode.Value {
                case 1:
                    DarkMode := "auto"
                case 2:
                    DarkMode := "light"
                case 3:
                    DarkMode := "dark"
                default:
                    DarkMode := "auto"
            }
            
            DimmedOpacity := Max(0, Min(255, DimmedOpacity))
            BrightOpacity := Max(0, Min(255, BrightOpacity))
            
            if (monCount > 1) {
                if (chkAllMonitors.Value = 1) {
                    EnabledMonitors := "*"
                } else {
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
        text .= "  Full: (" mon.Left "," mon.Top ") to (" mon.Right "," mon.Bottom ")`n"
        text .= "  Taskbar: " mon.TaskbarPosition " (" mon.TaskbarSize "px)`n"
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

SetMonitorOpacity(monNum, opacity) {
    global MonitorStates
    mon := MonitorManager.GetAllMonitors().Get(monNum, "")
    if (mon && mon.TaskbarHwnd && IsMonitorEnabled(monNum)) {
        SetTaskbarOpacity(mon.TaskbarHwnd, opacity)
        MonitorStates[monNum] := opacity
    }
}

SetAllTaskbarsOpacity(opacity) {
    global MonitorStates
    for monNum, mon in MonitorManager.GetAllMonitors() {
        if (mon.TaskbarHwnd && IsMonitorEnabled(monNum)) {
            SetTaskbarOpacity(mon.TaskbarHwnd, opacity)
            MonitorStates[monNum] := opacity
        }
    }
}

; ============================================================================
; SMART TASKBAR REVEAL (Simplified - Pure Distance-Based)
; ============================================================================

MonitorMouse() {
    global LastX, LastY
    global TriggerZone, EdgeThreshold
    
    MouseGetPos(&currentX, &currentY)
    
    ; Get current monitor info
    mon := MonitorManager.GetMonitorAt(currentX, currentY)
    if (!mon) {
        return
    }
    
    monNum := mon.Number
    
    ; Calculate distance from taskbar
    distanceFromTaskbar := mon.DistanceToTaskbar(currentX, currentY)
    isOverTaskbar := mon.IsPointOverTaskbar(currentX, currentY)
    edgeDistance := mon.GetEdgeDistance(currentX, currentY)
    
    ; Calculate target opacity based purely on distance
    if (isOverTaskbar) {
        ; Over taskbar - always fully bright
        targetOpacity := BrightOpacity
    } else if (edgeDistance <= EdgeThreshold) {
        ; At screen edge - trigger reveal
        targetOpacity := BrightOpacity
    } else {
        ; Use distance-based opacity calculation
        targetOpacity := GetOpacityForDistance(distanceFromTaskbar)
    }
    
    ; Apply the calculated opacity
    SetMonitorOpacity(monNum, targetOpacity)
    
    LastX := currentX
    LastY := currentY
}

; ============================================================================
; CLEANUP ON EXIT
; ============================================================================

ExitScript(*) {
    SetAllTaskbarsOpacity(BrightOpacity)
    Sleep(200)
    ExitApp()
}

OnExit(ExitScript)