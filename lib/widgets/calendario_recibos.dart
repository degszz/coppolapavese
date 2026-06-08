import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/proyeccion_recibo_model.dart';
import '../utils/proyeccion_recibos_service.dart';

/// Tira horizontal de 7 días (hoy + 6 siguientes) que muestra en qué
/// días hay que emitir recibos. Al hacer hover sobre un día con recibos
/// despliega un popover con la lista de contratos, y al clickear un
/// contrato invoca [onContratoTap].
class CalendarioRecibos extends StatefulWidget {
  /// Callback al clickear un contrato dentro del popover.
  /// Recibe el `contrato_id` del contrato seleccionado.
  final void Function(int contratoId) onContratoTap;

  const CalendarioRecibos({
    super.key,
    required this.onContratoTap,
  });

  @override
  State<CalendarioRecibos> createState() => CalendarioRecibosState();
}

class CalendarioRecibosState extends State<CalendarioRecibos> {
  static const _magenta = Color(0xFFC2185B);

  final _service = ProyeccionRecibosService();

  bool _cargando = true;
  Map<DateTime, List<ProyeccionReciboModel>> _eventos = {};

  /// Los 7 días de la tira — hoy + siguientes 6.
  late List<DateTime> _dias;

  @override
  void initState() {
    super.initState();
    _recalcularDias();
    _cargar();
  }

  void _recalcularDias() {
    final hoy = DateTime.now();
    final base = DateTime(hoy.year, hoy.month, hoy.day);
    _dias = List.generate(7, (i) => base.add(Duration(days: i)));
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final desde = _dias.first;
    final hasta = _dias.last.add(const Duration(days: 1));
    final datos = await _service.obtenerProyecciones(
      desde: desde,
      hasta: hasta,
    );
    final mapa = <DateTime, List<ProyeccionReciboModel>>{};
    for (final p in datos) {
      final key = DateTime(
        p.fechaPrevista.year,
        p.fechaPrevista.month,
        p.fechaPrevista.day,
      );
      mapa.putIfAbsent(key, () => []).add(p);
    }
    if (!mounted) return;
    setState(() {
      _eventos = mapa;
      _cargando = false;
    });
  }

  /// Permite al padre refrescar cuando se emite un recibo nuevo.
  Future<void> refrescar() async {
    _recalcularDias();
    await _cargar();
  }

  List<ProyeccionReciboModel> _eventosDe(DateTime dia) {
    final key = DateTime(dia.year, dia.month, dia.day);
    return _eventos[key] ?? const [];
  }

  int get _totalDeLaSemana {
    int total = 0;
    for (final d in _dias) {
      total += _eventosDe(d).length;
    }
    return total;
  }

