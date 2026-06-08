import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recibo_model.dart';
import '../utils/numero_a_letras.dart';

/// Vista previa del recibo en pantalla — formato ORIGINAL + COPIA en una hoja.
class ReciboWidget extends StatelessWidget {
  final ReciboModel recibo;

  const ReciboWidget({super.key, required this.recibo});

  // ── Paleta ──────────────────────────────────────────────────────
  static const _navy    = Color(0xFF1A3A5C);
  static const _dark    = Color(0xFF212121);
  static const _gray    = Color(0xFF757575);

  static const _empresa        = 'COPPOLA PAVESE Inmobiliaria';
  static const _direccionEmp   = 'Blandengues 188 - San Miguel del Monte';
  static const _telefonos      = '02226 546317 / 02271 412950';
  static const _emailEmp       = 'coppolapavese@gmail.com';

  /// Formateador de moneda con signo $ sin decimales
  static final _fmtPesos = NumberFormat.currency(
      locale: 'es_AR', symbol: '\$', decimalDigits: 0, customPattern: '\u00A4#,##0');

  String _fmtM(double v) => recibo.esNeutro ? '____________' : _fmtPesos.format(v);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _seccionOriginal(),
          _lineaCorte(),
          _seccionCopia(),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // SECCIÓN ORIGINAL
  // ────────────────────────────────────────────────────────────────
  Widget _seccionOriginal() {
    final fmt = DateFormat('dd/MM/yyyy');

    String fechaStr = recibo.fechaEmision;
    try { fechaStr = fmt.format(DateTime.parse(recibo.fechaEmision)); } catch (_) {}

    final montoLetras = recibo.esNeutro
        ? '___________________________'
        : numeroALetras(recibo.montoTotal);
    final locador   = recibo.propietarioNombre ?? '___________';
    final locatario = recibo.inquilinoNombre   ?? '___________';
    final domicilio = recibo.direccionCompleta.isNotEmpty
        ? recibo.direccionCompleta.toUpperCase()
        : '___________';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado: logo + empresa + badge ──────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset('assets/images/cp_logo.png',
                  width: 150, height: 130, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(width: 150, height: 130)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_empresa,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold, color: _navy)),
                    const SizedBox(height: 2),
                    Text(_direccionEmp,
                        style: const TextStyle(fontSize: 10, color: _gray)),
                    Text(_telefonos,
                        style: const TextStyle(fontSize: 10, color: _gray)),
                    Text(_emailEmp,
                        style: const TextStyle(fontSize: 10, color: _gray)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _badge('ORIGINAL', bg: _navy, size: 10),
            ],
          ),
          const SizedBox(height: 10),

          // ── Recibo / Fecha / Usuario ──────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RECIBO N° ${recibo.numeroRecibo.toString().padLeft(4, '0')}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold, color: _dark)),
              Row(
                children: [
                  Text('Fecha: $fechaStr',
                      style: const TextStyle(fontSize: 11, color: _dark)),
                  if (recibo.usuario != null && recibo.usuario!.isNotEmpty) ...[
                    const Text('   |   ',
                        style: TextStyle(fontSize: 11, color: _gray)),
                    Text('Resp.: ${recibo.usuario}',
                        style: const TextStyle(fontSize: 11, color: _dark)),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── LOCADOR / LOCATARIO ───────────────────────────────
          _filaLocador(locador: locador, locatario: locatario),
          const SizedBox(height: 10),

          // ── Párrafo monto ─────────────────────────────────────
          _parrafoBorde(
            'POR MANDATO DEL LOCADOR RECIBI DEL LOCATARIO LA SUMA DE '
            '${montoLetras.toUpperCase()} '
            '(${_fmtM(recibo.montoTotal)}) '
            'POR EL ALQUILER DE UNA PROPIEDAD UBICADA EN $domicilio, SAN MIGUEL DEL MONTE.',
          ),
          const SizedBox(height: 10),

          // ── Tabla servicios ───────────────────────────────────
          _tablaServicios(small: false),
          const SizedBox(height: 10),

          // ── Resumen de pago ───────────────────────────────────
          _resumenPago(),

          // ── Notas ─────────────────────────────────────────────
          if (recibo.notas != null && recibo.notas!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(recibo.notas!,
                style: const TextStyle(fontSize: 10, color: _gray, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 10),

          // ── Pie ───────────────────────────────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: Text(_empresa,
                style: const TextStyle(
                    fontSize: 9,
                    color: _gray,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // LÍNEA DE CORTE
  // ────────────────────────────────────────────────────────────────
  Widget _lineaCorte() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.content_cut, size: 14, color: _gray),
          const SizedBox(width: 4),
          Expanded(
            child: LayoutBuilder(
              builder: (_, constraints) {
                final count = (constraints.maxWidth / 6).floor();
                return Row(
                  children: List.generate(count, (i) => Expanded(
                    child: Container(
                      height: 1,
                      color: i.isEven ? _gray : Colors.transparent,
                    ),
                  )),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // SECCIÓN COPIA — sin logo, sin empresa, sin teléfonos/dirección
  // ────────────────────────────────────────────────────────────────
  Widget _seccionCopia() {
    final fmt = DateFormat('dd/MM/yyyy');

    String fechaStr = recibo.fechaEmision;
    try { fechaStr = fmt.format(DateTime.parse(recibo.fechaEmision)); } catch (_) {}

    final montoLetras = recibo.esNeutro
        ? '___________________________'
        : numeroALetras(recibo.montoTotal);
    final locador   = recibo.propietarioNombre ?? '___________';
    final locatario = recibo.inquilinoNombre   ?? '___________';
    final domicilio = recibo.direccionCompleta.isNotEmpty
        ? recibo.direccionCompleta.toUpperCase()
        : '___________';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado copia — solo inquilino + domicilio + badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (recibo.inquilinoNombre != null &&
                        recibo.inquilinoNombre!.isNotEmpty)
                      Text('Señor(es): ${recibo.inquilinoNombre}',
                          style: const TextStyle(fontSize: 11, color: _dark)),
                    if (recibo.direccionCompleta.isNotEmpty)
                      Text('Domicilio: ${recibo.direccionCompleta}',
                          style: const TextStyle(fontSize: 11, color: _dark)),
                  ],
                ),
              ),
              _badge('ES COPIA', bg: _gray, size: 10),
            ],
          ),
          const SizedBox(height: 6),

          // ── Recibo / Fecha / Usuario inline ───────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RECIBO N° ${recibo.numeroRecibo.toString().padLeft(4, '0')}',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold, color: _dark)),
              Row(
                children: [
                  Text('Fecha: $fechaStr',
                      style: const TextStyle(fontSize: 10, color: _dark)),
                  if (recibo.usuario != null && recibo.usuario!.isNotEmpty) ...[
                    const Text('  |  ',
                        style: TextStyle(fontSize: 10, color: _gray)),
                    Text('Resp.: ${recibo.usuario}',
                        style: const TextStyle(fontSize: 10, color: _dark)),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── LOCADOR / LOCATARIO — línea abajo ────────────────
          _filaLocador(locador: locador, locatario: locatario, small: true, soloLinea: true),
          const SizedBox(height: 8),

          // ── Párrafo monto ─────────────────────────────────────
          _parrafoBorde(
            'POR MANDATO DEL LOCADOR RECIBI DEL LOCATARIO LA SUMA DE '
            '${montoLetras.toUpperCase()} '
            '(${_fmtM(recibo.montoTotal)}) '
            'POR EL ALQUILER DE UNA PROPIEDAD UBICADA EN $domicilio, SAN MIGUEL DEL MONTE.',
            small: true,
          ),
          const SizedBox(height: 8),

          Text('Según Detalle:',
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: _dark)),
          const SizedBox(height: 4),

          // ── Tabla servicios ───────────────────────────────────
          _tablaServicios(small: true),
          const SizedBox(height: 8),

          // ── Resumen de pago ───────────────────────────────────
          _resumenPago(small: true),

          // ── Notas ─────────────────────────────────────────────
          if (recibo.notas != null && recibo.notas!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(recibo.notas!,
                style: const TextStyle(
                    fontSize: 9, color: _gray, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // HELPERS COMPARTIDOS
  // ────────────────────────────────────────────────────────────────

  Widget _badge(String texto, {required Color bg, double size = 10}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(3)),
      child: Text(texto,
          style: TextStyle(
              color: Colors.white,
              fontSize: size,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3)),
    );
  }

  /// LOCADOR / LOCATARIO — con cuadro border o solo línea abajo
  Widget _filaLocador({
    required String locador,
    required String locatario,
    bool small = false,
    bool soloLinea = false,
  }) {
    final fs = small ? 10.0 : 11.0;

    Widget campo(String label, String valor) {
      if (soloLinea) {
        // Solo línea debajo del texto
        return Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: fs - 1,
                      fontWeight: FontWeight.bold,
                      color: _dark)),
              const SizedBox(height: 2),
              Text(valor,
                  style: TextStyle(fontSize: fs, color: _dark),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Container(height: 1, color: const Color(0xFFBDBDBD)),
            ],
          ),
        );
      } else {
        // Cuadro con borde
        return Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFBDBDBD)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: fs - 1,
                        fontWeight: FontWeight.bold,
                        color: _dark)),
                const SizedBox(height: 2),
                Text(valor,
                    style: TextStyle(fontSize: fs, color: _dark),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        );
      }
    }

    return Row(
      children: [
        campo('LOCADOR', locador),
        const SizedBox(width: 8),
        campo('LOCATARIO', locatario),
      ],
    );
  }

  Widget _parrafoBorde(String texto, {bool small = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: small ? 10 : 14, vertical: small ? 10 : 14),
      decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFBDBDBD)),
          borderRadius: BorderRadius.circular(4)),
      child: Text(texto,
          style: TextStyle(
              fontSize: small ? 9.5 : 11,
              color: _dark,
              height: 1.6)),
    );
  }

  /// Tabla de servicios — con columna Total (monto + punitorios)
  Widget _tablaServicios({bool small = false}) {
    final fs  = small ? 9.5 : 11.0;
    final fsH = small ? 9.0 : 10.0;

    final tieneVence = recibo.servicios.any(
        (s) => s.fechaVence != null && s.fechaVence!.isNotEmpty);
    final fmtVence = DateFormat('dd/MM');

    return Table(
      border: TableBorder(
        top:              const BorderSide(color: _dark, width: 1),
        bottom:           const BorderSide(color: _dark, width: 1),
        horizontalInside: const BorderSide(color: Color(0xFFCCCCCC), width: 0.5),
        left:             const BorderSide(color: _dark, width: 0.5),
        right:            const BorderSide(color: _dark, width: 0.5),
        verticalInside:   const BorderSide(color: Color(0xFFCCCCCC), width: 0.5),
      ),
      columnWidths: tieneVence
          ? {
              0: const FixedColumnWidth(60),
              1: const FlexColumnWidth(4),
              2: const FlexColumnWidth(2),
              3: const FlexColumnWidth(1.5),
              4: const FlexColumnWidth(2),
            }
          : {
              0: const FlexColumnWidth(4),
              1: const FlexColumnWidth(2),
              2: const FlexColumnWidth(1.5),
              3: const FlexColumnWidth(2),
            },
      children: [
        // Header
        TableRow(
          decoration: const BoxDecoration(color: Colors.white),
          children: [
            if (tieneVence) _th('VENCE', fs: fsH),
            _th('DESCRIPCIÓN', fs: fsH),
            _th('MONTO', fs: fsH, center: true),
            _th('PUNIT.', fs: fsH, center: true),
            _th('TOTAL', fs: fsH, center: true),
          ],
        ),
        // Filas de servicios
        ...recibo.servicios.asMap().entries.map((e) {
          final s = e.value;
          String venceStr = '—';
          if (s.fechaVence != null && s.fechaVence!.isNotEmpty) {
            try { venceStr = fmtVence.format(DateTime.parse(s.fechaVence!)); } catch (_) {}
          }
          final totalFila = s.monto + s.punitorios;
          return TableRow(
            decoration: const BoxDecoration(color: Colors.white),
            children: [
              if (tieneVence)
                _td(venceStr, fs: fs, center: true),
              _td(s.descripcion, fs: fs),
              _td(_fmtM(s.monto), fs: fs, center: true),
              _td(!recibo.esNeutro && s.punitorios > 0
                  ? _fmtM(s.punitorios)
                  : (recibo.esNeutro ? '____________' : '—'),
                  fs: fs, center: true),
              _td(recibo.esNeutro ? '____________' : _fmtM(totalFila),
                  fs: fs, center: true),
            ],
          );
        }),
      ],
    );
  }

  Widget _th(String t, {double fs = 9, bool center = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Text(t,
            style: TextStyle(
                fontSize: fs,
                fontWeight: FontWeight.bold,
                color: _dark),
            textAlign: center ? TextAlign.center : TextAlign.left),
      );

  Widget _td(String t,
          {double fs = 10,
          bool center = false,
          bool bold = false,
          Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(t,
            style: TextStyle(
                fontSize: fs,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: color ?? _dark),
            textAlign: center ? TextAlign.center : TextAlign.left),
      );

  /// Resumen: Monto a Abonar + espacio vacío + Total Abonado (si está pagado)
  Widget _resumenPago({bool small = false}) {
    final fs = small ? 10.0 : 12.0;
    final esPagado = recibo.estado == 'pagado' || recibo.montoAbonado > 0;

    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 280,
        child: Column(
          children: [
            // Monto a Abonar (siempre visible)
            _filaResumen('Monto a Abonar:', _fmtM(recibo.montoTotal),
                _dark, fs: fs, bold: true),
            // Espacio vacío
            const SizedBox(height: 16),
            // Total Abonado (solo si pagado/parcial)
            if (esPagado)
              _filaResumen('Total Abonado:', _fmtM(recibo.montoAbonado),
                  _dark, fs: fs),
          ],
        ),
      ),
    );
  }

  Widget _filaResumen(String label, String valor, Color color,
      {double fs = 12, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: fs,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: _dark)),
          Text(valor,
              style: TextStyle(
                  fontSize: fs,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }
}
