/// Convierte un número double a su representación en letras
/// en español argentino, hasta miles de millones.
///
/// Ejemplos:
///   350000.00  → "TRESCIENTOS CINCUENTA MIL"
///   1250500.00 → "UN MILLON DOSCIENTOS CINCUENTA MIL QUINIENTOS"
///   100.50     → "CIEN PESOS CON CINCUENTA CENTAVOS"
String numeroALetras(double numero, {bool conPesos = true}) {
  if (numero < 0) return 'MENOS ${numeroALetras(-numero, conPesos: conPesos)}';
  if (numero == 0) return conPesos ? 'CERO PESOS' : 'CERO';

  final parteEntera = numero.truncate();
  final parteDecimal = ((numero - parteEntera) * 100).round();

  String resultado = _convertirEntero(parteEntera);

  if (conPesos) {
    resultado += parteEntera == 1 ? ' PESO' : ' PESOS';
    if (parteDecimal > 0) {
      resultado +=
          ' CON ${_convertirEntero(parteDecimal)} ${parteDecimal == 1 ? 'CENTAVO' : 'CENTAVOS'}';
    }
  }

  return resultado.trim();
}

/// Versión sin unidad monetaria — solo devuelve las letras del número entero.
String soloLetras(double numero) => _convertirEntero(numero.truncate());

// ─────────────────────────────────────────────────────────────────
// Implementación interna
// ─────────────────────────────────────────────────────────────────

const _unidades = [
  '',
  'UN',
  'DOS',
  'TRES',
  'CUATRO',
  'CINCO',
  'SEIS',
  'SIETE',
  'OCHO',
  'NUEVE',
  'DIEZ',
  'ONCE',
  'DOCE',
  'TRECE',
  'CATORCE',
  'QUINCE',
  'DIECISEIS',
  'DIECISIETE',
  'DIECIOCHO',
  'DIECINUEVE',
  'VEINTE',
];

const _decenas = [
  '',
  'DIEZ',
  'VEINTE',
  'TREINTA',
  'CUARENTA',
  'CINCUENTA',
  'SESENTA',
  'SETENTA',
  'OCHENTA',
  'NOVENTA',
];

const _centenas = [
  '',
  'CIENTO',
  'DOSCIENTOS',
  'TRESCIENTOS',
  'CUATROCIENTOS',
  'QUINIENTOS',
  'SEISCIENTOS',
  'SETECIENTOS',
  'OCHOCIENTOS',
  'NOVECIENTOS',
];

String _convertirEntero(int n) {
  if (n == 0) return 'CERO';
  if (n < 0) return 'MENOS ${_convertirEntero(-n)}';

  if (n >= 1000000000) {
    final miles = n ~/ 1000000000;
    final resto = n % 1000000000;
    final prefijo =
        miles == 1 ? 'MIL MILLONES' : '${_convertirEntero(miles)} MIL MILLONES';
    return resto == 0 ? prefijo : '$prefijo ${_convertirEntero(resto)}';
  }

  if (n >= 1000000) {
    final millones = n ~/ 1000000;
    final resto = n % 1000000;
    final prefijo =
        millones == 1 ? 'UN MILLON' : '${_convertirEntero(millones)} MILLONES';
    return resto == 0 ? prefijo : '$prefijo ${_convertirEntero(resto)}';
  }

  if (n >= 1000) {
    final miles = n ~/ 1000;
    final resto = n % 1000;
    final prefijo =
        miles == 1 ? 'MIL' : '${_convertirEntero(miles)} MIL';
    return resto == 0 ? prefijo : '$prefijo ${_convertirEntero(resto)}';
  }

  if (n == 100) return 'CIEN';

  if (n >= 100) {
    final centena = n ~/ 100;
    final resto = n % 100;
    final prefijo = _centenas[centena];
    return resto == 0 ? prefijo : '$prefijo ${_convertirMenorCien(resto)}';
  }

  return _convertirMenorCien(n);
}

String _convertirMenorCien(int n) {
  if (n <= 20) return _unidades[n];

  if (n < 30) {
    // 21-29: VEINTIUNO, VEINTIDOS...
    if (n == 21) return 'VEINTIUN';
    return 'VEINTI${_unidades[n - 20]}';
  }

  final decena = n ~/ 10;
  final unidad = n % 10;
  if (unidad == 0) return _decenas[decena];
  return '${_decenas[decena]} Y ${_unidades[unidad]}';
}
