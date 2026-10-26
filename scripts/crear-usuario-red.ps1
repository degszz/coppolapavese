# ============================================================
# crear-usuario-red.ps1 — PC HOST (Windows 11), como administrador
# Crea un usuario local SOLO para la red ("cpred") y le da acceso a la
# carpeta compartida. La otra PC se conecta con ese usuario.
#
# Por qué: Windows 11 (24H2 en adelante) bloquea o corta las conexiones
# "sin contraseña" (invitado) entre PCs. Con un usuario y clave propios
# la conexión es estable y no depende de la cuenta Microsoft de nadie.
#
# Uso (Terminal como administrador, en la carpeta del pendrive):
#   powershell -ExecutionPolicy Bypass -File .\crear-usuario-red.ps1
# ============================================================

param(
    [string]$Usuario = 'cpred',
    [string]$RutaCarpeta = 'C:\CoppolaPavese',
    [string]$NombreShare = 'CoppolaPavese'
)

$esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $esAdmin) {
    Write-Host 'Este script necesita administrador: Win + X > Terminal (Administrador).' -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $RutaCarpeta)) {
    Write-Host "No existe $RutaCarpeta. Correr con -RutaCarpeta <carpeta donde está inmobiliaria.db>." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Usuario de red: $Usuario" -ForegroundColor Cyan
Write-Host "Elegí una clave (la vas a escribir una sola vez en la otra PC). Anotala en un lugar seguro."
$clave  = Read-Host "Clave" -AsSecureString
$clave2 = Read-Host "Repetir clave" -AsSecureString
$t1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($clave))
$t2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($clave2))
if ($t1 -ne $t2 -or $t1.Length -lt 6) {
    Write-Host "Las claves no coinciden o tienen menos de 6 caracteres. No se cambió nada." -ForegroundColor Red
    exit 1
}

# 1. Crear (o actualizar la clave de) el usuario local
$existe = Get-LocalUser -Name $Usuario -ErrorAction SilentlyContinue
try {
    if ($existe) {
        Set-LocalUser -Name $Usuario -Password $clave -PasswordNeverExpires $true -ErrorAction Stop
        Write-Host "Usuario $Usuario ya existía: clave actualizada." -ForegroundColor Yellow
    } else {
        New-LocalUser -Name $Usuario -Password $clave -PasswordNeverExpires `
            -UserMayNotChangePassword -FullName 'Red CoppolaPavese' `
            -Description 'Usuario para la carpeta compartida de la app' -ErrorAction Stop | Out-Null
        Write-Host "Usuario $Usuario creado." -ForegroundColor Green
    }
} catch {
    Write-Host "ERROR creando el usuario: $_" -ForegroundColor Red
    exit 1
}

# Que no aparezca en la pantalla de inicio de sesión de Windows
$lista = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList'
New-Item -Path $lista -Force | Out-Null
New-ItemProperty -Path $lista -Name $Usuario -Value 0 -PropertyType DWord -Force | Out-Null

# 2. Permiso de archivos (NTFS): leer y escribir en la carpeta de la base
icacls $RutaCarpeta /grant "${Usuario}:(OI)(CI)M" | Out-Null
Write-Host "Permiso de lectura/escritura en $RutaCarpeta para $Usuario." -ForegroundColor Green

# 3. Permiso del recurso compartido
$share = Get-SmbShare -Name $NombreShare -ErrorAction SilentlyContinue
if (-not $share) {
    New-SmbShare -Name $NombreShare -Path $RutaCarpeta -FullAccess $Usuario | Out-Null
    Write-Host "Carpeta compartida '$NombreShare' creada." -ForegroundColor Green
} else {
    Grant-SmbShareAccess -Name $NombreShare -AccountName $Usuario -AccessRight Full -Force | Out-Null
    Write-Host "Acceso a '$NombreShare' dado a $Usuario." -ForegroundColor Green
}

$ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
       Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
       Select-Object -First 1).IPAddress
Write-Host ""
Write-Host "LISTO. En la PC no-host, en una Terminal (sin admin), correr UNA vez:" -ForegroundColor Cyan
Write-Host "    cmdkey /add:$ip /user:$env:COMPUTERNAME\$Usuario /pass" -ForegroundColor White
Write-Host "(te pide la clave que elegiste recién; Windows la recuerda para siempre)"
