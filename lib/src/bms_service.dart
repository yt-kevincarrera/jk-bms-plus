import 'dart:async';

import 'ble/ble_transport.dart';
import 'ble/bms_link.dart';
import 'ble/simulator/simulated_pack.dart';
import 'ble/switchable_link.dart';
import 'data/database.dart';
import 'data/repository.dart';
import 'gps/location_source.dart';
import 'gps/simulated_location_source.dart';
import 'platform/live_notification.dart';
import 'model/bms_snapshot.dart';
import 'model/jk_device_info.dart';
import 'model/jk_settings.dart';
import 'protocol/frame_assembler.dart';
import 'protocol/jk_constants.dart';
import 'protocol/jk_frame.dart';
import 'protocol/jk_parser.dart';
import 'package:flutter/services.dart';

import 'metrics/capacity_cycle_detector.dart';
import 'metrics/capacity_test_runner.dart';
import 'metrics/charge_session.dart';
import 'metrics/range_estimator.dart';
import 'metrics/ride_alerts.dart';
import 'metrics/trip_recorder.dart';
import 'metrics/snapshot_history.dart';
import 'protocol/protocol_variant.dart';

/// The single source of BMS data for the whole app.
///
/// One connection, one assembler, one parser, one snapshot stream. Every tab is
/// a view of [snapshots]; no screen gets its own connection or its own decoding
/// logic. That is what makes it safe to split, merge or add tabs later without
/// touching anything below this line.
class BmsService {
  BmsService({BmsLink? transport, JkParser parser = const JkParser()})
      : _transport = transport ?? SwitchableLink(),
        _parser = parser {
    _assembler.onRejected = (_) => _statsController.add(_assembler.stats);
    _bytesSub = _transport.bytes.listen(_onBytes);
    _stateSub = _transport.state.listen((s) => lastLinkState = s);
  }

  final BmsLink _transport;
  final JkParser _parser;
  final FrameAssembler _assembler = FrameAssembler();

  /// Full-resolution ring buffer every screen reads from.
  final SnapshotHistory history = SnapshotHistory();

  /// Everything that outlives the session. Optional so tests and the demo can
  /// run without touching disk.
  BmsRepository? repository;

  /// Learns the bike's real consumption and turns it into a range estimate.
  ///
  /// Rebuilt from the connected pack's stored trips by [relearnRangeFromTrips],
  /// on every connection, and
  /// refined in half-kilometre segments while a ride is being recorded. With
  /// nothing stored it quotes its starting default and says so rather than
  /// dressing a guess up as a measurement.
  RangeEstimator rangeEstimator = RangeEstimator();

  final SegmentAccumulator _segments = SegmentAccumulator();

  /// How many capacity tests have been completed. Advice uses it to stop
  /// nagging once the measurement has actually been made.
  int capacityTestCount = 0;

  /// The pack currently connected, as stored.
  ///
  /// Everything the app records or reads back is scoped to this. Null means
  /// nothing is connected, and in that state the app records nothing rather
  /// than filing readings under no pack at all.
  Device? activeDevice;

  String? get activeDeviceId => activeDevice?.id;

  /// What *this* pack was sold as, in amp-hours, or null when nobody has said.
  ///
  /// Per pack, not global, and with no fallback. There used to be one, and it
  /// meant an unstated capacity silently became 45 Ah -- every health figure
  /// for a 35 Ah pack then measured against a number this app made up. Null
  /// travels all the way to the screen, where it reads as unknown.
  double? get catalogueCapacityAh => activeDevice?.catalogueCapacityAh;

  /// Volts per cell at which the pack cuts off. Taken from the BMS's own
  /// undervoltage setting once the settings frame arrives, so the usable-energy
  /// figure follows how this pack is actually configured.
  double get cutoffVoltagePerCell {
    final configured = _lastSettings?.cellUvp;
    if (configured != null && configured > 1.5 && configured < 3.6) {
      return configured;
    }
    return 3.0;
  }

