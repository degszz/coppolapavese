import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../models/recibo_model.dart';
import '../../models/servicio_item_model.dart';
import '../../utils/pdf_generator.dart';
import '../../utils/numero_a_letras.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/print_queue_dialog.dart';

/// Recibo en blanco editable — el usuario completa los campos con teclado
/// y luego imprime/comparte el PDF.
class ReciboBlancoScreen extends StatefulWidget {
  final int numeroRecibo;
  final String? usuario;

  const ReciboBlancoScreen({
    super.key,
    required this.numeroRecibo,
    this.usuario,
  });

  @override
  State<ReciboBlancoScreen> createState() => _ReciboBlancoScreenState();
}

class _ReciboBlancoScreenState extends State<ReciboBlancoScreen> {
  static const _navy = Color(0xFF1A3A5C);
  static const _dark = Color(0xFF212121);
  static const _gray = Color(0xFF757575);
  static const _pink = Color(0xFFC2185B);

  // ── Campos editables ──────────────────────────────────────
  final _locadorCtrl    = TextEditingController();
  final _locatarioCtrl  = TextEditingController();
  final _domicilioCtrl  = TextEditingController();
  final _montoTotalCtrl = TextEditingController();
  final _notasCtrl      = TextEditingController();
  final _usuarioCtrl    = TextEditingController();
  DateTime _fechaEmision = DateTime.now();

  // 6 filas: 1 alquiler + 5 servicios
  late final List<_FilaBlanco> _filas;

  bool _generandoPdf = false;

  @override
  void initState() {
    super.initState();
    _usuarioCtrl.text = widget.usuario ?? '';
    _filas = List.generate(6, (i) => _FilaBlanco(
      hint: i == 0 ? 'Alquiler' : 'Servicio ${i}',
    ));
  }

  @override
  void dispose() {
    _locadorCtrl.dispose();
    _locatarioCtrl.dispose();
    _domicilioCtrl.dispose();
    _montoTotalCtrl.dispose();
    _notasCtrl.dispose();
    _usuarioCtrl.dispose();
    for (final f in _filas) { f.dispose(); }
    super.dispose();
  }

  double get _totalCalculado {
    double sum = 0;
    for (final f in _filas) {
      sum += double.tryParse(f.montoCtrl.text.replaceAll(',', '.')) ?? 0;
    }
    return sum;
  }

