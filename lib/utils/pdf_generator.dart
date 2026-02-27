import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/recibo_model.dart';
import 'numero_a_letras.dart';

class PdfGenerator {
  // Paleta de colores del logo
  static const _primaryColor = PdfColor.fromInt(0xFFC2185B);
  static const _darkColor = PdfColor.fromInt(0xFF212121);
  static const _grayColor = PdfColor.fromInt(0xFF757575);
  static const _lightGray = PdfColor.fromInt(0xFFF5F5F5);
  static const _greenColor = PdfColor.fromInt(0xFF2E7D32);
  static const _blueColor = PdfColor.fromInt(0xFF1565C0);
  static const _redColor = PdfColor.fromInt(0xFFC62828);

  static Future<List<int>> generarRecibo(ReciboModel recibo) async {
    final pdf = pw.Document();

    final fmt = DateFormat('dd/MM/yyyy');
    final fmtMonto = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 2);

    String fechaEmision = recibo.fechaEmision;
    String fechaVencimiento = recibo.fechaVencimiento ?? '';
    try {
      fechaEmision = fmt.format(DateTime.parse(recibo.fechaEmision));
    } catch (_) {}
    try {
      if (fechaVencimiento.isNotEmpty) {
        fechaVencimiento =
            fmt.format(DateTime.parse(recibo.fechaVencimiento!));
      }
    } catch (_) {}

    final montoLetras = numeroALetras(recibo.montoTotal);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── ENCABEZADO ──────────────────────────────────────
              _encabezado(recibo, fechaEmision, fechaVencimiento),
              _divisor(),

              // ── DATOS INQUILINO ─────────────────────────────────
              _datosInquilino(recibo),
              _divisor(),

              // ── PÁRRAFO MONTO EN LETRAS ─────────────────────────
              _parrafoMonto(recibo, montoLetras, fmtMonto),
              _divisor(),

              // ── TABLA DE SERVICIOS ──────────────────────────────
              _tablaServicios(recibo, fmtMonto),
              _divisor(),

              // ── RESUMEN DE PAGO ─────────────────────────────────
              _resumenPago(recibo, fmtMonto),
              _divisor(),

              // ── NOTAS ───────────────────────────────────────────
              _seccionNotas(recibo),

              pw.SizedBox(height: 30),

              // ── FIRMAS ──────────────────────────────────────────
              _firmas(),

              pw.Spacer(),

