class InquilinoModel {
  final int? id;
  final String nombre;
  final String? apellido;
  final String? telefono;
  final String? celular;
  final String? telefonoAlternativo;
  final String? email;
  final String? domicilio;
  final String? localidad;
  final String? provincia;
  final int? propietarioId; // nullable para compatibilidad hacia atrás

  InquilinoModel({
    this.id,
    required this.nombre,
    this.apellido,
    this.telefono,
    this.celular,
    this.telefonoAlternativo,
    this.email,
    this.domicilio,
    this.localidad,
    this.provincia,
    this.propietarioId,
  });

  String get nombreCompleto {
    if (apellido != null && apellido!.isNotEmpty) {
      return '$nombre $apellido';
    }
    return nombre;
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'nombre': nombre,
        'apellido': apellido ?? '',
        'telefono': telefono ?? '',
        'celular': celular ?? '',
        'telefono_alternativo': telefonoAlternativo ?? '',
        'email': email ?? '',
        'domicilio': domicilio ?? '',
        'localidad_inq': localidad ?? '',
        'provincia': provincia ?? '',
        if (propietarioId != null) 'propietario_id': propietarioId,
      };

  factory InquilinoModel.fromMap(Map<String, dynamic> map) => InquilinoModel(
        id: map['id'] as int?,
        nombre: map['nombre'] as String,
        apellido: map['apellido'] as String?,
        telefono: map['telefono'] as String?,
        celular: map['celular'] as String?,
        telefonoAlternativo: map['telefono_alternativo'] as String?,
        email: map['email'] as String?,
        domicilio: map['domicilio'] as String?,
        localidad: map['localidad_inq'] as String?,
        provincia: map['provincia'] as String?,
        propietarioId: map['propietario_id'] as int?,
      );

  InquilinoModel copyWith({
    int? id,
    String? nombre,
    String? apellido,
    String? telefono,
    String? celular,
    String? telefonoAlternativo,
    String? email,
    String? domicilio,
    String? localidad,
    String? provincia,
    int? propietarioId,
  }) =>
      InquilinoModel(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        apellido: apellido ?? this.apellido,
        telefono: telefono ?? this.telefono,
        celular: celular ?? this.celular,
        telefonoAlternativo: telefonoAlternativo ?? this.telefonoAlternativo,
        email: email ?? this.email,
        domicilio: domicilio ?? this.domicilio,
        localidad: localidad ?? this.localidad,
        provincia: provincia ?? this.provincia,
        propietarioId: propietarioId ?? this.propietarioId,
      );

  @override
  String toString() => nombreCompleto;
}
