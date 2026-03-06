import 'servicio_item_model.dart';

class ReciboModel {
  final int? id;
  final int numeroRecibo;
  final int propietarioId;
  final int? inquilinoId;
  final int? domicilioId;
  final String fechaEmision;
  final String? fechaVencimiento;
  final double montoTotal;
  final double montoAbonado;
  final double saldo;
  final String estado; // 'pagado' | 'pendiente' | 'parcial'
  final String? usuario;
  final String? notas;
  final String createdAt;
  final int? contratoId;  // v3
  final int? numeroCuota; // v3

  // Campos JOIN (no se guardan en BD, vienen de consultas)
  final String? propietarioNombre;
  final String? propietarioTelefono;
  final String? propietarioEmail;
  final String? inquilinoNombre;
  final String? inquilinoTelefono;
  final String? direccion;
  final String? localidad;

  // Servicios asociados (se cargan aparte)
  final List<ServicioItemModel> servicios;

  ReciboModel({
    this.id,
    required this.numeroRecibo,
    required this.propietarioId,
    this.inquilinoId,
    this.domicilioId,
    required this.fechaEmision,
    this.fechaVencimiento,
    required this.montoTotal,
    required this.montoAbonado,
    required this.saldo,
    required this.estado,
    this.usuario,
    this.notas,
    required this.createdAt,
    this.contratoId,
    this.numeroCuota,
    this.propietarioNombre,
    this.propietarioTelefono,
    this.propietarioEmail,
    this.inquilinoNombre,
    this.inquilinoTelefono,
    this.direccion,
    this.localidad,
    this.servicios = const [],
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'numero_recibo': numeroRecibo,
        'propietario_id': propietarioId,
        'inquilino_id': inquilinoId,
        'domicilio_id': domicilioId,
        'fecha_emision': fechaEmision,
        'fecha_vencimiento': fechaVencimiento,
        'monto_total': montoTotal,
        'monto_abonado': montoAbonado,
        'saldo': saldo,
        'estado': estado,
        'usuario': usuario ?? '',
        'notas': notas ?? '',
        'created_at': createdAt,
        if (contratoId != null) 'contrato_id': contratoId,
        if (numeroCuota != null) 'numero_cuota': numeroCuota,
      };

  factory ReciboModel.fromMap(
    Map<String, dynamic> map, {
    List<ServicioItemModel> servicios = const [],
  }) =>
      ReciboModel(
        id: map['id'] as int?,
        numeroRecibo: map['numero_recibo'] as int,
        propietarioId: map['propietario_id'] as int,
        inquilinoId: map['inquilino_id'] as int?,
        domicilioId: map['domicilio_id'] as int?,
        fechaEmision: map['fecha_emision'] as String,
        fechaVencimiento: map['fecha_vencimiento'] as String?,
        montoTotal: (map['monto_total'] as num).toDouble(),
        montoAbonado: (map['monto_abonado'] as num).toDouble(),
        saldo: (map['saldo'] as num).toDouble(),
        estado: map['estado'] as String,
        usuario: map['usuario'] as String?,
        notas: map['notas'] as String?,
        createdAt: map['created_at'] as String,
        contratoId: map['contrato_id'] as int?,
        numeroCuota: map['numero_cuota'] as int?,
        propietarioNombre: map['propietario_nombre'] as String?,
        propietarioTelefono: map['propietario_telefono'] as String?,
        propietarioEmail: map['propietario_email'] as String?,
        inquilinoNombre: map['inquilino_nombre'] as String?,
        inquilinoTelefono: map['inquilino_telefono'] as String?,
        direccion: map['direccion'] as String?,
        localidad: map['localidad'] as String?,
        servicios: servicios,
      );

  ReciboModel copyWith({
    int? id,
    int? numeroRecibo,
    int? propietarioId,
    int? inquilinoId,
    int? domicilioId,
    String? fechaEmision,
    String? fechaVencimiento,
    double? montoTotal,
    double? montoAbonado,
    double? saldo,
    String? estado,
    String? usuario,
    String? notas,
    String? createdAt,
    int? contratoId,
    int? numeroCuota,
    String? propietarioNombre,
    String? propietarioTelefono,
    String? propietarioEmail,
    String? inquilinoNombre,
    String? inquilinoTelefono,
    String? direccion,
    String? localidad,
    List<ServicioItemModel>? servicios,
  }) =>
      ReciboModel(
        id: id ?? this.id,
        numeroRecibo: numeroRecibo ?? this.numeroRecibo,
        propietarioId: propietarioId ?? this.propietarioId,
        inquilinoId: inquilinoId ?? this.inquilinoId,
        domicilioId: domicilioId ?? this.domicilioId,
        fechaEmision: fechaEmision ?? this.fechaEmision,
        fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
        montoTotal: montoTotal ?? this.montoTotal,
        montoAbonado: montoAbonado ?? this.montoAbonado,
        saldo: saldo ?? this.saldo,
        estado: estado ?? this.estado,
        usuario: usuario ?? this.usuario,
        notas: notas ?? this.notas,
        createdAt: createdAt ?? this.createdAt,
        contratoId: contratoId ?? this.contratoId,
        numeroCuota: numeroCuota ?? this.numeroCuota,
        propietarioNombre: propietarioNombre ?? this.propietarioNombre,
        propietarioTelefono: propietarioTelefono ?? this.propietarioTelefono,
        propietarioEmail: propietarioEmail ?? this.propietarioEmail,
        inquilinoNombre: inquilinoNombre ?? this.inquilinoNombre,
        inquilinoTelefono: inquilinoTelefono ?? this.inquilinoTelefono,
        direccion: direccion ?? this.direccion,
        localidad: localidad ?? this.localidad,
        servicios: servicios ?? this.servicios,
      );

  String get estadoLabel {
    switch (estado) {
      case 'pagado':
        return 'Pagado';
      case 'parcial':
        return 'Parcial';
      case 'pendiente':
      default:
        return 'Pendiente';
    }
  }

  String get direccionCompleta {
    if (localidad != null && localidad!.isNotEmpty) {
      return '${direccion ?? ''}, $localidad';
    }
    return direccion ?? '';
  }
}
