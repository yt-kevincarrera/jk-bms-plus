# Investigación JK BMS — 21 de octubre de 2026

La fase posterior de implementación y sus verificaciones se documenta en [corrección y validación](2026-10-21-jk-bms-fix-validation.md). Este informe conserva la evidencia de la versión original; sus enlaces de código apuntan al commit investigado.

Investigación sobre el código de `f0f7a3e` (versión 2.30.0), sin correcciones de producción, commits, instalaciones ni cambios de conexión al BMS. Las reproducciones siguientes son locales. No prueban por sí solas cuál de estos caminos causó el episodio concreto del teléfono.

## Resultado general

Los tres síntomas tienen mecanismos reproducibles en la implementación actual. La diferencia de autonomía sale de referencias de energía distintas. La conexión puede conservar un estado saludable sin recibir lecturas útiles. El inicio automático depende de esas lecturas y, además, tiene un hueco propio de recuperación del GPS antes de abrir un viaje.

| Síntoma | Resultado de la investigación | Qué queda por establecer en el teléfono |
| --- | --- | --- |
| Dos autonomías distintas con batería al 100 % | Reproducido pasando tramas por el servicio real: 149,28 km actuales y 167,94 km a plena carga, al mezclar 40 Ah del BMS con 45 Ah de catálogo. Una sola modificación de entrada, catálogo a 40 Ah, elimina esa diferencia. | Capacidad de catálogo/medida y química actualmente guardadas para ese pack. |
| Conectado al JK sin lecturas | Reproducido tras reconexión automática con el transporte y plugin reales sobre radio falsa; además hay incompatibilidad reproducida con características GATT de escritura/notificación separadas. | RX/TX, contadores y mapa GATT durante un episodio fallido. |
| Nunca inicia un viaje con pantalla apagada | Con GPS sano el flujo inicia; con una fuente aceptada pero muda o averiada no inicia durante 240 s de descarga y no la recrea. Otro defecto impide actualizar el tipo del servicio al activar la opción después de conectar. | Si el episodio se detiene por ausencia de lecturas BLE, ausencia de posiciones GPS u otra condición documentada. |

No se recomienda igualar las autonomías mediante un `if SOC == 100`, rebajar los requisitos de movimiento o declarar conectado un flujo sin datos. Esas medidas ocultarían la inconsistencia o crearían viajes falsos.

## Versión y evidencia física disponible

