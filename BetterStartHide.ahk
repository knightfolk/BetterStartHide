#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================================
; BetterStartHide - Smart Taskbar Dim & Reveal
; ============================================================================
; Dims the taskbar to near-invisibility and reveals it on mouse proximity
; or fast mouse movement toward the bottom edge.
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
global ScreenHeight := A_ScreenHeight
global TaskbarHwnd := 0
global TaskbarHeight := 48      ; Will be updated dynamically
global IsRevealed := false
global LastRevealTime := 0
global CurrentOpacity := 255
global SettingsGui := 0
global SettingsPath := A_ScriptDir "\Settings.ini"

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
A_TrayMenu.Add("Show Taskbar", (*) => SetTaskbarOpacity(BrightOpacity))
A_TrayMenu.Add("Dim Taskbar", (*) => SetTaskbarOpacity(DimmedOpacity))
A_TrayMenu.Add()
A_TrayMenu.Add("Exit", ExitScript)
A_IconTip := "BetterStartHide`nSmart Taskbar Reveal"

; Find taskbar
TaskbarHwnd := WinExist("ahk_class Shell_TrayWnd")
if (!TaskbarHwnd) {
    MsgBox("Could not find taskbar!", "Error", 16)
    ExitApp()
}

; Get taskbar height dynamically
UpdateTaskbarInfo()

; Get initial mouse position
MouseGetPos(&initX, &initY)
LastX := initX
LastY := initY
LastTime := A_TickCount

; Dim the taskbar initially
CurrentOpacity := BrightOpacity
SetTaskbarOpacity(DimmedOpacity)

; Start monitoring
SetTimer(MonitorMouse, CheckInterval)

; Start periodic refresh to maintain opacity (Windows may reset it)
SetTimer(RefreshTaskbarOpacity, 100)

TrayTip("BetterStartHide", "Taskbar dimmed. Move mouse toward bottom to reveal.`nRight-click tray icon for settings.")

; ============================================================================
; PERIODIC REFRESH
; ============================================================================

