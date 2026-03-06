import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recibo_model.dart';
import '../utils/numero_a_letras.dart';

/// Vista previa del recibo en pantalla — formato ORIGINAL + COPIA en una hoja.
/// Replica el diseño del PDF generado: sin marca de agua, logo arriba,
/// LOCADOR/LOCATARIO, tabla con Vence, línea de corte entre secciones.
class ReciboWidget extends StatelessWidget {
  final ReciboModel recibo;

  const ReciboWidget({super.key, required this.recibo});

  // ── Paleta ──────────────────────────────────────────────────────
  static const _navy    = Color(0xFF1A3A5C);
  static const _dark    = Color(0xFF212121);
  static const _gray    = Color(0xFF757575);
  static const _lightGray = Color(0xFFF5F5F5);
  static const _green   = Color(0xFF2E7D32);
  static const _blue    = Color(0xFF1565C0);
  static const _red     = Color(0xFFC62828);

  static const _empresa        = 'COPPOLA PAVESE Inmobiliaria';
  static const _direccionEmp   = 'Blandengues 188 - San Miguel del Monte';
  static const _telefonos      = '02226 546317 / 02271 412950';
  static const _emailEmp       = 'coppolapavese@gmail.com';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── SECCIÓN ORIGINAL ────────────────────────────────────
          _seccionOriginal(),

          // ── LÍNEA DE CORTE ──────────────────────────────────────
          _lineaCorte(),

          // ── SECCIÓN COPIA ───────────────────────────────────────
          _seccionCopia(),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // SECCIÓN ORIGINAL
  // ────────────────────────────────────────────────────────────────
  Widget _seccionOriginal() {
    final fmt    = DateFormat('dd/MM/yyyy');
    final fmtNum = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 2);

    String fechaStr = recibo.fechaEmision;
    try { fechaStr = fmt.format(DateTime.parse(recibo.fechaEmision)); } catch (_) {}

