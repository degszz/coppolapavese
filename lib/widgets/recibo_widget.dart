import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recibo_model.dart';
import '../utils/numero_a_letras.dart';

/// Widget reutilizable que renderiza el recibo en pantalla.
/// Replica el formato del recibo físico argentino.
/// Se usa tanto en la vista previa como referencia para el PDF.
class ReciboWidget extends StatelessWidget {
  final ReciboModel recibo;

  const ReciboWidget({super.key, required this.recibo});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _encabezado(),
          const SizedBox(height: 12),
          _lineaDivisora(),
          const SizedBox(height: 10),
          _datosInquilino(),
          const SizedBox(height: 10),
          _lineaDivisora(),
          const SizedBox(height: 10),
          _parrafoMonto(),
          const SizedBox(height: 10),
          _lineaDivisora(),
          const SizedBox(height: 10),
          _tablaServicios(),
          const SizedBox(height: 10),
          _lineaDivisora(),
          const SizedBox(height: 10),
          _resumenPago(),
          const SizedBox(height: 10),
          _lineaDivisora(),
          const SizedBox(height: 10),
          _seccionNotas(),
          const SizedBox(height: 20),
          _firmas(),
          const SizedBox(height: 16),
          _pieRecibo(),
        ],
      ),
    );
  }

  // ── ENCABEZADO ────────────────────────────────────────────────
  Widget _encabezado() {
    final fmt = DateFormat('dd/MM/yyyy');
    String fechaEmision = recibo.fechaEmision;
    try {
      fechaEmision =
          fmt.format(DateTime.parse(recibo.fechaEmision));
    } catch (_) {}

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Marca "ES COPIA"
        Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFC2185B), width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'ES COPIA',
              style: TextStyle(
                color: Color(0xFFC2185B),
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Título + número
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COPPOLA PAVESE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC2185B),
                    letterSpacing: 1,
                  ),
                ),
                const Text(
                  'INMOBILIARIA',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF212121),
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'RECIBO DE ALQUILER',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF212121),
                  ),
                ),
                Text(
                  'N° ${recibo.numeroRecibo.toString().padLeft(4, '0')}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC2185B),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Fecha y usuario
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _infoFila('Fecha:', fechaEmision),
            if (recibo.usuario != null && recibo.usuario!.isNotEmpty)
              _infoFila('Responsable:', recibo.usuario!),
          ],
        ),
        if (recibo.fechaVencimiento != null &&
            recibo.fechaVencimiento!.isNotEmpty)
          _infoFila(
            'Vencimiento:',
            () {
              try {
                return fmt
                    .format(DateTime.parse(recibo.fechaVencimiento!));
              } catch (_) {
                return recibo.fechaVencimiento!;
              }
            }(),
          ),
      ],
    );
  }

  // ── DATOS DEL INQUILINO ───────────────────────────────────────
  Widget _datosInquilino() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion('DATOS DEL LOCATARIO'),
        const SizedBox(height: 6),
        if (recibo.inquilinoNombre != null &&
            recibo.inquilinoNombre!.isNotEmpty)
          _infoFila('Inquilino:', recibo.inquilinoNombre!),
        if (recibo.direccionCompleta.isNotEmpty)
          _infoFila('Domicilio:', recibo.direccionCompleta),
        if (recibo.propietarioNombre != null &&
            recibo.propietarioNombre!.isNotEmpty)
          _infoFila('Propietario:', recibo.propietarioNombre!),
      ],
    );
  }

  // ── PÁRRAFO MONTO EN LETRAS ───────────────────────────────────
  Widget _parrafoMonto() {
    final montoLetras = numeroALetras(recibo.montoTotal);
    final fmtNum = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion('CONCEPTO'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFEECDD5)),
          ),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF212121), height: 1.6),
              children: [
                const TextSpan(
                  text:
                      'POR MANDATO DEL LOCADOR RECIBI DEL LOCATARIO LA SUMA DE ',
                ),
                TextSpan(
                  text: montoLetras,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: ' ('),
                TextSpan(
                  text: fmtNum.format(recibo.montoTotal),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(
                  text:
                      ') POR EL ALQUILER DE UNA PROPIEDAD UBICADA EN ',
                ),
                TextSpan(
                  text: recibo.direccionCompleta.isNotEmpty
                      ? recibo.direccionCompleta.toUpperCase()
                      : '____________________',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── TABLA DE SERVICIOS ────────────────────────────────────────
  Widget _tablaServicios() {
    final fmt = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion('DETALLE DE SERVICIOS'),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(4),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(2),
          },
          children: [
            // Encabezado
            TableRow(
              decoration: const BoxDecoration(
                  color: Color(0xFFC2185B)),
              children: [
                _celdaHeader('DESCRIPCIÓN'),
                _celdaHeader('MONTO', center: true),
                _celdaHeader('PUNITORIOS', center: true),
                _celdaHeader('TOTAL', center: true),
              ],
            ),
            // Filas de servicios
            ...recibo.servicios.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              final esPar = i % 2 == 0;
              return TableRow(
                decoration: BoxDecoration(
                  color: esPar
                      ? Colors.white
                      : const Color(0xFFFAFAFA),
                ),
                children: [
                  _celdaBody(s.descripcion),
                  _celdaBody(fmt.format(s.monto), center: true),
                  _celdaBody(
                    s.punitorios > 0
                        ? fmt.format(s.punitorios)
                        : '—',
                    center: true,
                  ),
                  _celdaBody(fmt.format(s.total),
                      center: true, bold: true),
                ],
              );
            }),
            // Fila total
            TableRow(
              decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5)),
              children: [
                _celdaBody('TOTAL', bold: true),
                _celdaBody('', center: true),
                _celdaBody('', center: true),
                _celdaBody(
                  fmt.format(recibo.montoTotal),
                  center: true,
                  bold: true,
                  color: const Color(0xFFC2185B),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _celdaHeader(String texto, {bool center = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        textAlign: center ? TextAlign.center : TextAlign.left,
      ),
    );
  }

  Widget _celdaBody(
    String texto, {
    bool center = false,
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color ?? const Color(0xFF212121),
        ),
        textAlign: center ? TextAlign.center : TextAlign.left,
      ),
    );
  }

  // ── RESUMEN DE PAGO ───────────────────────────────────────────
  Widget _resumenPago() {
    final fmt = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion('RESUMEN DE PAGO'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE0E0E0)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              _filaResumen(
                'Monto a Abonar:',
                fmt.format(recibo.montoTotal),
                const Color(0xFF1565C0),
                fondo: const Color(0xFFF5F9FF),
              ),
              const Divider(height: 1),
              _filaResumen(
                'Total Abonado:',
                fmt.format(recibo.montoAbonado),
                const Color(0xFF2E7D32),
                fondo: const Color(0xFFF5FFF7),
              ),
              const Divider(height: 1),
              _filaResumen(
                'Saldo:',
                fmt.format(recibo.saldo),
                recibo.saldo > 0
                    ? const Color(0xFFC62828)
                    : const Color(0xFF2E7D32),
                fondo: recibo.saldo > 0
                    ? const Color(0xFFFFF5F5)
                    : const Color(0xFFF5FFF7),
                negrita: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Estado: ',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12)),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _colorEstado.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _colorEstado.withOpacity(0.4)),
              ),
              child: Text(
                recibo.estadoLabel.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _colorEstado,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _filaResumen(
    String label,
    String valor,
    Color color, {
    Color? fondo,
    bool negrita = false,
  }) {
    return Container(
      color: fondo,
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  negrita ? FontWeight.bold : FontWeight.normal,
              color: const Color(0xFF424242),
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── NOTAS ─────────────────────────────────────────────────────
  Widget _seccionNotas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion('NOTAS'),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE0E0E0)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Text(
              (recibo.notas != null && recibo.notas!.isNotEmpty)
                  ? recibo.notas!
                  : ' ',
              style: const TextStyle(fontSize: 12, height: 1.5),
              maxLines: 5,
            ),
          ),
        ),
      ],
    );
  }

  // ── FIRMAS ────────────────────────────────────────────────────
  Widget _firmas() {
    return Row(
      children: [
        Expanded(child: _lineaFirma('Firma Propietario')),
        const SizedBox(width: 30),
        Expanded(child: _lineaFirma('Firma Inquilino')),
      ],
    );
  }

  Widget _lineaFirma(String label) {
    return Column(
      children: [
        const Divider(thickness: 1, color: Color(0xFF212121)),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
              fontSize: 11, color: Color(0xFF757575)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── PIE ───────────────────────────────────────────────────────
  Widget _pieRecibo() {
    return Center(
      child: Text(
        'Coppola Pavese Inmobiliaria — Documento generado digitalmente',
        style: const TextStyle(
            fontSize: 9, color: Color(0xFFBDBDBD)),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  Widget _lineaDivisora() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFC2185B),
            Color(0xFFE91E8C),
            Color(0xFFC2185B),
          ],
        ),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _tituloSeccion(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Color(0xFFC2185B),
        letterSpacing: 1,
      ),
    );
  }

  Widget _infoFila(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF424242),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF212121)),
            ),
          ),
        ],
      ),
    );
  }

  Color get _colorEstado {
    switch (recibo.estado) {
      case 'pagado':
        return const Color(0xFF2E7D32);
      case 'parcial':
        return const Color(0xFFF57C00);
      default:
        return const Color(0xFFC62828);
    }
  }
}
