class InquilinoModel {
  final int? id;
  final String nombre;
  final String? telefono;
  final int propietarioId;

  InquilinoModel({
    this.id,
    required this.nombre,
    this.telefono,
    required this.propietarioId,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'telefono': telefono ?? '',
      'propietario_id': propietarioId,
    };
  }

  factory InquilinoModel.fromMap(Map<String, dynamic> map) {
    return InquilinoModel(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      telefono: map['telefono'] as String?,
      propietarioId: map['propietario_id'] as int,
    );
  }

  InquilinoModel copyWith({
    int? id,
    String? nombre,
    String? telefono,
    int? propietarioId,
  }) {
    return InquilinoModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      propietarioId: propietarioId ?? this.propietarioId,
    );
  }

  @override
  String toString() => nombre;
}
