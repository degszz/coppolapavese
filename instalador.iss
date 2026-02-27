[Setup]
AppName=Coppola Pavese Inmobiliaria
AppVersion=1.0.0
AppPublisher=Coppola Pavese Inmobiliaria
AppPublisherURL=
DefaultDirName={autopf}\CoppolaPavese
DefaultGroupName=Coppola Pavese
OutputDir=instalador_output
OutputBaseFilename=CoppolaPavese_Setup_v1.0
SetupIconFile=
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear icono en el escritorio"; GroupDescription: "Iconos adicionales:"; Flags: unchecked

[Files]
; Todos los archivos de la carpeta Release
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Coppola Pavese Inmobiliaria"; Filename: "{app}\coppolapavese.exe"
Name: "{group}\Desinstalar"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Coppola Pavese Inmobiliaria"; Filename: "{app}\coppolapavese.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\coppolapavese.exe"; Description: "Iniciar Coppola Pavese Inmobiliaria"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
