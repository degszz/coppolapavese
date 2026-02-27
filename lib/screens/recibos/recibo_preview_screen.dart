import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../models/recibo_model.dart';
import '../../widgets/recibo_widget.dart';
import '../../utils/pdf_generator.dart';

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
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartir',
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

                // Recibo en formato papel (carta)
                Container(
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
                icon: const Icon(Icons.share_outlined),
                label: const Text('Compartir'),
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

  // ── Imprimir usando el paquete printing ───────────────────────
  Future<void> _imprimir() async {
    setState(() => _generandoPdf = true);
    try {
      final pdfBytes =
          await PdfGenerator.generarRecibo(widget.recibo);
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(pdfBytes),
        name:
            'Recibo_${widget.recibo.numeroRecibo.toString().padLeft(4, '0')}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }

  // ── Compartir por WhatsApp / otras apps ───────────────────────
  Future<void> _compartir() async {
    setState(() => _generandoPdf = true);
    try {
      final pdfBytes =
          await PdfGenerator.generarRecibo(widget.recibo);
      final dir = await getTemporaryDirectory();
      final nombreArchivo =
          'Recibo_${widget.recibo.numeroRecibo.toString().padLeft(4, '0')}.pdf';
      final archivo = File('${dir.path}/$nombreArchivo');
      await archivo.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(archivo.path)],
        text:
            'Recibo de alquiler N° ${widget.recibo.numeroRecibo.toString().padLeft(4, '0')} — Coppola Pavese Inmobiliaria',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
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

      final nombreArchivo =
          'Recibo_${widget.recibo.numeroRecibo.toString().padLeft(4, '0')}.pdf';

      final dir = await _obtenerDirectorioGuardado();
      final archivo = File('${dir.path}/$nombreArchivo');
      await archivo.writeAsBytes(pdfBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF guardado en: ${archivo.path}'),
            backgroundColor: const Color(0xFF2E7D32),
            action: SnackBarAction(
              label: 'ABRIR',
              textColor: Colors.white,
              onPressed: () => _abrirArchivo(archivo.path),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
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
