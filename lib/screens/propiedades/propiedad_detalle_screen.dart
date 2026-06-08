import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../database/database_helper.dart';
import '../../utils/ficha_html_generator.dart';
import '../../utils/snackbar_helper.dart';

class PropiedadDetalleScreen extends StatefulWidget {
  final int propiedadId;
  const PropiedadDetalleScreen({super.key, required this.propiedadId});

  @override
  State<PropiedadDetalleScreen> createState() => _PropiedadDetalleScreenState();
}

class _PropiedadDetalleScreenState extends State<PropiedadDetalleScreen> {
  final _db = DatabaseHelper();
  static const _magenta = Color(0xFFC2185B);

  Map<String, dynamic>? _propiedad;
  List<Map<String, dynamic>> _imagenes = [];
  bool _cargando = true;
  int _imagenActual = 0;

  // Ficha fields
  String _operacion = 'Alquiler';
  int _ambientes = 0;
  int _dormitorios = 0;
  int _banos = 0;
  int _cochera = 0;
  double _supTotal = 0;
  double _supCubierta = 0;
  String _antiguedad = '';
  List<String> _ambientesLista = [];
  List<String> _serviciosLista = [];
  String _descripcion = '';
  String _ubicacionFicha = '';

  final _supTotalCtrl = TextEditingController();
  final _supCubiertaCtrl = TextEditingController();
  final _antiguedadCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _ubicacionCtrl = TextEditingController();

  static const _ambientesOpciones = [
    'Cocina', 'Comedor', 'Cocina-Comedor', 'Living', 'Living-Comedor',
    'Lavadero', 'Patio', 'Balcón', 'Terraza', 'Quincho',
    'Pileta', 'Jardín', 'Hall', 'Escritorio', 'Vestidor',
    'Toilette', 'Galería', 'Sótano', 'Altillo', 'Depósito',
  ];

