@echo off
REM ============================================================
REM reconectar-red.bat - PC NO-HOST
REM Re-mapea la unidad Z: a la carpeta compartida de la host.
REM Poner en: shell:startup (se ejecuta al iniciar sesion).
REM Si la IP de la host no es 192.168.100.30, cambiarla abajo.
REM ============================================================
set HOST=192.168.100.30
set SHARE=\\%HOST%\CoppolaPavese

ping -n 1 -w 1500 %HOST% >nul 2>&1
if errorlevel 1 (
    echo ERROR: la PC host ^(%HOST%^) no responde en la red.
    echo Verifique que este encendida y conectada al mismo router.
    pause
    exit /b 1
)

net use Z: /delete /y >nul 2>&1
net use Z: %SHARE% /persistent:yes
if errorlevel 1 (
    echo.
    echo ERROR: la host responde pero no se pudo conectar a %SHARE%.
    echo Si dice "acceso denegado" o pide usuario: falta guardar la clave
    echo del usuario de red ^(una sola vez, ver guia paso B5^):
    echo     cmdkey /add:%HOST% /user:NOMBREPCHOST\cpred /pass
    pause
    exit /b 1
)

if exist "%SHARE%\inmobiliaria.db" (
    echo Conexion OK
) else (
    echo ATENCION: se conecto a %SHARE% pero no esta inmobiliaria.db adentro.
    pause
)
