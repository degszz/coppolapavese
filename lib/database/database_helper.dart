import 'package:sqflite/sqflite.dart';
import 'db_config.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Cierra la BD actual y fuerza reconexión (al cambiar ruta)
  Future<void> reconectar() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }
    _database = null;
    _database = await _initDatabase();
  }

  Future<Database> _initDatabase() async {
    // Obtener ruta desde configuración (local o red compartida)
    final dbPath = await DbConfig.instance.obtenerRutaDb();

    return await openDatabase(
      dbPath,
      version: 8, // v8: porcentaje en periodos_fijos
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        // Acceso concurrente: DELETE journal es más seguro en carpetas de red
        await db.execute('PRAGMA journal_mode = DELETE');
        // Esperar hasta 10s si la BD está bloqueada por otro equipo
        await db.execute('PRAGMA busy_timeout = 10000');
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  // CREACIÓN INICIAL (versión 1 + tablas nuevas de v2)
  // ════════════════════════════════════════════════════════════════

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

    // tablas v2
    await _crearTablasV2(db);
    // tablas v3
    await _migrarV3(db);
    // tablas v4
    await _migrarV4(db);
    // tablas v5
    await _migrarV5(db);
    // tablas v6
    await _migrarV6(db);
    // tablas v7
    await _migrarV7(db);
    // tablas v8
    await _migrarV8(db);
  }

  // ════════════════════════════════════════════════════════════════
  // NUEVO — MIGRACIÓN: v1 → v2 (no pierde datos existentes)
  // ════════════════════════════════════════════════════════════════

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _crearTablasV2(db);
    }
    if (oldVersion < 3) {
      await _migrarV3(db);
    }
    if (oldVersion < 4) {
      await _migrarV4(db);
    }
    if (oldVersion < 5) {
      await _migrarV5(db);
    }
    if (oldVersion < 6) {
      await _migrarV6(db);
    }
    if (oldVersion < 7) {
      await _migrarV7(db);
    }
    if (oldVersion < 8) {
      await _migrarV8(db);
    }
  }

  // ════════════════════════════════════════════════════════════════
  // MIGRACIÓN v4 — conceptos_regulares columnas extendidas
  // ════════════════════════════════════════════════════════════════
  Future<void> _migrarV4(Database db) async {
    for (final col in [
      'claro INTEGER DEFAULT 1',
      'recordar_pago INTEGER DEFAULT 0',
      'fecha_inicio TEXT',
      'fecha_fin TEXT',
      'periodo_tipo TEXT DEFAULT \'todos\'',
      'meses TEXT',
      'entregar_comprobante_prop INTEGER DEFAULT 0',
    ]) {
      try {
        await db.execute('ALTER TABLE conceptos_regulares ADD COLUMN $col');
      } catch (_) {}
    }
  }

  // ════════════════════════════════════════════════════════════════
  // MIGRACIÓN v5 — tabla garantes
  // ════════════════════════════════════════════════════════════════
  Future<void> _migrarV5(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS garantes (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        contrato_id  INTEGER NOT NULL,
        nombre       TEXT NOT NULL,
        telefono     TEXT,
        email        TEXT,
        tipo_garantia TEXT NOT NULL DEFAULT 'recibo_sueldo',
        FOREIGN KEY (contrato_id) REFERENCES contratos(id) ON DELETE CASCADE
      )
    ''');
  }

  // ════════════════════════════════════════════════════════════════
  // MIGRACIÓN v6 — fichas de propiedad + imágenes
  // ════════════════════════════════════════════════════════════════
  Future<void> _migrarV6(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS propiedad_fichas (
        id                    INTEGER PRIMARY KEY AUTOINCREMENT,
        propiedad_id          INTEGER NOT NULL UNIQUE,
        operacion             TEXT NOT NULL DEFAULT 'Alquiler',
        precio                REAL DEFAULT 0,
        moneda                TEXT NOT NULL DEFAULT 'ARS',
        ambientes             INTEGER DEFAULT 0,
        dormitorios           INTEGER DEFAULT 0,
        banos                 INTEGER DEFAULT 0,
        cochera               INTEGER DEFAULT 0,
        superficie_total      REAL DEFAULT 0,
        superficie_cubierta   REAL DEFAULT 0,
        antiguedad            TEXT,
        ambientes_lista       TEXT DEFAULT '[]',
        servicios_lista       TEXT DEFAULT '[]',
        descripcion           TEXT DEFAULT '',
        FOREIGN KEY (propiedad_id) REFERENCES propiedades(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS propiedad_imagenes (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        propiedad_id    INTEGER NOT NULL,
        ruta            TEXT NOT NULL,
        orden           INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (propiedad_id) REFERENCES propiedades(id) ON DELETE CASCADE
      )
    ''');
  }

  // ════════════════════════════════════════════════════════════════
  // MIGRACIÓN v7 — ubicacion_ficha en propiedad_fichas
  // ════════════════════════════════════════════════════════════════
  Future<void> _migrarV7(Database db) async {
    try {
      await db.execute("ALTER TABLE propiedad_fichas ADD COLUMN ubicacion_ficha TEXT DEFAULT ''");
    } catch (_) {
      // columna ya existe
    }
  }

  Future<void> _migrarV8(Database db) async {
    try {
      await db.execute("ALTER TABLE periodos_fijos ADD COLUMN porcentaje REAL DEFAULT 0");
    } catch (_) {
      // columna ya existe
    }
  }

  // ════════════════════════════════════════════════════════════════
  // MIGRACIÓN v3 — propiedades, periodos_fijos + columnas nuevas
  // ════════════════════════════════════════════════════════════════
  Future<void> _migrarV3(Database db) async {
    // Nueva tabla propiedades
    await db.execute('''
      CREATE TABLE IF NOT EXISTS propiedades (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        carpeta        TEXT,
        tipo           TEXT NOT NULL DEFAULT 'Vivienda',
        estado         TEXT NOT NULL DEFAULT 'Disponible',
        direccion      TEXT NOT NULL,
        entre_calles   TEXT,
        provincia      TEXT,
        localidad      TEXT,
        barrio         TEXT,
        codigo_postal  TEXT,
        propietario_id INTEGER,
        FOREIGN KEY (propietario_id) REFERENCES propietarios(id) ON DELETE SET NULL
      )
    ''');

    // Nueva tabla periodos_fijos
    await db.execute('''
      CREATE TABLE IF NOT EXISTS periodos_fijos (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        contrato_id  INTEGER NOT NULL,
        cuota_desde  INTEGER NOT NULL,
        cuota_hasta  INTEGER NOT NULL,
        monto        REAL    NOT NULL DEFAULT 0,
        FOREIGN KEY (contrato_id) REFERENCES contratos(id) ON DELETE CASCADE
      )
    ''');

    // ALTER TABLE inquilinos — campos adicionales del inquilino
    for (final col in [
      'apellido TEXT',
      'domicilio TEXT',
      'localidad_inq TEXT',
      'provincia TEXT',
      'celular TEXT',
      'telefono_alternativo TEXT',
      'email TEXT',
    ]) {
      try {
        await db.execute('ALTER TABLE inquilinos ADD COLUMN $col');
      } catch (_) {} // ignora si ya existe
    }

    // ALTER TABLE contratos — datos del contrato ampliado
    for (final col in [
      'propiedad_id INTEGER',
      'fecha_inicio TEXT',
      'cuotas_total INTEGER DEFAULT 0',
      'fecha_fin TEXT',
      'alquiler_primer_periodo REAL DEFAULT 0',
      'hasta_cuota INTEGER DEFAULT 0',
      'extras REAL DEFAULT 0',
      'primer_dia_pago INTEGER DEFAULT 1',
      'pago_final INTEGER DEFAULT 10',
      'punitorios_porcentaje REAL DEFAULT 0',
      'punitorios_fijos REAL DEFAULT 0',
      'rescindido INTEGER DEFAULT 0',
      'fecha_rescision TEXT',
    ]) {
      try {
        await db.execute('ALTER TABLE contratos ADD COLUMN $col');
      } catch (_) {}
    }

    // ALTER TABLE recibos — referencia al contrato y número de cuota
    for (final col in [
      'contrato_id INTEGER',
      'numero_cuota INTEGER',
    ]) {
      try {
        await db.execute('ALTER TABLE recibos ADD COLUMN $col');
      } catch (_) {}
    }

    // ALTER TABLE servicios_recibo — fecha de vencimiento por ítem
    try {
      await db.execute('ALTER TABLE servicios_recibo ADD COLUMN fecha_vence TEXT');
    } catch (_) {}
  }

  /// Crea las tablas contratos y conceptos_regulares
  Future<void> _crearTablasV2(Database db) async {
    // ── CONTRATOS ─────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS contratos (
        id                               INTEGER PRIMARY KEY AUTOINCREMENT,
        recibo_id                        INTEGER,
        inquilino_id                     INTEGER,
        propietario_id                   INTEGER NOT NULL,
        dias_gracia                      INTEGER NOT NULL DEFAULT 10,
        punitorios_desde_dia             INTEGER NOT NULL DEFAULT 1,
        fecha_alta                       TEXT,
        notas_recibo                     TEXT,
        recordatorio_inquilino           TEXT DEFAULT
          'Recuerde que el contrato de alquiler está próximo a vencer',
        recordatorio_propietario         TEXT DEFAULT
          'Recuerde que el contrato de alquiler de la calle [domicilio] está próximo a vencer',
        alertar_inquilino                INTEGER NOT NULL DEFAULT 1,
        imprimir_recordatorio_inquilino  INTEGER NOT NULL DEFAULT 1,
        alertar_propietario              INTEGER NOT NULL DEFAULT 1,
        imprimir_recordatorio_propietario INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (recibo_id)       REFERENCES recibos(id)      ON DELETE SET NULL,
        FOREIGN KEY (inquilino_id)    REFERENCES inquilinos(id)   ON DELETE SET NULL,
        FOREIGN KEY (propietario_id)  REFERENCES propietarios(id) ON DELETE CASCADE
      )
    ''');

    // ── CONCEPTOS_REGULARES ───────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS conceptos_regulares (
        id                          INTEGER PRIMARY KEY AUTOINCREMENT,
        contrato_id                 INTEGER NOT NULL,
        descripcion                 TEXT,
        monto                       REAL NOT NULL DEFAULT 0,
        porcentual                  REAL NOT NULL DEFAULT 0.0,
        tiene_comprobante           INTEGER NOT NULL DEFAULT 0,
        tipo                        TEXT NOT NULL DEFAULT 'regular',
        fecha_vence                 TEXT,
        efecto_inquilino            TEXT NOT NULL DEFAULT 'sin_efecto',
        aplica_punitorios_inquilino INTEGER NOT NULL DEFAULT 0,
        efecto_propietario          TEXT NOT NULL DEFAULT 'sin_efecto',
        aplica_administracion       INTEGER NOT NULL DEFAULT 0,
        aplica_todos                INTEGER NOT NULL DEFAULT 1,
        propietario_especifico      TEXT,
        FOREIGN KEY (contrato_id) REFERENCES contratos(id) ON DELETE CASCADE
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

  /// Lista inquilinos con propietario y propiedad (del contrato más reciente)
  Future<List<Map<String, dynamic>>> obtenerInquilinosConDetalle() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        i.*,
        p.nombre  AS propietario_nombre,
        c.id      AS contrato_id,
        pr.direccion  AS propiedad_direccion,
        pr.localidad  AS propiedad_localidad
      FROM inquilinos i
      LEFT JOIN propietarios p  ON i.propietario_id = p.id
      LEFT JOIN contratos    c  ON c.inquilino_id = i.id
      LEFT JOIN propiedades  pr ON c.propiedad_id = pr.id
      GROUP BY i.id
      ORDER BY i.nombre ASC, i.apellido ASC
    ''');
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
        i.celular  AS inquilino_celular,
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
    // Borrar servicios asociados primero
    await db.delete(
      'servicios_recibo',
      where: 'recibo_id = ?',
      whereArgs: [id],
    );
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

  /// Obtiene los servicios del último recibo de un contrato dado.
  /// Sirve para pre-cargar los mismos conceptos únicos en el siguiente recibo.
  Future<List<Map<String, dynamic>>> obtenerServiciosUltimoRecibo(
      int contratoId) async {
    final db = await database;
    // Buscar el último recibo del contrato
    final recibos = await db.query(
      'recibos',
      columns: ['id'],
      where: 'contrato_id = ?',
      whereArgs: [contratoId],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (recibos.isEmpty) return [];
    final ultimoReciboId = recibos.first['id'] as int;
    return await db.query(
      'servicios_recibo',
      where: 'recibo_id = ?',
      whereArgs: [ultimoReciboId],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // NUEVO — CONTRATOS — CRUD
  // ════════════════════════════════════════════════════════════════

  Future<int> insertarContrato(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('contratos', data);
  }

  Future<List<Map<String, dynamic>>> obtenerContratos() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        c.*,
        p.nombre AS propietario_nombre,
        i.nombre AS inquilino_nombre
      FROM contratos c
      LEFT JOIN propietarios p ON c.propietario_id = p.id
      LEFT JOIN inquilinos   i ON c.inquilino_id   = i.id
      ORDER BY c.fecha_alta DESC
    ''');
  }

  Future<Map<String, dynamic>?> obtenerContratoPorId(int id) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        c.*,
        p.nombre   AS propietario_nombre,
        i.nombre   AS inquilino_nombre,
        d.direccion,
        d.localidad
      FROM contratos c
      LEFT JOIN propietarios p ON c.propietario_id = p.id
      LEFT JOIN inquilinos   i ON c.inquilino_id   = i.id
      LEFT JOIN domicilios   d ON d.propietario_id = c.propietario_id
      WHERE c.id = ?
      LIMIT 1
    ''', [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<Map<String, dynamic>?> obtenerContratoPorPropietario(
      int propietarioId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        c.*,
        p.nombre   AS propietario_nombre,
        i.nombre   AS inquilino_nombre,
        d.direccion,
        d.localidad
      FROM contratos c
      LEFT JOIN propietarios p ON c.propietario_id = p.id
      LEFT JOIN inquilinos   i ON c.inquilino_id   = i.id
      LEFT JOIN domicilios   d ON d.propietario_id = c.propietario_id
      WHERE c.propietario_id = ?
      ORDER BY c.id DESC
      LIMIT 1
    ''', [propietarioId]);
    return result.isNotEmpty ? result.first : null;
  }

  /// Devuelve el contrato activo (no rescindido) más reciente de un inquilino.
  /// Si no hay activos, devuelve cualquiera. Null si el inquilino no tiene contratos.
  Future<Map<String, dynamic>?> obtenerContratoActivoPorInquilino(
      int inquilinoId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT c.*
      FROM contratos c
      WHERE c.inquilino_id = ?
      ORDER BY COALESCE(c.rescindido, 0) ASC, c.id DESC
      LIMIT 1
    ''', [inquilinoId]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<Map<String, dynamic>?> obtenerContratoPorRecibo(int reciboId) async {
    final db = await database;
    final result = await db.query(
      'contratos',
      where: 'recibo_id = ?',
      whereArgs: [reciboId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> actualizarContrato(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'contratos',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> eliminarContrato(int id) async {
    final db = await database;
    return await db.delete(
      'contratos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // NUEVO — CONCEPTOS_REGULARES — CRUD
  // ════════════════════════════════════════════════════════════════

  Future<int> insertarConcepto(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('conceptos_regulares', data);
  }

  Future<List<Map<String, dynamic>>> obtenerConceptosPorContrato(
      int contratoId) async {
    final db = await database;
    return await db.query(
      'conceptos_regulares',
      where: 'contrato_id = ?',
      whereArgs: [contratoId],
      orderBy: 'id ASC',
    );
  }

  Future<List<Map<String, dynamic>>> obtenerConceptosRegularesPorContrato(
      int contratoId) async {
    final db = await database;
    return await db.query(
      'conceptos_regulares',
      where: 'contrato_id = ? AND tipo = ?',
      whereArgs: [contratoId, 'regular'],
      orderBy: 'id ASC',
    );
  }

  Future<List<Map<String, dynamic>>> obtenerConceptosUnicosPorContrato(
      int contratoId) async {
    final db = await database;
    return await db.query(
      'conceptos_regulares',
      where: 'contrato_id = ? AND tipo = ?',
      whereArgs: [contratoId, 'unico'],
      orderBy: 'fecha_vence ASC',
    );
  }

  Future<Map<String, dynamic>?> obtenerConceptoPorId(int id) async {
    final db = await database;
    final result = await db.query(
      'conceptos_regulares',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> actualizarConcepto(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'conceptos_regulares',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> eliminarConcepto(int id) async {
    final db = await database;
    return await db.delete(
      'conceptos_regulares',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> eliminarConceptosPorContrato(int contratoId) async {
    final db = await database;
    await db.delete(
      'conceptos_regulares',
      where: 'contrato_id = ?',
      whereArgs: [contratoId],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // CONSULTAS COMPUESTAS — Estadísticas y Reportes
  // ════════════════════════════════════════════════════════════════

  /// Resumen por propietario: total cobrado, total pendiente, saldo
  /// Búsqueda global: propietarios, inquilinos, propiedades, contratos
  Future<List<Map<String, dynamic>>> busquedaGlobal(String query) async {
    final db = await database;
    final q = '%$query%';
    final resultados = <Map<String, dynamic>>[];

    // Propietarios
    final props = await db.rawQuery(
      "SELECT id, nombre, 'propietario' AS tipo FROM propietarios WHERE nombre LIKE ?",
      [q],
    );
    resultados.addAll(props);

    // Inquilinos
    final inqs = await db.rawQuery(
      "SELECT id, nombre || ' ' || COALESCE(apellido, '') AS nombre, 'inquilino' AS tipo FROM inquilinos WHERE nombre LIKE ? OR apellido LIKE ?",
      [q, q],
    );
    resultados.addAll(inqs);

    // Propiedades
    final prods = await db.rawQuery(
      "SELECT id, direccion || CASE WHEN localidad != '' THEN ', ' || localidad ELSE '' END AS nombre, 'propiedad' AS tipo FROM propiedades WHERE direccion LIKE ? OR localidad LIKE ?",
      [q, q],
    );
    resultados.addAll(prods);

    // Contratos (por dirección propiedad o inquilino)
    final contr = await db.rawQuery(
      "SELECT c.id, COALESCE(pr.direccion, '') || ' — ' || COALESCE(i.nombre, '') || ' ' || COALESCE(i.apellido, '') AS nombre, 'contrato' AS tipo FROM contratos c LEFT JOIN propiedades pr ON c.propiedad_id = pr.id LEFT JOIN inquilinos i ON c.inquilino_id = i.id WHERE pr.direccion LIKE ? OR i.nombre LIKE ? OR i.apellido LIKE ? LIMIT 20",
      [q, q, q],
    );
    resultados.addAll(contr);

    // Garantes
    final gars = await db.rawQuery(
      "SELECT id, nombre, 'garante' AS tipo FROM garantes WHERE nombre LIKE ?",
      [q],
    );
    resultados.addAll(gars);

    return resultados;
  }

  Future<List<Map<String, dynamic>>> obtenerResumenPorPropietario() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        p.id,
        p.nombre                        AS propietario_nombre,
        p.telefono                      AS propietario_telefono,
        (SELECT i.nombre FROM inquilinos i WHERE i.propietario_id = p.id LIMIT 1)
                                        AS inquilino_nombre,
        (SELECT d.direccion FROM domicilios d WHERE d.propietario_id = p.id LIMIT 1)
                                        AS direccion,
        (SELECT d.localidad FROM domicilios d WHERE d.propietario_id = p.id LIMIT 1)
                                        AS localidad,
        (SELECT COUNT(*) FROM recibos r WHERE r.propietario_id = p.id)
                                        AS total_recibos,
        (SELECT COALESCE(SUM(r.monto_total), 0) FROM recibos r WHERE r.propietario_id = p.id)
                                        AS total_monto,
        (SELECT COALESCE(SUM(r.monto_abonado), 0) FROM recibos r WHERE r.propietario_id = p.id)
                                        AS total_cobrado,
        (SELECT COALESCE(SUM(r.saldo), 0) FROM recibos r WHERE r.propietario_id = p.id)
                                        AS total_pendiente
      FROM propietarios p
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

    final cobradoMes = ((await db.rawQuery(
      'SELECT COALESCE(SUM(monto_abonado), 0) AS total FROM recibos '
      'WHERE fecha_emision BETWEEN ? AND ?',
      [primerDiaMes, ultimoDiaMesStr],
    ))
            .first['total'] as num?)
        ?.toDouble() ??
        0.0;

    final pendienteTotal = ((await db.rawQuery(
      "SELECT COALESCE(SUM(saldo), 0) AS total FROM recibos "
      "WHERE estado IN ('pendiente', 'parcial')",
    ))
            .first['total'] as num?)
        ?.toDouble() ??
        0.0;

    return {
      'total_propietarios': totalPropietarios,
      'recibos_mes': recibosMes,
      'cobrado_mes': cobradoMes,
      'pendiente_total': pendienteTotal,
    };
  }

  /// Datos mensuales de ingresos (total emitido) y cobros (abonado) por mes
  Future<List<Map<String, dynamic>>> obtenerDatosMensuales(
      {int meses = 12}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        strftime('%Y-%m', fecha_emision) AS mes,
        COALESCE(SUM(monto_total), 0)   AS total_emitido,
        COALESCE(SUM(monto_abonado), 0) AS total_cobrado
      FROM recibos
      WHERE fecha_emision >= date('now', '-$meses months')
      GROUP BY strftime('%Y-%m', fecha_emision)
      ORDER BY mes ASC
    ''');
  }

  /// Estadísticas generales de la app (conteos)
  Future<Map<String, int>> obtenerConteoGeneral() async {
    final db = await database;
    final totalContratos = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM contratos')) ?? 0;
    final contratosActivos = Sqflite.firstIntValue(
          await db.rawQuery(
              "SELECT COUNT(*) FROM contratos WHERE rescindido = 0")) ?? 0;
    final totalPropiedades = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM propiedades')) ?? 0;
    final totalPropietarios = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM propietarios')) ?? 0;
    final totalInquilinos = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM inquilinos')) ?? 0;
    final totalRecibos = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM recibos')) ?? 0;
    return {
      'contratos': totalContratos,
      'contratos_activos': contratosActivos,
      'propiedades': totalPropiedades,
      'propietarios': totalPropietarios,
      'inquilinos': totalInquilinos,
      'recibos': totalRecibos,
    };
  }

  /// Contratos creados por mes (últimos N meses)
  Future<List<Map<String, dynamic>>> obtenerContratosPorMes(
      {int meses = 12}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        strftime('%Y-%m', fecha_inicio) AS mes,
        COUNT(*) AS cantidad
      FROM contratos
      WHERE fecha_inicio IS NOT NULL
        AND fecha_inicio != ''
      GROUP BY strftime('%Y-%m', fecha_inicio)
      ORDER BY mes ASC
    ''');
  }

  /// Recibos pendientes o parciales (todas las fechas) con datos del propietario
  Future<List<Map<String, dynamic>>> obtenerRecibosPendientes() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        r.*,
        p.nombre   AS propietario_nombre,
        p.telefono AS propietario_telefono,
        i.nombre   AS inquilino_nombre,
        i.apellido AS inquilino_apellido,
        i.celular  AS inquilino_celular,
        i.telefono AS inquilino_telefono,
        d.direccion,
        d.localidad
      FROM recibos r
      LEFT JOIN propietarios p ON r.propietario_id = p.id
      LEFT JOIN inquilinos   i ON r.inquilino_id   = i.id
      LEFT JOIN domicilios   d ON r.domicilio_id   = d.id
      WHERE r.estado IN ('pendiente', 'parcial')
      ORDER BY r.id DESC
    ''');
  }

  /// Todos los recibos con filtros opcionales para Excel
  Future<List<Map<String, dynamic>>> obtenerRecibosParaExcel({
    String? fechaDesde,
    String? fechaHasta,
    int? propietarioId,
    int? inquilinoId,
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
    if (inquilinoId != null) {
      condiciones.add('r.inquilino_id = ?');
      args.add(inquilinoId);
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
        COALESCE(pr.direccion, d.direccion, '') AS direccion,
        COALESCE(pr.localidad, d.localidad, '') AS localidad,
        GROUP_CONCAT(s.descripcion, ' | ') AS servicios_descripcion
      FROM recibos r
      LEFT JOIN propietarios     p  ON r.propietario_id = p.id
      LEFT JOIN inquilinos       i  ON r.inquilino_id   = i.id
      LEFT JOIN domicilios       d  ON r.domicilio_id   = d.id
      LEFT JOIN contratos        c  ON c.id = r.contrato_id
      LEFT JOIN propiedades      pr ON pr.id = c.propiedad_id
      LEFT JOIN servicios_recibo s  ON s.recibo_id      = r.id
      $where
      GROUP BY r.id
      ORDER BY r.fecha_emision DESC
    ''', args);
  }

  // NUEVO — Recibos con info de contrato y conceptos para detalle propietario
  Future<List<Map<String, dynamic>>> obtenerRecibosConExtras(
      int propietarioId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        r.*,
        p.nombre  AS propietario_nombre,
        i.nombre  AS inquilino_nombre,
        i.celular AS inquilino_celular,
        i.telefono AS inquilino_telefono,
        d.direccion,
        d.localidad,
        c.id      AS contrato_id,
        c.notas_recibo,
        c.alertar_inquilino,
        c.alertar_propietario,
        (SELECT COUNT(*) FROM conceptos_regulares cr WHERE cr.contrato_id = c.id) AS cantidad_conceptos
      FROM recibos r
      LEFT JOIN propietarios p ON r.propietario_id = p.id
      LEFT JOIN inquilinos   i ON r.inquilino_id   = i.id
      LEFT JOIN domicilios   d ON r.domicilio_id   = d.id
      LEFT JOIN contratos    c ON c.recibo_id      = r.id
      WHERE r.propietario_id = ?
      ORDER BY r.fecha_emision DESC
    ''', [propietarioId]);
  }

  // ════════════════════════════════════════════════════════════════
  // PROPIEDADES — CRUD
  // ════════════════════════════════════════════════════════════════

  Future<int> insertarPropiedad(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('propiedades', data);
  }

  Future<List<Map<String, dynamic>>> obtenerPropiedades() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT pr.*, p.nombre AS propietario_nombre
      FROM propiedades pr
      LEFT JOIN propietarios p ON pr.propietario_id = p.id
      ORDER BY pr.direccion ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> obtenerPropiedadesPorPropietario(
      int propietarioId) async {
    final db = await database;
    return await db.query(
      'propiedades',
      where: 'propietario_id = ?',
      whereArgs: [propietarioId],
      orderBy: 'direccion ASC',
    );
  }

  /// Propiedades vinculadas a un propietario via contratos activos
  Future<List<Map<String, dynamic>>> obtenerPropiedadesDeContratosPorPropietario(
      int propietarioId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT DISTINCT pr.id, pr.direccion, pr.localidad
      FROM contratos c
      INNER JOIN propiedades pr ON c.propiedad_id = pr.id
      WHERE c.propietario_id = ?
      ORDER BY pr.direccion ASC
    ''', [propietarioId]);
  }

  /// Contratos de un propietario con info de propiedad e inquilino
  Future<List<Map<String, dynamic>>> obtenerContratosPorPropietario(
      int propietarioId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        c.*,
        pr.direccion  AS propiedad_direccion,
        pr.localidad  AS propiedad_localidad,
        i.nombre      AS inquilino_nombre,
        i.apellido    AS inquilino_apellido
      FROM contratos c
      LEFT JOIN propiedades pr ON c.propiedad_id = pr.id
      LEFT JOIN inquilinos  i  ON c.inquilino_id = i.id
      WHERE c.propietario_id = ?
      ORDER BY pr.direccion ASC
    ''', [propietarioId]);
  }

  /// Recibos de un contrato específico
  Future<List<Map<String, dynamic>>> obtenerRecibosPorContrato(
      int contratoId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        r.*,
        p.nombre  AS propietario_nombre,
        i.nombre  AS inquilino_nombre,
        i.celular AS inquilino_celular,
        i.telefono AS inquilino_telefono,
        COALESCE(pr.direccion, d.direccion, '') AS direccion,
        COALESCE(pr.localidad, d.localidad, '') AS localidad,
        c.notas_recibo,
        c.alertar_inquilino,
        c.alertar_propietario
      FROM recibos r
      LEFT JOIN propietarios p  ON r.propietario_id = p.id
      LEFT JOIN inquilinos   i  ON r.inquilino_id   = i.id
      LEFT JOIN domicilios   d  ON r.domicilio_id   = d.id
      LEFT JOIN contratos    c  ON r.contrato_id    = c.id
      LEFT JOIN propiedades  pr ON c.propiedad_id   = pr.id
      WHERE r.contrato_id = ?
      ORDER BY r.fecha_emision DESC
    ''', [contratoId]);
  }

  Future<Map<String, dynamic>?> obtenerPropiedadPorId(int id) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT pr.*, p.nombre AS propietario_nombre
      FROM propiedades pr
      LEFT JOIN propietarios p ON pr.propietario_id = p.id
      WHERE pr.id = ?
    ''', [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> actualizarPropiedad(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('propiedades', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> eliminarPropiedad(int id) async {
    final db = await database;
    return await db.delete('propiedades', where: 'id = ?', whereArgs: [id]);
  }

  // ════════════════════════════════════════════════════════════════
  // FICHAS DE PROPIEDAD — CRUD
  // ════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> obtenerFicha(int propiedadId) async {
    final db = await database;
    final result = await db.query('propiedad_fichas',
        where: 'propiedad_id = ?', whereArgs: [propiedadId]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> upsertFicha(int propiedadId, Map<String, dynamic> data) async {
    final db = await database;
    final existe = await obtenerFicha(propiedadId);
    data['propiedad_id'] = propiedadId;
    if (existe != null) {
      await db.update('propiedad_fichas', data,
          where: 'propiedad_id = ?', whereArgs: [propiedadId]);
    } else {
      await db.insert('propiedad_fichas', data);
    }
  }

  // ════════════════════════════════════════════════════════════════
  // IMÁGENES DE PROPIEDAD — CRUD
  // ════════════════════════════════════════════════════════════════

  Future<int> insertarImagenPropiedad(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('propiedad_imagenes', data);
  }

  Future<List<Map<String, dynamic>>> obtenerImagenesPropiedad(
      int propiedadId) async {
    final db = await database;
    return await db.query('propiedad_imagenes',
        where: 'propiedad_id = ?',
        whereArgs: [propiedadId],
        orderBy: 'orden ASC');
  }

  Future<int> eliminarImagenPropiedad(int id) async {
    final db = await database;
    return await db.delete('propiedad_imagenes',
        where: 'id = ?', whereArgs: [id]);
  }

  // ════════════════════════════════════════════════════════════════
  // PERIODOS_FIJOS — CRUD
  // ════════════════════════════════════════════════════════════════

  Future<void> upsertPeriodosFijos(
      int contratoId, List<Map<String, dynamic>> periodos) async {
    final db = await database;
    await db.delete('periodos_fijos',
        where: 'contrato_id = ?', whereArgs: [contratoId]);
    for (final p in periodos) {
      await db.insert('periodos_fijos', {...p, 'contrato_id': contratoId});
    }
  }

  Future<List<Map<String, dynamic>>> obtenerPeriodosPorContrato(
      int contratoId) async {
    final db = await database;
    return await db.query(
      'periodos_fijos',
      where: 'contrato_id = ?',
      whereArgs: [contratoId],
      orderBy: 'cuota_desde ASC',
    );
  }

  Future<void> eliminarPeriodosPorContrato(int contratoId) async {
    final db = await database;
    await db.delete('periodos_fijos',
        where: 'contrato_id = ?', whereArgs: [contratoId]);
  }

  // ════════════════════════════════════════════════════════════════
  // GARANTES — CRUD
  // ════════════════════════════════════════════════════════════════

  Future<void> upsertGarantes(
      int contratoId, List<Map<String, dynamic>> garantes) async {
    final db = await database;
    await db.delete('garantes',
        where: 'contrato_id = ?', whereArgs: [contratoId]);
    for (final g in garantes) {
      await db.insert('garantes', {
        'contrato_id': contratoId,
        'nombre': g['nombre'],
        'telefono': g['telefono'],
        'email': g['email'],
        'tipo_garantia': g['tipo_garantia'] ?? 'recibo_sueldo',
      });
    }
  }

  Future<List<Map<String, dynamic>>> obtenerGarantesPorContrato(
      int contratoId) async {
    final db = await database;
    return await db.query('garantes',
        where: 'contrato_id = ?', whereArgs: [contratoId]);
  }

  Future<Map<String, dynamic>?> obtenerGarantePorId(int id) async {
    final db = await database;
    final result = await db.query('garantes',
        where: 'id = ?', whereArgs: [id], limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> eliminarGarantesPorContrato(int contratoId) async {
    final db = await database;
    await db.delete('garantes',
        where: 'contrato_id = ?', whereArgs: [contratoId]);
  }

  Future<List<Map<String, dynamic>>> obtenerGarantesConDetalle() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT g.*,
             p.nombre   AS propietario_nombre,
             i.nombre   AS inquilino_nombre,
             pr.direccion AS propiedad_direccion
      FROM garantes g
      LEFT JOIN contratos c ON g.contrato_id = c.id
      LEFT JOIN propietarios p ON c.propietario_id = p.id
      LEFT JOIN inquilinos i ON c.inquilino_id = i.id
      LEFT JOIN propiedades pr ON c.propiedad_id = pr.id
      ORDER BY g.nombre
    ''');
  }

  // ════════════════════════════════════════════════════════════════
  // CONTRATOS — consultas ampliadas v3
  // ════════════════════════════════════════════════════════════════

  /// Lista todos los contratos con JOIN completo (propiedad + inquilino + propietario)
  Future<List<Map<String, dynamic>>> obtenerContratosActivos() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        c.*,
        pr.direccion      AS propiedad_direccion,
        pr.localidad      AS propiedad_localidad,
        pr.tipo           AS propiedad_tipo,
        i.nombre          AS inquilino_nombre,
        i.apellido        AS inquilino_apellido,
        i.celular         AS inquilino_celular,
        i.telefono        AS inquilino_telefono,
        p.nombre          AS propietario_nombre
      FROM contratos c
      LEFT JOIN propiedades  pr ON c.propiedad_id  = pr.id
      LEFT JOIN inquilinos   i  ON c.inquilino_id  = i.id
      LEFT JOIN propietarios p  ON c.propietario_id = p.id
      ORDER BY pr.direccion ASC, i.apellido ASC, i.nombre ASC
    ''');
  }

  /// Número de cuota siguiente para un contrato (COUNT recibos existentes + 1)
  Future<int> obtenerNumCuotaParaContrato(int contratoId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM recibos WHERE contrato_id = ?',
      [contratoId],
    );
    final cnt = result.first['cnt'] as int? ?? 0;
    return cnt + 1;
  }

  /// Monto del último período cargado del contrato.
  /// Siempre toma el período más reciente (mayor cuota_hasta).
  Future<double> obtenerMontoPeriodo(int contratoId, int numeroCuota) async {
    final db = await database;
    // Buscar el período fijo que contiene la cuota actual.
    // Si hay solapamiento (períodos viejos + nuevos para el mismo rango),
    // el ORDER BY cuota_desde DESC asegura que gane el más reciente.
    final periodoActual = await db.query(
      'periodos_fijos',
      where: 'contrato_id = ? AND cuota_desde <= ? AND cuota_hasta >= ?',
      whereArgs: [contratoId, numeroCuota, numeroCuota],
      orderBy: 'cuota_desde DESC',
      limit: 1,
    );
    if (periodoActual.isNotEmpty) {
      return (periodoActual.first['monto'] as num).toDouble();
    }
    // Fallback: último período cargado (para cuotas fuera de rango)
    final ultimoPeriodo = await db.query(
      'periodos_fijos',
      where: 'contrato_id = ?',
      whereArgs: [contratoId],
      orderBy: 'cuota_hasta DESC',
      limit: 1,
    );
    if (ultimoPeriodo.isNotEmpty) {
      return (ultimoPeriodo.first['monto'] as num).toDouble();
    }
    // Fallback: alquiler_primer_periodo del contrato
    final contrato = await db.query(
      'contratos',
      columns: ['alquiler_primer_periodo'],
      where: 'id = ?',
      whereArgs: [contratoId],
      limit: 1,
    );
    if (contrato.isNotEmpty) {
      return (contrato.first['alquiler_primer_periodo'] as num?)?.toDouble() ?? 0.0;
    }
    return 0.0;
  }

  /// Devuelve los recibos ya emitidos cuya fecha de vencimiento (o emisión
  /// si no hay vencimiento) cae dentro del rango [desde, hasta].
  /// Incluye datos del contrato, inquilino, propiedad y propietario para
  /// poder mostrarlos en el calendario junto a las proyecciones pendientes.
  Future<List<Map<String, dynamic>>> obtenerRecibosEmitidosPorFecha({
    required String desde,
    required String hasta,
  }) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        r.id                        AS recibo_id,
        r.numero_recibo,
        r.contrato_id,
        r.numero_cuota,
        r.fecha_emision,
        r.fecha_vencimiento,
        r.monto_total,
        r.estado,
        c.cuotas_total,
        c.fecha_inicio,
        c.primer_dia_pago,
        pr.direccion                AS propiedad_direccion,
        i.nombre                    AS inquilino_nombre,
        i.apellido                  AS inquilino_apellido,
        i.celular                   AS inquilino_celular,
        i.telefono                  AS inquilino_telefono,
        p.nombre                    AS propietario_nombre
      FROM recibos r
      LEFT JOIN contratos    c  ON r.contrato_id    = c.id
      LEFT JOIN propiedades  pr ON c.propiedad_id   = pr.id
      LEFT JOIN inquilinos   i  ON r.inquilino_id   = i.id
      LEFT JOIN propietarios p  ON r.propietario_id = p.id
      WHERE r.contrato_id IS NOT NULL
        AND r.fecha_emision BETWEEN ? AND ?
      ORDER BY COALESCE(r.fecha_vencimiento, r.fecha_emision) ASC
    ''', [desde, hasta]);
  }

  /// Devuelve los datos necesarios para proyectar los próximos recibos
  /// de cada contrato activo. Incluye:
  /// - datos del contrato (fecha_inicio, primer_dia_pago, cuotas_total)
  /// - cuántas cuotas ya fueron emitidas (num_cuotas_emitidas)
  /// - datos del inquilino, propiedad y propietario
  /// - monto actual (del último período fijo, si hay)
  Future<List<Map<String, dynamic>>> obtenerDatosProyeccionContratos() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        c.id,
        c.fecha_inicio,
        c.cuotas_total,
        c.primer_dia_pago,
        c.alquiler_primer_periodo,
        pr.direccion                AS propiedad_direccion,
        i.nombre                    AS inquilino_nombre,
        i.apellido                  AS inquilino_apellido,
        i.celular                   AS inquilino_celular,
        i.telefono                  AS inquilino_telefono,
        p.nombre                    AS propietario_nombre,
        (SELECT COALESCE(MAX(r.numero_cuota), 0) FROM recibos r WHERE r.contrato_id = c.id)
                                    AS ultima_cuota_emitida,
        (SELECT r.fecha_emision FROM recibos r
          WHERE r.contrato_id = c.id
          ORDER BY r.id DESC LIMIT 1)
                                    AS ultima_fecha_emision,
        (SELECT pf.monto FROM periodos_fijos pf
          WHERE pf.contrato_id = c.id
          ORDER BY pf.cuota_hasta DESC
          LIMIT 1)                  AS monto_periodo_actual
      FROM contratos c
      LEFT JOIN propiedades  pr ON c.propiedad_id  = pr.id
      LEFT JOIN inquilinos   i  ON c.inquilino_id  = i.id
      LEFT JOIN propietarios p  ON c.propietario_id = p.id
      WHERE COALESCE(c.rescindido, 0) = 0
        AND c.fecha_inicio IS NOT NULL
        AND c.fecha_inicio != ''
      ORDER BY c.id ASC
    ''');
  }
}
