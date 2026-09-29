# ============================================================
# actualizar-github.ps1 — PCs DE LA INMOBILIARIA
# Chequea si hay una versión nueva de la app en GitHub Releases
# y, si la hay, la descarga e instala.
#
# - Lee la config de %LocalAppData%\CoppolaPavese\update_config.json
#   (la crea instalar-tarea-actualizacion.ps1; ahí está la ruta
#    de la carpeta de la app de ESA PC — nada hardcodeado).
# - Nunca toca la base de datos (vive en la carpeta de red).
# - Si no hay internet o GitHub no responde, sale rápido sin
#   hacer nada (la app abre igual).
# - Hace backup de la versión anterior antes de reemplazar.
# Log: %LocalAppData%\CoppolaPavese\update.log
# ============================================================

param(
    [switch]$Silencioso   # sin mensajes emergentes
)

$ErrorActionPreference = 'Continue'
$repo = 'degszz/coppolapavese'
$cfgDir  = "$env:LOCALAPPDATA\CoppolaPavese"
$cfgFile = "$cfgDir\update_config.json"
$logFile = "$cfgDir\update.log"

if (-not (Test-Path $cfgDir)) { New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null }

function Log($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Add-Content -Path $logFile -Value $line -ErrorAction SilentlyContinue
}

function Avisar($texto) {
    if (-not $Silencioso) {
        try { msg * /TIME:15 $texto 2>$null } catch {}
    }
}

# ── Leer config ──────────────────────────────────────────────
if (-not (Test-Path $cfgFile)) {
    Log "Sin config ($cfgFile). Nada que hacer."
    exit 0
}
$cfg = Get-Content $cfgFile -Raw | ConvertFrom-Json
$appDir  = $cfg.appDir
$exe     = "$appDir\coppolapavese.exe"
$versionLocal = [version]($cfg.version)

if (-not (Test-Path $exe)) {
    Log "No existe $exe — config inválida o app desinstalada. Se omite."
    exit 0
}

# ── Consultar GitHub (timeout corto: sin internet = salir rápido)
try {
    $release = Invoke-RestMethod `
        -Uri "https://api.github.com/repos/$repo/releases/latest" `
        -Headers @{ 'User-Agent' = 'coppolapavese-updater' } `
        -TimeoutSec 8
} catch {
    Log "Sin internet o GitHub inaccesible. Se omite sin error."
    exit 0
}

$tag = $release.tag_name                       # ej. "v1.0.3"
$versionRemota = [version]($tag.TrimStart('v'))

if ($versionRemota -le $versionLocal) {
    Log "Ya está actualizada ($tag)."
    exit 0
}

Log "Nueva versión disponible: $tag (local: v$versionLocal). Descargando..."

# ── Descargar el zip de la release ───────────────────────────
$asset = $release.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1
if (-not $asset) {
    Log "ERROR: la release $tag no tiene zip adjunto. Se omite."
    exit 1
}
$tmpZip = "$env:TEMP\coppolapavese_$tag.zip"
try {
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmpZip -TimeoutSec 600
} catch {
    Log "ERROR descargando: $_"
    exit 1
}

# ── Cerrar la app si está abierta ────────────────────────────
$proceso = Get-Process -Name 'coppolapavese' -ErrorAction SilentlyContinue
if ($proceso) {
    Log "App abierta: se cierra para actualizar."
    Stop-Process -Name 'coppolapavese' -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

# ── Backup de la versión actual ──────────────────────────────
$backupDir = "$env:LOCALAPPDATA\CoppolaPavese\backup_v$versionLocal"
try {
    if (Test-Path $backupDir) { Remove-Item $backupDir -Recurse -Force }
    Copy-Item $appDir $backupDir -Recurse -Force
    Log "Backup en $backupDir"
} catch {
    Log "ERROR backup: $_. Se omite la actualización por seguridad."
    exit 1
}

# ── Descomprimir y reemplazar (robocopy esquivo a archivos en uso)
$tmpDir = "$env:TEMP\coppolapavese_$tag"
try {
    if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
    Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force
    robocopy $tmpDir $appDir /MIR /NFL /NDL /NJH /NJS /R:2 /W:2 | Out-Null
    Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
} catch {
    Log "ERROR instalando: $_. Restaurando backup..."
    robocopy $backupDir $appDir /MIR /NFL /NDL /NJH /NJS | Out-Null
    Log "Backup restaurado."
    exit 1
}

# ── Marcar versión instalada ─────────────────────────────────
$cfg.version = "$versionRemota"
$cfg | ConvertTo-Json | Set-Content $cfgFile -Encoding UTF8

Log "ACTUALIZADA a $tag ✔"
Avisar "La aplicacion se actualizo a la version $versionRemota. Si la tenias abierta, volve a abrirla."
