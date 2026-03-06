class ServicioItemModel {
  final int? id;
  final int? reciboId;
  final String descripcion;
  final double monto;
  final double punitorios;
  final double total;
  final String? fechaVence; // v3: fecha de vencimiento del ítem (yyyy-MM-dd)

  ServicioItemModel({
    this.id,
    this.reciboId,
    required this.descripcion,
    required this.monto,
    this.punitorios = 0.0,
    double? total,
    this.fechaVence,
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
      );

  ServicioItemModel copyWith({
    int? id,
    int? reciboId,
    String? descripcion,
    double? monto,
    double? punitorios,
    double? total,
    String? fechaVence,
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
    );
  }
}
