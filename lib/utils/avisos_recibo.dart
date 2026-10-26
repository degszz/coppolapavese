// Textos del aviso al pie del recibo. Los usan el formulario del recibo
// (_generarNotaPeriodo) y la lista de contratos (vista previa del próximo
// aviso), así ambos dicen siempre lo mismo. Reglas: docs/reglas-de-negocio.md
const String avisoProximoAVencer =
    'recuerde que el contrato de alquiler está próximo a vencer';
const String avisoAumentoPeriodo =
    'recuerde que habrá aumento de periodo en el próximo recibo';

/// Aviso del pie para la cuota [cuota] de un contrato SIN prórroga activa,
/// según sus períodos fijos (rangos globales) y [cuotasTotal].
/// Devuelve null si esa cuota no lleva aviso.
String? avisoPieCuotaFija({
  required int cuota,
  required List<Map<String, dynamic>> periodosFijos,
  required int cuotasTotal,
}) {
  if (cuota <= 0) return null;
  // Período que contiene la cuota (ante solapamiento, el rango más chico)
  int? hasta;
  int? rango;
  for (final p in periodosFijos) {
    final d = p['cuota_desde'] as int? ?? 0;
    final h = p['cuota_hasta'] as int? ?? 0;
    if (cuota >= d && cuota <= h && (rango == null || h - d < rango)) {
      hasta = h;
      rango = h - d;
    }
  }
  final finContrato = cuotasTotal > 0 && cuota == cuotasTotal;
  // "Próximo a vencer" solo en la última cuota del contrato; "aumento" en la
  // última de cada período.
  if (hasta != null && cuota == hasta) {
    return finContrato ? avisoProximoAVencer : avisoAumentoPeriodo;
  }
  if (finContrato) return avisoProximoAVencer;
  return null;
}
