import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/recibo_model.dart';
import 'numero_a_letras.dart';

class PdfGenerator {
  // Paleta
  static const _darkColor     = PdfColor.fromInt(0xFF212121);
  static const _grayColor     = PdfColor.fromInt(0xFF757575);
  static const _lightGray     = PdfColor.fromInt(0xFFF5F5F5);
  // ignore: unused_field
  static const _greenColor    = PdfColor.fromInt(0xFF2E7D32);
  // ignore: unused_field
  static const _blueColor     = PdfColor.fromInt(0xFF1565C0);
  // ignore: unused_field
  static const _redColor      = PdfColor.fromInt(0xFFC62828);

  // Datos de la empresa (constantes)
  static const _empresa        = 'COPPOLA PAVESE Inmobiliaria';
  static const _direccionEmpresa = 'Blandengues 188 - San Miguel del Monte - Buenos Aires';
  static const _telefonos      = '02226546317 / 02271412950';
  static const _emailEmpresa   = 'coppolapavese@gmail.com';

  static Future<List<int>> generarRecibo(
    ReciboModel recibo, {
    bool sinPunitorios = false,
    bool tieneConceptosConComprobante = false,
  }) async {
    final pdf = pw.Document();

    final fmt      = DateFormat('dd/MM/yyyy');
    final fmtMonto = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 2);

    final montoLetras = recibo.esNeutro ? '___________________________' : numeroALetras(recibo.montoTotal);

