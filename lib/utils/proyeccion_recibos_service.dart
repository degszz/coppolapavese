import '../database/database_helper.dart';
import '../models/proyeccion_recibo_model.dart';

/// Calcula las fechas de emisión previstas de los próximos recibos
/// de todos los contratos activos, basándose en:
/// - `fecha_inicio` del contrato
/// - `primer_dia_pago` (día del mes en que vence el alquiler)
/// - `cuotas_total` (cantidad de cuotas que tiene el contrato)
/// - cantidad de recibos ya emitidos para ese contrato
///
/// También devuelve los recibos ya emitidos dentro del rango consultado,
/// marcados con [emitido = true], para que el calendario pueda mostrar
/// tanto los recibos existentes como los pendientes de emisión.
class ProyeccionRecibosService {
  final _db = DatabaseHelper();

  /// Devuelve todas las proyecciones (emitidas + pendientes) dentro del
  /// rango [desde, hasta].
  ///
  /// - Recibos emitidos: se muestran en la fecha de vencimiento (o emisión).
  /// - Cuotas pendientes: se proyectan matemáticamente según el contrato.
  /// - Cuotas vencidas (no emitidas y con fecha pasada) también se incluyen.
  Future<List<ProyeccionReciboModel>> obtenerProyecciones({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final resultado = <ProyeccionReciboModel>[];

    // ── 1. Recibos ya emitidos dentro del rango ──────────────────
    final emitidos = await _obtenerEmitidos(desde: desde, hasta: hasta);
    resultado.addAll(emitidos);

    // Conjunto de (contratoId, numeroCuota) ya emitidos para no duplicar
    final emitidosSet = <String>{};
    for (final e in emitidos) {
      if (e.numeroCuota > 0) {
        emitidosSet.add('${e.contratoId}_${e.numeroCuota}');
      }
    }

    // ── 2. Proyecciones pendientes (no emitidas) ─────────────────
    final pendientes = await _obtenerPendientes(
      desde: desde,
      hasta: hasta,
      emitidosSet: emitidosSet,
    );
    resultado.addAll(pendientes);

    // Ordenar por fecha
    resultado.sort((a, b) => a.fechaPrevista.compareTo(b.fechaPrevista));
    return resultado;
  }

  /// Consulta la tabla de recibos para obtener los ya emitidos en el rango.
  Future<List<ProyeccionReciboModel>> _obtenerEmitidos({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final desdeStr =
        '${desde.year}-${desde.month.toString().padLeft(2, '0')}-${desde.day.toString().padLeft(2, '0')}';
    final hastaStr =
        '${hasta.year}-${hasta.month.toString().padLeft(2, '0')}-${hasta.day.toString().padLeft(2, '0')}';

    final rows = await _db.obtenerRecibosEmitidosPorFecha(
      desde: desdeStr,
      hasta: hastaStr,
    );

    final resultado = <ProyeccionReciboModel>[];
    for (final r in rows) {
      final fechaStr =
          (r['fecha_vencimiento'] as String?) ?? (r['fecha_emision'] as String?);
      if (fechaStr == null || fechaStr.isEmpty) continue;

      DateTime fecha;
      try {
        fecha = DateTime.parse(fechaStr);
      } catch (_) {
        continue;
      }

      final inqNombre = ((r['inquilino_nombre'] as String?) ?? '').trim();
      final inqApellido = ((r['inquilino_apellido'] as String?) ?? '').trim();
      final nombreCompleto =
          inqApellido.isNotEmpty ? '$inqNombre $inqApellido'.trim() : inqNombre;

      resultado.add(ProyeccionReciboModel(
        contratoId: (r['contrato_id'] as int?) ?? 0,
        numeroCuota: (r['numero_cuota'] as int?) ?? 0,
        cuotasTotal: (r['cuotas_total'] as int?) ?? 0,
        fechaPrevista: fecha,
        inquilinoNombre:
            nombreCompleto.isEmpty ? '(sin inquilino)' : nombreCompleto,
        inquilinoCelular: r['inquilino_celular'] as String?,
        inquilinoTelefono: r['inquilino_telefono'] as String?,
        propiedadDireccion:
            (r['propiedad_direccion'] as String?) ?? '(sin dirección)',
        propietarioNombre: (r['propietario_nombre'] as String?) ?? '',
        monto: (r['monto_total'] as num?)?.toDouble() ?? 0.0,
        emitido: true,
        reciboId: r['recibo_id'] as int?,
        numeroRecibo: r['numero_recibo'] as int?,
        estadoRecibo: r['estado'] as String?,
      ));
    }
    return resultado;
  }

  /// Proyecta las cuotas pendientes (no emitidas) de contratos activos.
  Future<List<ProyeccionReciboModel>> _obtenerPendientes({
    required DateTime desde,
    required DateTime hasta,
    required Set<String> emitidosSet,
  }) async {
    final contratos = await _db.obtenerDatosProyeccionContratos();
    final resultado = <ProyeccionReciboModel>[];

    for (final c in contratos) {
      final fechaInicioStr = c['fecha_inicio'] as String?;
      if (fechaInicioStr == null || fechaInicioStr.isEmpty) continue;

      DateTime fechaInicio;
      try {
        fechaInicio = DateTime.parse(fechaInicioStr);
      } catch (_) {
        continue;
      }

      final cuotasTotal = (c['cuotas_total'] as int?) ?? 0;
      final primerDiaPago = (c['primer_dia_pago'] as int?) ?? 1;
      final emitidas = (c['num_cuotas_emitidas'] as int?) ?? 0;

      if (cuotasTotal <= 0) continue;
      if (emitidas >= cuotasTotal) continue; // contrato completado

      final inqNombre = ((c['inquilino_nombre'] as String?) ?? '').trim();
      final inqApellido = ((c['inquilino_apellido'] as String?) ?? '').trim();
      final nombreCompleto =
          inqApellido.isNotEmpty ? '$inqNombre $inqApellido'.trim() : inqNombre;

      final monto = (c['monto_periodo_actual'] as num?)?.toDouble() ??
          (c['alquiler_primer_periodo'] as num?)?.toDouble() ??
          0.0;

      final contratoId = c['id'] as int;

      // Proyectar todas las cuotas pendientes del contrato
      for (int cuota = emitidas + 1; cuota <= cuotasTotal; cuota++) {
        // Saltar si esta cuota ya existe como recibo emitido
        if (emitidosSet.contains('${contratoId}_$cuota')) continue;

        final fechaPrev = _proyectarFecha(
          fechaInicio: fechaInicio,
          diaPago: primerDiaPago,
          numeroCuota: cuota,
        );

        // Filtrar por rango
        if (fechaPrev.isBefore(desde)) continue;
        if (fechaPrev.isAfter(hasta)) break;

        resultado.add(ProyeccionReciboModel(
          contratoId: contratoId,
          numeroCuota: cuota,
          cuotasTotal: cuotasTotal,
          fechaPrevista: fechaPrev,
          inquilinoNombre:
              nombreCompleto.isEmpty ? '(sin inquilino)' : nombreCompleto,
          inquilinoCelular: c['inquilino_celular'] as String?,
          inquilinoTelefono: c['inquilino_telefono'] as String?,
          propiedadDireccion:
              (c['propiedad_direccion'] as String?) ?? '(sin dirección)',
          propietarioNombre: (c['propietario_nombre'] as String?) ?? '',
          monto: monto,
          emitido: false,
        ));
      }
    }
    return resultado;
  }

  /// Proyecta la fecha de vencimiento de la cuota N.
  ///
  /// Regla: la cuota 1 vence en el mes de `fechaInicio` el día `diaPago`.
  /// La cuota N vence `N-1` meses después.
  /// Si el día no existe en el mes destino (p.ej. 31 en febrero),
  /// se usa el último día del mes.
  DateTime _proyectarFecha({
    required DateTime fechaInicio,
    required int diaPago,
    required int numeroCuota,
  }) {
    final mesBase = fechaInicio.month + (numeroCuota - 1);
    final anioDest = fechaInicio.year + ((mesBase - 1) ~/ 12);
    final mesDest = ((mesBase - 1) % 12) + 1;

    // Último día válido del mes destino
    final ultimoDia = DateTime(anioDest, mesDest + 1, 0).day;
    final diaFinal = diaPago.clamp(1, ultimoDia);

    return DateTime(anioDest, mesDest, diaFinal);
  }
}
