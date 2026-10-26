# Guía completa: dejar todo andando y mantenerlo desde casa

Volver a [[Inicio]] · Detalle técnico y problemas típicos: [[red-compartida]]

**La idea:** vas una vez a la inmobiliaria y dejás tres cosas funcionando:

1. **Red compartida**: la PC **host (Windows 11)** guarda la base y la PC
   **no-host (Windows 10)** la usa por la red.
2. **Auto-actualización**: publicás desde casa y las 2 PCs se actualizan solas al abrir la app.
   **Ya no hace falta llevar la app en el pendrive.**
3. **Acceso remoto**: si algo falla, entrás a las PCs desde tu casa.

Marcá cada paso a medida que lo hacés.

---

## Cómo abrir la Terminal en cada PC

Casi todo se hace pegando comandos en una Terminal **abierta en la carpeta del pendrive**.

| | Host (Windows 11) | No-host (Windows 10) |
|---|---|---|
| Como **administrador** | `Win + X` → **Terminal (Administrador)** | `Win + X` → **Windows PowerShell (Administrador)** |
| **Sin** administrador | `Win + X` → **Terminal** | `Win + X` → **Windows PowerShell** |

Después, ir a la carpeta del pendrive (cambiá `E:` por la letra que tenga):

```powershell
cd E:\scripts
```

Los `.ps1` se corren así (nunca con doble clic):
`powershell -ExecutionPolicy Bypass -File .\nombre-del-script.ps1`

---

## A. En casa, antes de ir

- [x] **A1. Publicar la versión nueva** — hecho el 26/10: **v1.0.5** está publicada.
  Para las próximas veces (esto reemplaza "exportar la app y llevarla en el pendrive"):
  1. Abrí una Terminal en `C:\dev\cp` y pegá (funciona en PowerShell y en el Símbolo
     del sistema; escribirlo como `.\scripts\publicar.ps1` en el Símbolo del sistema
     abre el Bloc de notas en vez de ejecutarlo):
     ```powershell
     powershell -ExecutionPolicy Bypass -File .\scripts\publicar.ps1 -mensaje "fix: lo que cambiaste"
     ```
  2. Te muestra los archivos que va a subir → escribí `s` y Enter.
  3. Esperá a que diga **PUBLICADO v1.0.x** (compila, así que tarda unos minutos).
  4. Si falla **solo el último paso** ("Creando GitHub Release"), no lo corras completo
     de nuevo (subiría otro número de versión). Reintentá solo ese paso:
     ```powershell
     powershell -ExecutionPolicy Bypass -File .\scripts\publicar.ps1 -SoloRelease
     ```

- [ ] **A2. Pendrive.** Copiá:
  - La carpeta **`C:\dev\cp\scripts`** entera (los scripts necesitan estar juntos).
  - Esta guía (`docs\guia-completa.md`).
  - El zip **`C:\dev\cp\dist\coppolapavese_v1.0.5.zip`**, solo por si una PC no tiene
    internet.

  Los scripts que vas a usar de esa carpeta:

  | Script | PC | Para qué |
  |---|---|---|
  | `diagnostico-red.ps1` | las 2 | Ver cómo está todo (no cambia nada) |
  | `reparar-red.ps1` | host | Arregla perfil, firewall, IP y carpeta compartida |
  | `instalar-tarea-red.ps1` | host | Repite el arreglo solo, cada 30 min y al prender |
  | `crear-usuario-red.ps1` | host | Usuario y clave para que la no-host entre |
  | `reconectar-red.bat` | no-host | Conecta la carpeta al iniciar sesión |
  | `instalar-tarea-actualizacion.ps1` | las 2 | Auto-actualización (usa `actualizar-github.ps1` y `abrir-app.bat`, que tienen que estar al lado) |

- [ ] **A3. Cuenta de Google** para el acceso remoto. Probá entrar a
  https://remotedesktop.google.com/access desde tu PC.

---

## B. En la inmobiliaria (en este orden)

- [ ] **B1. Backup de la base.** Cerrá la app en las 2 PCs. En la host, copiá
  `C:\CoppolaPavese\inmobiliaria.db` y pegala en la misma carpeta con otro nombre:
  `inmobiliaria_backup_20261026.db`.

- [ ] **B2. Diagnóstico** en las 2 PCs (Terminal **como administrador**):
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\diagnostico-red.ps1
  ```
  Deja `diagnostico-red-<PC>.txt` en el Escritorio. Fijate y anotá:
  - **IP de la host**: en el archivo de la host, "Dirección IPv4". Si **no** es
    `192.168.100.30`, usá la real en todos los pasos de abajo.
  - **Dónde está la app** en cada PC (la carpeta que tiene `coppolapavese.exe`).

- [ ] **B3. App y base en carpetas distintas.** La base va en `C:\CoppolaPavese`. La app
  tiene que estar en **otra** carpeta (ej. `C:\CoppolaPavese-app` o en el Escritorio).
  Si en la host la app está dentro de `C:\CoppolaPavese`, movela. La auto-actualización
  no funciona con la app y la base juntas: es una protección para no borrar la base.

### Host (Windows 11) — Terminal (Administrador)

- [ ] **B4. Reparar la red:**
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\reparar-red.ps1
  powershell -ExecutionPolicy Bypass -File .\instalar-tarea-red.ps1
  ```
  Cada línea del resultado tiene que decir **OK**. Si dice `ADVERTENCIA`, leé qué
  falta (por ejemplo, la IP es otra: repetí con `.\reparar-red.ps1 -IpHost 192.168.x.y`).

