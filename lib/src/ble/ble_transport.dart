import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../protocol/jk_constants.dart';
import 'bms_link.dart';
import 'link_quiet.dart';
import 'link_trouble.dart';
import 'reconnect_backoff.dart';

/// What the link is doing right now.
enum BleLinkState {
  idle,
  scanning,
  connecting,
  negotiating,
  connected,
  reconnecting,
  failed,
}

/// A JK BMS advertising nearby.
class DiscoveredBms {
  const DiscoveredBms({
    required this.id,
    required this.name,
    required this.rssi,
    this.advertisesJkService = false,
    this.nameLooksLikeJk = false,
  });

  final String id;
  final String name;
  final int rssi;

  /// The advertisement carried the JK service UUID. As close to proof as a
  /// scan gets.
  final bool advertisesJkService;

  /// The advertised name contains "JK". A hint, not proof: the name is a
  /// setting, and a renamed pack stops matching.
  final bool nameLooksLikeJk;

  /// Whether this is probably the BMS rather than a headset or a TV.
  ///
  /// Used to sort and to highlight, never to hide. A device that fails both
  /// checks can still be the right one -- a JK BMS renamed in the official app
  /// to something personal advertises neither the service UUID nor the letters
  /// JK, and hiding it would leave a rider staring at an empty list with no
  /// way to tell an absent pack from a filtered one.
  bool get likelyBms => advertisesJkService || nameLooksLikeJk;
}

/// Judges one advertisement, without deciding whether to show it.
///
/// Pulled out of the scan so the classification can be tested: the bug this
/// replaced was a filter that dropped anything failing both checks, and the
/// only way to keep that from coming back is a test that names a device with
/// neither and expects it to survive.
DiscoveredBms classifyAdvertisement({
  required String id,
  required String name,
  required int rssi,
  required Iterable<String> serviceUuids,
}) =>
    DiscoveredBms(
      id: id,
      name: name,
      rssi: rssi,
      advertisesJkService:
          serviceUuids.any((u) => u.toLowerCase().contains('ffe0')),
      nameLooksLikeJk: name.toUpperCase().contains('JK'),
    );

/// Strongest signal of being the BMS first, then closest.
int compareDiscovered(DiscoveredBms a, DiscoveredBms b) {
  if (a.likelyBms != b.likelyBms) return a.likelyBms ? -1 : 1;
  if (a.advertisesJkService != b.advertisesJkService) {
    return a.advertisesJkService ? -1 : 1;
  }
  // Closest first among equals: the pack under you outshouts a neighbour's.
  return b.rssi.compareTo(a.rssi);
}


/// Decides when a scan is genuinely over, from the radio's own scanning flag.
///
/// Its own class because getting this wrong is what stranded the connect
/// screen: `FlutterBluePlus.isScanning` reports its current value the moment
/// you subscribe, which is `false` before the scan has started. Treating that
/// first `false` as "finished" ends the scan instantly; ignoring every `false`
/// leaves it running forever. Only a `false` that follows a `true` means the
/// radio stopped.
class ScanLifecycle {
  bool _started = false;
  bool _finished = false;

  bool get started => _started;
  bool get finished => _finished;

  /// Returns true exactly once, on the transition that ends the scan.
  bool onScanningChanged({required bool scanning}) {
    if (_finished) return false;
    if (scanning) {
      _started = true;
      return false;
    }
    if (!_started) return false;
    _finished = true;
    return true;
  }

  /// The backstop firing. Ends the scan whether or not the radio ever said so,
  /// because a screen stuck on "searching" is worse than one that stops early.
  bool onDeadline() {
    if (_finished) return false;
    _finished = true;
    return true;
  }
}

/// A scan that ended without the radio ever confirming it began.
///
/// Its own type rather than a message, because the screen has to treat it
/// differently from every other kind of trouble: this is the one case where
/// "nothing found" must not be said.
class ScanNeverStarted implements Exception {
  const ScanNeverStarted();

  @override
  String toString() => 'the radio never confirmed the scan started';
}

/// Why the link is down, in words a rider can act on.
class BleLinkError {
  const BleLinkError(this.message, {this.likelyBusy = false, this.trouble});

  /// Reads an exception and classifies it, keeping the raw text as detail.
  ///
  /// Preferred over the plain constructor everywhere an exception is what we
  /// have: it is what stops `FlutterBluePlusException | ... | android-code:
  /// 133` reaching a screen as the headline.
  factory BleLinkError.from(Object error) {
    final t = LinkTrouble.from(error);
    return BleLinkError(
      error.toString(),
      likelyBusy: t.likelyBusy,
      trouble: t,
    );
  }

