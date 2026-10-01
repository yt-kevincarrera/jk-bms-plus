/// The morning the phone would not connect, and what this file does about it.
///
/// The rider's report (2026-10-01): it happens from one day to the next. The
/// link is let go of normally in the evening; the next morning, standing next
/// to the bike, no attempt connects. Retrying does nothing, switching the
/// phone's Bluetooth off and on does nothing, and restarting the phone fixes
/// it. The errors on screen were Android's GATT 147 (`GATT_CONNECTION_TIMEOUT`)
/// and, right after, an MTU request refused because the device was already
/// gone.
///
/// Two places can hold state that survives a Bluetooth toggle and not a
/// reboot, and the evidence so far does not say which:
///
///  * this app's process: flutter_blue_plus's Dart mutexes and connection
///    table, the transport's own flags, and the plugin's native map of
///    `BluetoothGatt` objects, any of which a toggle leaves alone;
///  * Android's stack below the app: with "Bluetooth scanning" on in the
///    location settings, switching Bluetooth off only drops to BLE-only mode,
///    so the controller, and whatever link it believes it still has with the
///    pack, is never reset.
///
/// So this does three things. It writes down every attempt with what the app
/// could see at the time (did the pack advertise, does the phone list it as
/// connected, how long has the process been up), so the next bad morning is
/// explained by a backup. It escalates what it does before each attempt as the
/// failures pile up, doing what a reboot does as far as an app can. And after
/// enough failures it tells the rider what to try, in an order that separates
/// the two places, and notices which one worked.
///
/// Pure apart from the [RecoveryRadio] it is handed, so all of it can be
/// tested without a phone.
library;

import 'dart:async';

DateTime? _processStart;

/// Called first thing in `main`, so "how long has this process been alive"
/// measures the process and not the first time anybody asked.
void markProcessStart() => _processStart ??= DateTime.now();

/// When this process started, as near as Dart can tell.
DateTime get processStartedAt => _processStart ??= DateTime.now();

/// One advertisement heard from a device.
class AdvertSighting {
  const AdvertSighting({required this.rssi, required this.at});

  final int rssi;

  /// When the radio heard it, which is not when the app looked at it.
  final DateTime at;
}

/// The last advertisement heard from each device, from every scan the app
/// runs: the connect screen's, the proximity watcher's, and the one the
/// recovery runs before an attempt.
///
/// The question it answers is the one that splits the morning failure in two.
/// A JK BMS stops advertising while a central holds its one connection, so a
/// pack that is heard advertising while every connect to it times out is
/// waiting for a phone that cannot reach it, and a pack that is not heard at
/// all believes it is still connected to somebody, very likely this phone.
class AdvertBook {
  AdvertBook({this.capacity = 200});

  /// The one the app's scans write to.
  static final AdvertBook shared = AdvertBook();

  /// Devices remembered at most. A busy street is full of headphones and the
  /// app cares about one pack.
  final int capacity;

  final Map<String, AdvertSighting> _last = {};
  final _seen = StreamController<String>.broadcast(sync: true);

  /// The id of every device heard, as it is heard.
  Stream<String> get seen => _seen.stream;

  void saw(String deviceId, {required int rssi, required DateTime at}) {
    final previous = _last[deviceId];
    // The plugin re-sends its whole list with every new result, each entry
    // stamped when it was first heard. Only a newer one is news.
    if (previous != null && !at.isAfter(previous.at)) return;
    _last.remove(deviceId);
    _last[deviceId] = AdvertSighting(rssi: rssi, at: at);
    if (_last.length > capacity) _last.remove(_last.keys.first);
    _seen.add(deviceId);
  }

  AdvertSighting? lastSeen(String deviceId) => _last[deviceId];
}

/// What the recovery needs from the radio, and nothing else.
///
/// An interface so the escalation can be tested in order with a fake; the
/// production one is `FbpRecoveryRadio`.
abstract interface class RecoveryRadio {
  /// The adapter state as the plugin last heard it, by name.
  String adapterState();

  /// Devices the plugin believes this app is connected to.
  List<String> appConnectedIds();

