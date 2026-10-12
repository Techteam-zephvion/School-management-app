#define MyAppName "Schoolic Staging"
#define MyAppPublisher "Schoolic"
#define MyAppExeName "schoolic.exe"
#define MyAppVersion GetEnv("SCHOOLIC_APP_VERSION")
#define MySourceDir GetEnv("SCHOOLIC_WINDOWS_RELEASE_DIR")
#define MyOutputDir GetEnv("SCHOOLIC_WINDOWS_ARTIFACT_DIR")
#define MyIconFile GetEnv("SCHOOLIC_WINDOWS_ICON_FILE")

[Setup]
AppId={{9B80F151-0A7D-42D8-A998-533C6E07C3C8}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\Schoolic Staging
DefaultGroupName=Schoolic Staging
DisableProgramGroupPage=yes
OutputDir={#MyOutputDir}
OutputBaseFilename=schoolic-windows-staging-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName={#MyAppName}
SetupIconFile={#MyIconFile}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#MySourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Schoolic Staging"; Filename: "{app}\{#MyAppExeName}"
Name: "{userdesktop}\Schoolic Staging"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch Schoolic Staging"; Flags: nowait postinstall skipifsilent
