@echo off
echo ================================================
echo   Coppola Pavese Inmobiliaria Modo desarrollo
echo ================================================
echo.

cd /d "%~dp0"

echo [1/3] Limpiando build anterior...
call flutter clean >nul 2>&1

echo [2/3] Restaurando dependencias...
call flutter pub get
if errorlevel 1 (
    echo ERROR: flutter pub get fallo. Verificar conexion a internet.
    pause
    exit /b 1
)

echo [3/3] Iniciando la aplicacion...
echo.
call flutter run -d windows
pause
