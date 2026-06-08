import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../models/recibo_model.dart';
import '../../widgets/recibo_widget.dart';
import '../../utils/pdf_generator.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/whatsapp_launcher.dart';
import '../../widgets/print_queue_dialog.dart';

class ReciboPreviewScreen extends StatefulWidget {
  final ReciboModel recibo;
  final bool esNuevo;

  const ReciboPreviewScreen({
    super.key,
    required this.recibo,
    this.esNuevo = false,
  });

  @override
  State<ReciboPreviewScreen> createState() => _ReciboPreviewScreenState();
}

class _ReciboPreviewScreenState extends State<ReciboPreviewScreen> {
  bool _generandoPdf = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Recibo N° ${widget.recibo.numeroRecibo.toString().padLeft(4, '0')}',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, widget.esNuevo),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Imprimir / Guardar PDF',
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
          // ── Vista previa del recibo ──────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Banner "GUARDADO" si viene de formulario nuevo
                if (widget.esNuevo)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF2E7D32).withOpacity(0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: Color(0xFF2E7D32), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Recibo guardado correctamente. Podés imprimirlo o compartirlo.',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Recibo en formato papel (carta) — ancho acotado para desktop
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Container(
                      width: double.infinity,
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
                      child: ReciboWidget(recibo: widget.recibo),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Botones inferiores
                _botonesAccion(context),
                const SizedBox(height: 30),
              ],
            ),
          ),

          // ── Indicador de carga ───────────────────────────────────
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
                        CircularProgressIndicator(
                          color: Color(0xFFC2185B),
                        ),
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

  Widget _botonesAccion(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _generandoPdf ? null : _imprimir,
                icon: const Icon(Icons.print_outlined),
                label: const Text('Imprimir / PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC2185B),
                  side: const BorderSide(color: Color(0xFFC2185B)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _generandoPdf ? null : _compartir,
                icon: const Icon(Icons.chat_outlined),
                label: const Text('WhatsApp'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _guardarPdfLocal,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Descargar PDF'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1565C0),
              side: const BorderSide(color: Color(0xFF1565C0)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  // ── Nombre de archivo: Recibo_0001_Juan_Perez ─────────────────
  String _nombrePdf() {
    final nro = widget.recibo.numeroRecibo.toString().padLeft(4, '0');
    final raw = (widget.recibo.inquilinoNombre ?? '').trim();
    if (raw.isEmpty) return 'Recibo_$nro';
    final sanitizado = raw
        .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i')
        .replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('ü', 'u')
        .replaceAll('Á', 'A').replaceAll('É', 'E').replaceAll('Í', 'I')
        .replaceAll('Ó', 'O').replaceAll('Ú', 'U').replaceAll('Ü', 'U')
        .replaceAll('ñ', 'n').replaceAll('Ñ', 'N')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return 'Recibo_${nro}_$sanitizado';
  }

  // ── Imprimir usando el paquete printing ───────────────────────
  Future<void> _imprimir() async {
    setState(() => _generandoPdf = true);
    try {
      final pdfBytes =
          await PdfGenerator.generarRecibo(widget.recibo);
      final enviado = await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(pdfBytes),
        name: _nombrePdf(),
      );
      // Si el usuario efectivamente mandó a imprimir, avisar con acción
      // para abrir la cola y verificar el estado del trabajo.
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

  // ── Compartir PDF por WhatsApp al inquilino ────────────────────
  Future<void> _compartir() async {
    setState(() => _generandoPdf = true);
    try {
      final pdfBytes = await PdfGenerator.generarRecibo(widget.recibo);

      // Guardar PDF en temp
      final dir = await getTemporaryDirectory();
      final nombreArchivo = '${_nombrePdf()}.pdf';
      final archivo = File('${dir.path}${Platform.pathSeparator}$nombreArchivo');
      await archivo.writeAsBytes(pdfBytes);

      // Texto con datos de la inmobiliaria
      final nroRecibo = widget.recibo.numeroRecibo.toString().padLeft(4, '0');
      final inquilino = widget.recibo.inquilinoNombre ?? '';
      final domicilio = widget.recibo.direccionCompleta;

      final mensaje = StringBuffer();
      mensaje.writeln('*COPPOLA PAVESE Inmobiliaria*');
      mensaje.writeln('Blandengues 188 - San Miguel del Monte');
      mensaje.writeln('Tel: 02226 546317 / 02271 412950');
      mensaje.writeln('');
      mensaje.writeln('*Recibo de Alquiler N° $nroRecibo*');
      if (inquilino.isNotEmpty) mensaje.writeln('Inquilino: $inquilino');
      if (domicilio.isNotEmpty) mensaje.writeln('Domicilio: $domicilio');
      mensaje.writeln('');
      mensaje.writeln('Se adjunta el recibo en formato PDF.');

      // Obtener teléfono del inquilino (celular o telefono)
      final celular = (widget.recibo.inquilinoCelular ?? '').trim();
      final telefono = (widget.recibo.inquilinoTelefono ?? '').trim();
      final rawTel = celular.isNotEmpty ? celular : telefono;

      if (rawTel.isNotEmpty) {
        // Abrir WhatsApp (Desktop si está instalado, si no Web) al número del
        // inquilino con el mensaje precargado.
        final tel = normalizarTelefonoAR(rawTel);
        await abrirWhatsApp(telefono: tel, mensaje: mensaje.toString());
        if (mounted) {
          await mostrarConfirmacionWhatsApp(
            context: context,
            nombreCompleto: inquilino,
            telefono: tel,
          );
        }
      }

      // También compartir PDF via share nativo
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

  // ── Guardar PDF en almacenamiento local ───────────────────────
  Future<void> _guardarPdfLocal() async {
    setState(() => _generandoPdf = true);
    try {
      final pdfBytes =
          await PdfGenerator.generarRecibo(widget.recibo);

      final nombreArchivo = '${_nombrePdf()}.pdf';

      final dir = await _obtenerDirectorioGuardado();
      final archivo = File('${dir.path}/$nombreArchivo');
      await archivo.writeAsBytes(pdfBytes);

      if (mounted) {
        mostrarNotificacion(context,
            texto: 'PDF guardado en: ${archivo.path}',
            color: const Color(0xFF2E7D32),
            action: SnackBarAction(
              label: 'ABRIR',
              textColor: Colors.white,
              onPressed: () => _abrirArchivo(archivo.path),
            ));
      }
    } catch (e) {
      if (mounted) {
        mostrarNotificacion(context,
            texto: 'Error al guardar: $e',
            color: const Color(0xFFC62828));
      }
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }

  Future<Directory> _obtenerDirectorioGuardado() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // Desktop: guardar en Documentos del usuario
      final docs = await getApplicationDocumentsDirectory();
      final carpeta = Directory('${docs.path}\\CoppolaPavese');
      if (!await carpeta.exists()) await carpeta.create(recursive: true);
      return carpeta;
    } else if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir;
      return (await getExternalStorageDirectory()) ??
          await getApplicationDocumentsDirectory();
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }

  void _abrirArchivo(String ruta) {
    if (Platform.isWindows) {
      Process.run('explorer', [ruta]);
    } else if (Platform.isMacOS) {
      Process.run('open', [ruta]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [ruta]);
    }
  }
}
