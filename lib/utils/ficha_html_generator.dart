import 'dart:convert';
import 'dart:io';

class FichaHtmlGenerator {
  static const _telefonos = '22271412950 / 2226546317';
  static const _direccion = 'Blandengues 188 - S.M. del Monte';
  static const _email = 'coppolapavese@gmail.com';

  static Future<String> generar({
    required Map<String, dynamic> propiedad,
    required Map<String, dynamic> ficha,
    required List<Map<String, dynamic>> imagenes,
    String? logoPath,
  }) async {
    final operacion = ficha['operacion'] as String? ?? 'Alquiler';
    final dormitorios = ficha['dormitorios'] as int? ?? 0;
    final banos = ficha['banos'] as int? ?? 0;
    final cochera = ficha['cochera'] as int? ?? 0;
    final supTotal = (ficha['superficie_total'] as num?)?.toDouble() ?? 0;
    final supCubierta = (ficha['superficie_cubierta'] as num?)?.toDouble() ?? 0;
    final descripcion = ficha['descripcion'] as String? ?? '';
    final ubicacionFicha = ficha['ubicacion_ficha'] as String? ?? '';

    final tipo = propiedad['tipo'] as String? ?? 'Propiedad';
    final barrio = propiedad['barrio'] as String? ?? '';
    final localidad = propiedad['localidad'] as String? ?? '';
    final direccionProp = propiedad['direccion'] as String? ?? '';

    final ubicacionBarra = ubicacionFicha.isNotEmpty
        ? ubicacionFicha.toUpperCase()
        : [
            tipo.toUpperCase(),
            if (barrio.isNotEmpty) 'EN ${barrio.toUpperCase()}',
            if (barrio.isEmpty && localidad.isNotEmpty) 'EN ${localidad.toUpperCase()}',
          ].join(' ');

    List<String> ambientesLista = [];
    List<String> serviciosLista = [];
    try {
      ambientesLista = List<String>.from(jsonDecode(ficha['ambientes_lista'] as String? ?? '[]'));
    } catch (_) {}
    try {
      serviciosLista = List<String>.from(jsonDecode(ficha['servicios_lista'] as String? ?? '[]'));
    } catch (_) {}

    // Convertir imágenes a base64
    final imagenesBase64 = <String>[];
    for (final img in imagenes) {
      try {
        final bytes = await File(img['ruta'] as String).readAsBytes();
        final ext = (img['ruta'] as String).toLowerCase();
        final mime = ext.endsWith('.png') ? 'image/png' : 'image/jpeg';
        imagenesBase64.add('data:$mime;base64,${base64Encode(bytes)}');
      } catch (_) {}
    }

    // Logo base64
    String logoBase64 = '';
    if (logoPath != null) {
      try {
        final bytes = await File(logoPath).readAsBytes();
        logoBase64 = 'data:image/png;base64,${base64Encode(bytes)}';
      } catch (_) {}
    }

    // Build specs HTML
    final specsHtml = StringBuffer();
    if (dormitorios > 0) {
      specsHtml.write(_specCard('bed', '$dormitorios', 'Habitacion${dormitorios > 1 ? 'es' : ''}'));
    }
    if (banos > 0) {
      specsHtml.write(_specCard('shower', '$banos', 'Ba\u00f1o${banos > 1 ? 's' : ''}'));
    }
    if (cochera > 0) {
      specsHtml.write(_specCard('directions_car', '$cochera', 'Cochera${cochera > 1 ? 's' : ''}'));
    }
    if (supTotal > 0) {
      specsHtml.write(_specCard('straighten', '${supTotal.toStringAsFixed(0)}', 'm\u00b2 Lote'));
    }
    if (supCubierta > 0) {
      specsHtml.write(_specCard('home', '${supCubierta.toStringAsFixed(0)}', 'm\u00b2 Casa'));
    }

    // Build ambientes HTML
    final ambientesHtml = ambientesLista.map((a) {
      final icono = _iconoAmbiente(a);
      return '<div class="ambiente-card"><span class="material-symbols-outlined ambiente-icon">$icono</span><span class="ambiente-label">${_escapeHtml(a)}</span></div>';
    }).join('\n');

    // Build servicios HTML
    final serviciosHtml = serviciosLista.map((s) =>
        '<li><span class="material-symbols-outlined serv-icon">check_circle</span>${_escapeHtml(s)}</li>'
    ).join('\n');

    return '''<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${_escapeHtml(direccionProp)} - Coppola Pavese Inmobiliaria</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@24,400,1,0" rel="stylesheet">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Inter',system-ui,-apple-system,sans-serif;background:#f0f0f0;color:#212121}
.page{max-width:900px;margin:0 auto;background:#fff;min-height:100vh;box-shadow:0 0 40px rgba(0,0,0,.1)}

/* Header */
.header{display:flex;align-items:center;justify-content:space-between;padding:16px 24px;border-bottom:1px solid #f0f0f0}
.header-left{display:flex;align-items:center;gap:12px}
.logo-img{width:44px;height:44px;border-radius:50%;object-fit:cover}
.brand-name{font-size:16px;font-weight:700;color:#212121}
.brand-sub{font-size:9px;color:#9e9e9e;letter-spacing:2.5px;text-transform:uppercase}
.header-right{text-align:right}
.header-right p{font-size:11px;color:#757575;line-height:1.7}
.header-right .email{color:#C2185B;font-weight:500}

/* Carousel */
.carousel-wrapper{position:relative;width:100%;background:#111}
.carousel{position:relative;width:100%;aspect-ratio:16/9;overflow:hidden;cursor:pointer}
.carousel img{width:100%;height:100%;object-fit:cover;display:none;transition:opacity .3s}
.carousel img.active{display:block}
.carousel-btn{position:absolute;top:50%;transform:translateY(-50%);background:rgba(0,0,0,.5);color:#fff;border:none;width:48px;height:48px;border-radius:50%;font-size:24px;cursor:pointer;display:flex;align-items:center;justify-content:center;transition:all .2s;z-index:2}
.carousel-btn:hover{background:rgba(194,24,91,.85);transform:translateY(-50%) scale(1.05)}
.carousel-btn.prev{left:14px}
.carousel-btn.next{right:14px}
.carousel-counter{position:absolute;bottom:14px;right:14px;background:rgba(0,0,0,.6);color:#fff;padding:5px 14px;border-radius:20px;font-size:13px;font-weight:500;z-index:2}
.carousel-zoom-hint{position:absolute;bottom:14px;left:14px;background:rgba(0,0,0,.6);color:#fff;padding:5px 12px;border-radius:20px;font-size:11px;font-weight:400;z-index:2;display:flex;align-items:center;gap:4px}
.carousel-zoom-hint .material-symbols-outlined{font-size:16px}
.carousel-empty{width:100%;aspect-ratio:16/9;background:#f5f5f5;display:flex;align-items:center;justify-content:center;color:#bdbdbd;font-size:18px}

/* Thumbnails */
.thumbnails{display:flex;gap:6px;padding:8px 16px;overflow-x:auto;background:#fafafa}
.thumbnails img{width:80px;height:60px;object-fit:cover;border-radius:8px;cursor:pointer;border:3px solid transparent;transition:all .2s;flex-shrink:0;opacity:.7}
.thumbnails img.active{border-color:#C2185B;opacity:1}
.thumbnails img:hover{opacity:1;border-color:#E91E63}

/* Lightbox */
.lightbox{display:none;position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,.92);z-index:1000;align-items:center;justify-content:center;flex-direction:column}
.lightbox.open{display:flex}
.lightbox-img{max-width:90vw;max-height:80vh;object-fit:contain;border-radius:8px;box-shadow:0 0 60px rgba(0,0,0,.5)}
.lightbox-close{position:absolute;top:16px;right:20px;background:none;border:none;color:#fff;font-size:36px;cursor:pointer;z-index:1001;width:48px;height:48px;display:flex;align-items:center;justify-content:center;border-radius:50%;transition:background .2s}
.lightbox-close:hover{background:rgba(255,255,255,.15)}
.lightbox-nav{position:absolute;top:50%;transform:translateY(-50%);background:rgba(255,255,255,.15);color:#fff;border:none;width:52px;height:52px;border-radius:50%;font-size:26px;cursor:pointer;display:flex;align-items:center;justify-content:center;transition:all .2s}
.lightbox-nav:hover{background:rgba(194,24,91,.8)}
.lightbox-nav.lb-prev{left:20px}
.lightbox-nav.lb-next{right:20px}
.lightbox-counter{position:absolute;bottom:20px;color:#fff;font-size:14px;font-weight:500;background:rgba(0,0,0,.5);padding:6px 18px;border-radius:20px}
.lightbox-thumbs{display:flex;gap:6px;position:absolute;bottom:60px;overflow-x:auto;max-width:90vw;padding:8px}
.lightbox-thumbs img{width:70px;height:50px;object-fit:cover;border-radius:6px;cursor:pointer;border:2px solid transparent;opacity:.5;transition:all .2s;flex-shrink:0}
.lightbox-thumbs img.active{border-color:#C2185B;opacity:1}
.lightbox-thumbs img:hover{opacity:.8}

/* Content area */
.content{padding:20px 24px}

/* Operation badge */
.operation{font-size:34px;font-weight:800;color:#C2185B;font-style:italic;letter-spacing:-0.5px;margin-bottom:4px}

/* Direccion */
.direccion-line{font-size:15px;color:#757575;margin-bottom:16px}

/* Two-column layout for desktop */
.content-grid{display:grid;grid-template-columns:1fr;gap:20px}

/* Specs */
.specs{display:flex;flex-wrap:wrap;gap:10px;margin-bottom:8px}
.spec-card{display:flex;align-items:center;gap:10px;background:#FCE4EC;padding:10px 16px;border-radius:12px;flex:0 0 auto}
.spec-icon{color:#C2185B;font-size:26px}
.spec-value{font-size:20px;font-weight:700;color:#C2185B}
.spec-label{font-size:12px;color:#880E4F;font-weight:500}

/* Ambientes */
.section{margin-bottom:16px}
.section-title{font-size:15px;font-weight:700;color:#212121;margin-bottom:12px;display:flex;align-items:center;gap:8px}
.section-title .material-symbols-outlined{font-size:22px;color:#C2185B}
.ambientes-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(140px,1fr));gap:10px}
.ambiente-card{display:flex;flex-direction:column;align-items:center;gap:6px;background:#FCE4EC;padding:14px 10px;border-radius:14px;text-align:center;transition:transform .15s}
.ambiente-card:hover{transform:translateY(-2px)}
.ambiente-icon{font-size:32px;color:#C2185B}
.ambiente-label{font-size:12px;font-weight:600;color:#880E4F}

/* Servicios */
.servicios-list{list-style:none;display:grid;grid-template-columns:1fr 1fr;gap:8px}
.servicios-list li{display:flex;align-items:center;gap:8px;font-size:13px;color:#424242;padding:6px 0}
.serv-icon{font-size:20px;color:#C2185B}

/* Descripcion */
.descripcion{font-size:14px;color:#616161;line-height:1.8;white-space:pre-wrap}

/* Location bar */
.location-bar{background:#C2185B;color:#fff;text-align:center;padding:16px 24px;font-size:17px;font-weight:700;letter-spacing:1.5px;margin-top:20px}

/* Footer */
.footer{background:#880E4F;color:#fff;text-align:center;padding:14px 24px}
.footer p{font-size:11px;font-weight:500;letter-spacing:0.5px}

/* Logo section */
.logo-section{display:flex;align-items:center;justify-content:center;gap:14px;padding:24px 24px 10px}
.logo-section img{width:56px;height:56px;border-radius:50%}
.logo-section .brand{text-align:center}
.logo-section .brand h3{font-size:14px;font-weight:700;color:#C2185B;line-height:1.3}
.logo-section .brand span{font-size:8px;color:#9e9e9e;letter-spacing:2.5px}

/* ══ Desktop responsive (768px+) ══ */
@media(min-width:768px){
  .content-grid{grid-template-columns:1fr 1fr;gap:28px}
  .ambientes-grid{grid-template-columns:repeat(auto-fill,minmax(130px,1fr))}
  .servicios-list{grid-template-columns:1fr 1fr 1fr}
  .specs{gap:14px}
  .spec-card{padding:12px 20px}
  .spec-icon{font-size:30px}
  .spec-value{font-size:22px}
  .spec-label{font-size:13px}
  .ambiente-card{padding:16px 12px}
  .ambiente-icon{font-size:36px}
  .ambiente-label{font-size:13px}
  .operation{font-size:40px}
  .direccion-line{font-size:16px}
  .section-title{font-size:16px}
  .header{padding:18px 32px}
  .content{padding:24px 32px}
  .thumbnails{padding:10px 20px;gap:8px}
  .thumbnails img{width:100px;height:70px}
}

/* ══ Large desktop (1100px+) ══ */
@media(min-width:1100px){
  .page{max-width:1080px}
  .ambientes-grid{grid-template-columns:repeat(auto-fill,minmax(140px,1fr))}
  .servicios-list{grid-template-columns:1fr 1fr 1fr 1fr}
}
</style>
</head>
<body>

<div class="page">
  <!-- Header -->
  <div class="header">
    <div class="header-left">
      ${logoBase64.isNotEmpty ? '<img src="$logoBase64" class="logo-img" alt="Logo">' : ''}
      <div>
        <div class="brand-name">Coppola Pavese</div>
        <div class="brand-sub">Inmobiliaria</div>
      </div>
    </div>
    <div class="header-right">
      <p>$_telefonos</p>
      <p class="email">$_email</p>
    </div>
  </div>

  <!-- Carousel -->
  ${imagenesBase64.isNotEmpty ? '''
  <div class="carousel-wrapper">
    <div class="carousel" id="carousel" onclick="abrirLightbox()">
      ${imagenesBase64.asMap().entries.map((e) => '<img src="${e.value}" alt="Foto ${e.key + 1}" ${e.key == 0 ? 'class="active"' : ''}>').join('\n      ')}
      ${imagenesBase64.length > 1 ? '''
      <button class="carousel-btn prev" onclick="event.stopPropagation();cambiarSlide(-1)">&#8249;</button>
      <button class="carousel-btn next" onclick="event.stopPropagation();cambiarSlide(1)">&#8250;</button>
      ''' : ''}
      <span class="carousel-counter" id="counter">1 / ${imagenesBase64.length}</span>
      <span class="carousel-zoom-hint"><span class="material-symbols-outlined">zoom_in</span>Click para ampliar</span>
    </div>
    ${imagenesBase64.length > 1 ? '''
    <div class="thumbnails" id="thumbs">
      ${imagenesBase64.asMap().entries.map((e) => '<img src="${e.value}" onclick="irASlide(${e.key})" ${e.key == 0 ? 'class="active"' : ''}>').join('\n      ')}
    </div>
    ''' : ''}
  </div>
  ''' : '<div class="carousel-empty">Sin fotos</div>'}

  <!-- Lightbox -->
  <div class="lightbox" id="lightbox" onclick="cerrarLightbox(event)">
    <button class="lightbox-close" onclick="cerrarLightboxForzar()">&times;</button>
    ${imagenesBase64.length > 1 ? '''
    <button class="lightbox-nav lb-prev" onclick="event.stopPropagation();navLightbox(-1)">&#8249;</button>
    <button class="lightbox-nav lb-next" onclick="event.stopPropagation();navLightbox(1)">&#8250;</button>
    ''' : ''}
    <img class="lightbox-img" id="lbImg" src="" alt="Imagen ampliada">
    <span class="lightbox-counter" id="lbCounter"></span>
    ${imagenesBase64.length > 1 ? '''
    <div class="lightbox-thumbs" id="lbThumbs">
      ${imagenesBase64.asMap().entries.map((e) => '<img src="${e.value}" onclick="event.stopPropagation();lbIrA(${e.key})" ${e.key == 0 ? 'class="active"' : ''}>').join('\n      ')}
    </div>
    ''' : ''}
  </div>

  <!-- Content -->
  <div class="content">
    <div class="operation">${_escapeHtml(operacion.toUpperCase())}</div>
    ${direccionProp.isNotEmpty ? '<div class="direccion-line">${_escapeHtml(direccionProp)}${localidad.isNotEmpty ? ', ${_escapeHtml(localidad)}' : ''}</div>' : ''}

    <!-- Specs -->
    ${specsHtml.isNotEmpty ? '<div class="specs">$specsHtml</div>' : ''}

    <div class="content-grid">
      <div>
        <!-- Ambientes -->
        ${ambientesLista.isNotEmpty ? '''
        <div class="section">
          <div class="section-title">
            <span class="material-symbols-outlined">meeting_room</span>
            Ambientes
          </div>
          <div class="ambientes-grid">
            $ambientesHtml
          </div>
        </div>
        ''' : ''}

        <!-- Descripcion -->
        ${descripcion.isNotEmpty ? '''
        <div class="section">
          <div class="section-title">
            <span class="material-symbols-outlined">description</span>
            Descripci\u00f3n
          </div>
          <p class="descripcion">${_escapeHtml(descripcion)}</p>
        </div>
        ''' : ''}
      </div>

      <div>
        <!-- Servicios -->
        ${serviciosLista.isNotEmpty ? '''
        <div class="section">
          <div class="section-title">
            <span class="material-symbols-outlined">electrical_services</span>
            Servicios
          </div>
          <ul class="servicios-list">
            $serviciosHtml
          </ul>
        </div>
        ''' : ''}

        <!-- Logo -->
        <div class="logo-section">
          ${logoBase64.isNotEmpty ? '<img src="$logoBase64" alt="Logo">' : ''}
          <div class="brand">
            <h3>COPPOLA<br>PAVESE</h3>
            <span>INMOBILIARIA</span>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- Location bar -->
  <div class="location-bar">${_escapeHtml(ubicacionBarra)}</div>

  <!-- Footer -->
  <div class="footer">
    <p>CONTACTO: $_telefonos  |  $_direccion</p>
  </div>
</div>

<script>
// ── Carousel ──
let actual=0;
const imgs=document.querySelectorAll('#carousel img');
const thumbs=document.querySelectorAll('#thumbs img');
const counter=document.getElementById('counter');
const total=imgs.length;

function mostrar(i){
  imgs.forEach(img=>img.classList.remove('active'));
  if(thumbs.length)thumbs.forEach(t=>t.classList.remove('active'));
  imgs[i].classList.add('active');
  if(thumbs.length){thumbs[i].classList.add('active');thumbs[i].scrollIntoView({behavior:'smooth',block:'nearest',inline:'center'})}
  if(counter)counter.textContent=(i+1)+' / '+total;
  actual=i;
}

function cambiarSlide(d){
  let n=actual+d;
  if(n<0)n=total-1;
  if(n>=total)n=0;
  mostrar(n);
}

function irASlide(i){mostrar(i)}

// Touch/swipe
let startX=0;
const car=document.getElementById('carousel');
if(car){
  car.addEventListener('touchstart',e=>{startX=e.touches[0].clientX},{passive:true});
  car.addEventListener('touchend',e=>{
    const diff=e.changedTouches[0].clientX-startX;
    if(Math.abs(diff)>50){diff>0?cambiarSlide(-1):cambiarSlide(1)}
  },{passive:true});
}

// ── Lightbox ──
const lightbox=document.getElementById('lightbox');
const lbImg=document.getElementById('lbImg');
const lbCounter=document.getElementById('lbCounter');
const lbThumbs=document.querySelectorAll('#lbThumbs img');
let lbActual=0;
const srcs=[${imagenesBase64.map((s) => "'$s'").join(',')}];

function abrirLightbox(){
  lbActual=actual;
  lbMostrar(lbActual);
  lightbox.classList.add('open');
  document.body.style.overflow='hidden';
}

function cerrarLightbox(e){
  if(e.target===lightbox){cerrarLightboxForzar()}
}

function cerrarLightboxForzar(){
  lightbox.classList.remove('open');
  document.body.style.overflow='';
}

function lbMostrar(i){
  lbImg.src=srcs[i];
  if(lbCounter)lbCounter.textContent=(i+1)+' / '+srcs.length;
  lbThumbs.forEach(t=>t.classList.remove('active'));
  if(lbThumbs[i]){lbThumbs[i].classList.add('active');lbThumbs[i].scrollIntoView({behavior:'smooth',block:'nearest',inline:'center'})}
  lbActual=i;
}

function navLightbox(d){
  let n=lbActual+d;
  if(n<0)n=srcs.length-1;
  if(n>=srcs.length)n=0;
  lbMostrar(n);
}

function lbIrA(i){lbMostrar(i)}

// Keyboard
document.addEventListener('keydown',e=>{
  if(lightbox.classList.contains('open')){
    if(e.key==='Escape')cerrarLightboxForzar();
    if(e.key==='ArrowLeft')navLightbox(-1);
    if(e.key==='ArrowRight')navLightbox(1);
  }else if(car){
    if(e.key==='ArrowLeft')cambiarSlide(-1);
    if(e.key==='ArrowRight')cambiarSlide(1);
  }
});

// Touch en lightbox
lightbox.addEventListener('touchstart',e=>{startX=e.touches[0].clientX},{passive:true});
lightbox.addEventListener('touchend',e=>{
  const diff=e.changedTouches[0].clientX-startX;
  if(Math.abs(diff)>50){diff>0?navLightbox(-1):navLightbox(1)}
},{passive:true});
</script>

</body>
</html>''';
  }

