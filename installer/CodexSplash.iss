#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{FFAE864E-E791-40C8-8FA7-7D79B611C1B9}
AppName=Codex Splash
AppVersion={#AppVersion}
AppPublisher=li1-init
AppPublisherURL=https://github.com/li1-init/Codex-Splash
AppSupportURL=https://github.com/li1-init/Codex-Splash/issues
DefaultDirName={localappdata}\Programs\Codex Splash
DisableProgramGroupPage=yes
DisableStartupPrompt=yes
PrivilegesRequired=lowest
MinVersion=10.0
CloseApplications=no
SetupIconFile=CodexSplash.ico
UninstallDisplayIcon={app}\CodexSplash.ico
WizardStyle=modern
OutputDir=..\dist
OutputBaseFilename=Codex-Splash-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes

[Files]
Source: "..\Launch.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\portal.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\.Welcome Jay.overlay.mp4"; DestDir: "{app}"; Flags: ignoreversion
Source: "CodexSplash.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autodesktop}\ChatGPT - Welcome Jay"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -Sta -WindowStyle Hidden -ExecutionPolicy Bypass -File ""{app}\Launch.ps1"""; WorkingDir: "{app}"; IconFilename: "{app}\CodexSplash.ico"; Comment: "Open ChatGPT with the Welcome Jay cold-start animation"
