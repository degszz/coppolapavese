import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

class ExcelGenerator {
  // ── Colores del tema ───────────────────────────────────────────
  static final _magentaBorder = ExcelColor.fromHexString('#C2185B');
  static final _lightBorder = ExcelColor.fromHexString('#E0E0E0');
  static final _whiteFill = ExcelColor.fromHexString('#FFFFFF');
  static final _totalFill = ExcelColor.fromHexString('#FAFAFA');
  static final _headerFill = ExcelColor.fromHexString('#FCE4EC');
  static final _redFont = ExcelColor.fromHexString('#C62828');
  static final _blackFont = ExcelColor.fromHexString('#212121');

  static final _fmtFecha = DateFormat('dd/MM/yyyy');
  static final _fmtMonto =
      NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0, customPattern: '\u00A4#,##0');
  static final _fmtMesAnio = DateFormat('MMMM yyyy', 'es');
  static final _fmtMesCorto = DateFormat('MMM', 'es');

  // Guardamos la posición del bloque mensual para inyectar el gráfico luego
  static int _mensualHeaderRow = -1;
  static int _mensualFirstDataRow = -1;
  static int _mensualLastDataRow = -1;

  // ════════════════════════════════════════════════════════════════
  // REPORTE PROPIETARIO — hoja única, pensada para imprimir/fotocopiar
  // ════════════════════════════════════════════════════════════════

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

    // Post-procesar XLSX: settings de impresión + gráfico
    try {
      return _postProcesarXlsx(
        bytes,
        chartHeaderRow: _mensualHeaderRow,
        chartFirstDataRow: _mensualFirstDataRow,
        chartLastDataRow: _mensualLastDataRow,
      );
    } catch (_) {
      // Si algo falla en el post-proceso, devolvemos el xlsx original
      return bytes;
    }
  }

  // ════════════════════════════════════════════════════════════════
  // HOJA RESUMEN — PROPIETARIO
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

    // Agrupar por inquilino + propiedad
    final mapa = <String, _ResumenPropietario>{};
    for (final r in recibos) {
      final inquilino = r['inquilino_nombre'] as String? ?? 'Sin inquilino';
      final direccion = r['direccion'] as String? ?? '';
      final localidad = r['localidad'] as String? ?? '';
      final propiedad =
          localidad.isNotEmpty ? '$direccion, $localidad' : direccion;
      final clave = '$inquilino|$propiedad';
      final estado = r['estado'] as String? ?? 'pendiente';

      if (!mapa.containsKey(clave)) {
        mapa[clave] = _ResumenPropietario(
          propietario: r['propietario_nombre'] as String? ?? '',
          inquilino: inquilino,
          propiedad: propiedad,
        );
      }
      final entry = mapa[clave]!;
      final monto = (r['monto_total'] as num?)?.toDouble() ?? 0.0;
      entry.montoTotal += monto;

      if (estado == 'pagado') {
        entry.pagado = true;
      } else {
        entry.pagado = false;
        entry.montoPendiente += monto;
      }

      final fecha = r['fecha_emision'] as String? ?? '';
      if (fecha.isNotEmpty && entry.fechaEmision.isEmpty) {
        entry.fechaEmision = fecha;
      }

      final nota = r['notas'] as String? ?? '';
      if (nota.isNotEmpty && !entry.notas.contains(nota)) {
        entry.notas.add(nota);
      }
    }

    double sumAlquiler = 0, sumAdm = 0, sumProp = 0;

    for (final entry in mapa.values) {
      final monto = entry.montoTotal;
      final adm = monto * 0.10;
      final totalProp = monto - adm;
      sumAlquiler += monto;
      sumAdm += adm;
      sumProp += totalProp;

      String obs = '';
      if (entry.pagado) {
        obs = 'PAGADO';
      } else {
        String mesAnioStr = '';
        if (entry.fechaEmision.isNotEmpty) {
          try {
            final dt = DateTime.parse(entry.fechaEmision);
            mesAnioStr = ' Alquiler ${_fmtMesCorto.format(dt)} ${dt.year}';
          } catch (_) {}
        }
        String cuotasStr = '';
        for (final n in entry.notas) {
          final match = RegExp(r'cuotas?\s*(\d+\s*[-–]\s*\d+)', caseSensitive: false).firstMatch(n);
          if (match != null) {
            cuotasStr = ', cuotas ${match.group(1)!.replaceAll('–', '-')}';
            break;
          }
        }
        obs = '${_fmtMonto.format(-entry.montoPendiente)}$mesAnioStr$cuotasStr';
      }

      final fila = sheet.maxRows;
      sheet.appendRow([
        TextCellValue(entry.inquilino),
        TextCellValue(entry.propiedad),
        TextCellValue(_fmtMonto.format(monto)),
        TextCellValue(_fmtMonto.format(adm)),
        TextCellValue(_fmtMonto.format(totalProp)),
        TextCellValue(obs),
      ]);

      final esNegativo = !entry.pagado;
      for (int c = 0; c < 6; c++) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: fila));
        cell.cellStyle = CellStyle(
          fontSize: 12,
          backgroundColorHex: _whiteFill,
          fontColorHex: (c == 5 && esNegativo) ? _redFont : _blackFont,
          bold: c == 5 && esNegativo,
          leftBorder: Border(
              borderStyle: BorderStyle.Thin, borderColorHex: _magentaBorder),
          rightBorder: Border(
              borderStyle: BorderStyle.Thin, borderColorHex: _magentaBorder),
          bottomBorder: Border(
              borderStyle: BorderStyle.Hair, borderColorHex: _lightBorder),
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

    // ── BLOQUE MENSUAL (debajo de la tabla principal) ──
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('')]);
    _celdaTitulo(sheet, sheet.maxRows, 0, 'INGRESOS POR MES', 3);
    sheet.appendRow([TextCellValue('')]);

    _mensualHeaderRow = sheet.maxRows;
    _agregarEncabezados(sheet, _mensualHeaderRow, ['Mes', 'Emitido', 'Cobrado']);

    final mesesEs = [
      '',
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    final porMes = <String, _DatoMesGrafico>{};
    for (final r in recibos) {
      final fecha = r['fecha_emision'] as String? ?? '';
      if (fecha.length < 7) continue;
      final clave = fecha.substring(0, 7);
      porMes.putIfAbsent(clave, () => _DatoMesGrafico());
      final monto = (r['monto_total'] as num?)?.toDouble() ?? 0.0;
      final abonado = (r['monto_abonado'] as num?)?.toDouble() ?? 0.0;
      porMes[clave]!.emitido += monto;
      porMes[clave]!.cobrado += abonado;
    }
    final claves = porMes.keys.toList()..sort();

    _mensualFirstDataRow = -1;
    _mensualLastDataRow = -1;

    for (final clave in claves) {
      final d = porMes[clave]!;
      final partes = clave.split('-');
      final anio = partes[0];
      final mesNum = int.tryParse(partes[1]) ?? 1;
      final etiqueta = '${mesesEs[mesNum]} $anio';

      final fila = sheet.maxRows;
      if (_mensualFirstDataRow == -1) _mensualFirstDataRow = fila;
      _mensualLastDataRow = fila;

      // Usamos valores NUMÉRICOS para que el gráfico pueda leerlos.
      sheet.appendRow([
        TextCellValue(etiqueta),
        DoubleCellValue(d.emitido),
        DoubleCellValue(d.cobrado),
      ]);

      for (int c = 0; c < 3; c++) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: fila));
        cell.cellStyle = CellStyle(
          fontSize: 12,
          backgroundColorHex: _whiteFill,
          numberFormat: c > 0
              ? CustomNumericNumFormat(formatCode: '"\$"#,##0')
              : NumFormat.defaultNumeric,
          fontColorHex: c == 1
              ? ExcelColor.fromHexString('#E65100')
              : c == 2
                  ? ExcelColor.fromHexString('#2E7D32')
                  : _blackFont,
          bold: c > 0,
          leftBorder: Border(
              borderStyle: BorderStyle.Thin, borderColorHex: _magentaBorder),
          rightBorder: Border(
              borderStyle: BorderStyle.Thin, borderColorHex: _magentaBorder),
          bottomBorder: Border(
              borderStyle: BorderStyle.Hair, borderColorHex: _lightBorder),
        );
      }
    }

    _ajustarAnchos(sheet, [28, 32, 22, 22, 22, 42]);

    // Altura de filas
    for (int r = 0; r < sheet.maxRows; r++) {
      sheet.setRowHeight(r, 26);
    }
    for (int r = 0; r < 5; r++) {
      sheet.setRowHeight(r, 30);
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
        backgroundColorHex: _headerFill,
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
        backgroundColorHex: _totalFill,
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

  static List<int> _postProcesarXlsx(
    List<int> bytes, {
    required int chartHeaderRow,
    required int chartFirstDataRow,
    required int chartLastDataRow,
  }) {
    final decoder = ZipDecoder();
    final archive = decoder.decodeBytes(bytes);
    final encoder = ZipEncoder();

    // 1) Inyectar pageSetup / printOptions / pageMargins en sheet1.xml
    final sheetFile = archive.files.firstWhere(
      (f) => f.name == 'xl/worksheets/sheet1.xml',
      orElse: () => ArchiveFile('', 0, []),
    );
    if (sheetFile.name.isEmpty) return bytes;

    String sheetXml = utf8.decode(sheetFile.content as List<int>);

    // Agregar printOptions + pageMargins + pageSetup antes de </worksheet>
    // Si ya existen, los reemplazamos.
    sheetXml = _asegurarPrintSettings(sheetXml);

    // 2) (Intento) inyectar gráfico de barras con los datos mensuales.
    final puedeGraficar = chartFirstDataRow >= 0 &&
        chartLastDataRow >= chartFirstDataRow &&
        chartHeaderRow >= 0;

    if (puedeGraficar) {
      // Agregar referencia <drawing r:id="rId100"/> a sheet1.xml
      if (!sheetXml.contains('<drawing ')) {
        sheetXml = sheetXml.replaceFirst(
          '</worksheet>',
          '<drawing r:id="rId100"/></worksheet>',
        );
      }
    }

    _reemplazarArchivo(archive, 'xl/worksheets/sheet1.xml',
        utf8.encode(sheetXml));

    if (puedeGraficar) {
      // sheet1.xml.rels: agregar relación al drawing
      final relsPath = 'xl/worksheets/_rels/sheet1.xml.rels';
      final relsFile = archive.files.firstWhere(
        (f) => f.name == relsPath,
        orElse: () => ArchiveFile('', 0, []),
      );
      String relsXml;
      if (relsFile.name.isEmpty) {
        relsXml =
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId100" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing" Target="../drawings/drawing1.xml"/>'
            '</Relationships>';
      } else {
        relsXml = utf8.decode(relsFile.content as List<int>);
        if (!relsXml.contains('rId100')) {
          relsXml = relsXml.replaceFirst(
            '</Relationships>',
            '<Relationship Id="rId100" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing" Target="../drawings/drawing1.xml"/></Relationships>',
          );
        }
      }
      _reemplazarArchivo(archive, relsPath, utf8.encode(relsXml));

      // drawing1.xml
      final anchorStartRow = chartHeaderRow;
      final anchorEndRow = chartHeaderRow + 20;
      final drawingXml = _drawingXml(anchorStartRow, anchorEndRow);
      _reemplazarArchivo(
          archive, 'xl/drawings/drawing1.xml', utf8.encode(drawingXml));

      // drawing1.xml.rels
      final drawingRels =
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rIdChart1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart" Target="../charts/chart1.xml"/>'
          '</Relationships>';
      _reemplazarArchivo(archive, 'xl/drawings/_rels/drawing1.xml.rels',
          utf8.encode(drawingRels));

      // chart1.xml
      final sheetName = 'Resumen Propietarios';
      final chartXml = _chartXml(
        sheetName: sheetName,
        headerRow: chartHeaderRow,
        firstDataRow: chartFirstDataRow,
        lastDataRow: chartLastDataRow,
      );
      _reemplazarArchivo(
          archive, 'xl/charts/chart1.xml', utf8.encode(chartXml));

      // Content_Types.xml: agregar overrides para drawing y chart
      final ctFile = archive.files.firstWhere(
        (f) => f.name == '[Content_Types].xml',
        orElse: () => ArchiveFile('', 0, []),
      );
      if (ctFile.name.isNotEmpty) {
        String ct = utf8.decode(ctFile.content as List<int>);
        if (!ct.contains('drawing1.xml')) {
          ct = ct.replaceFirst(
            '</Types>',
            '<Override PartName="/xl/drawings/drawing1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/>'
                '<Override PartName="/xl/charts/chart1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawingml.chart+xml"/>'
                '</Types>',
          );
        }
        _reemplazarArchivo(archive, '[Content_Types].xml', utf8.encode(ct));
      }
    }

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

  static String _drawingXml(int startRow, int endRow) {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<xdr:twoCellAnchor editAs="oneCell">'
        '<xdr:from><xdr:col>7</xdr:col><xdr:colOff>0</xdr:colOff>'
        '<xdr:row>$startRow</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from>'
        '<xdr:to><xdr:col>15</xdr:col><xdr:colOff>0</xdr:colOff>'
        '<xdr:row>$endRow</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:to>'
        '<xdr:graphicFrame macro="">'
        '<xdr:nvGraphicFramePr>'
        '<xdr:cNvPr id="2" name="Chart 1"/>'
        '<xdr:cNvGraphicFramePr/>'
        '</xdr:nvGraphicFramePr>'
        '<xdr:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></xdr:xfrm>'
        '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart">'
        '<c:chart xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'r:id="rIdChart1"/>'
        '</a:graphicData></a:graphic>'
        '</xdr:graphicFrame>'
        '<xdr:clientData/>'
        '</xdr:twoCellAnchor>'
        '</xdr:wsDr>';
  }

  static String _chartXml({
    required String sheetName,
    required int headerRow,
    required int firstDataRow,
    required int lastDataRow,
  }) {
    // Escape nombre de hoja para referencias
    final sheetRef = sheetName.contains(' ') ? "'$sheetName'" : sheetName;

    // Rango de categorías: columna A, filas firstDataRow..lastDataRow
    final catRef =
        '$sheetRef!\$A\$${firstDataRow + 1}:\$A\$${lastDataRow + 1}';
    // Emitido: columna B
    final emiRef =
        '$sheetRef!\$B\$${firstDataRow + 1}:\$B\$${lastDataRow + 1}';
    // Cobrado: columna C
    final cobRef =
        '$sheetRef!\$C\$${firstDataRow + 1}:\$C\$${lastDataRow + 1}';

    final count = lastDataRow - firstDataRow + 1;

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<c:chart>'
        '<c:title>'
        '<c:tx><c:rich>'
        '<a:bodyPr rot="0" spcFirstLastPara="1" vertOverflow="ellipsis" wrap="square" anchor="ctr" anchorCtr="1"/>'
        '<a:lstStyle/>'
        '<a:p><a:pPr><a:defRPr sz="1400" b="1"><a:solidFill><a:srgbClr val="C2185B"/></a:solidFill></a:defRPr></a:pPr>'
        '<a:r><a:rPr lang="es-AR" sz="1400" b="1"><a:solidFill><a:srgbClr val="C2185B"/></a:solidFill></a:rPr>'
        '<a:t>Ingresos por mes</a:t></a:r></a:p>'
        '</c:rich></c:tx>'
        '<c:overlay val="0"/>'
        '</c:title>'
        '<c:autoTitleDeleted val="0"/>'
        '<c:plotArea>'
        '<c:layout/>'
        '<c:barChart>'
        '<c:barDir val="col"/>'
        '<c:grouping val="clustered"/>'
        '<c:varyColors val="0"/>'
        // Serie Emitido
        '<c:ser>'
        '<c:idx val="0"/>'
        '<c:order val="0"/>'
        '<c:tx><c:v>Emitido</c:v></c:tx>'
        '<c:spPr><a:solidFill><a:srgbClr val="E65100"/></a:solidFill></c:spPr>'
        '<c:cat><c:strRef><c:f>$catRef</c:f><c:strCache><c:ptCount val="$count"/></c:strCache></c:strRef></c:cat>'
        '<c:val><c:numRef><c:f>$emiRef</c:f><c:numCache><c:formatCode>General</c:formatCode><c:ptCount val="$count"/></c:numCache></c:numRef></c:val>'
        '</c:ser>'
        // Serie Cobrado
        '<c:ser>'
        '<c:idx val="1"/>'
        '<c:order val="1"/>'
        '<c:tx><c:v>Cobrado</c:v></c:tx>'
        '<c:spPr><a:solidFill><a:srgbClr val="2E7D32"/></a:solidFill></c:spPr>'
        '<c:cat><c:strRef><c:f>$catRef</c:f><c:strCache><c:ptCount val="$count"/></c:strCache></c:strRef></c:cat>'
        '<c:val><c:numRef><c:f>$cobRef</c:f><c:numCache><c:formatCode>General</c:formatCode><c:ptCount val="$count"/></c:numCache></c:numRef></c:val>'
        '</c:ser>'
        '<c:gapWidth val="100"/>'
        '<c:axId val="1"/>'
        '<c:axId val="2"/>'
        '</c:barChart>'
        '<c:catAx>'
        '<c:axId val="1"/>'
        '<c:scaling><c:orientation val="minMax"/></c:scaling>'
        '<c:delete val="0"/>'
        '<c:axPos val="b"/>'
        '<c:crossAx val="2"/>'
        '</c:catAx>'
        '<c:valAx>'
        '<c:axId val="2"/>'
        '<c:scaling><c:orientation val="minMax"/></c:scaling>'
        '<c:delete val="0"/>'
        '<c:axPos val="l"/>'
        '<c:crossAx val="1"/>'
        '</c:valAx>'
        '</c:plotArea>'
        '<c:legend>'
        '<c:legendPos val="b"/>'
        '<c:overlay val="0"/>'
        '</c:legend>'
        '<c:plotVisOnly val="1"/>'
        '<c:dispBlanksAs val="gap"/>'
        '</c:chart>'
        '</c:chartSpace>';
  }
}

class _ResumenPropietario {
  final String propietario;
  final String inquilino;
  final String propiedad;
  double montoTotal = 0;
  double montoPendiente = 0;
  bool pagado = true;
  List<String> notas = [];
  String fechaEmision = '';

  _ResumenPropietario({
    required this.propietario,
    required this.inquilino,
    required this.propiedad,
  });
}

class _DatoMesGrafico {
  double emitido = 0;
  double cobrado = 0;
}