  /// Devices Android lists as GATT-connected, from any app. Null when the
  /// phone could not be asked.
  Future<List<String>?> systemConnectedIds();

  /// Lets go of the device without queueing behind a stuck operation.
  Future<void> release(String deviceId);

  /// Connects through the plugin and lets go again, to close a link the phone
  /// holds and nothing in this app does. Returns what happened, for the log.
  Future<String> closeStranded(String deviceId);

  /// Scans until the device advertises or [within] runs out. Null when it was
  /// not heard.
  Future<AdvertSighting?> freshAdvert(
    String deviceId, {
    required Duration within,
    required bool Function() stillWanted,
  });

  /// Lets go of everything the plugin holds, as far as an app can. Returns
  /// what happened, for the log.
  Future<String> resetAll();

  /// Adapter state changes, by name.
  Stream<String> get adapterStates;
}

/// Where the recovery keeps the few facts that must outlive the process.
///
/// Outliving the process is the point: the experiment is whether killing the
/// app or restarting the phone is what fixes it, and both of those wipe
/// everything in memory.
abstract interface class RecoveryMemory {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

/// A [RecoveryMemory] that forgets with the process. For tests, and for a
/// transport built without one.
class InMemoryRecoveryMemory implements RecoveryMemory {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

/// How one attempt ended.
enum AttemptOutcome {
  /// Connected and stayed up past the hold time.
  connected,

  /// An error.
  failed,

  /// Ran out of time, the plugin's connect timeout or the transport's own
  /// deadline.
  timedOut,

  /// Came up and went away again within the hold time. The MTU refusal on a
  /// link that was already gone is one of these.
  droppedAfterConnect,

  /// Let go of on purpose before it finished: the rider disconnected, or
  /// another attempt took its place. Not evidence of anything.
  cancelled,
}

/// What a rider can do about a stuck stack, in the order the card offers it.
enum BluetoothRemedy {
  /// The button: the app let go of everything it holds.
  inAppReset,

  /// The phone's Bluetooth went off while the stack looked stuck.
  bluetoothToggled,

  /// A new process started while the stack looked stuck: force-stopped, or
  /// killed and reopened.
  appRestarted,

  /// The phone booted after the stack was judged stuck.
  phoneRestarted,
}

/// Something the recovery wants written down or shown.
sealed class RecoveryEvent {
  const RecoveryEvent();
}

/// One attempt, finished.
class AttemptRecorded extends RecoveryEvent {
  const AttemptRecorded(this.record);
  final ConnectAttemptRecord record;
}

/// Enough failures in a row that the phone, not the pack, is the suspect.
class StuckDeclared extends RecoveryEvent {
  const StuckDeclared(this.deviceId, this.failures);
  final String deviceId;
  final int failures;
}

/// One of the card's steps was taken, or the app saw it happen.
class RemedyTaken extends RecoveryEvent {
  const RemedyTaken(this.remedy, {this.detail = ''});
  final BluetoothRemedy remedy;
  final String detail;
}

/// The first connection after the stack was judged stuck. Detail says what
/// was tried in between, which is the answer the experiment is after.
class RecoveredAfterStuck extends RecoveryEvent {
  const RecoveredAfterStuck(this.detail);
  final String detail;
}

/// One attempt in progress, and what the app could see before it began.
class PreparedAttempt {
  PreparedAttempt._({
    required this.deviceId,
    required this.number,
    required this.escalated,
    required this.releases,
    required this.connectTimeout,
    required this.beganAt,
  });

  final String deviceId;

  /// Which attempt this is in the current streak of failures, from 1.
  final int number;

  /// Whether the streak called for the release, the fresh-advert scan and
  /// the longer timeout.
  final bool escalated;

  /// Whether the release runs before it: escalated, or the phone was found
  /// holding the pack with nothing here owning it. The preparation can then
  /// take several seconds, and the transport's deadline has to allow for it.
  final bool releases;

  /// What the connect call is given.
  final Duration connectTimeout;

  /// When preparation began.
  final DateTime beganAt;

  /// What was done before connecting, in order, for the log.
  final List<String> steps = [];

