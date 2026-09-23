# ============================================================
# publicar.ps1 — PC DE DESARROLLO
# Flujo completo post-sesión de cambios:
#   1. flutter build windows --release
#   2. Comprime build\Release → dist\coppolapavese_YYYYMMDD_HHmm.zip
#   3. Copia el zip a la carpeta de red (si está accesible)
#   4. git add + commit + push (si hay cambios pendientes)
# Uso:  .\scripts\publicar.ps1 -mensaje "fix: lo que sea"
# ============================================================

param(
    [string]$mensaje = "update: cambios varios",
    [string]$destinoRed = "\\192.168.100.30\CoppolaPavese\app"
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "==> Compilando..." -ForegroundColor Cyan
flutter build windows --release
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR en build" -ForegroundColor Red; exit 1 }

$stamp = Get-Date -Format 'yyyyMMdd_HHmm'
$distDir = Join-Path $root 'dist'
if (-not (Test-Path $distDir)) { New-Item -ItemType Directory -Path $distDir | Out-Null }
$zip = Join-Path $distDir "coppolapavese_$stamp.zip"

Write-Host "==> Comprimiendo → $zip" -ForegroundColor Cyan
Compress-Archive -Path "$root\build\windows\x64\runner\Release\*" `
    -DestinationPath $zip -Force

if (Test-Path $destinoRed) {
    Write-Host "==> Copiando a $destinoRed" -ForegroundColor Cyan
    Copy-Item $zip $destinoRed -Force
    Write-Host "Copiado. En la inmobiliaria correr actualizar.bat" -ForegroundColor Green
} else {
    Write-Host "Carpeta de red no accesible. El zip quedó en: $zip" -ForegroundColor Yellow
    Write-Host "Copialo manualmente a \\192.168.100.30\CoppolaPavese\app" -ForegroundColor Yellow
}

Write-Host "==> Git commit + push" -ForegroundColor Cyan
git add -A
$cambios = git status --porcelain
if ($cambios) {
    git commit -m $mensaje
    git push origin main
    Write-Host "Subido a GitHub ✔" -ForegroundColor Green
} else {
    Write-Host "Sin cambios pendientes en git." -ForegroundColor Yellow
}

Write-Host "`nListo." -ForegroundColor Green
