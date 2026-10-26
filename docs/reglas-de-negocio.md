# Reglas de negocio: cuotas, períodos, prórrogas y avisos

Volver a [[Inicio]] · Código: `lib/screens/recibos/recibo_form_screen.dart`
(`_generarNotaPeriodo`) y `lib/database/database_helper.dart`.

## Número de cuota

- La cuota es **global** del contrato: 1, 2, 3… y sigue contando aunque haya prórroga.
- La **manda el "Va por"** del contrato (`contratos.cuota_inicial`, se edita en
  Editar contrato). Si está en 0, se usa la última cuota emitida + 1.
- Al **emitir** un recibo, el "Va por" pasa a la cuota siguiente y `mes_emision` avanza un mes.
- Al **borrar** el último recibo emitido, el "Va por" y el mes vuelven atrás (solo si el
  "Va por" apuntaba justo a la cuota siguiente: un "Va por" cargado a mano no se toca).

## Períodos fijos

- Tabla `periodos_fijos`: rangos de cuotas **globales** con su monto (ej. 1–6 $250.000,
  7–12 $316.100).
- El monto del recibo sale del período que contiene la cuota.

## Prórroga

- Tablas `prorrogas` (fechas, cantidad de cuotas, monto base, `activa`) y
  `prorroga_periodos` (rangos, monto, % aumento, "Va por", "Mes"). Solo una activa por contrato.
- Sus períodos se numeran **desde 1, propios de la prórroga** (1–4, 5–12…).
- **Ancla** (`prorrogas.cuota_inicio_global`): cuota global en la que arranca la prórroga.
  Se guarda al crearla con el "Va por" del contrato. En prórrogas viejas sin ancla se
  deduce del último recibo emitido antes de crearla; si no hay recibos, arranca después
  del último período fijo.
- Desde el ancla, el recibo dice **"Alquiler Prórroga N°x"**, donde
  `x = cuota global − ancla + "Va por" del primer período de la prórroga`.
- **Mes de cada cuota de prórroga**: el "Mes" del período corresponde a su "Va por" y
  avanza uno por cuota (Va por 2 = Oct → cuota 3 = Nov, cuota 4 = Dic).
- Antes del ancla, los períodos de la prórroga **no se usan** para nada (ni monto ni aviso).

## Avisos al pie del recibo

El aviso depende del período donde cae la cuota (fijo o de prórroga):

| Situación | Texto en el pie |
|---|---|
| Cuota en el medio del período | *(nada)* |
| **Penúltima** cuota del período | `recuerde que el contrato de alquiler está próximo a vencer` |
| **Última** cuota del período, y después hay otro período | `recuerde que habrá aumento de periodo en el próximo recibo` |
| **Última** cuota del contrato (sin prórroga cargada) o última de la prórroga | `recuerde que el contrato de alquiler está próximo a vencer` |
| Última cuota del contrato que no cae en ningún período cargado | `recuerde que el contrato de alquiler está próximo a vencer` |

Ejemplo, contrato de 24 cuotas con períodos 1–6, 7–12, 13–18, 19–24:

| Cuota | Pie |
|---|---|
| 1–4 | — |
| 5 | próximo a vencer |
| 6 | habrá aumento de periodo en el próximo recibo |
| 7–10 | — |
| 11 | próximo a vencer |
| 12 | habrá aumento… |
| … | … |
| 23 | próximo a vencer |
| 24 | próximo a vencer *(es la última del contrato: no hay aumento)* |

Si ese contrato tiene una prórroga cargada, la cuota 24 dice "habrá aumento…" porque
después viene la prórroga.

La nota se genera al elegir el contrato y al usar "Pagar próximo período" o "Período
anterior". Se puede editar a mano antes de guardar; lo guardado queda fijo en el recibo.

## Alertas al armar el recibo (no se imprimen)

Notificación naranja de 10 segundos:

- **La prórroga tiene datos incompletos**: falta fecha de inicio o de fin, la fecha de
  fin es igual a la de inicio, falta la cantidad de cuotas o hay un período al revés
  (ej. "25–12"). Sale aunque la cuota todavía sea de período fijo, para corregirlo a tiempo.
- **La cuota N de la prórroga no está en ningún período**: falta cargar ese período, no hay monto.
- **La prórroga terminó**: la cuota cae después de la última cuota de la prórroga
  (hay que cargar una nueva o revisar el contrato).

## Validaciones de la prórroga en Editar contrato

Bloquean el guardado y marcan en rojo: fecha de inicio, fecha de fin (no puede ser
anterior ni igual al inicio), cuotas, monto base, monto y "Hasta mes" del período 1,
"Va por" de cada período (obligatorio y dentro de su rango), filas extra a medio cargar.
Aviso amarillo (no bloquea) si los períodos no cubren todas las cuotas o se pasan.
Al abrir un contrato con datos rotos aparece un aviso naranja con los campos marcados.

Al elegir la fecha de inicio, la de fin se sugiere sola: inicio + cantidad de cuotas.
