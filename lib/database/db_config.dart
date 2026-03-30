import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Gestiona la configuración de la ruta de la base de datos.
/// Permite usar una carpeta compartida en red para acceso multi-PC.
class DbConfig {
  static DbConfig? _instance;
  static DbConfig get instance => _instance ??= DbConfig._();
  DbConfig._();

  String? _rutaPersonalizada;
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
        _rutaPersonalizada = json['ruta_bd'] as String?;
        // Verificar que la ruta sigue siendo accesible
        if (_rutaPersonalizada != null) {
          final dir = Directory(_rutaPersonalizada!);
          if (!await dir.exists()) {
            // La ruta de red no está disponible, volver a local
            _rutaPersonalizada = null;
          }
        }
      }
    } catch (_) {
      _rutaPersonalizada = null;
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
    await file.writeAsString(jsonEncode({
      'ruta_bd': _rutaPersonalizada,
    }));
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
    _rutaPersonalizada = null;
  }
}
