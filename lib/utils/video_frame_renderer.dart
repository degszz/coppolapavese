import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' show Icons;

class VideoFrameRenderer {
  static const double width = 1080;
  static const double height = 1920;
  static const double imageAreaHeight = 860;
  static const double marginX = 60;
  static const double contentW = width - 2 * marginX;
  static const double logoY = height - 70 - 16 - 50;
  static const double _descEstStartY = 1310.0;
  static const double _descEstMaxHeight = logoY - _descEstStartY - 16;

  static const _magenta = ui.Color(0xFFC2185B);
  static const _darkMagenta = ui.Color(0xFF880E4F);
  static const _gray = ui.Color(0xFF757575);
  static const _dark = ui.Color(0xFF212121);
  static const _lightBg = ui.Color(0xFFFCE4EC);
  static const _white = ui.Color(0xFFFFFFFF);

  static Future<List<Uint8List>> renderizarPropiedad({
    required List<String> rutasImagenes,
    required String operacion,
    required String direccion,
    required String ubicacion,
    required List<SpecItem> specs,
    required List<String> ambientes,
    required List<String> servicios,
    required String descripcion,
    required ui.Image logoImg,
    int totalFrames = 16,
  }) async {
    final imagenes = <ui.Image>[];
    for (final ruta in rutasImagenes) {
      try {
        final bytes = await File(ruta).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        imagenes.add(frame.image);
      } catch (_) {
        for (final img in imagenes) {
          img.dispose();
        }
        rethrow;
      }
    }

    final descMeasure = _buildParagraph(
      descripcion,
      ui.TextStyle(
        fontSize: 20,
        fontWeight: ui.FontWeight.w400,
        height: 1.6,
        color: _dark,
      ),
      maxWidth: contentW,
    );
    final descFullHeight = descMeasure.height;
    final maxScroll = descFullHeight > _descEstMaxHeight
        ? -(_descEstMaxHeight - 16)
        : 0.0;

    final frames = <Uint8List>[];
    final imgCount = imagenes.length;

    for (int f = 0; f < totalFrames; f++) {
      final scrollOffset = maxScroll == 0
          ? 0.0
          : maxScroll * f / (totalFrames - 1);
      final ui.Image? img;
      if (imgCount > 0) {
        final perImage = totalFrames ~/ imgCount;
        final idx = f ~/ perImage;
        img = imagenes[idx.clamp(0, imgCount - 1)];
      } else {
        img = null;
      }
      final png = await _renderizarFrame(
        imagenActual: img,
        operacion: operacion,
        direccion: direccion,
        ubicacion: ubicacion,
        specs: specs,
        ambientes: ambientes,
        servicios: servicios,
        descripcion: descripcion,
        descScrollOffset: scrollOffset,
        descFullHeight: descFullHeight,
        logoImg: logoImg,
      );
      frames.add(png);
    }

    for (final img in imagenes) {
      img.dispose();
    }
    return frames;
  }

