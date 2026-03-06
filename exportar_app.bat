@echo off
echo ================================================
echo   Coppola Pavese — Exportar para otra PC
echo ================================================
echo.

cd /d "%~dp0"

set RELEASE_DIR=build\windows\x64\runner\Release
set DESTINO=%USERPROFILE%\Desktop\CoppolaPavese_App

:: Verificar si existe el build
if not exist "%RELEASE_DIR%\coppolapavese.exe" (
    echo La app no esta compilada. Compilando ahora...
    echo.
    call flutter clean >nul 2>&1
    call flutter pub get >nul 2>&1
    call flutter build windows --release
    if errorlevel 1 (
        echo ERROR: El build fallo.
        pause
        exit /b 1
    )
)

:: Copiar al escritorio
echo Copiando archivos al escritorio...
if exist "%DESTINO%" rmdir /s /q "%DESTINO%"
xcopy /e /i /q "%RELEASE_DIR%" "%DESTINO%"

echo.
echo ================================================
echo   LISTO! Carpeta creada en:
echo   %DESTINO%
echo.
echo   Para instalar en otra PC:
echo   1. Copia la carpeta "CoppolaPavese_App" completa
echo   2. En la otra PC, ejecuta "coppolapavese.exe"
echo   3. No necesita instalacion ni Flutter
echo ================================================
echo.
explorer "%DESTINO%"
pause