    final montoLetras = numeroALetras(recibo.montoTotal);
    final locador     = recibo.propietarioNombre ?? '___________';
    final locatario   = recibo.inquilinoNombre   ?? '___________';
    final domicilio   = recibo.direccionCompleta.isNotEmpty
        ? recibo.direccionCompleta.toUpperCase()
        : '___________';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado: logo + empresa + badges ──────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Image.asset('assets/images/logo.png',
                  width: 64, height: 64, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(width: 64, height: 64)),
              const SizedBox(width: 12),
              // Empresa
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
              // Badges
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _badge('X  DOCUMENTO NO VALIDO COMO FACTURA',
                      bg: _red, size: 8),
                  const SizedBox(height: 4),
                  _badge('ORIGINAL', bg: _navy, size: 10),
                ],
              ),
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
          const SizedBox(height: 8),

          // ── Doble línea ───────────────────────────────────────
          _dobleLinea(),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'RECIBO POR CUENTA Y ORDEN DE TERCEROS',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _dark,
                  letterSpacing: 0.5),
            ),
          ),
          const SizedBox(height: 6),
          _dobleLinea(),
          const SizedBox(height: 10),

          // ── LOCADOR / LOCATARIO ───────────────────────────────
          _filaLocador(locador: locador, locatario: locatario),
          const SizedBox(height: 10),

          // ── Párrafo monto ─────────────────────────────────────
          _parrafoBorde(
            'POR MANDATO DEL LOCADOR RECIBI DEL LOCATARIO LA SUMA DE '
            '${montoLetras.toUpperCase()} '
            '(${fmtNum.format(recibo.montoTotal)}) '
            'POR EL ALQUILER DE UNA PROPIEDAD UBICADA EN $domicilio.',
          ),
          const SizedBox(height: 10),

          // ── Tabla servicios ───────────────────────────────────
          _tablaServicios(small: false),
          const SizedBox(height: 10),

          // ── Resumen de pago ───────────────────────────────────
          _resumenPago(fmtNum),

          // ── Notas ─────────────────────────────────────────────
          if (recibo.notas != null && recibo.notas!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(recibo.notas!,
                style: const TextStyle(fontSize: 10, color: _gray, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 10),

          // ── Pie ───────────────────────────────────────────────
          Center(
            child: Text(_empresa,
                style: const TextStyle(fontSize: 9, color: _gray)),
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
  // SECCIÓN COPIA
  // ────────────────────────────────────────────────────────────────
  Widget _seccionCopia() {
    final fmt    = DateFormat('dd/MM/yyyy');
    final fmtNum = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 2);

    String fechaStr = recibo.fechaEmision;
    try { fechaStr = fmt.format(DateTime.parse(recibo.fechaEmision)); } catch (_) {}

    final montoLetras = numeroALetras(recibo.montoTotal);
    final locador     = recibo.propietarioNombre ?? '___________';
    final locatario   = recibo.inquilinoNombre   ?? '___________';
    final domicilio   = recibo.direccionCompleta.isNotEmpty
        ? recibo.direccionCompleta.toUpperCase()
        : '___________';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado copia ──────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset('assets/images/logo.png',
                  width: 48, height: 48, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(width: 48, height: 48)),
              const SizedBox(width: 10),
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

          // ── LOCADOR / LOCATARIO ───────────────────────────────
          _filaLocador(locador: locador, locatario: locatario, small: true),
          const SizedBox(height: 8),

          // ── Párrafo monto ─────────────────────────────────────
          _parrafoBorde(
            'POR MANDATO DEL LOCADOR RECIBI DEL LOCATARIO LA SUMA DE '
            '${montoLetras.toUpperCase()} '
            '(${fmtNum.format(recibo.montoTotal)}) '
            'POR EL ALQUILER DE UNA PROPIEDAD UBICADA EN $domicilio.',
            small: true,
          ),
          const SizedBox(height: 8),

          // ── Según detalle ─────────────────────────────────────
          Text('Según Detalle:',
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: _dark)),
          const SizedBox(height: 4),

          // ── Tabla servicios ───────────────────────────────────
          _tablaServicios(small: true),
          const SizedBox(height: 8),

          // ── Resumen de pago ───────────────────────────────────
          _resumenPago(fmtNum, small: true),

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

  Widget _dobleLinea() {
    return Column(
      children: [
        Container(height: 1.5, color: _dark),
        const SizedBox(height: 2),
        Container(height: 1, color: _dark),
      ],
    );
  }

  Widget _filaLocador({
    required String locador,
    required String locatario,
    bool small = false,
  }) {
    final fs = small ? 10.0 : 11.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: _lightGray, borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LOCADOR',
                    style: TextStyle(
                        fontSize: fs - 1,
                        fontWeight: FontWeight.bold,
                        color: _green)),
                Text(locador,
                    style: TextStyle(fontSize: fs, color: _dark),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(width: 1, height: 32, color: Colors.grey.shade300,
              margin: const EdgeInsets.symmetric(horizontal: 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LOCATARIO',
                    style: TextStyle(
                        fontSize: fs - 1,
                        fontWeight: FontWeight.bold,
                        color: _blue)),
                Text(locatario,
                    style: TextStyle(fontSize: fs, color: _dark),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _parrafoBorde(String texto, {bool small = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFBDBDBD)),
          borderRadius: BorderRadius.circular(4)),
      child: Text(texto,
          style: TextStyle(
              fontSize: small ? 9.5 : 11,
              color: _dark,
              height: 1.5)),
    );
  }

  Widget _tablaServicios({bool small = false}) {
    final fmt = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 2);
    final fs  = small ? 9.5 : 11.0;
    final fsH = small ? 9.0 : 10.0;

    // Detect if any service has fechaVence
    final tieneVence = recibo.servicios.any(
        (s) => s.fechaVence != null && s.fechaVence!.isNotEmpty);
    final fmtVence = DateFormat('dd/MM');

    return Table(
      border: TableBorder(
        top:    const BorderSide(color: _dark, width: 0.5),
        bottom: const BorderSide(color: Colors.grey),
        horizontalInside: const BorderSide(color: Color(0xFFEEEEEE), width: 0.5),
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
          decoration: const BoxDecoration(color: _navy),
          children: [
            if (tieneVence)
              _th('VENCE', fs: fsH),
            _th('DESCRIPCIÓN', fs: fsH),
            _th('MONTO', fs: fsH, center: true),
            _th('PUNIT.', fs: fsH, center: true),
            _th('TOTAL', fs: fsH, center: true),
          ],
        ),
        // Rows
        ...recibo.servicios.asMap().entries.map((e) {
          final i = e.key;
          final s = e.value;
          String venceStr = '—';
          if (s.fechaVence != null && s.fechaVence!.isNotEmpty) {
            try { venceStr = fmtVence.format(DateTime.parse(s.fechaVence!)); } catch (_) {}
          }
          return TableRow(
            decoration: BoxDecoration(
                color: i.isEven ? Colors.white : _lightGray),
            children: [
              if (tieneVence)
                _td(venceStr, fs: fs, center: true,
                    color: s.fechaVence != null ? _red : _gray),
              _td(s.descripcion, fs: fs),
              _td(fmt.format(s.monto), fs: fs, center: true),
              _td(s.punitorios > 0 ? fmt.format(s.punitorios) : '—',
                  fs: fs, center: true,
                  color: s.punitorios > 0 ? _red : _gray),
              _td(fmt.format(s.total), fs: fs, center: true, bold: true),
            ],
          );
        }),
      ],
    );
  }

  Widget _th(String t, {double fs = 9, bool center = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(t,
            style: TextStyle(
                fontSize: fs,
                fontWeight: FontWeight.bold,
                color: Colors.white),
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

  Widget _resumenPago(NumberFormat fmt, {bool small = false}) {
    final fs = small ? 10.0 : 12.0;
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 280,
        child: Column(
          children: [
            _filaResumen('Monto a Abonar:', fmt.format(recibo.montoTotal),
                _blue, fs: fs),
            _filaResumen('TOTAL ABONADO:', fmt.format(recibo.montoAbonado),
                _green, fs: fs),
            _filaResumen('Saldo:',
                fmt.format(recibo.saldo),
                recibo.saldo > 0 ? _red : _green,
                fs: fs, bold: true),
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
