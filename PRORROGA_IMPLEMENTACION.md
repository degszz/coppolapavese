# Resumen Técnico: Implementación de Prórroga en Formulario de Contratos Flutter



## Estado General

- **Migración BD**: ✅ Completa (v11 - tablas `prorrogas` y `prorroga_periodos`)

- **Modelo**: ✅ Completo (`ProrrogaModel` + `ProrrogaPeriodoModel`)

- **CRUD BD**: ✅ Completo (todos los métodos en `database_helper.dart`)

- **Formulario Contrato (UI)**: ✅ ~95% completo (`contrato_form_screen.dart`)

- **Lista Contratos**: ❌ Pendiente (no muestra prórroga en detalle)

- **Recibos (notas pie)**: ❌ Pendiente (falta `obtenerTodosLosPeriodos`)



---



## 1. Modelo de Datos (`lib/models/prorroga_model.dart`)



### `ProrrogaModel`

| Campo | Tipo | Descripción |

|-------|------|-------------|

| `id` | `int?` | PK autoincremental |

| `contratoId` | `int` | FK → contratos.id |

| `fechaInicio` | `String` | ISO 8601 (YYYY-MM-DD) |

| `fechaFin` | `String` | ISO 8601 |

| `cuotasTotal` | `int` | Total cuotas de la prórroga |

| `montoBase` | `double` | Monto base de la prórroga |

| `activa` | `bool` | Solo 1 activa por contrato |

| `fechaCreacion` | `String` | ISO 8601 timestamp |

| `periodos` | `List<ProrrogaPeriodoModel>` | Períodos internos de la prórroga |



**Métodos**: `toMap()`, `fromMap()`, `copyWith()`



### `ProrrogaPeriodoModel`

| Campo | Tipo | Descripción |

|-------|------|-------------|

| `id` | `int?` | PK autoincremental |

| `prorrogaId` | `int` | FK → prorrogas.id |

| `cuotaDesde` | `int` | Cuota inicial del período (absoluta) |

| `cuotaHasta` | `int` | Cuota final del período (absoluta) |

| `monto` | `double` | Monto del alquiler en este período |

| `porcentaje` | `double` | % aumento (default 0) |



**Métodos**: `toMap()`, `fromMap()`, `copyWith()`



---



## 2. Migración BD v11 (`database_helper.dart`)