  /// Fires when the link is up but nothing decodable has arrived for a while.
  ///
  /// Worth calling out explicitly: reading a JK BMS needs no password — the
  /// reference implementation authenticates nowhere, and the device hands out
  /// its own passcode in the device info frame. So silence here means something
  /// else, and the message says what.
  Timer? _silenceTimer;
  static const Duration _silenceTimeout = Duration(seconds: 12);

  final _snapshotController = StreamController<BmsSnapshot>.broadcast();
  final _deviceInfoController = StreamController<JkDeviceInfo>.broadcast();
  final _settingsController = StreamController<JkSettings>.broadcast();
  final _statsController = StreamController<FrameStats>.broadcast();
  final _problemController = StreamController<String>.broadcast();

  late final StreamSubscription<List<int>> _bytesSub;
  late final StreamSubscription<BleLinkState> _stateSub;

  /// Live pack readings, roughly 1 Hz.
  Stream<BmsSnapshot> get snapshots => _snapshotController.stream;

  /// Device identity, normally once per connection.
  Stream<JkDeviceInfo> get deviceInfo => _deviceInfoController.stream;

  /// BMS configuration, read-only.
  Stream<JkSettings> get settings => _settingsController.stream;

  /// Link quality counters, pushed whenever they change.
  Stream<FrameStats> get frameStats => _statsController.stream;

  /// Human-readable trouble: unknown variant, undecodable frame, and so on.
  Stream<String> get problems => _problemController.stream;

  /// Last link state seen, so a screen built after the transition still shows
  /// the right thing instead of the value it was constructed with.
  BleLinkState lastLinkState = BleLinkState.idle;

  Stream<BleLinkState> get linkState => _transport.state;
  Stream<BleLinkError> get linkErrors => _transport.errors;

  BmsSnapshot? get lastSnapshot => _lastSnapshot;
  JkDeviceInfo? get lastDeviceInfo => _lastDeviceInfo;
  JkSettings? get lastSettings => _lastSettings;
  FrameStats get stats => _assembler.stats;
  int? get negotiatedMtu => _transport.negotiatedMtu;

  BmsSnapshot? _lastSnapshot;
  JkDeviceInfo? _lastDeviceInfo;
  JkSettings? _lastSettings;

  /// Which framing we are decoding with. Null until the device info frame
  /// arrives; cell info frames received before that are held back rather than
  /// decoded with a guessed variant.
  JkProtocolVariant? _variant;
  JkProtocolVariant? get variant => _variant;

  /// Set by the user in the System tab when auto-detection was not confident,
  /// or when the decoded values look wrong.
  JkProtocolVariant? _override;

  void overrideVariant(JkProtocolVariant? variant) {
    _override = variant;
    _variant = variant ?? _lastDeviceInfo?.variant;
  }

  Stream<List<DiscoveredBms>> scan() => _transport.scan();

  // --- Demo mode ---
  //
  // Demo mode swaps what feeds the bottom of the pipeline, nothing else. The
  // simulator emits real 300-byte frames in 20-byte chunks, so the assembler,
  // the checksum, variant detection and the parser all run exactly as they will
  // against the hardware. What you see on a screen in demo mode is produced the
  // same way a real reading is.

  SwitchableLink? get _switchable {
    final t = _transport;
    return t is SwitchableLink ? t : null;
  }

  bool get isDemo => _switchable?.isSimulated ?? false;

  DemoScenario? get demoScenario => _switchable?.simulator?.scenario;

  set demoScenario(DemoScenario? value) {
    if (value != null) _switchable?.simulator?.scenario = value;
  }

