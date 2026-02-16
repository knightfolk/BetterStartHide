; ============================================================================
; BetterStartHide Installer Script for Inno Setup
; ============================================================================
; Requires Inno Setup 6.x (https://jrsoftware.org/isdl.php)
; ============================================================================

#define AppName "BetterStartHide"
#define AppVersion "1.3.1"
#define AppPublisher "BetterStartHide"
#define AppURL "https://github.com/knightfolk/BetterStartHide"
#define AppExeName "BetterStartHide.exe"
#define AppIcon "BSH.ico"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
AllowNoIcons=yes
; LicenseFile=..\LICENSE  ; Uncomment if LICENSE file exists
; InfoBeforeFile=..\README.md  ; Uncomment to show README before install
OutputDir=output
OutputBaseFilename={#AppName}-{#AppVersion}-Setup
SetupIconFile=..\{#AppIcon}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
MinVersion=10.0
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startup"; Description: "Launch {#AppName} when Windows starts"; GroupDescription: "Startup Options:"; Flags: unchecked

[Files]
; Main executable
Source: "..\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
; Icon file (for shortcuts)
Source: "..\{#AppIcon}"; DestDir: "{app}"; Flags: ignoreversion
; Documentation
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppIcon}"
Name: "{group}\{cm:ProgramOnTheWeb,{#AppName}}"; Filename: "{#AppURL}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppIcon}"; Tasks: desktopicon

[Registry]
; Startup entry (only if task selected)
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#AppName}"; ValueData: """{app}\{#AppExeName}"""; Flags: uninsdeletevalue; Tasks: startup

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  SettingsPath: string;
  SettingsDir: string;
begin
  if CurUninstallStep = usUninstall then
  begin
    // Ask user if they want to delete settings (stored in AppData)
    if MsgBox('Do you want to remove your BetterStartHide settings?', mbConfirmation, MB_YESNO) = IDYES then
    begin
      SettingsDir := ExpandConstant('{userappdata}\BetterStartHide');
      SettingsPath := SettingsDir + '\Settings.ini';
      if FileExists(SettingsPath) then
        DeleteFile(SettingsPath);
      // Remove the directory if empty
      if DirExists(SettingsDir) then
        RemoveDir(SettingsDir);
    end;
  end;
end;