  /// When the connect call itself started, after any preparation.
  DateTime? connectAt;

  /// When the plugin said the link was up.
  DateTime? linkUpAt;

  String adapter = '?';
  int appConnected = 0;
  bool appHasOurs = false;
  int? systemConnected;
  bool? systemHasOurs;

  /// The last advertisement heard from this device before connecting.
  AdvertSighting? advert;

  bool finished = false;
}

/// One finished attempt, as it is written down.
class ConnectAttemptRecord {
  const ConnectAttemptRecord({
    required this.deviceId,
    required this.number,
    required this.outcome,
    required this.endedAt,
    required this.detail,
    required this.counted,
  });

  final String deviceId;
  final int number;
  final AttemptOutcome outcome;
  final DateTime endedAt;

  /// One line, technical, the same in every language, like the exception text
  /// it carries. It is what the LinkEvent stores.
  final String detail;

  /// Whether it counted towards the streak.
  final bool counted;
}

/// Decides what to do before each attempt, writes down how each one went, and
/// says when the phone looks stuck.
class ConnectRecovery {
  ConnectRecovery({
    required this.radio,
    AdvertBook? adverts,
    RecoveryMemory? memory,
    Future<DateTime?> Function()? bootTime,
    DateTime Function()? now,
    this.normalTimeout = const Duration(seconds: 8),
    this.longTimeout = const Duration(seconds: 15),
    this.releasePause = const Duration(milliseconds: 1500),
    this.advertWait = const Duration(seconds: 8),
    this.advertFresh = const Duration(seconds: 60),
    this.holdFor = const Duration(seconds: 2),
    this.escalateAfter = 2,
    this.stuckAfter = 4,
    this.forgetAfter = const Duration(minutes: 30),
  }) : adverts = adverts ?? AdvertBook.shared,
       _memory = memory ?? InMemoryRecoveryMemory(),
       _bootTime = bootTime,
       _now = now ?? DateTime.now;

  final RecoveryRadio radio;
  final AdvertBook adverts;
  final RecoveryMemory _memory;
  final Future<DateTime?> Function()? _bootTime;
  final DateTime Function() _now;

  /// The connect timeout for an ordinary attempt. The transport's own, which
  /// was chosen for a pack that answers in a couple of seconds or not at all.
  final Duration normalTimeout;

  /// The connect timeout once escalated. A stack that is struggling may need
  /// longer than eight seconds to get an answer through, and by now a slow
  /// success beats another fast failure.
  final Duration longTimeout;

  /// The pause after letting go, so the pack and the stack both notice before
  /// the next connect arrives.
  final Duration releasePause;

  /// How long the pre-attempt scan may look for the pack.
  final Duration advertWait;

  /// How old an advertisement may be and still count as "seen just now".
  final Duration advertFresh;

  /// How long a link must stay up to count as connected. Shorter than this
  /// and it is the "connected, then gone" pattern the 147 report showed.
  final Duration holdFor;

  /// Failures in a row before the release and the fresh scan run.
  ///
  /// Two, so a single bad attempt still gets the plain quick retry that
  /// recovers an ordinary drop in a few hundred milliseconds.
  final int escalateAfter;

  /// Failures in a row before the rider is told the phone looks stuck.
  /// Matches the connect screen's own threshold.
  final int stuckAfter;

  /// A failure older than this does not count towards today's streak.
  /// Last night's failures say nothing about this morning.
  final Duration forgetAfter;

  /// Synchronous, so the record of a failure is written and the streak is
  /// visible before the transport goes on to report the error that a screen
  /// redraws for.
  final _events = StreamController<RecoveryEvent>.broadcast(sync: true);

  /// Everything worth writing down or redrawing for.
  Stream<RecoveryEvent> get events => _events.stream;

  static const _stuckSinceKey = 'ble_stuck_since';
  static const _remediesKey = 'ble_stuck_remedies';
  static const _lastSuccessKey = 'ble_last_success';

  String? _streakDevice;
  int _streak = 0;
  DateTime? _lastCountedAt;

  /// Devices the phone was found holding with nothing in this app owning
  /// them. The next attempt on one of these releases first.
  final Set<String> _suspectStranded = {};

