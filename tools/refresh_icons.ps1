# Limpia el cache de iconos de Windows y reinicia el Explorer
$iconCacheDir = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
$iconCacheDB  = "$env:LOCALAPPDATA\IconCache.db"

Write-Host "Deteniendo Explorer..."
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 800

# Eliminar IconCache.db (Windows 7/8)
if (Test-Path $iconCacheDB) {
    Remove-Item $iconCacheDB -Force -ErrorAction SilentlyContinue
    Write-Host "IconCache.db eliminado"
}

# Eliminar iconcache_*.db (Windows 10/11)
if (Test-Path $iconCacheDir) {
    Get-ChildItem $iconCacheDir -Filter "iconcache_*.db" | ForEach-Object {
        Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
        Write-Host "Eliminado: $($_.Name)"
    }
}

Write-Host "Reiniciando Explorer..."
Start-Process explorer
Write-Host "Listo! El Explorer se reinicio con cache limpio."
