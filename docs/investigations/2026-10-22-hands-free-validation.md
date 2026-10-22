# Conexión y viajes sin abrir la app

Versión preparada: 2.31.0+2077. Base: v2.30.1 (`fb904e2`).

## Problema y alcance

El inicio automático de v2.30.1 funciona en el teléfono del usuario, pero empezó
unos 600 m después de arrancar. La conexión al acercarse estaba desactivada:
antes fallaba y después tampoco permitía conectar manualmente hasta reiniciar
el teléfono. Se pide recuperar también tras reinicio y retirada de recientes.

No hay una traza física del arranque que permita atribuir los 600 m a una única
causa. El código sí posponía encender el GPS hasta detectar consumo y descartaba
el recorrido previo a confirmar 20 s de movimiento. Un replay reproduce 52 s sin
fix más 20 s de confirmación; es un escenario sintético, no la medición del viaje.

## Cambios

- `CompanionDeviceManager`/`CompanionDeviceService`, con consentimiento explícito,
  observación de una batería conocida y restauración tras boot/actualización.
  API 31–35 utiliza los callbacks correspondientes; API 36+ usa associationId y
  eventos independientes de presencia BLE y conexión Bluetooth.
- Un único FlutterEngine compartido por Activity y servicio nativo. La app conserva
  un único BmsService, recorder y repositorio; no hay un segundo lector en otro
  isolate. Arrancar por presencia no abre Activity, scan de la pantalla, permisos
  modales ni búsqueda de actualizaciones.
- Coordinador de proximidad independiente de navegación. La acción manual toma
  prioridad antes de usar la radio. El watcher cancela sus propias suscripciones
  y deadlines, nunca un `stopScan` global sobre la búsqueda siguiente. Los anuncios
  legacy caducan; la presencia nativa dura hasta la ausencia explícita.
- Un intento automático respeta el presupuesto del transporte. Agotarlo requiere
  ausencia estable de 15 s, regreso y cooldown de 5 min para reintentar, o acción
  explícita del usuario. La desconexión manual exige ausencia y regreso, sin
  confundir un flap GATT corto con alejarse de la moto.
- GPS preparado durante 45 s desde la primera lectura útil. Se detiene en reposo;
  el consumo vuelve a armarlo. Pre-roll acotado a 512 eventos/120 s conserva
  posiciones y lecturas observadas durante la confirmación. El inicio manual
  sigue sin prehistoria. Se rechazan fixes antiguos, futuros o inválidos.
- El tipo del FGS sigue preparado para ubicación aunque el GPS descanse. El
  wake lock tiene leases acotadas y sigue la actividad real del GPS. Ambos relevos
  entre backend nativo y legado confirman el nuevo servicio antes de liberar el
  anterior. Un claim Dart de otro proceso no se restaura desde preferencias.
- Configuración y recuperación accesibles también sin BMS conectado, con permisos
  y estado en español/inglés. No se activa hasta finalizar la asociación; cancelar
  restaura la conexión que hubo que liberar para que el BMS anunciara.

## Evidencia local

- Kotlin compila; 12/12 pruebas JVM (lifecycle y energía) pasan.
- Suite completa: **1.560/1.560 pruebas verdes**, incluidos pre-roll, GPS,
  detector, replays históricos, recorder, pausa, energía y arbitraje de FGS.
- Revisión final: retirado el scan pendiente al cancelar/abrir Ajustes, reset
  Bluetooth con prioridad manual y handoff compartido entre solicitudes manuales
  concurrentes. Revalidación posterior: **28/28 pruebas de radio/coordinación**
  y **4/4 de UI**, incluida cancelación durante preparación Bluetooth.
- Los casos de radio utilizan FlutterBluePlus con FakeGatt y decodifican frames
  JK tras recuperación manual del mismo MAC después de agotar 12 intentos.
- Puente/configuración/relevos: **26/26 pruebas verdes** antes de añadir la cuarta
  prueba UI. Ambos relevos conservan el servicio anterior si falla su sucesor.
- `flutter analyze --no-pub` limpio y análisis posterior de los cuatro archivos
  afectados por la revisión final limpio. `git diff --check` limpio.
- Revalidación final del setup/target/coordinación/UI: **39/39 pruebas verdes**.
- APK release para arm64-v8a, armeabi-v7a y x86_64 compiladas con versión 2.31.0,
  códigos 4077/3077/6077 y el mismo certificado que v2.30.1:
  `61c3662b6e2e552926c25df2bdce0d247f1c9fec99847b4f31c19a4074de40c6`.
- ARM64 instalada mediante actualización sobre v2.30.1 en el Pixel 6/API 37.
  Arranca sin errores Flutter/AndroidRuntime en la comprobación inicial y mantiene
  las 11 baterías guardadas. Antes de instalar se verificó que la pantalla de
  conexión no tenía batería activa; no se simuló un viaje ni se borraron datos.
- Entrega: [v2.31.0](https://github.com/yt-kevincarrera/jk-bms-plus/releases/tag/v2.31.0),
  con las tres APK y SHA256SUMS. La comprobación física anterior sólo acredita
  instalación/arranque y conservación de las baterías guardadas.

## Validación física pendiente

La compilación y los dobles de radio no prueban las políticas del teléfono real.
El usuario conectó y desbloqueó el teléfono para actualizarlo, pero no puede
acercar/encender el BMS ahora y pidió probarlo después. Por tanto no se realizó
asociación, reinicio ni retirada de recientes como prueba de recuperación con BMS.
Se debe completar el consentimiento CDM en Android con la batería encendida y
libre de otra conexión. Después comprobar lecturas y viaje con pantalla apagada,
retirada de recientes, proceso recreado normalmente, reinicio y regreso al alcance.
Registrar en cada caso el estado del servicio, primera lectura, primer fix,
candidato y confirmación del viaje. No simular un recorrido ni conceder el
consentimiento del sistema por comandos para declarar éxito.

La función requiere Android 12+ con companion device setup, Nearby Devices,
notificaciones y ubicación precisa «Permitir siempre». La notificación/conexión
se mantiene mientras la batería esté presente y excluye a la app oficial del BMS.
Forzar detención desde Ajustes es una decisión del usuario que Android respeta:
hay que abrir la app de nuevo. No se puede reconstruir distancia sin posiciones GPS.