```dart

// version: 11

// Tablas creadas en _migrarV11:



CREATE TABLE prorrogas (

  id INTEGER PRIMARY KEY AUTOINCREMENT,

  contrato_id INTEGER NOT NULL,

  fecha_inicio TEXT,

  fecha_fin TEXT,

  cuotas_total INTEGER NOT NULL DEFAULT 0,

  monto_base REAL NOT NULL DEFAULT 0,

  activa INTEGER NOT NULL DEFAULT 1,

  fecha_creacion TEXT,

  FOREIGN KEY (contrato_id) REFERENCES contratos(id) ON DELETE CASCADE

);



CREATE TABLE prorroga_periodos (

  id INTEGER PRIMARY KEY AUTOINCREMENT,

  prorroga_id INTEGER NOT NULL,

  cuota_desde INTEGER NOT NULL,

  cuota_hasta INTEGER NOT NULL,

  monto REAL NOT NULL DEFAULT 0,

  porcentaje REAL NOT NULL DEFAULT 0,

  FOREIGN KEY (prorroga_id) REFERENCES prorrogas(id) ON DELETE CASCADE

);

3. CRUD Prórroga en database_helper.dart ✅ COMPLETO

Método

insertarProrroga(data)

actualizarProrroga(id, data)

eliminarProrroga(id)

obtenerProrrogasPorContrato(contratoId)

obtenerProrrogaActiva(contratoId)

desactivarProrrogasAnteriores(contratoId, exceptoId?)

insertarProrrogaPeriodo(data)

upsertProrrogaPeriodos(prorrogaId, periodos[])

obtenerProrrogaPeriodos(prorrogaId)

insertarProrrogaPeriodo(data)

Métodos auxiliares:

- obtenerProximaCuota(contratoId) → MAX(numero_cuota)+1 desde recibos

- actualizarCuotaInicialYMesContrato(contratoId, nuevaCuota, nuevoMes) → Sincroniza al emitir recibo

- obtenerMesesConRecibos(contratoId) → Meses (1-12) con recibos emitidos (para filtros)

4. Formulario Contrato (contrato_form_screen.dart) ✅ 95% COMPLETO

Estado (líneas ~88-102)

ProrrogaModel? _prorroga;

List<ProrrogaModel> _prorrogasContrato = [];

bool _prorrogaExpandida = false;

bool _prorrogaEliminada = false;



// Controllers principales

_prorrogaFechaInicioCtrl, _prorrogaFechaFinCtrl

_prorrogaCuotasCtrl, _prorrogaMontoCtrl



// Período 1 (principal)

_prorrogaAlquilerCtrl, _prorrogaHastaCuotaCtrl

_prorrogaPorcentajeCtrl, _prorrogaVaPorCtrl, _prorrogaMesCtrl



// Períodos extra (desde el 2do en adelante)

List<_ProrrogaPeriodoRow> _prorrogaPeriodosExtra = [];

_ProrrogaPeriodoRow (clase interna)

class _ProrrogaPeriodoRow {

  final TextEditingController montoCtrl;

  final TextEditingController hastaCtrl;

  final TextEditingController porcentajeCtrl;

  final TextEditingController vaPorCtrl;

  final TextEditingController mesCtrl;

  int cuotaDesde;

}

Métodos Principales Implementados

Método Línea aprox Descripción

_cargarProrroga(contratoId) ~1420 Carga prórroga activa + períodos, popula controllers

_guardarProrroga(contratoId) ~1480 Inserta/actualiza prórroga + desactiva anteriores + upsertProrrogaPeriodos

_hayDatosProrroga() ~1554 Verifica si hay datos en UI para decidir guardar

_buildValidacionPeriodosProrroga() ~1560 Valida que cuotas no excedan cuotasTotal

_seccionProrroga() ~1610 UI completa: card expandible con botón "Agregar prórroga", campos fecha/cuotas/monto, tabla períodos con columnas: Cuotas, Monto, Hasta mes, % Aum., Va por, Mes

_seleccionarProrrogaFechaInicio/Fin() ~1970 Date pickers

_agregarProrrogaPeriodoManual() ~2010 Agrega fila extra calculando desde = último_hasta + 1

_eliminarProrrogaPeriodoExtra(index) ~2040 Elimina fila y dispose controllers

_buildExtraProrrogaPeriodos() ~2050 Renderiza filas extra con botón delete

Getters Auxiliares

int get _prorrogaDesdeBase { 

  // Último período fijo cuota_hasta + 1, o 1 si no hay fijos

}

Flujo "Quitar Prórroga" (línea ~1641)

onTap: () => setState(() {

  _prorrogaEliminada = _prorroga != null; // Marca para borrar en BD al guardar

  _prorrogaExpandida = false;

  _prorroga = null;

  // ... limpia controllers ...

});

En _guardarProrroga: si _prorrogaEliminada → borra la activa de BD y return.

5. Qué FALTA Completar ❌

A. database_helper.dart - Método Faltante

// NECESARIO para fusionar períodos fijos + prórroga en recibos y lista

Future<List<Map<String, dynamic>>> obtenerTodosLosPeriodos(int contratoId) async {

  // 1. Períodos fijos (periodos_fijos WHERE contrato_id ORDER BY cuota_desde)

  // 2. Períodos prórroga (JOIN prorroga_periodos + prorrogas WHERE activa=1)

  // 3. Combinar + sort por cuota_desde ASC

  // 4. Retornar lista unificada

}

Uso crítico: _generarNotaPeriodo en recibo_form_screen.dart y visualización en lista de contratos.

B. contratos_list_screen.dart - Visualización Prórroga

- En _cargarDatosCompletos: ya carga _prorroga y _prorrogaPeriodos ✅

- FALTA: Método _buildProrroga(Map<String, dynamic> c) que retorne widgets:

- Si no hay prórroga → []

- Si hay → Card azul con: fechas, cuotas total, monto base, tabla períodos (Cuotas, Monto, % Aum., Va por)

- En build (ROW 4): agregar ..._buildProrroga(c) debajo de _buildPeriodos(c)

C. recibo_form_screen.dart - Notas de Período

- _generarNotaPeriodo ya implementado con lógica corregida (penúltima = "próximo a vencer", última = "aumento de periodo") ✅

- FALTA: Usar obtenerTodosLosPeriodos en lugar de obtenerPeriodosPorContrato en:

- _seleccionarContrato (línea ~359)

- _siguientePeriodo (línea ~668)

- _periodoAnterior (línea ~749)

- Así la nota al pie considera tanto períodos fijos como de prórroga continuados.

D. Corrección "Va por" en Lista (Opcional)

En _buildPeriodos y _buildProrroga:

- Cambiar cuotaManual = c['cuota_inicial'] → cuotaManual = c['_ultimo_numero_cuota'] (último recibo emitido)

- Si 0 (sin recibos) → mostrar 1 o cuota_desde del primer período

6. Archivos a Tocar para Completar

Archivo Acción

database_helper.dart Agregar obtenerTodosLosPeriodos()

contratos_list_screen.dart Agregar _buildProrroga() + llamarlo en ROW 4

recibo_form_screen.dart Cambiar 3 llamadas a obtenerPeriodosPorContrato → obtenerTodosLosPeriodos

contrato_form_screen.dart (Opcional) Ajustar "Va por" si se quiere mostrar último recibo

7. Dependencias entre Componentes

database_helper.dart (obtenerTodosLosPeriodos)

       │

       ├──────────────────┬──────────────────┐

       ▼                  ▼                  ▼

contrato_form      contratos_list      recibo_form

   (OK)              (FALTA _build)    (FALTA usar método)

8. Testing Checklist

- Crear contrato con período fijo 1→12

- Agregar prórroga 13→24 con 2 períodos (13→18 monto X, 19→24 monto Y + %)

- Guardar → Reabrir edición → Verificar datos persisten

- Emitir recibo cuota 12 → Nota "aumento de periodo"

- Emitir recibo cuota 13 → Descripción correcta, monto correcto

- Emitir recibo cuota 18 → Nota "aumento de periodo"  

- Emitir recibo cuota 24 → Nota "próximo a vencer"

- Lista contratos: ver badge/períodos de prórroga expandido

- Quitar prórroga → Guardar → Verificar BD limpia

