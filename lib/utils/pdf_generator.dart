import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/recibo_model.dart';
import 'numero_a_letras.dart';

class PdfGenerator {
  // Paleta
  static const _darkColor     = PdfColor.fromInt(0xFF000000);
  static const _grayColor     = PdfColor.fromInt(0xFF555555);
  static const _lightBorder   = PdfColor.fromInt(0xFFBDBDBD);

  // Datos de la empresa
  static const _empresa        = 'COPPOLA PAVESE Inmobiliaria';
  static const _direccionEmpresa = 'Blandengues 188 - San Miguel del Monte - Buenos Aires';
  static const _telefonos      = '02226546317 / 02271412950';
  static const _emailEmpresa   = 'coppolapavese@gmail.com';

  /// Formateador sin decimales, con signo $
  static final _fmtPesos = NumberFormat.currency(
      locale: 'es_AR', symbol: '\$', decimalDigits: 0, customPattern: '\u00A4#,##0');

  static String _fmtM(ReciboModel recibo, double v) =>
      recibo.esNeutro ? '____________' : _fmtPesos.format(v);

  static Future<List<int>> generarRecibo(
    ReciboModel recibo, {
    bool sinPunitorios = false,
    bool tieneConceptosConComprobante = false,
  }) async {
    final pdf = pw.Document();

    final fmt      = DateFormat('dd/MM/yyyy');

    final montoLetras = recibo.esNeutro ? '___________________________' : numeroALetras(recibo.montoTotal);

    // Cargar logo
    pw.MemoryImage? logoImg;
    try {
      final logoData = await rootBundle.load('assets/images/cp_logo.png');
      logoImg = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    final esSinPunitorios = sinPunitorios ||
        (recibo.servicios.isNotEmpty && recibo.servicios.every((s) => s.punitorios == 0));

    final tieneNotas = recibo.notas != null && recibo.notas!.trim().isNotEmpty;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(20, 16, 20, 16),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ═══════════════════ ORIGINAL ═══════════════════
              pw.Expanded(
                flex: 50,
                child: _seccionOriginal(
                  recibo, fmt, montoLetras,
                  logoImg: logoImg,
                  esSinPunitorios: esSinPunitorios,
                  tieneNotas: tieneNotas,
                ),
              ),

              // ───────── LÍNEA DE CORTE ─────────
              _lineaCorte(),

              // ═══════════════════ COPIA ═══════════════════
              pw.Expanded(
                flex: 50,
                child: _seccionCopia(
                  recibo, fmt, montoLetras,
                  esSinPunitorios: esSinPunitorios,
                  tieneNotas: tieneNotas,
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ══════════════════════════════════════════════════════════════
  // SECCIÓN ORIGINAL — con logo, empresa, teléfonos, cuadros
  // ══════════════════════════════════════════════════════════════
  static pw.Widget _seccionOriginal(
    ReciboModel recibo,
    DateFormat fmt,
    String montoLetras, {
    pw.MemoryImage? logoImg,
    bool esSinPunitorios = false,
    bool tieneNotas = false,
  }) {
    final locatario = recibo.inquilinoNombre ?? '—';
    final locador   = recibo.propietarioNombre ?? '—';
    final dir       = recibo.direccionCompleta.isNotEmpty
        ? recibo.direccionCompleta.toUpperCase()
        : '___________';
    String fechaStr = recibo.fechaEmision;
    try { fechaStr = fmt.format(DateTime.parse(recibo.fechaEmision)); } catch (_) {}

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // ── CABECERA CON LOGO ─────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoImg != null)
                pw.Image(logoImg, width: 115, height: 100),
              if (logoImg != null) pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_empresa,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 13,
                            color: _darkColor)),
                    pw.SizedBox(height: 2),
                    pw.Text(_direccionEmpresa,
                        style: pw.TextStyle(fontSize: 8, color: _grayColor)),
                    pw.Text('$_telefonos   $_emailEmpresa',
                        style: pw.TextStyle(fontSize: 8, color: _grayColor)),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _darkColor, width: 1.2),
                    ),
                    child: pw.Text('ORIGINAL',
                      style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: _darkColor),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  _miniInfoFila('Recibo:', '${recibo.numeroRecibo}'),
                  _miniInfoFila('Fecha:', fechaStr),
                  if (recibo.usuario != null && recibo.usuario!.isNotEmpty)
                    _miniInfoFila('Usuario:', recibo.usuario!),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 4),

        // ── LOCADOR / LOCATARIO — con cuadro ──────────────
        _filaLocador(locador, locatario, soloLinea: false),
        pw.SizedBox(height: 4),

        // ── PÁRRAFO MONTO ─────────────────────────────────
        _parrafoMonto(montoLetras, recibo, dir),
        pw.SizedBox(height: 4),

        // ── TABLA SERVICIOS ───────────────────────────────
        _tablaServicios(recibo, esSinPunitorios: esSinPunitorios),
        pw.SizedBox(height: 4),

