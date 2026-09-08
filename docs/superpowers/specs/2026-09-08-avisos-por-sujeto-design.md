# Diseño: los avisos se agrupan por sujeto

**Fecha:** 2026-09-08
**Estado:** aprobado en conversación (A y B), ejecución autorizada sin más puertas
**Audiencia:** el autor y el agente de codificación

---

## 0. El problema, medido sobre main 2.21.1

**55 códigos de aviso** en tres familias, dibujados por **cinco pantallas**:

| Familia | Códigos | Pantallas |
|---|---|---|
| Salud del pack | 20 | health_tab, offline_pack_screen |
| Inspección de otra batería | 17 | inspection_verdict_screen (dos sitios) |
| Auditoría de configuración | 18 | config_audit_screen |

El motor ordena **solo por gravedad** (`advice_engine.dart:959`, un `sort` por
`level.index`) y el widget los pinta en una **lista plana**
(`advice_list.dart:70`). Nada los agrupa.

Consecuencia que el autor reportó con estas palabras: "hay un montón en fila,
no están bien agrupados y además muchos parecen ser lo mismo."

Las dos mitades de esa queja tienen una sola causa. Como el único criterio es
la gravedad, una causa y su consecuencia caen en posiciones distintas separadas
por hallazgos ajenos. El ejemplo exacto: `imbalanceAtRest` sale como `problem`
arriba, y `imbalanceCostingRange`, que es su consecuencia, sale como `watch`
cuatro posiciones más abajo. Leídos así parecen dos hallazgos que dicen lo
mismo, cuando son un hallazgo y su precio.

---

## 1. Decisiones tomadas

| Decisión | Valor | Por qué |
|---|---|---|
| Agrupamiento | Por **sujeto físico**, no por urgencia | Ataca las dos mitades de la queja con un mecanismo: junta causa y consecuencia, y baja veinte filas a cinco o seis bloques. La urgencia ya la comunican el color y el orden. |
| Alcance | El **widget compartido**, así que las cinco pantallas lo heredan | Dos formas de leer lo mismo sería peor que el problema. La auditoría, con 18 códigos, es hoy la lista más larga. |
| Buenas noticias | **No dibujan tarjeta**; las recoge una línea de resumen | Una tarjeta verde ocupa lo mismo que una con contenido, y con seis sujetos la pantalla de una batería sana se vería igual de cargada que la de una enferma. |
| Qué es buena noticia | `level == AdviceLevel.good` | Ya está codificado: los cuatro códigos tranquilizadores lo usan y ninguno más. No hay que etiquetar nada a mano. |

---

## 2. Los seis sujetos

Cada uno de los 55 códigos cae en **exactamente uno**. La asignación es total y
exhaustiva: un código nuevo sin sujeto tiene que romper la compilación, no caer
en un cajón por defecto.

| Sujeto | Qué junta |
|---|---|
| **Celdas** | separación en reposo y bajo carga, celda débil dominante, deriva a lo largo de semanas, caída bajo carga, recuperación lenta, balanceador nunca visto |
| **Capacidad** | salud medida, degradación, contra el catálogo, sin test aún |
| **Autonomía** | kilómetros ahora, todavía aprendiendo, lo que el desbalance cuesta en kilómetros |
| **Temperatura** | pack caliente, cargar por debajo de cero, límites de calor al cargar y al descargar |
| **Configuración** | límites de celda, interruptores, corrientes, química sin declarar, cambios desde el primer día |
| **Lo que el BMS dice de sí mismo** | ciclos inflados, SoH decorativo, contador de SOC adelantado o atrasado, capacidad y número de celdas que no cuadran, contadores editables |

El sexto es el que más gana con esto. Hoy está disperso en las tres pantallas
repitiendo la misma idea: los números que el BMS reporta son declaraciones, no
medidas. Juntarlos lo convierte en un argumento en lugar de tres quejas suELTAS.

### 2.1 Dónde va `imbalanceCostingRange`

Con **Celdas**, no con Autonomía. Es la consecuencia del desbalance, y el
principio del agrupamiento es que la causa y su precio se leen juntos. Ponerlo
en Autonomía reproduciría exactamente el defecto que este trabajo elimina.

### 2.2 El caso que no es un sujeto

La inspección tiene cinco códigos que no hablan de la batería sino de si el
test sirvió: `inspectionNoHeavyLoad`, `inspectionRepeatLoadDiffers`,
`inspectionRepeatCountersReset`, `inspectionRepeatSteady`,
`inspectionCountersEditable`.