  /// Construye un ReciboModel con los datos ingresados
  ReciboModel _buildRecibo() {
    final servicios = <ServicioItemModel>[];
    for (final f in _filas) {
      final desc = f.descCtrl.text.trim();
      final monto = double.tryParse(f.montoCtrl.text.replaceAll(',', '.')) ?? 0;
      if (desc.isNotEmpty || monto > 0) {
        servicios.add(ServicioItemModel(
          descripcion: desc.isNotEmpty ? desc : '—',
          monto: monto,
          punitorios: 0,
          total: monto,
        ));
      }
    }
    // Si no se completó nada, agregar filas vacías para que aparezcan en el PDF
    if (servicios.isEmpty) {
      for (int i = 0; i < 6; i++) {
        servicios.add(ServicioItemModel(
          descripcion: '___________________________',
          monto: 0, punitorios: 0, total: 0,
        ));
      }
    }

    final total = _totalCalculado;
    final locador = _locadorCtrl.text.trim();
    final locatario = _locatarioCtrl.text.trim();
    final domicilio = _domicilioCtrl.text.trim();
    final esNeutro = locador.isEmpty && locatario.isEmpty && total == 0;

    return ReciboModel(
      numeroRecibo: widget.numeroRecibo,
      propietarioId: 0,
      fechaEmision: DateFormat('yyyy-MM-dd').format(_fechaEmision),
      montoTotal: total,
      montoAbonado: 0,
      saldo: total,
      estado: 'pendiente',
      usuario: _usuarioCtrl.text.trim(),
      notas: _notasCtrl.text.trim().isNotEmpty ? _notasCtrl.text.trim() : null,
      createdAt: DateTime.now().toIso8601String(),
      propietarioNombre: locador.isNotEmpty ? locador : null,
      inquilinoNombre: locatario.isNotEmpty ? locatario : null,
      direccion: domicilio.isNotEmpty ? domicilio : null,
      localidad: '',
      esNeutro: esNeutro,
      servicios: servicios,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final fmtPesos = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0, customPattern: '\u00A4#,##0');

    return Scaffold(
      appBar: AppBar(
        title: Text('Recibo en Blanco N° ${widget.numeroRecibo.toString().padLeft(4, '0')}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Imprimir / PDF',
            onPressed: _generandoPdf ? null : _imprimir,
          ),
          IconButton(
            icon: const Icon(Icons.chat_outlined),
            tooltip: 'Enviar por WhatsApp',
            onPressed: _generandoPdf ? null : _compartir,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Encabezado ────────────────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.asset('assets/images/cp_logo.png',
                                width: 150, height: 130, fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox(width: 150, height: 130)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('COPPOLA PAVESE Inmobiliaria',
                                      style: TextStyle(fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: _navy)),
                                  const SizedBox(height: 2),
                                  const Text('Blandengues 188 - San Miguel del Monte',
                                      style: TextStyle(fontSize: 10, color: _gray)),
                                  const Text('02226 546317 / 02271 412950',
                                      style: TextStyle(fontSize: 10, color: _gray)),
                                  const Text('coppolapavese@gmail.com',
                                      style: TextStyle(fontSize: 10, color: _gray)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _navy,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Text('RECIBO EN BLANCO',
                                      style: TextStyle(color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(height: 6),
                                Text('N° ${widget.numeroRecibo.toString().padLeft(4, '0')}',
                                    style: const TextStyle(fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _dark)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ── Fecha + Usuario ──────────────────────
                        Row(
                          children: [
                            // Fecha
                            SizedBox(
                              width: 160,
                              child: GestureDetector(
                                onTap: () async {
                                  final sel = await showDatePicker(
                                    context: context,
                                    initialDate: _fechaEmision,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                    builder: (ctx, child) => Theme(
                                      data: Theme.of(ctx).copyWith(
                                        colorScheme: const ColorScheme.light(
                                            primary: _pink),
                                      ),
                                      child: child!,
                                    ),
                                  );
                                  if (sel != null) setState(() => _fechaEmision = sel);
                                },
                                child: _campoConLabel('Fecha',
                                    fmt.format(_fechaEmision),
                                    icon: Icons.calendar_today),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Usuario
                            Expanded(
                              child: _inputConLabel('Responsable', _usuarioCtrl),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ── Locador / Locatario ──────────────────
                        Row(
                          children: [
                            Expanded(
                              child: _inputConLabel('LOCADOR', _locadorCtrl,
                                  hint: 'Nombre del propietario'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _inputConLabel('LOCATARIO', _locatarioCtrl,
                                  hint: 'Nombre del inquilino'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ── Domicilio ────────────────────────────
                        _inputConLabel('DOMICILIO', _domicilioCtrl,
                            hint: 'Dirección de la propiedad'),
                        const SizedBox(height: 16),

                        // ── Tabla de servicios editable ──────────
                        const Text('DETALLE DE SERVICIOS',
                            style: TextStyle(fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _pink,
                                letterSpacing: 1)),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: _dark, width: 1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            children: [
                              // Header
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(3)),
                                ),
                                child: const Row(
                                  children: [
                                    Expanded(flex: 4,
                                        child: Text('Descripción',
                                            style: TextStyle(fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: _dark))),
                                    SizedBox(width: 120,
                                        child: Text('Monto',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: _dark))),
                                  ],
                                ),
                              ),
                              // Filas editables
                              ..._filas.asMap().entries.map((e) {
                                final idx = e.key;
                                final f = e.value;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: idx.isEven
                                        ? Colors.white
                                        : const Color(0xFFFAFAFA),
                                    border: idx > 0
                                        ? const Border(top: BorderSide(
                                            color: Color(0xFFE0E0E0),
                                            width: 0.5))
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      // Descripción
                                      Expanded(
                                        flex: 4,
                                        child: TextField(
                                          controller: f.descCtrl,
                                          style: const TextStyle(fontSize: 12),
                                          decoration: InputDecoration(
                                            hintText: f.hint,
                                            hintStyle: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFFBDBDBD)),
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 8),
                                          ),
                                        ),
                                      ),
                                      // Monto
                                      SizedBox(
                                        width: 120,
                                        child: TextField(
                                          controller: f.montoCtrl,
                                          keyboardType:
                                              const TextInputType
                                                  .numberWithOptions(
                                                  decimal: true),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(
                                                RegExp(r'[\d,.]')),
                                          ],
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold),
                                          decoration: const InputDecoration(
                                            prefixText: '\$ ',
                                            hintText: '0',
                                            hintStyle: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFFBDBDBD)),
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    vertical: 8),
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Total calculado ──────────────────────
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: 280,
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Monto a Abonar:',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _dark)),
                                Text(
                                  _totalCalculado > 0
                                      ? fmtPesos.format(_totalCalculado)
                                      : '\$0',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _dark),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Notas ────────────────────────────────
                        _inputConLabel('Notas (opcional)', _notasCtrl,
                            hint: 'Se imprimirá al pie del recibo...',
                            maxLines: 2),
                        const SizedBox(height: 10),

                        // ── Pie (empresa, igual que recibo tradicional) ──
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'COPPOLA PAVESE Inmobiliaria',
                            style: TextStyle(
                              fontSize: 9,
                              color: _gray,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Botones ──────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    _generandoPdf ? null : _imprimir,
                                icon: const Icon(Icons.print_outlined),
                                label: const Text('Imprimir / PDF'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _pink,
                                  side: const BorderSide(color: _pink),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    _generandoPdf ? null : _compartir,
                                icon: const Icon(Icons.chat_outlined),
                                label: const Text('WhatsApp'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_generandoPdf)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: _pink),
                        SizedBox(height: 16),
                        Text('Generando PDF...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Helpers de UI ──────────────────────────────────────────────

  Widget _inputConLabel(String label, TextEditingController ctrl,
      {String? hint, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _dark)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _campoConLabel(String label, String valor, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFBDBDBD)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 9, color: _gray)),
          const SizedBox(height: 2),
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: _pink),
                const SizedBox(width: 4),
              ],
              Text(valor,
                  style: const TextStyle(fontSize: 12, color: _dark)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Nombre de archivo: Recibo_0001_Juan_Perez_blanco ──────────
  String _nombrePdf() {
    final nro = widget.numeroRecibo.toString().padLeft(4, '0');
    final raw = _locatarioCtrl.text.trim();
    if (raw.isEmpty) return 'Recibo_${nro}_blanco';
    final sanitizado = raw
        .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i')
        .replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('ü', 'u')
        .replaceAll('Á', 'A').replaceAll('É', 'E').replaceAll('Í', 'I')
        .replaceAll('Ó', 'O').replaceAll('Ú', 'U').replaceAll('Ü', 'U')
        .replaceAll('ñ', 'n').replaceAll('Ñ', 'N')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return 'Recibo_${nro}_${sanitizado}_blanco';
  }

  // ── Acciones ───────────────────────────────────────────────────

  Future<void> _imprimir() async {
    setState(() => _generandoPdf = true);
    try {
      final recibo = _buildRecibo();
      final pdfBytes = await PdfGenerator.generarRecibo(recibo);
      final enviado = await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(pdfBytes),
        name: _nombrePdf(),
      );
      if (enviado && mounted) {
        mostrarNotificacion(context,
            texto: 'Trabajo enviado a la impresora',
            color: const Color(0xFF2E7D32),
            action: SnackBarAction(
              label: 'VER COLA',
              textColor: Colors.white,
              onPressed: () => showPrintQueueDialog(context),
            ));
      }
    } catch (e) {
      if (mounted) {
        mostrarNotificacion(context,
            texto: 'Error al generar PDF: $e',
            color: const Color(0xFFC62828));
      }
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }

  Future<void> _compartir() async {
    setState(() => _generandoPdf = true);
    try {
      final recibo = _buildRecibo();
      final pdfBytes = await PdfGenerator.generarRecibo(recibo);

      final dir = await getTemporaryDirectory();
      final nombre = '${_nombrePdf()}.pdf';
      final archivo = File('${dir.path}${Platform.pathSeparator}$nombre');
      await archivo.writeAsBytes(pdfBytes);

      // Texto con datos de la inmobiliaria
      final nroRecibo = widget.numeroRecibo.toString().padLeft(4, '0');
      final locador = _locadorCtrl.text.trim();
      final locatario = _locatarioCtrl.text.trim();
      final domicilio = _domicilioCtrl.text.trim();

      final mensaje = StringBuffer();
      mensaje.writeln('*COPPOLA PAVESE Inmobiliaria*');
      mensaje.writeln('Blandengues 188 - San Miguel del Monte');
      mensaje.writeln('Tel: 02226 546317 / 02271 412950');
      mensaje.writeln('');
      mensaje.writeln('*Recibo de Alquiler N° $nroRecibo*');
      if (locatario.isNotEmpty) mensaje.writeln('Inquilino: $locatario');
      if (locador.isNotEmpty) mensaje.writeln('Propietario: $locador');
      if (domicilio.isNotEmpty) mensaje.writeln('Domicilio: $domicilio');
      mensaje.writeln('');
      mensaje.writeln('Se adjunta el recibo en formato PDF.');

      // Compartir PDF + texto via menú nativo
      await Share.shareXFiles(
        [XFile(archivo.path)],
        text: mensaje.toString(),
      );
    } catch (e) {
      if (mounted) {
        mostrarNotificacion(context,
            texto: 'Error al compartir: $e',
            color: const Color(0xFFC62828));
      }
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }
}

// ── Modelo interno de fila ────────────────────────────────────────
class _FilaBlanco {
  final String hint;
  final descCtrl  = TextEditingController();
  final montoCtrl = TextEditingController();

  _FilaBlanco({required this.hint});

  void dispose() {
    descCtrl.dispose();
    montoCtrl.dispose();
  }
}
