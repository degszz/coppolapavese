class ServicioItemModel {
  final int? id;
  final int? reciboId;
  final String descripcion;
  final double monto;
  final double punitorios;
  final double total;

  ServicioItemModel({
    this.id,
    this.reciboId,
    required this.descripcion,
    required this.monto,
    this.punitorios = 0.0,
    double? total,
  }) : total = total ?? (monto + (punitorios));

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (reciboId != null) 'recibo_id': reciboId,
      'descripcion': descripcion,
      'monto': monto,
      'punitorios': punitorios,
      'total': total,
    };
  }

  factory ServicioItemModel.fromMap(Map<String, dynamic> map) {
    return ServicioItemModel(
      id: map['id'] as int?,
      reciboId: map['recibo_id'] as int?,
      descripcion: map['descripcion'] as String,
      monto: (map['monto'] as num).toDouble(),
      punitorios: (map['punitorios'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num).toDouble(),
    );
  }

  ServicioItemModel copyWith({
    int? id,
    int? reciboId,
    String? descripcion,
    double? monto,
    double? punitorios,
    double? total,
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
    );
  }
}
