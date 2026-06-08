import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
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
      final props = await _db.obtenerPropiedades();
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
      final props = await _db.obtenerPropiedades();
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

