# Coppola Pavese Inmobiliaria — contexto para Claude

App de escritorio **Flutter (Windows)** para gestionar alquileres y emitir recibos de
una inmobiliaria de San Miguel del Monte. Base **SQLite** (`sqflite_common_ffi`).
Todo en español: UI, comentarios, commits y respuestas al usuario.

Antes de trabajar en un tema, leé SOLO la nota que corresponde (no todas):

| Tema | Nota |
|---|---|
| Cuotas, "Va por", períodos fijos, prórrogas, avisos del pie del recibo | [docs/reglas-de-negocio.md](docs/reglas-de-negocio.md) |
| Paso a paso: red + auto-actualización + acceso remoto, y qué hacer si algo falla | [docs/guia-completa.md](docs/guia-completa.md) |
| Red compartida: scripts, diagnóstico, problemas típicos | [docs/red-compartida.md](docs/red-compartida.md) |
| Instalar / auto-actualizar la app en la inmobiliaria | [INSTALACION_Y_ACTUALIZACION.md](INSTALACION_Y_ACTUALIZACION.md) |
| Qué se hizo en cada sesión y qué quedó pendiente | [docs/bitacora.md](docs/bitacora.md) |

`PRORROGA_IMPLEMENTACION.md` es un resumen viejo (desactualizado). `README.md` es un
resto de una plantilla Astro: ignorarlo.

## Infraestructura

- **Una sola base** `inmobiliaria.db`, en la PC host: `\\192.168.100.30\CoppolaPavese`.
  La otra PC la usa por red. La ruta se guarda en `Documentos\CoppolaPavese\db_config.json`
  (`lib/database/db_config.dart`). **Nunca copiar ni reemplazar la base entre PCs.**
- La copia en `Documentos\CoppolaPavese\inmobiliaria.db` de la PC de desarrollo es una
  foto vieja (3/10/2026): sirve para analizar, no es la real. Para analizar, copiarla al
  scratchpad y usar `C:\sqlite3\sqlite3.exe`. Nunca escribir sobre la base de la oficina.
- Publicar versión: `powershell -ExecutionPolicy Bypass -File .\scripts\publicar.ps1 -mensaje "fix: ..."`
  (si solo falló crear la release: `... publicar.ps1 -SoloRelease`) → sube versión en
  `pubspec.yaml`, compila, zip en `dist\`, `git add -A` + commit + push, GitHub Release
  (`degszz/coppolapavese`). Las PCs de la oficina se actualizan solas al abrir la app
  (`actualizar-github.ps1`, log en `%LocalAppData%\CoppolaPavese\update.log`). Un commit
  sin publicar NO llega a la oficina. Hay acceso remoto (Chrome Remote Desktop) a las 2 PCs.
- Versión: en `lib/version.dart` (la escribe `publicar.ps1` y se ve en el inicio). Esquema de BD: v16 (`database_helper.dart`, `_migrarVxx`).
  **Migraciones siempre aditivas** (agregar tablas/columnas con default; nunca borrar ni
  renombrar), porque una PC puede quedar con la app vieja un rato.

## Mapa del código (`lib/`)

- `database/database_helper.dart` — TODO el SQL: migraciones, CRUD, cálculo de cuota
  (`obtenerNumCuotaParaContrato`), monto (`obtenerMontoPeriodo`), períodos combinados
  fijos + prórroga (`obtenerTodosLosPeriodos`), borrado de recibos (revierte el "Va por").
- `screens/recibos/recibo_form_screen.dart` — arma el recibo. `_generarNotaPeriodo` decide
  descripción ("Alquiler Cuota N°x" / "Alquiler Prórroga N°x"), mes, aviso del pie y
  alerta de prórroga incompleta.
- `screens/contratos/contrato_form_screen.dart` — alta/edición de contrato, períodos fijos
  y sección Prórroga (validación inline en rojo con prefijo de error `pr_`).
- `screens/contratos/contratos_list_screen.dart` — lista y detalle de contratos.
- `screens/home_screen.dart` + `widgets/calendario_recibos.dart` +
  `utils/proyeccion_recibos_service.dart` — inicio, recibos pendientes (2 columnas) y
  calendario (emitidos en verde, pendientes en magenta, vencidos en rojo).
- `widgets/recibo_widget.dart` + `utils/pdf_generator.dart` — vista y PDF del recibo.
  `screens/recibos/recibo_preview_screen.dart` imprime/descarga/comparte
  (`_nombrePdf` → `Recibo_<nro>_<Inquilino>.pdf`).

## Convenciones

- Notificaciones: siempre `mostrarNotificacion(context, texto:, color:, duracion:)` de
  `utils/snackbar_helper.dart` (nunca `ScaffoldMessenger` directo).
- Errores de formulario: `ErroresCampos` (`utils/validacion_campos.dart`) con `errorText`.
- Colores: magenta `0xFFC2185B` (marca), verde `0xFF2E7D32`, rojo `0xFFC62828`,
  azul prórroga `0xFF1565C0`, naranja alerta `0xFFE65100`.
- Después de editar: `flutter analyze <archivos tocados>`. Hay ~140 infos/warnings viejos
  (withOpacity, etc.); solo importa no sumar errores nuevos.
- Los `.ps1` de `scripts/` van en UTF-8 **con BOM** (PowerShell 5.1) y los `.bat` con CRLF.
- Los scripts sueltos de la raíz (`apply_*.js`, `fix*.dart`, etc.) son restos de sesiones
  viejas y están en `.gitignore`.

## Al terminar una sesión

Agregar una entrada corta en `docs/bitacora.md` (qué se cambió, qué falta) para que la
próxima sesión no tenga que redescubrirlo.
