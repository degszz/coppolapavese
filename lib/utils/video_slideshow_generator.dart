import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';
import 'video_frame_renderer.dart';

class VideoSlideshowGenerator {
  static Future<String> exportar(
    String carpetaDestino, {
    Set<int>? soloIds,
    void Function(String mensaje, double progreso)? onProgress,
  }) async {
    final dir = Directory(carpetaDestino);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final db = DatabaseHelper();
    final todas = await db.obtenerPropiedadesConFicha();

    List<Map<String, dynamic>> propiedades;
    if (soloIds != null && soloIds.isNotEmpty) {
      propiedades =
          todas.where((r) => soloIds.contains(r['id'] as int)).toList();
    } else {
      propiedades = todas;
    }

    if (propiedades.isEmpty) {
      throw Exception(
          'No hay propiedades seleccionadas con ficha cargada.\n'
          'Generá al menos una ficha antes de exportar.');
    }

    final tempDir = Directory(p.join(carpetaDestino, '.cp_video_frames'));
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    await tempDir.create(recursive: true);

    final ffmpegPath = await _obtenerFfmpeg(onProgress);

    final logoBytes = await rootBundle.load('assets/images/cp.png');
    final logoCodec = await ui.instantiateImageCodec(
        logoBytes.buffer.asUint8List());
    final logoFrame = await logoCodec.getNextFrame();
    final logoImg = logoFrame.image;

    int frameIdx = 0;

    for (int i = 0; i < propiedades.length; i++) {
      final row = propiedades[i];
      final propId = row['id'] as int;

      final specs = <SpecItem>[];
      final dormitorios = (row['dormitorios'] as int?) ?? 0;
      final banos = (row['banos'] as int?) ?? 0;
      final cochera = (row['cochera'] as int?) ?? 0;
      final supTotal = ((row['superficie_total'] as num?)?.toDouble() ?? 0);
      final supCubierta =
          ((row['superficie_cubierta'] as num?)?.toDouble() ?? 0);

      if (dormitorios > 0) {
        specs.add(SpecItem(label: 'Dorm.', value: dormitorios.toString()));
      }
      if (banos > 0) {
        specs.add(SpecItem(label: 'Ba\u00f1os', value: banos.toString()));
      }
      if (cochera > 0) {
        specs.add(SpecItem(label: 'Cochera', value: cochera.toString()));
      }
      if (supTotal > 0) {
        specs.add(SpecItem(
            label: 'm\u00b2 Lote', value: supTotal.toStringAsFixed(0)));
      }
      if (supCubierta > 0) {
        specs.add(SpecItem(
            label: 'm\u00b2 Casa', value: supCubierta.toStringAsFixed(0)));
      }

      // Ambientes
      final ambientesLista = <String>[];
      try {
        final raw = row['ambientes_lista'] as String? ?? '[]';
        ambientesLista.addAll(List<String>.from(jsonDecode(raw)));
      } catch (_) {}

      // Servicios
      final serviciosLista = <String>[];
      try {
        final raw = row['servicios_lista'] as String? ?? '[]';
        serviciosLista.addAll(List<String>.from(jsonDecode(raw)));
      } catch (_) {}

      final imagenes = await db.obtenerImagenesPropiedad(propId);
      final rutas = imagenes.map((i) => i['ruta'] as String).toList();

      final frames = await VideoFrameRenderer.renderizarPropiedad(
        rutasImagenes: rutas,
        operacion: (row['operacion'] as String?) ?? 'Alquiler',
        direccion: (row['direccion'] as String?) ?? '',
        ubicacion: (row['ubicacion_ficha'] as String?) ??
            (row['localidad'] as String?) ??
            '',
        specs: specs,
        ambientes: ambientesLista,
        servicios: serviciosLista,
        descripcion: (row['descripcion'] as String?) ?? '',
        logoImg: logoImg,
        totalFrames: 16,
      );

      for (final png in frames) {
        final path = p.join(tempDir.path,
            'frame_${frameIdx.toString().padLeft(5, '0')}.png');
        await File(path).writeAsBytes(png);
        frameIdx++;
      }

      onProgress?.call(
        'Propiedad ${i + 1} de ${propiedades.length}\n${(row['direccion'] as String?) ?? ''}',
        (i + 1) / (propiedades.length + 1),
      );
    }

    // ── FFmpeg encode ──
    final outputPath = p.join(carpetaDestino, 'slideshow.mp4');
    if (await File(outputPath).exists()) {
      await File(outputPath).delete();
    }

    onProgress?.call('Codificando video...', 1.0);

    final result = await Process.run(
      ffmpegPath,
      [
        '-y',
        '-framerate',
        '2',
        '-i',
        p.join(tempDir.path, 'frame_%05d.png'),
        '-r',
        '30',
        '-c:v',
        'libx264',
        '-crf',
        '26',
        '-pix_fmt',
        'yuv420p',
        outputPath,
      ],
      workingDirectory: carpetaDestino,
    );

    await tempDir.delete(recursive: true);
    logoImg.dispose();

    if (result.exitCode != 0) {
      throw Exception(
          'FFmpeg falló:\n${result.stderr}\n\nEsto puede pasar si el código de video no está soportado. '
          'Probá instalar FFmpeg manualmente desde https://ffmpeg.org/download.html');
    }

    return outputPath;
  }

  static Future<String> _obtenerFfmpeg(
      [void Function(String, double)? onProgress]) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final ffmpegDir =
        Directory(p.join(docsDir.path, 'CoppolaPavese', 'ffmpeg'));
    if (!await ffmpegDir.exists()) {
      await ffmpegDir.create(recursive: true);
    }
    final ffmpegExe = p.join(ffmpegDir.path, 'ffmpeg.exe');

    if (await File(ffmpegExe).exists()) {
      return ffmpegExe;
    }

    final url =
        'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip';
    final zipPath = p.join(ffmpegDir.path, 'ffmpeg.zip');

    try {
      onProgress?.call('Descargando FFmpeg (primer uso)...', 0.0);
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(url));
        final response =
            await request.close().timeout(const Duration(minutes: 5));
        final zipFile = File(zipPath);
        await response.pipe(zipFile.openWrite());
      } finally {
        client.close();
      }

      await Process.run(
        'powershell',
        [
          '-Command',
          'Expand-Archive',
          '-Path', "'$zipPath'",
          '-DestinationPath', "'${ffmpegDir.path}'",
          '-Force',
        ],
      );

      final extraidos = await ffmpegDir
          .list()
          .where((e) => e is Directory && e.path != ffmpegDir.path)
          .toList();

      if (extraidos.isNotEmpty) {
        final binDir = p.join(extraidos.first.path, 'bin');
        if (await Directory(binDir).exists()) {
          final src = p.join(binDir, 'ffmpeg.exe');
          if (await File(src).exists()) {
            await File(src).copy(ffmpegExe);
          }
        }
      }

      await File(zipPath).delete();
    } on TimeoutException {
      throw Exception(
          'La descarga de FFmpeg tardó demasiado. Verificá tu conexión a internet.');
    } catch (e) {
      throw Exception(
          'No se pudo descargar FFmpeg: ${e}\n\n'
          'Instalalo manualmente desde https://ffmpeg.org/download.html\n'
          'y copiá ffmpeg.exe a:\n$ffmpegExe');
    }

    if (!await File(ffmpegExe).exists()) {
      throw Exception(
          'FFmpeg no se encuentra en $ffmpegExe\n'
          'Instalalo manualmente desde https://ffmpeg.org/download.html');
    }

    return ffmpegExe;
  }
}
