# Instalación, red compartida y auto-actualización — CoppolaPavese

Guía completa y ordenada. Leé primero la sección **0. Conceptos** — a partir
de ahí, cada paso es copiar/ejecutar.

---

## 0. Conceptos clave (para entender QUÉ se puede tocar y QUÉ no)

| Cosas | Dónde vive | ¿Se copia/mueve? |
|---|---|---|
| **La app** (`coppolapavese.exe` + archivos) | Una carpeta en cada PC (Escritorio) | Se ACTUALIZA sola desde GitHub. Nunca lleva datos. |
| **La base de datos** (`inmobiliaria.db`) | UNA SOLA, en la carpeta compartida `\\192.168.100.30\CoppolaPavese` | **NUNCA se copia ni se reemplaza de una PC a otra.** Solo backup. |
| **Config de red** | PC host (perfil Privado, firewall, share) | Se asegura sola con una tarea programada (cada 30 min + al iniciar sesión). |
| **Código fuente** | GitHub (`degszz/coppolapavese`, repo público) | Push desde tu PC. Las releases llevan el zip de la app. |

**Regla de oro:** la BD viaja por la red, no por pendrive ni por GitHub.
Los cambios de la app viajan por GitHub, no por pendrive (después de esta
visita inicial).

---

## 1. Qué llevar en el pendrive (última visita a la inmobiliaria)

1. El **zip más reciente de la app** → de tu repo, carpeta `dist\`
   (ej. `dist\coppolapavese_v1.0.1.zip`), o lo bajás de
   https://github.com/degszz/coppolapavese/releases/latest
2. La carpeta **`scripts\` completa** del repo:
   - `reparar-red.ps1`
   - `instalar-tarea-red.ps1`
   - `reconectar-red.bat`
   - `limpiar-prorrogas-fantasma.sql`
   - `actualizar.bat` (de respaldo manual, por las dudas)
   - `actualizar-github.ps1`
   - `abrir-app.bat`
   - `instalar-tarea-actualizacion.ps1`
3. `sqlite3.exe` (portable; lo tenés en `C:\sqlite3\sqlite3.exe`)
4. Este archivo `.md` para tener los pasos offline.

---

## 2. PC HOST (la que comparte la carpeta — 192.168.100.30)

Hacerlo **con la app cerrada en ambas PCs**, y en este orden:

### 2.1 Backup de la base de datos (nunca saltees esto)

```
En la carpeta compartida (accedida localmente en la host):
  copiar inmobiliaria.db  →  inmobiliaria_backup_AAAAMMDD.db
