#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================================
; BetterStartHide - Smart Taskbar Dim & Reveal
; ============================================================================
; Dims the taskbar to near-invisibility and reveals it on mouse proximity
; or fast mouse movement toward the bottom edge.
; ============================================================================

; ============================================================================
; CONFIGURATION
; ============================================================================
global DimmedOpacity := 10      ; Opacity when dimmed (0-255, 10 = ~4% visible)
global BrightOpacity := 255     ; Opacity when revealed (255 = fully visible)
global TriggerZone := 0.10      ; Bottom 10% of screen triggers reveal
global MinVelocity := 800       ; Mouse speed threshold for reveal
global CheckInterval := 10      ; Mouse check interval in ms
global EdgeThreshold := 5       ; Pixels from bottom to always trigger
global HideDelay := 500         ; ms to wait before hiding again

; ============================================================================
; GLOBAL VARIABLES
; ============================================================================
global LastX := 0
global LastY := 0
global LastTime := 0
global ScreenHeight := A_ScreenHeight
global TriggerPixels := ScreenHeight * TriggerZone
global TaskbarHwnd := 0
global IsRevealed := false
global LastRevealTime := 0

; ============================================================================
; INITIALIZATION
; ============================================================================

A_TrayMenu.Delete()
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

; Get initial mouse position
MouseGetPos(&initX, &initY)
LastX := initX
LastY := initY
LastTime := A_TickCount

; Dim the taskbar initially
SetTaskbarOpacity(DimmedOpacity)

; Start monitoring
SetTimer(MonitorMouse, CheckInterval)

TrayTip("BetterStartHide", "Taskbar dimmed. Move mouse fast toward bottom to reveal.")

; ============================================================================
; TASKBAR OPACITY CONTROL
; ============================================================================

SetTaskbarOpacity(opacity) {
    global TaskbarHwnd
    static GWL_EXSTYLE := -20
    static WS_EX_LAYERED := 0x00080000
    static LWA_ALPHA := 0x02
    
    ; Ensure the window has WS_EX_LAYERED style
    exStyle := DllCall("GetWindowLongPtr", "Ptr", TaskbarHwnd, "int", GWL_EXSTYLE, "Ptr")
    if (!(exStyle & WS_EX_LAYERED)) {
        DllCall("SetWindowLongPtr", "Ptr", TaskbarHwnd, "int", GWL_EXSTYLE, "Ptr", exStyle | WS_EX_LAYERED)
    }
    
    ; Set transparency
    DllCall("SetLayeredWindowAttributes", "Ptr", TaskbarHwnd, "UInt", 0, "UChar", opacity, "UInt", LWA_ALPHA)
}

; ============================================================================
; PART 2: SMART TASKBAR REVEAL
; ============================================================================

MonitorMouse() {
    global LastX, LastY, LastTime
    global ScreenHeight, TriggerPixels, MinVelocity, EdgeThreshold
    global IsRevealed, LastRevealTime, HideDelay
    
    MouseGetPos(&currentX, &currentY)
    currentTime := A_TickCount
    
    ; Check if mouse is over taskbar area (bottom of screen)
    taskbar := WinExist("ahk_class Shell_TrayWnd")
    if (taskbar) {
        WinGetPos(&tbX, &tbY, &tbW, &tbH, "ahk_class Shell_TrayWnd")
        
        ; If mouse is within taskbar bounds
        if (currentX >= tbX && currentX <= tbX + tbW && currentY >= tbY && currentY <= tbY + tbH) {
            if (!IsRevealed) {
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
    }
    
    ; Check if we should hide the taskbar (mouse left and delay passed)
    if (IsRevealed && (currentTime - LastRevealTime > HideDelay)) {
        ; Mouse is not over taskbar, check if it left the bottom area
        if (currentY < ScreenHeight - 100) {  ; Mouse is well above bottom
            SetTaskbarOpacity(DimmedOpacity)
            IsRevealed := false
        }
    }
    
    ; Calculate velocity
    timeDelta := (currentTime - LastTime) / 1000.0
    
    if (timeDelta < 0.005) {
        return
    }
    
    deltaX := currentX - LastX
    deltaY := currentY - LastY
    
    velocity := Sqrt(deltaX * deltaX + deltaY * deltaY) / timeDelta
    
    distanceFromBottom := ScreenHeight - currentY
    inTriggerZone := distanceFromBottom <= TriggerPixels
    movingDown := deltaY > 0
    fastEnough := velocity >= MinVelocity
    atEdge := distanceFromBottom <= EdgeThreshold
    
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