              // ── PIE ─────────────────────────────────────────────
              _pie(),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ── ENCABEZADO ─────────────────────────────────────────────────
  static pw.Widget _encabezado(
      ReciboModel recibo, String fechaEmision, String fechaVencimiento) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Marca ES COPIA centrada
        pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _primaryColor, width: 1.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Text(
              'ES COPIA',
              style: pw.TextStyle(
                color: _primaryColor,
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
                letterSpacing: 3,
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 10),

        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Logo / nombre inmobiliaria
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'COPPOLA PAVESE',
                  style: pw.TextStyle(
                    color: _primaryColor,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
                pw.Text(
                  'INMOBILIARIA',
                  style: pw.TextStyle(
                    color: _darkColor,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            // N° de recibo
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'RECIBO DE ALQUILER',
                  style: pw.TextStyle(
                    color: _darkColor,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                pw.Text(
                  'N° ${recibo.numeroRecibo.toString().padLeft(4, '0')}',
                  style: pw.TextStyle(
                    color: _primaryColor,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),

        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _infoFila('Fecha:', fechaEmision),
            if (recibo.usuario != null && recibo.usuario!.isNotEmpty)
              _infoFila('Responsable:', recibo.usuario!),
          ],
        ),
        if (fechaVencimiento.isNotEmpty)
          _infoFila('Vencimiento:', fechaVencimiento),
        pw.SizedBox(height: 8),
      ],
    );
  }

  // ── DATOS INQUILINO ────────────────────────────────────────────
  static pw.Widget _datosInquilino(ReciboModel recibo) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 8),
        _tituloSeccion('DATOS DEL LOCATARIO'),
        pw.SizedBox(height: 5),
        if (recibo.inquilinoNombre != null &&
            recibo.inquilinoNombre!.isNotEmpty)
          _infoFila('Inquilino:', recibo.inquilinoNombre!),
        if (recibo.direccionCompleta.isNotEmpty)
          _infoFila('Domicilio:', recibo.direccionCompleta),
        if (recibo.propietarioNombre != null &&
            recibo.propietarioNombre!.isNotEmpty)
          _infoFila('Propietario:', recibo.propietarioNombre!),
        pw.SizedBox(height: 8),
      ],
    );
  }

  // ── PÁRRAFO MONTO EN LETRAS ────────────────────────────────────
  static pw.Widget _parrafoMonto(
      ReciboModel recibo, String montoLetras, NumberFormat fmt) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 8),
        _tituloSeccion('CONCEPTO'),
        pw.SizedBox(height: 6),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFFFF8F9),
            border: pw.Border.all(
                color: const PdfColor.fromInt(0xFFEECDD5)),
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.RichText(
            text: pw.TextSpan(
              style: pw.TextStyle(
                  fontSize: 11,
                  color: _darkColor,
                  lineSpacing: 4),
              children: [
                const pw.TextSpan(
                  text:
                      'POR MANDATO DEL LOCADOR RECIBI DEL LOCATARIO LA SUMA DE ',
                ),
                pw.TextSpan(
                  text: montoLetras,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.TextSpan(
                  text: ' (${fmt.format(recibo.montoTotal)})',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                const pw.TextSpan(
                  text:
                      ' POR EL ALQUILER DE UNA PROPIEDAD UBICADA EN ',
                ),
                pw.TextSpan(
                  text: recibo.direccionCompleta.isNotEmpty
                      ? recibo.direccionCompleta.toUpperCase()
                      : '____________________',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                const pw.TextSpan(text: '.'),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 8),
      ],
    );
  }

  // ── TABLA SERVICIOS ────────────────────────────────────────────
  static pw.Widget _tablaServicios(ReciboModel recibo, NumberFormat fmt) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 8),
        _tituloSeccion('DETALLE DE SERVICIOS'),
        pw.SizedBox(height: 6),
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            // Encabezado
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: _primaryColor),
              children: [
                _thPdf('DESCRIPCIÓN'),
                _thPdf('MONTO', center: true),
                _thPdf('PUNITORIOS', center: true),
                _thPdf('TOTAL', center: true),
              ],
            ),
            // Filas de servicios
            ...recibo.servicios.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color:
                      i % 2 == 0 ? PdfColors.white : _lightGray,
                ),
                children: [
                  _tdPdf(s.descripcion),
                  _tdPdf(fmt.format(s.monto), center: true),
                  _tdPdf(
                    s.punitorios > 0 ? fmt.format(s.punitorios) : '—',
                    center: true,
                  ),
                  _tdPdf(fmt.format(s.total),
                      center: true, bold: true),
                ],
              );
            }),
            // Fila total
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: _lightGray),
              children: [
                _tdPdf('TOTAL', bold: true),
                _tdPdf('', center: true),
                _tdPdf('', center: true),
                _tdPdf(fmt.format(recibo.montoTotal),
                    center: true,
                    bold: true,
                    color: _primaryColor),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
      ],
    );
  }

  // ── RESUMEN PAGO ───────────────────────────────────────────────
  static pw.Widget _resumenPago(ReciboModel recibo, NumberFormat fmt) {
    final colorSaldo =
        recibo.saldo > 0 ? _redColor : _greenColor;
    final estadoLabel = recibo.estadoLabel.toUpperCase();
    final colorEstado = recibo.estado == 'pagado'
        ? _greenColor
        : recibo.estado == 'parcial'
            ? const PdfColor.fromInt(0xFFF57C00)
            : _redColor;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 8),
        _tituloSeccion('RESUMEN DE PAGO'),
        pw.SizedBox(height: 6),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
                color: const PdfColor.fromInt(0xFFE0E0E0)),
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            children: [
              _filaResumenPdf(
                'Monto a Abonar:',
                fmt.format(recibo.montoTotal),
                _blueColor,
                fondo: const PdfColor.fromInt(0xFFF5F9FF),
              ),
              pw.Divider(
                  height: 1,
                  color: const PdfColor.fromInt(0xFFE0E0E0)),
              _filaResumenPdf(
                'Total Abonado:',
                fmt.format(recibo.montoAbonado),
                _greenColor,
                fondo: const PdfColor.fromInt(0xFFF5FFF7),
              ),
              pw.Divider(
                  height: 1,
                  color: const PdfColor.fromInt(0xFFE0E0E0)),
              _filaResumenPdf(
                'Saldo:',
                fmt.format(recibo.saldo),
                colorSaldo,
                negrita: true,
                fondo: recibo.saldo > 0
                    ? const PdfColor.fromInt(0xFFFFF5F5)
                    : const PdfColor.fromInt(0xFFF5FFF7),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Text('Estado: ',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: pw.BoxDecoration(
                color: PdfColor(colorEstado.red, colorEstado.green,
                    colorEstado.blue, 0.1),
                border: pw.Border.all(
                    color: PdfColor(colorEstado.red, colorEstado.green,
                        colorEstado.blue, 0.4)),
                borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(10)),
              ),
              child: pw.Text(
                estadoLabel,
                style: pw.TextStyle(
                  color: colorEstado,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
      ],
    );
  }

  // ── NOTAS ──────────────────────────────────────────────────────
  static pw.Widget _seccionNotas(ReciboModel recibo) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 8),
        _tituloSeccion('NOTAS'),
        pw.SizedBox(height: 5),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
                color: const PdfColor.fromInt(0xFFE0E0E0)),
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(
            (recibo.notas != null && recibo.notas!.isNotEmpty)
                ? recibo.notas!
                : ' ',
            style:
                pw.TextStyle(fontSize: 11, color: _darkColor),
          ),
        ),
      ],
    );
  }

  // ── FIRMAS ─────────────────────────────────────────────────────
  static pw.Widget _firmas() {
    return pw.Row(
      children: [
        pw.Expanded(child: _lineaFirmaPdf('Firma Propietario')),
        pw.SizedBox(width: 40),
        pw.Expanded(child: _lineaFirmaPdf('Firma Inquilino')),
      ],
    );
  }

  static pw.Widget _lineaFirmaPdf(String label) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 0.8, color: _darkColor),
        pw.SizedBox(height: 3),
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 9, color: _grayColor),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  // ── PIE ────────────────────────────────────────────────────────
  static pw.Widget _pie() {
    return pw.Center(
      child: pw.Text(
        'Coppola Pavese Inmobiliaria — Documento generado digitalmente',
        style: pw.TextStyle(
            fontSize: 8,
            color: const PdfColor.fromInt(0xFFBDBDBD)),
      ),
    );
  }

  // ── Helpers internos ───────────────────────────────────────────

  static pw.Widget _divisor() {
    return pw.Container(
      height: 1,
      margin: const pw.EdgeInsets.symmetric(vertical: 2),
      color: _primaryColor,
    );
  }

  static pw.Widget _tituloSeccion(String texto) {
    return pw.Text(
      texto,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: _primaryColor,
        letterSpacing: 1,
      ),
    );
  }

  static pw.Widget _infoFila(String label, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '$label ',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF424242),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              valor,
              style: pw.TextStyle(fontSize: 10, color: _darkColor),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _thPdf(String texto, {bool center = false}) {
    return pw.Padding(
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        texto,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 9,
        ),
        textAlign:
            center ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  static pw.Widget _tdPdf(
    String texto, {
    bool center = false,
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        texto,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight:
              bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? _darkColor,
        ),
        textAlign:
            center ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  static pw.Widget _filaResumenPdf(
    String label,
    String valor,
    PdfColor color, {
    PdfColor? fondo,
    bool negrita = false,
  }) {
    return pw.Container(
      color: fondo,
      padding: const pw.EdgeInsets.symmetric(
          horizontal: 12, vertical: 7),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: negrita
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
              color: const PdfColor.fromInt(0xFF424242),
            ),
          ),
          pw.Text(
            valor,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