- [ ] **B5. Usuario de red** (lo que hace estable la conexión entre Windows 11 y 10):
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\crear-usuario-red.ps1
  ```
  Te pide una clave dos veces: **anotala**. Al final muestra un comando `cmdkey ...`:
  **sacale una foto**, lo usás en la no-host (paso B7).

- [ ] **B6. Comprobar el perfil de red:** Configuración → Red e Internet → Ethernet (o
  Wi-Fi) → **Tipo de perfil de red: Privada**. Si el router se puede configurar,
  reservá la IP de la host (la MAC está en el diagnóstico) para que nunca cambie.

### No-host (Windows 10) — Windows PowerShell (sin admin)

- [ ] **B7. Guardar la clave de red** (una sola vez). Pegá el comando de la foto del paso B5.
  Tiene esta forma:
  ```powershell
  cmdkey /add:192.168.100.30 /user:NOMBREHOST\cpred /pass
  ```
  Te pide la clave: escribí la del paso B5 (no se ve mientras escribís).
- [ ] **B8. Conexión automática:**
  1. Si la IP de la host no es `192.168.100.30`: abrí `reconectar-red.bat` con el Bloc
     de notas y cambiá la línea `set HOST=`.
  2. `Win + R` → `shell:startup` → Enter → copiá `reconectar-red.bat` en esa carpeta.
  3. Doble clic en el `.bat` que copiaste: tiene que decir **Conexion OK**.

### Las 2 PCs

- [ ] **B9. Auto-actualización** (Terminal **sin** administrador):
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\instalar-tarea-actualizacion.ps1
  ```
  1. Elegí la carpeta de la app.
  2. Tiene que terminar en **ACTUALIZADA a v1.0.5 OK** (o "Ya está actualizada").
  3. **Desde ahora, la app se abre solo con el acceso directo del Escritorio.** Si está
     anclada en la barra de tareas, desanclala (el `.exe` directo no se actualiza).
  4. Si una PC no tiene internet: descomprimí el zip del pendrive en la carpeta de la
     app y repetí este paso cuando haya internet.

- [ ] **B10. Las 2 PCs usan la misma base.** Abrí la app en las 2:
  - el inicio dice **v1.0.5**;
  - en Configuración de Red, las 2 apuntan al mismo archivo (la no-host a `\\192.168.100.30\CoppolaPavese\inmobiliaria.db`);
  - el último recibo emitido se ve igual en las 2.

- [ ] **B11. Acceso remoto:**
  1. En cada PC, abrí Chrome → https://remotedesktop.google.com/access con tu cuenta →
     **Configurar acceso remoto** → instalar.
  2. Nombres: `CP-Host` y `CP-Caja`. PIN de 6 o más números (no lo dejes anotado ahí).
  3. Que no se suspendan:
     - **Host (Win 11):** Configuración → Sistema → Inicio/apagado y batería (o "Energía") → Suspender: **Nunca**.
     - **No-host (Win 10):** Configuración → Sistema → Inicio/apagado y suspensión → Suspender: **Nunca**.

- [ ] **B12. Prueba de fuego.** Reiniciá las 2 PCs (primero la host, después la otra) y verificá:
  - La no-host abre la app con los datos, sin hacer nada.
  - Desde tu celular, en la app de Chrome Remote Desktop, ves las 2 PCs en línea.

- [ ] **B13. Corregir datos** de prórrogas y "Va por" (lista en [[red-compartida]], sección "Datos a corregir").

- [ ] **B14. (Opcional) Claude en la host**: instalá la app de claude.ai/download y
  `winget install Git.Git`, después `git clone https://github.com/degszz/coppolapavese.git C:\dev\cp`.

---

## C. Trabajo de todos los días, desde casa

1. `cd C:\dev\cp` → `claude` → pedís el cambio. Para probar, `flutter run -d windows`
   usa la copia vieja de la base de tu PC, nunca la de la oficina.
2. **Commit no es lo mismo que publicar:**
   - `git commit` + `git push` → guarda el código en GitHub. **No llega a la oficina.**
   - `powershell -ExecutionPolicy Bypass -File .\scripts\publicar.ps1 -mensaje "..."` → **llega a la oficina**: las PCs se
     actualizan la próxima vez que abren la app o al prenderse.
3. Si es urgente: pediles que cierren la app y la abran de nuevo desde el acceso directo.
4. Para confirmar: el inicio de la app muestra la versión (preguntales o entrá por acceso remoto).

---

## D. Si algo falla (sin ir)

| Pasa esto | Hacé esto desde casa |
|---|---|
| La versión nueva tiene un error | Corregir y volver a publicar. Si es grave: `git revert HEAD` y `publicar.ps1` (vuelve el código anterior con un número nuevo) |
| Una PC no se actualiza | Acceso remoto → abrir `%LocalAppData%\CoppolaPavese\update.log` (cada intento dice el motivo) |
| La no-host no encuentra la base | Acceso remoto → en la host, `C:\ProgramData\CoppolaPavese\reparar-red.log`; correr `diagnostico-red.ps1` en las 2 |
| La no-host dice "acceso denegado" | Repetir B7 (`cmdkey`). Si cambiaste la clave en la host, también |
| La host cambió de IP | Acceso remoto → `ipconfig`; reservar la IP en el router o `reparar-red.ps1 -IpHost <ip>` |
| La app no abre después de actualizar | La versión anterior está en `%LocalAppData%\CoppolaPavese\backup_v<versión>`; publicar la corrección |
| La PC no aparece en el acceso remoto | Está apagada o sin internet: pedí que la prendan |

**Nunca:** copiar `inmobiliaria.db` de una PC a otra, publicar una migración que borre
o renombre columnas, ni abrir la base de la oficina desde tu PC de desarrollo.
