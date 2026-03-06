; ════════════════════════════════════════════════════════════
; Coppola Pavese Inmobiliaria — Inno Setup Script
; Para compilar: abrir con Inno Setup Compiler y presionar F9
; ════════════════════════════════════════════════════════════

#define AppName      "Coppola Pavese Inmobiliaria"
#define AppVersion   "1.0.0"
#define AppPublisher "Coppola Pavese"
#define AppExeName   "coppolapavese.exe"
#define SourceDir    "..\build\windows\x64\runner\Release"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://coppolapavese.com.ar
DefaultDirName={autopf}\CoppolaPavese
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=output
OutputBaseFilename=CoppolaPavese_Instalador_v{#AppVersion}
SetupIconFile=..\assets\images\logo.png
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
; Requiere Windows 10 o superior
MinVersion=10.0
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
; No requiere ser administrador (instala por usuario)
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; GroupDescription: "Iconos adicionales:"

[Files]
; Ejecutable principal
Source: "{#SourceDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; DLLs de Flutter
Source: "{#SourceDir}\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

; Datos de la aplicación (assets)
Source: "{#SourceDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Acceso directo en el menú Inicio
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\Desinstalar {#AppName}"; Filename: "{uninstallexe}"

; Acceso directo en el escritorio (opcional)
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
; Ejecutar la app al finalizar la instalación
Filename: "{app}\{#AppExeName}"; Description: "Iniciar {#AppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Limpiar archivos temporales al desinstalar (NO borra la base de datos)
Type: filesandordirs; Name: "{app}\*.log"

[Code]
// Mostrar mensaje de bienvenida personalizado
procedure InitializeWizard;
begin
  WizardForm.WelcomeLabel2.Caption :=
    'Este asistente instalará ' + ExpandConstant('{#AppName}') + ' versión ' +
    ExpandConstant('{#AppVersion}') + ' en su computadora.' + #13#10 + #13#10 +
    'Se recomienda cerrar todas las aplicaciones antes de continuar.' + #13#10 + #13#10 +
    'Haga clic en Siguiente para continuar.';
end;
