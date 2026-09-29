# ============================================================
# instalar-tarea-actualizacion.ps1 — PCs DE LA INMOBILIARIA
# Correr UNA VEZ por PC (doble clic con permisos normales,
# NO hace falta admin). Hace 4 cosas:
#
# 1. Te pregunta DÓNDE está la carpeta de la app (explorador
#    de carpetas — no hace falta saber la ruta de memoria).
# 2. Copia el updater y el launcher a %LocalAppData%\CoppolaPavese.
# 3. Repunta el acceso directo del escritorio al launcher
#    (asi la app se actualiza ANTES de abrirse).
# 4. Crea una tarea programada que también chequea updates
#    al iniciar sesión (por si no la abrieron en todo el día).
#
# Nada queda hardcodeado: la ruta se guarda en
# %LocalAppData%\CoppolaPavese\update_config.json
# ============================================================

$ErrorActionPreference = 'Stop'
$cfgDir = "$env:LOCALAPPDATA\CoppolaPavese"
if (-not (Test-Path $cfgDir)) { New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null }

Write-Host ""
Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "  INSTALADOR — Auto-actualización CoppolaPavese" -ForegroundColor Magenta
Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

# ── 1. Elegir la carpeta de la app ───────────────────────────
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$dialog = New-Object System.Windows.Forms.FolderBrowserDialog
$dialog.Description = "Seleccioná la carpeta donde está instalada la app (la que contiene coppolapavese.exe — normalmente está en el Escritorio)"
$dialog.ShowNewFolderButton = $false
$dialog.SelectedPath = [Environment]::GetFolderPath('Desktop')

$appDir = $null
while ($true) {
    if ($dialog.ShowDialog() -eq 'OK') {
        $appDir = $dialog.SelectedPath
        if (Test-Path "$appDir\coppolapavese.exe") {
            break
        }
        [System.Windows.Forms.MessageBox]::Show(
            "En esa carpeta no está coppolapavese.exe.`nElegí la carpeta correcta de la app.",
            "Carpeta incorrecta", 'OK', 'Warning') | Out-Null
    } else {
        Write-Host "Cancelado por el usuario." -ForegroundColor Yellow
        exit 1
    }
}
Write-Host "Carpeta de la app: $appDir" -ForegroundColor Cyan

# ── 2. Guardar config + copiar updater/launcher ──────────────
# La versión local inicial se infiere si la app ya fue
# actualizada antes; si no, 0.0.0 (fuerza update al 1er chequeo
# solo si GitHub tiene algo más nuevo).
$configPath = "$cfgDir\update_config.json"
if (Test-Path $configPath) {
    $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
    $cfg.appDir = $appDir
} else {
    $cfg = [PSCustomObject]@{
        appDir    = $appDir
        version   = "0.0.0"
        instalado = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    }
}
$cfg | ConvertTo-Json | Set-Content $configPath -Encoding UTF8

$origenScripts = $PSScriptRoot
Copy-Item "$origenScripts\actualizar-github.ps1" "$cfgDir\actualizar-github.ps1" -Force
Copy-Item "$origenScripts\abrir-app.bat"         "$cfgDir\abrir-app.bat" -Force
Write-Host "Updater y launcher copiados a $cfgDir" -ForegroundColor Cyan

# ── 3. Repuntar acceso directo del escritorio ────────────────
$launcher = "$cfgDir\abrir-app.bat"
$escritorioUser  = [Environment]::GetFolderPath('Desktop')
$escritorioTodos = [Environment]::GetFolderPath('CommonDesktopDirectory')
$shell = New-Object -ComObject WScript.Shell
$accesoReemplazado = $false

foreach ($desk in @($escritorioUser, $escritorioTodos)) {
    Get-ChildItem $desk -Filter *.lnk -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $lnk = $shell.CreateShortcut($_.FullName)
            if ($lnk.TargetPath -match 'coppolapavese\.exe$' -or $lnk.Arguments -match 'coppolapavese') {
                $lnk.TargetPath = $launcher
                $lnk.IconLocation = "$appDir\coppolapavese.exe,0"
                $lnk.WorkingDirectory = $appDir
                $lnk.Description = "CoppolaPavese Inmobiliaria (con auto-actualización)"
                $lnk.Save()
                Write-Host "Acceso directo repuntado: $($_.FullName)" -ForegroundColor Cyan
                $accesoReemplazado = $true
            }
        } catch {}
    }
}

if (-not $accesoReemplazado) {
    Write-Host "No encontré acceso directo de la app en el escritorio; creo uno nuevo." -ForegroundColor Yellow
    $lnkNuevo = $shell.CreateShortcut("$escritorioUser\CoppolaPavese Inmobiliaria.lnk")
    $lnkNuevo.TargetPath = $launcher
    $lnkNuevo.IconLocation = "$appDir\coppolapavese.exe,0"
    $lnkNuevo.WorkingDirectory = $appDir
    $lnkNuevo.Description = "CoppolaPavese Inmobiliaria (con auto-actualización)"
    $lnkNuevo.Save()
}

# ── 4. Tarea programada: chequear update al iniciar sesión ───
$accion = New-ScheduledTaskAction -Execute $launcher
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel LeastPrivilege

Register-ScheduledTask -TaskName "CoppolaPavese-Actualizar" `
    -Action $accion -Trigger $trigger -Principal $principal -Force | Out-Null
Write-Host "Tarea 'CoppolaPavese-Actualizar' instalada (corre al iniciar sesión)." -ForegroundColor Cyan

# ── 5. Primer chequeo ahora ──────────────────────────────────
Write-Host ""
Write-Host "Haciendo primer chequeo de actualización..." -ForegroundColor Cyan
& powershell -NoProfile -ExecutionPolicy Bypass -File "$cfgDir\actualizar-github.ps1"

Write-Host ""
Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host " INSTALADO ✔" -ForegroundColor Green
Write-Host " - La app se actualiza sola al abrirla (acceso directo)." -ForegroundColor Green
Write-Host " - También al iniciar sesión en Windows." -ForegroundColor Green
Write-Host " - Log: $cfgDir\update.log" -ForegroundColor Green
Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Green
Read-Host "`nPresioná Enter para cerrar"
