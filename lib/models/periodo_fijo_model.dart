class PeriodoFijoModel {
  final int? id;
  final int contratoId;
  final int cuotaDesde;
  final int cuotaHasta;
  final double monto;

  PeriodoFijoModel({
    this.id,
    required this.contratoId,
    required this.cuotaDesde,
    required this.cuotaHasta,
    required this.monto,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'contrato_id': contratoId,
        'cuota_desde': cuotaDesde,
        'cuota_hasta': cuotaHasta,
        'monto': monto,
      };

  factory PeriodoFijoModel.fromMap(Map<String, dynamic> map) => PeriodoFijoModel(
        id: map['id'] as int?,
        contratoId: map['contrato_id'] as int,
        cuotaDesde: map['cuota_desde'] as int,
        cuotaHasta: map['cuota_hasta'] as int,
        monto: (map['monto'] as num).toDouble(),
      );

  PeriodoFijoModel copyWith({
    int? id,
    int? contratoId,
    int? cuotaDesde,
    int? cuotaHasta,
    double? monto,
  }) =>
      PeriodoFijoModel(
        id: id ?? this.id,
        contratoId: contratoId ?? this.contratoId,
        cuotaDesde: cuotaDesde ?? this.cuotaDesde,
        cuotaHasta: cuotaHasta ?? this.cuotaHasta,
        monto: monto ?? this.monto,
      );

  @override
  String toString() => 'Cuota $cuotaDesde–$cuotaHasta: \$$monto';
}
