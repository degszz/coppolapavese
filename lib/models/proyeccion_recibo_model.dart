/// Representa un recibo en el calendario — puede ser una cuota ya emitida
/// o una proyectada (pendiente de emisión), según el campo [emitido].
class ProyeccionReciboModel {
  final int contratoId;
  final int numeroCuota;
  final int cuotasTotal;
  final DateTime fechaPrevista;
  final String inquilinoNombre;
  final String? inquilinoCelular;
  final String? inquilinoTelefono;
  final String propiedadDireccion;
  final String propietarioNombre;
  final double monto;

  /// `true` si el recibo ya fue emitido (existe en la tabla recibos).
  final bool emitido;

  /// ID del recibo emitido (solo si [emitido] es true).
  final int? reciboId;

  /// Número de recibo (solo si [emitido] es true).
  final int? numeroRecibo;

  /// Estado del recibo emitido: 'pendiente', 'pagado', 'parcial', etc.
  final String? estadoRecibo;

  /// `true` si la fecha prevista ya pasó y el recibo no se emitió.
  bool get estaVencido {
    if (emitido) return false; // ya emitido → no vencido
    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    final f = DateTime(fechaPrevista.year, fechaPrevista.month, fechaPrevista.day);
    return f.isBefore(hoySinHora);
  }

  const ProyeccionReciboModel({
    required this.contratoId,
    required this.numeroCuota,
    required this.cuotasTotal,
    required this.fechaPrevista,
    required this.inquilinoNombre,
    this.inquilinoCelular,
    this.inquilinoTelefono,
    required this.propiedadDireccion,
    required this.propietarioNombre,
    required this.monto,
    this.emitido = false,
    this.reciboId,
    this.numeroRecibo,
    this.estadoRecibo,
  });
}