    // Cargar logo
    pw.MemoryImage? logoImg;
    try {
      final logoData = await rootBundle.load('assets/images/cp.png');
      logoImg = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    // Detectar sin punitorios
    final esSinPunitorios = sinPunitorios ||
        (recibo.servicios.isNotEmpty && recibo.servicios.every((s) => s.punitorios == 0));

    final tieneNotas = recibo.notas != null && recibo.notas!.trim().isNotEmpty;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(20, 18, 20, 18),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ═══════════════════ ORIGINAL ═══════════════════
              pw.Expanded(
                flex: 52,
                child: _seccionOriginal(
                  recibo, fmt, fmtMonto, montoLetras,
                  logoImg: logoImg,
                  esSinPunitorios: esSinPunitorios,
                  tieneNotas: tieneNotas,
                ),
              ),

              // ───────── LÍNEA DE CORTE ─────────
              _lineaCorte(),

              // ═══════════════════ COPIA ═══════════════════
              pw.Expanded(
                flex: 48,
                child: _seccionCopia(
                  recibo, fmt, fmtMonto, montoLetras,
                  logoImg: logoImg,
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
  // SECCIÓN ORIGINAL
  // ══════════════════════════════════════════════════════════════
  static pw.Widget _seccionOriginal(
    ReciboModel recibo,
    DateFormat fmt,
    NumberFormat fmtMonto,
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
        // ── CABECERA ──────────────────────────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Logo + datos empresa
            if (logoImg != null)
              pw.Image(logoImg, width: 52, height: 52),
            if (logoImg != null) pw.SizedBox(width: 6),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(_empresa,
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 9,
                          color: _darkColor)),
                  pw.Text(_direccionEmpresa,
                      style: pw.TextStyle(fontSize: 6.5, color: _grayColor)),
                  pw.Text('$_telefonos   $_emailEmpresa',
                      style: pw.TextStyle(fontSize: 6.5, color: _grayColor)),
                ],
              ),
            ),
            // Badge ORIGINAL + datos recibo
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _darkColor),
                  ),
                  child: pw.Text(
                    'ORIGINAL',
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _darkColor),
                  ),
                ),
                pw.SizedBox(height: 3),
                _miniInfoFila('Recibo:', '${recibo.numeroRecibo}'),
                _miniInfoFila('Fecha:', fechaStr),
                if (recibo.usuario != null && recibo.usuario!.isNotEmpty)
                  _miniInfoFila('Usuario:', recibo.usuario!),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 5),

        // ── LOCADOR / LOCATARIO ───────────────────────────────
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _grayColor, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('LOCADOR',
                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _darkColor)),
                    pw.SizedBox(height: 2),
                    pw.Text(locador, style: pw.TextStyle(fontSize: 8, color: _darkColor)),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _grayColor, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('LOCATARIO',
                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _darkColor)),
                    pw.SizedBox(height: 2),
                    pw.Text(locatario, style: pw.TextStyle(fontSize: 8, color: _darkColor)),
                  ],
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 5),

        // ── PÁRRAFO MONTO ─────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _grayColor, width: 0.5),
          ),
          child: pw.RichText(
          text: pw.TextSpan(
            style: pw.TextStyle(fontSize: 8, color: _darkColor, lineSpacing: 3),
            children: [
              const pw.TextSpan(
                text: 'POR MANDATO DEL LOCADOR RECIBÍ DEL LOCATARIO LA SUMA DE ',
              ),
              pw.TextSpan(
                  text: montoLetras.toUpperCase(),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.TextSpan(
                  text: ' POR EL ALQUILER DE UNA PROPIEDAD QUE OCUPA EN LA CALLE ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.normal)),
              pw.TextSpan(
                  text: dir,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              const pw.TextSpan(text: '.'),
            ],
          ),
        ),
        ),
        pw.SizedBox(height: 5),

        // ── TABLA SERVICIOS ───────────────────────────────────
        _tablaServicios(recibo, fmtMonto, esSinPunitorios: esSinPunitorios),
        pw.SizedBox(height: 5),

        // ── RESUMEN + NOTAS ───────────────────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Notas lado izquierdo
            pw.Expanded(
              child: tieneNotas
                  ? pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Notas',
                            style: pw.TextStyle(
                                fontSize: 7,
                                fontWeight: pw.FontWeight.bold,
                                color: _grayColor)),
                        pw.SizedBox(height: 2),
                        pw.Text(recibo.notas!,
                            style: pw.TextStyle(
                                fontSize: 7.5,
                                color: _darkColor,
                                fontStyle: pw.FontStyle.italic)),
                      ],
                    )
                  : pw.SizedBox(),
            ),
            // Resumen lado derecho
            _resumenPago(recibo, fmtMonto),
          ],
        ),
        pw.SizedBox(height: 6),

        // ── FOOTER ────────────────────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              _empresa,
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
  // SECCIÓN COPIA
  // ══════════════════════════════════════════════════════════════
  static pw.Widget _seccionCopia(
    ReciboModel recibo,
    DateFormat fmt,
    NumberFormat fmtMonto,
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
        pw.SizedBox(height: 4),
        // ── CABECERA COPIA ────────────────────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Logo
            if (logoImg != null)
              pw.Image(logoImg, width: 36, height: 36),
            if (logoImg != null) pw.SizedBox(width: 6),
            // Datos del inquilino (izquierda)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(_empresa,
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                          color: _darkColor)),
                  _miniInfoFila('Señor(es):', locatario),
                  if (recibo.direccionCompleta.isNotEmpty)
                    _miniInfoFila('Domicilio:', recibo.direccionCompleta),
                ],
              ),
            ),
            // Badge ES COPIA + datos recibo (derecha)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 2),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _darkColor),
                  ),
                  child: pw.Text(
                    'ES COPIA',
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _darkColor),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    _miniInfoFila('Recibo:', '${recibo.numeroRecibo}'),
                    pw.SizedBox(width: 8),
                    _miniInfoFila('Fecha:', fechaStr),
                    if (recibo.usuario != null &&
                        recibo.usuario!.isNotEmpty) ...[
                      pw.SizedBox(width: 8),
                      _miniInfoFila('Usuario:', recibo.usuario!),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 5),

        // ── LOCADOR / LOCATARIO ───────────────────────────────
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _grayColor, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('LOCADOR',
                        style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: _darkColor)),
                    pw.SizedBox(height: 1),
                    pw.Text(locador, style: pw.TextStyle(fontSize: 7.5, color: _darkColor)),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 4),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _grayColor, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('LOCATARIO',
                        style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: _darkColor)),
                    pw.SizedBox(height: 1),
                    pw.Text(locatario, style: pw.TextStyle(fontSize: 7.5, color: _darkColor)),
                  ],
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),

        // ── PÁRRAFO MONTO ─────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _grayColor, width: 0.5),
          ),
          child: pw.RichText(
          text: pw.TextSpan(
            style: pw.TextStyle(fontSize: 7.5, color: _darkColor, lineSpacing: 2.5),
            children: [
              const pw.TextSpan(
                text: 'POR MANDATO DEL LOCADOR RECIBÍ DEL LOCATARIO LA SUMA DE ',
              ),
              pw.TextSpan(
                  text: montoLetras.toUpperCase(),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              const pw.TextSpan(
                  text: ' POR EL ALQUILER DE UNA PROPIEDAD QUE OCUPA EN LA CALLE '),
              pw.TextSpan(
                  text: dir,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              const pw.TextSpan(text: '.'),
            ],
          ),
        ),
        ),
        pw.SizedBox(height: 4),

        // ── SEGÚN DETALLE ─────────────────────────────────────
        pw.Text('Según Detalle:',
            style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: _darkColor)),
        pw.SizedBox(height: 3),
        _tablaServicios(recibo, fmtMonto,
            esSinPunitorios: esSinPunitorios, small: true),
        pw.SizedBox(height: 4),

        // ── RESUMEN + NOTAS ───────────────────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: tieneNotas
                  ? pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Notas',
                            style: pw.TextStyle(
                                fontSize: 7,
                                fontWeight: pw.FontWeight.bold,
                                color: _grayColor)),
                        pw.SizedBox(height: 2),
                        pw.Text(recibo.notas!,
                            style: pw.TextStyle(
                                fontSize: 7,
                                color: _darkColor,
                                fontStyle: pw.FontStyle.italic)),
                      ],
                    )
                  : pw.SizedBox(),
            ),
            _resumenPago(recibo, fmtMonto, small: true),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // TABLA DE SERVICIOS
  // ══════════════════════════════════════════════════════════════
  static pw.Widget _tablaServicios(
    ReciboModel recibo,
    NumberFormat fmt, {
    bool esSinPunitorios = false,
    bool small = false,
  }) {
    final fs   = small ? 7.0 : 7.5;
    final fsTh = small ? 6.5 : 7.5;
    final pad  = small ? 2.5 : 3.5;

    pw.Widget th(String t, {bool center = false}) => pw.Padding(
          padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: pad),
          child: pw.Text(t,
              style: pw.TextStyle(
                  color: _darkColor,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: fsTh),
              textAlign: center ? pw.TextAlign.center : pw.TextAlign.left),
        );

    pw.Widget td(String t, {bool center = false, bool bold = false}) =>
        pw.Padding(
          padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: pad),
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

    final totalGeneral = recibo.servicios.fold<double>(
        0, (sum, s) => sum + s.total);

    return pw.Table(
      border: pw.TableBorder(
        top:              const pw.BorderSide(width: 0.8, color: _darkColor),
        bottom:           const pw.BorderSide(width: 0.8, color: _darkColor),
        left:             const pw.BorderSide(width: 0.5, color: _darkColor),
        right:            const pw.BorderSide(width: 0.5, color: _darkColor),
        horizontalInside: const pw.BorderSide(width: 0.4, color: _grayColor),
        verticalInside:   const pw.BorderSide(width: 0.4, color: _grayColor),
      ),
      columnWidths: {
        if (hasFechaVence) 0: const pw.FixedColumnWidth(52),
        (hasFechaVence ? 1 : 0): const pw.FlexColumnWidth(4),
        (hasFechaVence ? 2 : 1): const pw.FlexColumnWidth(2),
        (hasFechaVence ? 3 : 2): const pw.FlexColumnWidth(2),
        (hasFechaVence ? 4 : 3): const pw.FlexColumnWidth(2),
      },
      children: [
        // Encabezado — sin fondo, solo texto negro bold
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
          final i = e.key;
          final s = e.value;
          String venceStr = '';
          if (s.fechaVence != null && s.fechaVence!.isNotEmpty) {
            try { venceStr = fmtDate.format(DateTime.parse(s.fechaVence!)); } catch (_) {
              venceStr = s.fechaVence!;
            }
          }
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i % 2 == 0 ? PdfColors.white : _lightGray,
            ),
            children: [
              if (hasFechaVence) td(venceStr, center: true),
              td(s.descripcion),
              td(recibo.esNeutro ? '____________' : fmt.format(s.monto), center: true),
              td(recibo.esNeutro ? '____________' : (s.punitorios > 0 ? fmt.format(s.punitorios) : '\$0,00'),
                  center: true),
              td(recibo.esNeutro ? '____________' : fmt.format(s.total), center: true, bold: true),
            ],
          );
        }),
        // Fila total
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _lightGray),
          children: [
            if (hasFechaVence) td(''),
            td('TOTAL', bold: true),
            td(''),
            td(''),
            td(recibo.esNeutro ? '____________' : fmt.format(totalGeneral), center: true, bold: true),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // RESUMEN DE PAGO
  // ══════════════════════════════════════════════════════════════
  static pw.Widget _resumenPago(
    ReciboModel recibo,
    NumberFormat fmt, {
    bool small = false,
  }) {
    final fs = small ? 7.5 : 8.5;
    final fsBig = small ? 8.0 : 9.5;

    pw.Widget fila(String label, String valor, PdfColor color,
        {bool negrita = false}) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(width: 80,
              child: pw.Text(label,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      fontSize: fs, color: _grayColor))),
          pw.SizedBox(width: 4),
          pw.SizedBox(width: 80,
              child: pw.Text(valor,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      fontSize: negrita ? fsBig : fs,
                      fontWeight: negrita
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                      color: color))),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        fila('Monto a Abonar:', recibo.esNeutro ? '____________' : fmt.format(recibo.montoTotal), _darkColor),
        pw.SizedBox(height: 2),
        fila('TOTAL ABONADO:', recibo.esNeutro ? '____________' : fmt.format(recibo.montoAbonado), _darkColor,
            negrita: true),
        pw.SizedBox(height: 2),
        fila('Saldo:', recibo.esNeutro ? '____________' : fmt.format(recibo.saldo), _darkColor, negrita: true),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════
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

  static pw.Widget _barraLinea() {
    return pw.Container(height: 1, color: _darkColor);
  }

  static pw.Widget _miniInfoFila(String label, String valor) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text('$label ',
            style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: _darkColor)),
        pw.Text(valor,
            style: pw.TextStyle(fontSize: 7.5, color: _darkColor)),
      ],
    );
  }
}
