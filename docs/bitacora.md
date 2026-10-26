# Bitácora

Volver a [[Inicio]]. Una entrada por sesión, la más nueva arriba. Corta: qué se
cambió, dónde y qué quedó pendiente. Claude la actualiza al terminar cada sesión.

## Pendientes

- [ ] Publicar v1.0.5 con los arreglos del 25/10 (todavía sin commit): paso A1 de [[guia-completa]].
- [ ] Día en la oficina: pasos B1–B14 de [[guia-completa]] (red, auto-actualización, acceso remoto).
- [ ] Corregir datos de prórrogas y "Va por" (lista en [[red-compartida]], sección "Datos a corregir").
- [ ] Lista de contratos: el "Alquiler" muestra el monto de la prórroga aunque todavía no empezó.
- [ ] Formulario de contrato: si agregás una prórroga nueva y cerrás la sección con la ✕
      antes de guardar, se descarta sin avisar.
- [ ] `README.md` es un resto de plantilla Astro: reemplazarlo por uno del proyecto.
- [ ] Probar en la app real: emitir/borrar un recibo y ver que el "Va por" vuelve atrás.

## 2026-10-26

- La host es **Windows 11** y la no-host **Windows 10**. Windows 11 24H2 bloquea el
  acceso sin contraseña: nuevo `scripts/crear-usuario-red.ps1` (usuario `cpred`) y la
  no-host guarda la clave con `cmdkey`. Guía reescrita paso a paso para el pendrive,
  con los menús de cada Windows.

## 2026-10-25

**Notas del pie del recibo**
- El aviso salía antes de tiempo en contratos con prórroga: los rangos de la prórroga
  (1–4) se comparaban con la cuota global y ganaban sobre el período fijo (1–6).
  Ahora, antes del ancla, solo cuentan los períodos fijos (`_generarNotaPeriodo` y
  `obtenerMontoPeriodo`).
- Borrar un recibo no volvía atrás el "Va por" → el recibo rehecho salía con una cuota
  de más y el aviso un mes antes. `eliminarRecibo` ahora lo revierte.
- Última cuota del contrato o de la prórroga: dice "próximo a vencer" en vez de
  "habrá aumento". Textos y casos: [[reglas-de-negocio]].

**Prórrogas**
- `obtenerNumCuotaParaContrato`: con prórroga ignoraba el "Va por"; ahora manda siempre.
- Ancla de prórrogas viejas sin recibos previos: daba 1 (todo el contrato como
  prórroga); ahora arranca después del último período fijo.
- El mes de las cuotas de prórroga avanza por cuota (antes todas mostraban el mismo).
- Alertas naranjas al armar el recibo: prórroga incompleta, cuota sin período, prórroga terminada.
- Editar contrato: la fecha de fin ya no se copia de la de inicio (se sugiere
  inicio + cuotas); no se puede guardar fin = inicio; se valida el "Va por" de cada
  período; el aviso de datos rotos detecta más casos.
- `mostrarNotificacion` acepta `duracion`.

**Red**: scripts corregidos y `diagnostico-red.ps1` nuevo (ver [[red-compartida]]).

**Auto-actualización**: el updater no podía conectarse con GitHub en Windows 10 (TLS);
podía borrar la base si la app estaba en la misma carpeta; no detectaba errores de
copia. Corregido y probado de punta a punta en una carpeta aislada. `publicar.ps1`
confirma antes de subir, frena si el repo está atrasado y escribe `lib/version.dart`;
el inicio de la app muestra la versión. `dist/` sale del repo (los zips viven en Releases).
Guía nueva: [[guia-completa]] (incluye acceso remoto con Chrome Remote Desktop).

**Organización**: `CLAUDE.md` + carpeta `docs/` para Obsidian.

## Sesiones anteriores (resumen)

- Todas las notificaciones pasan por `mostrarNotificacion` (con ✕ y 3 s).
- PDF del recibo con nombre `Recibo_<nro>_<Inquilino>.pdf` (también recibo en blanco).
- Inicio: recibos pendientes en 2 columnas, el más nuevo primero.
- Alta de inquilino desde Accesos rápidos: el selector de propietario no cargaba.
- Calendario: muestra recibos emitidos (verde) además de pendientes y vencidos.
- v1.0.1–1.0.4: auto-actualización por GitHub Releases, validación inline en rojo,
  prórroga con numeración propia ("Alquiler Prórroga N°x") y ancla `cuota_inicio_global`.