  /// The attempt waiting out [holdFor] before it counts as connected.
  PreparedAttempt? _holding;
  Timer? _holdTimer;

  DateTime? _lastSuccessAt;

  /// When the stack was judged stuck, if it still is. Survives the process.
  DateTime? _stuckSince;

  /// What has been tried since [_stuckSince], oldest first, as written.
  final List<String> _remedies = [];

  /// Whether an attempt has failed since the last remedy. The card shows only
  /// then: right after the reset button, or in a fresh process, the next
  /// attempt deserves its chance before the card comes back.
  bool _failedSinceRemedy = false;

  StreamSubscription<String>? _adapterSub;
  String? _lastAdapter;

  /// Failures in a row on [deviceId] that still count.
  int failuresFor(String deviceId) {
    if (deviceId != _streakDevice) return 0;
    final at = _lastCountedAt;
    if (at == null || _now().difference(at) > forgetAfter) return 0;
    return _streak;
  }

  /// Whether the card should be on screen.
  bool get looksStuck => _stuckSince != null && _failedSinceRemedy;

  /// Failures in the current streak, for the card's wording.
  int get streak => _streakDevice == null ? 0 : failuresFor(_streakDevice!);

  /// What has been tried since the stack was judged stuck.
  List<String> get remedies => List.unmodifiable(_remedies);

  /// The phone was found holding [deviceId] with nothing here owning it. The
  /// next attempt lets go of it and closes it before connecting.
  void suspectStranded(String deviceId) => _suspectStranded.add(deviceId);

  /// Reads what the last process left behind, and notices whether the app or
  /// the phone restarted while the stack looked stuck.
  Future<void> load() async {
    try {
      final last = await _memory.read(_lastSuccessKey);
      _lastSuccessAt ??= last == null ? null : DateTime.tryParse(last);
      final since = await _memory.read(_stuckSinceKey);
      final stuckAt = since == null ? null : DateTime.tryParse(since);
      if (stuckAt == null) return;
      // A day on, whatever was stuck has had every chance to come unstuck by
      // itself, and the card coming back over one failed tap next week would
      // be a verdict on a different morning.
      if (_now().difference(stuckAt) > const Duration(days: 1)) {
        await _write(_stuckSinceKey, null);
        await _write(_remediesKey, null);
        return;
      }
      _stuckSince = stuckAt;
      final stored = await _memory.read(_remediesKey);
      if (stored != null && stored.isNotEmpty) {
        _remedies.addAll(stored.split('|'));
      }
      // A new process while stuck is a remedy on its own; a boot after the
      // judgement is a stronger one, and it implies the first.
      final booted = await _bootTime?.call();
      final remedy = booted != null && booted.isAfter(stuckAt)
          ? BluetoothRemedy.phoneRestarted
          : BluetoothRemedy.appRestarted;
      _remedy(remedy, detail: booted == null ? 'boot time unknown' : '');
      _watchAdapter();
    } on Object catch (_) {
      // Nothing remembered is the same as nothing stuck.
    }
  }

  /// Starts an attempt. Synchronous, so the transport has something to
  /// finish on every path out, including a deadline that fires while the
  /// preparation is still running.
  PreparedAttempt begin(String deviceId) {
    final failures = failuresFor(deviceId);
    final escalated = failures >= escalateAfter;
    // Taken here, once: the attempt that was told about the stranded link is
    // the one that deals with it.
    final stranded = _suspectStranded.remove(deviceId);
    return PreparedAttempt._(
      deviceId: deviceId,
      number: failures + 1,
      escalated: escalated,
      releases: escalated || stranded,
      connectTimeout: escalated ? longTimeout : normalTimeout,
      beganAt: _now(),
    );
  }

