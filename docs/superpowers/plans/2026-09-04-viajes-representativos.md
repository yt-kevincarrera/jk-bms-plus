# Viajes representativos y el viaje del bolsillo: plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que un viaje se grabe solo con el teléfono en el bolsillo y lo diga, y que un viaje que no representa la forma normal de manejar pueda quedar fuera del aprendizaje de autonomía con un toque.

**Architecture:** Dos fases secuenciales. La fase A arregla el viaje automático: el servicio en primer plano pasa a ser de tipo location mientras el detector necesita GPS, alguien escucha por fin `autoTripEvents`, y el resumen de un viaje cerrado solo se guarda en lugar de descartarse. La fase B agrega una marca de tres estados por viaje (sin responder, normal, excepción) que `tripsForLearning` respeta, apoyada en la reconstrucción desde cero que el servicio ya hace.

**Tech Stack:** Flutter, Dart, drift (SQLite con generación de código), geolocator, flutter_foreground_task, l10n con archivos `.arb`.

**Spec:** `docs/superpowers/specs/2026-09-04-viajes-representativos-design.md`

## Global Constraints

- **Nunca se escribe al BMS.** Todo es lectura, cálculo y presentación. Regla del PRD v1.0, sigue vigente.
- **Nada de em dashes**, ni en el código, ni en los comentarios, ni en las traducciones. Especialmente en español.
- **Umbral para preguntar: 5%.** El viaje pregunta solo si movería la cifra aprendida más de 0.05 en fracción. Va como constante con nombre.
- **Sin respuesta cuenta como normal.** Quien ignore la pregunta se queda con el comportamiento actual y la cifra no cambia.
- **Los dos idiomas siempre.** Cada string nueva va en `lib/l10n/app_es.arb` (plantilla) y en `lib/l10n/app_en.arb`, y después se regenera.
- **Los comentarios explican el por qué, no el qué.** Es el estilo de todo el repo: cada decisión no obvia dice contra qué falló antes.
- **Tests:** `flutter test`. Regenerar drift: `dart run build_runner build --delete-conflicting-outputs`. Regenerar traducciones: `flutter gen-l10n`.
- **Base:** rama `feat/viajes-representativos`, sobre `main` en 9ed439b.
- **Fixtures de test, nombres reales.** Verificados en el repo, no supuestos: la base es `AppDatabase.forTesting(NativeDatabase.memory())`, el repositorio es `BmsRepository(database: db)` (parámetro `database`, no `db`), y un servicio conectado se arma como en el `setUp` de `test/foreground_service_test.dart`: `BmsService(transport: FakeLink(), locationFactory: StubLocation.new)`, después `await service.connect('AA:BB', name: 'KevinJK')`, después alimentar una lectura. `applySettings` exige `haptics` y `rawFrames`. No inventar ayudantes nuevos donde ya hay uno.

## Corrección respecto a la spec

El defecto 4 de la spec (la notificación del viaje automático decía "Trip" en inglés con cuerpo vacío) **ya está arreglado en main**. `lib/src/app.dart:180-190` asigna `notificationTitle` y `notificationText` con las traducciones, y el comentario dice exactamente por qué. Lo que queda es un resto: `lib/src/ui/trip_screen.dart:62-63` sigue asignando lo mismo, redundante. Se borra en la Tarea 6.

Los otros tres defectos siguen tal cual, verificados sobre 9ed439b:

- No hay `ACCESS_BACKGROUND_LOCATION` en el manifest, y `bms_service.dart:1314` pasa `usesRealLocation` solo cuando el reclamo es `trip`.
- `autoTripEvents` no tiene un solo oyente en `lib` ni en `test`.
- `bms_service.dart:1422` llama a `stopTrip()` y tira el `TripOutcome`.

---

## Estructura de archivos

**Fase A: el viaje del bolsillo**

| Archivo | Responsabilidad |
|---|---|
| `lib/src/metrics/trip_autostart.dart` | Modificar: `AutoTripAction` gana el caso `blocked` |
| `lib/src/bms_service.dart` | Modificar: tipo location del servicio, emitir `blocked`, texto transitorio de viaje guardado |
| `lib/src/app.dart` | Modificar: el oyente de `autoTripEvents` y el `ScaffoldMessenger` global |
| `android/app/src/main/AndroidManifest.xml` | Modificar: `ACCESS_BACKGROUND_LOCATION` |
| `lib/src/ui/trip_screen.dart` | Modificar: borrar la asignación redundante de la notificación |

**Fase B: la marca de representatividad**

| Archivo | Responsabilidad |
|---|---|
| `lib/src/metrics/range_estimator.dart` | Modificar: `projectedShiftFraction`, la constante del umbral |
| `lib/src/data/database.dart` | Modificar: dos columnas, migración a schema 12, dos consultas |
| `lib/src/data/repository.dart` | Modificar: el filtro de aprendizaje, el setter, el viaje con resumen pendiente |
| `lib/src/bms_service.dart` | Modificar: `setTripRepresentative` que reconstruye |
| `lib/src/ui/widgets/trip_summary_view.dart` | **Crear:** el modelo que alimenta la hoja desde un `TripOutcome` o desde una fila guardada |
| `lib/src/ui/widgets/trip_summary_sheet.dart` | **Crear:** la hoja de resumen, sacada de `trip_screen.dart` para que se pueda abrir desde dos lugares |
| `lib/src/ui/widgets/representative_question.dart` | **Crear:** la pregunta y su confirmación, un solo widget reutilizado en la hoja y en el detalle |
| `lib/src/ui/trip_screen.dart` | Modificar: la hoja consume `TripSummaryView` y muestra la pregunta |
| `lib/src/ui/trip_detail_screen.dart` | Modificar: la pregunta, respondible después |
| `lib/src/ui/connect_screen.dart` | Modificar: el resumen pendiente al abrir la app |

Los dos widgets nuevos existen para que la pregunta se escriba una vez y aparezca en tres lugares, y para que la hoja deje de depender de haber estado presente cuando el viaje terminó.

---

# Fase A: el viaje del bolsillo

## Task 1: El servicio pide tipo location mientras el detector necesita GPS

Este es el defecto que rompe el escenario completo. El armado del GPS previo al viaje corre con el reclamo `link`, que arranca el servicio sin tipo location, y Android sostiene ubicación en segundo plano solo a un servicio de tipo location.

Hay una trampa adicional que decide la forma de la solución: `_updateForegroundService` para y arranca el servicio cuando cambia de dueño, y arrancar un servicio de tipo location **desde segundo plano** está restringido en Android 12 y superiores. Así que el servicio tiene que nacer con tipo location desde el momento en que estamos conectados y el auto arranque está encendido, y no cambiar de tipo con la pantalla apagada.

**Files:**
- Modify: `lib/src/bms_service.dart:1314`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Test: `test/foreground_service_test.dart`

**Interfaces:**
- Consumes: nada de tareas anteriores.
- Produces: `BmsService.serviceUsesLocationForTest` como `bool`, para que el test pueda leer la decisión sin arrancar un servicio real.

- [ ] **Step 1: Write the failing test**

En `test/foreground_service_test.dart`, dentro del grupo que ya existe:

```dart
test('the service is location-typed while auto-start needs a fix', () async {
  // The pre-trip GPS arming used to run under a dataSync-typed service, and
  // Android only sustains background location for a location-typed one. With
  // the screen off the fixes stopped, the detector saw no speed, and a ride
  // that needs speed to start never started.
  service.applySettings(haptics: false, rawFrames: false, autoTrip: true);
  link.announce(BleLinkState.connected);
  await pumpEventQueue();

  expect(service.claimForTest, ServiceClaim.link);
  expect(service.serviceUsesLocationForTest, isTrue);
});

test('and not location-typed when auto-start is off', () async {
  // Nothing is watching for a ride, so nothing needs the GPS. Claiming the
  // location type without using it is what Android 14 refuses.
  service.applySettings(haptics: false, rawFrames: false, autoTrip: false);
  link.announce(BleLinkState.connected);
  await pumpEventQueue();

  expect(service.claimForTest, ServiceClaim.link);
  expect(service.serviceUsesLocationForTest, isFalse);
});
```