  static String _specCard(String icon, String value, String label) {
    return '''<div class="spec-card">
      <span class="material-symbols-outlined spec-icon">$icon</span>
      <span class="spec-value">$value</span>
      <span class="spec-label">$label</span>
    </div>''';
  }

  static String _iconoAmbiente(String ambiente) {
    switch (ambiente.toLowerCase()) {
      case 'cocina':
        return 'skillet';
      case 'comedor':
        return 'dining';
      case 'cocina-comedor':
        return 'restaurant';
      case 'living':
        return 'weekend';
      case 'living-comedor':
        return 'living';
      case 'lavadero':
        return 'local_laundry_service';
      case 'patio':
        return 'deck';
      case 'balcón':
        return 'balcony';
      case 'terraza':
        return 'roofing';
      case 'quincho':
        return 'outdoor_grill';
      case 'pileta':
        return 'pool';
      case 'jardín':
        return 'yard';
      case 'hall':
        return 'door_front';
      case 'escritorio':
        return 'desk';
      case 'vestidor':
        return 'checkroom';
      case 'toilette':
        return 'bathroom';
      case 'galería':
        return 'gallery_thumbnail';
      case 'sótano':
        return 'foundation';
      case 'altillo':
        return 'staircase';
      case 'depósito':
        return 'warehouse';
      default:
        return 'room_preferences';
    }
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