        // ── RESUMEN DE PAGO ──────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [_resumenPago(recibo)],
        ),

        pw.Expanded(child: pw.SizedBox()),

        if (tieneNotas) ...[
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _lightBorder, width: 0.8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Notas:',
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _darkColor)),
                pw.SizedBox(height: 3),
                pw.Text(recibo.notas!,
                    style: pw.TextStyle(fontSize: 9, color: _darkColor)),
              ],
            ),
          ),
        ],

        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(_empresa,
              style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: _grayColor),
            ),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // SECCIÓN COPIA — sin logo, sin empresa, sin teléfonos, líneas
  // ══════════════════════════════════════════════════════════════
  static pw.Widget _seccionCopia(
    ReciboModel recibo,
    DateFormat fmt,
    String montoLetras, {
    bool esSinPunitorios = false,
    bool tieneNotas = false,
  }) {
    final locatario = recibo.inquilinoNombre ?? '—';
    final locador   = recibo.propietarioNombre ?? '—';
    final dir       = recibo.direccionCompleta.isNotEmpty
        ? recibo.direccionCompleta.toUpperCase()
        : '___________';
    String fechaStr = recibo.fechaEmision;
    try { fechaStr = fmt.format(DateTime.parse(recibo.fechaEmision)); } catch (_) {}

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // ── CABECERA COPIA — sin logo, sin empresa ────────
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (recibo.inquilinoNombre != null && recibo.inquilinoNombre!.isNotEmpty)
                      pw.Text('Señor(es): ${recibo.inquilinoNombre}',
                          style: pw.TextStyle(fontSize: 10, color: _darkColor)),
                    if (recibo.direccionCompleta.isNotEmpty)
                      pw.Text('Domicilio: ${recibo.direccionCompleta}',
                          style: pw.TextStyle(fontSize: 10, color: _darkColor)),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _darkColor, width: 1.2),
                    ),
                    child: pw.Text('ES COPIA',
                      style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: _darkColor),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  _miniInfoFila('Recibo:', '${recibo.numeroRecibo}'),
                  _miniInfoFila('Fecha:', fechaStr),
                  if (recibo.usuario != null && recibo.usuario!.isNotEmpty)
                    _miniInfoFila('Usuario:', recibo.usuario!),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 4),

        // ── LOCADOR / LOCATARIO — solo línea abajo ────────
        _filaLocador(locador, locatario, soloLinea: true),
        pw.SizedBox(height: 4),

        // ── PÁRRAFO MONTO ─────────────────────────────────
        _parrafoMonto(montoLetras, recibo, dir),
        pw.SizedBox(height: 4),

        // ── TABLA SERVICIOS ───────────────────────────────
        _tablaServicios(recibo, esSinPunitorios: esSinPunitorios),
        pw.SizedBox(height: 4),

        // ── RESUMEN DE PAGO ──────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [_resumenPago(recibo)],
        ),

        pw.Expanded(child: pw.SizedBox()),

        if (tieneNotas) ...[
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _lightBorder, width: 0.8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Notas:',
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _darkColor)),
                pw.SizedBox(height: 3),
                pw.Text(recibo.notas!,
                    style: pw.TextStyle(fontSize: 9, color: _darkColor)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // TABLA DE SERVICIOS — con columna Total
  // ══════════════════════════════════════════════════════════════
  static pw.Widget _tablaServicios(
    ReciboModel recibo, {
    bool esSinPunitorios = false,
  }) {
    const fs   = 9.0;
    const fsTh = 9.0;
    const pad  = 4.0;

    pw.Widget th(String t, {bool center = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: pad),
          child: pw.Text(t,
              style: pw.TextStyle(
                  color: _darkColor,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: fsTh),
              textAlign: center ? pw.TextAlign.center : pw.TextAlign.left),
        );

    pw.Widget td(String t, {bool center = false, bool bold = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: pad),
          child: pw.Text(t,
              style: pw.TextStyle(
                  fontSize: fs,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: _darkColor),
              textAlign: center ? pw.TextAlign.center : pw.TextAlign.left),
        );

    final hasFechaVence = recibo.servicios.any(
        (s) => s.fechaVence != null && s.fechaVence!.isNotEmpty);
    final fmtDate = DateFormat('dd/MM/yyyy');

    final int colOffset = hasFechaVence ? 1 : 0;

    return pw.Table(
      border: pw.TableBorder(
        top:              const pw.BorderSide(width: 1, color: _darkColor),
        bottom:           const pw.BorderSide(width: 1, color: _darkColor),
        left:             const pw.BorderSide(width: 0.5, color: _darkColor),
        right:            const pw.BorderSide(width: 0.5, color: _darkColor),
        horizontalInside: pw.BorderSide(width: 0.4, color: _lightBorder),
        verticalInside:   pw.BorderSide(width: 0.4, color: _lightBorder),
      ),
      columnWidths: {
        if (hasFechaVence) 0: const pw.FixedColumnWidth(56),
        (colOffset + 0): const pw.FlexColumnWidth(4),   // Descripción
        (colOffset + 1): const pw.FlexColumnWidth(2),   // Monto
        (colOffset + 2): const pw.FlexColumnWidth(1.5), // Punit.
        (colOffset + 3): const pw.FlexColumnWidth(2),   // Total
      },
      children: [
        // Encabezado
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.white),
          children: [
            if (hasFechaVence) th('Vence', center: true),
            th('Descripción'),
            th('Monto', center: true),
            th('Punit.', center: true),
            th('Total', center: true),
          ],
        ),
        // Filas de servicios
        ...recibo.servicios.asMap().entries.map((e) {
          final s = e.value;
          String venceStr = '';
          if (s.fechaVence != null && s.fechaVence!.isNotEmpty) {
            try { venceStr = fmtDate.format(DateTime.parse(s.fechaVence!)); } catch (_) {
              venceStr = s.fechaVence!;
            }
          }
          final totalFila = s.monto + s.punitorios;
          return pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.white),
            children: [
              if (hasFechaVence) td(venceStr, center: true),
              td(s.descripcion),
              td(_fmtM(recibo, s.monto), center: true),
              td(!recibo.esNeutro && s.punitorios > 0
                  ? _fmtM(recibo, s.punitorios)
                  : (recibo.esNeutro ? '____________' : '—'),
                  center: true),
              td(recibo.esNeutro ? '____________' : _fmtM(recibo, totalFila),
                  center: true, bold: true),
            ],
          );
        }),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // RESUMEN DE PAGO — solo Monto a Abonar + Total Abonado si pagó
  // ══════════════════════════════════════════════════════════════
  static pw.Widget _resumenPago(ReciboModel recibo) {
    const fs = 9.5;
    const fsBig = 10.5;
    final esPagado = recibo.estado == 'pagado' || recibo.montoAbonado > 0;

    pw.Widget fila(String label, String valor, {bool negrita = false}) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(width: 100,
              child: pw.Text(label,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      fontSize: fs, color: _grayColor))),
          pw.SizedBox(width: 4),
          pw.SizedBox(width: 90,
              child: pw.Text(valor,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      fontSize: negrita ? fsBig : fs,
                      fontWeight: negrita
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                      color: _darkColor))),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        fila('Monto a Abonar:', _fmtM(recibo, recibo.montoTotal), negrita: true),
        pw.SizedBox(height: 10),
        if (esPagado)
          fila('Total Abonado:', _fmtM(recibo, recibo.montoAbonado)),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════

  /// LOCADOR / LOCATARIO — cuadro o solo línea abajo
  static pw.Widget _filaLocador(String locador, String locatario,
      {bool soloLinea = false}) {
    pw.Widget campo(String label, String valor) {
      if (soloLinea) {
        return pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: _darkColor)),
              pw.SizedBox(height: 2),
              pw.Text(valor,
                  style: pw.TextStyle(fontSize: 10, color: _darkColor)),
              pw.SizedBox(height: 4),
              pw.Container(height: 0.8, color: _lightBorder),
            ],
          ),
        );
      } else {
        return pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _lightBorder, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label,
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: _darkColor)),
                pw.SizedBox(height: 2),
                pw.Text(valor,
                    style: pw.TextStyle(fontSize: 10, color: _darkColor)),
              ],
            ),
          ),
        );
      }
    }

    return pw.Row(
      children: [
        campo('LOCADOR', locador),
        pw.SizedBox(width: 6),
        campo('LOCATARIO', locatario),
      ],
    );
  }

  static pw.Widget _parrafoMonto(
      String montoLetras, ReciboModel recibo, String dir) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _lightBorder, width: 0.8),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          style: pw.TextStyle(fontSize: 9.5, color: _darkColor, lineSpacing: 3),
          children: [
            const pw.TextSpan(
              text: 'POR MANDATO DEL LOCADOR RECIBÍ DEL LOCATARIO LA SUMA DE ',
            ),
            pw.TextSpan(
                text: montoLetras.toUpperCase(),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(
                text: ' (${_fmtM(recibo, recibo.montoTotal)}) ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(
                text: 'POR EL ALQUILER DE UNA PROPIEDAD QUE OCUPA EN LA CALLE ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.normal)),
            pw.TextSpan(
                text: dir,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(
                text: ', SAN MIGUEL DEL MONTE.',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _lineaCorte() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: List.generate(
          90,
          (i) => pw.Expanded(
            child: pw.Container(
              height: 0.5,
              color: i % 2 == 0 ? _darkColor : PdfColors.white,
            ),
          ),
        ),
      ),
    );
  }

  static pw.Widget _miniInfoFila(String label, String valor) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text('$label ',
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _darkColor)),
        pw.Text(valor,
            style: pw.TextStyle(fontSize: 9, color: _darkColor)),
      ],
    );
  }
}
