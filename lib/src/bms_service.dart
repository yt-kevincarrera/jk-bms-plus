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
import 'platform/pack_widget.dart';
import 'platform/widget_publisher.dart';
import 'model/bms_snapshot.dart';
import 'model/jk_device_info.dart';
import 'model/jk_settings.dart';
import 'protocol/frame_assembler.dart';
import 'protocol/jk_constants.dart';
import 'protocol/jk_frame.dart';
import 'protocol/jk_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'metrics/capacity_cycle_detector.dart';
import 'metrics/capacity_test_runner.dart';
import 'metrics/charge_alerts.dart';
import 'metrics/charge_session.dart';
import 'metrics/range_estimator.dart';
import 'metrics/range_outlook.dart';
import 'metrics/sampling.dart';
import 'metrics/ride_alerts.dart';
import 'metrics/trip_autostart.dart';
import 'metrics/trip_energy_repair.dart';
import 'metrics/trip_recorder.dart';
import 'metrics/snapshot_history.dart';
import 'protocol/protocol_variant.dart';

/// What has a claim on the one foreground service, strongest first.
///
/// There is one service and one notification slot. Before this existed each
/// claimant started and stopped the service on its own, which meant a charge
/// finishing could stop the service a ride was relying on.
enum ServiceClaim {
  /// A ride is open, paused included. Needs the location service type.
  trip,

  /// A package is being fetched.
  ///
  /// Above [charge] and below [trip]: the rider is waiting on this one and its
  /// progress is the more useful thing to show, but not while riding. Without
  /// a claim of its own the download died whenever the screen went dark, which
  /// is the same failure as the readings stopping, with a worse ending: a
  /// truncated package.
  update,

  /// The pack is charging and the rider asked to be told about it overnight.
  charge,

  /// Nothing special is happening; the app is simply connected and reading.
  ///
  /// This is the claim that makes the app behave the same with the screen on
  /// or off. Without it, an app whose screen has gone dark keeps its Bluetooth
  /// subscription for a while and then quietly stops receiving.
  link,
}

/// The single source of BMS data for the whole app.
///
/// One connection, one assembler, one parser, one snapshot stream. Every tab is
/// a view of [snapshots]; no screen gets its own connection or its own decoding
/// logic. That is what makes it safe to split, merge or add tabs later without
/// touching anything below this line.
class BmsService {
  BmsService({
    BmsLink? transport,
    JkParser parser = const JkParser(),
    LocationSource Function()? locationFactory,
  })  : _transport = transport ?? SwitchableLink(),
        _parser = parser,
        _locationFactory = locationFactory {
    _assembler.onRejected = (_) => _statsController.add(_assembler.stats);
    _bytesSub = _transport.bytes.listen(_onBytes);
    _stateSub = _transport.state.listen((s) {
      lastLinkState = s;
      // Readings are what normally drive the service, and a dropped link stops
      // producing them, so the link state has to be able to stand it down
      // itself or the notification outlives the connection it describes.
      unawaited(_updateForegroundService());
    });
  }

  final BmsLink _transport;
  final JkParser _parser;

  /// Where positions come from, when something other than the phone should
  /// supply them.
  ///
  /// Exists so the pause-and-resume path can be tested. It was a real ride
  /// that found the bug there, which is an expensive way to run a test.
  final LocationSource Function()? _locationFactory;
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
    // Before the relearn, so the estimator is rebuilt from mended figures
    // rather than from the ones that made it refuse everything.
    lastTripRepair = await repo.repairTripEnergy(id);
    await relearnRangeFromTrips();
    await resumeCapacityTest();
    await scanForCapacityCycles();
    await refreshMeasuredCapacity();
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

  /// Puts the simulated pack at a given charge. Demo only.
  void setDemoCharge(double fraction) {
    _switchable?.simulator?.pack.setCharge(fraction);
  }