Van dentro del grupo `'who gets the one foreground service'`, que ya tiene el `setUp` con `link`, `db` y `service` armados y conectados. No crear un servicio nuevo a mano.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/foreground_service_test.dart`
Expected: FAIL con "The getter 'serviceUsesLocationForTest' isn't defined".

- [ ] **Step 3: Write minimal implementation**

En `lib/src/bms_service.dart`, reemplazar la línea 1314:

```dart
      usesRealLocation: _serviceNeedsLocation(wanted),
```

Y agregar, junto a `claimForTest`:

```dart
  /// Whether the service has to be location-typed for this claim.
  ///
  /// True for a ride, obviously. Also true for a bare connection while the
  /// auto-start detector is armed, and that second half is the whole point:
  /// the GPS arming that precedes a ride used to run under a dataSync-typed
  /// service, and Android sustains background location only for a
  /// location-typed one. With the screen off the fixes stopped arriving, the
  /// detector read no speed, and a ride that needs speed to begin could never
  /// begin.
  ///
  /// Decided by the claim rather than by whether a location stream happens to
  /// be open, because the service is stopped and restarted when its type
  /// changes, and starting a location-typed service *from the background* is
  /// what Android 12 refuses. So it has to be born with the type it will need,
  /// while the app is still on screen, rather than acquire it later in a
  /// pocket.
  bool _serviceNeedsLocation(ServiceClaim claim) {
    if (isDemo) return false;
    if (claim == ServiceClaim.trip) return true;
    return claim == ServiceClaim.link && autoTripEnabled;
  }

  @visibleForTesting
  bool get serviceUsesLocationForTest {
    final claim = _claim;
    return claim != null && _serviceNeedsLocation(claim);
  }
```

En `android/app/src/main/AndroidManifest.xml`, después del bloque de `ACCESS_COARSE_LOCATION`:

```xml
    <!-- The auto-start detector needs a fix before a trip exists, and asks for
         it with the screen off. A location-typed foreground service covers that
         on most devices; this is the permission Android falls back to asking
         for when it does not, and it is requested only if the device test in
         the plan shows the service type is not enough. -->
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/foreground_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/bms_service.dart android/app/src/main/AndroidManifest.xml test/foreground_service_test.dart
git commit -m "Give the service the location type before the ride, not after"
```

---

## Task 2: El detector dice cuando no pudo abrir el viaje

Hoy, si falta el permiso de ubicación, `startTrip` devuelve un problema, no se graba nada, y el evento solo se emite cuando **no** hubo problema. Se puede manejar semanas creyendo que la app aprende.

**Files:**
- Modify: `lib/src/metrics/trip_autostart.dart` (el enum)
- Modify: `lib/src/bms_service.dart:1417-1420`
- Test: `test/trip_autostart_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces: `AutoTripAction.blocked`, emitido en `BmsService.autoTripEvents` cuando `startTrip()` falla. La Tarea 3 lo escucha.

- [ ] **Step 1: Write the failing test**

En `test/trip_autostart_test.dart`:

```dart
test('a ride that could not open says so instead of going quiet', () async {
  // The silent version of this is the worst bug in the feature: the rider
  // believes the app is learning, the app records nothing, and the range
  // figure never appears. The problem used to be stored in
  // lastLocationProblem and read by nobody.
  //
  // The refusal comes from the injected location source rather than from a
  // test-only setter on the service: locationFactory is the seam that already
  // exists, and one seam is enough.
  final link = FakeLink();
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final service = BmsService(
    transport: link,
    locationFactory: RefusingLocation.new,
  )..repository = BmsRepository(database: db);
  addTearDown(service.dispose);
  await service.connect('AA:BB', name: 'KevinJK');
  service.applySettings(haptics: false, rawFrames: false, autoTrip: true);

  final events = <AutoTripAction>[];
  service.autoTripEvents.listen(events.add);

  await service.forceAutoTripStartForTest();
  await pumpEventQueue();

  expect(events, [AutoTripAction.blocked]);
});
```

Con la fuente que se niega, declarada en el mismo archivo de test:

```dart
/// A location source that refuses, so the blocked path can be exercised.
class RefusingLocation implements LocationSource {
  @override
  Stream<GeoFix> get fixes => const Stream<GeoFix>.empty();
  @override
  Future<LocationProblem?> start() async => LocationProblem.permissionDenied;
  @override
  Future<void> stop() async {}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/trip_autostart_test.dart`
Expected: FAIL con "The getter 'blocked' isn't defined for the type 'AutoTripAction'".

- [ ] **Step 3: Write minimal implementation**

En `lib/src/metrics/trip_autostart.dart`, ampliar el enum. Nota: `blocked` no lo devuelve nunca `evaluate`, lo emite el servicio; se declara acá porque es el mismo canal de eventos.

```dart
/// What the detector thinks should happen.
///
/// [blocked] is never returned by [TripAutoStart.evaluate]. It travels on the
/// same event channel because it answers the same question the rider is
/// asking: is a ride being recorded right now. A start that failed for want of
/// location used to answer it with silence.
enum AutoTripAction { none, start, stop, blocked }
```

En `lib/src/bms_service.dart`, reemplazar el caso `start`:

```dart
      case AutoTripAction.start:
        final problem = await startTrip();
        // No location, no ride: distance is the whole point, and a trip with
        // no track would poison the consumption figure with a divide by zero.
        // But saying nothing is worse than not recording: the rider goes on
        // believing the app is learning while it rejects every ride.
        _autoTripController.add(
          problem == null ? AutoTripAction.start : AutoTripAction.blocked,
        );
```

Y una sola costura de test, junto a `claimForTest`. Corre la rama real, no una copia de ella, para que el test no pueda pasar mientras la de producción está mal:

```dart
  /// Runs the detector's start branch directly.
  ///
  /// The branch itself needs sustained current and speed over twenty seconds
  /// to fire, which a unit test cannot wait for. What is worth testing is not
  /// the timing, which [TripAutoStart] already covers, but that a start which
  /// failed says so.
  @visibleForTesting
  Future<void> forceAutoTripStartForTest() =>
      _runAutoTripAction(AutoTripAction.start);
```

Para eso, el `switch` de `_updateAutoTrip` se extrae a un método propio, `Future<void> _runAutoTripAction(AutoTripAction action)`, y `_updateAutoTrip` pasa a llamarlo. Así la costura ejecuta exactamente el mismo código que la ruta real.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/trip_autostart_test.dart`
Expected: PASS. Además `flutter test` completo, porque ampliar un enum rompe cualquier `switch` exhaustivo sobre él; el analizador lo señala y hay que agregar el caso donde falte.

- [ ] **Step 5: Commit**

```bash
git add lib/src/metrics/trip_autostart.dart lib/src/bms_service.dart test/trip_autostart_test.dart
git commit -m "Say it when a ride could not open for want of location"
```

---

## Task 3: Alguien escucha por fin los eventos del viaje automático

`autoTripEvents` no tiene oyentes. `autoTripStarted` ("Viaje iniciado solo") y `autoTripStopped` ("Viaje guardado") están traducidos a los dos idiomas y nunca se muestran. El oyente va a nivel de app y no de pantalla, porque el caso normal es que no haya ninguna pantalla de viaje abierta.

**Files:**
- Modify: `lib/src/app.dart`
- Modify: `lib/src/ui/trip_screen.dart:62-63` (borrar la asignación redundante)
- Modify: `lib/l10n/app_es.arb`, `lib/l10n/app_en.arb`

**Interfaces:**
- Consumes: `AutoTripAction.blocked` de la Tarea 2.
- Produces: `_JkBmsAppState._messenger`, un `GlobalKey<ScaffoldMessengerState>` pasado a `MaterialApp.scaffoldMessengerKey`. Solo lo usa el oyente de esta tarea; las pantallas usan `ScaffoldMessenger.of(context)` como siempre.

- [ ] **Step 1: Add the strings**

En `lib/l10n/app_es.arb`:

```json
  "autoTripBlocked": "No pude grabar el viaje: falta el permiso de ubicación. Sin él la app no aprende tu autonomía.",
  "@autoTripBlocked": {},
```

En `lib/l10n/app_en.arb`:

```json
  "autoTripBlocked": "Could not record the ride: location permission is missing. Without it the app learns no range.",
  "@autoTripBlocked": {},
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the listener**

En `lib/src/app.dart`, en `_JkBmsAppState`:

```dart
  /// So a ride that starts or ends with no trip screen open can still say so.
  ///
  /// The events had no listener at all: two translated strings that could
  /// never appear, and a ride recorded in a pocket that the rider learned
  /// about only by going looking for it.
  final GlobalKey<ScaffoldMessengerState> _messenger =
      GlobalKey<ScaffoldMessengerState>();

  StreamSubscription<AutoTripAction>? _autoTripSub;

  /// Set once the localisations exist, and read by the subscription below.
  /// The stream fires from the service, which has no opinion about language.
  String Function(AutoTripAction)? _autoTripMessage;
```

En `initState`, después de `_service.repository = _repository;`:

```dart
    _autoTripSub = _service.autoTripEvents.listen((action) {
      final text = _autoTripMessage?.call(action);
      if (text == null) return;
      _messenger.currentState?.showSnackBar(SnackBar(content: Text(text)));
    });
```

En `dispose`, antes de `super.dispose()`:

```dart
    unawaited(_autoTripSub?.cancel());
```

En `MaterialApp`, agregar:

```dart
          scaffoldMessengerKey: _messenger,
```

Y en el `home: Builder`, junto a las otras asignaciones de strings al servicio:

```dart
              _autoTripMessage = (action) => switch (action) {
                AutoTripAction.start => t.autoTripStarted,
                AutoTripAction.stop => t.autoTripStopped,
                AutoTripAction.blocked => t.autoTripBlocked,
                AutoTripAction.none => '',
              };
```

Nota: el caso `none` devuelve cadena vacía y no se muestra, porque el servicio nunca lo emite; está para que el `switch` sea exhaustivo sin un `default` que se coma un caso nuevo en silencio.

- [ ] **Step 3: Delete the redundant assignment**

En `lib/src/ui/trip_screen.dart`, borrar las líneas 62 a 71 (la asignación de `notificationTitle` y `notificationText`). `lib/src/app.dart` ya las fija al arrancar, para los dos casos, y tenerlas en dos lugares invita a que se separen.

- [ ] **Step 4: Verify**

Run: `flutter analyze && flutter test`
Expected: sin errores, todos los tests pasan.

- [ ] **Step 5: Commit**

```bash
git add lib/src/app.dart lib/src/ui/trip_screen.dart lib/l10n/
git commit -m "Let a ride that starts or ends on its own say so"
```

---

## Task 4: La notificación dice que el viaje se guardó

Al cerrarse el viaje, el reclamo del servicio pasa de `trip` a `link`, porque seguís conectado. Eso da un lugar gratis para el aviso: la misma notificación, sin permiso nuevo ni plugin nuevo.

**Files:**
- Modify: `lib/src/bms_service.dart`
- Modify: `lib/src/app.dart`
- Modify: `lib/l10n/app_es.arb`, `lib/l10n/app_en.arb`
- Test: `test/foreground_service_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces: `BmsService.rideSavedText` de tipo `String Function(double km, double? whPerKm)?`, y `BmsService.rideSavedFor` de tipo `Duration`.

- [ ] **Step 1: Write the failing test**

```dart
test('the notification says a ride was saved, then goes back to normal',
    () async {
  // Arriving home with the phone in a pocket used to give nothing at all: the
  // summary was discarded and the notification went straight back to the
  // connected readout. The one notification slot is free at that moment, so
  // it carries the news instead of a second notification being invented.
  link.announce(BleLinkState.connected);
  await pumpEventQueue();
  expect(service.claimForTest, ServiceClaim.link);

  service.rideSavedText = (km, whPerKm) =>
      'Guardado ${km.toStringAsFixed(1)} km';
  service.linkWatchText = (_) => 'conectado';

  service.noteRideSavedForTest(km: 23.4, whPerKm: 18);
  expect(service.serviceTextForTest, 'Guardado 23.4 km');

  service.expireRideSavedForTest();
  expect(service.serviceTextForTest, 'conectado');
});
```

Va en el mismo grupo que la Tarea 1, con el `setUp` que ya existe.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/foreground_service_test.dart`
Expected: FAIL con "The setter 'rideSavedText' isn't defined".

- [ ] **Step 3: Write minimal implementation**

En `lib/src/bms_service.dart`, junto a `linkWatchText`:

```dart
  /// What the notification says just after a ride is stored.
  ///
  /// Rides end in a pocket more often than on screen, and the summary sheet
  /// needs the app to be open. The one notification slot is free at that exact
  /// moment, because the trip claim has just been released and the link claim
  /// has taken over, so it carries the news for a few minutes rather than a
  /// second notification being invented for it.
  String Function(double km, double? whPerKm)? rideSavedText;

  /// How long that text stands before the normal connected readout returns.
  Duration rideSavedFor = const Duration(minutes: 5);

  DateTime? _rideSavedUntil;
  double _rideSavedKm = 0;
  double? _rideSavedWhPerKm;

  bool get _rideSavedStanding {
    final until = _rideSavedUntil;
    return until != null && DateTime.now().toUtc().isBefore(until);
  }
```

En `_serviceText`, cambiar el caso `link`:

```dart
    ServiceClaim.link => _rideSavedStanding
        ? rideSavedText?.call(_rideSavedKm, _rideSavedWhPerKm) ?? ''
        : linkWatchText?.call(_lastSnapshot) ?? '',
```

En `stopTrip`, después de `await relearnRangeFromTrips();`:

```dart
      // Before the service is brought into line below, so the first
      // notification the rider sees after arriving is the news and not the
      // connected readout.
      _rideSavedKm = summary.distanceKm;
      _rideSavedWhPerKm = summary.whPerKm;
      _rideSavedUntil = DateTime.now().toUtc().add(rideSavedFor);
      await _updateForegroundService();
```

Y los ayudantes de test:

```dart
  @visibleForTesting
  String get serviceTextForTest {
    final claim = _claim;
    return claim == null ? '' : _serviceText(claim);
  }

  @visibleForTesting
  void noteRideSavedForTest({required double km, double? whPerKm}) {
    _rideSavedKm = km;
    _rideSavedWhPerKm = whPerKm;
    _rideSavedUntil = DateTime.now().toUtc().add(rideSavedFor);
  }

  @visibleForTesting
  void expireRideSavedForTest() => _rideSavedUntil = null;
```

- [ ] **Step 4: Add the strings and wire them**

`lib/l10n/app_es.arb`:

```json
  "rideSavedNotif": "Viaje guardado: {km} km, {whPerKm} Wh/km",
  "@rideSavedNotif": { "placeholders": { "km": {}, "whPerKm": {} } },
  "rideSavedNotifNoConsumption": "Viaje guardado: {km} km",
  "@rideSavedNotifNoConsumption": { "placeholders": { "km": {} } },
```

`lib/l10n/app_en.arb`:

```json
  "rideSavedNotif": "Ride saved: {km} km, {whPerKm} Wh/km",
  "@rideSavedNotif": { "placeholders": { "km": {}, "whPerKm": {} } },
  "rideSavedNotifNoConsumption": "Ride saved: {km} km",
  "@rideSavedNotifNoConsumption": { "placeholders": { "km": {} } },
```

Run: `flutter gen-l10n`

En `lib/src/app.dart`, junto a `_service.linkWatchText`:

```dart
              _service.rideSavedText = (km, whPerKm) => whPerKm == null
                  ? t.rideSavedNotifNoConsumption(km.toStringAsFixed(1))
                  : t.rideSavedNotif(
                      km.toStringAsFixed(1),
                      whPerKm.toStringAsFixed(0),
                    );
```

- [ ] **Step 5: Run tests and commit**

Run: `flutter test`
Expected: PASS

```bash
git add lib/src/bms_service.dart lib/src/app.dart lib/l10n/ test/foreground_service_test.dart
git commit -m "Tell the rider a ride was saved, where they will actually see it"
```

---

# Fase B: la marca de representatividad

## Task 5: Cuánto movería la cifra este viaje

El disparador está atado a la consecuencia, no al desvío: un viaje raro de 2 km no puede mover nada y no debe preguntar nada.

**Files:**
- Modify: `lib/src/metrics/range_estimator.dart`
- Test: `test/range_weighting_test.dart`

**Interfaces:**
- Produces: `RangeEstimator.projectedShiftFraction({required double wh, required double km})` devuelve `double`, la fracción del promedio actual que la cifra se movería si esa muestra entrara. Devuelve 0 si la muestra sería rechazada. `RangeEstimator.askThresholdFraction` es `0.05`.

- [ ] **Step 1: Write the failing test**

