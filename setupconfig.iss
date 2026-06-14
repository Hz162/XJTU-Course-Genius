; XJTU Course Genius — Inno Setup Script
; Updated from v3.6 (Python) to v4.0 (Flutter + Go)

#define MyAppName "XJTU Course Genius"
#define MyAppVersion "4.0"
#define MyAppPublisher "Hz"
#define MyAppExeName "xjtu_course_genius.exe"

[Setup]
; Same AppId as v3.6 — enables automatic upgrade
AppId={{BA86B661-D40E-45AC-973C-39BE51995377}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\XJTUCourseGenius
UninstallDisplayIcon={app}\{#MyAppExeName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename=XJTU-Course-Genius-Setup-v{#MyAppVersion}
SolidCompression=yes
Compression=lzma2/ultra
WizardStyle=modern
PrivilegesRequired=lowest

; Clean up old v3.6 files on upgrade
[InstallDelete]
Type: filesandordirs; Name: "{app}\_internal"
Type: files; Name: "{app}\login.exe"
Type: files; Name: "{app}\config.ini"

[Dirs]
Name: "{app}"; Permissions: users-modify

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Flutter app
Source: "frontend\build\windows\x64\runner\Release\xjtu_course_genius.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "frontend\build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "frontend\build\windows\x64\runner\Release\screen_retriever_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "frontend\build\windows\x64\runner\Release\window_manager_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "frontend\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
; Go backend (auto-started by Flutter app)
Source: "backend\xjtu-genius.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