- El usuario confirma que usa la última release, con la app conectada y la pantalla apagada cuando el viaje no se inicia.
- GitHub identifica [v2.30.0](https://github.com/yt-kevincarrera/jk-bms-plus/releases/tag/v2.30.0) como última release estable, publicada el 5 de octubre de 2026 a las 17:20:41 UTC. Se comprobó mediante `gh release list` y `gh api .../releases/latest`.
- `HEAD` y el tag `v2.30.0` resuelven al mismo commit: `f0f7a3e8b9d44cec61f24373435470714ba590d9`.
- Se encontró un Pixel 6 conectado mediante ADB. `dumpsys package dev.selector.jk_bms` informa `versionName=2.30.0`, `versionCode=4075` y proceso activo. Coincide el nombre de versión; no se verificó byte a byte el APK instalado frente al fuente.
- Para el usuario Android 0 están concedidos Bluetooth scan/connect, ubicación precisa, ubicación en segundo plano y notificaciones. `dumpsys activity services` muestra `ForegroundService` activo con tipo `0x00000008` (`location`) y el servicio de Geolocator enlazado.
- Eso descarta la ausencia de esos permisos y del servicio en el instante observado. No demuestra su estado durante todos los fallos anteriores ni que estuvieran entrando posiciones GPS o lecturas BLE.
- El logcat reciente del proceso no contiene una traza útil del fallo. `run-as` rechaza el acceso porque la instalación no es depurable; no se extrajo la base privada ni se intentó eludir esa restricción.

Las inspecciones del teléfono fueron de lectura. No se instaló una build, se forzó un viaje, se reinició Bluetooth ni se modificaron ajustes del BMS.

## Autonomía actual frente a autonomía llena

### Causa reproducida: se mezclan capacidades independientes

La energía actual recibe `remainingCapacityAh` y SOC del BMS en [BmsService.energyOf](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/bms_service.dart#L528). La energía llena recibe `bestMeasuredCapacityAh ?? catalogueCapacityAh` en [BmsService.rangeOutlook](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/bms_service.dart#L2325). El catálogo introducido por el usuario se conserva y prevalece sobre la configuración BMS ([repository.dart:1058](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/data/repository.dart#L1058)).

El parser lee SOC, Ah restantes y Ah nominales de campos distintos ([jk_parser.dart:178](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/protocol/jk_parser.dart#L178)); que uno marque 100 % no obliga a que los otros coincidan con el catálogo o una prueba de capacidad.

El harness usa `JkFrameBuilder → FakeLink → assembler/parser → BmsService → RangeOutlook`, con SQLite en memoria. Entradas del caso principal: 20S NMC, celdas equilibradas a 4,18 V, corriente 0 A, SOC exactamente 100 %, consumo aprendido 20 Wh/km y factor utilizable 1.

| Variación controlada | Autonomía actual | Con batería llena |
| --- | ---: | ---: |
| Ah restantes y nominales BMS = 40; catálogo = 45 | 149,28 km | 167,94 km |
| Único cambio: catálogo = 40 | 149,28 km | 149,28 km |
| Único cambio posterior: capacidad medida = 38 | 149,28 km | 141,816 km |
| SOC 100 %, restantes = 39 Ah, referencia = 40 Ah | 145,548 km | 149,28 km |

La primera discrepancia, repetida dos veces, equivale a 18,66 km o un 12,5 % sobre la cifra actual. La pantalla redondearía a 149 frente a 168 km ([now_tab.dart:270](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/ui/tabs/now_tab.dart#L270), [now_tab.dart:653](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/ui/tabs/now_tab.dart#L653)). No es un error de división: las premisas de los dos cálculos son diferentes.

### Evidencia histórica del pack del usuario

Se decodificaron con el parser real y checksum validado las cuatro capturas guardadas en [real_kevinjk_frames.dart](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/test/fixtures/real_kevinjk_frames.dart). Su cabecera identifica el backup del 2 de septiembre de 2026, pack KevinJK, modelo JK-BD6A20S6P, hardware 20H, firmware 20.20 y variante JK02_32S. No se asume que esa identificación o configuración siga siendo la actual.

| Captura UTC | SOC | Nominal BMS | Restantes BMS | Voltaje |
| --- | ---: | ---: | ---: | ---: |
| 2026-08-29 09:28:55 | 100 % | 40 Ah | 39,919 Ah | 82,769 V |
| 2026-08-29 10:14:54 | 97 % | 40 Ah | 38,769 Ah | 81,998 V |
| 2026-09-01 17:24:20 | 69 % | 40 Ah | 27,678 Ah | 76,933 V |
| 2026-09-01 19:25:19 | 66 % | 40 Ah | 26,528 Ah | 76,371 V |

Las cuatro tienen 20 celdas y corriente 0 A; en la primera las celdas están entre 4,138 y 4,141 V. La última configuración capturada, del 1 de septiembre a las 19:29:15 UTC, también declara 40 Ah. El [README:9](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/README.md#L9) describe la batería objetivo como Yoazaky 72 V 45 Ah. Por tanto el conflicto 40/45 Ah tiene correspondencia histórica con este proyecto, aunque falta saber qué catálogo o capacidad medida usa ahora el teléfono. Los tests existentes ya verifican los 40 Ah de las capturas ([jk_parser_test.dart:357](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/test/jk_parser_test.dart#L357)).

La primera captura demuestra además un caso real de SOC 100 % con Ah restantes distintos de los nominales. Eso no demuestra por sí solo carga física completa ni autoriza a corregir el porcentaje a ciegas.

### Otros factores contrastados

- **Química desconocida:** hay una segunda divergencia en el motor. La energía actual usa una media conservadora entre voltaje observado y corte; la llena adopta la curva LFP. Con 40 Ah, SOC 100 %, media observada 3,8 V/celda y corte 3,0 V/celda resultan 136 frente a 130,1 km. Ver [pack_energy.dart:125](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/metrics/pack_energy.dart#L125) y [pack_energy.dart:149](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/metrics/pack_energy.dart#L149). No se confirmó que esta condición corresponda al perfil actual.
- **Desequilibrio:** se aplica el mismo factor a las dos energías ([range_outlook.dart:98](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/metrics/range_outlook.dart#L98)). Con capacidad común y factor `0.9077795641300469`, ambas dan 135,513333 km; no explica por sí solo el caso principal.
- **Confianza:** baja/media/alta modifica el intervalo, no el centro de 149,28 km del caso probado.
- **Reserva y redondeo:** no hay una reserva fija adicional en estas fórmulas; el caso principal usa SOC exactamente 100 %, por lo que el redondeo visual no lo explica.

### Pruebas y corrección propuesta

```text
flutter test test/investigation_range_tmp_test.dart --reporter expanded
=> rojo: esperado 167.94 +/- 0.5; obtenido 149.28.

flutter test --no-pub test/investigation_range_tmp_test.dart --plain-name 'INV-RANGE: full charge must agree between now and full' --reporter expanded
=> mismo rojo en la repetición.

flutter test --no-pub test/range_outlook_test.dart test/pack_energy_test.dart test/range_weighting_test.dart --reporter expanded
=> 39/39 verdes.

dart run test/investigation_range_decode_tmp.dart
=> capturas históricas decodificadas correctamente; checksums válidos.
```

El [test de igualdad existente](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/test/range_outlook_test.dart#L199) inyecta manualmente la misma capacidad/energía en las dos entradas. Comprueba la fórmula, pero no la elección real de fuentes en BmsService; por eso no detecta el caso reproducido.

Para una fase de solución hay que definir una capacidad operativa coherente y mostrar aparte el catálogo o una discrepancia con el BMS. Debe preservarse la procedencia de las mediciones, decidir cómo se traduce SOC/Ah a energía utilizable y cubrir en BmsService las combinaciones catálogo/configuración/medición. Igualar artificialmente los números al 100 % ocultaría el problema.

## Inicio automático con pantalla apagada

### A1: el GPS armado antes del viaje carece de recuperación

Se probó la ruta completa `frames JK fragmentados → BmsService → detector → GPS → TripRecorder`, con descarga de -10 A durante 240 segundos virtuales y posiciones de control a 25 km/h.

| Fuente GPS | Fuentes creadas | Resultado |
| --- | ---: | --- |
| Entrega posiciones normalmente | 1 | Viaje iniciado |
| Acepta start(), permanece muda | 1 | Nunca inicia durante los 240 s |
| Acepta start(), después emite error | 1 | Nunca inicia durante los 240 s |
| Muda 91 s, luego entrega posiciones | 1 | Viaje iniciado |

La fuente queda asignada en [bms_service.dart:2172](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/bms_service.dart#L2172). Su `onError` solo registra `locationStreamError` ([línea 2204](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/bms_service.dart#L2204)). El armado vuelve a crear GPS únicamente si `_location == null` ([línea 3198](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/bms_service.dart#L3198)). El watchdog que recupera GPS sale cuando todavía no hay viaje grabándose ([línea 2237](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/bms_service.dart#L2237)).

Así una fuente aceptada pero sin posiciones permanece retenida durante la descarga: la app interpreta su existencia como un GPS operativo, no dispone de velocidad para iniciar, y el mecanismo de recuperación exige que el viaje ya haya iniciado. El control que entrega posiciones después de 91 s sí inicia, aislando el bloqueo de recuperación frente a un fallo del detector sano.

Eventos del caso mudo: `ridingCurrentSeen → locationArmed`. Con error se añade `locationStreamError`. Los controles sanos añaden `idleSpeedSeen` y `autoTripStarted`. Se confirmó el defecto local; no se capturó esa secuencia en el Pixel durante el episodio fallido.

### A2: activar el ajuste tras conectar no actualiza el tipo aplicado

Repro repetido: conectar con auto-start desactivado y servicio `dataSync`; activar después auto-start. El contador de arranques queda en 1, aunque el tipo deseado pasa a `location` y debería reiniciarse el servicio con ese tipo.

```text
before toggle starts=1; after=1; desired location=true
Expected: 2
Actual: 1
```

[bms_service.dart:2698](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/bms_service.dart#L2698) retorna por conservar el mismo dueño antes de comparar el tipo requerido en la línea 2714. El [test existente](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/test/foreground_service_test.dart#L247) solo consulta un getter calculado desde el estado deseado ([bms_service.dart:2611](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/bms_service.dart#L2611)); no verifica el tipo aplicado ni el reinicio. Por eso pasa pese al fallo.

El Pixel observado tiene ahora un servicio `location`, así que A2 no explica por sí solo su estado presente. Sigue siendo un defecto real del ajuste y un escenario de regresión que debe cubrirse.

### Condiciones y alternativas

El detector exige descarga de al menos 3 A y velocidad de al menos 6 km/h durante 20 s, con gracia de descarga de 10 s ([trip_autostart.dart:45](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/metrics/trip_autostart.dart#L45), [línea 161](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/metrics/trip_autostart.dart#L161)). GPS con precisión peor de 30 m se filtra ([location_source.dart:138](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/gps/location_source.dart#L138)). Sin snapshots BLE no se evalúa el detector ([bms_service.dart:1811](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/bms_service.dart#L1811)); por tanto el síntoma BLE puede bloquear el viaje aun con GPS y permisos correctos.

La persistencia y aplicación del ajuste sí existen: [app_settings.dart:177](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/app_settings.dart#L177), [línea 277](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/app_settings.dart#L277), [app_settings_screen.dart:218](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/ui/app_settings_screen.dart#L218), [app.dart:188](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/app.dart#L188). No hay evidencia obtenida de que el teléfono pierda el valor guardado. Los controles sanos y los replays de viajes reales inician; la afirmación del usuario de que nunca inicia en su uso con pantalla apagada sigue siendo compatible con un problema de entrada BLE/GPS, sin demostrar cuál.

Las [reglas oficiales de Android sobre servicios](https://developer.android.com/develop/background-work/services/fgs/service-types) y [restricciones de arranque](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start) explican por qué importan el tipo `location`, los permisos y el momento del arranque. Son contexto del impacto de A2; no identifican por sí solas la causa física del Pixel.

### Pruebas y corrección propuesta

```text
flutter test test/trip_autostart_test.dart test/auto_trip_real_replay_test.dart test/auto_trip_pocket_note_test.dart --reporter expanded
=> 34/34 verdes.

flutter test --no-pub test/foreground_service_test.dart test/foreground_service_options_test.dart test/ant_current_sign_test.dart --reporter expanded
=> 26/26 verdes.

flutter test --no-pub test/investigation_autostart_tmp_test.dart --reporter expanded
=> 2 controles verdes; 3 rojos: GPS mudo, GPS con error y cambio de tipo del servicio.
```

Se propone ampliar la vigilancia al periodo de armado, medir edad/errores de posiciones y recrear la fuente con un intervalo de reintento. Hay que conservar el requisito de movimiento para evitar viajes inventados. El servicio debe comparar dueño y tipo aplicado antes de su retorno temprano, con tests sobre llamadas reales de start/stop/tipo. La interfaz debe poder decir «esperando GPS» o «GPS sin posiciones» antes de que exista un viaje.

## BLE: conectado sin lecturas

### Resultado y nivel de evidencia

Se reprodujeron dos defectos concretos que producen el síntoma «conectado, pero sin lecturas nuevas», además de un hueco de recuperación ante tramas estructuralmente válidas que no producen datos utilizables.

| Hallazgo | Evidencia obtenida | Límite |
| --- | --- | --- |
| B1. La recuperación de lecturas JK se apaga después de la primera lectura y no vuelve a activarse al reconectar automáticamente. Si siguen llegando device-info, el enlace queda conectado sin pedir más celdas. | Reproducción determinista con `BmsService`, transporte real `BleTransport`, FlutterBluePlus 2.3.12 y radio falsa; parser y tramas reales del pack del usuario. | Falta comprobar si durante el fallo real llegan device-info u otras tramas válidas sin cell-info. |
| B2. Cuando el módulo JK presenta dos FFE1 separados para escritura y notificación, la app escribe en la característica de notificación. Anuncia conectado y no obtiene lecturas. | Reproducción diferencial con transporte real y mismo plugin: GATT combinado funciona; GATT separado falla. La referencia original documenta y maneja ese GATT separado. | No se inspeccionó el mapa GATT del pack físico actual. Si el pack usa una FFE1 combinada, este defecto no explica por sí solo su fallo intermitente. |
| B3. Recibir cell-info con checksum válido basta para detener los pedidos auxiliares aunque ninguna trama llegue a convertirse en lectura. | Reproducción con datos alterados deliberadamente para ser indecodificables, conservando checksum correcto. | Es una prueba sintética de una vía de espera, no evidencia de que el pack esté transmitiendo esos bytes. Pedir más o reconectar no garantiza resolver un firmware no reconocido. |

### B1: la recuperación no sigue el ciclo de cada reconexión

Cadena comprobada:

1. `BmsService.connect()` arma `_armCellInfoRequests()` para JK (`lib/src/bms_service.dart:1047`).
2. Ese timer comprueba `cellInfoFrames > 0` y se cancela definitivamente (`lib/src/bms_service.dart:1094`). El contador pertenece a la sesión iniciada mediante `connect`, no a cada enlace BLE que se reconstruye.
3. Una caída automática llama `_onLinkDown()` y una reconexión llama `_onLinkUp()` (`lib/src/bms_service.dart:120`), pero ninguno rearma la recuperación de celdas ni reinicia el contador correspondiente (`lib/src/bms_service.dart:2961`, `:2994`).
4. El transporte vuelve a enviar su pareja inicial `0x97`, `0x96` (`lib/src/ble/ble_transport.dart:737`). Si eso no reactiva cell-info, la recuperación específica del servicio ya está apagada.
5. `BmsService` acepta como prueba de vida cualquier trama JK con framing/checksum correcto **antes** de decodificar su contenido (`lib/src/bms_service.dart:1215`). `BleTransport.frameAccepted()` refresca `_lastFrameAt` y perdona el backoff (`lib/src/ble/ble_transport.dart:1067`). Device-info mantiene ese reloj vivo sin producir una lectura de batería.
6. El script JK solo pide celdas cuando ese reloj queda quieto; si sigue llegando device-info, devuelve `NoAction` y tampoco activa `ReleaseMute` (`lib/src/ble/link_script.dart:162`).

Se ejercitaron dos seams para no depender de una interpretación aislada del código:

- Servicio con `FakeLink`, 24 segundos virtuales tras una caída: 12 device-info reales, ninguna lectura nueva y cero solicitudes nuevas.
- Servicio con **transporte real** y plugin real, radio sustituida bajo FlutterBluePlus: lectura inicial correcta; esperar a que el timer se cancele; caída BLE; reconexión automática real; permitir device-info pero no cell-info; esperar 3,1 segundos adicionales. Resultado: `connected`, `snapshots=1`, `cells=1`, `extraWrites=0`, `drops=1`. El número de device-info varía con la planificación de Windows; el veredicto no depende de ese número.

El control de primera conexión, sin lectura anterior y con solo device-info, sí pidió celdas dos veces en siete segundos virtuales. La diferencia es el historial del enlace y el timer cancelado, no que el parser no sepa leer las capturas del usuario.

Hay además una imprecisión en la evidencia persistida: `_onLinkUp()` registra `readingsResumed` al subir el enlace (`lib/src/bms_service.dart:3002`), antes de verificar que se reanudaron las lecturas. Un evento con ese nombre no demuestra que volvieran los datos.

### B2: notificación y escritura están unidas al mismo objeto

`_findCharacteristic()` reconoce expresamente que algunos JK exponen dos características FFE1, pero devuelve solo la que notifica (`lib/src/ble/ble_transport.dart:954`). `_attach()` la guarda en `_characteristic`, se suscribe y publica `BleLinkState.connected` (`lib/src/ble/ble_transport.dart:698`, `:714`, `:717`). `_send()` utiliza después ese mismo objeto para escribir (`lib/src/ble/ble_transport.dart:1211`). No selecciona una característica escribible aparte.

La prueba diferencial devolvió:

```text
splitGatt=false state=BleLinkState.connected snapshots=1 writeInstances=[1, 1]
splitGatt=true state=BleLinkState.connected snapshots=0 writeInstances=[2, 2]
Exception: write not permitted on notify-only FFE1 instance 2
```

En el control, instancia 1 permite notify y write. En el caso separado, instancia 1 permite write, instancia 2 permite notify; la app intenta ambos comandos de arranque en la 2. El plugin conserva `instanceId` tanto al suscribirse como al escribir; compartir UUID no convierte ambas características en la misma.

El estado conectado aparece antes de que salgan los comandos de arranque. Además `_send()` captura el error y devuelve `false`, mientras `_write()` no utiliza ese resultado para invalidar el arranque (`lib/src/ble/ble_transport.dart:1205`, `:1221`). Por tanto el resultado «conectado sin lecturas» de la prueba atraviesa el mismo control de estado que la app.

La radio falsa corre en Windows y el plugin devuelve el aviso esperado `requestMtu ... android-only`; el transporte conserva MTU 23 y sigue. Ese aviso aparece también en el control que sí obtiene lecturas y no explica la diferencia. La prueba no sustituye una validación Android/GATT física.

El código original de la referencia JK distingue `char_handle_` de `notify_handle_` y describe un módulo nuevo con FFE1 escribible en handle `0x03` y FFE1 notificable en `0x05`. La app debe conservar compatibilidad con el módulo de característica combinada y admitir ambas capacidades separadas. [Referencia original JK: GATT y handles](https://github.com/syssi/esphome-jk-bms/blob/main/components/jk_bms_ble/jk_bms_ble.cpp), [documentación del protocolo en el mismo proyecto](https://github.com/syssi/esphome-jk-bms/blob/main/docs/protocol-design-ble.md), [FlutterBluePlus 2.3.12: identidad de característica](https://github.com/chipweinberger/flutter_blue_plus/blob/2.3.12/packages/flutter_blue_plus/lib/src/bluetooth_characteristic.dart).

### B3: transporte vivo y datos utilizables son dos condiciones distintas

`_dispatch()` incrementa `cellInfoFrames` antes de ejecutar el parser/prober (`lib/src/bms_service.dart:1580`). Como el timer se cancela por ese contador, una sola cell-info que no se pueda interpretar basta para detener la recuperación. El aviso de silencio es informativo y se ejecuta una vez; no reconstruye el enlace (`lib/src/bms_service.dart:1128`).

En el harness se copió una trama real en un nuevo `Uint8List`, se reemplazaron sus bytes de contenido y se recalculó el checksum. No se modificó la captura original ni código de producción. Tras 24 segundos virtuales se observaron 12 cell-info aceptadas como tramas, 12 retenidas por framing/prober, cero snapshots y cero solicitudes auxiliares.

Esto exige un estado explícito de datos ausentes/no decodificables y una recuperación acotada por el progreso de lecturas, conservando bytes y razón de rechazo. No justifica aceptar valores imposibles ni elegir una variante a ciegas. El parser actual **sí** lee las cuatro capturas cell-info reales ya incluidas del pack y puede determinar JK02_32S sin device-info; esas pruebas existentes pasaron.

### Hipótesis contrastadas y alternativas abiertas

Se priorizaron: recuperación que no se rearma; checksum válido sin lectura utilizable; elección incorrecta de característica; problema físico/GATT o de notificaciones que requiere datos del teléfono. Las tres primeras tienen bucles locales; la última sigue abierta.

La secuencia de suscripción está en el orden recomendado: crear listener `onValueReceived` antes de `setNotifyValue(true)`. El transporte vuelve a descubrir servicios y crear esa suscripción en cada attach, y cancela la anterior al caer el enlace. La lectura está fragmentada mediante `FrameAssembler`, con casos de MTU pequeño cubiertos. No hay evidencia actual para atribuir el fallo a un password, a un tamaño de MTU concreto, a otro cliente BLE, a permisos faltantes, o a una versión nueva del plugin. [Guía oficial FlutterBluePlus: reconexión y suscripción](https://github.com/chipweinberger/flutter_blue_plus).

No se encontró `GLOSSARY.md` ni ADR formal en los archivos del repo. Se leyeron `docs/PROTOCOL.md` y el diseño/plan ANT de 2026-09-28. El plan exige preservar el comportamiento JK; `git blame` sitúa el timer y su condición de parada en `9c59c0b1` del 4 de septiembre, anterior a ANT, y el selector de FFE1 en el código inicial de agosto. Por tanto no hay base para culpar a ANT por haber introducido esos dos defectos. La extracción a `LinkScript` mantuvo los bytes JK, cubiertos por pruebas.

`docs/PROTOCOL.md` contiene notas antiguas que deben interpretarse con cuidado: todavía habla de una falta de captura JK02_32S y de asumir la cadencia, mientras el repo ya tiene capturas reales del dueño y recuperación por silencio. No se usó esa nota desactualizada como prueba de que el parser actual carezca de soporte.

### Comandos ejecutados y resultados

Pruebas existentes, sin modificar producción:

```powershell
flutter test --no-pub test/ble_transport_recovery_test.dart test/link_script_test.dart test/bms_service_test.dart test/variant_prober_test.dart test/frame_assembler_test.dart test/jk_parser_test.dart --reporter expanded
```

```text
00:46 +104: All tests passed!
exit_code: 0
```

Estas 104 pruebas verifican la cobertura existente, no cubrían los escenarios nuevos anteriores.

Harness de investigación preservado fuera del repo en:

`C:\Users\carre\AppData\Local\Temp\jk-bms-investigation-2026-10-21\ble_tmp_test.dart`

Para repetir desde la raíz del repo:

```powershell
$bleHarness = Join-Path $env:TEMP 'jk-bms-investigation-2026-10-21/ble_tmp_test.dart'
Copy-Item -LiteralPath $bleHarness -Destination 'test/investigation_ble_tmp_test.dart'
flutter test --no-pub test/investigation_ble_tmp_test.dart --reporter expanded
Remove-Item -LiteralPath 'test/investigation_ble_tmp_test.dart'
```

Salida relevante de la última ejecución, antes de retirar el archivo temporal:

```text
first connect: state=BleLinkState.connected, cells=0, info=1, asks=2
after reconnect, 24 s of device info: state=BleLinkState.connected, snapshots=1, cells=1, info=12, new asks=0
24 s of checksum-valid undecodable cells: state=BleLinkState.connected, snapshots=0, cells=12, held=12, accepted=12, asks=0
splitGatt=false state=BleLinkState.connected snapshots=1 writeInstances=[1, 1]
splitGatt=true state=BleLinkState.connected snapshots=0 writeInstances=[2, 2]
actual transport reconnect: state=BleLinkState.connected snapshots=1 deviceInfo=206 cells=1 extraWrites=0 drops=1
00:06 +3 -4: Some tests failed.
exit_code: 1
```

Los cuatro rojos son aserciones intencionales de la investigación: tres escenarios de fallo y una segunda reproducción de B1 con transporte real. No se añadió una prueba fallando a la suite permanente ni se cambió la app para hacerla pasar. Los escenarios B1/B3 se repitieron en varias ejecuciones con el mismo resultado. No hubo CI, build, instalación ni verificación física de una corrección.

### Evidencia física que falta para asignar la causa del fallo recurrente

Hace falta capturar **el episodio fallido**, no solo el estado conectado de una sesión sana: bytes RX/TX, último snapshot, contadores device-info/cell-info/held-back/decode-failures, variante elegida, historial de intentos y GATT con capacidades/instancias FFE1. Con cero RX se investiga suscripción/handshake/radio; con device-info y sin celdas encaja B1; con bytes rechazados o held-back encaja B3; con errores de escritura y FFE1 separadas encaja B2.

La app ya contiene consola de tramas y diagnósticos; conviene usar esa evidencia antes de reiniciar Bluetooth, porque el reinicio destruye parte del contexto del fallo. La afirmación de que el teléfono sigue conectado y con la pantalla apagada no permite distinguir esos caminos. No se solicita instalar una app nueva ni alterar el BMS para obtener primero esta evidencia.

### Orden propuesto para una fase posterior de corrección

1. Separar conectividad GATT de disponibilidad de lecturas, manteniendo la última lectura con su edad y un diagnóstico preciso.
2. Rearmar la recuperación JK por cada enlace y medir progreso mediante lecturas nuevas, sin volver a escribir continuamente sobre un stream sano.
3. Seleccionar capacidades notify/write por separado y conservar soporte de características combinadas.
4. Distinguir silencio de RX de framing/parser sin avance; conservar los bytes y aplicar una recuperación acotada sin aceptar datos inventados.
5. Verificar luego en Android con el BMS físico, pantalla encendida/apagada y reconexiones, correlacionando los contadores con snapshots nuevos. No dar por resuelto el fallo del dueño solo porque pase el harness local.

## Interfaz: comunicar el estado que el usuario necesita

La revisión se limita a los estados implicados en estos tres fallos, mediante código; no se hizo una auditoría visual, de contraste o de accesibilidad sobre una pantalla renderizada. Se aplicaron los principios de información y recuperación de apple-design adaptados a Flutter/Android.

- **Conservar lo que ya explica la procedencia:** la autonomía llena ya muestra si sale del catálogo, BMS o una descarga medida ([now_tab.dart:669](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/ui/tabs/now_tab.dart#L669)); no se propone eliminar esa distinción. Hay que resolver o señalar explícitamente el conflicto entre referencias cuando produce cifras incompatibles con la lectura al 100 %.
- **Conectar no equivale a leer:** el transporte publica `connected` después de suscribirse, antes de recibir una lectura. FirstContact acepta device-info como prueba de BMS ([connect_screen.dart:1222](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/ui/connect_screen.dart#L1222)). Eso sirve para identificar el dispositivo, pero la pantalla debe distinguir «enlace abierto», «esperando lecturas», «lecturas al día» y «lecturas detenidas». Debe conservarse el aviso de edad que HomeShell ya tiene ([home_shell.dart:128](https://github.com/yt-kevincarrera/jk-bms-plus/blob/f0f7a3e8b9d44cec61f24373435470714ba590d9/lib/src/ui/home_shell.dart#L128)).
- **El ajuste de viajes necesita diagnóstico operativo:** además de encendido/apagado, interesa saber si está esperando descarga, posiciones GPS o recuperación de lecturas, con una acción concreta cuando no puede avanzar. No se debe mostrar una promesa incondicional solo porque los permisos estén concedidos.

La recomendación sigue `feedback.md › Best practices`: “Show people when a command can’t be carried out and help them understand why.” [Guía de feedback](https://developer.apple.com/design/human-interface-guidelines/feedback). También sigue la claridad del estado de carga de `loading.md › Showing progress` y la claridad de ajustes/errores de `writing.md › Best practices`. [Loading](https://developer.apple.com/design/human-interface-guidelines/loading), [Writing](https://developer.apple.com/design/human-interface-guidelines/writing). Los nombres de estado anteriores son propuestas de producto, no convenciones nativas de navegación de Apple impuestas a Android.

## Verificación conjunta y límites de entrega

Además de los comandos de cada área se ejecutó:

```powershell
flutter test --no-pub test/foreground_service_test.dart test/foreground_service_options_test.dart test/backup_preferences_test.dart test/pack_energy_test.dart test/waiting_diagnosis_test.dart --reporter expanded
```

Resultado: **51/51 verdes**. Drift emitió su aviso de instancias múltiples de base durante el test de backup; el comando terminó con código 0. No es evidencia de corrupción de la base del teléfono. Las cantidades de las distintas corridas no deben sumarse como pruebas únicas, porque hay archivos repetidos entre comandos.

| Nivel | Verificación realizada |
| --- | --- |
| Fuente y pruebas locales | Reproducciones de los tres síntomas, controles sanos y suites dirigidas existentes. Los rojos de investigación son deliberados y están descritos en cada sección. |
| Teléfono físico | Solo versión, permisos, proceso, servicio activo y búsqueda de logs recientes. No se reprodujo en carretera ni se capturó el episodio BLE/GPS fallido. |
| CI | No se ejecutó. |
| Build/instalación/release | No se ejecutaron. |
| Corrección de implementación | No se realizó; esta entrega es investigación. |

Los harnesses se retiraron de `test/` para no dejar una suite permanente en rojo. Se conservaron copias locales fuera del repositorio:

- `C:\Users\carre\AppData\Local\Temp\jk-bms-investigation-2026-10-21\range_tmp_test.dart`
- `C:\Users\carre\AppData\Local\Temp\jk-bms-investigation-2026-10-21\range_decode_tmp.dart`
- `C:\Users\carre\AppData\Local\Temp\jk-bms-investigation-2026-10-21\autostart_tmp_test.dart`
- `C:\Users\carre\AppData\Local\Temp\jk-bms-investigation-2026-10-21\ble_tmp_test.dart`

Para repetir autonomía o auto-start hay que copiar el archivo correspondiente a `test/investigation_range_tmp_test.dart` o `test/investigation_autostart_tmp_test.dart`, ejecutar el comando documentado y retirar únicamente esa copia al terminar. Sus imports relativos requieren esa ubicación. El decodificador histórico se copia a `test/investigation_range_decode_tmp.dart` y se ejecuta con `dart run`. Las copias de TEMP no son artefactos versionados ni una validación física; pueden perderse si se limpia ese directorio.

## Orden de trabajo recomendado después de la investigación

1. Guardar el diagnóstico de un episodio real antes de reiniciar el enlace: RX/TX y últimos snapshots para BLE; `ridingCurrentSeen → locationArmed → idleSpeedSeen → autoTripStarted`, con errores intermedios, para viajes.
2. Corregir el seguimiento de lecturas útiles y la recuperación por reconexión JK. Es la entrada común que también necesita el detector de viajes. Cubrir transporte real con radio falsa y conservar compatibilidad GATT combinada/separada.
3. Recuperar el GPS durante el armado y comprobar el tipo de servicio realmente aplicado. Verificar inicio con la app abierta, pantalla apagada, reconexión y activación del ajuste después de conectar.
4. Definir la referencia operativa de capacidad/energía de las autonomías, conservar su procedencia y probar discrepancias de catálogo/BMS/medición y química desconocida sin ocultarlas con el porcentaje.
5. Validar los tres flujos en el Pixel y el JK físico. Un test local verde será evidencia de la corrección lógica; cerrar el fallo recurrente exige comprobar las lecturas y el viaje en las condiciones del usuario.
