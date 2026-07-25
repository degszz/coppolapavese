import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../database/database_helper.dart';
import '../../database/db_config.dart';
import '../../utils/video_slideshow_generator.dart';
import 'propiedad_detalle_screen.dart';

class PropiedadesListScreen extends StatefulWidget {
  const PropiedadesListScreen({super.key});

  @override
  State<PropiedadesListScreen> createState() => _PropiedadesListScreenState();

  /// Dialog reutilizable para crear propiedad desde cualquier pantalla.
  static Future<void> mostrarDialogNuevaPropiedad(BuildContext context) async {
    final db = DatabaseHelper();
    final propietarios = await db.obtenerPropietarios();
    final formKey = GlobalKey<FormState>();

    final carpetaCtrl   = TextEditingController();
    final direccionCtrl = TextEditingController();
    final localidadCtrl = TextEditingController();
    final barrioCtrl    = TextEditingController();

    String tipoSel = 'Vivienda';
    String estadoSel = 'Disponible';
    int? propietarioSel;

    const tipos = ['Vivienda','Departamento','Local','Terreno','Quinta','Oficina','Cochera','Otro'];
    const estados = ['Disponible','Alquilado','En venta','Vendido','Nulo'];
    const color = Color(0xFFC2185B);

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.apartment, color: color, size: 22),
                        const SizedBox(width: 8),
                        const Text('Nueva propiedad',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                            padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                      ]),
                      const SizedBox(height: 20),
                      TextFormField(controller: carpetaCtrl,
                          decoration: const InputDecoration(labelText: 'Carpeta / N° interno', isDense: true, border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: DropdownButtonFormField<String>(value: tipoSel,
                            decoration: const InputDecoration(labelText: 'Tipo', isDense: true, border: OutlineInputBorder()),
                            items: tipos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) => setS(() => tipoSel = v!))),
                        const SizedBox(width: 12),
                        Expanded(child: DropdownButtonFormField<String>(value: estadoSel,
                            decoration: const InputDecoration(labelText: 'Estado', isDense: true, border: OutlineInputBorder()),
                            items: estados.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) => setS(() => estadoSel = v!))),
                      ]),
                      const SizedBox(height: 12),
                      TextFormField(controller: direccionCtrl,
                          decoration: const InputDecoration(labelText: 'Dirección *', isDense: true, border: OutlineInputBorder()),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: TextFormField(controller: localidadCtrl,
                            decoration: const InputDecoration(labelText: 'Localidad', isDense: true, border: OutlineInputBorder()))),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(controller: barrioCtrl,
                            decoration: const InputDecoration(labelText: 'Barrio', isDense: true, border: OutlineInputBorder()))),
                      ]),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(value: propietarioSel,
                          decoration: const InputDecoration(labelText: 'Propietario', isDense: true, border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem<int?>(value: null,
                                child: Text('— Sin asignar —', style: TextStyle(color: Colors.grey))),
                            ...propietarios.map((p) => DropdownMenuItem<int?>(
                                value: p['id'] as int, child: Text(p['nombre'] as String? ?? '—'))),
                          ],
                          onChanged: (v) => setS(() => propietarioSel = v)),
                      const SizedBox(height: 24),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          icon: const Icon(Icons.save, size: 16),
                          label: const Text('Crear propiedad'),
                          style: FilledButton.styleFrom(backgroundColor: color),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            await db.insertarPropiedad({
                              'carpeta': carpetaCtrl.text.trim().isEmpty ? null : carpetaCtrl.text.trim(),
                              'tipo': tipoSel,
                              'estado': estadoSel,
                              'direccion': direccionCtrl.text.trim(),
                              'localidad': localidadCtrl.text.trim().isEmpty ? null : localidadCtrl.text.trim(),
                              'barrio': barrioCtrl.text.trim().isEmpty ? null : barrioCtrl.text.trim(),
                              'propietario_id': propietarioSel,
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PropiedadesListScreenState extends State<PropiedadesListScreen> {
  final _db = DatabaseHelper();

  List<Map<String, dynamic>> _propiedades = [];
  List<Map<String, dynamic>> _propiedadesFiltradas = [];
  List<Map<String, dynamic>> _propietarios = [];
  Map<int, String?> _primeraImagen = {}; // propiedadId → ruta primera imagen
  bool _cargando = true;
  final _busquedaCtrl = TextEditingController();
  Timer? _autoRefresh;
  String? _filtroOperacion;
  bool? _filtroFicha;

  static const _primaryColor = Color(0xFFC2185B);
  static const _tipos = [
    'Vivienda',
    'Departamento',
    'Local',
    'Terreno',
    'Quinta',
    'Oficina',
    'Cochera',
    'Otro',
  ];
  static const _estados = [
    'Disponible',
    'Alquilado',
    'En venta',
    'Vendido',
    'Nulo',
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
    _busquedaCtrl.addListener(_filtrar);
    _autoRefresh = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refrescoSilencioso(),
    );
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<Map<int, String?>> _cargarImagenes(List<Map<String, dynamic>> props) async {
    final mapa = <int, String?>{};
    for (final p in props) {
      final id = p['id'] as int;
      final imgs = await _db.obtenerImagenesPropiedad(id);
      mapa[id] = imgs.isNotEmpty ? imgs.first['ruta'] as String? : null;
    }
    return mapa;
  }

  Future<void> _refrescoSilencioso() async {
    try {
      final props = await _db.obtenerPropiedadesConFiltros(
          operacion: _filtroOperacion, tieneFicha: _filtroFicha);
      final propietarios = await _db.obtenerPropietarios();
      final imgs = await _cargarImagenes(props);
      if (mounted) {
        setState(() {
          _propiedades = props;
          _propietarios = propietarios;
          _primeraImagen = imgs;
          _filtrar();
        });
      }
    } catch (_) {}
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final props = await _db.obtenerPropiedadesConFiltros(
          operacion: _filtroOperacion, tieneFicha: _filtroFicha);
      final propietarios = await _db.obtenerPropietarios();
      final imgs = await _cargarImagenes(props);
      setState(() {
        _propiedades = props;
        _propiedadesFiltradas = props;
        _propietarios = propietarios;
        _primeraImagen = imgs;
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
    }
  }

  void _aplicarFiltro({String? operacion, bool? ficha}) {
    setState(() {
      _filtroOperacion = operacion;
      _filtroFicha = ficha;
    });
    _cargar();
  }

  Widget _labelTodas(String text,
      {required bool activo, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Text(text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: activo ? FontWeight.w600 : FontWeight.w400,
            color: activo ? _primaryColor : const Color(0xFF9E9E9E),
            decoration: activo ? TextDecoration.underline : null,
          )),
    );
  }

  Future<Set<int>?> _seleccionarPropiedadesVideo() async {
    final props = await _db.obtenerPropiedadesConFicha();

    if (props.isEmpty) {
      if (!mounted) return null;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.info, color: Color(0xFFC62828)),
            SizedBox(width: 8),
            Text('Sin propiedades', style: TextStyle(fontSize: 16)),
          ]),
          content: const Text(
            'No hay propiedades con ficha cargada.\n'
            'Generá al menos una ficha antes de exportar.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
      return null;
    }

    // Cargar primera imagen de cada propiedad para mostrar thumbnail
    final primeraImg = await _cargarImagenes(props);

    if (!mounted) return null;

    return showDialog<Set<int>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final seleccionadas = <int>{};
        return StatefulBuilder(
          builder: (ctx, setS) => Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Row(children: [
                      const Icon(Icons.videocam, color: _primaryColor, size: 22),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Seleccionar propiedades para el video',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      '${props.length} propiedad${props.length != 1 ? 'es' : ''} con ficha completa',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9E9E9E)),
                    ),
                    const SizedBox(height: 12),

                    // List
                    Expanded(
                      child: ListView.builder(
                        itemCount: props.length,
                        itemBuilder: (lctx, i) {
                          final p = props[i];
                          final id = p['id'] as int;
                          final direccion =
                              p['direccion'] as String? ?? '—';
                          final localidad = p['localidad'] as String?;
                          final rutaImg = primeraImg[id];

                          return InkWell(
                            onTap: () => setS(() {
                              if (seleccionadas.contains(id)) {
                                seleccionadas.remove(id);
                              } else {
                                seleccionadas.add(id);
                              }
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: seleccionadas.contains(id),
                                    onChanged: (v) => setS(() {
                                      if (v == true) {
                                        seleccionadas.add(id);
                                      } else {
                                        seleccionadas.remove(id);
                                      }
                                    }),
                                    activeColor: _primaryColor,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: rutaImg != null &&
                                            File(rutaImg).existsSync()
                                        ? Image.file(
                                            File(rutaImg),
                                            width: 44,
                                            height: 44,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            width: 44,
                                            height: 44,
                                            color: _primaryColor
                                                .withValues(alpha: 0.08),
                                            child: const Icon(Icons.image,
                                                color: _primaryColor,
                                                size: 20),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(direccion,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF212121))),
                                        Row(children: [
                                          if (localidad != null &&
                                              localidad.isNotEmpty)
                                            Text(localidad,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF757575))),
                                          if (rutaImg == null)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 8),
                                              child: Text('(sin fotos)',
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Color(0xFFBDBDBD),
                                                      fontStyle: FontStyle.italic)),
                                            ),
                                        ]),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const Divider(height: 8),

                    // Buttons
                    Row(children: [
                      TextButton(
                        onPressed: () => setS(() {
                          seleccionadas
                              .addAll(props.map((p) => p['id'] as int));
                        }),
                        child: const Text('Seleccionar todas',
                            style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () => setS(() => seleccionadas.clear()),
                        child: const Text('Deseleccionar todas',
                            style: TextStyle(fontSize: 12)),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        icon: const Icon(Icons.videocam, size: 18),
                        label: Text(
                            'Generar video (${seleccionadas.length})'),
                        style: FilledButton.styleFrom(
                            backgroundColor: _primaryColor),
                        onPressed: seleccionadas.isEmpty
                            ? null
                            : () =>
                                Navigator.pop(ctx, Set<int>.from(seleccionadas)),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportarVideoSlideshow() async {
    Set<int>? idsSeleccionados;
    try {
      idsSeleccionados = await _seleccionarPropiedadesVideo();
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.error, color: Color(0xFFC62828)),
            SizedBox(width: 8),
            Text('Error', style: TextStyle(fontSize: 16)),
          ]),
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
      return;
    }
    if (idsSeleccionados == null || idsSeleccionados.isEmpty || !mounted) {
      return;
    }

    final carpetaPrevia = DbConfig.instance.ultimaCarpetaSlideshow;
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Seleccionar carpeta para guardar el video',
      initialDirectory: carpetaPrevia,
    );
    if (result == null || !mounted) return;

    String estado = 'Preparando...';
    double progreso = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.videocam, color: Color(0xFFC2185B)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Generando video para TV',
                        style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(estado,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF757575))),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: progreso > 0 ? progreso : null,
                    color: const Color(0xFFC2185B),
                    backgroundColor: const Color(0xFFFCE4EC),
                  ),
                  if (progreso > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('${(progreso * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF9E9E9E))),
                    ),
                ],
              ),
            );
          },
        );
      },
    );

    try {
      final outputPath = await VideoSlideshowGenerator.exportar(
        result,
        soloIds: idsSeleccionados,
        onProgress: (mensaje, prog) {
          estado = mensaje;
          progreso = prog;
          if (mounted) {
            (context as Element).markNeedsBuild();
          }
        },
      );

      await DbConfig.instance.guardarCarpetaSlideshow(result);

      if (!mounted) return;

      Navigator.of(context).pop();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
              SizedBox(width: 8),
              Text('Video listo', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Text(
              'El video se guardó en:\n$outputPath\n\nCopialo al pendrive y conectalo al TV.',
              style: const TextStyle(fontSize: 13, height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Process.run('explorer', ['/select,', outputPath]);
              },
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Abrir carpeta'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pop();

      final msg = e.toString().replaceFirst('Exception: ', '');
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Color(0xFFC62828)),
              SizedBox(width: 8),
              Text('Error', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Text(msg.length > 300 ? '${msg.substring(0, 300)}…' : msg,
              style: const TextStyle(fontSize: 13)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  void _filtrar() {
    final q = _busquedaCtrl.text.toLowerCase();
    setState(() {
      _propiedadesFiltradas = _propiedades.where((p) {
        final dir = (p['direccion'] as String? ?? '').toLowerCase();
        final loc = (p['localidad'] as String? ?? '').toLowerCase();
        final prop = (p['propietario_nombre'] as String? ?? '').toLowerCase();
        return dir.contains(q) || loc.contains(q) || prop.contains(q);
      }).toList();
    });
  }

  // ── Colores por estado ────────────────────────────────────────
  Color _colorEstado(String estado) {
    switch (estado) {
      case 'Alquilado':
        return const Color(0xFF1565C0);
      case 'En venta':
        return const Color(0xFFF57C00);
      case 'Vendido':
        return const Color(0xFF2E7D32);
      case 'Nulo':
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF00897B); // Disponible
    }
  }

  // ── Dialog agregar / editar ───────────────────────────────────
  Future<void> _abrirFormPropiedad(Map<String, dynamic>? datos) async {
    final esEdicion = datos != null;
    final formKey = GlobalKey<FormState>();

    final carpetaCtrl = TextEditingController(text: datos?['carpeta'] ?? '');
    final direccionCtrl =
        TextEditingController(text: datos?['direccion'] ?? '');
    final localidadCtrl =
        TextEditingController(text: datos?['localidad'] ?? '');
    final barrioCtrl = TextEditingController(text: datos?['barrio'] ?? '');

    String tipoSel = (datos?['tipo'] as String?) ?? 'Vivienda';
    String estadoSel = (datos?['estado'] as String?) ?? 'Disponible';
    int? propietarioSel = datos?['propietario_id'] as int?;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Título ──────────────────────────────
                      Row(
                        children: [
                          const Icon(Icons.apartment,
                              color: _primaryColor, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            esEdicion ? 'Editar propiedad' : 'Nueva propiedad',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Carpeta ──────────────────────────────
                      TextFormField(
                        controller: carpetaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Carpeta / N° interno',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Tipo + Estado ────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: tipoSel,
                              decoration: const InputDecoration(
                                labelText: 'Tipo',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: _tipos
                                  .map((t) => DropdownMenuItem(
                                      value: t, child: Text(t)))
                                  .toList(),
                              onChanged: (v) => setS(() => tipoSel = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: estadoSel,
                              decoration: const InputDecoration(
                                labelText: 'Estado',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: _estados
                                  .map((e) => DropdownMenuItem(
                                      value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (v) => setS(() => estadoSel = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Dirección ────────────────────────────
                      TextFormField(
                        controller: direccionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Dirección *',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
                      ),
                      const SizedBox(height: 12),

                      // ── Localidad + Barrio ───────────────────
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: localidadCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Localidad',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: barrioCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Barrio',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Propietario ──────────────────────────
                      DropdownButtonFormField<int?>(
                        value: propietarioSel,
                        decoration: const InputDecoration(
                          labelText: 'Propietario',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('— Sin asignar —',
                                style: TextStyle(color: Colors.grey)),
                          ),
                          ..._propietarios.map((p) => DropdownMenuItem<int?>(
                                value: p['id'] as int,
                                child: Text(p['nombre'] as String? ?? '—'),
                              )),
                        ],
                        onChanged: (v) => setS(() => propietarioSel = v),
                      ),
                      const SizedBox(height: 24),

                      // ── Botones ──────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            icon: const Icon(Icons.save, size: 16),
                            label:
                                Text(esEdicion ? 'Guardar' : 'Crear propiedad'),
                            style: FilledButton.styleFrom(
                                backgroundColor: _primaryColor),
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              final data = {
                                'carpeta': carpetaCtrl.text.trim().isEmpty
                                    ? null
                                    : carpetaCtrl.text.trim(),
                                'tipo': tipoSel,
                                'estado': estadoSel,
                                'direccion': direccionCtrl.text.trim(),
                                'localidad': localidadCtrl.text.trim().isEmpty
                                    ? null
                                    : localidadCtrl.text.trim(),
                                'barrio': barrioCtrl.text.trim().isEmpty
                                    ? null
                                    : barrioCtrl.text.trim(),
                                'propietario_id': propietarioSel,
                              };
                              if (esEdicion) {
                                await _db.actualizarPropiedad(
                                    datos['id'] as int, data);
                              } else {
                                await _db.insertarPropiedad(data);
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                              await _cargar();
                            },
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
      ),
    );
  }

  // ── Confirmar eliminación ─────────────────────────────────────
  Future<void> _eliminar(Map<String, dynamic> p) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar propiedad'),
        content: Text(
            '¿Eliminar "${p['direccion']}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado == true) {
      await _db.eliminarPropiedad(p['id'] as int);
      await _cargar();
    }
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Propiedades',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: _exportarVideoSlideshow,
            tooltip: 'Exportar video para TV',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormPropiedad(null),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva propiedad'),
      ),
      body: Column(
        children: [
          // ── Buscador ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _busquedaCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por dirección, localidad o propietario…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _busquedaCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _busquedaCtrl.clear();
                          _filtrar();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
              ),
            ),
          ),

          // ── Filtros ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              children: [
                // ── Grupo Operación ──
                _labelTodas('Todas',
                    activo: _filtroOperacion == null,
                    onTap: () => _aplicarFiltro()),
                const SizedBox(width: 6),
                ToggleButtons(
                  children: const [
                    Text('Alquiler', style: TextStyle(fontSize: 12)),
                    Text('Venta', style: TextStyle(fontSize: 12)),
                  ],
                  isSelected: [
                    _filtroOperacion == 'Alquiler',
                    _filtroOperacion == 'Venta',
                  ],
                  onPressed: (i) {
                    const ops = ['Alquiler', 'Venta'];
                    _aplicarFiltro(
                        operacion: _filtroOperacion == ops[i]
                            ? null
                            : ops[i]);
                  },
                  borderRadius: BorderRadius.circular(8),
                  constraints: const BoxConstraints(
                      minWidth: 72, minHeight: 32),
                  selectedColor: Colors.white,
                  fillColor: _primaryColor,
                  color: const Color(0xFF757575),
                  borderWidth: 1.5,
                  borderColor: const Color(0xFFBDBDBD),
                  selectedBorderColor: _primaryColor,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                // ── Separador ──
                const SizedBox(width: 12),
                Container(
                    width: 1,
                    height: 28,
                    color: const Color(0xFFE0E0E0)),
                const SizedBox(width: 12),
                // ── Grupo Ficha ──
                _labelTodas('Todas',
                    activo: _filtroFicha == null,
                    onTap: () => _aplicarFiltro()),
                const SizedBox(width: 6),
                ToggleButtons(
                  children: const [
                    Text('Con ficha', style: TextStyle(fontSize: 12)),
                    Text('Sin ficha', style: TextStyle(fontSize: 12)),
                  ],
                  isSelected: [
                    _filtroFicha == true,
                    _filtroFicha == false,
                  ],
                  onPressed: (i) {
                    const vals = [true, false];
                    _aplicarFiltro(
                        ficha: _filtroFicha == vals[i] ? null : vals[i]);
                  },
                  borderRadius: BorderRadius.circular(8),
                  constraints: const BoxConstraints(
                      minWidth: 82, minHeight: 32),
                  selectedColor: Colors.white,
                  fillColor: _primaryColor,
                  color: const Color(0xFF757575),
                  borderWidth: 1.5,
                  borderColor: const Color(0xFFBDBDBD),
                  selectedBorderColor: _primaryColor,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // ── Contador ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${_propiedadesFiltradas.length} propiedad${_propiedadesFiltradas.length != 1 ? 'es' : ''}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9E9E9E)),
                ),
              ],
            ),
          ),

          // ── Lista ─────────────────────────────────────────────
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _propiedadesFiltradas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.apartment,
                                size: 56,
                                color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              _busquedaCtrl.text.isEmpty
                                  ? 'No hay propiedades cargadas'
                                  : 'Sin resultados para "${_busquedaCtrl.text}"',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 14),
                            ),
                            if (_busquedaCtrl.text.isEmpty) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Agregar primera propiedad'),
                                onPressed: () => _abrirFormPropiedad(null),
                              ),
                            ]
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 0,
                          childAspectRatio: 5.2 / (MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.3)),
                        ),
                        itemCount: _propiedadesFiltradas.length,
                        itemBuilder: (ctx, i) =>
                            _tarjeta(_propiedadesFiltradas[i]),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Tarjeta de propiedad ──────────────────────────────────────
  Widget _tarjeta(Map<String, dynamic> p) {
    final direccion = p['direccion'] as String? ?? '—';
    final tipo = p['tipo'] as String? ?? 'Vivienda';
    final estado = p['estado'] as String? ?? 'Disponible';
    final localidad = p['localidad'] as String?;
    final propietarioNombre = p['propietario_nombre'] as String?;
    final carpeta = p['carpeta'] as String?;
    final colorEstado = _colorEstado(estado);
    final propId = p['id'] as int;
    final rutaImg = _primeraImagen[propId];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PropiedadDetalleScreen(propiedadId: propId),
            ),
          );
          _cargar();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Imagen o ícono ─────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: rutaImg != null && File(rutaImg).existsSync()
                  ? Image.file(
                      File(rutaImg),
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      color: _primaryColor.withValues(alpha: 0.08),
                      child: const Icon(Icons.apartment,
                          color: _primaryColor, size: 22),
                    ),
            ),
            const SizedBox(width: 14),

            // ── Info principal ─────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          direccion,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF212121),
                          ),
                        ),
                      ),
                      if (carpeta != null && carpeta.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E5F5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            carpeta,
                            style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF7B1FA2),
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  if (localidad != null && localidad.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        localidad,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF757575)),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      // Chip tipo
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFE0E0E0)),
                        ),
                        child: Text(
                          tipo,
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF616161),
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      // Chip estado
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colorEstado.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          estado,
                          style: TextStyle(
                              fontSize: 11,
                              color: colorEstado,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (propietarioNombre != null &&
                      propietarioNombre.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 13, color: Color(0xFF9E9E9E)),
                          const SizedBox(width: 4),
                          Text(
                            propietarioNombre,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF757575)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // ── Menú acciones ──────────────────────────────
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  size: 20, color: Color(0xFF9E9E9E)),
              onSelected: (action) async {
                if (action == 'ficha') {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PropiedadDetalleScreen(
                          propiedadId: p['id'] as int),
                    ),
                  );
                  _cargar();
                } else if (action == 'editar') {
                  _abrirFormPropiedad(p);
                } else if (action == 'eliminar') {
                  _eliminar(p);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'ficha',
                  child: Row(children: [
                    Icon(Icons.article_outlined, size: 18, color: Color(0xFFC2185B)),
                    SizedBox(width: 8),
                    Text('Ficha / Fotos', style: TextStyle(color: Color(0xFFC2185B), fontWeight: FontWeight.w600)),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'editar',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Editar'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'eliminar',
                  child: Row(children: [
                    Icon(Icons.delete_outline,
                        size: 18, color: Color(0xFFC62828)),
                    SizedBox(width: 8),
                    Text('Eliminar',
                        style: TextStyle(color: Color(0xFFC62828))),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