  static Future<Uint8List> _renderizarFrame({
    required ui.Image? imagenActual,
    required String operacion,
    required String direccion,
    required String ubicacion,
    required List<SpecItem> specs,
    required List<String> ambientes,
    required List<String> servicios,
    required String descripcion,
    required double descScrollOffset,
    required double descFullHeight,
    required ui.Image logoImg,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, width, height),
    );

    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width, height),
      ui.Paint()..color = _white,
    );

    // ── Image area ──
    double y;

    if (imagenActual != null) {
      final imgW = imagenActual.width.toDouble();
      final imgH = imagenActual.height.toDouble();
      final scale = width / imgW;
      final drawH = imgH * scale;

      if (drawH > imageAreaHeight * 1.5) {
        // ── Tall image: overlay — content drawn on image ──
        final double imgMaxH = height * 0.62;
        final double imgBottom = drawH < imgMaxH ? drawH : imgMaxH;
        final double sourceH = imgBottom / scale;

        canvas.drawImageRect(
          imagenActual,
          ui.Rect.fromLTWH(0, 0, imgW, sourceH),
          ui.Rect.fromLTWH(0, 0, width, imgBottom),
          ui.Paint(),
        );

        y = imgBottom - 150;
      } else {
        // ── Normal image (fits in area) ──
        final offY = (imageAreaHeight - drawH) / 2;
        canvas.drawImageRect(
          imagenActual,
          ui.Rect.fromLTWH(0, 0, imgW, imgH),
          ui.Rect.fromLTWH(0, offY, width, drawH),
          ui.Paint(),
        );
        y = imageAreaHeight;
      }
    } else {
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, width, imageAreaHeight),
        ui.Paint()..color = const ui.Color(0xFFF5F5F5),
      );
      final noImgPara = _buildParagraph(
        'Sin fotos',
        ui.TextStyle(fontSize: 24, color: const ui.Color(0xFFBDBDBD)),
        maxWidth: width,
      );
      canvas.drawParagraph(
        noImgPara,
        ui.Offset((width - noImgPara.width) / 2,
            (imageAreaHeight - noImgPara.height) / 2),
      );
      y = imageAreaHeight;
    }

    // ── Content panel (always drawn; on top of image in overlay mode) ──
    // Magenta bar
    y += 20;
    canvas.drawRect(
      ui.Rect.fromLTWH(marginX, y, contentW, 5),
      ui.Paint()..color = _magenta,
    );
    y += 5 + 16;

    // Operation badge
    final opPara = _buildParagraph(
      operacion.toUpperCase(),
      ui.TextStyle(
        color: _magenta,
        fontSize: 46,
        fontWeight: ui.FontWeight.w800,
        fontStyle: ui.FontStyle.italic,
        letterSpacing: -0.5,
      ),
      maxWidth: contentW,
    );
    canvas.drawParagraph(opPara, ui.Offset(marginX, y));
    y += opPara.height + 8;

    // Address
    final addrText =
        direccion + (ubicacion.isNotEmpty ? ', $ubicacion' : '');
    final addrPara = _buildParagraph(
      addrText,
      ui.TextStyle(fontSize: 22, color: _gray),
      maxWidth: contentW,
    );
    canvas.drawParagraph(addrPara, ui.Offset(marginX, y));
    y += addrPara.height + 12;

    // Gray separator
    canvas.drawRect(
      ui.Rect.fromLTWH(marginX, y, contentW, 2),
      ui.Paint()..color = const ui.Color(0xFFE0E0E0),
    );
    y += 2 + 16;

    // Specs
    y = _drawSpecs(canvas, specs, y);
    y += 12;

    // Ambientes
    y = _drawAmbientes(canvas, ambientes, y);
    y += 12;

    // Servicios
    y = _drawServicios(canvas, servicios, y);
    y += 16;

    // ── Description (scrollable) ──
    final descAreaY = y;
    const descAreaMaxH = logoY - 16;
    final descVisibleH = descAreaMaxH - descAreaY;

    canvas.save();
    canvas.clipRect(ui.Rect.fromLTWH(
      marginX,
      descAreaY,
      contentW,
      descVisibleH,
    ));

    if (descripcion.isNotEmpty) {
      final descPara = _buildParagraph(
        descripcion,
        ui.TextStyle(
          fontSize: 20,
          fontWeight: ui.FontWeight.w400,
          height: 1.6,
          color: _dark,
        ),
        maxWidth: contentW,
      );
      canvas.drawParagraph(
        descPara,
        ui.Offset(marginX, descAreaY + descScrollOffset),
      );
    }

    canvas.restore();

    // Fade gradient at bottom of description
    if (descFullHeight > descVisibleH) {
      final fadeRect = ui.Rect.fromLTWH(
        marginX,
        descAreaY + descVisibleH - 40,
        contentW,
        40,
      );
      final gradient = ui.Gradient.linear(
        ui.Offset(0, fadeRect.top),
        ui.Offset(0, fadeRect.bottom),
        [const ui.Color(0x00FFFFFF), const ui.Color(0xFFFFFFFF)],
      );
      canvas.drawRect(fadeRect, ui.Paint()..shader = gradient);
    }

    // ── Logo + brand ──
    _drawLogo(canvas, logoImg);

    // ── Footer bar ──
    const footerY = height - 50;
    canvas.drawRect(
      ui.Rect.fromLTWH(0, footerY, width, 50),
      ui.Paint()..color = _magenta,
    );
    final footerPara = _buildParagraph(
      'BLANDENGUES 188 - S.M. DEL MONTE  |  22271412950 / 2226546317',
      ui.TextStyle(
        color: _white,
        fontSize: 16,
        fontWeight: ui.FontWeight.w500,
        letterSpacing: 1,
      ),
      maxWidth: width - 120,
    );
    canvas.drawParagraph(
      footerPara,
      ui.Offset((width - footerPara.width) / 2, footerY + 16),
    );

    // ── Renderizar a PNG ──
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(width.toInt(), height.toInt());
    final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
    rendered.dispose();
    picture.dispose();
    return data!.buffer.asUint8List();
  }

  // ── Specs cards with Material Icons ──
  static double _drawSpecs(
      ui.Canvas canvas, List<SpecItem> specs, double y) {
    final iconMap = <String, int>{
      'Dorm.': Icons.bed.codePoint,
      'Ba\u00f1os': Icons.bathtub.codePoint,
      'Cochera': Icons.directions_car.codePoint,
      'm\u00b2 Lote': Icons.straighten.codePoint,
      'm\u00b2 Casa': Icons.home.codePoint,
    };

    double x = marginX;
    const double cardW = 176;
    const double cardH = 88;
    const double gap = 12;

    for (int i = 0; i < specs.length && i < 5; i++) {
      if (x + cardW > width - marginX) {
        x = marginX;
        y += cardH + gap;
      }

      // Card background
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(x, y, cardW, cardH),
          const ui.Radius.circular(14),
        ),
        ui.Paint()..color = _lightBg,
      );

      // Icon
      final cp = iconMap[specs[i].label] ?? Icons.room_preferences.codePoint;
      final iconPara = _buildIconPara(cp, 28, _magenta);
      canvas.drawParagraph(iconPara, ui.Offset(x + 14, y + 12));

      // Value
      final valPara = _buildParagraph(
        specs[i].value,
        ui.TextStyle(
          fontSize: 24,
          fontWeight: ui.FontWeight.w800,
          color: _magenta,
        ),
        maxWidth: cardW - 28,
      );
      canvas.drawParagraph(
          valPara, ui.Offset(x + 14, y + 48));

      // Label
      final labelPara = _buildParagraph(
        specs[i].label,
        ui.TextStyle(
          fontSize: 13,
          fontWeight: ui.FontWeight.w600,
          color: _darkMagenta,
        ),
        maxWidth: cardW - 28,
      );
      canvas.drawParagraph(
          labelPara, ui.Offset(x + 48, y + 16));

      x += cardW + gap;
    }

    return y + cardH;
  }

  // ── Ambiente grid ──
  static final Map<String, int> _ambienteIconCp = {
    'cocina': Icons.kitchen.codePoint,
    'comedor': Icons.dining.codePoint,
    'cocina-comedor': Icons.restaurant.codePoint,
    'living': Icons.weekend.codePoint,
    'living comedor': Icons.living.codePoint,
    'comedor diario': Icons.table_restaurant.codePoint,
    'lavadero': Icons.local_laundry_service.codePoint,
    'patio': Icons.deck.codePoint,
    'balcón': Icons.balcony.codePoint,
    'terraza': Icons.roofing.codePoint,
    'quincho': Icons.outdoor_grill.codePoint,
    'pileta': Icons.pool.codePoint,
    'jardín': Icons.yard.codePoint,
    'hall': Icons.door_front_door.codePoint,
    'escritorio': Icons.desk.codePoint,
    'vestidor': Icons.checkroom.codePoint,
    'toilette': Icons.wash.codePoint,
    'galería': Icons.roofing.codePoint,
    'sótano': Icons.stairs.codePoint,
    'altillo': Icons.arrow_upward.codePoint,
    'depósito': Icons.inventory_2.codePoint,
    'dormitorio': Icons.bed.codePoint,
    'baño': Icons.bathtub.codePoint,
    'cochera': Icons.directions_car.codePoint,
  };

  static double _drawAmbientes(
      ui.Canvas canvas, List<String> ambientes, double y) {
    if (ambientes.isEmpty) return y;

    final titlePara = _buildParagraph(
      'AMBIENTES',
      ui.TextStyle(
        fontSize: 16,
        fontWeight: ui.FontWeight.w700,
        color: _dark,
      ),
      maxWidth: contentW,
    );
    canvas.drawParagraph(titlePara, ui.Offset(marginX, y));
    y += titlePara.height + 8;

    const int cols = 3;
    const double gap = 14;
    const double cellW = (contentW - (cols - 1) * gap) / cols;
    const double cellH = 82;

    for (int i = 0; i < ambientes.length; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final xPos = marginX + col * (cellW + gap);
      final yPos = y + row * (cellH + gap);

      // Card background
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(xPos, yPos, cellW, cellH),
          const ui.Radius.circular(12),
        ),
        ui.Paint()..color = _lightBg,
      );

      // Card border
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(xPos, yPos, cellW, cellH),
          const ui.Radius.circular(12),
        ),
        ui.Paint()
          ..color = _magenta.withValues(alpha: 0.15)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Icon
      final iconCp = _ambienteIconCp[ambientes[i].toLowerCase()] ??
          Icons.meeting_room.codePoint;
      final iconPara = _buildIconPara(iconCp, 28, _magenta);
      canvas.drawParagraph(
        iconPara,
        ui.Offset(
          xPos + (cellW - iconPara.width) / 2,
          yPos + 16,
        ),
      );

      // Label
      final labelPara = _buildParagraph(
        ambientes[i],
        ui.TextStyle(
          fontSize: 16,
          fontWeight: ui.FontWeight.w600,
          color: _darkMagenta,
        ),
        maxWidth: cellW - 16,
      );
      canvas.drawParagraph(
        labelPara,
        ui.Offset(
          xPos + (cellW - labelPara.width) / 2,
          yPos + 16 + 28 + 4,
        ),
      );
    }

    final rows = (ambientes.length + cols - 1) ~/ cols;
    return y + rows * cellH + (rows - 1) * gap + 4;
  }

  // ── Servicios list ──
  static double _drawServicios(
      ui.Canvas canvas, List<String> servicios, double y) {
    if (servicios.isEmpty) return y;

    final titlePara = _buildParagraph(
      'SERVICIOS',
      ui.TextStyle(
        fontSize: 16,
        fontWeight: ui.FontWeight.w700,
        color: _dark,
      ),
      maxWidth: contentW,
    );
    canvas.drawParagraph(titlePara, ui.Offset(marginX, y));
    y += titlePara.height + 8;

    const double colGap = 16;
    const double colW = (contentW - colGap) / 2;
    const double itemH = 26;
    final int rows = ((servicios.length) + 1) ~/ 2;

    for (int i = 0; i < servicios.length; i++) {
      final col = i % 2;
      final row = i ~/ 2;
      final xPos = marginX + col * (colW + colGap);
      final yPos = y + row * itemH;

      // Check icon
      final checkPara = _buildIconPara(Icons.check_circle.codePoint, 18, _magenta);
      canvas.drawParagraph(checkPara, ui.Offset(xPos, yPos));

      // Text
      final txtPara = _buildParagraph(
        servicios[i],
        ui.TextStyle(fontSize: 17, color: _dark),
        maxWidth: colW - 26,
      );
      canvas.drawParagraph(txtPara, ui.Offset(xPos + 24, yPos));
    }

    return y + rows * itemH + 4;
  }

  // ── Logo + brand ──
  static void _drawLogo(ui.Canvas canvas, ui.Image logoImg) {
    const double logoSize = 70;

    // Center logo area: logo left, text right
    final logoText = 'COPPOLA PAVESE';
    final subText = 'INMOBILIARIA';
    final logoTextPara = _buildParagraph(
      logoText,
      ui.TextStyle(
        fontSize: 22,
        fontWeight: ui.FontWeight.w700,
        color: _magenta,
        letterSpacing: 2,
      ),
      maxWidth: 400,
    );
    final subPara = _buildParagraph(
      subText,
      ui.TextStyle(
        fontSize: 14,
        color: _gray,
        letterSpacing: 4,
      ),
      maxWidth: 400,
    );
    final brandW = logoTextPara.width > subPara.width
        ? logoTextPara.width
        : subPara.width;
    final totalW = logoSize + 16 + brandW;
    final startX = (width - totalW) / 2;

    // Circular logo clip
    final circlePath = ui.Path()
      ..addOval(ui.Rect.fromLTWH(startX, logoY, logoSize, logoSize));
    canvas.save();
    canvas.clipPath(circlePath);
    canvas.drawImageRect(
      logoImg,
      ui.Rect.fromLTWH(
          0, 0, logoImg.width.toDouble(), logoImg.height.toDouble()),
      ui.Rect.fromLTWH(startX, logoY, logoSize, logoSize),
      ui.Paint(),
    );
    canvas.restore();

    // Text
    canvas.drawParagraph(
        logoTextPara, ui.Offset(startX + logoSize + 16, logoY + 8));
    canvas.drawParagraph(
        subPara, ui.Offset(startX + logoSize + 16, logoY + 8 + logoTextPara.height));
  }

  // ── Paragraph builders ──

  static ui.Paragraph _buildParagraph(
    String text,
    ui.TextStyle style, {
    double maxWidth = 960,
  }) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: ui.TextAlign.left,
      maxLines: 0x7FFFFFFF,
    ))
      ..pushStyle(style)
      ..addText(text);
    final para = builder.build();
    para.layout(ui.ParagraphConstraints(width: maxWidth));
    return para;
  }

  static ui.Paragraph _buildIconPara(int codePoint, double size, ui.Color color) {
    final iconStyle = ui.TextStyle(
      color: color,
      fontSize: size,
      fontFamily: 'MaterialIcons',
    );
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: ui.TextAlign.left,
    ))
      ..pushStyle(iconStyle)
      ..addText(String.fromCharCode(codePoint));
    final para = builder.build();
    para.layout(ui.ParagraphConstraints(width: size * 1.5));
    return para;
  }
}

class SpecItem {
  final String label;
  final String value;
  const SpecItem({required this.label, required this.value});
}
