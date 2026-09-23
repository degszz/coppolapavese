@echo off
REM ============================================================
REM reconectar-red.bat — PC NO-HOST
REM Re-mapea la unidad a la carpeta compartida de la host.
REM Poner en: shell:startup (se ejecuta al iniciar sesión).
REM ============================================================
net use Z: /delete /y >nul 2>&1
net use Z: \\192.168.100.30\CoppolaPavese /persistent:yes >nul 2>&1
if exist "\\192.168.100.30\CoppolaPavese\inmobiliaria.db" (
    echo Conexion OK
) else (
    echo ERROR: no se pudo acceder a la carpeta compartida.
    echo Verifique que la PC host este encendida y conectada.
    pause
)
