class ServicioItemModel {
  final int? id;
  final int? reciboId;
  final String descripcion;
  final double monto;
  final double punitorios;
  final double total;
  final String? fechaVence; // v3: fecha de vencimiento del ítem (yyyy-MM-dd)
  final String? fechaCuota; // mes en letra + año (ej. "Junio 2026"), solo runtime

  ServicioItemModel({
    this.id,
    this.reciboId,
    required this.descripcion,
    required this.monto,
    this.punitorios = 0.0,
    double? total,
    this.fechaVence,
    this.fechaCuota,
  }) : total = total ?? (monto + punitorios);

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        if (reciboId != null) 'recibo_id': reciboId,
        'descripcion': descripcion,
        'monto': monto,
        'punitorios': punitorios,
        'total': total,
        'fecha_vence': fechaVence ?? '',
      };

  factory ServicioItemModel.fromMap(Map<String, dynamic> map) =>
      ServicioItemModel(
        id: map['id'] as int?,
        reciboId: map['recibo_id'] as int?,
        descripcion: map['descripcion'] as String,
        monto: (map['monto'] as num).toDouble(),
        punitorios: (map['punitorios'] as num?)?.toDouble() ?? 0.0,
        total: (map['total'] as num).toDouble(),
        fechaVence: map['fecha_vence'] as String?,
        fechaCuota: map['fecha_cuota'] as String?,
      );

  ServicioItemModel copyWith({
    int? id,
    int? reciboId,
    String? descripcion,
    double? monto,
    double? punitorios,
    double? total,
    String? fechaVence,
    String? fechaCuota,
  }) {
    final nuevoMonto = monto ?? this.monto;
    final nuevosPunitorios = punitorios ?? this.punitorios;
    return ServicioItemModel(
      id: id ?? this.id,
      reciboId: reciboId ?? this.reciboId,
      descripcion: descripcion ?? this.descripcion,
      monto: nuevoMonto,
      punitorios: nuevosPunitorios,
      total: total ?? (nuevoMonto + nuevosPunitorios),
      fechaVence: fechaVence ?? this.fechaVence,
      fechaCuota: fechaCuota ?? this.fechaCuota,
    );
  }
}
