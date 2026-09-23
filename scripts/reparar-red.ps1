# ============================================================
# reparar-red.ps1 — PC HOST (192.168.100.30)
# Re-aplica la configuración de red que Windows suele "olvidar"
# tras reinicios: perfil Privado, firewall SMB, servicios,
# IP estática y ahorro de energía del adaptador.
# Es idempotente: si todo está bien, no rompe nada.
# Log: %ProgramData%\CoppolaPavese\reparar-red.log
# ============================================================

$ErrorActionPreference = 'Continue'
$logDir  = "$env:ProgramData\CoppolaPavese"
$logFile = "$logDir\reparar-red.log"
$ipHost  = '192.168.100.30'

if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Log($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Add-Content -Path $logFile -Value $line
}

Log "=== Inicio reparación de red ==="

# 1. Perfil de red → Privado (en todos los adaptadores conectados)
Get-NetConnectionProfile | Where-Object { $_.NetworkCategory -ne 'Private' } | ForEach-Object {
    try {
        Set-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -NetworkCategory Private -ErrorAction Stop
        Log "Perfil cambiado a Privado en: $($_.Name)"
    } catch { Log "ERROR perfil privado ($($_.Name)): $_" }
}

# 2. Firewall: reglas SMB-In habilitadas (grupo completo)
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

# 4. IP estática de la host (la re-aplica si se perdió)
try {
    $iface = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
    if ($iface) {
        $tieneIP = Get-NetIPAddress -InterfaceIndex $iface.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                   Where-Object { $_.IPAddress -eq $ipHost }
        if (-not $tieneIP) {
            # Quitar IPs dinámicas conflictivas y asignar la fija
            Get-NetIPAddress -InterfaceIndex $iface.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
            New-NetIPAddress -InterfaceIndex $iface.ifIndex -IPAddress $ipHost `
                -PrefixLength 24 -DefaultGateway '192.168.100.1' -ErrorAction Stop | Out-Null
            Set-DnsClientServerAddress -InterfaceIndex $iface.ifIndex `
                -ServerAddresses ('192.168.100.1', '8.8.8.8') -ErrorAction SilentlyContinue
            Log "IP estática $ipHost re-asignada en $($iface.Name)"
        } else {
            Log "IP estática OK ($ipHost en $($iface.Name))"
        }
    }
} catch { Log "ERROR IP estática: $_" }

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

# 6. Compartido de la carpeta existe y activo
try {
    if (-not (Get-SmbShare -Name 'CoppolaPavese' -ErrorAction SilentlyContinue)) {
        $rutaCarpeta = "C:\CoppolaPavese"
        if (Test-Path $rutaCarpeta) {
            New-SmbShare -Name 'CoppolaPavese' -Path $rutaCarpeta `
                -FullAccess 'Todos' -ErrorAction Stop | Out-Null
            Log "Carpeta compartida 'CoppolaPavese' re-creada"
        } else {
            Log "ADVERTENCIA: no existe $rutaCarpeta para compartir (revisar ruta real)"
        }
    } else {
        Log "Carpeta compartida OK"
    }
} catch { Log "ERROR share: $_" }

Log "=== Fin reparación ==="
