@echo off
REM ============================================================
REM actualizar.bat — PCs DE LA INMOBILIARIA (host y no-host)
REM Descarga la última versión de la app desde la carpeta de red
REM y reemplaza la carpeta local de la app.
REM No requiere Git ni Flutter.
REM Ajustar APP_DIR si la app está instalada en otra carpeta.
REM ============================================================
setlocal
set APP_DIR=C:\CoppolaPavese\app
set RED_DIR=\\192.168.100.30\CoppolaPavese\app

echo Cerrando la app si esta abierta...
taskkill /IM coppolapavese.exe /F >nul 2>&1

echo Buscando el ultimo zip en %RED_DIR% ...
for /f "delims=" %%f in ('dir /b /o-n "%RED_DIR%\coppolapavese_*.zip" 2^>nul') do (
    set ZIP=%%f
    goto :encontrado
)
echo ERROR: no se encontro ningun zip en %RED_DIR%
pause
exit /b 1

:encontrado
echo Actualizando con %ZIP% ...
if not exist "%APP_DIR%" mkdir "%APP_DIR%"
powershell -NoProfile -Command "Expand-Archive -Path '%RED_DIR%\%ZIP%' -DestinationPath '%APP_DIR%' -Force"
if errorlevel 1 (
    echo ERROR al descomprimir.
    pause
    exit /b 1
)
echo.
echo Actualizacion completa. Ya podes abrir la app.
pause