  /// The raw text. Kept for the frame console and the details view; never the
  /// thing a screen leads with when [trouble] is set.
  final String message;

  /// The BMS accepts exactly one BLE connection at a time. When the official
  /// app (or an ESP32) already holds it, connection attempts fail in ways that
  /// look like a generic error, so we call it out explicitly.
  final bool likelyBusy;

  /// What this is really about, in terms a screen can put into words the rider
  /// can act on. Null for messages that were already written for a human.
  final LinkTrouble? trouble;

  @override
  String toString() => message;
}

/// Owns the one and only BLE connection to the BMS.
///
/// Deliberately knows nothing about frame contents: it emits raw notification
/// payloads and lets [FrameAssembler] and [JkParser] make sense of them.
///
/// There is exactly one of these in the app. The BMS will not accept a second
/// connection, so a second transport would not just be wasteful, it would fight
/// the first one for the channel.
class BleTransport implements BmsLink {
  BleTransport({
    this.mtuRequest = 244,
    this.reconnectDelay = const Duration(milliseconds: 400),
    this.connectTimeout = const Duration(seconds: 8),
    this.pollInterval = const Duration(seconds: 5),
    this.quietBefore = const Duration(seconds: 6),
    this.muteBefore = const Duration(seconds: 20),
    this.muteRetryDelay = const Duration(seconds: 3),
    this.attachTimeout = const Duration(seconds: 25),
  });

  /// MTU we ask for on connect. 244 is the largest an Android BLE stack will
  /// grant over a 247-byte ATT MTU, and it drops a 300-byte frame from 15
  /// notifications to 2.
  final int mtuRequest;

  /// How long to wait before trying again after the link drops.
  ///
  /// Was two seconds, which sounds harmless and was not. A real ride shows
  /// this pack dropping the link every few seconds and reconnecting, over and
  /// over: fifty-two gaps in an hour, most of them 27 to 33 seconds. Two of
  /// those seconds were this delay and the rest was a connect attempt allowed
  /// to run for twenty. Cycling faster does not stop the drops, but it turns a
  /// thirty-second hole into a few seconds of one.
  final Duration reconnectDelay;

  /// How long a single connect attempt may run before it is abandoned.
  ///
  /// Short on purpose. A JK BMS three feet away either answers in a couple of
  /// seconds or is not going to; waiting twenty is not patience, it is a hole
  /// in the recording.
  final Duration connectTimeout;

  /// Times the link has dropped since the app started, and how long has been
  /// spent disconnected. Shown rather than kept, because a rider whose ride
  /// has holes in it deserves to know whether the link is the reason.
  int drops = 0;
  Duration timeDisconnected = Duration.zero;
  DateTime? _droppedAt;

  @override
  LinkHealth get health => LinkHealth(
        drops: drops,
        // Counts the stretch currently in progress, so a link that went away a
        // minute ago and has not come back says a minute rather than nothing.
        timeDisconnected: _droppedAt == null
            ? timeDisconnected
            : timeDisconnected + DateTime.now().difference(_droppedAt!),
        nudges: nudges,
      );

  /// How often to check whether the BMS has gone quiet.
  ///
  /// The comment here used to say "a nudge, not a poll loop" and the code was
  /// a poll loop: it wrote a cell-info request every five seconds regardless.
  ///
  /// A real ride shows what that costs. Fifty-two stretches of 20 seconds or
  /// more with no cell info at all, most of them 27 to 33 seconds, and in 48 of
  /// them frames were still arriving, so the link was never down. What arrived
  /// during them was device-info responses, at two- to six-second intervals: in
  /// step with the poll. The pack streams cell info two or three times a second
  /// on its own, and being written to every five seconds while it does that is
  /// what appears to interrupt it.
  ///
  /// So the nudge is a nudge now: it only writes when nothing has arrived for
  /// [quietBefore]. On a pack that is streaming normally it never fires at all.
  final Duration pollInterval;

  /// Silence long enough to be worth a nudge.
  ///
  /// Generous next to the two or three readings a second a healthy pack sends,
  /// so ordinary jitter never triggers a write.
  final Duration quietBefore;

  /// Silence long enough to conclude the link is up and dead.
  ///
  /// Not the nudge threshold: by now three nudges have gone unanswered. A JK
  /// BMS that is connected and says nothing for this long is not slow, it is
  /// serving somebody else, or its Bluetooth module is still bound to a session
  /// that ended without a proper disconnect. The rider's report: the pack
  /// connects and stays mute across app restarts and the phone's Bluetooth
  /// being switched off and on, and only after enough taps, rescans and
  /// retries does one attempt land and answer as if nothing happened. Nudging
  /// a link in that state forever is what the transport used to do. Now it
  /// lets go cleanly, which is the one thing the module can act on, and comes
  /// back after [muteRetryDelay], so the retrying happens without the thumb.
  final Duration muteBefore;

