import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Gestiona la configuración de la ruta de la base de datos.
/// Permite usar una carpeta compartida en red para acceso multi-PC.
class DbConfig {
  static DbConfig? _instance;
  static DbConfig get instance => _instance ??= DbConfig._();
  DbConfig._();

  String? _rutaPersonalizada;
  double _zoom = 1.0;
  bool _cargado = false;

  /// Nombre del archivo de configuración
  static const _configFileName = 'db_config.json';
  static const _dbFileName = 'inmobiliaria.db';

  /// Ruta del archivo de configuración (siempre local)
  Future<String> get _configFilePath async {
    final docsDir = await getApplicationDocumentsDirectory();
    final appDir = Directory(p.join(docsDir.path, 'CoppolaPavese'));
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return p.join(appDir.path, _configFileName);
  }

  /// Carga la configuración al iniciar la app
  Future<void> cargar() async {
    if (_cargado) return;
    try {
      final path = await _configFilePath;
      final file = File(path);
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        final rutaGuardada = json['ruta_bd'] as String?;
        // Usar la ruta guardada tal cual, sin validarla.
        // Si no está accesible al abrir la BD, SQLite fallará con un error
        // claro en lugar de silenciosamente caer a la base de datos local.
        _rutaPersonalizada = (rutaGuardada != null && rutaGuardada.trim().isNotEmpty)
            ? rutaGuardada.trim()
            : null;
        _zoom = (json['zoom'] as num?)?.toDouble() ?? 1.0;
      }
    } catch (_) {
      // Si el archivo de config no se puede leer, simplemente no hay ruta personalizada
    }
    _cargado = true;
  }

  /// Devuelve la ruta completa al archivo .db
  Future<String> obtenerRutaDb() async {
    await cargar();
    if (_rutaPersonalizada != null && _rutaPersonalizada!.isNotEmpty) {
      return p.join(_rutaPersonalizada!, _dbFileName);
    }
    // Ruta local por defecto
    final docsDir = await getApplicationDocumentsDirectory();
    final appDir = Directory(p.join(docsDir.path, 'CoppolaPavese'));
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return p.join(appDir.path, _dbFileName);
  }

  /// Devuelve la carpeta configurada (null = local)
  String? get rutaPersonalizada => _rutaPersonalizada;

  /// Devuelve el zoom guardado (1.0 por defecto)
  double get zoom => _zoom;

  /// Guarda el nivel de zoom actual
  Future<void> guardarZoom(double nuevoZoom) async {
    _zoom = nuevoZoom;
    final path = await _configFilePath;
    final file = File(path);
    // Leer config existente para no pisar ruta_bd
    Map<String, dynamic> config = {};
    try {
      if (await file.exists()) {
        config = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      }
    } catch (_) {}
    config['zoom'] = _zoom;
    await file.writeAsString(jsonEncode(config));
  }

  /// Devuelve la ruta local por defecto (para mostrar en UI)
  Future<String> obtenerRutaLocal() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return p.join(docsDir.path, 'CoppolaPavese');
  }

  /// Guarda una nueva ruta de carpeta compartida
  Future<void> guardarRuta(String? nuevaRuta) async {
    _rutaPersonalizada = (nuevaRuta != null && nuevaRuta.trim().isNotEmpty)
        ? nuevaRuta.trim()
        : null;
    final path = await _configFilePath;
    final file = File(path);
    // Leer config existente para no pisar zoom
    Map<String, dynamic> config = {};
    try {
      if (await file.exists()) {
        config = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      }
    } catch (_) {}
    config['ruta_bd'] = _rutaPersonalizada;
    await file.writeAsString(jsonEncode(config));
  }

  /// Verifica si una ruta de red es accesible y escribible
  Future<bool> verificarRuta(String ruta) async {
    try {
      final dir = Directory(ruta);
      if (!await dir.exists()) return false;
      // Intentar crear un archivo temporal para verificar permisos de escritura
      final testFile = File(p.join(ruta, '.cp_test_write'));
      await testFile.writeAsString('test');
      await testFile.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Resetea para forzar recarga (útil al cambiar ruta)
  void reset() {
    _cargado = false;
    // NO tocar _rutaPersonalizada aquí; se recargará del archivo en el próximo cargar()
  }

  /// Diagnóstico detallado de la ruta de red. Realiza múltiples chequeos
  /// y devuelve un reporte legible para el usuario + un flag [ok].
  ///
  /// Chequeos:
  /// 1. La carpeta existe y es accesible
  /// 2. Se pueden listar archivos en ella
  /// 3. Se puede crear y borrar un archivo de prueba (permiso de escritura)
  /// 4. El archivo inmobiliaria.db existe en esa carpeta (o se puede crear)
  /// 5. Se puede abrir la BD, aplicar PRAGMAs y hacer un SELECT simple
  /// 6. Se puede escribir en la BD (INSERT/DELETE en una tabla temporal)
  Future<DiagnosticoConexion> diagnosticar(String ruta) async {
    final pasos = <PasoDiagnostico>[];
    bool okTotal = true;

    // 1. Carpeta accesible
    try {
      final dir = Directory(ruta);
      final existe = await dir.exists();
      if (!existe) {
        pasos.add(PasoDiagnostico(
          nombre: 'Carpeta accesible',
          ok: false,
          detalle:
              'La carpeta "$ruta" no existe o no se puede acceder.\n'
              'Verificá: PC host encendida, carpeta compartida creada, '
              'permisos de acceso al usuario.',
        ));
        return DiagnosticoConexion(ok: false, pasos: pasos, ruta: ruta);
      }
      pasos.add(PasoDiagnostico(
          nombre: 'Carpeta accesible', ok: true, detalle: ruta));
    } catch (e) {
      pasos.add(PasoDiagnostico(
        nombre: 'Carpeta accesible',
        ok: false,
        detalle: 'Error al acceder: $e',
      ));
      return DiagnosticoConexion(ok: false, pasos: pasos, ruta: ruta);
    }

    // 2. Listar contenido
    final archivosExistentes = <String>[];
    try {
      final dir = Directory(ruta);
      await for (final entry in dir.list()) {
        archivosExistentes.add(p.basename(entry.path));
      }
      pasos.add(PasoDiagnostico(
        nombre: 'Listar contenido',
        ok: true,
        detalle: archivosExistentes.isEmpty
            ? '(carpeta vacía)'
            : archivosExistentes.take(10).join(', ') +
                (archivosExistentes.length > 10 ? ', …' : ''),
      ));
    } catch (e) {
      pasos.add(PasoDiagnostico(
        nombre: 'Listar contenido',
        ok: false,
        detalle: 'No se pudo listar: $e',
      ));
      okTotal = false;
    }

    // 3. Permiso de escritura (archivo de prueba)
    try {
      final testFile = File(p.join(ruta, '.cp_test_write'));
      await testFile.writeAsString('test-${DateTime.now().millisecondsSinceEpoch}');
      await testFile.delete();
      pasos.add(const PasoDiagnostico(
        nombre: 'Permiso de escritura',
        ok: true,
        detalle: 'Se puede crear y borrar archivos.',
      ));
    } catch (e) {
      pasos.add(PasoDiagnostico(
        nombre: 'Permiso de escritura',
        ok: false,
        detalle: 'Sin permiso de escritura: $e\n'
            'Solución: en la PC host, compartí la carpeta con permisos de '
            '"Lectura y escritura" para el usuario correspondiente.',
      ));
      okTotal = false;
    }

    // 4. Detectar archivos residuales que pueden bloquear SQLite
    final residuales = <String>[];
    for (final f in ['inmobiliaria.db-wal',
                     'inmobiliaria.db-shm',
                     'inmobiliaria.db-journal']) {
      if (archivosExistentes.contains(f)) residuales.add(f);
    }
    if (residuales.isNotEmpty) {
      pasos.add(PasoDiagnostico(
        nombre: 'Archivos residuales SQLite',
        ok: false,
        detalle:
            'Se encontraron archivos que pueden bloquear la BD: '
            '${residuales.join(", ")}.\n'
            'Solución: cerrá la app en TODAS las PCs, luego borrá esos archivos '
            'desde el explorador y volvé a abrir la app.',
      ));
      okTotal = false;
    } else {
      pasos.add(const PasoDiagnostico(
        nombre: 'Archivos residuales SQLite',
        ok: true,
        detalle: 'Sin archivos -wal/-shm/-journal bloqueando.',
      ));
    }

    // 5. Existencia del archivo de BD
    final dbPath = p.join(ruta, _dbFileName);
    final dbExiste = await File(dbPath).exists();
    pasos.add(PasoDiagnostico(
      nombre: 'Archivo de BD',
      ok: true,
      detalle: dbExiste
          ? 'Existe: $_dbFileName'
          : 'NO existe aún en la carpeta. Se creará al primer uso '
              '(o copiá la BD local con "Copiar base local a red").',
    ));

    // 6. Apertura real de la BD + SELECT + INSERT/DELETE de prueba
    Database? db;
    try {
      db = await openDatabase(
        dbPath,
        onConfigure: (d) async {
          await d.execute('PRAGMA journal_mode = DELETE');
          await d.execute('PRAGMA busy_timeout = 5000');
        },
      );
      // SELECT simple
      await db.rawQuery('SELECT 1');
      // INSERT/DELETE en tabla temporal (no toca datos reales)
      await db.execute(
          'CREATE TABLE IF NOT EXISTS _cp_test_write (id INTEGER PRIMARY KEY, t INTEGER)');
      await db.rawInsert(
          'INSERT INTO _cp_test_write (t) VALUES (?)',
          [DateTime.now().millisecondsSinceEpoch]);
      await db.execute('DROP TABLE _cp_test_write');
      pasos.add(const PasoDiagnostico(
        nombre: 'Abrir y escribir en la BD',
        ok: true,
        detalle: 'Lectura y escritura OK.',
      ));
    } catch (e) {
      final msg = e.toString();
      String ayuda = '';
      if (msg.contains('locked')) {
        ayuda =
            '\n→ La BD está bloqueada por otra PC o por archivos residuales. '
            'Cerrá la app en todas las PCs y borrá los archivos '
            '-wal/-shm/-journal si existen.';
      } else if (msg.contains('readonly') || msg.contains('read-only')) {
        ayuda =
            '\n→ La BD o la carpeta están en solo lectura. Revisá los permisos '
            'de la carpeta compartida.';
      } else if (msg.contains('unable to open') ||
          msg.contains('cannot open')) {
        ayuda =
            '\n→ No se pudo abrir el archivo. Verificá la ruta y que la PC '
            'host tenga la carpeta compartida activa.';
      }
      pasos.add(PasoDiagnostico(
        nombre: 'Abrir y escribir en la BD',
        ok: false,
        detalle: 'Error: $msg$ayuda',
      ));
      okTotal = false;
    } finally {
      try {
        await db?.close();
      } catch (_) {}
    }

    return DiagnosticoConexion(ok: okTotal, pasos: pasos, ruta: ruta);
  }
}

/// Resultado de un paso del diagnóstico.
class PasoDiagnostico {
  final String nombre;
  final bool ok;
  final String detalle;
  const PasoDiagnostico({
    required this.nombre,
    required this.ok,
    required this.detalle,
  });
}

/// Reporte completo del diagnóstico.
class DiagnosticoConexion {
  final bool ok;
  final String ruta;
  final List<PasoDiagnostico> pasos;
  const DiagnosticoConexion({
    required this.ok,
    required this.ruta,
    required this.pasos,
  });
}
