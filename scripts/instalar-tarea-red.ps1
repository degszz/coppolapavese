# ============================================================
# instalar-tarea-red.ps1 — PC HOST (correr UNA VEZ como admin)
# Instala la tarea programada que re-aplica la config de red:
#   - al iniciar sesión (cualquier usuario)
#   - y cada 30 minutos (chequeo idempotente)
# Requisito: copiar reparar-red.ps1 a C:\CoppolaPavese\scripts\
# (o ajustar $scriptPath abajo).
# ============================================================

$scriptPath = "C:\CoppolaPavese\scripts\reparar-red.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Host "No se encontró $scriptPath"
    Write-Host "Copiá reparar-red.ps1 a esa ubicación y volvé a correr este script."
    exit 1
}

$accion = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""

$triggerLogon = New-ScheduledTaskTrigger -AtLogOn
$triggerCada30 = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 30) `
    -RepetitionDuration ([TimeSpan]::MaxValue)

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" `
    -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "CoppolaPavese-RepararRed" `
    -Action $accion -Trigger @($triggerLogon, $triggerCada30) `
    -Principal $principal -Force | Out-Null

Write-Host "Tarea 'CoppolaPavese-RepararRed' instalada OK."
Write-Host "Corre al iniciar sesión y cada 30 minutos. Log en $env:ProgramData\CoppolaPavese\reparar-red.log"
