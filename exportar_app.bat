@echo off
echo ================================================
echo   Coppola Pavese - Exportar para otra PC
echo ================================================
echo.

cd /d "%~dp0"

set RELEASE_DIR=build\windows\x64\runner\Release
set DESTINO=%USERPROFILE%\Desktop\CoppolaPavese_App

:: Si se pasa el parametro /clean, hace un rebuild completo desde cero
if /i "%1"=="/clean" (
    echo Rebuild completo solicitado. Limpiando...
    call flutter clean >nul 2>&1
    call flutter pub get
    echo.
)

:: Siempre compila - Flutter detecta los cambios y hace build incremental
echo Compilando aplicacion...
echo.
call flutter build windows --release
if errorlevel 1 (
    echo.
    echo ERROR: El build fallo.
    pause
    exit /b 1
)

:: Verificar que el exe se haya creado
if not exist "%RELEASE_DIR%\coppolapavese.exe" (
    echo ERROR: No se encontro el ejecutable despues del build.
    pause
    exit /b 1
)

:: Copiar al escritorio
echo.
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
echo.
echo   TIP: Si ves comportamiento viejo, corre:
echo        exportar_app.bat /clean
echo ================================================
echo.
explorer "%DESTINO%"
pause