  /// The pause before reconnecting to a pack that was connected and mute.
  ///
  /// Longer than [reconnectDelay] on purpose: 400 ms is right for a link that
  /// dropped, and too quick for a module that needs to notice it was let go.
  final Duration muteRetryDelay;

  /// How long one whole attempt -- connect, MTU, discovery, subscribe, the
  /// first two requests -- may take before it is written off.
  ///
  /// [connectTimeout] covers the connect and nothing after it, and the steps
  /// after it are the ones that hang. Each takes the plugin's per-device
  /// operation mutex, and waiting for that mutex has no timeout of its own, so
  /// a discovery or a subscribe whose platform callback never arrives holds
  /// every later operation for the life of the process. The attach that was
  /// waiting never reaches the line that arms [_pollTimer], so the link sits
  /// in whatever state it had reached with nothing watching it: on a rider's
  /// screen, the "connecting" banner disappearing and no reading ever moving
  /// again. This is the deadline that ends that, by letting go -- which is the
  /// one thing that unblocks a stuck operation.
  final Duration attachTimeout;

  /// When a cell-info frame last arrived, which is the only thing that proves
  /// the pack is still talking.
  DateTime? _lastCellInfoAt;

  /// When the current link came up, so a pack that has never spoken since
  /// connecting can be timed too.
  DateTime? _connectedAt;

  /// Nudges sent because the pack really had gone quiet. Counted so the effect
  /// of not polling can be seen rather than assumed.
  int nudges = 0;

  /// Nudges on the current link only, for the mute report to quote.
  int _nudgesThisLink = 0;

  final _stateController = StreamController<BleLinkState>.broadcast();
  final _bytesController = StreamController<List<int>>.broadcast();
  final _errorController = StreamController<BleLinkError>.broadcast();

  @override
  Stream<BleLinkState> get state => _stateController.stream;

  /// Raw notification payloads, in arrival order.
  @override
  Stream<List<int>> get bytes => _bytesController.stream;

  @override
  Stream<BleLinkError> get errors => _errorController.stream;

  BleLinkState _currentState = BleLinkState.idle;
  BleLinkState get currentState => _currentState;

  /// Negotiated MTU, once known. Useful for the System tab: a link stuck at 23
  /// explains a lot of dropped frames.
  
  @override
  int? negotiatedMtu;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  Timer? _pollTimer;

  bool _wantConnection = false;
  bool _disposed = false;

  /// The pending reconnect, so a drop noticed twice (once by the connection
  /// state stream, once by the attach that failed) schedules one attempt, not
  /// two racing each other for the same pack.
  Timer? _reconnectTimer;

  /// Whether an attempt is running right now.
  ///
  /// One at a time, always. Two attaches on one device share `_notifySub`,
  /// `_characteristic` and the plugin's operation mutex, so the second
  /// overwrites what the first is still using and each waits on the other's
  /// operations. The scheduled retry and the connection-state stream can both
  /// start one, and before this flag they did.
  bool _attaching = false;

  /// [attachTimeout] for the attempt in flight.
  Timer? _attachDeadline;

  /// Which attempt is the current one.
  ///
  /// Only ever used to answer "is this still mine": an attempt the deadline
  /// gave up on can still complete later, and when it does it must not set
  /// the state, arm the poll timer, or tear down what the attempt after it
  /// has since built. It stops touching anything instead.
  int _attachId = 0;

  /// The pause the next reconnect should take instead of the backoff's.
  Duration? _nextReconnectDelay;

  /// How long to wait before each retry, and when to stop retrying.
  ///
  /// The loop used to have neither. It retried every 400 ms for ever, which is
  /// exactly what [ConnectGuard] exists to stop a *thumb* doing, for exactly
  /// the reason written at the top of that file: every failed attempt can
  /// leave a connection Android never closes, and those resources belong to
  /// the whole phone. A tap was protected. The loop, running unattended for a
  /// whole ride, was not.
  late final ReconnectBackoff _backoff = ReconnectBackoff(
    firstDelay: reconnectDelay,
  );

  @override
  LinkRetryState get retry => LinkRetryState(
        failures: _backoff.failures,
        gaveUp: _backoff.hasGivenUp,
      );