```dart
group('when a ride is worth asking about', () {
  // The trigger is what the ride would do to the number, not how far off the
  // ride was. A weird 2 km errand cannot move a 40 km half-life average, so
  // asking about it would be noise with no consequence behind it.

  test('a long ride slightly off is worth asking about', () {
    // 40 km at 14% below a learned 17.5 moves the figure 6.3%, past the line.
    // The break-even for a 40 km ride is 15.53 Wh/km, or 11.25% below, so this
    // sits clear of it rather than on it: a test balanced on the threshold
    // passes or fails on the last bit of a double.
    final e = RangeEstimator()..addSegment(wh: 17.5 * 100, km: 100);
    final shift = e.projectedShiftFraction(wh: 15.0 * 40, km: 40);
    expect(shift, greaterThan(RangeEstimator.askThresholdFraction));
  });

  test('and a long ride just inside the line is not', () {
    // 15.6 Wh/km is 10.9% below, which moves the figure 4.8%. Under the
    // threshold, so it passes without a word. This is the case that decides
    // whether the feature nags: an ordinary day is a few percent off, and a
    // few percent must stay silent.
    final e = RangeEstimator()..addSegment(wh: 17.5 * 100, km: 100);
    final shift = e.projectedShiftFraction(wh: 15.6 * 40, km: 40);
    expect(shift, lessThan(RangeEstimator.askThresholdFraction));
  });

  test('a short ride wildly off is not', () {
    // 5 km at half the usual consumption still cannot move the average by 5%.
    final e = RangeEstimator()..addSegment(wh: 17.5 * 100, km: 100);
    final shift = e.projectedShiftFraction(wh: 8.75 * 5, km: 5);
    expect(shift, lessThan(RangeEstimator.askThresholdFraction));
  });

  test('it works in both directions', () {
    // A day with a passenger or a headwind is no more representative than a
    // deliberately gentle one, and reads as a rise rather than a fall.
    final e = RangeEstimator()..addSegment(wh: 17.5 * 100, km: 100);
    final high = e.projectedShiftFraction(wh: 26 * 40, km: 40);
    expect(high, greaterThan(RangeEstimator.askThresholdFraction));
  });

  test('a sample the estimator would reject moves nothing', () {
    final e = RangeEstimator()..addSegment(wh: 17.5 * 100, km: 100);
    expect(e.projectedShiftFraction(wh: 5, km: 0.05), 0);
    expect(e.projectedShiftFraction(wh: -10, km: 5), 0);
  });

  test('asking does not change what was learned', () {
    final e = RangeEstimator()..addSegment(wh: 17.5 * 100, km: 100);
    final before = e.whPerKm;
    e.projectedShiftFraction(wh: 26 * 40, km: 40);
    expect(e.whPerKm, before);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/range_weighting_test.dart`
Expected: FAIL con "The method 'projectedShiftFraction' isn't defined".

- [ ] **Step 3: Write minimal implementation**

En `lib/src/metrics/range_estimator.dart`:

```dart
  /// Fraction of the current figure that one more sample would move it by.
  ///
  /// The question a rider is asked has to be worth the interruption, and what
  /// makes it worth it is consequence, not oddity. A 2 km errand at triple the
  /// usual consumption cannot budge a 40 km half-life average, so asking about
  /// it would be a notification about nothing.
  ///
  /// Returns 0 for a sample [addSegment] would reject, so a rejected ride is
  /// never the subject of a question about a change that will not happen.
  ///
  /// Pure: it computes what the fold would do without folding anything in.
  double projectedShiftFraction({required double wh, required double km}) {
    if (km < 0.2 || wh <= 0) return 0;
    final sampleWhPerKm = wh / km;
    if (sampleWhPerKm > 400 || sampleWhPerKm < 2) return 0;

    final current = whPerKm;
    if (current <= 0) return 0;

    final decay = math.pow(0.5, km / halfLifeKm).toDouble();
    final weight = _weight * decay + km;
    if (weight <= 0) return 0;
    final weighted = _weighted * decay + km * sampleWhPerKm;

    return ((weighted / weight) - current).abs() / current;
  }

  /// How much a ride has to move the figure before the rider is asked whether
  /// it represents them.
  ///
  /// Not a law of anything. With a real pack at 17.5 Wh/km and 100 km of
  /// weight behind the estimate, 5% means a 40 km ride asks at 11% off, a
  /// 20 km ride at 23% off, and a 10 km ride at 47% off. Quiet on an ordinary
  /// fast day, which is the point. Named so recalibrating it is one line.
  static const double askThresholdFraction = 0.05;
```

