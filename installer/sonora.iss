; Inno Setup script for Sonora.
;
; Build the Flutter Windows release first:
;   flutter build windows --release
;
; Then compile (from the repo root), passing the app version explicitly:
;   iscc /DAppVersion=0.1.0-beta.1 installer\sonora.iss
;
; Requires Inno Setup 6.3+ (for the x64compatible architecture identifier).
; Output: installer\Output\Sonora-Setup-<version>.exe

#ifndef AppVersion
  #define AppVersion "0.0.0-dev"
#endif

#define AppName "Sonora"
#define AppPublisher "Eli-Aqula"
#define AppExeName "Sonora.exe"
#define AppURL "https://github.com/Eli-Aqula/Sonora"
#define ReleaseDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{98FF3383-F4FB-432C-A205-9D6002C0606C}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}/issues
AppUpdatesURL={#AppURL}/releases
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#AppExeName}
OutputDir=Output
OutputBaseFilename=Sonora-Setup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
LicenseFile=..\LICENSE
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
