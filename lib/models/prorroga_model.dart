class ProrrogaModel {
  final int? id;
  final int contratoId;
  final String fechaInicio;
  final String fechaFin;
  final int cuotasTotal;
  final double montoBase;
  final bool activa;
  final String fechaCreacion;
  final List<ProrrogaPeriodoModel> periodos;

  ProrrogaModel({
    this.id,
    required this.contratoId,
    required this.fechaInicio,
    required this.fechaFin,
    required this.cuotasTotal,
    required this.montoBase,
    this.activa = true,
    required this.fechaCreacion,
    this.periodos = const [],
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'contrato_id': contratoId,
        'fecha_inicio': fechaInicio,
        'fecha_fin': fechaFin,
        'cuotas_total': cuotasTotal,
        'monto_base': montoBase,
        'activa': activa ? 1 : 0,
        'fecha_creacion': fechaCreacion,
      };

  factory ProrrogaModel.fromMap(Map<String, dynamic> map) => ProrrogaModel(
        id: map['id'] as int?,
        contratoId: map['contrato_id'] as int,
        fechaInicio: map['fecha_inicio'] as String,
        fechaFin: map['fecha_fin'] as String,
        cuotasTotal: map['cuotas_total'] as int,
        montoBase: (map['monto_base'] as num).toDouble(),
        activa: (map['activa'] as int) == 1,
        fechaCreacion: map['fecha_creacion'] as String? ?? '',
        periodos: [],
      );

  ProrrogaModel copyWith({
    int? id,
    int? contratoId,
    String? fechaInicio,
    String? fechaFin,
    int? cuotasTotal,
    double? montoBase,
    bool? activa,
    String? fechaCreacion,
    List<ProrrogaPeriodoModel>? periodos,
  }) =>
      ProrrogaModel(
        id: id ?? this.id,
        contratoId: contratoId ?? this.contratoId,
        fechaInicio: fechaInicio ?? this.fechaInicio,
        fechaFin: fechaFin ?? this.fechaFin,
        cuotasTotal: cuotasTotal ?? this.cuotasTotal,
        montoBase: montoBase ?? this.montoBase,
        activa: activa ?? this.activa,
        fechaCreacion: fechaCreacion ?? this.fechaCreacion,
        periodos: periodos ?? this.periodos,
      );
}

class ProrrogaPeriodoModel {
  final int? id;
  final int prorrogaId;
  final int cuotaDesde;
  final int cuotaHasta;
  final double monto;
  final double porcentaje;
  final int vaPor;
  final int mes;

  ProrrogaPeriodoModel({
    this.id,
    required this.prorrogaId,
    required this.cuotaDesde,
    required this.cuotaHasta,
    required this.monto,
    this.porcentaje = 0,
    this.vaPor = 0,
    this.mes = 0,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'prorroga_id': prorrogaId,
        'cuota_desde': cuotaDesde,
        'cuota_hasta': cuotaHasta,
        'monto': monto,
        'porcentaje': porcentaje,
        'va_por': vaPor,
        'mes': mes,
      };

  factory ProrrogaPeriodoModel.fromMap(Map<String, dynamic> map) => ProrrogaPeriodoModel(
        id: map['id'] as int?,
        prorrogaId: map['prorroga_id'] as int,
        cuotaDesde: map['cuota_desde'] as int,
        cuotaHasta: map['cuota_hasta'] as int,
        monto: (map['monto'] as num).toDouble(),
        porcentaje: (map['porcentaje'] as num?)?.toDouble() ?? 0,
        vaPor: (map['va_por'] as num?)?.toInt() ?? 0,
        mes: (map['mes'] as num?)?.toInt() ?? 0,
      );

  ProrrogaPeriodoModel copyWith({
    int? id,
    int? prorrogaId,
    int? cuotaDesde,
    int? cuotaHasta,
    double? monto,
    double? porcentaje,
    int? vaPor,
    int? mes,
  }) =>
      ProrrogaPeriodoModel(
        id: id ?? this.id,
        prorrogaId: prorrogaId ?? this.prorrogaId,
        cuotaDesde: cuotaDesde ?? this.cuotaDesde,
        cuotaHasta: cuotaHasta ?? this.cuotaHasta,
        monto: monto ?? this.monto,
        porcentaje: porcentaje ?? this.porcentaje,
        vaPor: vaPor ?? this.vaPor,
        mes: mes ?? this.mes,
      );
}