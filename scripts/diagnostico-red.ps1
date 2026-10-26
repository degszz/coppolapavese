# ============================================================
# diagnostico-red.ps1 — correr en CADA PC (host y no-host)
# Solo LEE información, no cambia nada. Genera un archivo
#   Escritorio\diagnostico-red-<NOMBREPC>.txt
# con todo lo necesario para entender por qué falla la red compartida.
#
# Uso (mejor como administrador, así ve también las carpetas compartidas):
#   powershell -ExecutionPolicy Bypass -File .\diagnostico-red.ps1
#   powershell -ExecutionPolicy Bypass -File .\diagnostico-red.ps1 -IpHost 192.168.0.10
# ============================================================

param([string]$IpHost = '192.168.100.30')

$salida = Join-Path ([Environment]::GetFolderPath('Desktop')) "diagnostico-red-$env:COMPUTERNAME.txt"
$esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

function Seccion($titulo, [scriptblock]$bloque) {
    "`r`n===== $titulo =====" | Out-File $salida -Append -Encoding utf8
    try {
        & $bloque 2>&1 | Out-String -Width 200 | Out-File $salida -Append -Encoding utf8
    } catch {
        "ERROR: $_" | Out-File $salida -Append -Encoding utf8
    }
}

"Diagnóstico de red CoppolaPavese — $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $salida -Encoding utf8
"PC: $env:COMPUTERNAME  Usuario: $env:USERNAME  Admin: $esAdmin  Host esperada: $IpHost" | Out-File $salida -Append -Encoding utf8

Seccion 'Windows' { Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, OSLanguage, MUILanguages }
Seccion 'Adaptadores' { Get-NetAdapter | Select-Object Name, Status, LinkSpeed, MacAddress | Format-Table -AutoSize }
Seccion 'IPs (ipconfig /all)' { ipconfig /all }
Seccion 'Perfil de red (debe ser Private)' { Get-NetConnectionProfile | Select-Object Name, InterfaceAlias, NetworkCategory, IPv4Connectivity | Format-Table -AutoSize }
Seccion 'Servicios de compartir archivos' { Get-Service lanmanserver, lanmanworkstation, fdPHost, FDResPub | Select-Object Name, Status, StartType | Format-Table -AutoSize }
Seccion 'Firewall: perfiles' { Get-NetFirewallProfile | Select-Object Name, Enabled | Format-Table -AutoSize }
Seccion 'Firewall: reglas de compartir archivos (entrada)' {
    Get-NetFirewallRule -Direction Inbound -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayGroup -in 'Compartir archivos e impresoras', 'File and Printer Sharing' -or $_.DisplayName -like 'CoppolaPavese*' } |
        Select-Object DisplayName, Enabled, Profile | Format-Table -AutoSize
}
Seccion 'Carpetas compartidas de esta PC' {
    if ($esAdmin) { Get-SmbShare | Select-Object Name, Path, Description | Format-Table -AutoSize; Get-SmbShareAccess -Name CoppolaPavese -ErrorAction SilentlyContinue | Format-Table -AutoSize }
    else { net share }
}
Seccion 'Acceso anónimo (relacionado con "uso compartido con protección por contraseña")' {
    Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name everyoneincludesanonymous, restrictanonymous -ErrorAction SilentlyContinue
}
Seccion 'Unidades de red mapeadas' { net use }
Seccion "Ping a la host $IpHost" { ping -n 2 $IpHost }
Seccion "Puerto 445 (compartir archivos) en $IpHost" { Test-NetConnection -ComputerName $IpHost -Port 445 -WarningAction SilentlyContinue | Select-Object ComputerName, RemoteAddress, PingSucceeded, TcpTestSucceeded }
Seccion "Acceso a \\$IpHost\CoppolaPavese" {
    $unc = "\\$IpHost\CoppolaPavese"
    "Carpeta accesible: $(Test-Path $unc)"
    "inmobiliaria.db visible: $(Test-Path (Join-Path $unc 'inmobiliaria.db'))"
}
Seccion 'Config de la app (ruta de la base de datos)' {
    $cfg = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'CoppolaPavese\db_config.json'
    if (Test-Path $cfg) { Get-Content $cfg } else { "No existe $cfg" }
}
Seccion 'Tareas programadas CoppolaPavese' { Get-ScheduledTask -TaskName 'CoppolaPavese*' -ErrorAction SilentlyContinue | Select-Object TaskName, State | Format-Table -AutoSize }
Seccion 'Últimas líneas de reparar-red.log' {
    $log = "$env:ProgramData\CoppolaPavese\reparar-red.log"
    if (Test-Path $log) { Get-Content $log -Tail 40 } else { "No existe $log (la tarea nunca corrió en esta PC)" }
}
Seccion 'Política de ejecución de scripts' { Get-ExecutionPolicy -List | Format-Table -AutoSize }

Write-Host "Listo. Diagnóstico guardado en:" -ForegroundColor Green
Write-Host "  $salida"