Nota: los tres números mágicos (0.2, 400, 2) están duplicados con `addSegment`. Extraerlos a constantes privadas compartidas dentro de la misma tarea, para que un cambio de criterio no deje las dos mitades en desacuerdo.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/range_weighting_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/metrics/range_estimator.dart test/range_weighting_test.dart
git commit -m "Ask about a ride for its consequence, not for its oddity"
```

---

## Task 6: Las dos columnas y la migración a schema 12

**Files:**
- Modify: `lib/src/data/database.dart`
- Test: `test/migration_test.dart`

**Interfaces:**
- Produces: en la tabla `Trips`, `representative` de tipo `BoolColumn` nullable (null significa sin responder, true normal, false excepción) y `summarySeen` de tipo `BoolColumn` con default `false`. `schemaVersion` pasa a 12.

- [ ] **Step 1: Write the failing test**

En `test/migration_test.dart`:

Dentro del grupo `'upgrading a database that already has history'`, que ya tiene un `setUp` con `raw = _populatedV3()` y `db = AppDatabase.forTesting(NativeDatabase.opened(raw))`. Ese fixture trae un viaje ya insertado y dispara la migración completa al abrir, así que ejercita el salto a 12 sin escribir un esquema a mano:

Los viajes se leen con `db.select(db.trips).get()` y no con `recentTrips`, porque `recentTrips` filtra por pack y el fixture v3 inserta viajes sin `device_id`.

```dart
test('an upgrade leaves old rides unanswered and unseen', () async {
  // Null is not false here. A ride recorded before the question existed was
  // never asked about, and saying "the rider called it normal" would be
  // putting words in their mouth. It counts as normal for the learning, which
  // is the old behaviour, while still reading as unanswered on screen.
  final trips = await db.select(db.trips).get();
  expect(trips, isNotEmpty);

  for (final trip in trips) {
    expect(trip.representative, isNull);
    expect(trip.summarySeen, isFalse);
  }
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/migration_test.dart`
Expected: FAIL con "The getter 'representative' isn't defined for the type 'Trip'".

- [ ] **Step 3: Write minimal implementation**

En `lib/src/data/database.dart`, en `class Trips`, después de `energySource`:

```dart
  /// Whether this ride represents how the rider normally rides.
  ///
  /// Null means nobody was asked, which is different from "yes". A ride
  /// recorded before the question existed, or one whose question was never
  /// answered, counts towards the learning exactly as it did before, and still
  /// reads as unanswered on screen. Only an explicit false takes a ride out.
  ///
  /// The point of it: the estimator has no notion of context, so one
  /// deliberately gentle ride to nurse a low charge moves the learned figure a
  /// third of the way towards a number that is not how this bike gets ridden.
  BoolColumn get representative => boolean().nullable()();

  /// Whether the rider has seen this ride's summary.
  ///
  /// Rides end in a pocket. The summary sheet used to be shown by the stop
  /// button and by nothing else, so a ride that closed itself was stored with
  /// its conclusions and never shown to anybody.
  BoolColumn get summarySeen =>
      boolean().withDefault(const Constant(false))();
```

Subir la versión:

```dart
  @override
  int get schemaVersion => 12;
```

Y en `onUpgrade`, después del bloque `if (from < 11)`:

```dart
      if (from < 12) {
        // Both nullable-or-defaulted, so every existing ride lands in the
        // right place with no backfill: unanswered, and unseen.
        await m.addColumn(trips, trips.representative);
        await m.addColumn(trips, trips.summarySeen);
      }
```

- [ ] **Step 4: Regenerate and run**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/migration_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/data/database.dart lib/src/data/database.g.dart test/migration_test.dart
git commit -m "Remember whether a ride represents the rider, and whether they saw it"
```

---

## Task 7: Una excepción queda fuera del aprendizaje

**Files:**
- Modify: `lib/src/data/database.dart` (los dos setters nuevos, junto a `setTripNote`)
- Modify: `lib/src/data/repository.dart:354`
- Test: `test/range_learning_exclusion_test.dart` (crear)

**Interfaces:**
- Consumes: la columna `representative` de la Tarea 6.
- Produces: `BmsRepository.tripsForLearning` deja de devolver los viajes con `representative == false`.

- [ ] **Step 1: Write the failing test**

Crear `test/range_learning_exclusion_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';

void main() {
  group('a ride the rider called an exception', () {
    test('is not one of the rides the estimate is built from', () async {
      // Deleting the ride was the only way to say this before, and deleting
      // throws away the track and the pack readings with it. A ride can be
      // unrepresentative and still be worth keeping.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = BmsRepository(database: db);
      const device = 'pack-1';

      await _storeRide(repo, device, km: 20, whPerKm: 17.5);
      final exceptionId =
          await _storeRide(repo, device, km: 40, whPerKm: 10.0);

      expect((await repo.tripsForLearning(device)).length, 2);

      await repo.setTripRepresentative(exceptionId, false);
      final kept = await repo.tripsForLearning(device);

      expect(kept.length, 1);
      expect(kept.single.distanceKm, 20);
    });

    test('comes back the moment the rider changes their mind', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = BmsRepository(database: db);
      const device = 'pack-1';
      final id = await _storeRide(repo, device, km: 40, whPerKm: 10.0);

      await repo.setTripRepresentative(id, false);
      expect(await repo.tripsForLearning(device), isEmpty);

      await repo.setTripRepresentative(id, true);
      expect((await repo.tripsForLearning(device)).length, 1);
    });
  });
}
```

Nota: `_storeRide` es un ayudante local que abre un viaje con `beginTrip`, lo cierra con `finishTrip` y devuelve el id, con una `TripSummary` armada a mano. Los constructores estan verificados contra el repo: ver `test/multi_pack_test.dart`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/range_learning_exclusion_test.dart`
Expected: FAIL con "The method 'setTripRepresentative' isn't defined".

- [ ] **Step 3: Write minimal implementation**

En `lib/src/data/database.dart`, junto a `setTripNote`:

```dart
  Future<void> setTripRepresentative(int tripId, bool? value) =>
      (update(trips)..where((t) => t.id.equals(tripId))).write(
        TripsCompanion(representative: Value(value)),
      );

  Future<void> markTripSummarySeen(int tripId) =>
      (update(trips)..where((t) => t.id.equals(tripId))).write(
        const TripsCompanion(summarySeen: Value(true)),
      );
```

En `lib/src/data/repository.dart`, reemplazar el filtro de `tripsForLearning`:

```dart
  Future<List<Trip>> tripsForLearning(String deviceId) async {
    final all = await db.recentTrips(deviceId, limit: 500);
    final usable =
        all
            .where(
              (t) =>
                  t.distanceKm >= 0.2 &&
                  t.energyOutWh > t.energyInWh &&
                  // Null is not false: a ride nobody was asked about counts,
                  // which keeps the behaviour of every ride recorded before
                  // the question existed. Only an explicit no takes one out.
                  t.representative != false,
            )
            .toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return usable;
  }

  Future<void> setTripRepresentative(int tripId, bool? value) =>
      db.setTripRepresentative(tripId, value);

  Future<void> markTripSummarySeen(int tripId) =>
      db.markTripSummarySeen(tripId);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/range_learning_exclusion_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/data/ test/range_learning_exclusion_test.dart
git commit -m "Keep an unrepresentative ride, and stop learning from it"
```

---

## Task 8: Responder cambia la autonomía, y desdecirse la devuelve

El servicio ya reconstruye el estimador desde cero en cada borrado. La respuesta usa el mismo camino, y eso es lo que hace la marca reversible sin código extra.

**Files:**
- Modify: `lib/src/bms_service.dart` (junto a `deleteTrip`)
- Test: `test/range_learning_exclusion_test.dart`

**Interfaces:**
- Consumes: `BmsRepository.setTripRepresentative` de la Tarea 7.
- Produces: `BmsService.setTripRepresentative(int tripId, bool? value)` devuelve `Future<void>` y deja `rangeEstimator` reconstruido.

- [ ] **Step 1: Write the failing test**

```dart
test('answering moves the learned figure, and unanswering puts it back',
    () async {
  // The whole promise of the question: an answer has a visible consequence
  // immediately, and it is reversible. Both fall out of the rebuild the
  // service already does on a delete, which is why the marking goes through
  // the service rather than the repository.
  final link = FakeLink();
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final repo = BmsRepository(database: db);
  final service = BmsService(
    transport: link,
    locationFactory: StubLocation.new,
  )..repository = repo;
  addTearDown(service.dispose);
  // connect() is what sets the active device, and the estimate is rebuilt per
  // pack, so there is no shortcut around it.
  await service.connect('AA:BB', name: 'KevinJK');
  final device = service.activeDeviceId!;

  await _storeRide(repo, device, km: 40, whPerKm: 17.5);
  final gentleId = await _storeRide(repo, device, km: 40, whPerKm: 10.0);
  await service.relearnRangeFromTrips();

  final withGentle = service.rangeEstimator.whPerKm;
  expect(withGentle, lessThan(17.0));

  await service.setTripRepresentative(gentleId, false);
  expect(service.rangeEstimator.whPerKm, closeTo(17.5, 0.01));

  await service.setTripRepresentative(gentleId, true);
  expect(service.rangeEstimator.whPerKm, closeTo(withGentle, 0.01));
});
```

Nota: `FakeLink` y `StubLocation` son las clases falsas que `test/foreground_service_test.dart` ya declara. Copiarlas al archivo nuevo o extraerlas a un `test/support/` compartido; extraerlas es mejor y esta tarea es un buen momento.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/range_learning_exclusion_test.dart`
Expected: FAIL con "The method 'setTripRepresentative' isn't defined for the type 'BmsService'".

- [ ] **Step 3: Write minimal implementation**

En `lib/src/bms_service.dart`, junto a `deleteTrip`:

```dart
  /// Records whether a ride represents how this bike gets ridden, and relearns.
  ///
  /// Goes through the service rather than the repository for the same reason
  /// deleting does: the estimate has to be rebuilt from what is left, or the
  /// answer would be stored and change nothing. Rebuilding is also what makes
  /// the answer reversible for free.
  Future<void> setTripRepresentative(int tripId, bool? value) async {
    await repository?.setTripRepresentative(tripId, value);
    await relearnRangeFromTrips();
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/range_learning_exclusion_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/bms_service.dart test/range_learning_exclusion_test.dart
git commit -m "An answer about a ride changes the range, and can be taken back"
```

---

## Task 9: El resumen deja de depender de haber estado presente

La hoja se construye hoy desde un `TripOutcome`, que solo existe si apretaste parar. Un modelo intermedio la deja construirse igual desde una fila guardada.

**Files:**
- Create: `lib/src/ui/widgets/trip_summary_view.dart`
- Create: `lib/src/ui/widgets/trip_summary_sheet.dart`
- Modify: `lib/src/ui/trip_screen.dart`
- Modify: `lib/src/bms_service.dart` (`lastStoredTripId`)
- Test: `test/trip_summary_view_test.dart` (crear)

**Interfaces:**
- Produces: `TripSummaryView` con los campos `tripId` (`int?`), `distanceKm`, `movingDuration`, `totalDuration`, `maxSpeedKmh`, `averageSpeedKmh`, `climbM`, `descentM`, `energyOutWh`, `energyInWh`, `whPerKm` (`double?`), `whPerKmBefore` (`double?`), `whPerKmAfter` (`double?`), `representative` (`bool?`). Dos constructores con nombre: `TripSummaryView.fromOutcome(TripOutcome outcome, {int? tripId})` y `TripSummaryView.fromStored(Trip trip)`.

- [ ] **Step 1: Write the failing test**

Crear `test/trip_summary_view_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ui/widgets/trip_summary_view.dart';

void main() {
  group('the summary of a ride', () {
    test('reads the same from a stored row as from a fresh stop', () {
      // The sheet used to be built only from what stopTrip returned, so a ride
      // that closed itself had a summary nobody could ever see. The two paths
      // have to agree, or the pocket ride would get a second-class version of
      // the same screen.
      final outcome = _outcome(km: 20, energyOutWh: 350, energyInWh: 0);
      final stored = _storedTrip(km: 20, energyOutWh: 350, energyInWh: 0);

      final fromStop = TripSummaryView.fromOutcome(outcome, tripId: 7);
      final fromRow = TripSummaryView.fromStored(stored);

      expect(fromRow.distanceKm, fromStop.distanceKm);
      expect(fromRow.whPerKm, fromStop.whPerKm);
      expect(fromRow.movingDuration, fromStop.movingDuration);
    });

    test('a stored row carries the answer already given', () {
      final stored = _storedTrip(
        km: 20,
        energyOutWh: 350,
        energyInWh: 0,
        representative: false,
      );
      expect(TripSummaryView.fromStored(stored).representative, isFalse);
    });
  });
}
```

Nota: `_outcome` y `_storedTrip` son ayudantes locales que arman un `TripOutcome` y un `Trip` a mano. Para el `Trip`, usar el constructor generado por drift con todos sus campos.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/trip_summary_view_test.dart`
Expected: FAIL, el archivo `trip_summary_view.dart` no existe.

- [ ] **Step 3: Write minimal implementation**

Crear `lib/src/ui/widgets/trip_summary_view.dart`:

```dart
import '../../data/database.dart';
import '../../metrics/trip_recorder.dart';

/// Everything the end-of-ride sheet shows, from either of the two places a
/// ride can be read.
///
/// The sheet used to take a [TripOutcome], which only exists in the moment the
/// stop button is pressed. Rides end in a pocket more often than that, and a
/// ride that closed itself was stored with its conclusions and shown to
/// nobody. This is the one shape both paths produce, so the pocket ride gets
/// the same screen and not a lesser version of it.
class TripSummaryView {
  const TripSummaryView({
    required this.tripId,
    required this.distanceKm,
    required this.movingDuration,
    required this.totalDuration,
    required this.maxSpeedKmh,
    required this.climbM,
    required this.descentM,
    required this.energyOutWh,
    required this.energyInWh,
    required this.whPerKmBefore,
    required this.whPerKmAfter,
    required this.representative,
  });

  /// Null only for a ride that was never given a row, which happens when
  /// there is no repository at all. The question needs an id to record an
  /// answer against, and hides itself without one.
  final int? tripId;

  final double distanceKm;
  final Duration movingDuration;
  final Duration totalDuration;
  final double maxSpeedKmh;
  final double climbM;
  final double descentM;
  final double energyOutWh;
  final double energyInWh;

  /// What the estimate said before and after this ride was folded in.
  final double? whPerKmBefore;
  final double? whPerKmAfter;

  /// Null means nobody has been asked yet.
  final bool? representative;

  /// Consumption over this ride. Null under 200 m, where it means nothing.
  double? get whPerKm {
    if (distanceKm < 0.2) return null;
    final net = energyOutWh - energyInWh;
    return net <= 0 ? null : net / distanceKm;
  }

  double get averageSpeedKmh {
    final hours = movingDuration.inMilliseconds / 3600000.0;
    return hours <= 0 ? 0 : distanceKm / hours;
  }

  /// Time the bike stood still without the ride being paused.
  Duration get stoppedDuration {
    final idle = totalDuration - movingDuration;
    return idle.isNegative ? Duration.zero : idle;
  }

  factory TripSummaryView.fromOutcome(TripOutcome outcome, {int? tripId}) {
    final s = outcome.summary;
    return TripSummaryView(
      tripId: tripId,
      distanceKm: s.distanceKm,
      movingDuration: s.movingDuration,
      totalDuration: s.totalDuration,
      maxSpeedKmh: s.maxSpeedKmh,
      climbM: s.climbM,
      descentM: s.descentM,
      energyOutWh: s.energyOutWh,
      energyInWh: s.energyInWh,
      whPerKmBefore: outcome.conclusions.whPerKmBefore,
      whPerKmAfter: outcome.conclusions.whPerKmAfter,
      // A ride that has only just ended has not been asked about yet.
      representative: null,
    );
  }

  factory TripSummaryView.fromStored(Trip trip) => TripSummaryView(
    tripId: trip.id,
    distanceKm: trip.distanceKm,
    movingDuration: Duration(seconds: trip.movingSeconds),
    totalDuration: Duration(seconds: trip.totalSeconds),
    maxSpeedKmh: trip.maxSpeedKmh,
    climbM: trip.climbM,
    descentM: trip.descentM,
    energyOutWh: trip.energyOutWh,
    energyInWh: trip.energyInWh,
    whPerKmBefore: trip.whPerKmBefore,
    whPerKmAfter: trip.whPerKmAfter,
    representative: trip.representative,
  );
}
```

- [ ] **Step 4: Move the sheet out and point it at the view**

Sacar `_TripSummarySheet` de `trip_screen.dart` a un archivo propio, `lib/src/ui/widgets/trip_summary_sheet.dart`, público, con una función que la abre:

```dart
/// Opens the end-of-ride summary.
///
/// A function rather than a call site per screen: the sheet is opened from the
/// stop button, and also on opening the app for a ride that ended in a pocket,
/// and those two had no business drifting apart.
Future<void> showTripSummarySheet({
  required BuildContext context,
  required TripSummaryView view,
  required BmsService service,
  required AppL10n t,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: AppTheme.surface,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => TripSummarySheet(view: view, service: service, t: t),
);
```

La hoja toma un `TripSummaryView` en lugar de un `TripOutcome`: reemplazar cada `summary.x` por `view.x`. `trip_screen.dart` la usa desde ahí, y su `_stop()` pasa `TripSummaryView.fromOutcome(outcome, tripId: service.lastStoredTripId)`.

El id del viaje recién cerrado hay que exponerlo, porque `stopTrip` pone `_currentTripId` en null antes de devolver. En `BmsService`:

```dart
  /// The row of the ride that just ended, for a screen that has to ask
  /// something about it. `_currentTripId` is cleared by then.
  int? lastStoredTripId;
```

Fijado en `stopTrip` en la línea donde hoy se limpia:

```dart
    final id = _currentTripId;
    lastStoredTripId = id;
    _currentTripId = null;
```

Nota: los campos que la hoja muestra y que `TripSummaryView` no tiene (SOC de inicio y fin, voltajes, temperatura, delta) están en la sección "el pack durante el viaje". Agregarlos al modelo con el mismo patrón en este mismo paso, tomándolos de `summary` y de `trip` respectivamente. No dejar la sección a medias ni borrarla.

Se mueve acá y no en la Tarea 12 a propósito: la hoja ya se está reescribiendo en esta tarea, y moverla después obligaría a la Tarea 11 a editar un archivo que la 12 cambia de lugar.

- [ ] **Step 5: Run tests and commit**

Run: `flutter analyze && flutter test`
Expected: PASS

```bash
git add lib/src/ui/widgets/trip_summary_view.dart lib/src/ui/trip_screen.dart lib/src/bms_service.dart test/trip_summary_view_test.dart
git commit -m "Let the ride summary be read from a stored row, not only from a stop"
```

---

## Task 10: La pregunta

Un widget, tres lugares. Dice qué midió, cuánto se aparta, y qué le hace al número. Al responder confirma la consecuencia y no la acción.

**Files:**
- Create: `lib/src/ui/widgets/representative_question.dart`
- Modify: `lib/l10n/app_es.arb`, `lib/l10n/app_en.arb`
- Test: `test/representative_question_test.dart` (crear)

**Interfaces:**
- Consumes: `RangeEstimator.projectedShiftFraction` y `askThresholdFraction` (Tarea 5), `BmsService.setTripRepresentative` (Tarea 8), `TripSummaryView` (Tarea 9).
- Produces: `RepresentativeQuestion`, un `StatelessWidget` con `{required TripSummaryView view, required BmsService service, required AppL10n t}`. Se dibuja como `SizedBox.shrink()` cuando no hay nada que preguntar.

- [ ] **Step 1: Add the strings**

`lib/l10n/app_es.arb`:

```json
  "representativeAsk": "¿Este viaje te representa?",
  "@representativeAsk": {},
  "representativeAskBodyUp": "Salió en {whPerKm} Wh/km, un {percent}% por encima de lo tuyo. Ya lo conté: tu autonomía pasó de {before} a {after} km. Si fue una excepción, vuelve a {before}.",
  "@representativeAskBodyUp": { "placeholders": { "whPerKm": {}, "percent": {}, "before": {}, "after": {} } },
  "representativeAskBodyDown": "Salió en {whPerKm} Wh/km, un {percent}% por debajo de lo tuyo. Ya lo conté: tu autonomía pasó de {before} a {after} km. Si fue una excepción, vuelve a {before}.",
  "@representativeAskBodyDown": { "placeholders": { "whPerKm": {}, "percent": {}, "before": {}, "after": {} } },
  "representativeYes": "Es normal",
  "@representativeYes": {},
  "representativeNo": "Fue una excepción",
  "@representativeNo": {},
  "representativeDone": "Listo. Tu autonomía queda en {km} km.",
  "@representativeDone": { "placeholders": { "km": {} } },
  "representativeMarkedException": "Marcado como excepción. No cuenta para tu autonomía.",
  "@representativeMarkedException": {},
  "representativeChange": "Cambiar",
  "@representativeChange": {},
```

`lib/l10n/app_en.arb`: las mismas claves, traducidas.

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing test**

Crear `test/representative_question_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ui/widgets/representative_question.dart';

void main() {
  group('whether to ask about a ride', () {
    test('asks when the ride moves the figure past the threshold', () {
      expect(shouldAskAbout(shiftFraction: 0.08, answered: null), isTrue);
    });

    test('stays quiet under the threshold', () {
      // An ordinary fast day. Making a storm out of it is exactly what the
      // rider asked this not to do.
      expect(shouldAskAbout(shiftFraction: 0.03, answered: null), isFalse);
    });

    test('stays quiet once it has been answered', () {
      expect(shouldAskAbout(shiftFraction: 0.30, answered: true), isFalse);
      expect(shouldAskAbout(shiftFraction: 0.30, answered: false), isFalse);
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/representative_question_test.dart`
Expected: FAIL, el archivo no existe.

- [ ] **Step 4: Write minimal implementation**

Crear `lib/src/ui/widgets/representative_question.dart`. La decisión sale a función libre para poder probarla sin construir un árbol de widgets:

```dart
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../bms_service.dart';
import '../../metrics/range_estimator.dart';
import '../theme.dart';
import 'common.dart';
import 'trip_summary_view.dart';

/// Whether this ride is worth a question.
///
/// Free function so the rule can be tested without building a widget tree,
/// and so the three places that show the question cannot disagree about when
/// it appears.
bool shouldAskAbout({required double shiftFraction, required bool? answered}) =>
    answered == null &&
    shiftFraction > RangeEstimator.askThresholdFraction;

/// Asks whether one ride represents how this bike normally gets ridden.
///
/// The estimator has no notion of context: one deliberately gentle ride to
/// nurse a low charge moves the learned figure a third of the way towards a
/// number that is not how anybody rides. Detecting that automatically and
/// quietly adjusting would change the range with no explanation, which is the
/// thing the rider disliked in the first place. So it asks, once, at the only
/// moment the context is still in somebody's head, and only when the answer
/// would actually change the number.
class RepresentativeQuestion extends StatelessWidget {
  const RepresentativeQuestion({
    required this.view,
    required this.service,
    required this.t,
    super.key,
  });

  final TripSummaryView view;
  final BmsService service;
  final AppL10n t;

  @override
  Widget build(BuildContext context) {
    final tripId = view.tripId;
    final rideWhPerKm = view.whPerKm;
    final learned = view.whPerKmBefore;
    if (tripId == null || rideWhPerKm == null || learned == null || learned <= 0) {
      return const SizedBox.shrink();
    }

    // Already answered: a line saying so, and a way to change it. Not the
    // question again.
    if (view.representative != null) {
      return _Answered(
        representative: view.representative!,
        onChange: () => service.setTripRepresentative(tripId, null),
        t: t,
      );
    }

    final shift = service.rangeEstimator.projectedShiftFraction(
      wh: view.energyOutWh - view.energyInWh,
      km: view.distanceKm,
    );
    if (!shouldAskAbout(shiftFraction: shift, answered: null)) {
      return const SizedBox.shrink();
    }

    final after = view.whPerKmAfter ?? learned;
    // Kilometres rather than Wh/km, because kilometres are what the rider
    // plans around. The consequence is the point of the sentence.
    final beforeKm = _fullPackKm(learned);
    final afterKm = _fullPackKm(after);
    final percent = ((rideWhPerKm - learned).abs() / learned * 100).round();
    final higher = rideWhPerKm > learned;

    return Section(
      title: t.representativeAsk,
      accent: AppTheme.watch,
      children: [
        Text(
          higher
              ? t.representativeAskBodyUp(
                  rideWhPerKm.toStringAsFixed(0),
                  '$percent',
                  beforeKm.toStringAsFixed(0),
                  afterKm.toStringAsFixed(0),
                )
              : t.representativeAskBodyDown(
                  rideWhPerKm.toStringAsFixed(0),
                  '$percent',
                  beforeKm.toStringAsFixed(0),
                  afterKm.toStringAsFixed(0),
                ),
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.45,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _answer(context, tripId, true),
                child: Text(t.representativeYes),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _answer(context, tripId, false),
                child: Text(t.representativeNo),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  /// Full-pack kilometres at a given consumption, so the two halves of the
  /// sentence are comparable. Falls back to the remaining range when no
  /// capacity has been measured, which is the honest thing the rest of the app
  /// already does.
  double _fullPackKm(double whPerKm) {
    final outlook = service.rangeOutlook;
    final reference = outlook.fullKm ?? outlook.nowKm ?? 0;
    final learned = service.rangeEstimator.whPerKm;
    if (reference <= 0 || whPerKm <= 0 || learned <= 0) return 0;
    // Range scales inversely with consumption, so one reference point is
    // enough and no second capacity lookup is needed.
    return reference * learned / whPerKm;
  }

  Future<void> _answer(BuildContext context, int tripId, bool normal) async {
    final messenger = ScaffoldMessenger.of(context);
    await service.setTripRepresentative(tripId, normal);
    // The consequence, not the action. "Saved" tells the rider nothing they
    // could not see, and the number is the only reason they answered.
    final km = service.rangeOutlook.fullKm ?? service.rangeOutlook.nowKm;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          normal && km != null
              ? t.representativeDone(km.toStringAsFixed(0))
              : t.representativeMarkedException,
        ),
      ),
    );
  }
}

class _Answered extends StatelessWidget {
  const _Answered({
    required this.representative,
    required this.onChange,
    required this.t,
  });

  final bool representative;
  final VoidCallback onChange;
  final AppL10n t;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            representative
                ? t.representativeYes
                : t.representativeMarkedException,
            style: const TextStyle(fontSize: 12, color: AppTheme.textFaint),
          ),
        ),
        TextButton(onPressed: onChange, child: Text(t.representativeChange)),
      ],
    ),
  );
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/representative_question_test.dart && flutter analyze`
Expected: PASS y sin avisos.

- [ ] **Step 6: Commit**

```bash
git add lib/src/ui/widgets/representative_question.dart lib/l10n/ test/representative_question_test.dart
git commit -m "Ask once whether a ride represents the rider, and answer in kilometres"
```

---

## Task 11: La pregunta aparece en los dos lugares donde se ve un viaje

**Files:**
- Modify: `lib/src/ui/trip_screen.dart` (la hoja)
- Modify: `lib/src/ui/trip_detail_screen.dart`

**Interfaces:**
- Consumes: `RepresentativeQuestion` (Tarea 10), `TripSummaryView` (Tarea 9).

- [ ] **Step 1: Add it to the sheet**

En `_TripSummarySheet`, como primer hijo del `ListView` después del título, para que sea lo primero que se lee y no algo al pie:

```dart
          RepresentativeQuestion(view: view, service: service, t: t),
```

`_TripSummarySheet` necesita el `BmsService`; pasarlo desde `_stop()`.

- [ ] **Step 2: Add it to the detail screen**

En `lib/src/ui/trip_detail_screen.dart`, construir la vista desde la fila y mostrar la pregunta bajo la cabecera:

```dart
    final view = TripSummaryView.fromStored(trip);
    // ...
    RepresentativeQuestion(view: view, service: service, t: t),
```

`TripDetailScreen` hoy recibe `trip` y `repository`; agregar `service` a su constructor y pasarlo desde `history_tab.dart`, que ya lo tiene a mano.

- [ ] **Step 3: Verify by hand**

Run: `flutter run`
Comprobar: abrir un viaje del historial que haya movido la cifra más del 5%; la pregunta aparece; responder "fue una excepción"; el aviso dice la consecuencia; volver a entrar y ahora dice que está marcado, con "Cambiar".

- [ ] **Step 4: Run tests and commit**

Run: `flutter analyze && flutter test`

```bash
git add lib/src/ui/
git commit -m "Show the question wherever a ride is shown"
```

---

## Task 12: El resumen del viaje del bolsillo aparece al abrir la app

**Files:**
- Modify: `lib/src/data/repository.dart`
- Modify: `lib/src/ui/connect_screen.dart`
- Modify: `lib/src/bms_service.dart` (marcar visto al cerrar a mano)
- Test: `test/pending_summary_test.dart` (crear)

**Interfaces:**
- Produces: `BmsRepository.pendingSummaryTrip(String deviceId)` devuelve `Future<Trip?>`, el viaje terminado más reciente de ese pack cuyo resumen no se vio, excluyendo los de demo.

- [ ] **Step 1: Write the failing test**

Crear `test/pending_summary_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';

void main() {
  group('a ride whose summary nobody saw', () {
    test('is offered the next time the app opens', () async {
      // The pocket case, which is the normal case. The summary used to be
      // built by the stop button and by nothing else, so a ride that closed
      // itself was stored complete and shown to nobody.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = BmsRepository(database: db);
      final id = await _storeRide(repo, 'pack-1', km: 20, whPerKm: 17.5);

      final pending = await repo.pendingSummaryTrip('pack-1');
      expect(pending?.id, id);
    });

    test('is not offered twice', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = BmsRepository(database: db);
      final id = await _storeRide(repo, 'pack-1', km: 20, whPerKm: 17.5);

      await repo.markTripSummarySeen(id);
      expect(await repo.pendingSummaryTrip('pack-1'), isNull);
    });

    test('a demo ride is never offered', () async {
      // A made-up ride announcing itself would be the app talking about
      // nothing, which is the one thing it is built not to do.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = BmsRepository(database: db);
      await _storeRide(repo, 'pack-1', km: 20, whPerKm: 17.5, demo: true);
      expect(await repo.pendingSummaryTrip('pack-1'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/pending_summary_test.dart`
Expected: FAIL con "The method 'pendingSummaryTrip' isn't defined".

- [ ] **Step 3: Write minimal implementation**

En `lib/src/data/repository.dart`:

```dart
  /// The most recent finished ride on this pack whose summary was never shown.
  ///
  /// Rides end in a pocket, and the summary used to be drawn by the stop
  /// button and by nothing else. Only the latest one is offered: a week of
  /// unseen rides queued up on opening the app would be a punishment for
  /// having gone riding.
  Future<Trip?> pendingSummaryTrip(String deviceId) async {
    final recent = await db.recentTrips(deviceId, limit: 20);
    for (final t in recent) {
      if (t.demo || t.summarySeen) continue;
      if (t.distanceKm <= 0) continue;
      return t;
    }
    return null;
  }
```

En `lib/src/bms_service.dart`, en `stopTrip`, marcar visto solamente cuando el cierre fue a mano no es posible desde el servicio, que no sabe quién lo llamó. Se marca desde la UI: quien muestra la hoja llama a `markTripSummarySeen`. Añadir en `BmsService`:

```dart
  /// Records that the rider has seen this ride's summary.
  Future<void> markTripSummarySeen(int tripId) =>
      repository?.markTripSummarySeen(tripId) ?? Future<void>.value();
```

- [ ] **Step 4: Show it on opening**

En `lib/src/ui/connect_screen.dart`, después de que el pack activo esté resuelto y la primera vez por sesión:

```dart
  /// Offers the summary of a ride that ended with nobody watching.
  ///
  /// Once per session, and only for the latest one.
  Future<void> _offerPendingSummary() async {
    if (_offeredPendingSummary) return;
    _offeredPendingSummary = true;
    final device = widget.service.activeDeviceId;
    final repo = widget.service.repository;
    if (device == null || repo == null) return;

    final trip = await repo.pendingSummaryTrip(device);
    if (trip == null || !mounted) return;

    final t = AppL10n.of(context);
    await widget.service.markTripSummarySeen(trip.id);
    if (!mounted) return;
    await showTripSummarySheet(
      context: context,
      view: TripSummaryView.fromStored(trip),
      service: widget.service,
      t: t,
    );
  }
```

`showTripSummarySheet` ya existe desde la Tarea 9; acá solo se llama.

- [ ] **Step 5: Verify by hand**

Comprobar en el teléfono: cerrar un viaje sin la app abierta, abrirla, y ver el resumen una sola vez.

- [ ] **Step 6: Run tests and commit**

Run: `flutter analyze && flutter test`

```bash
git add lib/src/data/repository.dart lib/src/bms_service.dart lib/src/ui/ test/pending_summary_test.dart
git commit -m "Show the summary of a ride that ended with nobody watching"
```

---

## Task 13: Verificación en el teléfono

Ningún test responde esto y es la única tarea que puede invalidar la Tarea 1.

**Files:** ninguno, salvo lo que la verificación obligue a cambiar.

- [ ] **Step 1: Run the checklist**

Conectar el pack, apagar la pantalla, teléfono al bolsillo, rodar, volver.

1. El viaje arrancó solo, sin tocar nada.
2. La notificación dice "Grabando viaje" en español, con distancia que avanza.
3. Al llegar y quedarse quieto 3 minutos, se cerró solo.
4. La notificación dice que el viaje se guardó, con km y Wh/km.
5. Al abrir la app aparece el resumen del viaje, una sola vez.
6. Si movió el número más del 5%, aparece la pregunta.
7. Responder "fue una excepción" devuelve la autonomía al valor anterior.

- [ ] **Step 2: If step 1 of the checklist fails**

Significa que el servicio de tipo location no alcanza en ese teléfono. Pedir el permiso de segundo plano, que ya está en el manifest. En `lib/src/gps/location_source.dart`, en `GeolocatorSource.start`, después de la comprobación de `denied`:

```dart
    // Some devices do not sustain location for a location-typed foreground
    // service alone, and the auto-start detector asks for a fix with the
    // screen off, before any trip exists. Where that is the case this is the
    // permission Android wants, and it can only be granted from settings, so
    // it is asked for once and never insisted on.
    if (needsBackground && permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }
```

Con `needsBackground` como parámetro del constructor, puesto en true solo por el camino de armado. Si aun así falla, activar el `ownForegroundService: true` que ya existe en esa clase para el armado, y aceptar la segunda notificación mientras dure.

- [ ] **Step 3: Record what happened**

Anotar el resultado al pie de la spec, en una sección "Verificado en hardware", con el modelo de teléfono y la versión de Android. Es lo que el repo ya hace con los hechos medidos, y evita que la próxima sesión vuelva a suponer.

```bash
git add docs/superpowers/specs/2026-09-04-viajes-representativos-design.md
git commit -m "Record what the phone actually did with the pocket ride"
```

---

## Autorrevisión

**Cobertura de la spec:**

| Requisito de la spec | Tarea |
|---|---|
| A1 GPS con pantalla apagada | 1, y 13 lo verifica |
| A2 oyente a nivel de app | 3 |
| A3 resumen de cierre automático guardado | 9 y 12 |
| A4 texto de notificación fuera de la pantalla | ya estaba en main; el resto se borra en 3 |
| A5 decir cuando no se pudo grabar | 2 y 3 |
| B umbral 5% atado a la consecuencia | 5 |
| B marca de tres estados | 6 |
| B filtro en tripsForLearning | 7 |
| B reversible con reconstrucción | 8 |
| B aparece en la hoja | 10 y 11 |
| B aparece en el detalle del viaje | 11 |
| B aviso al abrir la app | 12 |
| B letra exacta y confirmación en km | 10 |
| A4.4 notificación de viaje guardado | 4 |
| Pruebas unitarias de la spec 5.1 | 1, 2, 5, 6, 7, 8, 9, 10, 12 |
| Pruebas en teléfono de la spec 5.2 | 13 |

Sin huecos.

**Placeholders:** ninguno. No hay TBD, ni "manejar los casos borde", ni "similar a la tarea N", ni pasos de código sin código. Cada test tiene sus aserciones escritas y cada implementación su cuerpo.

**Consistencia de nombres:** `projectedShiftFraction` y `askThresholdFraction` (Tarea 5) se usan con esos nombres en 10. `setTripRepresentative` existe en la base (6), el repositorio (7) y el servicio (8), con la misma firma `(int tripId, bool? value)`. `markTripSummarySeen` igual, en base (7), repositorio (7) y servicio (12). `TripSummaryView` con sus dos constructores (9) se consume en 10, 11 y 12.
