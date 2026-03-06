// Modelo para la tabla conceptos_regulares (v4)

/// Efecto sobre inquilino / propietario
enum EfectoConcepto { sinEfecto, sumar, descontar }

/// Tipo de concepto
enum TipoConcepto { regular, unico }

/// Tipo de período de aplicación
enum PeriodoTipo { todos, pares, impares, especifico }

class ConceptoRegularModel {
  final int? id;
  final int contratoId;
  final String? descripcion;
  final double monto;
  final double porcentual;
  final bool tieneComprobante;       // "Solo Entregar Comprobante"
  final TipoConcepto tipo;
  final String? fechaVence;          // Solo para tipo 'unico'

  // Efectos
  final EfectoConcepto efectoInquilino;
  final bool aplicaPunitoriosInquilino;
  final EfectoConcepto efectoPropietario;
  final bool aplicaAdministracion;
  final bool entregarComprobanteProp; // "Entregar Comprobante" sección propietario
  final bool aplicaTodos;
  final String? propietarioEspecifico;

  // Campos v4
  final bool claro;
  final bool recordarPago;
  final String? fechaInicio;
  final String? fechaFin;
  final PeriodoTipo periodoTipo;     // 'todos' | 'pares' | 'impares' | 'especifico'
  final String? meses;               // Ej: "1,3,6,12" — meses específicos

  const ConceptoRegularModel({
    this.id,
    required this.contratoId,
    this.descripcion,
    this.monto = 0.0,
    this.porcentual = 0.0,
    this.tieneComprobante = false,
    this.tipo = TipoConcepto.regular,
    this.fechaVence,
    this.efectoInquilino = EfectoConcepto.sinEfecto,
    this.aplicaPunitoriosInquilino = false,
    this.efectoPropietario = EfectoConcepto.sinEfecto,
    this.aplicaAdministracion = false,
    this.entregarComprobanteProp = false,
    this.aplicaTodos = true,
    this.propietarioEspecifico,
    this.claro = true,
    this.recordarPago = false,
    this.fechaInicio,
    this.fechaFin,
    this.periodoTipo = PeriodoTipo.todos,
    this.meses,
  });