  /// How fast the simulated pack ages. Demo only.
  set demoTimeScale(double scale) {
    final pack = _switchable?.simulator?.pack;
    if (pack != null) pack.timeScale = scale;
  }

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
    chargeAlerts.reset();
    tripAutoStart.reset();
  }

  Future<void> connect(String deviceId, {String name = ''}) async {
    _assembler.reset();
    // Held, not stored. A device only becomes a battery on record once it has
    // sent a frame this app can parse: connecting is not proof of anything,
    // and a tapped pair of headphones used to be filed away as a pack, with a
    // history folder and a place in the saved list.
    _pendingDeviceId = deviceId;
    _pendingDeviceName = name;
    _armSilenceWatchdog();
    await _transport.connect(deviceId);
  }

  String? _pendingDeviceId;
  String _pendingDeviceName = '';

  /// Promotes the connected device to a stored battery, on the first frame
  /// that decodes. Does nothing on later frames.
  Future<void> _activatePending() async {
    final id = _pendingDeviceId;
    if (id == null) return;
    _pendingDeviceId = null;
    await _activate(id: id, name: _pendingDeviceName, demo: false);
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
    _pendingDeviceId = null;
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
          unawaited(_handleCellInfo(frame));
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

  Future<void> _handleCellInfo(JkFrame frame) async {
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
    // A frame that decodes into cell voltages is the proof that this is a BMS,
    // and the first moment it is honest to file the device away as a battery.
    // Everything below writes to that battery's history, so it has to come
    // first, and is awaited so the very first reading is not dropped for want
    // of a battery to file it under.
    await _activatePending();
    _lastSnapshot = snapshot;
    history.add(snapshot);
    trip.addSnapshot(snapshot);
    repository?.addSnapshot(snapshot);
    _checkAlerts(snapshot);
    _checkChargeAlerts(snapshot);
    unawaited(_updateForegroundService());
    unawaited(_updateAutoTrip(snapshot));
    _updateCapacityTest(snapshot);
    _watchCharging(snapshot);
    _learnFromSnapshot(snapshot);
    _snapshotController.add(snapshot);
    unawaited(_publishWidget(snapshot));
  }

  void _handleSettings(JkFrame frame) {
    final variant = _variant;
    if (variant == null) return;
    final settings = _parser.parseSettings(frame, variant);
    _lastSettings = settings;
    // Fills a blank capacity from the pack's own configuration, so a freshly
    // connected battery produces real health figures instead of dashes.
    unawaited(_adoptCapacityFromBms(settings));
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
    await _updateForegroundService();
    return null;
  }

  void pauseTrip() => trip.pause();

  /// Picks the ride back up, and makes sure there is still a location stream
  /// to pick it up with.
  ///
  /// Belt and braces on top of the fix in [_armLocationForAutoTrip]: the
  /// stream can also die without the app being told, when the OS revokes the
  /// permission or stands the provider down. Since the app cannot tell a live
  /// stream from a dead one by looking at its own fields, resume rebuilds it
  /// unconditionally. A second of missing fixes at the kerb costs nothing;
  /// resuming into a ride that silently records no distance cost a real one.
  Future<LocationProblem?> resumeTrip() async {
    if (!trip.isPaused) return null;

    final problem = await _ensureLocation();
    lastLocationProblem = problem;
    if (problem != null) {
      // Said out loud rather than swallowed. A ride that cannot see where it
      // is going must not look like a ride that can.
      _problemController.add(
        'Resumed without location, so no distance will be recorded from '
        'here. Stop the trip and start it again once location is back.',
      );
    }

    // Resumed either way. A ride missing its track is worth less than a whole
    // one; it is worth much more than a ride that quietly stopped.
    trip.resume();
    return problem;
  }

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
    // Not stopped outright: the pack may still be connected, or charging, and
    // either of those has its own claim on the service. Ending a ride is not a
    // reason to stop reading.
    await _updateForegroundService();

    final id = _currentTripId;
    _currentTripId = null;
    if (summary == null) return null;

    if (id != null) {
      // Written with the ride, not after the relearn below: once the estimator
      // has folded this ride in, "before" is no longer available to anybody.
      await repository?.finishTrip(
        id,
        summary,
        points,
        conclusions: TripConclusions(
          whPerKmBefore: hadLearnedBefore ? whPerKmBefore : null,
          whPerKmAfter: rangeEstimator.whPerKm,
          learnedKm: rangeEstimator.learnedKm,
          rangeKmAtEnd: 0,
          confidence: rangeEstimator.confidence,
        ),
      );
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

    final conclusions = TripConclusions(
      whPerKmBefore: hadLearnedBefore ? whPerKmBefore : null,
      whPerKmAfter: rangeEstimator.whPerKm,
      learnedKm: rangeEstimator.learnedKm,
      rangeKmAtEnd: rangeEstimator.rangeKm(usableWh),
      confidence: rangeEstimator.confidence,
    );

    // Rewritten now that the range at the end charge is known: it needs the
    // relearned estimator above, which did not exist when the row was first
    // completed. Cheap, and it keeps the stored conclusions identical to the
    // ones the rider just read.
    if (id != null) {
      await repository?.recordTripConclusions(id, conclusions);
    }

    return TripOutcome(summary: summary, conclusions: conclusions);
  }

  int? _currentTripId;

  /// Id of the trip being recorded, if any.
  int? get currentTripId => _currentTripId;

  Future<LocationProblem?> _ensureLocation() async {
    await _fixSub?.cancel();
    _fixSub = null;
    await _location?.stop();
    _location = null;

    // In demo mode the position comes from the simulated pack, so the riding
    // screens can be judged with no window and no satellites.
    final simulator = _switchable?.simulator;
    final source = _locationFactory?.call() ??
        (simulator != null
            ? SimulatedLocationSource(pack: simulator.pack)
            : GeolocatorSource());
    _location = source;

    final problem = await source.start();
    if (problem != null) {
      // Not left in place. A source that refused to start is not a location
      // stream, and holding it would make the next check think one is running.
      _location = null;
      return problem;
    }

    _fixSub = source.fixes.listen((fix) {
      // While a trip is open the recorder owns the fixes; before one, they
      // exist only so the auto-start detector has a speed to judge.
      if (trip.isRecording) {
        trip.addFix(fix);
      } else {
        _lastAutoSpeedKmh = fix.speedKmh;
      }
    });
    return null;
  }

  Future<void> _stopLocation() async {
    await _fixSub?.cancel();
    _fixSub = null;
    await _location?.stop();
    _location = null;
  }

  /// How far it can go now, and how far a full pack is worth.
  ///
  /// The two were one number with one label, which invited the worst possible
  /// reading: a distance quoted off a half-empty pack, taken as what the bike
  /// does. Only one of them changes when you charge.
  RangeOutlook get rangeOutlook {
    final s = _lastSnapshot;
    if (s == null) return RangeOutlook.unknown;

    final usableNow = RangeEstimator.usableWh(
      remainingAh: s.remainingCapacityAh,
      packVoltage: s.packVoltage,
      cellCount: s.cellCount,
      minCellVoltage: s.minCellVoltage,
      averageCellVoltage: s.averageCellVoltage,
      cutoffVoltagePerCell: cutoffVoltagePerCell,
    );

    // A measured capacity outranks the catalogue figure, which is a claim
    // about a purchase rather than a measurement of this battery.
    final measured = bestMeasuredCapacityAh;
    final capacity = measured ?? catalogueCapacityAh;

    return RangeOutlook.from(
      estimator: rangeEstimator,
      usableWhNow: usableNow,
      fullCapacityAh: capacity,
      // The voltage a full pack sits at, from the BMS's own per-cell limit
      // where it has stated one. Not the voltage right now, which is whatever
      // today's charge happens to be.
      fullPackVoltage: capacity == null ? null : _fullPackVoltage(s),
      // The same derating the remaining figure gets. A weak cell shortens a
      // full pack exactly as much as it shortens a half-empty one.
      usableFraction: RangeEstimator.usableFractionOf(
        minCellVoltage: s.minCellVoltage,
        averageCellVoltage: s.averageCellVoltage,
        cutoffVoltagePerCell: cutoffVoltagePerCell,
      ),
      capacityWasMeasured: measured != null,
    );
  }

  /// Pack voltage at full, for turning a capacity into watt-hours.
  double? _fullPackVoltage(BmsSnapshot s) {
    if (s.cellCount <= 0) return null;
    // Mid-charge nominal rather than the peak: energy is capacity times the
    // *average* voltage over a discharge, and quoting the fully-charged
    // voltage would overstate a full pack by several percent.
    const nominalPerCell = 3.7;
    return s.cellCount * nominalPerCell;
  }

  /// The best capacity this pack has ever actually measured, if any.
  ///
  /// The high-water mark of completed tests, not the latest: a test done on a
  /// cold day, or one with a hole in it, is not what the pack holds. Null until
  /// a full discharge has been recorded, and null is the honest answer, since
  /// the alternative is quoting a full-pack range off a number from an advert.
  double? bestMeasuredCapacityAh;

  /// Re-reads the stored tests to find that high-water mark.
  Future<void> refreshMeasuredCapacity() async {
    final repo = repository;
    final device = activeDeviceId;
    if (repo == null || device == null) {
      bestMeasuredCapacityAh = null;
      return;
    }
    final tests = await repo.capacityTests(device);
    double? best;
    for (final t in tests) {
      if (!t.completed || t.measuredAh <= 0) continue;
      // A measurement with minutes missing from the middle counts low, and
      // counting low here would understate the pack for good.
      if (t.gapSeconds > 120) continue;
      if (best == null || t.measuredAh > best) best = t.measuredAh;
    }
    bestMeasuredCapacityAh = best;
  }

  /// What the last repair pass over old rides found, for the screen to say.
  TripRepairReport lastTripRepair = TripRepairReport.none;

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
  // There is exactly one foreground service, and on Android it is the only
  // thing that stops the system throttling this app off the radio and the GPS
  // the moment the screen goes dark. Three different things want it, so this
  // arbitrates rather than each one starting and stopping it behind the others'
  // backs, which is how a charge finishing used to be able to end a ride.
  //
  // The reason it matters more than it looks: without a service, an app with
  // the screen off keeps its Bluetooth subscription for a while and then
  // quietly stops receiving. Readings do not fail, they thin out and stop,
  // which is the worst way for a logger to break.

  final LiveNotification notifications = LiveNotification();
  Timer? _notificationTimer;

  /// Wording for the notification, set by the UI so the analysis layer does not
  /// have to know what language anyone reads.
  String Function(TripRecorder trip, BmsSnapshot? snapshot)? notificationText;
  String notificationTitle = 'Trip';

  /// Whether to hold the service open merely for being connected.
  ///
  /// On by default, which is a change of position. The app used to keep the
  /// *screen* awake instead, which answered the wrong question: a phone in a
  /// mount with a burning screen, and a phone whose screen had been allowed to
  /// sleep silently losing readings. Holding the service is what actually makes
  /// the app behave the same either way.
  bool linkWatchEnabled = true;

  /// Wording for the connected notification, supplied by the UI.
  String linkWatchTitle = 'Reading the pack';
  String Function(BmsSnapshot?)? linkWatchText;

  /// Wording for a download in progress, supplied by the UI.
  String downloadTitle = 'Downloading update';
  String Function(int percent)? downloadText;

  /// How far the current download has got, or null when none is running.
  int? _download;

  /// Told by the update service that a package is being fetched.
  ///
  /// [percent] null means finished, failed or cancelled; either way the claim
  /// is released. Nothing about the download itself lives here: this object
  /// only decides who holds the foreground service.
  void reportDownloadProgress(int? percent) {
    final was = _download;
    _download = percent;
    // Only when it starts or stops does the owner change; the rest are text
    // updates the timer is already making.
    if ((was == null) != (percent == null)) {
      unawaited(_updateForegroundService());
    }
  }

  /// What currently has a claim on the one service, strongest first.
  ///
  /// Order is the priority order. A ride outranks a charge because its
  /// notification is the one worth reading and because it is the one that
  /// needs the location type; both outrank merely being connected.
  ServiceClaim? get _claim {
    if (trip.isActive) return ServiceClaim.trip;
    if (_download != null) return ServiceClaim.update;
    if (chargeWatchEnabled && chargeAlerts.isCharging) {
      return ServiceClaim.charge;
    }
    // Never in demo mode: there is no radio to keep alive, and a permanent
    // notification about a simulated pack would be a claim about nothing.
    if (linkWatchEnabled &&
        !isDemo &&
        activeDevice != null &&
        lastLinkState == BleLinkState.connected) {
      return ServiceClaim.link;
    }
    return null;
  }

  /// The current claim, for tests.
  ///
  /// The service cannot actually start off a device, so what is worth checking
  /// is the arbitration: which of the four things gets the one slot, and when
  /// it is released.
  @visibleForTesting
  ServiceClaim? get claimForTest => _claim;

  ServiceClaim? _serviceOwner;

  /// True while the app is holding the link open for a charge.
  bool get isWatchingCharge => _serviceOwner == ServiceClaim.charge;

  /// True while it is held open just to keep reading.
  bool get isWatchingLink => _serviceOwner == ServiceClaim.link;

  String _serviceTitle(ServiceClaim claim) => switch (claim) {
        ServiceClaim.trip => notificationTitle,
        ServiceClaim.charge => chargeWatchTitle,
        ServiceClaim.update => downloadTitle,
        ServiceClaim.link => linkWatchTitle,
      };

  String _serviceText(ServiceClaim claim) => switch (claim) {
        ServiceClaim.trip => notificationText?.call(trip, _lastSnapshot) ?? '',
        ServiceClaim.charge => chargeWatchText?.call(_lastSnapshot) ?? '',
        ServiceClaim.update => downloadText?.call(_download ?? 0) ?? '',
        ServiceClaim.link => linkWatchText?.call(_lastSnapshot) ?? '',
      };

  /// Brings the one service into line with whoever has the strongest claim.
  ///
  /// Safe to call as often as readings arrive. Starting is the only expensive
  /// part and it only happens when the owner actually changes.
  Future<void> _updateForegroundService() async {
    final wanted = _claim;

    if (wanted == null) {
      if (_serviceOwner != null) {
        _serviceOwner = null;
        _notificationTimer?.cancel();
        _notificationTimer = null;
        await notifications.stop();
      }
      return;
    }

    if (_serviceOwner == wanted) {
      await notifications.update(
        title: _serviceTitle(wanted),
        text: _serviceText(wanted),
      );
      return;
    }

    // A change of owner can also be a change of service *type*, and Android
    // will not reclassify a running service, so it has to be restarted.
    if (_serviceOwner != null) await notifications.stop();

    if (!await notifications.requestPermission()) {
      _serviceOwner = null;
      if (wanted == ServiceClaim.trip) {
        _problemController.add(
          'Could not start the background service, so the trip will stop '
          'recording when the app leaves the screen.',
        );
      }
      return;
    }

    final started = await notifications.start(
      title: _serviceTitle(wanted),
      text: _serviceText(wanted),
      // location only for a ride, and only a real one. Android 14 refuses a
      // location-typed service from an app with no location permission, and
      // neither a charge nor a bare connection has anything to do with where
      // the bike is.
      usesRealLocation: wanted == ServiceClaim.trip && !isDemo,
    );
    if (!started) {
      _serviceOwner = null;
      if (wanted == ServiceClaim.trip) {
        _problemController.add(
          'Could not start the background service, so the trip will stop '
          'recording when the app leaves the screen.',
        );
      }
      return;
    }

    _serviceOwner = wanted;
    _notificationTimer?.cancel();
    // A ride and a download are being watched second by second; a charge or a
    // bare connection is not, and rewriting that notification once a second
    // for hours would spend battery on a number nobody is reading. The point
    // of holding the service is the radio, not the text.
    final cadence = switch (wanted) {
      ServiceClaim.trip || ServiceClaim.update => const Duration(seconds: 1),
      ServiceClaim.charge || ServiceClaim.link => const Duration(seconds: 10),
    };
    _notificationTimer = Timer.periodic(
      cadence,
      (_) => unawaited(_updateForegroundService()),
    );
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
      if (mutedAlerts.contains(alert.name)) continue;
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

  // --- Automatic trip recording ---
  //
  // Consumption is learned from recorded rides, so a ride nobody recorded
  // teaches the app nothing. And the rides people forget to record are not a
  // random sample: they are the short ones, the rushed ones, the ones where
  // you were late.

  final TripAutoStart tripAutoStart = TripAutoStart();

  /// Whether to open and close trips without being asked.
  bool autoTripEnabled = true;

  /// Fires when a trip was started or stopped without anybody pressing
  /// anything, so a screen can say so rather than leaving the rider to work
  /// out why it is suddenly recording.
  final _autoTripController = StreamController<AutoTripAction>.broadcast();

  Stream<AutoTripAction> get autoTripEvents => _autoTripController.stream;

  Future<void> _updateAutoTrip(BmsSnapshot snapshot) async {
    // Never against the simulated pack: a demo ride that opened itself would
    // be teaching the demo world things nobody asked for.
    if (!autoTripEnabled || isDemo || activeDevice == null) return;

    // The radio is not on until the pack is drawing, which is what keeps this
    // from being a GPS listener running all day. Current is cheap to watch and
    // already arriving; satellites are not.
    await _armLocationForAutoTrip(snapshot);

    final action = tripAutoStart.evaluate(
      at: snapshot.timestamp,
      current: snapshot.current,
      // Null until there is a *fresh* fix. The stale figure was the other half
      // of the pause bug: the last thing pause() writes is a zero, and handing
      // that to the detector for the rest of the ride made every coast look
      // like a parked bike.
      speedKmh: trip.isRecording ? trip.freshSpeedKmh : _lastAutoSpeedKmh,
      recording: trip.isRecording,
    );

    switch (action) {
      case AutoTripAction.start:
        final problem = await startTrip();
        // No location, no ride: distance is the whole point, and a trip with
        // no track would poison the consumption figure with a divide by zero.
        if (problem == null) _autoTripController.add(AutoTripAction.start);
      case AutoTripAction.stop:
        await stopTrip();
        _autoTripController.add(AutoTripAction.stop);
      case AutoTripAction.none:
        break;
    }
  }

  /// Turns the GPS on once the pack is drawing, and off again when it stops.
  ///
  /// Auto-start needs movement as well as current, and movement needs a fix.
  /// Holding a location stream open all day to catch the moment somebody sets
  /// off would cost more battery than the feature saves, so the current does
  /// the waiting and the GPS only joins in once there is something to confirm.
  Future<void> _armLocationForAutoTrip(BmsSnapshot snapshot) async {
    // isActive, not isRecording. A paused trip still owns the location stream,
    // and this used to tear it down: pausing to put air in the tyres left the
    // pack drawing nothing, which read as "stood down", and the fixes never
    // came back when the ride resumed. The rest of that ride recorded no
    // distance at all, and the stale zero speed then looked like a parked bike
    // to the auto-stop.
    if (trip.isActive) return;

    final drawing = snapshot.current <= -tripAutoStart.minCurrentAmps;
    if (drawing && _location == null) {
      await _ensureLocation();
    } else if (!drawing && _location != null && !tripAutoStart.looksLikeRiding) {
      // Stood down. The speed goes with it: a stale one would let a later
      // burst of current start a ride on a fix from an hour ago.
      _lastAutoSpeedKmh = null;
      await _stopLocation();
    }
  }

  /// Speed while no trip is open, so the detector has something to judge.
  double? _rawAutoSpeedKmh;
  DateTime? _autoSpeedAt;

  /// The same figure, withdrawn once it is too old to mean anything.
  ///
  /// A speed from a minute ago is not a speed. Left standing, it lets a burst
  /// of current open a ride on a fix taken at the last set of lights.
  double? get _lastAutoSpeedKmh {
    final at = _autoSpeedAt;
    if (at == null) return null;
    return DateTime.now().toUtc().difference(at) > const Duration(seconds: 20)
        ? null
        : _rawAutoSpeedKmh;
  }

  set _lastAutoSpeedKmh(double? kmh) {
    _rawAutoSpeedKmh = kmh;
    _autoSpeedAt = kmh == null ? null : DateTime.now().toUtc();
  }

  /// Fed by the UI from the location stream when nothing is recording.
  set idleSpeedKmh(double? kmh) => _lastAutoSpeedKmh = kmh;

  // --- Charge watch ---
  //
  // Charge alerts were useless without a service. Android throttles a
  // backgrounded app off the radio within minutes, so overnight there were no
  // readings and therefore no alerts -- exactly the case the alerts were built
  // for. The service itself is arbitrated in [_updateForegroundService]; all
  // that is left here is the claim and the wording.

  /// Whether to hold a foreground service open while the pack is charging.
  ///
  /// Distinct from [linkWatchEnabled] even though both hold the same service:
  /// this one is about being reachable overnight with the app closed, which is
  /// a longer and more expensive commitment than staying alive while somebody
  /// is using the app.
  bool chargeWatchEnabled = false;

  /// Wording for the charging notification, supplied by the UI.
  String chargeWatchTitle = 'Charging';
  String Function(BmsSnapshot?)? chargeWatchText;

  // --- Home screen widget ---
  //
  // Shows the last reading, never a live one: the app holds the link for a few
  // minutes a day, so anything on the home screen is a memory and says so.

  final WidgetPublisher widgetPublisher = WidgetPublisher();

  /// The words for the age line, set by the app so this layer stays free of
  /// Flutter localisations.
  PackWidgetStrings? widgetStrings;

  Future<void> _publishWidget(BmsSnapshot snapshot) async {
    final device = activeDevice;
    final words = widgetStrings;
    if (device == null || words == null || device.demo) return;

    await widgetPublisher.publish(
      PackWidgetContent.from(
        packName: device.name.isEmpty ? device.id : device.name,
        soc: snapshot.soc,
        readingAt: snapshot.timestamp,
        now: DateTime.now().toUtc(),
        // Only once this pack has taught the app what a kilometre costs. A
        // range quoted from the default consumption would look identical to
        // one it had earned.
        rangeKm: rangeEstimator.hasLearned
            ? rangeEstimator.rangeKm(
                RangeEstimator.usableWh(
                  remainingAh: snapshot.remainingCapacityAh,
                  packVoltage: snapshot.packVoltage,
                  cellCount: snapshot.cellCount,
                  minCellVoltage: snapshot.minCellVoltage,
                  averageCellVoltage: snapshot.averageCellVoltage,
                  cutoffVoltagePerCell: cutoffVoltagePerCell,
                ),
              )
            : null,
        strings: words,
      ),
    );
  }

  // --- Charge alerts ---

  //
  // Charging happens overnight, which is exactly why nobody sees any of it.

  /// Alert names the rider has switched off. Checked at the moment of firing
  /// rather than inside the detectors, so muting never changes what the app
  /// knows -- only what it says out loud.
  Set<String> mutedAlerts = const {};

  final ChargeAlerts chargeAlerts = ChargeAlerts();
  final _chargeAlertController = StreamController<ChargeAlert>.broadcast();

  Stream<ChargeAlert> get chargeAlertStream => _chargeAlertController.stream;

  void _checkChargeAlerts(BmsSnapshot snapshot) {
    for (final alert in chargeAlerts.evaluate(snapshot)) {
      if (mutedAlerts.contains(alert.name)) continue;
      _chargeAlertController.add(alert);
      // The notification the trip service already owns is the only way any of
      // this reaches a phone in another room. It is only running during a
      // ride, so on the bench this is a buzz and a banner; plugged in with the
      // service up, it is a notification.
      if (hapticAlerts) {
        if (alert.isProblem) {
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
    double? chargeTargetSoc,
    bool watchCharge = false,
    bool autoTrip = true,
    bool watchLink = true,
    Set<String> muted = const {},
  }) {
    chargeWatchEnabled = watchCharge;
    linkWatchEnabled = watchLink;
    autoTripEnabled = autoTrip;
    mutedAlerts = muted;
    chargeAlerts.targetSoc = chargeTargetSoc;
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
      await refreshMeasuredCapacity();
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

  Future<void> _adoptCapacityFromBms(JkSettings settings) async {
    final id = activeDeviceId;
    final repo = repository;
    if (id == null || repo == null) return;
    final nominal = settings.nominalCapacityAh;
    if (nominal < 1 || nominal > 2000) return;
    if (await repo.adoptDeviceCatalogueFromBms(id, nominal)) {
      await refreshActiveDevice();
    }
  }

  Future<void> dispose() async {


    _silenceTimer?.cancel();
    _notificationTimer?.cancel();
    _notificationTimer = null;
    _serviceOwner = null;
    await notifications.stop();
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

    // Milliseconds: inSeconds was zero for almost every real interval, so
    // this returned early on nearly every reading and the in-ride learning
    // never accumulated anything at all. See [usableInterval].
    final dt = usableInterval(previousAt, at);
    if (dt == null) return null;

    final dKm = odometerKm - previousKm;
    if (dKm < 0) return null;

    // Discharge is negative power, and consumption is what we are learning.
    _wh += -power * hoursIn(dt);
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
