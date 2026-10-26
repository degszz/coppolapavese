# ============================================================
# reparar-red.ps1 — PC HOST
# Re-aplica la configuración de red que Windows suele "olvidar"
# tras reinicios: perfil Privado, firewall SMB, servicios,
# IP fija, ahorro de energía del adaptador y carpeta compartida.
# Es idempotente: si todo está bien, no rompe nada.
# Requiere administrador (la tarea programada lo corre como SYSTEM).
# Log: %ProgramData%\CoppolaPavese\reparar-red.log
#
# Uso manual (PowerShell como administrador):
#   powershell -ExecutionPolicy Bypass -File .\reparar-red.ps1
# ============================================================

param(
    # IP fija que debe tener la PC host
    [string]$IpHost = '192.168.100.30',
    # Carpeta local que se comparte en la red
    [string]$RutaCarpeta = 'C:\CoppolaPavese',
    [string]$NombreShare = 'CoppolaPavese'
)

$ErrorActionPreference = 'Continue'
$logDir  = "$env:ProgramData\CoppolaPavese"
$logFile = "$logDir\reparar-red.log"

if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Log($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

$esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $esAdmin) {
    Write-Host 'Este script necesita administrador: click derecho > Ejecutar como administrador.' -ForegroundColor Red
    exit 1
}

Log "=== Inicio reparación de red ==="

# 1. Perfil de red → Privado (en todos los adaptadores conectados)
Get-NetConnectionProfile | Where-Object { $_.NetworkCategory -ne 'Private' } | ForEach-Object {
    try {
        Set-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -NetworkCategory Private -ErrorAction Stop
        Log "Perfil cambiado a Privado en: $($_.Name)"
    } catch { Log "ERROR perfil privado ($($_.Name)): $_" }
}

# 2. Firewall: reglas de compartir archivos (Windows en español o inglés)
try {
    Enable-NetFirewallRule -DisplayGroup "Compartir archivos e impresoras" -ErrorAction SilentlyContinue
    Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing" -ErrorAction SilentlyContinue
    # Regla explícita puerto 445 por si el grupo no existe
    if (-not (Get-NetFirewallRule -DisplayName "CoppolaPavese-SMB-445" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName "CoppolaPavese-SMB-445" `
            -Direction Inbound -Protocol TCP -LocalPort 445 `
            -Action Allow -Profile Private -ErrorAction Stop | Out-Null
        Log "Regla firewall SMB-445 creada"
    } else {
        Enable-NetFirewallRule -DisplayName "CoppolaPavese-SMB-445" -ErrorAction SilentlyContinue
    }
    Log "Firewall SMB OK"
} catch { Log "ERROR firewall: $_" }

# 3. Servicios SMB en automático y corriendo
foreach ($svc in 'lanmanserver', 'lanmanworkstation') {
    try {
        Set-Service -Name $svc -StartupType Automatic -ErrorAction Stop
        $s = Get-Service -Name $svc
        if ($s.Status -ne 'Running') {
            Start-Service -Name $svc -ErrorAction Stop
            Log "Servicio $svc iniciado"
        }
    } catch { Log "ERROR servicio $svc : $_" }
}
Log "Servicios lanmanserver/lanmanworkstation OK"

# 4. IP fija de la host.
#    Solo la re-aplica si la PC está en la MISMA red (mismos 3 primeros
#    números). Antes borraba todas las IPs aunque el router usara otra red,
#    y la PC quedaba sin conexión.
try {
    $redEsperada = ($IpHost -split '\.')[0..2] -join '.'
    $iface = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
    if ($iface) {
        $ips = @(Get-NetIPAddress -InterfaceIndex $iface.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue)
        if ($ips.IPAddress -contains $IpHost) {
            Log "IP fija OK ($IpHost en $($iface.Name))"
        } else {
            $actual = ($ips | Select-Object -First 1).IPAddress
            $redActual = if ($actual) { ($actual -split '\.')[0..2] -join '.' } else { '' }
            if ($redActual -eq $redEsperada) {
                $gw = (Get-NetRoute -InterfaceIndex $iface.ifIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
                       Select-Object -First 1).NextHop
                if (-not $gw) { $gw = "$redEsperada.1" }
                $ips | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
                Remove-NetRoute -InterfaceIndex $iface.ifIndex -DestinationPrefix '0.0.0.0/0' -Confirm:$false -ErrorAction SilentlyContinue
                Set-NetIPInterface -InterfaceIndex $iface.ifIndex -Dhcp Disabled -ErrorAction SilentlyContinue
                New-NetIPAddress -InterfaceIndex $iface.ifIndex -IPAddress $IpHost `
                    -PrefixLength 24 -DefaultGateway $gw -ErrorAction Stop | Out-Null
                Set-DnsClientServerAddress -InterfaceIndex $iface.ifIndex `
                    -ServerAddresses ($gw, '8.8.8.8') -ErrorAction SilentlyContinue
                Log "IP fija $IpHost re-asignada en $($iface.Name) (antes $actual, gateway $gw)"
            } else {
                Log "ADVERTENCIA: la PC tiene IP $actual y no está en la red $redEsperada.x. No se cambió nada. Revisar la IP del router y correr con -IpHost <ip correcta>."
            }
        }
    }
} catch { Log "ERROR IP fija: $_" }

# 5. Desactivar ahorro de energía del adaptador (evita que Windows lo apague)
try {
    $adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' }
    foreach ($a in $adapters) {
        $pow = Get-NetAdapterPowerManagement -Name $a.Name -ErrorAction SilentlyContinue
        if ($pow -and $pow.AllowComputerToTurnOffDevice -ne 'Disabled') {
            Disable-NetAdapterPowerManagement -Name $a.Name -ErrorAction SilentlyContinue
            Log "Ahorro de energía desactivado en $($a.Name)"
        }
    }
} catch { Log "ERROR ahorro energía: $_" }

# 6. Carpeta compartida existe y activa.
#    "Todos" se resuelve por su identificador (S-1-1-0) para que funcione
#    en Windows en español ("Todos") y en inglés ("Everyone").
try {
    $todos = ([System.Security.Principal.SecurityIdentifier]'S-1-1-0').Translate(
                [System.Security.Principal.NTAccount]).Value
    $share = Get-SmbShare -Name $NombreShare -ErrorAction SilentlyContinue
    if (-not $share) {
        if (Test-Path $RutaCarpeta) {
            New-SmbShare -Name $NombreShare -Path $RutaCarpeta `
                -FullAccess $todos -ErrorAction Stop | Out-Null
            Log "Carpeta compartida '$NombreShare' re-creada ($RutaCarpeta, acceso total: $todos)"
        } else {
            Log "ADVERTENCIA: no existe $RutaCarpeta para compartir. Correr con -RutaCarpeta <ruta real>."
        }
    } else {
        Log "Carpeta compartida OK ($($share.Path))"
        if (-not (Test-Path (Join-Path $share.Path 'inmobiliaria.db'))) {
            Log "ADVERTENCIA: no hay inmobiliaria.db dentro de $($share.Path)"
        }
    }
} catch { Log "ERROR share: $_" }

Log "=== Fin reparación ==="
