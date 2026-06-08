import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre WhatsApp Desktop si está instalado; si no, cae a WhatsApp Web (wa.me).
///
/// Flujo:
/// 1. Intenta el protocolo nativo `whatsapp://send?...` (abre WhatsApp Desktop).
/// 2. Si no hay handler registrado o falla, abre `https://wa.me/...` en el
///    navegador por defecto (que suele redirigir a web.whatsapp.com o proponer
///    abrir la app instalada).
///
/// [telefono] ya debe venir normalizado en formato internacional con `+`
/// (p.ej. `+541112345678`).
/// [mensaje] es el texto a precargar; se URL-encodea acá dentro.
Future<void> abrirWhatsApp({
  required String telefono,
  required String mensaje,
}) async {
  final telLimpio = telefono.replaceAll('+', '').trim();
  final texto = Uri.encodeComponent(mensaje);

  final uriDesktop = Uri.parse('whatsapp://send?phone=$telLimpio&text=$texto');
  final uriWeb = Uri.parse('https://wa.me/$telLimpio?text=$texto');

  // 1) Intentar WhatsApp Desktop vía url_launcher (respeta canLaunchUrl).
  try {
    if (await canLaunchUrl(uriDesktop)) {
      final ok = await launchUrl(uriDesktop,
          mode: LaunchMode.externalApplication);
      if (ok) return;
    }
  } catch (_) {
    // Si falla el handler nativo, probamos fallback
  }

  // 2) Fallback: wa.me vía url_launcher
  try {
    final ok = await launchUrl(uriWeb, mode: LaunchMode.externalApplication);
    if (ok) return;
  } catch (_) {
    // Último recurso: cmd start (misma estrategia vieja)
  }

  // 3) Último fallback: cmd /c start (por si url_launcher falla en Windows)
  if (Platform.isWindows) {
    try {
      await Process.run('cmd', ['/c', 'start', '', uriWeb.toString()]);
    } catch (_) {}
  }
}

/// Normaliza un teléfono argentino al formato internacional `+54...`.
/// Devuelve cadena vacía si [raw] está vacío.
String normalizarTelefonoAR(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return '';
  var tel = t.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  if (tel.startsWith('+')) return tel;
  if (tel.startsWith('0')) {
    tel = '+54${tel.substring(1)}';
  } else {
    tel = '+54$tel';
  }
  return tel;
}

/// Muestra un diálogo flotante confirmando que se envió un mensaje por
/// WhatsApp al inquilino. Llamar después de `abrirWhatsApp`.
///
/// - [context]: contexto activo (se usa `mounted` fuera antes de llamar).
/// - [nombreCompleto]: nombre y apellido del destinatario.
/// - [telefono]: teléfono en cualquier formato; se muestra tal cual se
///   le pasó (preferir el número normalizado con `+54...`).
Future<void> mostrarConfirmacionWhatsApp({
  required BuildContext context,
  required String nombreCompleto,
  required String telefono,
}) async {
  const verdeWA = Color(0xFF25D366);
  const verdeWAOscuro = Color(0xFF128C7E);

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header verde WhatsApp con ícono y X
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [verdeWA, verdeWAOscuro],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Mensaje enviado',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: Colors.white,
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              // Cuerpo
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Se envió un mensaje por WhatsApp a:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF616161),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: verdeWA.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: verdeWA.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person,
                              color: verdeWAOscuro,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombreCompleto.trim().isEmpty
                                      ? '(sin nombre)'
                                      : nombreCompleto,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF212121),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.phone,
                                      size: 12,
                                      color: verdeWAOscuro,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      telefono.isEmpty
                                          ? '(sin teléfono)'
                                          : telefono,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: verdeWAOscuro,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 13, color: Color(0xFF9E9E9E)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Confirmá el envío desde WhatsApp.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9E9E9E),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Footer con botón OK
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: verdeWAOscuro,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Text('Entendido'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