  int get _pendientesDeLaSemana {
    int total = 0;
    for (final d in _dias) {
      total += _eventosDe(d).where((e) => !e.emitido).length;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const SizedBox(height: 10),
            _tira(),
            if (_cargando)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _magenta,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final total = _totalDeLaSemana;
    final pendientes = _pendientesDeLaSemana;
    final emitidos = total - pendientes;
    return Row(
      children: [
        const Icon(Icons.event_note, color: _magenta, size: 18),
        const SizedBox(width: 6),
        const Text(
          'Próximos 7 días',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF212121),
          ),
        ),
        const Spacer(),
        if (total > 0) ...[
          if (pendientes > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _magenta.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$pendientes ${pendientes == 1 ? 'pendiente' : 'pendientes'}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _magenta,
                ),
              ),
            ),
          if (emitidos > 0)
            Padding(
              padding: EdgeInsets.only(left: pendientes > 0 ? 4 : 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$emitidos ${emitidos == 1 ? 'emitido' : 'emitidos'}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
            ),
        ] else
          const Text(
            'sin recibos esta semana',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF9E9E9E),
              fontStyle: FontStyle.italic,
            ),
          ),
        const SizedBox(width: 6),
        // Botón "Ver calendario completo"
        TextButton.icon(
          onPressed: () => _abrirCalendarioCompleto(context),
          icon: const Icon(Icons.calendar_month, size: 14),
          label: const Text('Ver mes'),
          style: TextButton.styleFrom(
            foregroundColor: _magenta,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, size: 16),
          color: _magenta,
          tooltip: 'Actualizar',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: () {
            _recalcularDias();
            _cargar();
          },
        ),
      ],
    );
  }

  Future<void> _abrirCalendarioCompleto(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => CalendarioMesDialog(
        onContratoTap: (id) {
          Navigator.of(context).pop();
          widget.onContratoTap(id);
        },
      ),
    );
    // Al cerrar, refrescar por si emitieron recibos desde el dialog
    _recalcularDias();
    _cargar();
  }

  Widget _tira() {
    return LayoutBuilder(
      builder: (ctx, c) {
        return Row(
          children: [
            for (int i = 0; i < _dias.length; i++) ...[
              Expanded(
                child: _DayTile(
                  day: _dias[i],
                  eventos: _eventosDe(_dias[i]),
                  esHoy: i == 0,
                  onContratoTap: widget.onContratoTap,
                ),
              ),
              if (i < _dias.length - 1) const SizedBox(width: 6),
            ],
          ],
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Celda de cada día con hover/click + popover
// ════════════════════════════════════════════════════════════════════

class _DayTile extends StatefulWidget {
  final DateTime day;
  final List<ProyeccionReciboModel> eventos;
  final bool esHoy;
  final void Function(int contratoId) onContratoTap;

  const _DayTile({
    required this.day,
    required this.eventos,
    required this.esHoy,
    required this.onContratoTap,
  });

  @override
  State<_DayTile> createState() => _DayTileState();
}

class _DayTileState extends State<_DayTile> {
  static const _magenta = Color(0xFFC2185B);
  static const _magentaClaro = Color(0xFFFCE4EC);
  static const _rojoVencido = Color(0xFFC62828);
  static const _verde = Color(0xFF2E7D32);
  static const _verdeClaro = Color(0xFFE8F5E9);

  final _link = LayerLink();
  OverlayEntry? _overlay;
  Timer? _cierreTimer;
  bool _pinned = false; // si se abrió con click, no se cierra al salir hover

  bool get _hayRecibos => widget.eventos.isNotEmpty;

  @override
  void dispose() {
    _cierreTimer?.cancel();
    _overlay?.remove();
    super.dispose();
  }

  void _mostrarOverlay({bool pin = false}) {
    if (!_hayRecibos) return;
    _cierreTimer?.cancel();
    if (_overlay != null) {
      if (pin) setState(() => _pinned = true);
      return;
    }
    _pinned = pin;
    _overlay = _crearOverlay();
    Overlay.of(context).insert(_overlay!);
  }

  void _programarCierre() {
    if (_pinned) return;
    _cierreTimer?.cancel();
    _cierreTimer = Timer(const Duration(milliseconds: 180), _cerrarOverlay);
  }

  void _cerrarOverlay() {
    _cierreTimer?.cancel();
    _overlay?.remove();
    _overlay = null;
    if (mounted) {
      setState(() => _pinned = false);
    } else {
      _pinned = false;
    }
  }

  OverlayEntry _crearOverlay() {
    return OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            // Barrier invisible solo cuando está pineado: click fuera cierra
            if (_pinned)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _cerrarOverlay,
                  child: const SizedBox(),
                ),
              ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: const Offset(0, 78),
              child: MouseRegion(
                onEnter: (_) => _cierreTimer?.cancel(),
                onExit: (_) => _programarCierre(),
                child: Material(
                  color: Colors.transparent,
                  child: _Popover(
                    day: widget.day,
                    eventos: widget.eventos,
                    onContratoTap: (id) {
                      _cerrarOverlay();
                      widget.onContratoTap(id);
                    },
                    onClose: _cerrarOverlay,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final diaSemana = DateFormat('EEE', 'es_AR').format(widget.day);
    final estaVencido = widget.eventos.any((e) => e.estaVencido);
    final todosEmitidos = widget.eventos.isNotEmpty &&
        widget.eventos.every((e) => e.emitido);
    final pendientesCount = widget.eventos.where((e) => !e.emitido).length;
    final emitidosCount = widget.eventos.where((e) => e.emitido).length;

    // Colores según estado
    final Color fondo;
    final Color borde;
    final Color colorTexto;
    final Color colorNumero;
    if (_hayRecibos) {
      if (estaVencido) {
        fondo = _rojoVencido.withValues(alpha: 0.08);
        borde = _rojoVencido.withValues(alpha: 0.55);
        colorTexto = _rojoVencido;
        colorNumero = _rojoVencido;
      } else if (todosEmitidos) {
        fondo = _verdeClaro;
        borde = _verde.withValues(alpha: 0.55);
        colorTexto = _verde;
        colorNumero = _verde;
      } else {
        fondo = _magentaClaro;
        borde = _magenta.withValues(alpha: 0.55);
        colorTexto = _magenta;
        colorNumero = _magenta;
      }
    } else {
      fondo = const Color(0xFFFAFAFA);
      borde = const Color(0xFFE0E0E0);
      colorTexto = const Color(0xFF9E9E9E);
      colorNumero = const Color(0xFF616161);
    }

    final contenido = Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borde, width: _pinned ? 2 : 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Día de la semana
          Text(
            _capitalize(diaSemana).replaceAll('.', ''),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colorTexto,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          // Número de día
          Text(
            '${widget.day.day}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorNumero,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          // Indicador: badge si hay recibos, o puntito si es hoy
          if (_hayRecibos)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (emitidosCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: _verde,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, size: 8, color: Colors.white),
                        const SizedBox(width: 1),
                        Text(
                          '$emitidosCount',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (emitidosCount > 0 && pendientesCount > 0)
                  const SizedBox(width: 3),
                if (pendientesCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: estaVencido ? _rojoVencido : _magenta,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$pendientesCount',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ),
              ],
            )
          else if (widget.esHoy)
            Container(
              height: 6,
              width: 6,
              decoration: const BoxDecoration(
                color: Color(0xFFBDBDBD),
                shape: BoxShape.circle,
              ),
            )
          else
            const SizedBox(height: 6),
          // Etiqueta HOY
          if (widget.esHoy) ...[
            const SizedBox(height: 4),
            Text(
              'HOY',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: _hayRecibos ? colorTexto : const Color(0xFF757575),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );

    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        onEnter: (_) => _mostrarOverlay(),
        onExit: (_) => _programarCierre(),
        cursor: _hayRecibos
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _hayRecibos ? () => _mostrarOverlay(pin: true) : null,
          child: contenido,
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ════════════════════════════════════════════════════════════════════
// Popover con botón X
// ════════════════════════════════════════════════════════════════════

class _Popover extends StatelessWidget {
  static const _magenta = Color(0xFFC2185B);
  static const _rojoVencido = Color(0xFFC62828);
  static const _verde = Color(0xFF2E7D32);

  final DateTime day;
  final List<ProyeccionReciboModel> eventos;
  final void Function(int contratoId) onContratoTap;
  final VoidCallback onClose;

  const _Popover({
    required this.day,
    required this.eventos,
    required this.onContratoTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("EEEE d 'de' MMMM", 'es_AR');
    final montoFmt = NumberFormat.currency(
        locale: 'es_AR',
        symbol: '\$',
        decimalDigits: 0,
        customPattern: '\u00A4#,##0');
    final estaVencido = eventos.any((e) => e.estaVencido);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340, maxHeight: 420),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: estaVencido
                ? _rojoVencido.withValues(alpha: 0.3)
                : const Color(0xFFE0E0E0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header con botón X
            Container(
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              decoration: BoxDecoration(
                color: estaVencido
                    ? _rojoVencido.withValues(alpha: 0.08)
                    : const Color(0xFFFCE4EC),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(
                    estaVencido ? Icons.warning_amber : Icons.event,
                    size: 16,
                    color: estaVencido ? _rojoVencido : _magenta,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _capitalize(fmt.format(day)),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: estaVencido ? _rojoVencido : _magenta,
                      ),
                    ),
                  ),
                  Text(
                    '${eventos.length} ${eventos.length == 1 ? 'recibo' : 'recibos'}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: estaVencido ? _rojoVencido : _magenta,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    color: estaVencido ? _rojoVencido : _magenta,
                    tooltip: 'Cerrar',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 26, minHeight: 26),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            if (estaVencido)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                color: _rojoVencido.withValues(alpha: 0.05),
                child: Text(
                  eventos.every((e) => e.emitido)
                      ? 'Todos los recibos de este día fueron emitidos.'
                      : 'Este día ya pasó y hay recibos sin emitir.',
                  style: TextStyle(
                    fontSize: 10,
                    color: eventos.every((e) => e.emitido)
                        ? _verde
                        : _rojoVencido,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const Divider(height: 1),
            // Lista de contratos
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: eventos.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 12, endIndent: 12),
                itemBuilder: (ctx, i) {
                  final p = eventos[i];
                  final colorEstado = p.emitido
                      ? _verde
                      : (p.estaVencido ? _rojoVencido : _magenta);
                  return InkWell(
                    onTap: () => onContratoTap(p.contratoId),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorEstado.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  p.numeroCuota > 0
                                      ? 'Cuota ${p.numeroCuota}/${p.cuotasTotal}'
                                      : 'Recibo',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: colorEstado,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: p.emitido ? _verde : (p.estaVencido ? _rojoVencido : _magenta),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (p.emitido)
                                      const Icon(Icons.check, size: 8, color: Colors.white),
                                    if (p.emitido) const SizedBox(width: 2),
                                    Text(
                                      p.emitido ? 'EMITIDO' : (p.estaVencido ? 'VENCIDO' : 'PENDIENTE'),
                                      style: const TextStyle(
                                        fontSize: 7,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.inquilinoNombre,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF212121),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  p.propiedadDireccion,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF757575),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (p.monto > 0)
                                  Text(
                                    montoFmt.format(p.monto),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: p.emitido ? _verde : const Color(0xFF2E7D32),
                                    ),
                                  ),
                                if (p.emitido && p.numeroRecibo != null)
                                  Text(
                                    'Recibo N° ${p.numeroRecibo.toString().padLeft(4, '0')}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: _verde.withValues(alpha: 0.8),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            p.emitido ? Icons.visibility : Icons.chevron_right,
                            size: 18,
                            color: colorEstado,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Footer
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFA),
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(12)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.touch_app, size: 12, color: Color(0xFF9E9E9E)),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Clickeá un contrato para ver o emitir el recibo',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ════════════════════════════════════════════════════════════════════
// Diálogo con calendario mensual completo
// ════════════════════════════════════════════════════════════════════

/// Ventana flotante que muestra el calendario mensual completo con las
/// proyecciones de recibos. Permite navegar entre meses, ver detalles
/// al hacer hover/click sobre un día y navegar al contrato para emitirlo.
class CalendarioMesDialog extends StatefulWidget {
  final void Function(int contratoId) onContratoTap;

  const CalendarioMesDialog({
    super.key,
    required this.onContratoTap,
  });

  @override
  State<CalendarioMesDialog> createState() => _CalendarioMesDialogState();
}

class _CalendarioMesDialogState extends State<CalendarioMesDialog> {
  static const _magenta = Color(0xFFC2185B);
  static const _magentaClaro = Color(0xFFFCE4EC);
  static const _rojoVencido = Color(0xFFC62828);

  final _service = ProyeccionRecibosService();

  late DateTime _mesVisible;
  bool _cargando = true;
  Map<DateTime, List<ProyeccionReciboModel>> _eventos = {};

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _mesVisible = DateTime(hoy.year, hoy.month, 1);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final desde = _mesVisible.subtract(const Duration(days: 7));
    final hasta = DateTime(_mesVisible.year, _mesVisible.month + 1, 0)
        .add(const Duration(days: 7));
    final datos = await _service.obtenerProyecciones(
      desde: desde,
      hasta: hasta,
    );
    final mapa = <DateTime, List<ProyeccionReciboModel>>{};
    for (final p in datos) {
      final key = DateTime(
        p.fechaPrevista.year,
        p.fechaPrevista.month,
        p.fechaPrevista.day,
      );
      mapa.putIfAbsent(key, () => []).add(p);
    }
    if (!mounted) return;
    setState(() {
      _eventos = mapa;
      _cargando = false;
    });
  }

  List<ProyeccionReciboModel> _eventosDe(DateTime dia) {
    final key = DateTime(dia.year, dia.month, dia.day);
    return _eventos[key] ?? const [];
  }

  int get _totalDelMes {
    int total = 0;
    _eventos.forEach((k, v) {
      if (k.year == _mesVisible.year && k.month == _mesVisible.month) {
        total += v.length;
      }
    });
    return total;
  }

  void _mesAnterior() {
    setState(() {
      _mesVisible = DateTime(_mesVisible.year, _mesVisible.month - 1, 1);
    });
    _cargar();
  }

  void _mesSiguiente() {
    setState(() {
      _mesVisible = DateTime(_mesVisible.year, _mesVisible.month + 1, 1);
    });
    _cargar();
  }

  void _irHoy() {
    final hoy = DateTime.now();
    setState(() {
      _mesVisible = DateTime(hoy.year, hoy.month, 1);
    });
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 820,
          maxHeight: 680,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _headerDialog(),
            _barraMes(),
            _cabeceraDiasSemana(),
            Expanded(child: _grilla()),
            _footerDialog(),
          ],
        ),
      ),
    );
  }

  Widget _headerDialog() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
      decoration: const BoxDecoration(
        color: _magentaClaro,
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: _magenta, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Calendario de recibos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _magenta,
            ),
          ),
          const Spacer(),
          if (_totalDelMes > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _magenta,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_totalDelMes ${_totalDelMes == 1 ? 'recibo' : 'recibos'} este mes',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: _magenta,
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _barraMes() {
    final titulo =
        DateFormat("MMMM 'de' y", 'es_AR').format(_mesVisible);
    final hoy = DateTime.now();
    final esMesActual = _mesVisible.year == hoy.year &&
        _mesVisible.month == hoy.month;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFEEEEEE)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            color: _magenta,
            tooltip: 'Mes anterior',
            onPressed: _mesAnterior,
          ),
          Expanded(
            child: Center(
              child: Text(
                _capitalizeDialog(titulo),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121),
                ),
              ),
            ),
          ),
          if (!esMesActual)
            TextButton.icon(
              onPressed: _irHoy,
              icon: const Icon(Icons.today, size: 14),
              label: const Text('Hoy'),
              style: TextButton.styleFrom(
                foregroundColor: _magenta,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            color: _magenta,
            tooltip: 'Mes siguiente',
            onPressed: _mesSiguiente,
          ),
        ],
      ),
    );
  }

  Widget _cabeceraDiasSemana() {
    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        border: Border(
          bottom: BorderSide(color: Color(0xFFEEEEEE)),
        ),
      ),
      child: Row(
        children: [
          for (final d in dias)
            Expanded(
              child: Center(
                child: Text(
                  d,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF616161),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _grilla() {
    final primerDia = _mesVisible;
    final ultimoDia =
        DateTime(_mesVisible.year, _mesVisible.month + 1, 0);
    final offsetInicial = primerDia.weekday - 1; // lunes=0 ... domingo=6
    final totalCeldas = offsetInicial + ultimoDia.day;
    final totalConRelleno = ((totalCeldas / 7).ceil()) * 7;

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.05,
            ),
            itemCount: totalConRelleno,
            itemBuilder: (ctx, index) {
              final diaNum = index - offsetInicial + 1;
              if (diaNum < 1 || diaNum > ultimoDia.day) {
                return const SizedBox();
              }
              final fecha = DateTime(
                _mesVisible.year,
                _mesVisible.month,
                diaNum,
              );
              final hoy = DateTime.now();
              final esHoy = fecha.year == hoy.year &&
                  fecha.month == hoy.month &&
                  fecha.day == hoy.day;
              return _MesDayCell(
                day: fecha,
                eventos: _eventosDe(fecha),
                esHoy: esHoy,
                onContratoTap: widget.onContratoTap,
              );
            },
          ),
        ),
        if (_cargando)
          Positioned(
            top: 8,
            right: 14,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _magenta,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _footerDialog() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
        border: Border(
          top: BorderSide(color: Color(0xFFEEEEEE)),
        ),
      ),
      child: Row(
        children: [
          _leyenda(color: const Color(0xFF2E7D32), texto: 'Emitidos'),
          const SizedBox(width: 14),
          _leyenda(color: _magenta, texto: 'Pendientes'),
          const SizedBox(width: 14),
          _leyenda(color: _rojoVencido, texto: 'Vencidos'),
          const SizedBox(width: 14),
          _leyenda(color: const Color(0xFFBDBDBD), texto: 'Sin recibos'),
          const Spacer(),
          const Icon(Icons.touch_app, size: 12, color: Color(0xFF9E9E9E)),
          const SizedBox(width: 4),
          const Text(
            'Clickeá un día para ver los contratos',
            style: TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
          ),
        ],
      ),
    );
  }

  Widget _leyenda({required Color color, required String texto}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          texto,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF616161),
          ),
        ),
      ],
    );
  }

  String _capitalizeDialog(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ════════════════════════════════════════════════════════════════════
// Celda del calendario mensual con hover + popover
// ════════════════════════════════════════════════════════════════════

class _MesDayCell extends StatefulWidget {
  final DateTime day;
  final List<ProyeccionReciboModel> eventos;
  final bool esHoy;
  final void Function(int contratoId) onContratoTap;

  const _MesDayCell({
    required this.day,
    required this.eventos,
    required this.esHoy,
    required this.onContratoTap,
  });

  @override
  State<_MesDayCell> createState() => _MesDayCellState();
}

class _MesDayCellState extends State<_MesDayCell> {
  static const _magenta = Color(0xFFC2185B);
  static const _magentaClaro = Color(0xFFFCE4EC);
  static const _rojoVencido = Color(0xFFC62828);
  static const _verde = Color(0xFF2E7D32);
  static const _verdeClaro = Color(0xFFE8F5E9);

  final _link = LayerLink();
  OverlayEntry? _overlay;
  Timer? _cierreTimer;
  bool _pinned = false;

  bool get _hayRecibos => widget.eventos.isNotEmpty;

  @override
  void dispose() {
    _cierreTimer?.cancel();
    _overlay?.remove();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _MesDayCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day != widget.day) {
      _cerrarOverlay();
    }
  }

  void _mostrarOverlay({bool pin = false}) {
    if (!_hayRecibos) return;
    _cierreTimer?.cancel();
    if (_overlay != null) {
      if (pin) setState(() => _pinned = true);
      return;
    }
    _pinned = pin;
    _overlay = _crearOverlay();
    Overlay.of(context).insert(_overlay!);
  }

  void _programarCierre() {
    if (_pinned) return;
    _cierreTimer?.cancel();
    _cierreTimer = Timer(const Duration(milliseconds: 180), _cerrarOverlay);
  }

  void _cerrarOverlay() {
    _cierreTimer?.cancel();
    _overlay?.remove();
    _overlay = null;
    if (mounted) {
      setState(() => _pinned = false);
    } else {
      _pinned = false;
    }
  }

  OverlayEntry _crearOverlay() {
    return OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            if (_pinned)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _cerrarOverlay,
                  child: const SizedBox(),
                ),
              ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: const Offset(0, 56),
              child: MouseRegion(
                onEnter: (_) => _cierreTimer?.cancel(),
                onExit: (_) => _programarCierre(),
                child: Material(
                  color: Colors.transparent,
                  child: _Popover(
                    day: widget.day,
                    eventos: widget.eventos,
                    onContratoTap: (id) {
                      _cerrarOverlay();
                      widget.onContratoTap(id);
                    },
                    onClose: _cerrarOverlay,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final estaVencido = widget.eventos.any((e) => e.estaVencido);
    final todosEmitidos = widget.eventos.isNotEmpty &&
        widget.eventos.every((e) => e.emitido);
    final pendientesCount = widget.eventos.where((e) => !e.emitido).length;
    final emitidosCount = widget.eventos.where((e) => e.emitido).length;

    final Color fondo;
    final Color borde;
    final Color colorNumero;
    if (_hayRecibos) {
      if (estaVencido) {
        fondo = _rojoVencido.withValues(alpha: 0.08);
        borde = _rojoVencido.withValues(alpha: 0.55);
        colorNumero = _rojoVencido;
      } else if (todosEmitidos) {
        fondo = _verdeClaro;
        borde = _verde.withValues(alpha: 0.55);
        colorNumero = _verde;
      } else {
        fondo = _magentaClaro;
        borde = _magenta.withValues(alpha: 0.55);
        colorNumero = _magenta;
      }
    } else {
      fondo = const Color(0xFFFAFAFA);
      borde = const Color(0xFFE0E0E0);
      colorNumero = const Color(0xFF616161);
    }

    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        onEnter: (_) => _mostrarOverlay(),
        onExit: (_) => _programarCierre(),
        cursor: _hayRecibos
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _hayRecibos ? () => _mostrarOverlay(pin: true) : null,
          child: Container(
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.esHoy ? _magenta : borde,
                width: widget.esHoy || _pinned ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${widget.day.day}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colorNumero,
                        height: 1,
                      ),
                    ),
                    if (widget.esHoy)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: _magenta,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'HOY',
                          style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_hayRecibos)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (emitidosCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 3, vertical: 2),
                          decoration: BoxDecoration(
                            color: _verde,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check, size: 7, color: Colors.white),
                              const SizedBox(width: 1),
                              Text(
                                '$emitidosCount',
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (emitidosCount > 0 && pendientesCount > 0)
                        const SizedBox(width: 2),
                      if (pendientesCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: estaVencido ? _rojoVencido : _magenta,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$pendientesCount',
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.1,
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
    );
  }
}
