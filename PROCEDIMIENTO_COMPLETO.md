# Procedimiento Completo — Coppola Pavese Inmobiliaria

> Llevar este archivo en el pendrive junto con la carpeta `CoppolaPavese_App`.

---

## Lo que llevas en el pendrive

| Archivo / Carpeta | Contenido |
|-------------------|-----------|
| `CoppolaPavese_App\` | App compilada (copiar toda la carpeta) |
| `PROCEDIMIENTO_COMPLETO.md` | Este archivo |

---

# SECCION A — Verificaciones rapidas (PC host)

> Hacer esto ANTES de reemplazar la app. Son 2 minutos.

### A1. IP de la host

```powershell
ipconfig | Select-String "192.168"
```

Debe ser `192.168.100.68`. Si es otra, anotala.

### A2. Perfil de red

```powershell
Get-NetConnectionProfile | Select-Object Name, NetworkCategory
```

Debe decir `Private`. Si dice `Public`:

```powershell
$iface = (Get-NetConnectionProfile).InterfaceIndex; Set-NetConnectionProfile -InterfaceIndex $iface -NetworkCategory Private
```

### A3. Carpeta compartida

```powershell
Get-SmbShare -Name "CoppolaPavese" -ErrorAction SilentlyContinue
```

Debe aparecer `CoppolaPavese`. Si no → ir a **Seccion D**.

### A4. Servicios

```powershell
Get-Service -Name lanmanserver, lanmanworkstation | Select-Object Name, Status
```

Ambos `Running`. Si no:

```powershell
Start-Service -Name lanmanserver
Start-Service -Name lanmanworkstation
```

### A5. Ping desde la no-host

En la PC no-host:

```powershell
ping 192.168.100.68
```

### A6. Carpeta desde la no-host

En Explorer: `\\192.168.100.68\CoppolaPavese` — debe verse `inmobiliaria.db`.

---

# SECCION B — Reemplazar la app

### B1. PC HOST

```powershell
# Borrar archivos que bloquean SQLite
Remove-Item "$env:USERPROFILE\Documents\CoppolaPavese\inmobiliaria.db-wal" -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\Documents\CoppolaPavese\inmobiliaria.db-shm" -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\Documents\CoppolaPavese\inmobiliaria.db-journal" -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\Documents\CoppolaPavese\db_config.json" -ErrorAction SilentlyContinue
```

- Copiar `CoppolaPavese_App` del pendrive al escritorio (reemplazar anterior)
- Abrir `coppolapavese.exe`
- **No configurar el engranaje** (usa local, que es donde esta la BD)
- Verificar que muestra datos reales

### B2. PC NO-HOST

- Copiar `CoppolaPavese_App` del pendrive al escritorio
- Abrir `coppolapavese.exe`
- Si carga los datos → listo
- Si muestra todo en 0 → engranaje → Ruta: `\\192.168.100.68\CoppolaPavese` → Diagnosticar → Guardar

### B3. Prueba de encendido

1. Cerrar app en todas las PCs
2. Apagar todas las PCs
3. Encender primero la host, esperar 1 minuto
4. Encender la no-host
5. Abrir la app en la no-host → debe cargar datos sola

---

# SECCION C — Exportar video para TV (vidriera)

### C1. Generar el video

1. Pestaña **Propiedades** → icono de videocamara (arriba derecha)
2. Elegir carpeta destino (ej. el pendrive `E:\`)
3. Aparece un dialogo con barra de progreso
4. La primera vez descarga FFmpeg (~40 MB, 30 segundos, necesita internet)
5. Al terminar, dialogo verde: **"Video listo"** con boton **"Abrir carpeta"**

Tiempo estimado: 2-3 minutos para 10-15 propiedades.

### C2. Reproducir en el TV

1. Conectar pendrive al puerto USB del TV
2. Abrir con el reproductor de video nativo
3. Seleccionar `slideshow.mp4`
4. Menu del TV → **Repetir** (loop infinito)

---

# SECCION D — Plan B (solo si la Seccion A fallo)

### B1. IP cambio

Usar la nueva IP en el ping y en la ruta de la no-host.

### B2. Perfil Public

```powershell
$iface = (Get-NetConnectionProfile).InterfaceIndex
Set-NetConnectionProfile -InterfaceIndex $iface -NetworkCategory Private
```

### B3. Carpeta no compartida

1. Explorer → `C:\Users\Inmobiliaria\Documents\CoppolaPavese`
2. Clic derecho → Propiedades → Compartir → Uso compartido avanzado
3. Tildar "Compartir esta carpeta", nombre: `CoppolaPavese`
4. Permisos → Todos → Control total
5. Pestana Seguridad → Editar → Agregar → `Todos` → Control total

### B4. Servicios detenidos

```powershell
Set-Service -Name lanmanserver -StartupType Automatic
Set-Service -Name lanmanworkstation -StartupType Automatic
Start-Service -Name lanmanserver
Start-Service -Name lanmanworkstation
```

### B5. Firewall

```powershell
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes
```

---

## Que cambia en esta version

| Fix | Que hace |
|-----|----------|
| Red compartida | Si la carpeta de red no esta accesible, la app usa BD local y muestra un dialogo con opciones (Reintentar / Configurar / Usar local) |
| Input "Va por" | Ya no se desborda en el periodo 1 del formulario de contratos |
| Exportar video | Nuevo boton en Propiedades que genera `slideshow.mp4` para TV |

### Dial de red caida

Si al abrir la app la carpeta compartida no responde:

```
Carpeta de red no disponible
La base de datos compartida en:
\\192.168.100.68\CoppolaPavese
no esta accesible.

[Usar local por ahora] [Configurar ruta] [Reintentar conexion]
```

---

## Resumen rapido

| # | Donde | Que hacer |
|---|-------|-----------|
| 1 | Host | Borrar WAL/SHM/journal, copiar app, verificar datos |
| 2 | No-host | Copiar app, configurar `\\192.168.100.68\CoppolaPavese` si no carga |
| 3 | Prueba | Apagar todo → encender host 1ro → encender no-host → verificar |
| 4 | Video | Propiedades → videocamara → elegir pendrive → copiar `slideshow.mp4` al TV |