Los tres primeros son advertencias sobre la medición y van como **nota al pie**
de la pantalla de inspección, no como tarjeta: mezclar "no hubo carga fuerte"
con hallazgos sobre celdas es lo que hace dudar de los hallazgos buenos.

`inspectionCountersEditable` sí es un sujeto y va con **Lo que el BMS dice de
sí mismo**. `inspectionRepeatSteady` es una buena noticia sobre Celdas y se la
lleva la línea de resumen.

---

## 3. Cómo se arma una tarjeta

- El hallazgo **más grave** del sujeto da el título y el tono de la tarjeta.
- Los demás del mismo sujeto entran debajo como líneas, ordenados por gravedad.
- La evidencia sigue viviendo **por hallazgo**, detrás del "por qué" que ya
  existe. No se agrega al nivel de la tarjeta: una tarjeta no mide nada, sus
  hallazgos sí.
- Las tarjetas se ordenan entre sí por la gravedad de su hallazgo más grave, y
  a igual gravedad por el orden de la tabla de sujetos, que va de lo físico a
  lo declarado.

Un sujeto cuyos hallazgos son **todos** `good` no dibuja tarjeta.

---

## 4. La línea de resumen

Va **arriba de las tarjetas**, en una línea, y distingue tres estados por
sujeto. Los tres salen de datos que ya existen, sin inventar nada:

| Estado del sujeto | Regla | Dónde aparece |
|---|---|---|
| Tiene algo que decir | al menos un hallazgo que no es `good` | tarjeta |
| Revisado y bien | tiene hallazgos, todos `good` | nombrado en la línea como revisado |
| No se pudo revisar | no produjo ningún hallazgo | nombrado en la línea como pendiente |

La letra, en español:

> Revisé celdas, temperatura y configuración: bien. De capacidad y autonomía
> todavía no puedo decir nada.

Y cuando todo está bien y todo se pudo medir:

> Revisé celdas, capacidad, autonomía, temperatura y configuración. Todo bien.

Cuando ningún sujeto pudo revisarse, la línea no aparece: no hay nada honesto
que decir, y una línea que diga "no revisé nada" es ruido.

**Por qué la distinción importa.** Es el riesgo que B introduce: si un sujeto
desaparece, no se puede saber si está bien o si no se pudo medir. Esta línea es
lo que cierra ese hueco, y es la razón por la que B es aceptable. La app ya hace
esta distinción en otras partes, como la autonomía que calla en lugar de citar
un número inventado.

---

## 5. Qué se toca

| Archivo | Cambio |
|---|---|
| `lib/src/metrics/advice_engine.dart` | **Crear** `AdviceSubject` (enum de seis) y `subjectOf(AdviceCode)` con un `switch` exhaustivo sin `default` |
| `lib/src/metrics/advice_grouping.dart` | **Crear**: agrupa una `List<Advice>` en tarjetas y calcula los tres estados por sujeto. Puro, sin Flutter, testeable |
| `lib/src/ui/widgets/advice_list.dart` | Consume el agrupamiento: dibuja una tarjeta por sujeto más la línea de resumen |
| `lib/l10n/app_es.arb`, `app_en.arb` | Nombres de los seis sujetos y las dos formas de la línea de resumen |
| `lib/src/ui/inspection/inspection_verdict_screen.dart` | Los tres códigos de fiabilidad salen a nota al pie |

Las cinco pantallas que ya usan `AdviceList` no cambian: heredan el
agrupamiento por consumir el mismo widget.

---

## 6. Pruebas

| Qué | Dónde |
|---|---|
| Cada uno de los 55 códigos tiene sujeto, y el `switch` es exhaustivo | nuevo `test/advice_subject_test.dart` |
| El desbalance y su consecuencia caen en la misma tarjeta | nuevo `test/advice_grouping_test.dart` |
| Un sujeto con todos sus hallazgos `good` no dibuja tarjeta y sale en la línea | idem |
| Un sujeto sin hallazgos sale como pendiente, no como bien | idem |
| Sin sujetos revisables, no hay línea de resumen | idem |
| El título de la tarjeta es el hallazgo más grave del sujeto | idem |
| Las tarjetas se ordenan por su hallazgo más grave | idem |
| Los tests que ya existen sobre el orden plano siguen pasando o se reescriben | `test/verdicts_test.dart` |

---

## 7. Fuera de alcance

- La limpieza de las opciones de notificaciones en ajustes. Trabajo aparte,
  siguiente en la fila.
- El diagnóstico del viaje automático, que necesita la batería del autor.
- Los umbrales de cada veredicto, que no se tocan.
