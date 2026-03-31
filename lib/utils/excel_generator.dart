import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

class ExcelGenerator {
  // ── Colores del tema ───────────────────────────────────────────
  static final _headerFill = ExcelColor.fromHexString('#C2185B');
  static final _filaParFill = ExcelColor.fromHexString('#FFFFFF');
  static final _filaImparFill = ExcelColor.fromHexString('#FCF3F6');
  static final _totalFill = ExcelColor.fromHexString('#F5F5F5');
  static final _verdeFill = ExcelColor.fromHexString('#E8F5E9');
  static final _rojFill = ExcelColor.fromHexString('#FFEBEE');

  static final _fmtFecha = DateFormat('dd/MM/yyyy');
  static final _fmtMonto =
      NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 2);

  // ════════════════════════════════════════════════════════════════
  // REPORTE INQUILINO
  // Hojas: Resumen Inquilinos, Historial, Pagados, Pendientes
  // ════════════════════════════════════════════════════════════════

  static Future<List<int>> generarExcelInquilino({
    required List<Map<String, dynamic>> recibos,
  }) async {
    final excel = Excel.createExcel();

    _crearHojaResumenInquilino(excel, recibos);
    _crearHojaHistorial(excel, recibos, 'Historial de Recibos', null);
    _crearHojaHistorial(
        excel,
        recibos.where((r) => r['estado'] == 'pagado').toList(),
        'Recibos Pagados',
        'pagado');
    _crearHojaHistorial(
        excel,
        recibos
            .where((r) =>
                r['estado'] == 'pendiente' || r['estado'] == 'parcial')
            .toList(),
        'Recibos Pendientes',
        'pendiente');

    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');
    final bytes = excel.save();
    return bytes ?? [];
  }

  // ════════════════════════════════════════════════════════════════
  // REPORTE PROPIETARIO
  // Hojas: Resumen Propietarios, Historial, Pagados, Pendientes
  // ════════════════════════════════════════════════════════════════

  static Future<List<int>> generarExcelPropietario({
    required List<Map<String, dynamic>> resumenPropietarios,
    required List<Map<String, dynamic>> recibos,
  }) async {
    final excel = Excel.createExcel();

    _crearHojaResumenPropietario(excel, resumenPropietarios);
    _crearHojaHistorial(excel, recibos, 'Historial de Recibos', null);
    _crearHojaHistorial(
        excel,
        recibos.where((r) => r['estado'] == 'pagado').toList(),
        'Recibos Pagados',
        'pagado');
    _crearHojaHistorial(
        excel,
        recibos
            .where((r) =>
                r['estado'] == 'pendiente' || r['estado'] == 'parcial')
            .toList(),
        'Recibos Pendientes',
        'pendiente');

    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');
    final bytes = excel.save();
    return bytes ?? [];
  }

  // ════════════════════════════════════════════════════════════════
  // HOJA RESUMEN — INQUILINO
  // Inquilino | Alquiler Mes | Adm. 5% Inmob. | Total Propietario | Obs
  // ════════════════════════════════════════════════════════════════

  static void _crearHojaResumenInquilino(
      Excel excel, List<Map<String, dynamic>> recibos) {
    final sheet = excel['Resumen Inquilinos'];

    _celdaTitulo(sheet, 0, 0,
        'COPPOLA PAVESE INMOBILIARIA — REPORTE POR INQUILINO', 5);
    _celdaTitulo(sheet, 1, 0,
        'Generado: ${_fmtFecha.format(DateTime.now())}', 5);
    sheet.appendRow([TextCellValue('')]);

    final headers = [
      'Inquilino',
      'Alquiler Mes',
      'Adm. 5% Inmob.',
      'Total Propietario',
      'Observaciones',
    ];
    _agregarEncabezados(sheet, sheet.maxRows, headers);

    // Agrupar por inquilino
    final mapaInq = <String, _ResumenInquilino>{};
    for (final r in recibos) {
      final inq = r['inquilino_nombre'] as String? ?? 'Sin inquilino';
      if (!mapaInq.containsKey(inq)) {
        mapaInq[inq] = _ResumenInquilino();
      }
      mapaInq[inq]!.monto +=
          (r['monto_total'] as num?)?.toDouble() ?? 0.0;
      final nota = r['notas'] as String? ?? '';
      if (nota.isNotEmpty && !mapaInq[inq]!.notas.contains(nota)) {
        mapaInq[inq]!.notas.add(nota);
      }
    }

    double sumAlquiler = 0, sumAdm = 0, sumProp = 0;
    int i = 0;
    for (final entry in mapaInq.entries) {
      final monto = entry.value.monto;
      final adm = monto * 0.05;
      final prop = monto - adm;
      sumAlquiler += monto;
      sumAdm += adm;
      sumProp += prop;

      _agregarFilaDatos(sheet, [
        entry.key,
        _fmtMonto.format(monto),
        _fmtMonto.format(adm),
        _fmtMonto.format(prop),
        entry.value.notas.join('; '),
      ], i % 2 == 0 ? _filaParFill : _filaImparFill);
      i++;
    }

    _agregarFilaTotales(sheet, [
      'TOTALES',
      _fmtMonto.format(sumAlquiler),
      _fmtMonto.format(sumAdm),
      _fmtMonto.format(sumProp),
      '',
    ]);

    _ajustarAnchos(sheet, [28, 20, 20, 20, 35]);
  }

  // ════════════════════════════════════════════════════════════════
  // HOJA RESUMEN — PROPIETARIO
  // Propietario | Inquilino | Dirección | Localidad | Recibos |
  //   Facturado | Cobrado | Pendiente | Estado
  // ════════════════════════════════════════════════════════════════

  static void _crearHojaResumenPropietario(
      Excel excel, List<Map<String, dynamic>> datos) {
    final sheet = excel['Resumen Propietarios'];

    _celdaTitulo(sheet, 0, 0,
        'COPPOLA PAVESE INMOBILIARIA — REPORTE POR PROPIETARIO', 9);
    _celdaTitulo(sheet, 1, 0,
        'Generado: ${_fmtFecha.format(DateTime.now())}', 9);
    sheet.appendRow([TextCellValue('')]);

    final headers = [
      'Propietario',
      'Inquilino',
      'Dirección',
      'Localidad',
      'Total Recibos',
      'Total Facturado',
      'Total Cobrado',
      'Total Pendiente',
      'Estado',
    ];
    _agregarEncabezados(sheet, sheet.maxRows, headers);

    double sumFact = 0, sumCob = 0, sumPend = 0;

    for (int i = 0; i < datos.length; i++) {
      final d = datos[i];
      final totalFact = (d['total_monto'] as num?)?.toDouble() ?? 0.0;
      final totalCob = (d['total_cobrado'] as num?)?.toDouble() ?? 0.0;
      final totalPend = (d['total_pendiente'] as num?)?.toDouble() ?? 0.0;

      sumFact += totalFact;
      sumCob += totalCob;
      sumPend += totalPend;

      final estado = totalPend <= 0
          ? 'Al día'
          : totalCob > 0
              ? 'Parcial'
              : 'Deudor';

      _agregarFilaDatos(sheet, [
        d['propietario_nombre'] ?? '',
        d['inquilino_nombre'] ?? '',
        d['direccion'] ?? '',
        d['localidad'] ?? '',
        (d['total_recibos'] as num?)?.toInt() ?? 0,
        _fmtMonto.format(totalFact),
        _fmtMonto.format(totalCob),
        _fmtMonto.format(totalPend),
        estado,
      ], i % 2 == 0 ? _filaParFill : _filaImparFill);
    }

    _agregarFilaTotales(sheet, [
      'TOTALES',
      '',
      '',
      '',
      datos.length,
      _fmtMonto.format(sumFact),
      _fmtMonto.format(sumCob),
      _fmtMonto.format(sumPend),
      '',
    ]);

    _ajustarAnchos(sheet, [25, 20, 25, 15, 12, 18, 18, 18, 10]);
  }

  // ════════════════════════════════════════════════════════════════
  // HOJAS HISTORIAL / PAGADOS / PENDIENTES (compartida)
  // ════════════════════════════════════════════════════════════════

  static void _crearHojaHistorial(
    Excel excel,
    List<Map<String, dynamic>> datos,
    String nombreHoja,
    String? filtroEstado,
  ) {
    final sheet = excel[nombreHoja];

    String titulo =
        'COPPOLA PAVESE INMOBILIARIA — $nombreHoja'.toUpperCase();
    _celdaTitulo(sheet, 0, 0, titulo, 11);
    _celdaTitulo(
        sheet, 1, 0, 'Generado: ${_fmtFecha.format(DateTime.now())}', 11);
    sheet.appendRow([TextCellValue('')]);

    final headers = [
      'N° Recibo',
      'Fecha Emisión',
      'Vencimiento',
      'Propietario',
      'Inquilino',
      'Dirección',
      'Localidad',
      'Servicios',
      'Monto Total',
      'Monto Abonado',
      'Saldo',
      'Estado',
    ];
    _agregarEncabezados(sheet, sheet.maxRows, headers);

    double sumTotal = 0, sumAbonado = 0, sumSaldo = 0;

    for (int i = 0; i < datos.length; i++) {
      final d = datos[i];
      final mTotal = (d['monto_total'] as num?)?.toDouble() ?? 0.0;
      final mAbonado = (d['monto_abonado'] as num?)?.toDouble() ?? 0.0;
      final mSaldo = (d['saldo'] as num?)?.toDouble() ?? 0.0;
      final estado = d['estado'] as String? ?? '';

      sumTotal += mTotal;
      sumAbonado += mAbonado;
      sumSaldo += mSaldo;

      _agregarFilaHistorial(
        sheet,
        [
          'N° ${(d['numero_recibo'] as int? ?? 0).toString().padLeft(4, '0')}',
          _formatearFecha(d['fecha_emision'] as String? ?? ''),
          _formatearFecha(d['fecha_vencimiento'] as String? ?? ''),
          d['propietario_nombre'] ?? '',
          d['inquilino_nombre'] ?? '',
          d['direccion'] ?? '',
          d['localidad'] ?? '',
          d['servicios_descripcion'] ?? '',
          _fmtMonto.format(mTotal),
          _fmtMonto.format(mAbonado),
          _fmtMonto.format(mSaldo),
          _labelEstado(estado),
        ],
        i % 2 == 0 ? _filaParFill : _filaImparFill,
        estado,
      );
    }

    _agregarFilaTotales(sheet, [
      'TOTALES', '', '', '', '', '', '', '',
      _fmtMonto.format(sumTotal),
      _fmtMonto.format(sumAbonado),
      _fmtMonto.format(sumSaldo),
      '',
    ]);

    _ajustarAnchos(
        sheet, [12, 14, 14, 22, 20, 25, 15, 30, 18, 18, 18, 12]);
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
      fontSize: 12,
      fontColorHex: ExcelColor.fromHexString('#C2185B'),
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
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: _headerFill,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        textWrapping: TextWrapping.WrapText,
        leftBorder: Border(
            borderStyle: BorderStyle.Thin,
            borderColorHex: ExcelColor.fromHexString('#880E4F')),
        rightBorder: Border(
            borderStyle: BorderStyle.Thin,
            borderColorHex: ExcelColor.fromHexString('#880E4F')),
      );
    }
  }

  static void _agregarFilaDatos(
      Sheet sheet, List<dynamic> valores, ExcelColor fill) {
    final fila = sheet.maxRows;
    sheet.appendRow(valores.map((v) => _toCell(v)).toList());
    for (int c = 0; c < valores.length; c++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: fila));
      cell.cellStyle = CellStyle(
        fontSize: 10,
        backgroundColorHex: fill,
        leftBorder: Border(
            borderStyle: BorderStyle.Hair,
            borderColorHex: ExcelColor.fromHexString('#E0E0E0')),
        rightBorder: Border(
            borderStyle: BorderStyle.Hair,
            borderColorHex: ExcelColor.fromHexString('#E0E0E0')),
        bottomBorder: Border(
            borderStyle: BorderStyle.Hair,
            borderColorHex: ExcelColor.fromHexString('#E0E0E0')),
      );
    }
  }

  static void _agregarFilaHistorial(
      Sheet sheet, List<dynamic> valores, ExcelColor fill, String estado) {
    final fila = sheet.maxRows;
    sheet.appendRow(valores.map((v) => _toCell(v)).toList());

    ExcelColor? fillEstado;
    if (estado == 'pagado') fillEstado = _verdeFill;
    if (estado == 'pendiente') fillEstado = _rojFill;

    for (int c = 0; c < valores.length; c++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: fila));
      final bg = (c == 11 && fillEstado != null) ? fillEstado : fill;
      cell.cellStyle = CellStyle(
        fontSize: 10,
        backgroundColorHex: bg,
        bold: c == 11,
        leftBorder: Border(
            borderStyle: BorderStyle.Hair,
            borderColorHex: ExcelColor.fromHexString('#E0E0E0')),
        rightBorder: Border(
            borderStyle: BorderStyle.Hair,
            borderColorHex: ExcelColor.fromHexString('#E0E0E0')),
        bottomBorder: Border(
            borderStyle: BorderStyle.Hair,
            borderColorHex: ExcelColor.fromHexString('#E0E0E0')),
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
        fontSize: 10,
        backgroundColorHex: _totalFill,
        fontColorHex: ExcelColor.fromHexString('#C2185B'),
        topBorder: Border(
            borderStyle: BorderStyle.Medium,
            borderColorHex: ExcelColor.fromHexString('#C2185B')),
        bottomBorder: Border(
            borderStyle: BorderStyle.Medium,
            borderColorHex: ExcelColor.fromHexString('#C2185B')),
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

  static String _formatearFecha(String fecha) {
    if (fecha.isEmpty) return '—';
    try {
      return _fmtFecha.format(DateTime.parse(fecha));
    } catch (_) {
      return fecha;
    }
  }

  static String _labelEstado(String estado) {
    switch (estado) {
      case 'pagado':
        return 'Pagado';
      case 'parcial':
        return 'Parcial';
      case 'pendiente':
        return 'Pendiente';
      default:
        return estado;
    }
  }
}

class _ResumenInquilino {
  double monto = 0;
  List<String> notas = [];
}