  /// Does what the streak calls for before connecting, then notes what the
  /// app can see. Each radio call is bounded, so this always returns.
  Future<void> prepare(
    PreparedAttempt a, {
    required bool Function() stillWanted,
  }) async {
    final id = a.deviceId;
    List<String>? system;

    if (a.releases) {
      // Step two of the escalation: give back everything this app might
      // hold for the device. `release` jumps the plugin's queue, which is
      // the only way past an operation that hung.
      a.steps.add('release');
      await _bounded(radio.release(id), const Duration(seconds: 10));
      final app = radio.appConnectedIds();
      system = await _bounded<List<String>?>(
        radio.systemConnectedIds(),
        const Duration(seconds: 4),
      );
      // The phone still lists it while this app thinks it is not connected:
      // a link nobody owns. Connecting through the plugin and letting go is
      // the only handle an app has on it.
      if (stillWanted() &&
          (app.contains(id) || (system?.contains(id) ?? false))) {
        final note = await _bounded(
          radio.closeStranded(id),
          const Duration(seconds: 15),
        );
        a.steps.add('close stranded (${note ?? 'no answer'})');
        system = null;
      }
      if (stillWanted()) await Future<void>.delayed(releasePause);
    }

    if (a.escalated && stillWanted()) {
      // Step three: wait to hear the pack, then connect straight away. Not
      // hearing it is an answer too, and the attempt goes ahead regardless.
      final started = _now();
      final heard = await _bounded(
        radio.freshAdvert(id, within: advertWait, stillWanted: stillWanted),
        advertWait + const Duration(seconds: 4),
      );
      final took = _now().difference(started).inMilliseconds;
      a.steps.add(
        heard == null
            ? 'advert not heard in $took ms'
            : 'advert heard after $took ms',
      );
    }

    a.adapter = radio.adapterState();
    final app = radio.appConnectedIds();
    a.appConnected = app.length;
    a.appHasOurs = app.contains(id);
    system ??= await _bounded<List<String>?>(
      radio.systemConnectedIds(),
      const Duration(seconds: 4),
    );
    a.systemConnected = system?.length;
    a.systemHasOurs = system?.contains(id);
    a.advert = adverts.lastSeen(id);
    a.connectAt = _now();
  }

  /// The plugin's connect returned: the link is up, for now.
  void linkUp(PreparedAttempt a) => a.linkUpAt ??= _now();

  /// The attempt reached `connected`. It is written down once it has stayed
  /// up for [holdFor], or as a drop if it does not.
  void connected(PreparedAttempt a) {
    if (a.finished) return;
    final up = a.linkUpAt ??= _now();
    _holdTimer?.cancel();
    final previous = _holding;
    if (previous != null && !identical(previous, a)) cancelled(previous);
    _holding = a;
    var left = holdFor - _now().difference(up);
    if (left.isNegative) left = Duration.zero;
    _holdTimer = Timer(left, () {
      if (!identical(_holding, a)) return;
      _holding = null;
      _holdTimer = null;
      _finish(a, AttemptOutcome.connected, counted: false);
    });
  }

  /// The attempt threw, or the transport gave up on it.
  void failed(PreparedAttempt a, Object error, {bool timedOut = false}) {
    if (a.finished) return;
    if (identical(_holding, a)) {
      _holdTimer?.cancel();
      _holding = null;
    }
    final text = error.toString();
    final up = a.linkUpAt;
    final droppedEarly = up != null && _now().difference(up) < holdFor;
    final timeout = timedOut || isTimeout(text);
    final outcome = droppedEarly
        ? AttemptOutcome.droppedAfterConnect
        : timeout
        ? AttemptOutcome.timedOut
        : AttemptOutcome.failed;
    _finish(
      a,
      outcome,
      error: text,
      counted: droppedEarly || timeout || isStuckCode(text),
    );
  }

  /// The link went down. Only news when an attempt is still inside its hold
  /// time; a link that dropped after that is a drop, not a failed attempt.
  void dropped() {
    final a = _holding;
    if (a == null) return;
    _holdTimer?.cancel();
    _holdTimer = null;
    _holding = null;
    final up = a.linkUpAt;
    final ms = up == null ? '?' : '${_now().difference(up).inMilliseconds}';
    _finish(
      a,
      AttemptOutcome.droppedAfterConnect,
      error: 'link dropped $ms ms after coming up',
      counted: true,
    );
  }

