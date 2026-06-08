class PeriodoFijoModel {
  final int? id;
  final int contratoId;
  final int cuotaDesde;
  final int cuotaHasta;
  final double monto;
  final double porcentaje;

  PeriodoFijoModel({
    this.id,
    required this.contratoId,
    required this.cuotaDesde,
    required this.cuotaHasta,
    required this.monto,
    this.porcentaje = 0,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'contrato_id': contratoId,
        'cuota_desde': cuotaDesde,
        'cuota_hasta': cuotaHasta,
        'monto': monto,
        'porcentaje': porcentaje,
      };

  factory PeriodoFijoModel.fromMap(Map<String, dynamic> map) => PeriodoFijoModel(
        id: map['id'] as int?,
        contratoId: map['contrato_id'] as int,
        cuotaDesde: map['cuota_desde'] as int,
        cuotaHasta: map['cuota_hasta'] as int,
        monto: (map['monto'] as num).toDouble(),
        porcentaje: (map['porcentaje'] as num?)?.toDouble() ?? 0,
      );

  PeriodoFijoModel copyWith({
    int? id,
    int? contratoId,
    int? cuotaDesde,
    int? cuotaHasta,
    double? monto,
    double? porcentaje,
  }) =>
      PeriodoFijoModel(
        id: id ?? this.id,
        contratoId: contratoId ?? this.contratoId,
        cuotaDesde: cuotaDesde ?? this.cuotaDesde,
        cuotaHasta: cuotaHasta ?? this.cuotaHasta,
        monto: monto ?? this.monto,
        porcentaje: porcentaje ?? this.porcentaje,
      );

  @override
  String toString() => 'Cuota $cuotaDesde–$cuotaHasta: \$$monto (+$porcentaje%)';
}
