class PropietarioModel {
  final int? id;
  final String nombre;
  final String? telefono;
  final String? email;

  PropietarioModel({
    this.id,
    required this.nombre,
    this.telefono,
    this.email,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'telefono': telefono ?? '',
      'email': email ?? '',
    };
  }

  factory PropietarioModel.fromMap(Map<String, dynamic> map) {
    return PropietarioModel(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      telefono: map['telefono'] as String?,
      email: map['email'] as String?,
    );
  }

  PropietarioModel copyWith({
    int? id,
    String? nombre,
    String? telefono,
    String? email,
  }) {
    return PropietarioModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
    );
  }

  @override
  String toString() => nombre;
}