  /// Let go of on purpose. Written down, never counted.
  void cancelled(PreparedAttempt? a) {
    if (a == null || a.finished) return;
    if (identical(_holding, a)) {
      _holdTimer?.cancel();
      _holdTimer = null;
      _holding = null;
    }
    _finish(a, AttemptOutcome.cancelled, counted: false);
  }

  /// The card's first step: lets go of everything and starts the streak's
  /// escalation over, so the next attempt runs with nothing held.
  Future<String> resetEverything() async {
    final note =
        await _bounded(radio.resetAll(), const Duration(seconds: 20)) ??
        'reset did not finish';
    _remedy(BluetoothRemedy.inAppReset, detail: note);
    return note;
  }

  /// Android GATT codes that, from a pack within reach, mean the phone could
  /// not get a link up: 147 (`GATT_CONNECTION_TIMEOUT`) and the catch-all
  /// 133.
  static bool isStuckCode(String text) {
    final l = text.toLowerCase();
    return l.contains('android-code: 147') ||
        l.contains('android-code: 133') ||
        l.contains('gatt_connection_timeout');
  }

  /// The plugin's own connect timeout, or anything else that says it ran out
  /// of time.
  static bool isTimeout(String text) {
    final l = text.toLowerCase();
    return l.contains('timed out') || l.contains('fbp-code: 1 |');
  }

  void _finish(
    PreparedAttempt a,
    AttemptOutcome outcome, {
    String? error,
    required bool counted,
  }) {
    a.finished = true;
    final ended = _now();
    if (counted) {
      if (a.deviceId != _streakDevice || failuresFor(a.deviceId) == 0) {
        _streakDevice = a.deviceId;
        _streak = 0;
      }
      _streak++;
      _lastCountedAt = ended;
      _failedSinceRemedy = true;
    }
    _events.add(
      AttemptRecorded(
        ConnectAttemptRecord(
          deviceId: a.deviceId,
          number: a.number,
          outcome: outcome,
          endedAt: ended,
          detail: _describe(a, outcome, ended, error),
          counted: counted,
        ),
      ),
    );
    if (outcome == AttemptOutcome.connected) {
      _succeeded(a.deviceId, ended);
      return;
    }
    if (counted && _streak >= stuckAfter && _stuckSince == null) {
      _stuckSince = ended;
      _remedies.clear();
      unawaited(_persistStuck());
      _watchAdapter();
      _events.add(StuckDeclared(a.deviceId, _streak));
    }
  }

  void _succeeded(String deviceId, DateTime at) {
    if (deviceId == _streakDevice) {
      _streak = 0;
      _lastCountedAt = null;
    }
    _lastSuccessAt = at;
    unawaited(_write(_lastSuccessKey, at.toUtc().toIso8601String()));
    final since = _stuckSince;
    if (since == null) return;
    final mins = at.difference(since).inMinutes;
    final tried = _remedies.isEmpty ? 'nothing' : _remedies.join(', ');
    _events.add(
      RecoveredAfterStuck(
        'connected $mins min after the stack was judged stuck; tried since: '
        '$tried',
      ),
    );
    _stuckSince = null;
    _remedies.clear();
    _failedSinceRemedy = false;
    unawaited(_adapterSub?.cancel());
    _adapterSub = null;
    unawaited(_write(_stuckSinceKey, null));
    unawaited(_write(_remediesKey, null));
  }

  void _remedy(BluetoothRemedy remedy, {String detail = ''}) {
    if (_stuckSince == null) {
      // A reset with nothing stuck is still worth a line, but it is not part
      // of any experiment.
      _events.add(RemedyTaken(remedy, detail: detail));
      _failedSinceRemedy = false;
      return;
    }
    final now = _now();
    _remedies.add('${remedy.name} at ${_clock(now)}');
    _failedSinceRemedy = false;
    unawaited(_persistStuck());
    _events.add(RemedyTaken(remedy, detail: detail));
  }

