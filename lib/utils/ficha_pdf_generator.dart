import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class FichaPdfGenerator {
  static const _magenta = PdfColor.fromInt(0xFFC2185B);
  static const _darkMagenta = PdfColor.fromInt(0xFF880E4F);
  static const _dark = PdfColor.fromInt(0xFF212121);
  static const _gray = PdfColor.fromInt(0xFF757575);
  static const _lightPink = PdfColor.fromInt(0xFFFCE4EC);
  static const _white = PdfColor.fromInt(0xFFFFFFFF);

  static const _telefonos = '22271412950 / 2226546317';
  static const _direccionCorta = 'Blandengues 188 - S.M. del Monte';

  static Future<List<int>> generar({
    required Map<String, dynamic> propiedad,
    required Map<String, dynamic> ficha,
    required List<Map<String, dynamic>> imagenes,
  }) async {
    final pdf = pw.Document();

    // Cargar logo
    pw.MemoryImage? logoImg;
    try {
      final logoData = await rootBundle.load('assets/images/cp.png');
      logoImg = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    // Cargar Material Icons font
    pw.Font? iconFont;
    try {
      final iconData = await rootBundle.load('MaterialIcons-Regular.otf');
      iconFont = pw.Font.ttf(iconData);
    } catch (_) {}

    // Cargar imágenes
    final propImagenes = <pw.MemoryImage>[];
    for (final img in imagenes) {
      try {
        final bytes = await File(img['ruta'] as String).readAsBytes();
        propImagenes.add(pw.MemoryImage(bytes));
      } catch (_) {}
    }

    // Datos ficha
    final operacion = ficha['operacion'] as String? ?? 'Alquiler';
    final dormitorios = ficha['dormitorios'] as int? ?? 0;
    final banos = ficha['banos'] as int? ?? 0;
    final cochera = ficha['cochera'] as int? ?? 0;
    final supTotal = (ficha['superficie_total'] as num?)?.toDouble() ?? 0;
    final supCubierta = (ficha['superficie_cubierta'] as num?)?.toDouble() ?? 0;
    final descripcion = ficha['descripcion'] as String? ?? '';
    final ubicacionFicha = ficha['ubicacion_ficha'] as String? ?? '';

    // Fallback ubicacion from propiedad data
    final tipo = propiedad['tipo'] as String? ?? 'Propiedad';
    final barrio = propiedad['barrio'] as String? ?? '';
    final localidad = propiedad['localidad'] as String? ?? '';
    final ubicacionBarra = ubicacionFicha.isNotEmpty
        ? ubicacionFicha.toUpperCase()
        : [
            tipo.toUpperCase(),
            if (barrio.isNotEmpty) 'EN ${barrio.toUpperCase()}',
            if (barrio.isEmpty && localidad.isNotEmpty) 'EN ${localidad.toUpperCase()}',
          ].join(' ');

    List<String> ambientesLista = [];
    List<String> serviciosLista = [];
    try {
      ambientesLista = List<String>.from(jsonDecode(ficha['ambientes_lista'] as String? ?? '[]'));
    } catch (_) {}
    try {
      serviciosLista = List<String>.from(jsonDecode(ficha['servicios_lista'] as String? ?? '[]'));
    } catch (_) {}

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ══════ HEADER con logo ══════
              _buildHeader(logoImg),

              // ══════ FOTO PRINCIPAL ══════
              _buildFotoPrincipal(propImagenes),

              // ══════ BADGE OPERACIÓN ══════
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 20),
                child: pw.Text(
                  operacion.toUpperCase(),
                  style: pw.TextStyle(
                    color: _magenta,
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),

              // ══════ CONTENIDO ══════
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 20),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Columna izquierda: specs + ambientes + servicios
                      pw.Expanded(
                        flex: 5,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            // Ambientes como lista
                            if (ambientesLista.isNotEmpty) ...[
                              pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  _iconoCirculo(iconFont, 0xe88a), // home icon
                                  pw.SizedBox(width: 6),
                                  pw.Expanded(
                                    child: pw.Text(
                                      ambientesLista.join(' - '),
                                      style: const pw.TextStyle(fontSize: 10, color: _dark),
                                    ),
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 10),
                            ],

                            // Especificaciones en fila
                            _buildEspecificaciones(iconFont, dormitorios, banos, cochera, supTotal, supCubierta),
                            pw.SizedBox(height: 12),

                            // Servicios
                            if (serviciosLista.isNotEmpty) ...[
                              pw.Text('Servicios:',
                                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _dark)),
                              pw.SizedBox(height: 4),
                              ...serviciosLista.map((s) => pw.Padding(
                                padding: const pw.EdgeInsets.only(bottom: 3),
                                child: pw.Row(
                                  children: [
                                    pw.Container(
                                      width: 7, height: 7,
                                      decoration: const pw.BoxDecoration(color: _magenta, shape: pw.BoxShape.circle),
                                    ),
                                    pw.SizedBox(width: 6),
                                    pw.Text(s, style: const pw.TextStyle(fontSize: 9, color: _dark)),
                                  ],
                                ),
                              )),
                              pw.SizedBox(height: 8),
                            ],

                            // Descripción
                            if (descripcion.isNotEmpty)
                              pw.Text(descripcion,
                                  style: const pw.TextStyle(fontSize: 9, color: _gray, lineSpacing: 3),
                                  maxLines: 6),
                          ],
                        ),
                      ),

                      pw.SizedBox(width: 12),

                      // Columna derecha: logo grande
                      pw.SizedBox(
                        width: 100,
                        child: pw.Column(
                          children: [
                            if (logoImg != null)
                              pw.Image(logoImg, width: 80, height: 80),
                            pw.SizedBox(height: 6),
                            pw.Text('COPPOLA\nPAVESE',
                                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _magenta),
                                textAlign: pw.TextAlign.center),
                            pw.Text('INMOBILIARIA',
                                style: const pw.TextStyle(fontSize: 6, color: _gray, letterSpacing: 1),
                                textAlign: pw.TextAlign.center),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ══════ BARRA UBICACIÓN ROSA ══════
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                color: _magenta,
                child: pw.Text(
                  ubicacionBarra,
                  style: pw.TextStyle(color: _white, fontSize: 14, fontWeight: pw.FontWeight.bold, letterSpacing: 1),
                  textAlign: pw.TextAlign.center,
                ),
              ),

              // ══════ FOOTER CONTACTO ══════
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                color: _darkMagenta,
                child: pw.Text(
                  'CONTACTO: $_telefonos  |  $_direccionCorta',
                  style: pw.TextStyle(color: _white, fontSize: 9, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ── Header ─────────────────────────────────────────────────────

  static pw.Widget _buildHeader(pw.MemoryImage? logo) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null)
            pw.ClipOval(child: pw.Image(logo, width: 36, height: 36, fit: pw.BoxFit.cover)),
          if (logo != null) pw.SizedBox(width: 8),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Coppola Pavese',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _dark)),
              pw.Text('INMOBILIARIA',
                  style: const pw.TextStyle(fontSize: 7, color: _gray, letterSpacing: 2)),
            ],
          ),
          pw.Spacer(),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(_telefonos,
                  style: const pw.TextStyle(fontSize: 8, color: _gray)),
              pw.Text('coppolapavese@gmail.com',
                  style: const pw.TextStyle(fontSize: 8, color: _magenta)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Foto principal ─────────────────────────────────────────────

  static pw.Widget _buildFotoPrincipal(List<pw.MemoryImage> imagenes) {
    if (imagenes.isEmpty) {
      return pw.Container(
        height: 300,
        margin: const pw.EdgeInsets.symmetric(horizontal: 16),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFF5F5F5),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Center(
          child: pw.Text('Sin fotos', style: const pw.TextStyle(color: _gray, fontSize: 16)),
        ),
      );
    }

    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(horizontal: 16),
      child: pw.Column(
        children: [
          pw.ClipRRect(
            horizontalRadius: 8,
            verticalRadius: 8,
            child: pw.Image(imagenes.first, fit: pw.BoxFit.cover, height: 280, width: double.infinity),
          ),
          if (imagenes.length > 1) ...[
            pw.SizedBox(height: 4),
            pw.Row(
              children: [
                for (int i = 1; i < min(4, imagenes.length); i++)
                  pw.Expanded(
                    child: pw.Padding(
                      padding: pw.EdgeInsets.only(left: i > 1 ? 4 : 0),
                      child: pw.ClipRRect(
                        horizontalRadius: 4,
                        verticalRadius: 4,
                        child: pw.Image(imagenes[i], fit: pw.BoxFit.cover, height: 70),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Icono circular rosa ────────────────────────────────────────

  static pw.Widget _iconoCirculo(pw.Font? iconFont, int codePoint) {
    // Si tenemos la fuente de Material Icons, usar el icono real
    if (iconFont != null) {
      return pw.Container(
        width: 22, height: 22,
        decoration: const pw.BoxDecoration(color: _lightPink, shape: pw.BoxShape.circle),
        child: pw.Center(
          child: pw.RichText(
            text: pw.TextSpan(
              text: String.fromCharCode(codePoint),
              style: pw.TextStyle(
                font: iconFont,
                fontSize: 14,
                color: _magenta,
              ),
            ),
          ),
        ),
      );
    }
    // Fallback: circulo rosa vacío
    return pw.Container(
      width: 22, height: 22,
      decoration: const pw.BoxDecoration(color: _lightPink, shape: pw.BoxShape.circle),
      child: pw.Center(
        child: pw.Container(
          width: 8, height: 8,
          decoration: const pw.BoxDecoration(color: _magenta, shape: pw.BoxShape.circle),
        ),
      ),
    );
  }

  // ── Especificaciones con iconos ────────────────────────────────

  static pw.Widget _buildEspecificaciones(
      pw.Font? iconFont,
      int dormitorios, int banos, int cochera,
      double supTotal, double supCubierta) {

    final specs = <pw.Widget>[];

    if (dormitorios > 0) {
      specs.add(_specItem(iconFont, 0xe53a, '$dormitorios Habitacion${dormitorios > 1 ? 'es' : ''}')); // hotel icon
    }
    if (banos > 0) {
      specs.add(_specItem(iconFont, 0xe06e, '$banos Ba\u00f1o${banos > 1 ? 's' : ''}')); // bathtub icon
    }
    if (cochera > 0) {
      specs.add(_specItem(iconFont, 0xe531, '$cochera Cochera${cochera > 1 ? 's' : ''}')); // directions_car icon
    }
    if (supTotal > 0) {
      specs.add(_specItemTexto('Lote ${supTotal.toStringAsFixed(0)} m\u00B2'));
    }
    if (supCubierta > 0) {
      specs.add(_specItemTexto('Casa ${supCubierta.toStringAsFixed(0)} m\u00B2'));
    }

    if (specs.isEmpty) return pw.SizedBox();

    return pw.Wrap(
      spacing: 14,
      runSpacing: 8,
      children: specs,
    );
  }

  static pw.Widget _specItem(pw.Font? iconFont, int codePoint, String texto) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        _iconoCirculo(iconFont, codePoint),
        pw.SizedBox(width: 6),
        pw.Text(texto, style: const pw.TextStyle(fontSize: 10, color: _dark)),
      ],
    );
  }

  static pw.Widget _specItemTexto(String texto) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 22, height: 22,
          decoration: pw.BoxDecoration(
            color: _lightPink,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Center(
            child: pw.Text('m\u00B2',
                style: pw.TextStyle(fontSize: 8, color: _magenta, fontWeight: pw.FontWeight.bold)),
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Text(texto, style: const pw.TextStyle(fontSize: 10, color: _dark)),
      ],
    );
  }
}
