# Red compartida: flujo de trabajo en la inmobiliaria

Volver a [[Inicio]] · Detalle de instalación y auto-actualización:
[INSTALACION_Y_ACTUALIZACION.md](../INSTALACION_Y_ACTUALIZACION.md)

**Cómo funciona:** la PC **host** tiene la carpeta `C:\CoppolaPavese` (con
`inmobiliaria.db` adentro) compartida como `\\192.168.100.30\CoppolaPavese`. La otra
PC (**no-host**) abre esa misma base por la red. Si la host cambia de IP, pasa la red
a "Pública" o el firewall bloquea el compartido, la no-host se queda sin datos.

## Scripts (`scripts/`)

| Script | Dónde | Admin | Qué hace |
|---|---|---|---|
| `diagnostico-red.ps1` | las 2 PCs | conviene | Solo lee. Deja `diagnostico-red-<PC>.txt` en el Escritorio |
| `reparar-red.ps1` | host | sí | Perfil Privado, firewall, servicios, IP fija (solo si está en la misma red), carpeta compartida. Log: `C:\ProgramData\CoppolaPavese\reparar-red.log` |
| `instalar-tarea-red.ps1` | host | sí | Copia `reparar-red.ps1` a `C:\CoppolaPavese\scripts\` y lo programa al iniciar sesión y cada 30 min |
| `crear-usuario-red.ps1` | host | sí | Crea el usuario local `cpred` (oculto en el inicio de sesión) con acceso a la carpeta; muestra el `cmdkey` para la no-host |
| `reconectar-red.bat` | no-host | no | Conecta `Z:` a la carpeta compartida y dice qué falló |

**Host Windows 11 + no-host Windows 10:** Windows 11 24H2 endureció el compartido
(firma SMB obligatoria y acceso de invitado bloqueado), así que la conexión "sin
contraseña" falla o se corta. Por eso la no-host entra con el usuario `cpred` y su
clave guardada con `cmdkey` (guía, pasos B5 y B7).

**Cómo correr un `.ps1` como administrador** (el doble clic no sirve):
`Win + X` → **Terminal (Administrador)** → ir a la carpeta y correr:

```powershell
cd E:\scripts            # la carpeta donde estén (pendrive o C:\dev\cp\scripts)
powershell -ExecutionPolicy Bypass -File .\diagnostico-red.ps1
```

`-ExecutionPolicy Bypass` evita el bloqueo de Windows a scripts copiados de un
pendrive o descargados.

## Paso a paso

El orden completo para dejar todo andando (backup, diagnóstico, reparar la host,
conectar la no-host, auto-actualización y acceso remoto) está en [[guia-completa]].

**Para que Claude te ayude en la host:** instalá Claude allá (paso B9 de la guía),
abrí `C:\dev\cp` y arrancá con:
> Leé docs/red-compartida.md. Estoy en la PC host de la inmobiliaria. Los
> diagnósticos están en el Escritorio (diagnostico-red-*.txt). Ayudame a dejar
> andando la red compartida.

Claude va a proponer comandos; los de administrador los corrés vos en la Terminal
(Administrador).

**Opciones de los scripts:** si la IP real no es la de siempre,
`.\reparar-red.ps1 -IpHost 192.168.x.y`. Si la carpeta compartida está en otra ruta,
`-RutaCarpeta D:\loquesea`. En la no-host, editar `set HOST=` de `reconectar-red.bat`.

## Datos a corregir (con la versión nueva instalada)

- Contrato **18**: cargar fechas y períodos de la prórroga (el período "25–12" está al revés).
- Contratos **46** y **98**: la fecha de fin de la prórroga es igual a la de inicio.
- Contrato **46**: confirmar el "Va por" = 4 de una prórroga de 4 cuotas.
- "Va por" que no coincide con el último recibo: **45** (22 vs 20), **47** (11 vs 9),
  **90** (8 vs 8), **100** (4 vs 5).

(Datos vistos en la copia del 3/10; en la base real pueden haber cambiado.)


## Problemas típicos

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| La no-host no hace ping a la host | Host apagada, otra red/router, IP cambiada | `ipconfig` en las 2; reservar IP en el router |
| Ping OK pero no abre `\\IP\CoppolaPavese` | Perfil "Pública" o firewall | `reparar-red.ps1` en la host |
| Pide usuario/contraseña o "acceso denegado" | Falta la clave guardada de `cpred` en la no-host | `cmdkey` (guía, paso B7) |
| "Las directivas de seguridad bloquean el acceso de invitado" | Se intentó entrar sin usuario a una host Windows 11 | Usar el usuario `cpred` (guía, pasos B5 y B7) |
| Funciona y después de reiniciar deja de andar | La tarea no está instalada o la IP cambió | `instalar-tarea-red.ps1`; ver el log |
| "database is locked" | Las 2 PCs escribiendo a la vez, o red cortada un instante | Cerrar y reintentar; con las 2 apps cerradas borrar `inmobiliaria.db-journal` |
| El `.ps1` no arranca ("no está firmado digitalmente") | Política de ejecución | Correrlo con `powershell -ExecutionPolicy Bypass -File ...` |

## Qué se corrigió en los scripts (25/10/2026)

- `instalar-tarea-red.ps1`: usaba una duración de repetición que Windows 10 rechaza,
  y la tarea nunca se creaba. Ahora además copia `reparar-red.ps1` solo y lo ejecuta una vez.
- `reparar-red.ps1`: compartía con el usuario "Todos", que no existe en Windows en
  inglés. Antes, si la IP no coincidía, borraba todas las IPs aunque la PC estuviera en
  otra red (la dejaba sin conexión); ahora solo cambia la IP dentro de la misma red y
  avisa en el resto de los casos. También avisa si falta `inmobiliaria.db`.
- `reconectar-red.bat`: escondía los errores; ahora prueba ping y dice qué falló.
- Nuevo `diagnostico-red.ps1`.
- Todos verifican que haya permisos de administrador cuando hacen falta.

**Auto-actualización (`actualizar-github.ps1`, `instalar-tarea-actualizacion.ps1`, `publicar.ps1`):**
- El updater fuerza TLS 1.2: con el TLS viejo que usa por defecto Windows 10 no podía
  hablar con GitHub, lo anotaba como "sin internet" y nunca actualizaba.
- Se niega a actualizar si la carpeta de la app tiene `inmobiliaria.db` adentro (la
  copia en espejo la habría borrado) y nunca copia ni borra archivos `.db`.
- Si la copia falla, restaura el backup (antes no detectaba el error de robocopy).
  El log dice el motivo de cada fallo y el nombre de la PC.
- La tarea de inicio de sesión solo actualiza: antes además abría la app, a veces
  antes de que la red estuviera lista.
- `publicar.ps1`: muestra qué archivos va a subir y pide confirmar; frena si GitHub
  tiene commits que tu PC no tiene; si el build falla, la versión vuelve atrás;
  actualiza `lib/version.dart` (la versión que se ve en el inicio de la app).
- Probado el 25/10 en una carpeta aislada: bajó v1.0.4 de GitHub y la instaló en 7 s.
