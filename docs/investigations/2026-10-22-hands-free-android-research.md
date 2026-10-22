# Android: presencia del JK, conexión y viaje sin abrir la app

Fecha: 2026-10-22. Investigación de fuentes primarias y dependencias instaladas. No se cambió código productivo ni se probó esta arquitectura en el BMS físico.

## Decisión propuesta

Para Android 12+ conviene **CompanionDeviceManager (CDM) + CompanionDeviceService (CDS), con asociación voluntaria del BMS y un único runtime que pueda arrancar sin Activity**. La presencia despierta ese runtime; éste establece GATT, valida lecturas y alimenta el detector de viaje. La UI observa y envía comandos a ese propietario único. Esta es una recomendación de arquitectura, todavía pendiente de validación física.

Android documenta CDM/CDS para despertar una aplicación por presencia y escuchar notificaciones de un periférico durante periodos largos. Un scan mediante `PendingIntent` también puede despertar el proceso, pero ese hecho por sí solo no resuelve el servicio duradero ni el GPS. No conviene programar escaneos periódicos que despierten el proceso aunque el BMS no esté cerca. [Guía oficial de BLE en segundo plano](https://developer.android.com/develop/connectivity/bluetooth/ble/background).

## Comparación implementable

| Mecanismo | Proceso terminado normalmente | Propietario de conexión/estado | Coste y límite práctico |
|---|---|---|---|
| Scan Dart con `ScanCallback` o reconexión actual | Necesita un proceso vivo | Runtime Dart existente | Sirve tras minimizar; no crea un runtime tras muerte del proceso. |
| `BluetoothLeScanner.startScan(filters, settings, PendingIntent)` | El sistema entrega resultados y puede crear el proceso | Receptor nativo más worker/runtime explícito | Usar filtros concretos. No equivale a autorización general para arrancar FGS desde background en API 31+. Alternativa parcial, no solución completa aislada. |
| CDM + CDS | El sistema enlaza el servicio para un dispositivo asociado presente | CDS arranca un runtime explícito | Mejor ajuste para este caso en API 31+. Requiere consentimiento, compatibilidad del anuncio/dirección y validación real. |
| FGS permanente iniciado previamente por el usuario | Puede recrearse si se implementa bootstrap persistente | Worker de larga vida | Notificación permanente y más consumo. Tener un servicio nativo vivo no reconstruye automáticamente el servicio Dart actual. |
| WorkManager periódico | Puede ejecutarse posteriormente | Worker temporal | No promete detectar el instante de acercarse o comenzar a conducir; no elegirlo como señal primaria de proximidad. |

Las dos primeras limitaciones y el cierre de GATT al morir el proceso están descritos en la [guía BLE](https://developer.android.com/develop/connectivity/bluetooth/ble/background). El contrato que permite recibir resultados sin proceso está en [BluetoothLeScanner.startScan con PendingIntent](https://developer.android.com/reference/android/bluetooth/le/BluetoothLeScanner#startScan(java.util.List%3Candroid.bluetooth.le.ScanFilter%3E,%20android.bluetooth.le.ScanSettings,%20android.app.PendingIntent)). Android 16 aplica cuotas de ejecución a jobs incluso cuando coexisten con un FGS: [cambios de foreground services](https://developer.android.com/develop/background-work/services/fgs/changes).

## APIs y permisos que cambian el diseño

### Asociación y presencia

La asociación CDM requiere una selección/confirmación del usuario. No establece GATT ni proporciona un lector del BMS. El setup CDM puede descubrir sin permiso de localización, aunque requiere los servicios de ubicación del sistema habilitados. La asociación y el consentimiento no sustituyen los permisos necesarios para las operaciones posteriores. [Asociación de dispositivos](https://developer.android.com/develop/connectivity/bluetooth/companion-device-pairing), [permisos Bluetooth](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions).

- API 31–32: `startObservingDevicePresence(address)` y callbacks CDS basados en dirección.
- API 33–35: el mismo registro de presencia y callbacks que reciben `AssociationInfo`.
- API 36: `startObservingDevicePresence(ObservingDevicePresenceRequest.Builder().setAssociationId(id).build())` y `onDevicePresenceEvent(event)`. Las APIs anteriores siguen disponibles, pero están deprecadas.
- Declarar `REQUEST_OBSERVE_COMPANION_DEVICE_PRESENCE`; comprobar `FEATURE_COMPANION_DEVICE_SETUP`. El CDS debe estar exportado y protegido por `android.permission.BIND_COMPANION_DEVICE_SERVICE`, con el intent filter `android.companion.CompanionDeviceService`.

Fuentes: [CompanionDeviceManager](https://developer.android.com/reference/android/companion/CompanionDeviceManager#startObservingDevicePresence(android.companion.ObservingDevicePresenceRequest)), [CompanionDeviceService](https://developer.android.com/reference/android/companion/CompanionDeviceService).

**No usar `ObservingDevicePresenceRequest.setUuid` como filtro del servicio GATT JK:** esa alternativa observa Bluetooth clásico y exige el perfil de proyección automotriz. Para este BLE corresponde `setAssociationId`. [Builder oficial](https://developer.android.com/reference/android/companion/ObservingDevicePresenceRequest.Builder#setUuid(android.os.ParcelUuid)).

En API 36, presencia BLE y conexión Bluetooth son señales distintas. El sistema mantiene el CDS enlazado mientras hay presencia BLE o conexión; no cerrar el runtime sólo porque llegue `EVENT_BT_DISCONNECTED` si sigue cerca. La referencia precisa indica desvinculación cuando desaparecen ambas condiciones. [Contrato de SERVICE_INTERFACE](https://developer.android.com/reference/android/companion/CompanionDeviceService#SERVICE_INTERFACE), [DevicePresenceEvent](https://developer.android.com/reference/android/companion/DevicePresenceEvent).

La documentación avisa de limitaciones de direcciones aleatorias. La referencia recomienda RPA resoluble y vínculo Bluetooth si el periférico rota su dirección. Debe comprobarse la estabilidad real del anuncio JK; no forzar bonding sólo para leer si el dispositivo no lo requiere. [Referencia de presencia](https://developer.android.com/reference/android/companion/CompanionDeviceManager#startObservingDevicePresence(android.companion.ObservingDevicePresenceRequest)).

### API 31: arrancar el servicio

Desde target 31, un inicio FGS desde background necesita una excepción. CDM con `REQUEST_COMPANION_START_FOREGROUND_SERVICES_FROM_BACKGROUND` proporciona una vía documentada; Android prefiere ese permiso al más amplio `REQUEST_COMPANION_RUN_IN_BACKGROUND`. Un resultado de scan con `PendingIntent` no aparece como excepción general. No diseñar un bucle de alarmas para eludir esta condición. [Restricciones de inicio FGS](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start).

### API 34+: GPS sin Activity

La excepción para iniciar FGS **no concede por sí sola acceso GPS de uso en primer plano**. Para el flujo realmente automático desde background, diseñar con permiso de ubicación precisa y `ACCESS_BACKGROUND_LOCATION` concedido previamente, además de `FOREGROUND_SERVICE_LOCATION` y ubicación habilitada. Sin ese permiso, conservar conexión/lecturas y ofrecer una acción visible para iniciar GPS; no anunciar que se está grabando una ruta completa. [Tipo location](https://developer.android.com/develop/background-work/services/fgs/service-types#location), [restricciones while-in-use](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start#restrictions-while-in-use).

En Android 11+, el permiso de ubicación en todo momento se habilita en Ajustes; se solicita después del permiso de primer plano, con explicación específica y opción de continuar sin él. [Solicitud de ubicación en segundo plano](https://developer.android.com/develop/sensors-and-location/location/permissions/background).

### Tipo de servicio y API 35/36

BLE sostenido corresponde a `connectedDevice`, con `FOREGROUND_SERVICE_CONNECTED_DEVICE` y permiso Bluetooth concedido. Añadir `location` cuando se utilice GPS, con sus requisitos. `dataSync` no debe representar un vigilante BLE permanente: desde target 35 comparte un presupuesto de seis horas por 24 horas y tiene restricciones de inicio desde boot. [Tipos FGS](https://developer.android.com/develop/background-work/services/fgs/service-types), [timeouts](https://developer.android.com/develop/background-work/services/fgs/timeout).

El manifiesto actual declara `location|dataSync`; en ejecución `LiveNotification.start` elige `location` para GPS real y `dataSync` para demo. La mera declaración de ambos tipos no demuestra que la sesión real esté consumiendo el presupuesto de `dataSync`.

## Flutter: qué existe y qué falta

Se inspeccionó el paquete instalado **flutter_foreground_task 10.0.0**, no sólo su README actual. Su `service/ForegroundTask.kt:49` crea otro `FlutterEngine`; líneas 63–68 ejecutan Dart únicamente si hay `callbackHandle`. `service/ForegroundService.kt:188` usa `START_STICKY` salvo stop-with-task; su reinicio vuelve a crear la tarea. Eso recupera el callback configurado, no los objetos del isolate UI desaparecido. Fuente publicada: [paquete 10.0.0](https://pub.dev/packages/flutter_foreground_task/versions/10.0.0), [archivo exacto del paquete](https://pub.dev/api/archives/flutter_foreground_task-10.0.0.tar.gz).

Actualmente `lib/src/platform/live_notification.dart:47` documenta que trabaja con el isolate principal vivo y `startService` no recibe `callback`. Por tanto, recrear la notificación o activar `autoRunOnBoot` no recupera BmsService, parser, repositorio ni GPS. El plugin admite callbacks top-level/static con `@pragma('vm:entry-point')`, pero hace falta implementar su runtime. [Ejemplo de TaskHandler del autor](https://pub.dev/packages/flutter_foreground_task/versions/10.0.0#how-to-use).

Dos implementaciones razonables del runner, para elegir antes de programar:

1. Reutilizar el TaskHandler del plugin y añadir un puente Kotlin que pueda iniciar su servicio desde CDS con configuración y callback persistidos. La clase `ForegroundServiceManager.start` existe en el source 10.0.0, pero usarla directamente acopla el puente a internals del paquete; requiere controlar esa versión y sus actualizaciones. Parar mediante el manager borra los datos del callback, así que el setup propio debe conservar la intención de vigilancia independientemente del estado actual del servicio.
2. Un servicio Kotlin pequeño crea el motor headless y ejecuta un entrypoint propio; sirve como cargador/propietario del FGS, manteniendo protocolo y viajes en Dart. Evita internals del plugin, pero obliga a integrar notificación y ciclo del motor explícitamente.

Un `FlutterEngine` independiente tiene su propio isolate y no ejecuta Dart por el mero hecho de construirse. Los plugins se registran automáticamente, pero eso no ejecuta `MainActivity.configureFlutterEngine` ni habilita sus canales personalizados. [Referencia FlutterEngine](https://api.flutter.dev/javadoc/io/flutter/embedding/engine/FlutterEngine.html). La UI no debe crear otro propietario BLE/recorder: dos motores no comparten BmsService por compartir proceso.

El source instalado de `flutter_blue_plus_android 9.0.3` usa contexto de aplicación para GATT, pero su rama de solicitud de permisos requiere Activity (`FlutterBluePlusPlugin.java:1572–1585`). Todos los permisos necesarios deben estar concedidos durante el setup; una revocación requiere estado recuperable y aviso, no intentar abrir diálogos desde el motor headless. Destruir su motor desconecta sus GATT (`onDetachedFromEngine`, línea 233). [Source publicado de la dependencia](https://pub.dev/packages/flutter_blue_plus_android/versions/9.0.3).

## Consumo y estados propuestos

Esta máquina de estados es propuesta de implementación, no una garantía de consumo medida:

1. **Desactivado:** sin observación ni conexión automática.
2. **Armado y ausente:** sistema observa la asociación; sin GPS, sin bucle Dart de scans y sin wake lock permanente.
3. **Presente:** runtime único conecta y exige frames válidos antes de marcar “leyendo”. Mantiene observación barata de corriente; GPS apagado.
4. **Conducción probable:** descarga sostenida activa GPS y el FGS correspondiente, respeta permisos y conserva evidencia de la decisión.
5. **Viaje:** recorder existente; persistencia y recuperación idempotentes ante muerte del proceso. Reconectar no crea un segundo viaje.
6. **Reposo/pérdida:** cerrar viaje según la política acordada, apagar GPS y volver al estado de presencia adecuado. Retirar el permiso opt-in cancela observación y libera la conexión.

La presencia no equivale a conducción. Si el BMS anuncia todo el día cerca de casa, apagar por completo el observador después de unos minutos de reposo deja al sistema sin otro borde de aparición cuando empieza el viaje. Hace falta mantener un observador de lecturas mientras esté presente, o autorizar otro disparador como reconocimiento de actividad. El `allowWakeLock: true` actual merece medición en este modo. No prometer cifras de batería sin probar reposo prolongado y movimiento real.

## Ciclo real sin abrir la app y límites

| Situación | Resultado que debe comprobarse |
|---|---|
| Pantalla apagada / UI minimizada | Misma sesión y propietario; GPS sólo cuando corresponde. |
| Proceso eliminado por memoria / UI retirada de recientes | CDS vuelve a enlazar o el servicio se recrea y ejecuta el bootstrap persistido; reconexión y viaje sin duplicados. |
| Reinicio / actualización del paquete | Reconciliar opt-in, asociación y observación tras arranque/desbloqueo; no arrancar ciegamente un FGS prohibido. Debe probarse persistencia real de la observación en el teléfono. |
| Bluetooth/ubicación apagados o permisos revocados | Estado “requiere atención”, sin falso “conectado/grabando”; recuperación al restaurar condiciones. |
| Forzar detención en Ajustes | No prometer reactivación automática. Desde Android 15 se cancelan PendingIntents y el paquete queda parado hasta intervención del usuario. |
| Stop de “Apps activas” Android 13+ | Mata toda la app sin callback de cierre. Es distinto de retirar la tarjeta de recientes y de force-stop; registrar la causa de salida y respetar la intención de parar. |

Fuentes para los dos últimos casos: [estado detenido Android 15](https://developer.android.com/about/versions/15/behavior-changes-all#stopped-state), [parada de FGS por el usuario](https://developer.android.com/develop/background-work/services/fgs/handle-user-stopping).

## Validación mínima antes de afirmar que funciona

- Asociación BLE real y dirección/anuncio estable; demostrar el callback nativo con la Activity inexistente.
- Arranque frío tras muerte del proceso, tras retirar recientes, con pantalla bloqueada y después de reiniciar/desbloquear.
- Conexión que recibe frames JK válidos, no sólo evento GATT conectado; tolerar la app oficial ocupando el único enlace.
- Movimiento real: comienzo de viaje, GPS y distancia; parar, perder alcance y volver sin duplicación.
- Varias horas cerca del BMS sin conducir: GPS inactivo, wake locks y batería medidos; después salir sin reabrir la app.
- Permisos rechazados/revocados, Bluetooth apagado, force-stop y Stop de Apps activas diferenciados en la UX.

No se realizaron estas comprobaciones en esta investigación. La documentación establece las piezas disponibles; el comportamiento del anuncio JK, el coste del runtime y la recuperación exacta en el Pixel requieren evidencia física.

## Aclaración posterior: teléfono con API 37

La comprobación del equipo de trabajo identificó API 37 en el teléfono objetivo, por lo que la rama de presencia debe usar `SDK_INT >= 36`, no una igualdad con 36. La documentación actual de Android 17 añade recuperación autónoma de vínculos Bluetooth perdidos y límites de memoria aplicables a todas las apps. No proporciona una nueva exención que elimine los requisitos descritos de inicio FGS y GPS. Esta implementación puede mantener target/compile 36 sin invocar símbolos exclusivos de 37; requiere validación física en el sistema realmente instalado. [Cambios Android 17 para todas las apps](https://developer.android.com/about/versions/17/behavior-changes-all).
