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
  // MÉTODO PRINCIPAL
  // ════════════════════════════════════════════════════════════════

  static Future<List<int>> generarExcel({
    required List<Map<String, dynamic>> resumenPropietarios,
    required List<Map<String, dynamic>> todosLosRecibos,
  }) async {
    final excel = Excel.createExcel();

    // Excel crea una hoja por defecto llamada "Sheet1" — la eliminamos al final
    _crearHojaResumen(excel, resumenPropietarios);
    _crearHojaHistorial(excel, todosLosRecibos, 'Historial de Recibos', null);
    _crearHojaHistorial(
        excel,
        todosLosRecibos.where((r) => r['estado'] == 'pagado').toList(),
        'Recibos Pagados',
        'pagado');
    _crearHojaHistorial(
        excel,
        todosLosRecibos
            .where((r) =>
                r['estado'] == 'pendiente' || r['estado'] == 'parcial')
            .toList(),
        'Recibos Pendientes',
        'pendiente');

    // Eliminar hoja por defecto si existe
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.save();
    return bytes ?? [];
  }

  // ════════════════════════════════════════════════════════════════
  // HOJA 1 — RESUMEN GENERAL
  // ════════════════════════════════════════════════════════════════

  static void _crearHojaResumen(
      Excel excel, List<Map<String, dynamic>> datos) {
    final sheet = excel['Resumen General'];

    // Título principal
    _celdaTitulo(sheet, 0, 0,
        'COPPOLA PAVESE INMOBILIARIA — RESUMEN GENERAL', 8);
    _celdaTitulo(sheet, 1, 0,
        'Generado: ${_fmtFecha.format(DateTime.now())}', 8);
    sheet.appendRow([TextCellValue('')]);

    // Encabezados
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
    final fila3 = sheet.maxRows;
    _agregarEncabezados(sheet, fila3, headers);

    // Datos
    double sumFacturado = 0;
    double sumCobrado = 0;
    double sumPendiente = 0;

    for (int i = 0; i < datos.length; i++) {
      final d = datos[i];
      final totalPend =
          (d['total_pendiente'] as num?)?.toDouble() ?? 0.0;
      final totalCob =
          (d['total_cobrado'] as num?)?.toDouble() ?? 0.0;
      final totalFact =
          (d['total_monto'] as num?)?.toDouble() ?? 0.0;

      sumFacturado += totalFact;
      sumCobrado += totalCob;
      sumPendiente += totalPend;

      final estado = totalPend <= 0
          ? 'Al día'
          : totalCob > 0
              ? 'Parcial'
              : 'Deudor';
      final fillFila = i % 2 == 0 ? _filaParFill : _filaImparFill;

      _agregarFilaResumen(sheet, [
        d['propietario_nombre'] ?? '',
        d['inquilino_nombre'] ?? '',
        d['direccion'] ?? '',
        d['localidad'] ?? '',
        (d['total_recibos'] as num?)?.toInt() ?? 0,
        _fmtMonto.format(totalFact),
        _fmtMonto.format(totalCob),
        _fmtMonto.format(totalPend),
        estado,
      ], fillFila, i % 2 == 0);
    }

    // Fila de totales
    _agregarFilaTotales(sheet, [
      'TOTALES',
      '',
      '',
      '',
      datos.length,
      _fmtMonto.format(sumFacturado),
      _fmtMonto.format(sumCobrado),
      _fmtMonto.format(sumPendiente),
      '',
    ]);

    // Anchos de columna
    _ajustarAnchos(sheet, [25, 20, 25, 15, 12, 18, 18, 18, 10]);
  }

  // ════════════════════════════════════════════════════════════════
  // HOJAS 2, 3, 4 — HISTORIAL / PAGADOS / PENDIENTES
  // ════════════════════════════════════════════════════════════════

  static void _crearHojaHistorial(
    Excel excel,
    List<Map<String, dynamic>> datos,
    String nombreHoja,
    String? filtroEstado,
  ) {
    final sheet = excel[nombreHoja];

    // Título
    String titulo = 'COPPOLA PAVESE INMOBILIARIA — $nombreHoja'.toUpperCase();
    _celdaTitulo(sheet, 0, 0, titulo, 11);
    _celdaTitulo(sheet, 1, 0,
        'Generado: ${_fmtFecha.format(DateTime.now())}', 11);
    sheet.appendRow([TextCellValue('')]);

    // Encabezados
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
    final filaEnc = sheet.maxRows;
    _agregarEncabezados(sheet, filaEnc, headers);

    // Datos
    double sumTotal = 0;
    double sumAbonado = 0;
    double sumSaldo = 0;

    for (int i = 0; i < datos.length; i++) {
      final d = datos[i];
      final mTotal = (d['monto_total'] as num?)?.toDouble() ?? 0.0;
      final mAbonado = (d['monto_abonado'] as num?)?.toDouble() ?? 0.0;
      final mSaldo = (d['saldo'] as num?)?.toDouble() ?? 0.0;
      final estado = d['estado'] as String? ?? '';

      sumTotal += mTotal;
      sumAbonado += mAbonado;
      sumSaldo += mSaldo;

      final fillFila = i % 2 == 0 ? _filaParFill : _filaImparFill;

      _agregarFilaHistorial(sheet, [
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
      ], fillFila, estado);
    }

    // Fila de totales
    _agregarFilaTotales(sheet, [
      'TOTALES',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      _fmtMonto.format(sumTotal),
      _fmtMonto.format(sumAbonado),
      _fmtMonto.format(sumSaldo),
      '',
    ]);

    // Anchos de columna
    _ajustarAnchos(
        sheet, [12, 14, 14, 22, 20, 25, 15, 30, 18, 18, 18, 12]);
  }

  // ════════════════════════════════════════════════════════════════
  // HELPERS DE FORMATO
  // ════════════════════════════════════════════════════════════════

  static void _celdaTitulo(
      Sheet sheet, int fila, int col, String texto, int span) {
    // Asegurar que haya suficientes filas
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

  static void _agregarFilaResumen(
      Sheet sheet, List<dynamic> valores, ExcelColor fill, bool esPar) {
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
    if (estado == 'pagado') {
      fillEstado = _verdeFill;
    } else if (estado == 'pendiente') {
      fillEstado = _rojFill;
    }

    for (int c = 0; c < valores.length; c++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: fila));
      // Columna de estado con color especial
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

  static void _agregarFilaTotales(
      Sheet sheet, List<dynamic> valores) {
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