  // ── toMap ──────────────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'contrato_id': contratoId,
      'descripcion': descripcion,
      'monto': monto,
      'porcentual': porcentual,
      'tiene_comprobante': tieneComprobante ? 1 : 0,
      'tipo': _tipoToString(tipo),
      'fecha_vence': fechaVence,
      'efecto_inquilino': _efectoToString(efectoInquilino),
      'aplica_punitorios_inquilino': aplicaPunitoriosInquilino ? 1 : 0,
      'efecto_propietario': _efectoToString(efectoPropietario),
      'aplica_administracion': aplicaAdministracion ? 1 : 0,
      'entregar_comprobante_prop': entregarComprobanteProp ? 1 : 0,
      'aplica_todos': aplicaTodos ? 1 : 0,
      'propietario_especifico': propietarioEspecifico,
      'claro': claro ? 1 : 0,
      'recordar_pago': recordarPago ? 1 : 0,
      'fecha_inicio': fechaInicio,
      'fecha_fin': fechaFin,
      'periodo_tipo': _periodoToString(periodoTipo),
      'meses': meses,
    };
  }

  // ── fromMap ────────────────────────────────────────────────────
  factory ConceptoRegularModel.fromMap(Map<String, dynamic> map) {
    return ConceptoRegularModel(
      id: map['id'] as int?,
      contratoId: map['contrato_id'] as int,
      descripcion: map['descripcion'] as String?,
      monto: (map['monto'] as num? ?? 0).toDouble(),
      porcentual: (map['porcentual'] as num? ?? 0).toDouble(),
      tieneComprobante: (map['tiene_comprobante'] as int? ?? 0) == 1,
      tipo: _tipoFromString(map['tipo'] as String? ?? 'regular'),
      fechaVence: map['fecha_vence'] as String?,
      efectoInquilino:
          _efectoFromString(map['efecto_inquilino'] as String? ?? 'sin_efecto'),
      aplicaPunitoriosInquilino:
          (map['aplica_punitorios_inquilino'] as int? ?? 0) == 1,
      efectoPropietario:
          _efectoFromString(map['efecto_propietario'] as String? ?? 'sin_efecto'),
      aplicaAdministracion: (map['aplica_administracion'] as int? ?? 0) == 1,
      entregarComprobanteProp:
          (map['entregar_comprobante_prop'] as int? ?? 0) == 1,
      aplicaTodos: (map['aplica_todos'] as int? ?? 1) == 1,
      propietarioEspecifico: map['propietario_especifico'] as String?,
      claro: (map['claro'] as int? ?? 1) == 1,
      recordarPago: (map['recordar_pago'] as int? ?? 0) == 1,
      fechaInicio: map['fecha_inicio'] as String?,
      fechaFin: map['fecha_fin'] as String?,
      periodoTipo: _periodoFromString(map['periodo_tipo'] as String? ?? 'todos'),
      meses: map['meses'] as String?,
    );
  }

  // ── copyWith ───────────────────────────────────────────────────
  ConceptoRegularModel copyWith({
    int? id,
    int? contratoId,
    String? descripcion,
    double? monto,
    double? porcentual,
    bool? tieneComprobante,
    TipoConcepto? tipo,
    String? fechaVence,
    EfectoConcepto? efectoInquilino,
    bool? aplicaPunitoriosInquilino,
    EfectoConcepto? efectoPropietario,
    bool? aplicaAdministracion,
    bool? entregarComprobanteProp,
    bool? aplicaTodos,
    String? propietarioEspecifico,
    bool? claro,
    bool? recordarPago,
    String? fechaInicio,
    String? fechaFin,
    PeriodoTipo? periodoTipo,
    String? meses,
  }) {
    return ConceptoRegularModel(
      id: id ?? this.id,
      contratoId: contratoId ?? this.contratoId,
      descripcion: descripcion ?? this.descripcion,
      monto: monto ?? this.monto,
      porcentual: porcentual ?? this.porcentual,
      tieneComprobante: tieneComprobante ?? this.tieneComprobante,
      tipo: tipo ?? this.tipo,
      fechaVence: fechaVence ?? this.fechaVence,
      efectoInquilino: efectoInquilino ?? this.efectoInquilino,
      aplicaPunitoriosInquilino:
          aplicaPunitoriosInquilino ?? this.aplicaPunitoriosInquilino,
      efectoPropietario: efectoPropietario ?? this.efectoPropietario,
      aplicaAdministracion: aplicaAdministracion ?? this.aplicaAdministracion,
      entregarComprobanteProp:
          entregarComprobanteProp ?? this.entregarComprobanteProp,
      aplicaTodos: aplicaTodos ?? this.aplicaTodos,
      propietarioEspecifico:
          propietarioEspecifico ?? this.propietarioEspecifico,
      claro: claro ?? this.claro,
      recordarPago: recordarPago ?? this.recordarPago,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      periodoTipo: periodoTipo ?? this.periodoTipo,
      meses: meses ?? this.meses,
    );
  }

  // ── Getters ────────────────────────────────────────────────────
  double get montoFinal {
    if (porcentual == 0) return monto;
    return monto + (monto * porcentual / 100);
  }

  String get tipoLabel => tipo == TipoConcepto.unico ? 'Único' : 'Regular';

  String get efectoInquilinoLabel => _efectoLabel(efectoInquilino);
  String get efectoPropietarioLabel => _efectoLabel(efectoPropietario);

  bool get estaVencido {
    if (tipo != TipoConcepto.unico || fechaVence == null) return false;
    try {
      return DateTime.parse(fechaVence!).isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  /// Lista de meses seleccionados (1–12)
  List<int> get mesesLista {
    if (meses == null || meses!.isEmpty) return [];
    return meses!
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();
  }

  // ── Helpers enum ↔ String ──────────────────────────────────────
  static String _efectoToString(EfectoConcepto e) {
    switch (e) {
      case EfectoConcepto.sumar:
        return 'sumar';
      case EfectoConcepto.descontar:
        return 'descontar';
      case EfectoConcepto.sinEfecto:
        return 'sin_efecto';
    }
  }

  static EfectoConcepto _efectoFromString(String s) {
    switch (s) {
      case 'sumar':
        return EfectoConcepto.sumar;
      case 'descontar':
        return EfectoConcepto.descontar;
      default:
        return EfectoConcepto.sinEfecto;
    }
  }

  static String _tipoToString(TipoConcepto t) =>
      t == TipoConcepto.unico ? 'unico' : 'regular';

  static TipoConcepto _tipoFromString(String s) =>
      s == 'unico' ? TipoConcepto.unico : TipoConcepto.regular;

  static String _periodoToString(PeriodoTipo p) {
    switch (p) {
      case PeriodoTipo.pares:
        return 'pares';
      case PeriodoTipo.impares:
        return 'impares';
      case PeriodoTipo.especifico:
        return 'especifico';
      case PeriodoTipo.todos:
        return 'todos';
    }
  }

  static PeriodoTipo _periodoFromString(String s) {
    switch (s) {
      case 'pares':
        return PeriodoTipo.pares;
      case 'impares':
        return PeriodoTipo.impares;
      case 'especifico':
        return PeriodoTipo.especifico;
      default:
        return PeriodoTipo.todos;
    }
  }

  static String _efectoLabel(EfectoConcepto e) {
    switch (e) {
      case EfectoConcepto.sumar:
        return 'Sumar';
      case EfectoConcepto.descontar:
        return 'Descontar';
      case EfectoConcepto.sinEfecto:
        return 'Sin efecto';
    }
  }
}