  /// Starts the simulated pack. Drops any real connection first.
  Future<void> enterDemoMode({
    DemoScenario scenario = DemoScenario.riding,
  }) async {
    final link = _switchable;
    if (link == null) return;
    _resetDecoding();
    await link.useSimulator(scenario: scenario);
    // The simulated pack is a pack like any other as far as storage goes. It
    // gets its own row, so demo rides learn from demo rides and never touch
    // what the app believes about a real battery.
    await _activate(id: demoDeviceId, name: 'Pack demo', demo: true);
    _armSilenceWatchdog();
    await link.connect(demoDeviceId);
  }

  /// The id the simulated pack is stored under.
  static const String demoDeviceId = 'demo';

  /// Records which pack is connected and points storage at it.
  Future<void> _activate({
    required String id,
    required String name,
    required bool demo,
  }) async {
    final repo = repository;
    if (repo == null) return;
    activeDevice = await repo.rememberDevice(id: id, name: name, demo: demo);
    repo.activeDeviceId = id;
    repo.activeIsDemo = demo;
    _deviceController.add(activeDevice);

    // Everything derived from history has to be rebuilt for *this* pack. None
    // of it can happen at startup any more, because until a pack is connected
    // there is no history to speak of -- only several histories, and no way to
    // know which one applies.
    await relearnRangeFromTrips();
    await resumeCapacityTest();
    await scanForCapacityCycles();
  }

  /// Re-reads the stored row, after a rename or a catalogue change.
  Future<void> refreshActiveDevice() async {
    final id = activeDeviceId;
    final repo = repository;
    if (id == null || repo == null) return;
    activeDevice = await repo.device(id);
    _deviceController.add(activeDevice);
  }

  final StreamController<Device?> _deviceController =
      StreamController<Device?>.broadcast();

  /// Fires whenever the connected pack changes, or its stored details do.
  Stream<Device?> get deviceStream => _deviceController.stream;

  /// Returns to the radio.
  Future<void> exitDemoMode() async {
    final link = _switchable;
    if (link == null) return;
    _resetDecoding();
    await link.useRealBms();
    activeDevice = null;
    repository?.activeDeviceId = null;
    _deviceController.add(null);
  }

  /// Feeds the range estimator during a ride, so the number improves as you go
  /// rather than only when you press stop.
  void _learnFromSnapshot(BmsSnapshot snapshot) {
    if (!trip.isRecording) return;

    final segment = _segments.add(
      at: snapshot.timestamp,
      power: snapshot.power,
      odometerKm: trip.distanceKm,
    );
    if (segment != null) {
      rangeEstimator.addSegment(wh: segment.wh, km: segment.km);
    }
  }

  /// Clears everything decoded from the previous source, so a stale variant or
  /// a stale snapshot cannot leak across a switch.
  void _resetDecoding() {
    _assembler.reset();
    history.clear();
    _segments.reset();
    rangeEstimator = RangeEstimator();
    _variant = null;
    _override = null;
    _lastSnapshot = null;
    _lastDeviceInfo = null;
    _lastSettings = null;
  }

  Future<void> connect(String deviceId, {String name = ''}) async {
    _assembler.reset();
    await _activate(id: deviceId, name: name, demo: false);
    _armSilenceWatchdog();
    await _transport.connect(deviceId);
  }