  /// Scans for BLE devices and reports every one of them.
  ///
  /// It reports everything on purpose. Filtering to devices that advertise the
  /// JK service UUID or carry "JK" in the name looks tidy and is wrong: plenty
  /// of JK firmware puts neither in the advertisement, and a pack renamed in
  /// the official app matches nothing. The result was a scan that found the
  /// BMS, discarded it, and showed an empty list -- a failure indistinguishable
  /// from the pack being switched off.
  ///
  /// So the judgement moves to [DiscoveredBms.likelyBms], which sorts and
  /// highlights, and the rider can still pick anything they recognise.
  @override
  Stream<List<DiscoveredBms>> scan({
    Duration timeout = const Duration(seconds: 20),
  }) {
    _setState(BleLinkState.scanning);
    final found = <String, DiscoveredBms>{};
    final controller = StreamController<List<DiscoveredBms>>();
    final lifecycle = ScanLifecycle();

    StreamSubscription<List<ScanResult>>? resultsSub;
    StreamSubscription<bool>? scanningSub;
    Timer? deadline;

    Future<void> finish() async {
      deadline?.cancel();
      await resultsSub?.cancel();
      await scanningSub?.cancel();
      resultsSub = null;
      scanningSub = null;
      if (_currentState == BleLinkState.scanning) _setState(BleLinkState.idle);

      // A scan the radio never confirmed it started is not a scan that found
      // nothing, and saying so is how the app came to greet a rider with
      // "search finished, no devices found" a fraction of a second after
      // launch. The distinction reaches the screen as an error, so it can say
      // that it could not look rather than that it looked and the bike was not
      // there.
      if (!lifecycle.started && !controller.isClosed) {
        controller.addError(const ScanNeverStarted());
      }

      // Closing is the whole point: it is what makes onDone fire, which is
      // what turns the screen's spinner off. Without it the radio stopped at
      // the timeout and the screen said "searching" indefinitely -- over a
      // scan that had already ended and could no longer find anything.
      if (!controller.isClosed) await controller.close();
    }

    resultsSub = FlutterBluePlus.scanResults.listen((results) {
      var changed = false;
      for (final r in results) {
        final name = r.advertisementData.advName.isNotEmpty
            ? r.advertisementData.advName
            : r.device.platformName;
        final id = r.device.remoteId.str;
        final existing = found[id];
        if (existing == null || existing.rssi != r.rssi) {
          found[id] = classifyAdvertisement(
            id: id,
            name: name,
            rssi: r.rssi,
            serviceUuids: r.advertisementData.serviceUuids.map((u) => u.str),
          );
          changed = true;
        }
      }
      if (changed) {
        controller.add(found.values.toList()..sort(compareDiscovered));
      }
    });

    // The radio stops itself when the timeout expires; this is how the app
    // hears about it.
    scanningSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (lifecycle.onScanningChanged(scanning: scanning)) unawaited(finish());
    });

    // And a backstop, in case that flag never arrives. Whatever else goes
    // wrong, the search has to end where the rider can see it end.
    deadline = Timer(timeout + const Duration(seconds: 3), () {
      if (lifecycle.onDeadline()) unawaited(finish());
    });

    // androidUsesFineLocation is not decoration. This app declares
    // BLUETOOTH_SCAN without `neverForLocation`, and Android 12+ then requires
    // ACCESS_FINE_LOCATION before it will hand over any scan result at all.
    // The plugin defaults this to false, so it asked for the Bluetooth
    // permissions, never asked for location, and Android returned an empty
    // list from a scan that reported success -- a BMS advertising three feet
    // away, invisible, with nothing anywhere saying why.
    FlutterBluePlus.startScan(
      timeout: timeout,
      androidUsesFineLocation: true,
    ).catchError((Object e) {
      _errorController.add(BleLinkError.from(e));
      if (lifecycle.onDeadline()) unawaited(finish());
    });

    controller.onCancel = () async {
      lifecycle.onDeadline();
      deadline?.cancel();
      await resultsSub?.cancel();
      await scanningSub?.cancel();
      await FlutterBluePlus.stopScan();
      if (_currentState == BleLinkState.scanning) _setState(BleLinkState.idle);
    };

    return controller.stream;
  }

  /// Connects and keeps the link up until [disconnect] is called.
  @override
  Future<void> connect(String deviceId) async {
    _wantConnection = true;
    // A tap outranks whatever was still running. Without this, an attempt
    // wedged inside the plugin would make [_attach] below return without
    // doing anything, and the rider would be looking at a screen where
    // connect does nothing at all -- the single-flight guard turned into a
    // dead button.
    _attachDeadline?.cancel();
    _attachDeadline = null;
    _attachId++;
    _attaching = false;
    final device = BluetoothDevice.fromId(deviceId);
    _device = device;

    await _connectionSub?.cancel();
    _connectionSub = device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected && _wantConnection) {
        _onDropped();
      }
    });

    await _attach();
  }

  Future<void> _attach() async {
    final device = _device;
    if (device == null || _disposed) return;
    // A retry that arrives while an attempt is still running is not a second
    // attempt, it is the same one asked for twice.
    if (_attaching) return;
    _attaching = true;
    final id = ++_attachId;
    _attachDeadline?.cancel();
    _attachDeadline = Timer(attachTimeout, _abandonStalledAttach);

    try {
      _setState(BleLinkState.connecting);
      await FlutterBluePlus.stopScan();
      await device.connect(
        // flutter_blue_plus requires this declaration. This app is a personal
        // tool for one rider and one motorcycle, and section 2 of the PRD rules
        // out publishing it, so the nonprofit terms apply. Revisit if that ever
        // changes.
        license: License.nonprofit,
        timeout: connectTimeout,
        // Null so the MTU request below is ours to observe and report on.
        mtu: null,
        autoConnect: false,
      );

      // A disconnect that arrived while the connect was in flight wins. The
      // attach used to carry on regardless: the screen had given up, told the
      // transport to let go, and the transport went on to negotiate, subscribe
      // and start nudging a pack nobody wanted any more. The BMS then had its
      // one connection held by a link the app had already written off, and
      // the next tap found it mute, and the one after that, until Bluetooth
      // was switched off and on.
      if (await _abandonedMidway(device, id)) return;

      _setState(BleLinkState.negotiating);

      // Ask for a big MTU straight away. Android may grant less; the frame
      // assembler copes either way, so a refusal is worth recording, not fatal.
      try {
        await device.requestMtu(mtuRequest);
        negotiatedMtu = device.mtuNow;
      } on Exception catch (e) {
        negotiatedMtu = device.mtuNow;
        _errorController.add(
          BleLinkError(
            'MTU stayed at ${device.mtuNow} bytes ($e). Frames will arrive in '
            'more pieces, which is slower but still correct.',
            trouble: LinkTrouble(
              LinkTroubleKind.slowFrames,
              detail: e.toString(),
            ),
          ),
        );
      }

      if (await _abandonedMidway(device, id)) return;
      final characteristic = await _findCharacteristic(device);
      if (await _abandonedMidway(device, id)) return;
      _characteristic = characteristic;

      await _notifySub?.cancel();
      _notifySub = characteristic.onValueReceived.listen(
        (bytes) {
          // Any notification at all proves the pack is still talking, which is
          // the only thing the nudge needs to know. The transport does not
          // parse record types and should not have to.
          _lastCellInfoAt = DateTime.now();
          // And it is the only thing that disproves what the failures implied,
          // which is why the ledger is cleared here and not on the link coming
          // up. A pack that accepts the connection and then says nothing has
          // proved nothing, and clearing the ledger there was what let the
          // mute-link loop run for ever: connect, twenty seconds of silence,
          // let go, reconnect, with the count back at zero every time.
          _backoff.recordSuccess();
          _bytesController.add(bytes);
        },
        onError: (Object e) =>
            _errorController.add(BleLinkError.from(e)),
      );
      await characteristic.setNotifyValue(true);
      if (await _abandonedMidway(device, id)) return;

      _setState(BleLinkState.connected);
      _connectedAt = DateTime.now();
      _nudgesThisLink = 0;
      final since = _droppedAt;
      if (since != null) {
        timeDisconnected += DateTime.now().difference(since);
        _droppedAt = null;
      }

      // The BMS answers device info first; the variant we decode everything
      // else with comes out of that frame, so it has to be the first request.
      await requestDeviceInfo();
      await requestCellInfo();

      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(pollInterval, (_) => _nudgeIfQuiet());
    } on NotAJkBmsException catch (e) {
      // The wrong device, not a bad link. Stop wanting it so the reconnect
      // loop does not chase it, and let go so it is not held either.
      _wantConnection = false;
      _setState(BleLinkState.failed);
      _errorController.add(BleLinkError.from(e));
      await _letGo(device);
    } on Exception catch (e) {
      // Superseded: the deadline let go of this device already, and a later
      // attempt may be using it by now. Nothing here is this attempt's to do.
      if (id != _attachId) return;
      // An attempt that disconnect() abandoned midway is not trouble: the
      // cancelled connect throws, and reporting that would land a generic
      // Bluetooth complaint on top of whatever the screen was about to say.
      if (!_wantConnection) return;
      // Give the device back before asking for it again. The plugin cancels
      // the attempt itself when its own connect timeout fires, and nothing
      // cancels the rest: a discovery or a subscribe that throws on a link
      // Android considers up leaves that link up, held by an attempt already
      // written off, and the retry a moment later asks for a connection the
      // phone is still spending on this one.
      await _letGo(device);
      _backoff.recordFailure();
      _setState(BleLinkState.failed);
      _errorController.add(_describeConnectFailure(e));
      _scheduleReconnect();
    } finally {
      // Only if this is still the current attempt: one the deadline gave up
      // on has already handed both of these to its successor.
      if (id == _attachId) {
        _attaching = false;
        _attachDeadline?.cancel();
        _attachDeadline = null;
      }
    }
  }

  /// Ends an attempt that has taken longer than [attachTimeout].
  ///
  /// Letting go is the whole point. The operation it is stuck in holds the
  /// plugin's per-device mutex, and `disconnect(queue: false)` is the one call
  /// that does not queue behind it; without that, the stall outlives every
  /// later attempt and the app needs the phone restarted to talk to the pack
  /// again. The attempt itself may still be waiting somewhere inside the
  /// plugin, so it is retired by number: whatever it does when it finally
  /// returns, [_attachId] has moved on and it touches nothing.
  void _abandonStalledAttach() {
    _attachDeadline = null;
    if (!_attaching) return;
    _attachId++;
    _attaching = false;
    final device = _device;
    final detail = 'connect attempt gave up after ${attachTimeout.inSeconds} s '
        'without finishing; letting go of the link so the next one can start';
    _errorController.add(
      // Not packMute: that wording tells the rider the pack was connected and
      // sent nothing for twenty seconds despite being asked, and this attempt
      // never got far enough to ask. The generic kind carries the detail,
      // which is the true account.
      BleLinkError(
        detail,
        trouble: LinkTrouble(LinkTroubleKind.unknown, detail: detail),
      ),
    );
    if (device != null) unawaited(_letGo(device));
    if (!_wantConnection || _disposed) return;
    _backoff.recordFailure();
    _setState(BleLinkState.failed);
    _scheduleReconnect();
  }

  /// True when [disconnect] was called while an attach was in flight. Gives
  /// back whatever the attach had gained since, so the pack is free for the
  /// next attempt instead of held by a link nobody is listening to.
  Future<bool> _abandonedMidway(BluetoothDevice device, int id) async {
    // Superseded rather than abandoned: the deadline already let go of this
    // device and a later attempt owns everything below. Touching any of it
    // from here would tear down a link that is being built, so this one just
    // stops.
    if (id != _attachId) return true;
    if (_wantConnection && !_disposed) return false;
    _pollTimer?.cancel();
    await _notifySub?.cancel();
    _notifySub = null;
    _characteristic = null;
    await _letGo(device);
    _setState(BleLinkState.idle);
    return true;
  }

  /// Gives the device back to the phone, jumping the operation queue.
  ///
  /// `queue: false` is the whole reason this is not just `device.disconnect()`.
  /// By default the plugin queues a disconnect behind the other operations for
  /// that device, and the operation it would be queued behind is exactly the
  /// one that hung: a service discovery or a notify subscription on a link
  /// that is half dead. The disconnect then never runs, the plugin never gets
  /// its disconnect callback, and it never closes the GATT client -- which its
  /// own source warns will "quickly run out of bluetooth resources, preventing
  /// new connections", for every app on the phone. That is the state a reboot
  /// was clearing. Skipping the queue is what the plugin documents this flag
  /// for: cancelling an attempt in progress.
  Future<void> _letGo(BluetoothDevice device) async {
    try {
      await device.disconnect(queue: false);
    } on Exception catch (_) {
      // Already gone, which was the point.
    }
  }

  /// Whether the phone itself already holds a connection to this device.
  ///
  /// Android lists connections that belong to no app this one can see: another
  /// app's, or one stranded by an attempt that never got its disconnect
  /// callback. Either way the pack's single connection is taken and nothing
  /// attempted from here will get it, so it is worth saying rather than
  /// letting the rider tap into an exhausted stack. Only meaningful before
  /// connecting: once this app is connected it is in the list itself.
  Future<bool> heldBySystem(String deviceId) async {
    try {
      final held = await FlutterBluePlus.systemDevices([
        Guid(jkServiceUuid16.toRadixString(16).padLeft(4, '0')),
      ]);
      return held.any((d) => d.remoteId.str == deviceId);
    } on Object catch (_) {
      // Could not ask. Inventing a diagnosis would be worse than no answer.
      return false;
    }
  }

  Future<BluetoothCharacteristic> _findCharacteristic(
    BluetoothDevice device,
  ) async {
    final services = await device.discoverServices();
    for (final service in services) {
      if (!service.uuid.str.toLowerCase().contains('ffe0')) continue;
      for (final c in service.characteristics) {
        if (!c.uuid.str.toLowerCase().contains('ffe1')) continue;
        // Newer BLE modules expose 0xFFE1 twice: one write-only, one notify.
        // We need the one that can notify.
        if (c.properties.notify || c.properties.indicate) return c;
      }
    }
    throw NotAJkBmsException(
      'This device does not expose a notifying $jkCharacteristicUuid16 '
      'characteristic on service $jkServiceUuid16, so it is not a JK BMS '
      'this app can talk to.',
    );
  }

  /// Classifies a failed connection.
  ///
  /// This used to read GATT 133 as proof that another client held the link,
  /// and tell the rider to close the official app. It is not proof: 133 is
  /// Android's catch-all and it comes back just as readily from a pack that is
  /// out of range or switched off, which is the far more common case on a bike
  /// somebody has walked away from. The wording now names both causes instead
  /// of picking the wrong one confidently.
  BleLinkError _describeConnectFailure(Object e) => BleLinkError.from(e);

  void _onDropped() {
    // Once per drop. A mute-link reset reports the drop itself and the
    // connection-state stream reports it again a moment later.
    if (_currentState == BleLinkState.reconnecting) return;
    // Nothing is retrying, so a disconnect changes nothing: the link the
    // giving-up let go of reports itself gone a moment later, and counting
    // that as a fresh drop would restate a decision already made.
    if (_backoff.hasGivenUp) return;
    drops++;
    // Forgotten on a drop, so the first check after reconnecting nudges rather
    // than trusting a timestamp from before the link went away.
    _lastCellInfoAt = null;
    _connectedAt = null;
    _droppedAt ??= DateTime.now();
    _pollTimer?.cancel();
    _notifySub?.cancel();
    _notifySub = null;
    _characteristic = null;
    _setState(BleLinkState.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_wantConnection || _disposed) return;
    _reconnectTimer?.cancel();
    // The mute-link reset names a pause and knows why 400 ms is too quick for
    // it. That is a floor, not a bypass. It used to replace the backoff's
    // answer outright, and since the reset never counted a failure either, a
    // pack that connected and stayed silent was let go and reconnected every
    // twenty-three seconds for as long as the app was open -- the one case the
    // brake was added for, and the only one it could not see.
    final delay = _backoff.nextDelayAtLeast(_nextReconnectDelay);
    _nextReconnectDelay = null;
    if (delay == null) {
      _giveUp();
      return;
    }
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (_wantConnection && !_disposed) _attach();
    });
  }

  /// Stops retrying and says so, rather than hammering a stack that has run
  /// out of the resources these attempts consume.
  ///
  /// The state stays [BleLinkState.failed] from here: nothing starts again on
  /// its own, and the screen offers [retryNow] instead of a spinner that will
  /// never resolve. That spinner was the rider's other complaint — the app
  /// gave no sign the reconnect had failed, and the reason only turned up on
  /// the connect screen.
  void _giveUp() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pollTimer?.cancel();
    // Nothing is going to use this link again until the rider asks, so it is
    // not ours to hold. Holding it is worse than useless: the pack takes one
    // connection at a time, so a link kept by an app that has stopped trying
    // is a link the next attempt -- from here, or from the official app --
    // cannot have. [_device] stays, because [retryNow] needs it.
    final device = _device;
    if (device != null) unawaited(_letGo(device));
    _setState(BleLinkState.failed);
  }

  /// One more go, because the rider asked. Clears the ledger first: walking
  /// back to the bike or restarting Bluetooth is what makes the next attempt
  /// worth trying, and it is not the app's place to know which happened.
  @override
  set persistRetries(bool value) {
    if (_backoff.persist == value) return;
    _backoff.persist = value;
    // Turning it on while the loop had already stopped has to restart it:
    // the ride began after the give-up, and the whole point is that a ride in
    // progress outranks the decision to stop.
    if (value && _wantConnection && !_disposed) _scheduleReconnect();
  }

  @override
  Future<void> retryNow() async {
    if (_device == null || _disposed) return;
    _wantConnection = true;
    _backoff.forgive();
    _scheduleReconnect();
  }

  /// Lets go of a link that is up and has said nothing for [muteBefore].
  ///
  /// Counted as a drop, because from the rider's side that is what it was: no
  /// readings for that long, followed by a reconnect. [_onDropped] is called
  /// here rather than left to the connection-state stream, so a disconnect the
  /// stack fails to report cannot leave the link down for good.
  Future<void> _resetMuteLink() async {
    final device = _device;
    if (device == null || !_wantConnection) return;
    _nextReconnectDelay = muteRetryDelay;
    // A link that came up and never spoke is a failed attempt, whatever
    // Android thought of it. Counting it is what lets the loop end: a mute
    // that clears reports a byte and wipes the ledger, and one that does not
    // keeps counting until the app stops and says so.
    _backoff.recordFailure();
    _pollTimer?.cancel();

    // Said before it is done, so the screen can name the reason while the
    // link is being re-established rather than showing a bare "lost".
    final now = DateTime.now();
    final since = _lastCellInfoAt ?? _connectedAt ?? now;
    final detail = 'connected, ${now.difference(since).inSeconds} s without a '
        'byte, $_nudgesThisLink nudge(s) unanswered, MTU ${negotiatedMtu ?? '?'}; '
        'letting go, back in ${muteRetryDelay.inSeconds} s';
    _errorController.add(
      BleLinkError(
        detail,
        trouble: LinkTrouble(LinkTroubleKind.packMute, detail: detail),
      ),
    );

    await _letGo(device);
    if (_wantConnection) _onDropped();
  }

  /// Asks the BMS for a device info frame (record type 0x03).
  Future<void> requestDeviceInfo() => _writeCommand(commandDeviceInfo);

  /// Asks the BMS for a cell info frame (record type 0x02).
  Future<void> requestCellInfo() => _writeCommand(commandCellInfo);

  /// Asks again, but only if the pack has actually stopped talking. Gives up
  /// on the link altogether once it has been mute for [muteBefore].
  Future<void> _nudgeIfQuiet() async {
    final now = DateTime.now();
    final lastSign = _lastCellInfoAt ?? _connectedAt;
    if (lastSign != null && now.difference(lastSign) > muteBefore) {
      await _resetMuteLink();
      return;
    }
    if (!shouldNudge(
      lastHeardAt: _lastCellInfoAt,
      now: now,
      quietBefore: quietBefore,
    )) {
      return;
    }
    nudges++;
    _nudgesThisLink++;
    await requestCellInfo();
  }

  /// Builds and sends a read command.
  ///
  /// This is the only place the app ever writes to the BMS, and it only ever
  /// writes read requests. Writing settings is out of scope: the protocol is
  /// reverse-engineered, and a wrong value can disable a protection.
  ///
  /// Frame layout source: `build_frame()` in
  /// https://github.com/syssi/esphome-jk-bms/blob/main/components/jk_bms_ble/jk_bms_ble.cpp
  Future<void> _writeCommand(int register) async {
    final c = _characteristic;
    if (c == null) return;

    final frame = List<int>.filled(commandFrameSize, 0);
    frame.setRange(0, 4, commandPreamble);
    frame[4] = register; // holding register
    frame[5] = 0x00; // value length in bytes; 0 for a read
    // Bytes 6..9 carry the value, which stays zero for a read.
    var sum = 0;
    for (var i = 0; i < commandFrameSize - 1; i++) {
      sum = (sum + frame[i]) & 0xFF;
    }
    frame[commandFrameSize - 1] = sum;

    try {
      await c.write(frame, withoutResponse: c.properties.writeWithoutResponse);
    } on Exception catch (e) {
      _errorController.add(BleLinkError.from(e));
    }
  }

  @override
  Future<void> disconnect() async {
    _wantConnection = false;
    _pollTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _nextReconnectDelay = null;
    // Retires the attempt in flight along with everything else, so a rider who
    // taps disconnect and then connect again is not refused by a flag left
    // standing by the attempt they just cancelled.
    _attachDeadline?.cancel();
    _attachDeadline = null;
    _attachId++;
    _attaching = false;
    // A pack the rider let go of starts the next connection from nothing,
    // rather than inheriting the failures of the one before it.
    _backoff.forgive();
    await _notifySub?.cancel();
    await _connectionSub?.cancel();
    _notifySub = null;
    _connectionSub = null;
    _characteristic = null;
    final device = _device;
    // Same reasoning as _letGo: a teardown that queues behind a hung
    // operation is a teardown that never happens, and a link nobody can close.
    if (device != null) await _letGo(device);
    _setState(BleLinkState.idle);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _stateController.close();
    await _bytesController.close();
    await _errorController.close();
  }

  void _setState(BleLinkState s) {
    _currentState = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }
}
