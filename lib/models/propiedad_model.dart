class PropiedadModel {
  final int? id;
  final String? carpeta;
  final String tipo;
  final String estado;
  final String direccion;
  final String? entreCalles;
  final String? provincia;
  final String? localidad;
  final String? barrio;
  final String? codigoPostal;
  final int? propietarioId;

  // JOIN (solo lectura)
  final String? propietarioNombre;

  PropiedadModel({
    this.id,
    this.carpeta,
    this.tipo = 'Vivienda',
    this.estado = 'Disponible',
    required this.direccion,
    this.entreCalles,
    this.provincia,
    this.localidad,
    this.barrio,
    this.codigoPostal,
    this.propietarioId,
    this.propietarioNombre,
  });

  String get direccionCompleta {
    if (localidad != null && localidad!.isNotEmpty) {
      return '$direccion, $localidad';
    }
    return direccion;
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'carpeta': carpeta ?? '',
        'tipo': tipo,
        'estado': estado,
        'direccion': direccion,
        'entre_calles': entreCalles ?? '',
        'provincia': provincia ?? '',
        'localidad': localidad ?? '',
        'barrio': barrio ?? '',
        'codigo_postal': codigoPostal ?? '',
        'propietario_id': propietarioId,
      };

  factory PropiedadModel.fromMap(Map<String, dynamic> map) => PropiedadModel(
        id: map['id'] as int?,
        carpeta: map['carpeta'] as String?,
        tipo: (map['tipo'] as String?) ?? 'Vivienda',
        estado: (map['estado'] as String?) ?? 'Disponible',
        direccion: map['direccion'] as String,
        entreCalles: map['entre_calles'] as String?,
        provincia: map['provincia'] as String?,
        localidad: map['localidad'] as String?,
        barrio: map['barrio'] as String?,
        codigoPostal: map['codigo_postal'] as String?,
        propietarioId: map['propietario_id'] as int?,
        propietarioNombre: map['propietario_nombre'] as String?,
      );

  PropiedadModel copyWith({
    int? id,
    String? carpeta,
    String? tipo,
    String? estado,
    String? direccion,
    String? entreCalles,
    String? provincia,
    String? localidad,
    String? barrio,
    String? codigoPostal,
    int? propietarioId,
  }) =>
      PropiedadModel(
        id: id ?? this.id,
        carpeta: carpeta ?? this.carpeta,
        tipo: tipo ?? this.tipo,
        estado: estado ?? this.estado,
        direccion: direccion ?? this.direccion,
        entreCalles: entreCalles ?? this.entreCalles,
        provincia: provincia ?? this.provincia,
        localidad: localidad ?? this.localidad,
        barrio: barrio ?? this.barrio,
        codigoPostal: codigoPostal ?? this.codigoPostal,
        propietarioId: propietarioId ?? this.propietarioId,
      );

  @override
  String toString() => direccionCompleta;
}
