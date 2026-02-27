import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // En Windows/Linux/macOS usamos la carpeta Documents para persistencia real
    String dbPath;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final docsDir = await getApplicationDocumentsDirectory();
      final appDir = Directory(join(docsDir.path, 'CoppolaPavese'));
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }
      dbPath = join(appDir.path, 'inmobiliaria.db');
    } else {
      final dir = await getDatabasesPath();
      dbPath = join(dir, 'inmobiliaria.db');
    }

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ── PROPIETARIOS ──────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE propietarios (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre   TEXT NOT NULL,
        telefono TEXT,
        email    TEXT
      )
    ''');

    // ── INQUILINOS ────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE inquilinos (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre          TEXT NOT NULL,
        telefono        TEXT,
        propietario_id  INTEGER NOT NULL,
        FOREIGN KEY (propietario_id) REFERENCES propietarios(id)
          ON DELETE CASCADE
      )
    ''');

    // ── DOMICILIOS ────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE domicilios (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        direccion      TEXT NOT NULL,
        localidad      TEXT,
        propietario_id INTEGER NOT NULL,
        inquilino_id   INTEGER,
        FOREIGN KEY (propietario_id) REFERENCES propietarios(id)
          ON DELETE CASCADE,
        FOREIGN KEY (inquilino_id)   REFERENCES inquilinos(id)
          ON DELETE SET NULL
      )
    ''');

    // ── RECIBOS ───────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE recibos (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        numero_recibo    INTEGER UNIQUE NOT NULL,
        propietario_id   INTEGER NOT NULL,
        inquilino_id     INTEGER,
        domicilio_id     INTEGER,
        fecha_emision    TEXT NOT NULL,
        fecha_vencimiento TEXT,
        monto_total      REAL NOT NULL DEFAULT 0,
        monto_abonado    REAL NOT NULL DEFAULT 0,
        saldo            REAL NOT NULL DEFAULT 0,
        estado           TEXT NOT NULL DEFAULT 'pendiente',
        usuario          TEXT,
        notas            TEXT,
        created_at       TEXT NOT NULL,
        FOREIGN KEY (propietario_id) REFERENCES propietarios(id)
          ON DELETE CASCADE,
        FOREIGN KEY (inquilino_id)   REFERENCES inquilinos(id)
          ON DELETE SET NULL,
        FOREIGN KEY (domicilio_id)   REFERENCES domicilios(id)
          ON DELETE SET NULL
      )
    ''');

    // ── SERVICIOS_RECIBO ──────────────────────────────────────────
    await db.execute('''
      CREATE TABLE servicios_recibo (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        recibo_id   INTEGER NOT NULL,
        descripcion TEXT NOT NULL,
        monto       REAL NOT NULL DEFAULT 0,
        punitorios  REAL NOT NULL DEFAULT 0,
        total       REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (recibo_id) REFERENCES recibos(id)
          ON DELETE CASCADE
      )
    ''');
  }

  // ════════════════════════════════════════════════════════════════
  // PROPIETARIOS — CRUD
  // ════════════════════════════════════════════════════════════════

  Future<int> insertarPropietario(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('propietarios', data);
  }

  Future<List<Map<String, dynamic>>> obtenerPropietarios() async {
    final db = await database;
    return await db.query('propietarios', orderBy: 'nombre ASC');
  }

  Future<Map<String, dynamic>?> obtenerPropietarioPorId(int id) async {
    final db = await database;
    final result = await db.query(
      'propietarios',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> actualizarPropietario(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'propietarios',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> eliminarPropietario(int id) async {
    final db = await database;
    return await db.delete(
      'propietarios',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // INQUILINOS — CRUD
  // ════════════════════════════════════════════════════════════════

  Future<int> insertarInquilino(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('inquilinos', data);
  }

  Future<List<Map<String, dynamic>>> obtenerInquilinos() async {
    final db = await database;
    return await db.query('inquilinos', orderBy: 'nombre ASC');
  }

  Future<List<Map<String, dynamic>>> obtenerInquilinosPorPropietario(
      int propietarioId) async {
    final db = await database;
    return await db.query(
      'inquilinos',
      where: 'propietario_id = ?',
      whereArgs: [propietarioId],
      orderBy: 'nombre ASC',
    );
  }

  Future<Map<String, dynamic>?> obtenerInquilinoPorId(int id) async {
    final db = await database;
    final result = await db.query(
      'inquilinos',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> actualizarInquilino(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'inquilinos',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> eliminarInquilino(int id) async {
    final db = await database;
    return await db.delete(
      'inquilinos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // DOMICILIOS — CRUD
  // ════════════════════════════════════════════════════════════════

  Future<int> insertarDomicilio(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('domicilios', data);
  }

  Future<List<Map<String, dynamic>>> obtenerDomicilios() async {
    final db = await database;
    return await db.query('domicilios');
  }

  Future<List<Map<String, dynamic>>> obtenerDomiciliosPorPropietario(
      int propietarioId) async {
    final db = await database;
    return await db.query(
      'domicilios',
      where: 'propietario_id = ?',
      whereArgs: [propietarioId],
    );
  }

  Future<Map<String, dynamic>?> obtenerDomicilioPorId(int id) async {
    final db = await database;
    final result = await db.query(
      'domicilios',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> actualizarDomicilio(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'domicilios',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> eliminarDomicilio(int id) async {
    final db = await database;
    return await db.delete(
      'domicilios',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // RECIBOS — CRUD
  // ════════════════════════════════════════════════════════════════

  Future<int> insertarRecibo(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('recibos', data);
  }

  Future<List<Map<String, dynamic>>> obtenerRecibos() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        r.*,
        p.nombre  AS propietario_nombre,
        i.nombre  AS inquilino_nombre,
        d.direccion,
        d.localidad
      FROM recibos r
      LEFT JOIN propietarios p ON r.propietario_id = p.id
      LEFT JOIN inquilinos   i ON r.inquilino_id   = i.id
      LEFT JOIN domicilios   d ON r.domicilio_id   = d.id
      ORDER BY r.fecha_emision DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> obtenerRecibosPorPropietario(
      int propietarioId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        r.*,
        p.nombre  AS propietario_nombre,
        i.nombre  AS inquilino_nombre,
        d.direccion,
        d.localidad
      FROM recibos r
      LEFT JOIN propietarios p ON r.propietario_id = p.id
      LEFT JOIN inquilinos   i ON r.inquilino_id   = i.id
      LEFT JOIN domicilios   d ON r.domicilio_id   = d.id
      WHERE r.propietario_id = ?
      ORDER BY r.fecha_emision DESC
    ''', [propietarioId]);
  }

  Future<Map<String, dynamic>?> obtenerReciboPorId(int id) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        r.*,
        p.nombre  AS propietario_nombre,
        p.telefono AS propietario_telefono,
        p.email   AS propietario_email,
        i.nombre  AS inquilino_nombre,
        i.telefono AS inquilino_telefono,
        d.direccion,
        d.localidad
      FROM recibos r
      LEFT JOIN propietarios p ON r.propietario_id = p.id
      LEFT JOIN inquilinos   i ON r.inquilino_id   = i.id
      LEFT JOIN domicilios   d ON r.domicilio_id   = d.id
      WHERE r.id = ?
    ''', [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> actualizarRecibo(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'recibos',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> eliminarRecibo(int id) async {
    final db = await database;
    return await db.delete(
      'recibos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> obtenerProximoNumeroRecibo() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(numero_recibo) AS ultimo FROM recibos',
    );
    final ultimo = result.first['ultimo'];
    return (ultimo == null ? 0 : (ultimo as int)) + 1;
  }

  // ════════════════════════════════════════════════════════════════
  // SERVICIOS_RECIBO — CRUD
  // ════════════════════════════════════════════════════════════════

  Future<int> insertarServicio(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('servicios_recibo', data);
  }

  Future<List<Map<String, dynamic>>> obtenerServiciosPorRecibo(
      int reciboId) async {
    final db = await database;
    return await db.query(
      'servicios_recibo',
      where: 'recibo_id = ?',
      whereArgs: [reciboId],
    );
  }

  Future<void> eliminarServiciosPorRecibo(int reciboId) async {
    final db = await database;
    await db.delete(
      'servicios_recibo',
      where: 'recibo_id = ?',
      whereArgs: [reciboId],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // CONSULTAS COMPUESTAS — Estadísticas y Reportes
  // ════════════════════════════════════════════════════════════════

  /// Resumen por propietario: total cobrado, total pendiente, saldo
  Future<List<Map<String, dynamic>>> obtenerResumenPorPropietario() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        p.id,
        p.nombre                        AS propietario_nombre,
        p.telefono                      AS propietario_telefono,
        i.nombre                        AS inquilino_nombre,
        d.direccion,
        d.localidad,
        COUNT(r.id)                     AS total_recibos,
        COALESCE(SUM(r.monto_total),  0) AS total_monto,
        COALESCE(SUM(r.monto_abonado),0) AS total_cobrado,
        COALESCE(SUM(r.saldo),        0) AS total_pendiente
      FROM propietarios p
      LEFT JOIN inquilinos  i ON i.propietario_id = p.id
      LEFT JOIN domicilios  d ON d.propietario_id = p.id
      LEFT JOIN recibos     r ON r.propietario_id = p.id
      GROUP BY p.id
      ORDER BY p.nombre ASC
    ''');
  }

  /// Estadísticas generales para la pantalla de inicio
  Future<Map<String, dynamic>> obtenerEstadisticasGenerales() async {
    final db = await database;

    final ahora = DateTime.now();
    final primerDiaMes =
        '${ahora.year}-${ahora.month.toString().padLeft(2, '0')}-01';
    final ultimoDiaMes = DateTime(ahora.year, ahora.month + 1, 0);
    final ultimoDiaMesStr =
        '${ultimoDiaMes.year}-${ultimoDiaMes.month.toString().padLeft(2, '0')}-${ultimoDiaMes.day.toString().padLeft(2, '0')}';

    final totalPropietarios = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM propietarios'),
        ) ??
        0;

    final recibosMes = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM recibos WHERE fecha_emision BETWEEN ? AND ?',
            [primerDiaMes, ultimoDiaMesStr],
          ),
        ) ??
        0;

    final cobradoMes = (await db.rawQuery(
      'SELECT COALESCE(SUM(monto_abonado), 0) AS total FROM recibos '
      'WHERE fecha_emision BETWEEN ? AND ?',
      [primerDiaMes, ultimoDiaMesStr],
    ))
        .first['total'] as double? ??
        0.0;

    final pendienteTotal = (await db.rawQuery(
      "SELECT COALESCE(SUM(saldo), 0) AS total FROM recibos "
      "WHERE estado IN ('pendiente', 'parcial')",
    ))
        .first['total'] as double? ??
        0.0;

    return {
      'total_propietarios': totalPropietarios,
      'recibos_mes': recibosMes,
      'cobrado_mes': cobradoMes,
      'pendiente_total': pendienteTotal,
    };
  }

  /// Todos los recibos con filtros opcionales para Excel
  Future<List<Map<String, dynamic>>> obtenerRecibosParaExcel({
    String? fechaDesde,
    String? fechaHasta,
    int? propietarioId,
    String? estado,
  }) async {
    final db = await database;
    final condiciones = <String>[];
    final args = <dynamic>[];

    if (fechaDesde != null) {
      condiciones.add('r.fecha_emision >= ?');
      args.add(fechaDesde);
    }
    if (fechaHasta != null) {
      condiciones.add('r.fecha_emision <= ?');
      args.add(fechaHasta);
    }
    if (propietarioId != null) {
      condiciones.add('r.propietario_id = ?');
      args.add(propietarioId);
    }
    if (estado != null) {
      condiciones.add('r.estado = ?');
      args.add(estado);
    }

    final where =
        condiciones.isNotEmpty ? 'WHERE ${condiciones.join(' AND ')}' : '';

    return await db.rawQuery('''
      SELECT
        r.*,
        p.nombre   AS propietario_nombre,
        i.nombre   AS inquilino_nombre,
        d.direccion,
        d.localidad,
        GROUP_CONCAT(s.descripcion, ' | ') AS servicios_descripcion
      FROM recibos r
      LEFT JOIN propietarios   p ON r.propietario_id = p.id
      LEFT JOIN inquilinos     i ON r.inquilino_id   = i.id
      LEFT JOIN domicilios     d ON r.domicilio_id   = d.id
      LEFT JOIN servicios_recibo s ON s.recibo_id    = r.id
      $where
      GROUP BY r.id
      ORDER BY r.fecha_emision DESC
    ''', args);
  }
}
