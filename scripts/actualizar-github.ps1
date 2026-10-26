# ============================================================
# actualizar-github.ps1 — PCs DE LA INMOBILIARIA
# Chequea si hay una versión nueva de la app en GitHub Releases
# y, si la hay, la descarga e instala.
#
# - Lee la config de %LocalAppData%\CoppolaPavese\update_config.json
#   (la crea instalar-tarea-actualizacion.ps1; ahí está la ruta
#    de la carpeta de la app de ESA PC — nada hardcodeado).
# - Nunca toca la base de datos: si la carpeta de la app tiene
#   inmobiliaria.db adentro, NO actualiza (avisa en el log).
# - Si no hay internet o GitHub no responde, sale rápido sin
#   hacer nada (la app abre igual).
# - Hace backup de la versión anterior antes de reemplazar y lo
#   restaura si la copia falla.
# Log: %LocalAppData%\CoppolaPavese\update.log
#
# Uso manual (para probar o forzar):
#   powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\CoppolaPavese\actualizar-github.ps1"
# ============================================================

param(
    [switch]$Silencioso   # sin mensajes emergentes
)

$ErrorActionPreference = 'Continue'
# Windows 10 con PowerShell 5.1 usa TLS viejo por defecto y GitHub lo
# rechaza: sin esto el updater creía que "no había internet" y nunca
# actualizaba.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# La barra de progreso de PowerShell 5.1 hace la descarga 10 veces más lenta.
$ProgressPreference = 'SilentlyContinue'

$repo = 'degszz/coppolapavese'
$cfgDir  = "$env:LOCALAPPDATA\CoppolaPavese"
$cfgFile = "$cfgDir\update_config.json"
$logFile = "$cfgDir\update.log"
$lockFile = "$cfgDir\actualizando.lock"

if (-not (Test-Path $cfgDir)) { New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null }

function Log($msg) {
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $env:COMPUTERNAME, $msg
    Add-Content -Path $logFile -Value $line -ErrorAction SilentlyContinue
}

function Avisar($texto) {
    if (-not $Silencioso) {
        try { msg * /TIME:15 $texto 2>$null } catch {}
    }
}

# ── Evitar dos actualizaciones a la vez (doble clic en el acceso directo)
if (Test-Path $lockFile) {
    $edad = (Get-Date) - (Get-Item $lockFile).LastWriteTime
    if ($edad.TotalMinutes -lt 15) { Log "Ya hay una actualización en curso. Se omite."; exit 0 }
}
Set-Content -Path $lockFile -Value (Get-Date) -ErrorAction SilentlyContinue

try {
    # ── Leer config ──────────────────────────────────────────
    if (-not (Test-Path $cfgFile)) {
        Log "Sin config ($cfgFile). Correr instalar-tarea-actualizacion.ps1."
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
    # Protección: la actualización copia en espejo y borraría todo lo que
    # no venga en el zip. Si la base está en la misma carpeta, NO seguir.
    if (Test-Path "$appDir\inmobiliaria.db") {
        Log "ERROR: $appDir tiene inmobiliaria.db adentro. La app tiene que estar en su propia carpeta (ver docs/red-compartida.md). No se actualiza."
        exit 1
    }

    # ── Consultar GitHub (timeout corto: sin internet = salir rápido)
    try {
        $release = Invoke-RestMethod `
            -Uri "https://api.github.com/repos/$repo/releases/latest" `
            -Headers @{ 'User-Agent' = 'coppolapavese-updater' } `
            -TimeoutSec 8 -UseBasicParsing
    } catch {
        Log "No se pudo consultar GitHub (sin internet, GitHub caído o límite de consultas): $($_.Exception.Message)"
        exit 0
    }

    $tag = $release.tag_name                       # ej. "v1.0.5"
    $versionRemota = [version]($tag.TrimStart('v'))

    if ($versionRemota -le $versionLocal) {
        Log "Ya está actualizada (local v$versionLocal, GitHub $tag)."
        exit 0
    }

    Log "Nueva versión disponible: $tag (local: v$versionLocal). Descargando..."

    # ── Descargar el zip de la release ───────────────────────
    $asset = $release.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1
    if (-not $asset) {
        Log "ERROR: la release $tag no tiene zip adjunto. Se omite."
        exit 1
    }
    $tmpZip = "$env:TEMP\coppolapavese_$tag.zip"
    try {
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmpZip -TimeoutSec 600 -UseBasicParsing
    } catch {
        Log "ERROR descargando: $($_.Exception.Message)"
        exit 1
    }

    # ── Descomprimir ANTES de tocar la app (si el zip está roto, no se cierra nada)
    $tmpDir = "$env:TEMP\coppolapavese_$tag"
    try {
        if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
        Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force
    } catch {
        Log "ERROR descomprimiendo el zip: $($_.Exception.Message)"
        exit 1
    }
    if (-not (Test-Path "$tmpDir\coppolapavese.exe")) {
        Log "ERROR: el zip de $tag no trae coppolapavese.exe. Se omite."
        exit 1
    }

    # ── Cerrar la app si está abierta ────────────────────────
    $proceso = Get-Process -Name 'coppolapavese' -ErrorAction SilentlyContinue
    if ($proceso) {
        Log "App abierta: se cierra para actualizar."
        Stop-Process -Name 'coppolapavese' -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
    }

    # ── Backup de la versión actual ──────────────────────────
    $backupDir = "$cfgDir\backup_v$versionLocal"
    try {
        if (Test-Path $backupDir) { Remove-Item $backupDir -Recurse -Force }
        Copy-Item $appDir $backupDir -Recurse -Force -ErrorAction Stop
        Log "Backup en $backupDir"
    } catch {
        Log "ERROR backup: $($_.Exception.Message). Se omite la actualización por seguridad."
        exit 1
    }

    # ── Reemplazar. robocopy no tira excepciones: hay que mirar su código
    #    de salida (0-7 = OK, 8 o más = falló). Nunca tocar archivos de base.
    $excluir = @('*.db', '*.db-journal', '*.db-wal', '*.db-shm')
    robocopy $tmpDir $appDir /MIR /XF $excluir /NFL /NDL /NJH /NJS /R:3 /W:2 | Out-Null
    $rc = $LASTEXITCODE
    if ($rc -ge 8) {
        Log "ERROR copiando archivos (robocopy $rc). Restaurando backup..."
        robocopy $backupDir $appDir /MIR /XF $excluir /NFL /NDL /NJH /NJS /R:3 /W:2 | Out-Null
        Log "Backup restaurado (robocopy $LASTEXITCODE). Sigue la versión v$versionLocal."
        exit 1
    }
    Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue

    # ── Marcar versión instalada ─────────────────────────────
    $cfg.version = "$versionRemota"
    $cfg | ConvertTo-Json | Set-Content $cfgFile -Encoding UTF8

    Log "ACTUALIZADA a $tag OK"
    Avisar "La aplicacion se actualizo a la version $versionRemota. Si la tenias abierta, volve a abrirla."
}
finally {
    Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
}
