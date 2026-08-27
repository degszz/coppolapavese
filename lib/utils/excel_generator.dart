import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

class ExcelGenerator {
  // ── Colores del tema ───────────────────────────────────────────
  static final _magentaBorder = ExcelColor.fromHexString('#C2185B');
  static final _lightBorder = ExcelColor.fromHexString('#E0E0E0');
  static final _whiteFill = ExcelColor.fromHexString('#FFFFFF');
  static final _blackFont = ExcelColor.fromHexString('#212121');

  static final _fmtFecha = DateFormat('dd/MM/yyyy');
  static final _fmtMonto =
      NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0, customPattern: '\u00A4#,##0');
  static final _fmtMesAnio = DateFormat('MMMM yyyy', 'es');

  // ═════════════════════════════════════════════════════════════════
  // REPORTE PROPIETARIO — hoja única, pensada para imprimir/fotocopiar
  // ═════════════════════════════════════════════════════════════════

  static Future<List<int>> generarExcelPropietario({
    required List<Map<String, dynamic>> recibos,
    String? propietarioNombre,
    String? mesAnio,
  }) async {
    final excel = Excel.createExcel();

    _crearHojaResumenPropietario(excel, recibos,
        propietarioNombre: propietarioNombre, mesAnio: mesAnio);

    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');
    final bytes = excel.save();
    if (bytes == null) return [];

// Post-procesar XLSX: solo settings de impresión (sin gráfico)
    try {
      return _postProcesarXlsx(bytes);
    } catch (_) {
      return bytes;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // HOJA RESUMEN — PROPIETARIO
  // ═════════════════════════════════════════════════════════════════
  // POST-PROCESADO OOXML: print settings
  // ════════════════════════════════════════════════════════════════

  static void _crearHojaResumenPropietario(
      Excel excel, List<Map<String, dynamic>> recibos,
      {String? propietarioNombre, String? mesAnio}) {
    final sheet = excel['Resumen Propietarios'];

    // ── Encabezado superior: Propietario + Mes/Año ──
    final nombreProp = propietarioNombre ?? _extraerPropietario(recibos);
    final periodo = mesAnio ?? _fmtMesAnio.format(DateTime.now());

    _celdaTitulo(sheet, 0, 0, 'COPPOLA PAVESE INMOBILIARIA', 6);
    _celdaTitulo(sheet, 1, 0, 'Propietario: $nombreProp', 6);
    _celdaTitulo(sheet, 2, 0, 'Período: $periodo', 6);
    _celdaTitulo(
        sheet, 3, 0, 'Generado: ${_fmtFecha.format(DateTime.now())}', 6);
    sheet.appendRow([TextCellValue('')]);

    final headers = [
      'Inquilino',
      'Propiedad',
      'Alquiler Mes',
      '10%',
      'Total Propietario',
      'Observaciones',
    ];
    _agregarEncabezados(sheet, sheet.maxRows, headers);

    // Agrupar por contrato_id (una fila por contrato)
    final mapa = <int, _ResumenContrato>{};
    for (final r in recibos) {
      final contratoId = (r['contrato_id'] as num?)?.toInt() ?? 0;
      if (contratoId == 0) continue; // saltar sin contrato

      final inquilino = r['inquilino_nombre'] as String? ?? 'Sin inquilino';
      final direccion = r['direccion'] as String? ?? '';
      final localidad = r['localidad'] as String? ?? '';
      final propiedad =
          localidad.isNotEmpty ? '$direccion, $localidad' : direccion;
      final montoPeriodoActual =
          (r['monto_periodo_actual'] as num?)?.toDouble() ?? 0.0;
      final estado = r['estado'] as String? ?? 'pendiente';
      final servicios = r['servicios_descripcion'] as String? ?? '';

      if (!mapa.containsKey(contratoId)) {
        mapa[contratoId] = _ResumenContrato(
          contratoId: contratoId,
          inquilino: inquilino,
          propiedad: propiedad,
          montoPeriodoActual: montoPeriodoActual,
          estado: estado,
          servicios: servicios,
        );
      } else {
        // Si hay múltiples recibos para el mismo contrato, mantener el estado "no pagado" si alguno lo está
        if (estado != 'pagado') {
          mapa[contratoId]!.estado = estado;
        }
        // Concatenar servicios si son diferentes
        final existing = mapa[contratoId]!.servicios;
        if (servicios.isNotEmpty &&
            !existing.contains(servicios) &&
            !servicios.contains(existing)) {
          mapa[contratoId]!.servicios = '$existing | $servicios';
        }
      }
    }

    double sumAlquiler = 0, sumAdm = 0, sumProp = 0;

    for (final entry in mapa.values) {
      final monto = entry.montoPeriodoActual;
      final adm = monto * 0.10;
      final totalProp = monto - adm;
      sumAlquiler += monto;
      sumAdm += adm;
      sumProp += totalProp;

      // Observaciones = servicios del recibo (con precios)
      String obs = entry.servicios.isNotEmpty ? entry.servicios : 'Sin servicios';

      final fila = sheet.maxRows;
      sheet.appendRow([
        TextCellValue(entry.inquilino),
        TextCellValue(entry.propiedad),
        TextCellValue(_fmtMonto.format(monto)),
        TextCellValue(_fmtMonto.format(adm)),
        TextCellValue(_fmtMonto.format(totalProp)),
        TextCellValue(obs),
      ]);

      // Estilo fila de datos: fondo blanco, bordes finos
      for (int c = 0; c < 6; c++) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: fila));
        cell.cellStyle = CellStyle(
          fontSize: 11,
          backgroundColorHex: _whiteFill,
          fontColorHex: _blackFont,
          textWrapping: TextWrapping.WrapText,
          verticalAlign: VerticalAlign.Center,
          leftBorder: Border(
              borderStyle: BorderStyle.Thin, borderColorHex: _lightBorder),
          rightBorder: Border(
              borderStyle: BorderStyle.Thin, borderColorHex: _lightBorder),
          bottomBorder: Border(
              borderStyle: BorderStyle.Thin, borderColorHex: _lightBorder),
        );
      }
    }

    _agregarFilaTotales(sheet, [
      'TOTALES',
      '',
      _fmtMonto.format(sumAlquiler),
      _fmtMonto.format(sumAdm),
      _fmtMonto.format(sumProp),
      '',
    ]);

    // ── Ajustar anchos de columnas para A4 landscape ──
    // Más altos, menos anchos para que quepa en una hoja al fotocopiar
    _ajustarAnchos(sheet, [35, 38, 20, 16, 22, 55]);

    // Altura de filas: más altas para fotocopia
    for (int r = 0; r < sheet.maxRows; r++) {
      sheet.setRowHeight(r, 36);
    }
    // Filas de encabezado un poco más altas
    for (int r = 0; r < 5; r++) {
      sheet.setRowHeight(r, 40);
    }
  }

  /// Extraer nombre del propietario más frecuente de los recibos
  static String _extraerPropietario(List<Map<String, dynamic>> recibos) {
    if (recibos.isEmpty) return 'Todos';
    final nombres = <String, int>{};
    for (final r in recibos) {
      final n = r['propietario_nombre'] as String? ?? '';
      if (n.isNotEmpty) nombres[n] = (nombres[n] ?? 0) + 1;
    }
    if (nombres.isEmpty) return 'Todos';
    if (nombres.length == 1) return nombres.keys.first;
    return 'Varios Propietarios';
  }

  // ════════════════════════════════════════════════════════════════
  // HELPERS DE FORMATO
  // ════════════════════════════════════════════════════════════════

  static void _celdaTitulo(
      Sheet sheet, int fila, int col, String texto, int span) {
    while (sheet.maxRows <= fila) {
      sheet.appendRow([TextCellValue('')]);
    }
    final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: fila));
    cell.value = TextCellValue(texto);
    cell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: _magentaBorder,
    );
  }

  static void _agregarEncabezados(
      Sheet sheet, int fila, List<String> headers) {
    while (sheet.maxRows <= fila) {
      sheet.appendRow([TextCellValue('')]);
    }
    for (int c = 0; c < headers.length; c++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: fila));
      cell.value = TextCellValue(headers[c]);
      cell.cellStyle = CellStyle(
        bold: true,
        fontSize: 12,
        fontColorHex: _magentaBorder,
        backgroundColorHex: _whiteFill, // Fondo blanco para impresión B&N
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        textWrapping: TextWrapping.WrapText,
        topBorder: Border(
            borderStyle: BorderStyle.Medium, borderColorHex: _magentaBorder),
        bottomBorder: Border(
            borderStyle: BorderStyle.Medium, borderColorHex: _magentaBorder),
        leftBorder: Border(
            borderStyle: BorderStyle.Thin, borderColorHex: _magentaBorder),
        rightBorder: Border(
            borderStyle: BorderStyle.Thin, borderColorHex: _magentaBorder),
      );
    }
  }

  static void _agregarFilaTotales(Sheet sheet, List<dynamic> valores) {
    final fila = sheet.maxRows;
    sheet.appendRow(valores.map((v) => _toCell(v)).toList());
    for (int c = 0; c < valores.length; c++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: fila));
      cell.cellStyle = CellStyle(
        bold: true,
        fontSize: 13,
        backgroundColorHex: _whiteFill, // Fondo blanco para impresión B&N
        fontColorHex: _magentaBorder,
        topBorder: Border(
            borderStyle: BorderStyle.Medium, borderColorHex: _magentaBorder),
        bottomBorder: Border(
            borderStyle: BorderStyle.Medium, borderColorHex: _magentaBorder),
        leftBorder: Border(
            borderStyle: BorderStyle.Thin, borderColorHex: _magentaBorder),
        rightBorder: Border(
            borderStyle: BorderStyle.Thin, borderColorHex: _magentaBorder),
      );
    }
  }

  static void _ajustarAnchos(Sheet sheet, List<int> anchos) {
    for (int i = 0; i < anchos.length; i++) {
      sheet.setColumnWidth(i, anchos[i].toDouble());
    }
  }

  static CellValue _toCell(dynamic valor) {
    if (valor is int) return IntCellValue(valor);
    if (valor is double) return DoubleCellValue(valor);
    return TextCellValue(valor?.toString() ?? '');
  }

  // ════════════════════════════════════════════════════════════════
  // POST-PROCESADO OOXML: print settings + gráfico de barras
  // ════════════════════════════════════════════════════════════════

  static List<int> _postProcesarXlsx(List<int> bytes) {
    final decoder = ZipDecoder();
    final archive = decoder.decodeBytes(bytes);
    final encoder = ZipEncoder();

    // Inyectar pageSetup / printOptions / pageMargins en sheet1.xml
    final sheetFile = archive.files.firstWhere(
      (f) => f.name == 'xl/worksheets/sheet1.xml',
      orElse: () => ArchiveFile('', 0, []),
    );
    if (sheetFile.name.isEmpty) return bytes;

    String sheetXml = utf8.decode(sheetFile.content as List<int>);

    // Agregar printOptions + pageMargins + pageSetup antes de </worksheet>
    sheetXml = _asegurarPrintSettings(sheetXml);

    _reemplazarArchivo(archive, 'xl/worksheets/sheet1.xml',
        utf8.encode(sheetXml));

    final out = encoder.encode(archive);
    return out ?? bytes;
  }

  /// Asegura que sheet1.xml tenga printOptions, pageMargins y pageSetup
  /// configurados para impresión/fotocopia (horizontal, ajustar a página).
  static String _asegurarPrintSettings(String xml) {
    // Remover los existentes si los hay
    xml = xml.replaceAll(RegExp(r'<printOptions[^/]*/>'), '');
    xml = xml.replaceAll(RegExp(r'<pageMargins[^/]*/>'), '');
    xml = xml.replaceAll(RegExp(r'<pageSetup[^/]*/>'), '');
    xml = xml.replaceAll(RegExp(r'<pageSetUpPr[^/]*/>'), '');

    // Agregar sheetPr con fitToPage
    if (!xml.contains('<sheetPr')) {
      xml = xml.replaceFirst(
        '<dimension',
        '<sheetPr><pageSetUpPr fitToPage="1"/></sheetPr><dimension',
      );
    } else {
      xml = xml.replaceFirst(
        RegExp(r'<sheetPr[^>]*/?>'),
        '<sheetPr><pageSetUpPr fitToPage="1"/></sheetPr>',
      );
    }

    final printBlock =
        '<printOptions horizontalCentered="1"/>'
        '<pageMargins left="0.4" right="0.4" top="0.5" bottom="0.5" header="0.2" footer="0.2"/>'
        '<pageSetup paperSize="9" orientation="landscape" fitToWidth="1" fitToHeight="0" horizontalDpi="300" verticalDpi="300"/>';

    xml = xml.replaceFirst('</worksheet>', '$printBlock</worksheet>');
    return xml;
  }

  static void _reemplazarArchivo(
      Archive archive, String nombre, List<int> contenido) {
    archive.files.removeWhere((f) => f.name == nombre);
    archive.addFile(ArchiveFile(nombre, contenido.length, contenido));
  }
}

class _ResumenContrato {
  final int contratoId;
  final String inquilino;
  final String propiedad;
  final double montoPeriodoActual;
  String estado;
  String servicios;

  _ResumenContrato({
    required this.contratoId,
    required this.inquilino,
    required this.propiedad,
    required this.montoPeriodoActual,
    required this.estado,
    required this.servicios,
  });
}
