// NUEVO — Modelo para la tabla contratos

class ContratoModel {
  final int? id;
  final int? reciboId;
  final int? inquilinoId;
  final int propietarioId;
  final int diasGracia;
  final int punitoriosDesde;
  final String? fechaAlta;
  final String? notasRecibo;
  final String recordatorioInquilino;
  final String recordatorioPropietario;
  final bool alertarInquilino;
  final bool imprimirRecordatorioInquilino;
  final bool alertarPropietario;
  final bool imprimirRecordatorioPropietario;

  // Campos de JOIN (solo lectura, no se guardan en la tabla)
  final String? propietarioNombre;
  final String? inquilinoNombre;
  final String? direccion;
  final String? localidad;

  const ContratoModel({
    this.id,
    this.reciboId,
    this.inquilinoId,
    required this.propietarioId,
    this.diasGracia = 10,
    this.punitoriosDesde = 1,
    this.fechaAlta,
    this.notasRecibo,
    this.recordatorioInquilino =
        'Recuerde que el contrato de alquiler está próximo a vencer',
    this.recordatorioPropietario =
        'Recuerde que el contrato de alquiler de la calle [domicilio] está próximo a vencer',
    this.alertarInquilino = true,
    this.imprimirRecordatorioInquilino = true,
    this.alertarPropietario = true,
    this.imprimirRecordatorioPropietario = true,
    this.propietarioNombre,
    this.inquilinoNombre,
    this.direccion,
    this.localidad,
  });

  // ── toMap: solo campos de la tabla (sin campos de JOIN) ────────
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'recibo_id': reciboId,
      'inquilino_id': inquilinoId,
      'propietario_id': propietarioId,
      'dias_gracia': diasGracia,
      'punitorios_desde_dia': punitoriosDesde,
      'fecha_alta': fechaAlta,
      'notas_recibo': notasRecibo,
      'recordatorio_inquilino': recordatorioInquilino,
      'recordatorio_propietario': recordatorioPropietario,
      'alertar_inquilino': alertarInquilino ? 1 : 0,
      'imprimir_recordatorio_inquilino': imprimirRecordatorioInquilino ? 1 : 0,
      'alertar_propietario': alertarPropietario ? 1 : 0,
      'imprimir_recordatorio_propietario':
          imprimirRecordatorioPropietario ? 1 : 0,
    };
  }

  // ── fromMap: lee desde la BD (incluye campos de JOIN si existen) ─
  factory ContratoModel.fromMap(Map<String, dynamic> map) {
    return ContratoModel(
      id: map['id'] as int?,
      reciboId: map['recibo_id'] as int?,
      inquilinoId: map['inquilino_id'] as int?,
      propietarioId: map['propietario_id'] as int,
      diasGracia: map['dias_gracia'] as int? ?? 10,
      punitoriosDesde: map['punitorios_desde_dia'] as int? ?? 1,
      fechaAlta: map['fecha_alta'] as String?,
      notasRecibo: map['notas_recibo'] as String?,
      recordatorioInquilino: map['recordatorio_inquilino'] as String? ??
          'Recuerde que el contrato de alquiler está próximo a vencer',
      recordatorioPropietario: map['recordatorio_propietario'] as String? ??
          'Recuerde que el contrato de alquiler de la calle [domicilio] está próximo a vencer',
      alertarInquilino: (map['alertar_inquilino'] as int? ?? 1) == 1,
      imprimirRecordatorioInquilino:
          (map['imprimir_recordatorio_inquilino'] as int? ?? 1) == 1,
      alertarPropietario: (map['alertar_propietario'] as int? ?? 1) == 1,
      imprimirRecordatorioPropietario:
          (map['imprimir_recordatorio_propietario'] as int? ?? 1) == 1,
      propietarioNombre: map['propietario_nombre'] as String?,
      inquilinoNombre: map['inquilino_nombre'] as String?,
      direccion: map['direccion'] as String?,
      localidad: map['localidad'] as String?,
    );
  }

  // ── copyWith ───────────────────────────────────────────────────
  ContratoModel copyWith({
    int? id,
    int? reciboId,
    int? inquilinoId,
    int? propietarioId,
    int? diasGracia,
    int? punitoriosDesde,
    String? fechaAlta,
    String? notasRecibo,
    String? recordatorioInquilino,
    String? recordatorioPropietario,
    bool? alertarInquilino,
    bool? imprimirRecordatorioInquilino,
    bool? alertarPropietario,
    bool? imprimirRecordatorioPropietario,
    String? propietarioNombre,
    String? inquilinoNombre,
    String? direccion,
    String? localidad,
  }) {
    return ContratoModel(
      id: id ?? this.id,
      reciboId: reciboId ?? this.reciboId,
      inquilinoId: inquilinoId ?? this.inquilinoId,
      propietarioId: propietarioId ?? this.propietarioId,
      diasGracia: diasGracia ?? this.diasGracia,
      punitoriosDesde: punitoriosDesde ?? this.punitoriosDesde,
      fechaAlta: fechaAlta ?? this.fechaAlta,
      notasRecibo: notasRecibo ?? this.notasRecibo,
      recordatorioInquilino:
          recordatorioInquilino ?? this.recordatorioInquilino,
      recordatorioPropietario:
          recordatorioPropietario ?? this.recordatorioPropietario,
      alertarInquilino: alertarInquilino ?? this.alertarInquilino,
      imprimirRecordatorioInquilino:
          imprimirRecordatorioInquilino ?? this.imprimirRecordatorioInquilino,
      alertarPropietario: alertarPropietario ?? this.alertarPropietario,
      imprimirRecordatorioPropietario: imprimirRecordatorioPropietario ??
          this.imprimirRecordatorioPropietario,
      propietarioNombre: propietarioNombre ?? this.propietarioNombre,
      inquilinoNombre: inquilinoNombre ?? this.inquilinoNombre,
      direccion: direccion ?? this.direccion,
      localidad: localidad ?? this.localidad,
    );
  }

  // ── Getter: recordatorio con domicilio reemplazado ─────────────
  /// Devuelve el texto del recordatorio al propietario
  /// reemplazando [domicilio] con la dirección real si está disponible
  String get recordatorioPropietarioFinal {
    final dom = direccion ?? '[domicilio]';
    return recordatorioPropietario.replaceAll('[domicilio]', dom);
  }

  // ── Getter: indica si tiene alertas activas ────────────────────
  bool get tieneAlertasActivas => alertarInquilino || alertarPropietario;

  // ── Getter: indica si tiene notas al pie ──────────────────────
  bool get tieneNotas =>
      notasRecibo != null && notasRecibo!.trim().isNotEmpty;

  // ── Getter: días restantes desde fecha_alta ───────────────────
  /// Retorna null si no hay fecha_alta cargada
  int? get diasDesdeAlta {
    if (fechaAlta == null) return null;
    try {
      final alta = DateTime.parse(fechaAlta!);
      return DateTime.now().difference(alta).inDays;
    } catch (_) {
      return null;
    }
  }
}