```

### 2.2 Red compartida — solución permanente

1. Crear la carpeta `C:\CoppolaPavese\scripts\` en la host y pegar ahí
   `reparar-red.ps1` e `instalar-tarea-red.ps1`.
2. Click derecho sobre `instalar-tarea-red.ps1` → **Ejecutar con PowerShell
   como administrador**. Instala la tarea `CoppolaPavese-RepararRed`
   (corre al iniciar sesión y cada 30 minutos).
3. Correr una vez `reparar-red.ps1` a mano (también como admin) y revisar
   el log en `C:\ProgramData\CoppolaPavese\reparar-red.log`:
   cada línea debe decir OK.
4. Verificar que la carpeta compartida esté activa:
   desde la propia host, abrir `\\192.168.100.30\CoppolaPavese` en el
   explorador — debe abrir y dejarte crear un archivo de prueba.

A partir de acá, si Windows vuelve a poner el perfil en Público o apaga
el firewall SMB, la tarea lo **repara sola** a los 30 minutos como máximo.

### 2.3 Limpieza de prórrogas fantasma (una sola vez)

1. Copiar `sqlite3.exe` y `limpiar-prorrogas-fantasma.sql` a la carpeta
   compartida (o a cualquier carpeta local de la host).
2. En una terminal (CMD) en esa carpeta:
   ```
   sqlite3 inmobiliaria.db "SELECT id, contrato_id, cuotas_total, monto_base FROM prorrogas WHERE cuotas_total = 0 AND monto_base = 0 AND (fecha_inicio IS NULL OR fecha_inicio = '');"
   ```
   → Esto muestra las prórrogas fantasma que se van a borrar. **Revisalas.**
   Las reales tienen cuotas y montos > 0 y NO se tocan.
3. Si el listado es correcto:
   ```
   sqlite3 inmobiliaria.db ".read limpiar-prorrogas-fantasma.sql"
   ```
4. Control final:
   ```
   sqlite3 inmobiliaria.db "SELECT id, contrato_id, cuotas_total, monto_base FROM prorrogas;"
   ```
   → Solo deben quedar las prórrogas reales.

(El fix en el código evita que vuelvan a crearse; esto es solo limpieza
del histórico.)

### 2.4 Instalar la app actualizada + el auto-updater

1. Descomprimir el zip del pendrive en el **Escritorio** (reemplazando la
   carpeta vieja de la app, o poniéndola donde la tengan).
2. Correr `instalar-tarea-actualizacion.ps1` (doble clic con PowerShell,
   **sin admin**):
   - Se abre un explorador de carpetas → elegí la carpeta de la app
     (validará que tenga `coppolapavese.exe` adentro).
   - El instalador solo: guarda la config, repunta el acceso directo del
     escritorio, crea la tarea y hace el primer chequeo de update.
3. **Probar**: doble clic en el acceso directo del escritorio →
   tarda 2-3 seg más de lo normal la primera vez (chequea GitHub) →
   la app abre ya actualizada (aplica la migración de BD v15 sola).
4. Si la BD está en la carpeta compartida de esta PC, la app debería
   abrir con los datos normales (la ruta ya estaba configurada).

---

## 3. PC NO-HOST (la que consume la carpeta compartida)

### 3.1 Reconexión automática al iniciar sesión

1. Copiar `reconectar-red.bat` a `shell:startup`:
   - `Win + R` → escribir `shell:startup` → Enter → pegar el `.bat` ahí.
2. Probar: cerrar sesión / reiniciar → abrir el explorador → debería
   existir la unidad `Z:` con la carpeta compartida (o al menos acceder a
   `\\192.168.100.30\CoppolaPavese`).
3. Dentro de la app: Configuración → la ruta de la BD debe seguir
   apuntando a la carpeta de red. Si alguna vez dice "no se puede acceder",
   primero fijarse que la host esté prendida y el acceso de red responda
   (punto 2.2 lo auto-repara en la host).

### 3.2 App actualizada + auto-updater

Exactamente lo mismo del punto **2.4** pero en esta PC:
descomprimir zip en el Escritorio → correr
`instalar-tarea-actualizacion.ps1` → elegir la carpeta de la app →
probar el acceso directo.

---

## 4. Flujo de publicación desde tu casa (lo que vas a usar siempre)

Cuando termines una sesión de cambios:

```powershell
.\scripts\publicar.ps1 -mensaje "fix: descripción de lo que cambiaste"
```

Eso hace TODO solo:
1. Sube el número de versión en `pubspec.yaml` (automático).
2. Compila Flutter Windows Release.
3. Genera el zip nuevo en `dist\`.
4. `git add + commit + push` con tu mensaje.
5. Crea la **GitHub Release** `vX.Y.Z` con el zip adjunto — eso es lo
   que ven las PCs de la inmobiliaria.

**Del otro lado (sin hacer nada):**
- Al iniciar sesión en Windows: la tarea chequea GitHub y actualiza.
- Cada vez que abren la app por el acceso directo: chequea antes de abrir
  (1-3 seg extra) y si había update lo instala y abre la versión nueva.

---

## 5. Cómo probarlo desde tu PC (antes de ir)

Podés simular TODO el ciclo sin tocar la inmobiliaria:

1. Corré `.\scripts\publicar.ps1 -mensaje "test: release de prueba"`.
   Debe terminar con `PUBLICADO vX.Y.Z ✔`.
2. Verificá en https://github.com/degszz/coppolapavese/releases que existe
   la release con su zip.
3. Simulá una PC de la inmobiliaria en tu propia máquina:
   - Creá una carpeta de prueba, ej: `C:\test-cp\app-prueba` y descomprimí
     ahí una **versión vieja** de la app (o simplemente creá el archivo
     `%LocalAppData%\CoppolaPavese\update_config.json` a mano):
     ```json
     { "appDir": "C:\\test-cp\\app-prueba", "version": "0.0.0" }
     ```
   - Copiá `scripts\actualizar-github.ps1` a
     `%LocalAppData%\CoppolaPavese\actualizar-github.ps1`.
   - Corrélo y mirá el log en `%LocalAppData%\CoppolaPavese\update.log`:
     debe decir `ACTUALIZADA a vX.Y.Z ✔` y la carpeta de prueba debe
     quedar con el contenido nuevo.
4. Si ese test pasa, el flujo funciona. Las PCs reales hacen exactamente
   lo mismo, con su propia ruta de app.

---

## 6. Reglas para el futuro (para no romper nada)

1. **Nunca copiar `inmobiliaria.db` de una PC a otra.** Solo backup
   (copiar con otro nombre, sin borrar el original hasta verificar).
2. Las migraciones de BD son **siempre aditivas**: agregar tablas/columnas
   con defaults está OK; **borrar o renombrar columnas NO** sin avisar
   (rompería la app vieja si alguna PC aún no se actualizó).
3. No subir archivos `.db` al repo (ya lo bloquea el `.gitignore`, pero
   revisalo si cambiás la estructura).
4. Si una PC no se actualiza sola: revisar primero que tenga internet
   y después el log `%LocalAppData%\CoppolaPavese\update.log`.

---

## 7. Troubleshooting rápido

| Síntoma | Qué mirar |
|---|---|
| La no-host no ve la carpeta | ¿La host está prendida? En la host, log `C:\ProgramData\CoppolaPavese\reparar-red.log` |
| La app no se actualiza sola | Log en la PC: `%LocalAppData%\CoppolaPavese\update.log`. ¿Config apunta bien? (`update_config.json` en la misma carpeta) |
| La app tira raro después de un update | La carpeta `backup_vX` está en `%LocalAppData%\CoppolaPavese\` — se restaura copiándola de vuelta |
| GitHub dice que la release existe | Tu script la reemplaza solo; si querés versionar limpio subí el patch en `pubspec.yaml` o dejá que `publicar.ps1` lo haga |
| Error "database is locked" | App abierta en las 2 PCs al mismo tiempo + problema puntual de red. Cerrar y reintentar. Si persiste, borrar `inmobiliaria.db-journal` con las 2 apps cerradas |