RefreshTaskbarOpacity() {
    global CurrentOpacity, TaskbarHwnd, DimmedOpacity, IsRevealed
    
    ; Re-find taskbar if needed
    if (!TaskbarHwnd || !DllCall("IsWindow", "Ptr", TaskbarHwnd)) {
        TaskbarHwnd := WinExist("ahk_class Shell_TrayWnd")
    }
    
    if (!TaskbarHwnd) {
        return
    }
    
    ; Re-apply opacity using WinSetTransparent - simpler and more reliable
    WinSetTransparent(CurrentOpacity, "ahk_class Shell_TrayWnd")
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

UpdateTaskbarInfo() {
    global TaskbarHwnd, TaskbarHeight, ScreenHeight
    
    WinGetPos(, &tbY, , &tbH, "ahk_class Shell_TrayWnd")
    TaskbarHeight := tbH
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
    SettingsGui.Add("GroupBox", "x10 y265 w280 r2.5", "Gradual Fade")
    chkGradual := SettingsGui.Add("CheckBox", "x20 y290 w200 Checked" . (GradualFade ? 1 : 0), "Enable gradual fade on approach")
    SettingsGui.Add("Text", "x20 y315 w120", "Fade Distance (px):")
    edtFadeDist := SettingsGui.Add("Edit", "x150 y312 w60 Number", FadeDistance)
    
    ; Buttons
    SettingsGui.Add("Button", "x50 y355 w100 Default", "Save").OnEvent("Click", (*) => SaveAndClose())
    SettingsGui.Add("Button", "x160 y355 w100", "Cancel").OnEvent("Click", (*) => SettingsGui.Destroy())
    
    SettingsGui.Show("w300 h390")
    
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
; TASKBAR OPACITY CONTROL
; ============================================================================

SetTaskbarOpacity(opacity) {
    global TaskbarHwnd, CurrentOpacity
    
    CurrentOpacity := opacity
    
    ; Re-find taskbar handle in case it changed (e.g., explorer restart)
    if (!TaskbarHwnd || !DllCall("IsWindow", "Ptr", TaskbarHwnd)) {
        TaskbarHwnd := WinExist("ahk_class Shell_TrayWnd")
    }
    
    if (!TaskbarHwnd) {
        return
    }
    
    ; Use WinSetTransparent - AHK's built-in method is more robust
    WinSetTransparent(opacity, "ahk_class Shell_TrayWnd")
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
; SMART TASKBAR REVEAL
; ============================================================================

MonitorMouse() {
    global LastX, LastY, LastTime
    global ScreenHeight, TriggerPixels, MinVelocity, EdgeThreshold
    global TaskbarHeight, IsRevealed, LastRevealTime, HideDelay
    global GradualFade, FadeDistance, CurrentOpacity
    global DimmedOpacity, BrightOpacity
    
    ; Update taskbar info periodically (in case it resizes)
    static lastUpdate := 0
    if (A_TickCount - lastUpdate > 5000) {
        UpdateTaskbarInfo()
        lastUpdate := A_TickCount
    }
    
    MouseGetPos(&currentX, &currentY)
    currentTime := A_TickCount
    
    ; Calculate distance from taskbar (bottom of screen)
    distanceFromBottom := ScreenHeight - currentY
    taskbarTop := ScreenHeight - TaskbarHeight
    distanceFromTaskbarTop := taskbarTop - currentY
    
    ; Check if mouse is over taskbar area
    if (currentY >= taskbarTop && currentY <= ScreenHeight) {
        if (!IsRevealed || CurrentOpacity != BrightOpacity) {
            SetTaskbarOpacity(BrightOpacity)
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
        ; Mouse is not over taskbar, check if it left the bottom area
        if (currentY < taskbarTop - 50) {  ; Mouse is well above taskbar
            ; Handle fade out if gradual fade is enabled and mouse is in fade zone
            if (GradualFade && distanceFromTaskbarTop > 0 && distanceFromTaskbarTop < FadeDistance) {
                ; Gradual fade will handle this below
            } else {
                SetTaskbarOpacity(DimmedOpacity)
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
    
    ; Trigger zone: within TriggerPixels of taskbar top edge
    inTriggerZone := distanceFromTaskbarTop <= TriggerPixels && distanceFromTaskbarTop >= -TaskbarHeight
    movingDown := deltaY > 0
    fastEnough := velocity >= MinVelocity
    atEdge := distanceFromBottom <= EdgeThreshold
    
    ; Gradual fade - bidirectional based on distance from taskbar
    if (GradualFade && distanceFromTaskbarTop > 0 && distanceFromTaskbarTop < FadeDistance) {
        ; Calculate target opacity based on distance
        newOpacity := CalculateGradualOpacity(distanceFromTaskbarTop)
        
        ; Apply the calculated opacity (handles both fade in and fade out)
        if (CurrentOpacity != newOpacity) {
            SetTaskbarOpacity(newOpacity)
        }
        
        ; Update revealed state based on whether we're significantly visible
        if (newOpacity > DimmedOpacity + 10 && !IsRevealed) {
            IsRevealed := true
            LastRevealTime := currentTime
        }
    } else if (GradualFade && distanceFromTaskbarTop >= FadeDistance && CurrentOpacity > DimmedOpacity) {
        ; Mouse is outside fade zone but opacity is still elevated - fade out
        SetTaskbarOpacity(DimmedOpacity)
        if (IsRevealed && (currentTime - LastRevealTime > HideDelay)) {
            IsRevealed := false
        }
    }
    
    ; Reveal taskbar if conditions met
    if ((inTriggerZone && fastEnough && movingDown) || atEdge) {
        if (!IsRevealed) {
            SetTaskbarOpacity(BrightOpacity)
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
    global TaskbarHwnd, BrightOpacity
    
    ; Restore full opacity before exiting
    SetTaskbarOpacity(BrightOpacity)
    
    Sleep(200)
    ExitApp()
}

OnExit(ExitScript)