# ============================================================
# publicar.ps1 — PC DE DESARROLLO (tu casa)
# Un solo comando publica TODO:
#   1. Sube automáticamente el número de versión en pubspec.yaml
#   2. flutter build windows --release
#   3. Zip del build → dist\
#   4. git add + commit + push (con tu mensaje)
#   5. GitHub Release con el zip adjunto (tag = versión)
#
# Las PCs de la inmobiliaria detectan la release nueva y se
# actualizan solas antes de abrir la app.
#
# Uso:  .\scripts\publicar.ps1 -mensaje "fix: lo que sea"
# Requisito: que `git push` ya funcione en esta PC (lo hace —
# se reutiliza el mismo token de Git Credential Manager para
# crear la release; no hace falta gh ni login extra).
# ============================================================

param(
    [string]$mensaje = ""
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$repo = 'degszz/coppolapavese'

# ── 0. Token de GitHub (reutiliza las credenciales de git) ───
$credOutput = "protocol=https`nhost=github.com`n" | git credential fill 2>$null
$token = ($credOutput | Select-String '^password=(.+)$').Matches.Groups[1].Value
if (-not $token) {
    Write-Host "ERROR: no se encontraron credenciales de GitHub." -ForegroundColor Red
    Write-Host "Hacé un 'git push' manual una vez para que Windows las guarde." -ForegroundColor Yellow
    exit 1
}
$ghHeaders = @{
    Authorization  = "Bearer $token"
    'User-Agent'   = 'coppolapavese-release'
    Accept         = 'application/vnd.github+json'
}
$apiBase = "https://api.github.com/repos/$repo"

# ── 1. Bump automático de versión en pubspec.yaml ────────────
$pubspec = Join-Path $root 'pubspec.yaml'
$lineas = Get-Content $pubspec
$versionLine = $lineas | Where-Object { $_ -match '^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)' } | Select-Object -First 1
if (-not $versionLine) {
    Write-Host "ERROR: no encontré la línea 'version: X.Y.Z+N' en pubspec.yaml" -ForegroundColor Red
    exit 1
}
$Matches = [regex]::Match($versionLine, '^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)')
$major = [int]$Matches.Groups[1].Value
$minor = [int]$Matches.Groups[2].Value
$patch = [int]$Matches.Groups[3].Value + 1   # sube solo el patch
$build = [int]$Matches.Groups[4].Value + 1
$nuevaVersion = "$major.$minor.$patch"
$nuevaLinea = "version: $nuevaVersion+$build"
$lineas = $lineas -replace [regex]::Escape($versionLine), $nuevaLinea
Set-Content -Path $pubspec -Value $lineas -Encoding UTF8
Write-Host "==> Versión subida a $nuevaVersion (build $build)" -ForegroundColor Cyan

# ── 2. Build ─────────────────────────────────────────────────
Write-Host "==> Compilando (flutter build windows --release)..." -ForegroundColor Cyan
flutter build windows --release
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR en build" -ForegroundColor Red; exit 1 }

# ── 3. Zip ───────────────────────────────────────────────────
$stamp = Get-Date -Format 'yyyyMMdd_HHmm'
$distDir = Join-Path $root 'dist'
if (-not (Test-Path $distDir)) { New-Item -ItemType Directory -Path $distDir | Out-Null }
$zipName = "coppolapavese_v$nuevaVersion.zip"
$zip = Join-Path $distDir $zipName
Write-Host "==> Comprimiendo → $zipName" -ForegroundColor Cyan
Compress-Archive -Path "$root\build\windows\x64\runner\Release\*" -DestinationPath $zip -Force

# ── 4. Git commit + push ─────────────────────────────────────
Write-Host "==> Git commit + push" -ForegroundColor Cyan
if ([string]::IsNullOrWhiteSpace($mensaje)) {
    $mensaje = "release v$nuevaVersion"
} else {
    $mensaje = "$mensaje (v$nuevaVersion)"
}
git add -A
$cambios = git status --porcelain
if ($cambios) {
    git commit -m $mensaje | Out-Null
}
git push origin main
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR en git push" -ForegroundColor Red; exit 1 }

# ── 5. GitHub Release (vía API REST, mismo token de git) ─────
$tag = "v$nuevaVersion"
Write-Host "==> Creando GitHub Release $tag" -ForegroundColor Cyan

# Si la release ya existe (reintento de la misma versión), borrarla:
try {
    $existente = Invoke-RestMethod -Uri "$apiBase/releases/tags/$tag" -Headers $ghHeaders -TimeoutSec 15
    Invoke-RestMethod -Uri "$apiBase/releases/$($existente.id)" -Method Delete -Headers $ghHeaders -TimeoutSec 15 | Out-Null
    Write-Host "Release $tag ya existía; se reemplaza." -ForegroundColor Yellow
} catch { }

$release = Invoke-RestMethod -Uri "$apiBase/releases" -Method Post -Headers $ghHeaders `
    -Body (@{ tag_name = $tag; name = "CoppolaPavese $tag"; body = $mensaje } | ConvertTo-Json) `
    -TimeoutSec 30

$uploadUrl = ($release.upload_url -replace '\{\?.*$', '') + "?name=$zipName"
Invoke-RestMethod -Uri $uploadUrl -Method Post -Headers $ghHeaders `
    -InFile $zip -ContentType 'application/zip' -TimeoutSec 900 | Out-Null

Write-Host ""
Write-Host "════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host " PUBLICADO v$nuevaVersion ✔" -ForegroundColor Green
Write-Host " Las PCs de la inmobiliaria se actualizarán solas al" -ForegroundColor Green
Write-Host " abrir la app (y al iniciar sesión en Windows)." -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════" -ForegroundColor Green
