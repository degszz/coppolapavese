@echo off
REM ============================================================
REM abrir-app.bat — LAUNCHER de la app (PCs de la inmobiliaria)
REM El acceso directo del escritorio apunta ACA, no al .exe.
REM 1) Chequea si hay versión nueva en GitHub y actualiza.
REM 2) Abre la app (siempre, haya o no internet/update).
REM Vive en %LocalAppData%\CoppolaPavese\ (lo instala
REM instalar-tarea-actualizacion.ps1).
REM ============================================================
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%LOCALAPPDATA%\CoppolaPavese\actualizar-github.ps1" -Silencioso
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "(Get-Content '%LOCALAPPDATA%\CoppolaPavese\update_config.json' -Raw | ConvertFrom-Json).appDir"`) do set "APPDIR=%%a"
if exist "%APPDIR%\coppolapavese.exe" (
    start "" "%APPDIR%\coppolapavese.exe"
) else (
    echo ERROR: no se encontro la app en "%APPDIR%"
    echo Corra de nuevo scripts\instalar-tarea-actualizacion.ps1
    pause
)