  /// Complains if the link comes up but stays quiet.
  void _armSilenceWatchdog() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silenceTimeout, () {
      if (_lastSnapshot != null) return;
      _problemController.add(
        'Connected, but no readings have arrived. Reading a JK BMS needs no '
        'password, so this is not an authentication problem. The usual causes '
        'are another client still holding the channel, or a firmware whose '
        'frames this app does not recognise yet — check the raw frame console.',
      );
    });
  }

  Future<void> disconnect() async {
    _silenceTimer?.cancel();
    await _transport.disconnect();
    _assembler.reset();
  }

  void _onBytes(List<int> chunk) {
    for (final frame in _assembler.addChunk(chunk)) {
      _dispatch(frame);
    }
    _statsController.add(_assembler.stats);
  }

  void _dispatch(JkFrame frame) {
    // Stored before decoding, and regardless of whether decoding succeeds: the
    // frames worth keeping most are the ones this app got wrong.
    repository?.addRawFrame(frame);

    final type = frame.type;
    if (type == null) {
      _problemController.add(
        'Ignored a frame with unsupported record type '
        '0x${frame.rawType.toRadixString(16).padLeft(2, '0')}.',
      );
      return;
    }

    try {
      switch (type) {
        case JkRecordType.deviceInfo:
          _handleDeviceInfo(_parser.parseDeviceInfo(frame));
        case JkRecordType.cellInfo:
          _handleCellInfo(frame);
        case JkRecordType.settings:
          _handleSettings(frame);
        case JkRecordType.logbook:
          // Event log decoding is not needed for read parity and is not
          // implemented. The raw frame is still worth persisting.
          break;
      }
    } on JkParseException catch (e) {
      _problemController.add(e.message);
    }
  }

  void _handleDeviceInfo(JkDeviceInfo info) {
    _lastDeviceInfo = info;
    // The serial and model only arrive once a frame has been parsed, so the
    // stored row catches up here rather than at connect time.
    _recordDeviceDetails(info);
    _variant = _override ?? info.variant;
    _deviceInfoController.add(info);

    if (info.variant == null) {
      _problemController.add(
        'Could not work out which JK protocol variant this BMS speaks. '
        'Pick one manually in the System tab; until '
        'then no readings will be decoded, because decoding with the wrong '
        'variant produces wrong numbers rather than an error.',
      );
    } else if (!info.detection.confident && _override == null) {
      _problemController.add(
        'Assuming ${info.variant!.name}.',
      );
    }
  }

  void _handleCellInfo(JkFrame frame) {
    final variant = _variant;
    if (variant == null) {
      // Refusing to decode is the correct behaviour here. Guessing the variant
      // would produce plausible but wrong voltages, which is worse than a gap.
      _problemController.add(
        'Held back a cell info frame: the protocol variant is not known yet.',
      );
      return;
    }
    final snapshot = _parser.parseCellInfo(frame, variant);
    _silenceTimer?.cancel();
    _lastSnapshot = snapshot;
    history.add(snapshot);
    trip.addSnapshot(snapshot);
    repository?.addSnapshot(snapshot);
    _checkAlerts(snapshot);
    _updateCapacityTest(snapshot);
    _watchCharging(snapshot);
    _learnFromSnapshot(snapshot);
    _snapshotController.add(snapshot);
  }

  void _handleSettings(JkFrame frame) {
    final variant = _variant;
    if (variant == null) return;
    final settings = _parser.parseSettings(frame, variant);
    _lastSettings = settings;
    _settingsController.add(settings);
  }


  // --- Trip recording ---
  //
  // Distance and speed come from the phone, everything else from the pack. The
  // BMS cannot do this half: the JK protocol carries GPS lock bits but no
  // position data at all.

  final TripRecorder trip = TripRecorder();

  LocationSource? _location;
  StreamSubscription<GeoFix>? _fixSub;
  LocationProblem? lastLocationProblem;

  /// Starts recording a ride. Returns a problem when location is unavailable,
  /// in which case nothing is recorded rather than a trip of zero kilometres
  /// being logged as if it were real.
  Future<LocationProblem?> startTrip() async {
    final problem = await _ensureLocation();
    lastLocationProblem = problem;
    if (problem != null) return problem;
    _segments.reset();
    trip.start();
    // The row is opened now rather than at the end, so readings taken during
    // the ride can be attributed to it and so a ride that ends badly still
    // leaves something behind.
    _currentTripId =
        await repository?.beginTrip(DateTime.now().toUtc(), demo: isDemo);
    await _startLiveNotification();
    return null;
  }

  void pauseTrip() => trip.pause();

  void resumeTrip() => trip.resume();

  /// Ends the trip, stores it, and returns the summary.
  ///
  /// The range estimator is not fed here: it has already been learning in
  /// half-kilometre segments throughout the ride, and adding the whole trip
  /// again at the end would count every kilometre twice.
  Future<TripOutcome?> stopTrip() async {
    // Captured before the trip is stored, because storing it is what changes
    // the estimate — and the whole point of the outcome is the before and after.
    final whPerKmBefore = rangeEstimator.whPerKm;
    // Asked of the store, not the in-memory estimator: entering demo mode
    // resets the estimator, and "first trip ever" should not depend on that.
    final device = activeDeviceId;
    final priorTrips = device == null
        ? const <Trip>[]
        : await repository?.tripsForLearning(device) ?? const <Trip>[];
    final hadLearnedBefore = priorTrips.isNotEmpty;

    final points = trip.points;
    final summary = trip.stop();
    _segments.reset();
    await _stopLocation();
    await _stopLiveNotification();

    final id = _currentTripId;
    _currentTripId = null;
    if (summary == null) return null;

    if (id != null) {
      await repository?.finishTrip(id, summary, points);
      // A ride is the most likely thing to have completed a discharge.
      await scanForCapacityCycles();
      // Rebuilding from every stored trip, rather than adding this one on top
      // of what the in-ride segments already taught, keeps one source of truth
      // and avoids counting this ride twice.
      await relearnRangeFromTrips();
    }

    final snapshot = _lastSnapshot;
    final usableWh = snapshot == null
        ? 0.0
        : RangeEstimator.usableWh(
            remainingAh: snapshot.remainingCapacityAh,
            packVoltage: snapshot.packVoltage,
            cellCount: snapshot.cellCount,
            minCellVoltage: snapshot.minCellVoltage,
            averageCellVoltage: snapshot.averageCellVoltage,
            cutoffVoltagePerCell: cutoffVoltagePerCell,
          );

    return TripOutcome(
      summary: summary,
      whPerKmBefore: whPerKmBefore,
      whPerKmAfter: rangeEstimator.whPerKm,
      hadLearnedBefore: hadLearnedBefore,
      learnedKm: rangeEstimator.learnedKm,
      confidence: rangeEstimator.confidence,
      rangeKmNow: rangeEstimator.rangeKm(usableWh),
      averageWhPerKm: summary.whPerKm,
    );
  }

  int? _currentTripId;

  /// Id of the trip being recorded, if any.
  int? get currentTripId => _currentTripId;

  Future<LocationProblem?> _ensureLocation() async {
    await _fixSub?.cancel();
    await _location?.stop();

    // In demo mode the position comes from the simulated pack, so the riding
    // screens can be judged with no window and no satellites.
    final simulator = _switchable?.simulator;
    final source = simulator != null
        ? SimulatedLocationSource(pack: simulator.pack)
        : GeolocatorSource();
    _location = source;

    final problem = await source.start();
    if (problem != null) return problem;

    _fixSub = source.fixes.listen(trip.addFix);
    return null;
  }

  Future<void> _stopLocation() async {
    await _fixSub?.cancel();
    _fixSub = null;
    await _location?.stop();
    _location = null;
  }

  /// Rebuilds the range estimate from every stored trip.
  ///
  /// Called at startup and whenever a trip is deleted. Rebuilding rather than
  /// accumulating is what makes deletion honest: a ride recorded by accident,
  /// or one spent on a trailer, can be removed and stops counting.
  Future<int> relearnRangeFromTrips() async {
    final repo = repository;
    if (repo == null) return 0;

    final device = activeDeviceId;
    if (device == null) return 0;
    final trips = await repo.tripsForLearning(device);
    final rebuilt = RangeEstimator();
    for (final t in trips) {
      rebuilt.addSegment(
        wh: t.energyOutWh - t.energyInWh,
        km: t.distanceKm,
      );
    }
    rangeEstimator = rebuilt;
    return trips.length;
  }

  /// Deletes a stored trip and forgets what it taught.
  Future<void> deleteTrip(int tripId) async {
    await repository?.deleteTrip(tripId);
    await relearnRangeFromTrips();
  }

  // --- The live notification ---
  //
  // What keeps a trip alive once you switch to your music app or lock the
  // screen, and what puts speed, distance and charge where you can see them
  // without coming back here.

  final LiveNotification notifications = LiveNotification();
  Timer? _notificationTimer;

  /// Wording for the notification, set by the UI so the analysis layer does not
  /// have to know what language anyone reads.
  String Function(TripRecorder trip, BmsSnapshot? snapshot)? notificationText;
  String notificationTitle = 'Trip';

  Future<void> _startLiveNotification() async {
    if (!await notifications.requestPermission()) return;

    final started = await notifications.start(
      title: notificationTitle,
      text: notificationText?.call(trip, _lastSnapshot) ?? '',
      usesRealLocation: !isDemo,
    );
    if (!started) {
      _problemController.add(
        'Could not start the background service, so the trip will stop '
        'recording when the app leaves the screen.',
      );
      return;
    }

    _notificationTimer?.cancel();
    // Once a second: often enough to read as live, rare enough that the system
    // does not start rate-limiting the updates.
    _notificationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!trip.isActive) return;
      notifications.update(
        title: notificationTitle,
        text: notificationText?.call(trip, _lastSnapshot) ?? '',
      );
    });
  }

  Future<void> _stopLiveNotification() async {
    _notificationTimer?.cancel();
    _notificationTimer = null;
    await notifications.stop();
  }

  // --- Alerts while riding ---

  final RideAlerts alerts = RideAlerts();
  final _alertController = StreamController<RideAlert>.broadcast();

  /// Fires when something crosses a line worth interrupting a ride for.
  Stream<RideAlert> get rideAlerts => _alertController.stream;

  /// Whether to buzz the phone. Off by default in demo mode, where every
  /// scenario would set something off within seconds.
  bool hapticAlerts = true;

  void _checkAlerts(BmsSnapshot snapshot) {
    final firing = alerts.evaluate(
      snapshot,
      cutoffVoltagePerCell: cutoffVoltagePerCell,
    );
    for (final alert in firing) {
      _alertController.add(alert);
      if (hapticAlerts) {
        // Riding is exactly when nobody is looking at the screen, so the phone
        // has to be felt rather than read.
        if (alert.isCritical) {
          HapticFeedback.heavyImpact();
        } else {
          HapticFeedback.mediumImpact();
        }
      }
    }
  }

  // --- Capacity test ---
  //
  // The one measurement in this app, as opposed to the inferences. It runs for
  // hours, so its progress is written to the database as it goes and picked
  // back up if the app is closed part way through.

  final CapacityTestRunner capacityTest = CapacityTestRunner();
  final _capacityController = StreamController<CapacityTestState>.broadcast();

  Stream<CapacityTestState> get capacityTestState => _capacityController.stream;

  /// Why a run cannot start right now, or null when it can.
  CapacityTestBlock? get capacityTestBlockedBy =>
      capacityTest.blockedBy(_lastSnapshot);

  Future<bool> startCapacityTest() async {
    final snapshot = _lastSnapshot;
    final repo = repository;
    if (snapshot == null || repo == null) return false;
    if (capacityTest.blockedBy(snapshot) != null) return false;

    final id = await repo.beginCapacityTest(
      startedAt: snapshot.timestamp,
      startSoc: snapshot.soc,
      startPackVoltage: snapshot.packVoltage,
      catalogueAh: catalogueCapacityAh,
    );
    capacityTest.begin(
      snapshot: snapshot,
      catalogueAh: catalogueCapacityAh,
      rowId: id,
    );
    _capacityController.add(capacityTest.state);
    return true;
  }

  Future<void> abortCapacityTest() async {
    final id = capacityTest.rowId;
    capacityTest.abort();
    if (id != null) await repository?.deleteCapacityTest(id);
    _capacityController.add(capacityTest.state);
  }

  Future<void> _finishCapacityTest() async {
    final id = capacityTest.rowId;
    if (id != null) {
      await repository?.finishCapacityTest(
        id,
        endedAt: DateTime.now().toUtc(),
        endSoc: capacityTest.endSoc,
        endPackVoltage: capacityTest.endPackVoltage,
        measuredAh: capacityTest.measuredAh,
        measuredWh: capacityTest.measuredWh,
      );
      final device = activeDeviceId;
      capacityTestCount = device == null
          ? 0
          : await repository?.countCompletedCapacityTests(device) ?? 0;
    }
    capacityTest.finish();
    _capacityController.add(capacityTest.state);
  }

  void _updateCapacityTest(BmsSnapshot snapshot) {
    if (!capacityTest.isRunning) return;
    final done = capacityTest.addSnapshot(snapshot);

    // Written on the way past rather than only at the end, so an app that is
    // closed or killed mid-test loses seconds of counting, not hours.
    final id = capacityTest.rowId;
    if (id != null) {
      repository?.updateCapacityProgress(
        id,
        measuredAh: capacityTest.measuredAh,
        measuredWh: capacityTest.measuredWh,
        endSoc: capacityTest.endSoc,
        endPackVoltage: capacityTest.endPackVoltage,
      );
    }

    if (done) _finishCapacityTest();
  }

  // --- Charge sessions ---
  //
  // The top of a charge is the most revealing window a pack offers and the one
  // nobody watches, because it happens overnight. Recorded whenever the app
  // does happen to be connected.

  final ChargeSessionRecorder chargeRecorder = ChargeSessionRecorder();
  final _chargeController = StreamController<ChargeReport>.broadcast();

  /// Fires when a charge finishes with enough behind it to be worth reading.
  Stream<ChargeReport> get chargeReports => _chargeController.stream;

  /// The most recent finished charge, for the screen to show on arrival.
  ChargeReport? lastChargeReport;

  void _watchCharging(BmsSnapshot snapshot) {
    final report = chargeRecorder.addSnapshot(snapshot);
    if (report == null) return;
    lastChargeReport = report;
    _chargeController.add(report);
  }

  /// Applies the user's settings. Called once at startup and whenever they
  /// change, so nothing here has to reach into the settings object itself.
  void applySettings({
    required bool haptics,
    required bool rawFrames,
  }) {
    hapticAlerts = haptics;
    repository?.recordRawFrames = rawFrames;
  }

  /// Picks up a capacity test that was interrupted by the app closing.
  Future<void> resumeCapacityTest() async {
    final repo = repository;
    if (repo == null || capacityTest.isRunning) return;

    final device = activeDeviceId;
    if (device == null) return;

    final unfinished = await repo.unfinishedCapacityTest(device);
    if (unfinished == null) return;

    capacityTest.resume(
      rowId: unfinished.id,
      startedAt: unfinished.startedAt,
      ah: unfinished.measuredAh,
      wh: unfinished.measuredWh,
      startSoc: unfinished.startSoc,
      startPackVoltage: unfinished.startPackVoltage,
      catalogueAh: unfinished.catalogueAh,
    );
    capacityTestCount = await repo.countCompletedCapacityTests(device);
    _capacityController.add(capacityTest.state);
  }

  /// Scans the stored readings for full discharges nobody asked it to record.
  ///
  /// This is what makes the capacity measurement something you get rather than
  /// something you have to remember to start. Every reading is already on disk;
  /// a pass over it finds the cycles that already happened. Run at startup and
  /// after each ride.
  Future<int> scanForCapacityCycles() async {
    final repo = repository;
    final device = activeDeviceId;
    if (repo == null || device == null) return 0;

    final readings = await repo.allSnapshots(device);
    if (readings.length < 20) return 0;

    const detector = CapacityCycleDetector();
    final found = detector.scan(readings);

    var added = 0;
    for (final cycle in found) {
      if (await repo.recordDetectedCycle(device, cycle, catalogueCapacityAh)) {
        added++;
      }
    }
    if (added > 0) {
      capacityTestCount = await repo.countCompletedCapacityTests(device);
      _capacityController.add(capacityTest.state);
    }
    return added;
  }

  /// Whether the catalogue figure came from the rider.
  ///
  /// The app deliberately does *not* adopt the capacity the BMS is configured
  /// with. That number is not a measurement — it is what whoever assembled the
  /// pack typed in, and it is what the coulomb counter scales the charge
  /// percentage against. If it disagrees with what the pack was sold as, that
  /// disagreement is a finding, and adopting the BMS figure would erase it:
  /// a pack sold as 45 Ah with a BMS set to 40 would measure 40 and be called
  /// perfectly healthy. See [configuredCapacityAh].
  bool catalogueSetByUser = false;

  /// What the BMS is configured for, when it has said. Shown next to the
  /// catalogue figure rather than replacing it.
  double? get configuredCapacityAh {
    final n = _lastSettings?.nominalCapacityAh;
    if (n == null || n < 1 || n > 2000) return null;
    return n;
  }

  Future<void> _recordDeviceDetails(JkDeviceInfo info) async {
    final id = activeDeviceId;
    final repo = repository;
    if (id == null || repo == null) return;
    activeDevice = await repo.rememberDevice(
      id: id,
      name: activeDevice?.name ?? '',
      demo: activeDevice?.demo ?? false,
      serialNumber: info.serialNumber,
      model: info.model,
    );
    _deviceController.add(activeDevice);
  }

  Future<void> dispose() async {

    _silenceTimer?.cancel();
    await _stopLiveNotification();
    await _stopLocation();
    await _bytesSub.cancel();
    await _stateSub.cancel();
    await _transport.dispose();
    await _snapshotController.close();
    await _deviceInfoController.close();
    await _settingsController.close();
    await _statsController.close();
    await _problemController.close();
    await _alertController.close();
    await _capacityController.close();
    await _chargeController.close();
  }
}

