# ============================================================
# instalar-tarea-red.ps1 — PC HOST (correr UNA VEZ como admin)
# Instala la tarea programada que re-aplica la config de red:
#   - al iniciar sesión (cualquier usuario)
#   - y cada 30 minutos (chequeo idempotente)
# Copia reparar-red.ps1 (que está al lado de este script) a
# C:\CoppolaPavese\scripts\ si todavía no está ahí.
#
# Uso (PowerShell como administrador):
#   powershell -ExecutionPolicy Bypass -File .\instalar-tarea-red.ps1
# ============================================================

$destino    = "C:\CoppolaPavese\scripts"
$scriptPath = Join-Path $destino 'reparar-red.ps1'

$esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $esAdmin) {
    Write-Host 'Este script necesita administrador: click derecho > Ejecutar como administrador.' -ForegroundColor Red
    exit 1
}

# Copiar reparar-red.ps1 al lugar fijo (si se corre desde el pendrive, etc.)
$origen = Join-Path $PSScriptRoot 'reparar-red.ps1'
if ((Test-Path $origen) -and ($origen -ne $scriptPath)) {
    New-Item -ItemType Directory -Path $destino -Force | Out-Null
    Copy-Item $origen $scriptPath -Force
    Write-Host "Copiado reparar-red.ps1 a $destino"
}
if (-not (Test-Path $scriptPath)) {
    Write-Host "No se encontró $scriptPath" -ForegroundColor Red
    Write-Host "Poné reparar-red.ps1 en la misma carpeta que este script y volvé a correrlo."
    exit 1
}
# Quitar el bloqueo de "archivo descargado de internet"
Unblock-File -Path $scriptPath -ErrorAction SilentlyContinue

$accion = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""

$triggerLogon = New-ScheduledTaskTrigger -AtLogOn
# Duración de la repetición: 10 años. Antes se usaba [TimeSpan]::MaxValue,
# que Windows 10 rechaza con error y la tarea nunca se creaba.
$triggerCada30 = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 30) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" `
    -LogonType ServiceAccount -RunLevel Highest

$ajustes = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -StartWhenAvailable

try {
    Register-ScheduledTask -TaskName "CoppolaPavese-RepararRed" `
        -Action $accion -Trigger @($triggerLogon, $triggerCada30) `
        -Principal $principal -Settings $ajustes -Force -ErrorAction Stop | Out-Null
} catch {
    Write-Host "ERROR al crear la tarea: $_" -ForegroundColor Red
    exit 1
}

Write-Host "Tarea 'CoppolaPavese-RepararRed' instalada OK." -ForegroundColor Green
Write-Host "Corre al iniciar sesión y cada 30 minutos. Log en $env:ProgramData\CoppolaPavese\reparar-red.log"
Write-Host "Ejecutándola ahora una vez..."
Start-ScheduledTask -TaskName "CoppolaPavese-RepararRed"
