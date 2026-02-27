class DomicilioModel {
  final int? id;
  final String direccion;
  final String? localidad;
  final int propietarioId;
  final int? inquilinoId;

  DomicilioModel({
    this.id,
    required this.direccion,
    this.localidad,
    required this.propietarioId,
    this.inquilinoId,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'direccion': direccion,
      'localidad': localidad ?? '',
      'propietario_id': propietarioId,
      'inquilino_id': inquilinoId,
    };
  }

  factory DomicilioModel.fromMap(Map<String, dynamic> map) {
    return DomicilioModel(
      id: map['id'] as int?,
      direccion: map['direccion'] as String,
      localidad: map['localidad'] as String?,
      propietarioId: map['propietario_id'] as int,
      inquilinoId: map['inquilino_id'] as int?,
    );
  }

  DomicilioModel copyWith({
    int? id,
    String? direccion,
    String? localidad,
    int? propietarioId,
    int? inquilinoId,
  }) {
    return DomicilioModel(
      id: id ?? this.id,
      direccion: direccion ?? this.direccion,
      localidad: localidad ?? this.localidad,
      propietarioId: propietarioId ?? this.propietarioId,
      inquilinoId: inquilinoId ?? this.inquilinoId,
    );
  }

  String get direccionCompleta {
    if (localidad != null && localidad!.isNotEmpty) {
      return '$direccion, $localidad';
    }
    return direccion;
  }

  @override
  String toString() => direccionCompleta;
}
