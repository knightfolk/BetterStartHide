#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================================
; Compile Script for BetterStartHide
; ============================================================================
; This script compiles BetterStartHide.ahk into a standalone executable.
; It checks for AutoHotkey v2 installation and provides guidance if not found.
; ============================================================================

; Find AutoHotkey installation - try multiple methods
AhkPath := ""
BaseFile := ""  ; Initialize at top level

; Method 1: Check if running as script - use current AHK path
if (A_IsCompiled = 0) {
    ; A_AhkPath is the full path to AutoHotkey.exe - can use as base file!
    BaseFile := A_AhkPath
    ; Get directory from full path for compiler location
    SplitPath(A_AhkPath, , &AhkDir)
    AhkPath := AhkDir
}

; Method 2: Try registry - HKCU (current user)
if (AhkPath = "" || !FileExist(AhkPath "\Compiler\Ahk2Exe.exe")) {
    try {
        AhkPath := RegRead("HKEY_CURRENT_USER\SOFTWARE\AutoHotkey", "InstallDir", "")
    }
}

; Method 3: Try registry - HKLM (all users)
if (AhkPath = "" || !FileExist(AhkPath "\Compiler\Ahk2Exe.exe")) {
    try {
        AhkPath := RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\AutoHotkey", "InstallDir", "")
    }
}

; Method 4: Try registry - 32-bit compat on 64-bit Windows
if (AhkPath = "" || !FileExist(AhkPath "\Compiler\Ahk2Exe.exe")) {
    try {
        AhkPath := RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\AutoHotkey", "InstallDir", "")
    }
}

; Method 5: Try common installation paths
CommonPaths := [
    A_ProgramFiles "\AutoHotkey",
    A_ProgramFiles "\AutoHotkey\v2",
    A_AppData "\AutoHotkey",
    "C:\Program Files\AutoHotkey",
    "C:\Program Files (x86)\AutoHotkey",
    "C:\AutoHotkey"
]

if (AhkPath = "" || !FileExist(AhkPath "\Compiler\Ahk2Exe.exe")) {
    for _, path in CommonPaths {
        if (FileExist(path "\Compiler\Ahk2Exe.exe")) {
            AhkPath := path
            break
        }
    }
}

; Check if compiler exists
CompilerPath := ""
if (AhkPath != "" && FileExist(AhkPath "\Compiler\Ahk2Exe.exe")) {
    CompilerPath := AhkPath "\Compiler\Ahk2Exe.exe"
    ; Find the base file (AutoHotkey binary) if not already set
    if (BaseFile = "") {
        if (FileExist(AhkPath "\v2\AutoHotkey64.exe")) {
            BaseFile := AhkPath "\v2\AutoHotkey64.exe"
        } else if (FileExist(AhkPath "\AutoHotkey64.exe")) {
            BaseFile := AhkPath "\AutoHotkey64.exe"
        } else if (FileExist(AhkPath "\v2\AutoHotkey32.exe")) {
            BaseFile := AhkPath "\v2\AutoHotkey32.exe"
        } else if (FileExist(AhkPath "\AutoHotkey32.exe")) {
            BaseFile := AhkPath "\AutoHotkey32.exe"
        } else if (FileExist(AhkPath "\UX\AutoHotkey64.exe")) {
            BaseFile := AhkPath "\UX\AutoHotkey64.exe"
        }
    }
}

; If still not found, ask user
if (CompilerPath = "") {
    Result := MsgBox(
        "AutoHotkey compiler (Ahk2Exe.exe) not found automatically.`n`n"
        . "Would you like to:`n"
        . "• Yes - Browse for Ahk2Exe.exe manually`n"
        . "• No - Open AutoHotkey download page`n"
        . "• Cancel - Exit",
        "Compiler Not Found",
        3 + 48  ; Yes/No/Cancel + Warning
    )
    
    if (Result = "Yes") {
        SelectedFile := FileSelect(1, , "Select Ahk2Exe.exe", "Executable (*.exe)")
        if (SelectedFile != "") {
            CompilerPath := SelectedFile
        } else {
            ExitApp()
        }
    } else if (Result = "No") {
        Run("https://www.autohotkey.com/")
        ExitApp()
    } else {
        ExitApp()
    }
}

; Get script directory
ScriptDir := A_ScriptDir
SourceFile := ScriptDir "\BetterStartHide.ahk"
OutputFile := ScriptDir "\BetterStartHide.exe"
IconFile := ""  ; Optional icon file

; Check for default icon file in script directory
if (FileExist(ScriptDir "\BetterStartHide.ico")) {
    IconFile := ScriptDir "\BetterStartHide.ico"
}

; Check if source file exists
if (!FileExist(SourceFile)) {
    MsgBox(
        "Source file not found:`n"
        . SourceFile "`n`n"
        . "Make sure BetterStartHide.ahk is in the same directory as this compile script.",
        "Source Not Found",
        16  ; Error
    )
    ExitApp()
}

; Ask about custom icon
Result := MsgBox(
    "Would you like to use a custom icon for the executable?`n`n"
    . "• Yes - Select an .ico file`n"
    . "• No - Use default icon`n"
    . "• Cancel - Exit without compiling",
    "Custom Icon",
    3 + 64  ; Yes/No/Cancel + Info
)

if (Result = "Cancel") {
    ExitApp()
}

if (Result = "Yes") {
    SelectedIcon := FileSelect(1, ScriptDir, "Select Icon File", "Icon (*.ico)")
    if (SelectedIcon != "") {
        IconFile := SelectedIcon
    }
}

; Warn if base file not found
BaseWarning := ""
if (BaseFile = "") {
    BaseWarning := "`n`nWARNING: Base file not found. Compilation may fail.`nTry specifying the base file manually."
}

; Compile the script
Result := MsgBox(
    "Ready to compile:`n`n"
    . "Source: " SourceFile "`n"
    . "Output: " OutputFile "`n"
    . "Compiler: " CompilerPath "`n"
    . "Base: " (BaseFile != "" ? BaseFile : "Not found") "`n"
    . "Icon: " (IconFile != "" ? IconFile : "Default") BaseWarning "`n`n"
    . "Proceed with compilation?",
    "Compile BetterStartHide",
    4 + (BaseFile != "" ? 64 : 48)  ; Yes/No + Info/Warning
)

if (Result != "Yes") {
    ExitApp()
}

; Run the compiler
try {
    ; Build command with optional base file and icon
    Cmd := '"' CompilerPath '" /in "' SourceFile '" /out "' OutputFile '"'
    
    if (BaseFile != "") {
        Cmd .= ' /base "' BaseFile '"'
    }
    
    if (IconFile != "") {
        Cmd .= ' /icon "' IconFile '"'
    }
    
    RunWait(Cmd, , "Hide")
    
    if (FileExist(OutputFile)) {
        MsgBox(
            "Compilation successful!`n`n"
            . "Created: " OutputFile "`n`n"
            . "You can now run BetterStartHide.exe without AutoHotkey installed.",
            "Success",
            64  ; Info
        )
        
        ; Optionally open the folder containing the exe
        Result := MsgBox("Open folder containing the compiled executable?", "Open Folder?", 4 + 64)
        if (Result = "Yes") {
            Run('explorer /select,"' OutputFile '"')
        }
    } else {
        MsgBox(
            "Compilation may have failed.`n`n"
            . "The output file was not created:`n"
            . OutputFile "`n`n"
            . "Try running the compiler manually.",
            "Compilation Issue",
            48  ; Warning
        )
    }
} catch as e {
    MsgBox(
        "Error during compilation:`n"
        . e.Message,
        "Compilation Error",
        16  ; Error
    )
}