/// Accumulates measured energy and distance into range-estimator samples.
///
/// The energy half is real today; the distance half comes from the simulator in
/// demo mode and will come from GPS in M3. Keeping the accumulation here means
/// only the distance source has to change when that lands.
class SegmentAccumulator {
  double _wh = 0;
  double _km = 0;
  DateTime? _lastAt;
  double? _lastDistanceKm;

  /// Folds a new reading in, and returns a finished segment when one is long
  /// enough to be worth learning from.
  ({double wh, double km})? add({
    required DateTime at,
    required double power,
    required double odometerKm,
  }) {
    final previousAt = _lastAt;
    final previousKm = _lastDistanceKm;
    _lastAt = at;
    _lastDistanceKm = odometerKm;
    if (previousAt == null || previousKm == null) return null;

    final dt = at.difference(previousAt);
    // A gap means a dropped link, not hours of riding. Skip it rather than
    // integrating a straight line across it.
    if (dt.inSeconds <= 0 || dt.inSeconds > 10) return null;

    final dKm = odometerKm - previousKm;
    if (dKm < 0) return null;

    // Discharge is negative power, and consumption is what we are learning.
    _wh += -power * dt.inMilliseconds / 3600000.0;
    _km += dKm;

    if (_km < 0.5) return null;
    final segment = (wh: _wh, km: _km);
    _wh = 0;
    _km = 0;
    return segment;
  }

  void reset() {
    _wh = 0;
    _km = 0;
    _lastAt = null;
    _lastDistanceKm = null;
  }
}