  /// Watches the adapter while stuck, so a toggle is noticed without the
  /// rider having to say so.
  void _watchAdapter() {
    if (_adapterSub != null) return;
    try {
      _adapterSub = radio.adapterStates.listen((s) {
        final was = _lastAdapter;
        _lastAdapter = s;
        // On the way to off, once: the stream says turningOff, then off.
        if (_stuckSince == null || s != 'off' || was == 'off') return;
        _remedy(BluetoothRemedy.bluetoothToggled);
      }, onError: (Object _) {});
    } on Object catch (_) {
      // No adapter stream, no toggle detection. The rider can still say.
    }
  }

  Future<void> _persistStuck() async {
    final since = _stuckSince;
    if (since == null) return;
    await _write(_stuckSinceKey, since.toUtc().toIso8601String());
    await _write(_remediesKey, _remedies.join('|'));
  }

  Future<void> _write(String key, String? value) async {
    try {
      await _memory.write(key, value);
    } on Object catch (_) {
      // Lost across a restart at worst; this process still knows.
    }
  }

  String _describe(
    PreparedAttempt a,
    AttemptOutcome outcome,
    DateTime ended,
    String? error,
  ) {
    final from = a.connectAt ?? a.beganAt;
    final parts = <String>[
      '#${a.number} ${outcome.name} in ${ended.difference(from).inMilliseconds} ms'
          '${error == null ? '' : ': $error'}',
    ];
    final prep = (a.connectAt ?? ended).difference(a.beganAt).inMilliseconds;
    if (a.steps.isNotEmpty) {
      parts.add('before it: ${a.steps.join(', ')} ($prep ms)');
    }
    parts.add('timeout ${a.connectTimeout.inSeconds} s');
    final ad = a.advert;
    final seenAt = a.connectAt ?? ended;
    if (ad == null) {
      parts.add('advert never heard this process');
    } else {
      final age = seenAt.difference(ad.at);
      parts.add(
        age <= advertFresh
            ? 'advert ${ad.rssi} dBm ${age.inSeconds} s before'
            : 'no advert in the last ${advertFresh.inSeconds} s '
                  '(last ${_span(age)} before)',
      );
    }
    parts.add(
      'app connected ${a.appConnected} (ours ${a.appHasOurs ? 'yes' : 'no'})',
    );
    parts.add(
      a.systemConnected == null
          ? 'system connected ?'
          : 'system connected ${a.systemConnected} '
                '(ours ${a.systemHasOurs == true ? 'yes' : 'no'})',
    );
    parts.add('adapter ${a.adapter}');
    parts.add('uptime ${_span(ended.difference(processStartedAt))}');
    final last = _lastSuccessAt;
    parts.add(
      last == null
          ? 'no success on record'
          : 'last success ${_span(ended.difference(last))} ago',
    );
    if (_stuckSince != null && _remedies.isNotEmpty) {
      parts.add('tried: ${_remedies.join(', ')}');
    }
    return parts.join(' · ');
  }

  static Future<T?> _bounded<T>(Future<T> f, Duration limit) async {
    try {
      return await f.timeout(limit);
    } on Object catch (_) {
      return null;
    }
  }

  static String _span(Duration d) {
    if (d.isNegative) return '0 s';
    if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
    if (d.inMinutes > 0) return '${d.inMinutes} min ${d.inSeconds % 60} s';
    return '${d.inSeconds} s';
  }

  static String _clock(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    final l = t.toLocal();
    return '${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
  }

  Future<void> dispose() async {
    _holdTimer?.cancel();
    await _adapterSub?.cancel();
    await _events.close();
  }
}

/// At most so many attempt rows an hour, so a retry loop cannot fill the
/// database. Rows over the budget are counted, and the count rides on the next
/// row that is written, so a backup still says how many there were.
class AttemptBudget {
  AttemptBudget({this.perHour = 30});

  final int perHour;
  final List<DateTime> _written = [];
  int _skipped = 0;

  /// Null when [at] is over budget. Otherwise how many were skipped since the
  /// last one admitted.
  int? admit(DateTime at) {
    _written.removeWhere((t) => at.difference(t) >= const Duration(hours: 1));
    if (_written.length >= perHour) {
      _skipped++;
      return null;
    }
    _written.add(at);
    final skipped = _skipped;
    _skipped = 0;
    return skipped;
  }
}