  static const _serviciosOpciones = [
    'Electricidad', 'Agua corriente', 'Gas natural', 'Gas envasado',
    'Cloacas', 'Internet', 'Cable', 'Teléfono',
    'Pavimento', 'Alumbrado público',
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _supTotalCtrl.dispose();
    _supCubiertaCtrl.dispose();
    _antiguedadCtrl.dispose();
    _descripcionCtrl.dispose();
    _ubicacionCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final prop = await _db.obtenerPropiedadPorId(widget.propiedadId);
    final imgs = await _db.obtenerImagenesPropiedad(widget.propiedadId);
    final ficha = await _db.obtenerFicha(widget.propiedadId);

    if (ficha != null) {
      _operacion = ficha['operacion'] as String? ?? 'Alquiler';
      _ambientes = ficha['ambientes'] as int? ?? 0;
      _dormitorios = ficha['dormitorios'] as int? ?? 0;
      _banos = ficha['banos'] as int? ?? 0;
      _cochera = ficha['cochera'] as int? ?? 0;
      _supTotal = (ficha['superficie_total'] as num?)?.toDouble() ?? 0;
      _supCubierta = (ficha['superficie_cubierta'] as num?)?.toDouble() ?? 0;
      _antiguedad = ficha['antiguedad'] as String? ?? '';
      _descripcion = ficha['descripcion'] as String? ?? '';
      _ubicacionFicha = ficha['ubicacion_ficha'] as String? ?? '';
      try {
        _ambientesLista = List<String>.from(jsonDecode(ficha['ambientes_lista'] as String? ?? '[]'));
      } catch (_) { _ambientesLista = []; }
      try {
        _serviciosLista = List<String>.from(jsonDecode(ficha['servicios_lista'] as String? ?? '[]'));
      } catch (_) { _serviciosLista = []; }
    }

    _supTotalCtrl.text = _supTotal > 0 ? _supTotal.toStringAsFixed(0) : '';
    _supCubiertaCtrl.text = _supCubierta > 0 ? _supCubierta.toStringAsFixed(0) : '';
    _antiguedadCtrl.text = _antiguedad;
    _descripcionCtrl.text = _descripcion;
    _ubicacionCtrl.text = _ubicacionFicha;

    setState(() {
      _propiedad = prop;
      _imagenes = imgs;
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    _supTotal = double.tryParse(_supTotalCtrl.text) ?? 0;
    _supCubierta = double.tryParse(_supCubiertaCtrl.text) ?? 0;
    _antiguedad = _antiguedadCtrl.text.trim();
    _descripcion = _descripcionCtrl.text.trim();
    _ubicacionFicha = _ubicacionCtrl.text.trim();

    await _db.upsertFicha(widget.propiedadId, {
      'operacion': _operacion,
      'ambientes': _ambientes,
      'dormitorios': _dormitorios,
      'banos': _banos,
      'cochera': _cochera,
      'superficie_total': _supTotal,
      'superficie_cubierta': _supCubierta,
      'antiguedad': _antiguedad,
      'ambientes_lista': jsonEncode(_ambientesLista),
      'servicios_lista': jsonEncode(_serviciosLista),
      'descripcion': _descripcion,
      'ubicacion_ficha': _ubicacionFicha,
    });

    if (mounted) {
      mostrarNotificacion(context,
          texto: 'Ficha guardada',
          color: const Color(0xFF2E7D32));
    }
  }

  // ── Imágenes ─────────────────────────────────────────────────

  Future<Directory> _dirImagenes() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'CoppolaPavese', 'imagenes', '${widget.propiedadId}'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _agregarImagenes() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final dir = await _dirImagenes();
    final orden = _imagenes.length;

    for (int i = 0; i < result.files.length; i++) {
      final file = result.files[i];
      if (file.path == null) continue;
      final ext = p.extension(file.path!);
      final nombre = 'img_${DateTime.now().millisecondsSinceEpoch}_$i$ext';
      final destino = p.join(dir.path, nombre);
      await File(file.path!).copy(destino);
      await _db.insertarImagenPropiedad({
        'propiedad_id': widget.propiedadId,
        'ruta': destino,
        'orden': orden + i,
      });
    }
    await _cargar();
  }

  Future<void> _eliminarImagen(int id, String ruta) async {
    await _db.eliminarImagenPropiedad(id);
    try { await File(ruta).delete(); } catch (_) {}
    await _cargar();
    if (_imagenActual >= _imagenes.length && _imagenes.isNotEmpty) {
      _imagenActual = _imagenes.length - 1;
    }
  }

  // ── Generar HTML ─────────────────────────────────────────────

  Future<void> _generarHtml() async {
    await _guardar();
    try {
      final ficha = await _db.obtenerFicha(widget.propiedadId);

      // Logo path
      String? logoPath;
      try {
        final logoAsset = await DefaultAssetBundle.of(context).load('assets/images/cp.png');
        final docs = await getApplicationDocumentsDirectory();
        final logoFile = File(p.join(docs.path, 'CoppolaPavese', 'cp_logo.png'));
        if (!await logoFile.exists()) {
          await logoFile.parent.create(recursive: true);
          await logoFile.writeAsBytes(logoAsset.buffer.asUint8List());
        }
        logoPath = logoFile.path;
      } catch (_) {}

      final html = await FichaHtmlGenerator.generar(
        propiedad: _propiedad!,
        ficha: ficha ?? {},
        imagenes: _imagenes,
        logoPath: logoPath,
      );

      final docs = await getApplicationDocumentsDirectory();
      final carpeta = Directory(p.join(docs.path, 'CoppolaPavese'));
      if (!await carpeta.exists()) await carpeta.create(recursive: true);

      final direccion = (_propiedad?['direccion'] as String? ?? 'propiedad')
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .trim()
          .replaceAll(' ', '_');
      final nombre = 'Ficha_$direccion.html';
      final archivo = File(p.join(carpeta.path, nombre));
      await archivo.writeAsString(html);

      if (mounted) {
        mostrarNotificacion(context,
            texto: 'Ficha guardada: ${archivo.path}',
            color: const Color(0xFF2E7D32),
            action: SnackBarAction(
              label: 'ABRIR',
              textColor: Colors.white,
              onPressed: () {
                if (Platform.isWindows) {
                  Process.run('explorer', [archivo.path]);
                }
              },
            ));
      }
    } catch (e) {
      if (mounted) {
        mostrarNotificacion(context,
            texto: 'Error al generar ficha: $e',
            color: const Color(0xFFC62828));
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ficha de Propiedad')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final direccion = _propiedad?['direccion'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(direccion, style: const TextStyle(fontSize: 15)),
        backgroundColor: _magenta,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _guardar,
            tooltip: 'Guardar ficha',
          ),
          IconButton(
            icon: const Icon(Icons.language_outlined),
            onPressed: _generarHtml,
            tooltip: 'Generar Ficha HTML',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Imágenes ──
          _seccionImagenes(),
          const SizedBox(height: 16),

          // ── Operación y precio ──
          _seccionOperacion(),
          const SizedBox(height: 12),

          // ── Especificaciones ──
          _seccionEspecificaciones(),
          const SizedBox(height: 12),

          // ── Ambientes ──
          _seccionChips('Ambientes', _ambientesOpciones, _ambientesLista,
              (lista) => setState(() => _ambientesLista = lista)),
          const SizedBox(height: 12),

          // ── Servicios ──
          _seccionChips('Servicios', _serviciosOpciones, _serviciosLista,
              (lista) => setState(() => _serviciosLista = lista)),
          const SizedBox(height: 12),

          // ── Descripción ──
          _seccionDescripcion(),
          const SizedBox(height: 20),

          // ── Botones ──
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: _guardar,
                    icon: const Icon(Icons.save, size: 20),
                    label: const Text('Guardar Ficha'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _magenta,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: _generarHtml,
                    icon: const Icon(Icons.language, size: 20),
                    label: const Text('Generar Ficha'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _magenta,
                      side: const BorderSide(color: _magenta),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // SECCIONES UI
  // ════════════════════════════════════════════════════════════════

  Widget _seccionImagenes() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_library_outlined, color: _magenta, size: 18),
                const SizedBox(width: 8),
                const Text('Fotos de la Propiedad',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _magenta)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _agregarImagenes,
                  icon: const Icon(Icons.add_photo_alternate, size: 18),
                  label: const Text('Agregar', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: _magenta),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_imagenes.isEmpty)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text('Agregá fotos de la propiedad',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ],
                ),
              )
            else
              Column(
                children: [
                  // Imagen principal (carousel)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          height: 280,
                          width: double.infinity,
                          child: PageView.builder(
                            itemCount: _imagenes.length,
                            onPageChanged: (i) => setState(() => _imagenActual = i),
                            itemBuilder: (_, i) {
                              final ruta = _imagenes[i]['ruta'] as String;
                              return Image.file(
                                File(ruta),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFFEEEEEE),
                                  child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      // Contador
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_imagenActual + 1} / ${_imagenes.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                      // Borrar imagen
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            final img = _imagenes[_imagenActual];
                            _eliminarImagen(img['id'] as int, img['ruta'] as String);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.delete, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Miniaturas
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _imagenes.length,
                      itemBuilder: (_, i) {
                        final ruta = _imagenes[i]['ruta'] as String;
                        final seleccionada = i == _imagenActual;
                        return GestureDetector(
                          onTap: () => setState(() => _imagenActual = i),
                          child: Container(
                            width: 70,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: seleccionada ? _magenta : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.file(File(ruta), fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      Container(color: const Color(0xFFEEEEEE))),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _seccionOperacion() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo('Operación y Ubicación', Icons.sell_outlined),
            const SizedBox(height: 12),
            Row(
              children: [
                // Operación
                SizedBox(
                  width: 260,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Alquiler', label: Text('Alquiler', style: TextStyle(fontSize: 12))),
                      ButtonSegment(value: 'Venta', label: Text('Venta', style: TextStyle(fontSize: 12))),
                    ],
                    selected: {_operacion},
                    onSelectionChanged: (v) => setState(() => _operacion = v.first),
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((states) =>
                          states.contains(WidgetState.selected) ? _magenta : null),
                      foregroundColor: WidgetStateProperty.resolveWith((states) =>
                          states.contains(WidgetState.selected) ? Colors.white : null),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Ubicación para la ficha PDF
                Expanded(
                  child: TextFormField(
                    controller: _ubicacionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ubicación (barra rosa del PDF)',
                      hintText: 'Ej: Vivienda en Centro',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionEspecificaciones() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo('Especificaciones', Icons.straighten_outlined),
            const SizedBox(height: 12),
            Row(
              children: [
                _campoNumero('Ambientes', _ambientes, (v) => setState(() => _ambientes = v)),
                const SizedBox(width: 8),
                _campoNumero('Dormitorios', _dormitorios, (v) => setState(() => _dormitorios = v)),
                const SizedBox(width: 8),
                _campoNumero('Baños', _banos, (v) => setState(() => _banos = v)),
                const SizedBox(width: 8),
                _campoNumero('Cocheras', _cochera, (v) => setState(() => _cochera = v)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _supTotalCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Sup. Total (m²)', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _supCubiertaCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Sup. Cubierta (m²)', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _antiguedadCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Antigüedad', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoNumero(String label, int valor, ValueChanged<int> onChanged) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF757575))),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: valor > 0 ? () => onChanged(valor - 1) : null,
                  child: Icon(Icons.remove_circle_outline, size: 20,
                      color: valor > 0 ? _magenta : Colors.grey.shade300),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('$valor',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                InkWell(
                  onTap: () => onChanged(valor + 1),
                  child: const Icon(Icons.add_circle_outline, size: 20, color: _magenta),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionChips(String titulo, List<String> opciones,
      List<String> seleccionados, ValueChanged<List<String>> onChanged) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo(titulo, titulo == 'Ambientes' ? Icons.room_outlined : Icons.electrical_services_outlined),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: opciones.map((op) {
                final activo = seleccionados.contains(op);
                return FilterChip(
                  label: Text(op, style: TextStyle(fontSize: 11,
                      color: activo ? Colors.white : const Color(0xFF616161))),
                  selected: activo,
                  selectedColor: _magenta,
                  checkmarkColor: Colors.white,
                  backgroundColor: const Color(0xFFF5F5F5),
                  side: BorderSide(color: activo ? _magenta : const Color(0xFFE0E0E0)),
                  onSelected: (sel) {
                    final nueva = List<String>.from(seleccionados);
                    sel ? nueva.add(op) : nueva.remove(op);
                    onChanged(nueva);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionDescripcion() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo('Descripción', Icons.notes_outlined),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descripcionCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Descripción de la propiedad...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titulo(String texto, IconData icono) {
    return Row(
      children: [
        Icon(icono, size: 17, color: _magenta),
        const SizedBox(width: 8),
        Text(texto, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF212121))),
      ],
    );
  }
}
