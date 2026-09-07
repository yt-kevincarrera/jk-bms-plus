import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';

import '../../l10n/app_localizations.dart';
import '../ble/ble_transport.dart';
import '../ble/connect_guard.dart';
import '../ble/first_contact.dart';
import '../app_settings.dart';
import '../ble/proximity_watcher.dart';
import '../ble/simulator/simulated_pack.dart';
import '../bms_service.dart';
import '../model/bms_snapshot.dart';
import 'home_shell.dart';
import 'locale_controller.dart';
import 'theme.dart';
import 'widgets/link_trouble_text.dart';
import '../data/database.dart';
import 'app_settings_screen.dart';
import 'offline_pack_screen.dart';
import 'widgets/common.dart';
import '../update/update_service.dart';
import '../license/entitlements.dart';
import 'inspection/inspection_screen.dart';
import 'license_scope.dart';
import 'widgets/pro_gate.dart';
import 'widgets/trip_summary_sheet.dart';
import 'widgets/trip_summary_view.dart';

/// Scan, pick a BMS, or open demo mode.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({
    required this.service,
    required this.localeController,
    required this.proximity,
    required this.settings,
    required this.updateService,
    super.key,
  });

  final BmsService service;
  final LocaleController localeController;
  final ProximityWatcher proximity;
  final AppSettings settings;
  final UpdateService updateService;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  StreamSubscription<List<DiscoveredBms>>? _scanSub;
  StreamSubscription<BleLinkError>? _errorSub;
  StreamSubscription<DiscoveredBms>? _foundSub;
  bool _connecting = false;
  List<DiscoveredBms> _devices = const [];
  bool _scanning = false;

  /// Whether a scan has been run and finished. Distinguishes "you have not
  /// looked yet" from "we looked and found nothing", which need different
  /// things said to them.
  bool _searched = false;

  /// Packs already on record, so their history is reachable with nothing
  /// connected.
  List<Device> _stored = const [];

  /// Whether the update dialog has already been offered this launch.
  bool _offeredUpdate = false;

  /// Whether the pocket-ride summary has already been offered this launch.
  ///
  /// A rebuild must not be able to reopen it: `build()` can run any number of
  /// times while the screen sits there, and only the callback that first
  /// learns the active pack should ever get to ask.
  bool _offeredPendingSummary = false;
  String? _message;
  bool _busyMessage = false;

  /// Whether a link error was shown during the attempt in progress. When the
  /// link never comes up, that error is the explanation and the verdict must
  /// not paper over it.
  bool _troubleDuringAttempt = false;

  /// Set while a failed attempt is being torn down. A connect cancelled midway
  /// complains on its way out, and that complaint is not news.
  bool _settling = false;

  /// Decides whether a tap becomes an attempt at all. Every cancelled attempt
  /// risks leaving a connection Android will not close, and those run out for
  /// the whole phone, so tapping repeatedly is the one thing that must not be
  /// free.
  final ConnectGuard _guard = ConnectGuard();

  /// Redraws the cooldown countdowns. Nothing else changes while a pack is
  /// waiting out its pause, so nothing else would repaint it.
  Timer? _cooldownTick;

  /// The pack this app is connected to right now, or null. Kept in state so
  /// the card at the top of the screen follows a disconnect that happened
  /// anywhere else.
  Device? _connected;

  /// The last reading, for the connected card to show a charge level rather
  /// than only a name.
  BmsSnapshot? _liveSnapshot;

  StreamSubscription<Device?>? _deviceSub;
  StreamSubscription<BmsSnapshot>? _liveSub;

  /// The raw exception behind [_message], when there was one.
  ///
  /// Kept separate so the screen can lead with a sentence and still hand over
  /// the original text on request. It used to be the message.
  String _messageDetail = '';

  /// How many times each pack in the list has been inspected before.
  ///
  /// Loaded when inspection mode is entered. A pack already on record is
  /// worth marking: the second run on the same battery is what turns a
  /// reading into a finding, and the rider has to be able to find it again in
  /// a list of addresses that all look alike.
  Map<String, int> _inspectedBefore = const {};

  /// Whether the next connection is a look at somebody else's pack.
  ///
  /// In this mode the pack tapped is never adopted: nothing about it reaches
  /// the rider's history, the proximity watcher is not told to look for it,
  /// and the screens that open are the guided quick test, not the live tabs.
  /// The mode ends by itself once one inspection has finished, so a rider who
  /// forgets they were in it cannot connect to their own bike as a stranger.
  bool _inspecting = false;

  @override
  void initState() {
    super.initState();
    // When the watcher spots the bike, walk straight in. This is the whole
    // point of the feature: get on, ride, and the app is already recording.
    _foundSub = widget.proximity.found.listen((device) {
      // Not while inspecting: the watcher exists to find the rider's own
      // bike, and that is the one pack the quick test must never be run on
      // by accident.
      //
      // And not while a pack is already connected. The link outlives this
      // screen now, so the watcher spotting the bike again while the app is
      // holding a working link would tear it down to rebuild it -- the one
      // sequence this whole change exists to stop.
      if (!mounted || _connecting || _inspecting || _connected != null) return;
      _connecting = true;
      _connect(device);
    });

    _errorSub = widget.service.linkErrors.listen((e) {
      if (mounted && !_settling) {
        setState(() {
          final trouble = e.trouble;
          // A smaller packet size is a note about speed, not a failure worth
          // colouring red on the screen somebody is trying to connect from.
          if (trouble != null && !trouble.isNoteworthy) return;
          if (_connecting) _troubleDuringAttempt = true;
          _message = trouble == null
              ? e.message
              : linkTroubleWording(AppL10n.of(context), trouble);
          _messageDetail = trouble?.detail ?? '';
          _busyMessage = e.likelyBusy;
        });
      }
    });

    _connected = widget.service.activeDevice;
    _liveSnapshot = widget.service.lastSnapshot;
    _deviceSub = widget.service.deviceStream.listen((d) {
      if (!mounted) return;
      setState(() => _connected = d);
      // This stream only fires from `_activate`, after a decoded frame has
      // promoted the pack from pending to active -- connect() alone never
      // reaches it. Offering earlier, on the connect attempt itself, would
      // read a null device and silently never offer anything, which is the
      // exact bug an earlier task in this plan had to fix for this same
      // screen.
      if (d != null) unawaited(_offerPendingSummary());
    });
    _liveSub = widget.service.snapshots.listen((s) {
      if (mounted) setState(() => _liveSnapshot = s);
    });

    // One second is enough for a countdown and cheap enough to leave running
    // only while there is a countdown to draw.
    //
    // The tick after the last one ends has to redraw as well. Repainting only
    // while something was still counting down meant the frame showing "1 s"
    // was the last one ever painted: the countdown reached zero and the tile
    // kept the greyed-out look it had a second earlier.
    _cooldownTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final cooling = _anyCooling();
      if (cooling || _wasCooling) setState(() {});
      _wasCooling = cooling;
    });

    _loadStored();
    unawaited(_checkForUpdateQuietly());

    // Scanning is what anybody opens this screen to do, so it starts on its
    // own. The button below becomes a retry rather than the way in.
    //
    // Not while a pack is connected, though. Scanning competes with the link
    // for the same radio, and Android throttles an app that scans repeatedly
    // by silently returning nothing -- so a scan here would risk the
    // connection and poison the next real search. Coming back from the pack
    // screens lands on the connected card instead, which is the thing worth
    // seeing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.service.activeDevice == null) {
        _startScan();
      } else {
        // The pack was already active before this screen existed -- this
        // instance's own deviceStream subscription started too late to see
        // that promotion go by, so it would otherwise never get a chance to
        // ask.
        unawaited(_offerPendingSummary());
      }
    });
  }

  /// Whether a countdown was running at the previous tick, so the tick that
  /// ends the last one still gets a repaint.
  bool _wasCooling = false;

  /// Whether any pack is waiting out a cooldown, so the ticker knows whether
  /// there is anything to redraw.
  bool _anyCooling() {
    if (_guard.saturated) return false;
    final now = DateTime.now();
    for (final d in _devices) {
      if (_guard.cooldownLeft(deviceId: d.id, now: now) != null) return true;
    }
    return false;
  }

  @override
  void dispose() {
    _cooldownTick?.cancel();
    _scanSub?.cancel();
    _errorSub?.cancel();
    _foundSub?.cancel();
    _deviceSub?.cancel();
    _liveSub?.cancel();
    super.dispose();
  }

  /// Announces a new build as a dialog, once, when one is found.
  ///
  /// It was an inline banner and looked like part of the page. A dialog is
  /// what an announcement should be: it arrives, it is answered, it goes away.
  /// Still only after a check that happened at most once a day, still never
  /// downloading anything, and still dismissible for good.
  Future<void> _offerUpdate(AppL10n t) async {
    final check = widget.updateService.lastCheck;
    if (!mounted || check == null || !check.hasUpdate) return;

    final release = check.release!;
    final version = release.version.toString();
    if (widget.settings.dismissedUpdateVersion == version) return;

    // Once per launch. Answering "not now" and then having it reappear on the
    // next rebuild would make it an argument rather than a question.
    if (_offeredUpdate) return;
    _offeredUpdate = true;

    final notes = release.notes.trim();
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.system_update_alt, color: AppTheme.cool),
        title: Text(t.updateBannerTitle(version)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.updateDialogBody(
                  widget.updateService.currentVersion?.toString() ?? '--',
                  check.asset?.sizeMb.toStringAsFixed(1) ?? '--',
                ),
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  notes,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppTheme.textFaint,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.updateBannerDismiss),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.updateBannerAction),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (go ?? false) {
      await _openSettings();
    } else {
      // "Not now" is an answer about this version, not a snooze.
      await widget.settings.dismissUpdate(version);
    }
  }

  Future<void> _checkForUpdateQuietly() async {
    widget.updateService.token = widget.settings.updateToken;
    final found = await widget.updateService.checkQuietly(
      lastCheckedAt: widget.settings.lastUpdateCheck,
      interval: const Duration(hours: 24),
      onChecked: widget.settings.markUpdateChecked,
    );
    if (found && mounted) await _offerUpdate(AppL10n.of(context));
  }

  /// Offers the summary of a ride that ended with nobody watching.
  ///
  /// Once per launch, and only the latest unseen ride. The repository's
  /// `pendingSummaryTrip` and the [_offeredPendingSummary] guard split the
  /// work: the guard stops a second ask from this screen's own rebuilds, the
  /// query stops a queue of them from a week of unwatched rides.
  Future<void> _offerPendingSummary() async {
    if (_offeredPendingSummary) return;
    _offeredPendingSummary = true;

    final device = widget.service.activeDeviceId;
    final repo = widget.service.repository;
    if (device == null || repo == null) return;

    final trip = await repo.pendingSummaryTrip(device);
    if (trip == null || !mounted) return;

    final t = AppL10n.of(context);
    // Marked seen only after the sheet has actually run its course, not
    // before: showModalBottomSheet's future completes on every dismissal
    // path -- the button, the drag handle, tapping the scrim -- so this
    // still fires "whether or not the rider interacts with the sheet". The
    // other order, marking first, would lose the summary for good if the
    // sheet itself threw before ever reaching the screen; this order instead
    // leaves it unseen and offered again next launch, which is a rare extra
    // showing rather than a silent loss.
    await showTripSummarySheet(
      context: context,
      view: TripSummaryView.fromStored(trip),
      service: widget.service,
      t: t,
    );
    await widget.service.markTripSummarySeen(trip.id);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppSettingsScreen(
          service: widget.service,
          settings: widget.settings,
          localeController: widget.localeController,
          updateService: widget.updateService,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _loadStored() async {
    final devices = await widget.service.repository?.devices();
    if (mounted && devices != null) setState(() => _stored = devices);
  }

  /// The batteries already on record, openable with nothing connected.
  ///
  /// Sits above the scan results because most of the time you already know
  /// which pack you care about, and half the reasons to open this app -- how
  /// is it doing, how far does it go, what did the last rides cost -- need no
  /// radio at all.
  /// One row, not a list.
  ///
  /// Scanning is why this screen exists. The stored batteries are for the
  /// occasional "how is it doing" from the sofa, and a list of them was
  /// pushing the thing everybody actually came for down the screen.
  Widget _storedPacks(AppL10n t) {
    if (_stored.isEmpty) return const SizedBox.shrink();

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: const Icon(Icons.history, size: 20, color: AppTheme.textFaint),
      title: Text(
        t.storedTitle,
        style: const TextStyle(fontSize: 13.5, color: AppTheme.textSecondary),
      ),
      trailing: Text(
        t.storedCount('${_stored.length}'),
        style: const TextStyle(fontSize: 12, color: AppTheme.textFaint),
      ),
      onTap: () => _openStoredSheet(t),
    );
  }

  Future<void> _openStoredSheet(AppL10n t) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
              child: Row(
                children: [
                  Text(t.storedTitle, style: const TextStyle(fontSize: 15)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  t.storedManageHint,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: AppTheme.textFaint,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final d in _stored)
                    ListTile(
                      leading: Icon(
                        d.demo ? Icons.science_outlined : Icons.battery_full,
                        size: 20,
                        color: AppTheme.textSecondary,
                      ),
                      title: Text(
                        d.name.isEmpty ? d.id : d.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        t.storedLastSeen(_shortDate(d.lastSeenAt)),
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(this.context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => OfflinePackScreen(
                              service: widget.service,
                              device: d,
                            ),
                          ),
                        );
                      },
                      onLongPress: () {
                        Navigator.of(context).pop();
                        _managePack(t, d);
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    await _loadStored();
  }

  /// Rename or delete a stored battery, from the list itself.
  ///
  /// Deleting takes everything recorded on that pack with it, so it asks
  /// first and says what goes.
  Future<void> _managePack(AppL10n t, Device d) async {
    final label = d.name.isEmpty ? d.id : d.name;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(label, style: const TextStyle(fontSize: 15)),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(t.packsRename),
              onTap: () => Navigator.of(context).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.bad),
              title: Text(
                t.packsDelete,
                style: const TextStyle(color: AppTheme.bad),
              ),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    if (action == 'rename') {
      final controller = TextEditingController(text: d.name);
      final name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.packsRename),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: t.packsRenameHint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.packsCancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: Text(t.packsSave),
            ),
          ],
        ),
      );
      controller.dispose();
      if (name != null && name.isNotEmpty) {
        await widget.service.repository?.setDeviceName(d.id, name);
        await _loadStored();
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.packsDelete),
        content: Text(t.packsDeleteConfirm(label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.packsCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.bad),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.packsDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await widget.service.repository?.deleteDevice(d.id);
    await _loadStored();
  }

  static String _shortDate(DateTime utc) {
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  Future<void> _startScan() async {
    final t = AppL10n.of(context);
    // Searching again is the deliberate, slow action that follows the advice
    // to restart Bluetooth, so it is what lifts a saturation refusal. Without
    // this the advice was a dead end for a rider with nothing connected: no
    // Disconnect button to press, and every tap refused for the session.
    if (_guard.saturated) _guard.forgive();
    setState(() {
      _scanning = true;
      _searched = false;
      _message = null;
      _messageDetail = '';
      _devices = const [];
    });

    if (!await FlutterBluePlus.isSupported) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _message = t.connectNoBle;
        _messageDetail = '';
      });
      return;
    }

    // Not `.first`. At launch the adapter stream's first value is routinely
    // `unknown` or `turningOn`, and scanning on that either failed outright or
    // came back empty a moment later. Waiting for it to settle costs a second
    // at worst and is the difference between searching and pretending to.
    final adapterState = await FlutterBluePlus.adapterState
        .firstWhere(
          (s) =>
              s == BluetoothAdapterState.on ||
              s == BluetoothAdapterState.off ||
              s == BluetoothAdapterState.unauthorized ||
              s == BluetoothAdapterState.unavailable,
        )
        .timeout(
          const Duration(seconds: 6),
          onTimeout: () => BluetoothAdapterState.unknown,
        );
    if (adapterState != BluetoothAdapterState.on) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _message = t.connectBluetoothOff;
        _messageDetail = '';
      });
      return;
    }

    // Android ties BLE scanning to location being switched on, not just to the
    // permission being granted. With it off the scan succeeds and returns
    // nothing, which looks exactly like no BMS being present -- so this is
    // checked and named rather than left to be guessed at.
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _message = t.connectLocationOff;
        _messageDetail = '';
      });
      return;
    }

    // And the permission, not just the service. This app declares
    // BLUETOOTH_SCAN without `neverForLocation`, so Android 12+ will not
    // return a single scan result without it -- the scan reports success and
    // hands back nothing. Asked here, with a reason, rather than left to fail
    // silently.
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _message = t.connectLocationDenied;
        _messageDetail = '';
      });
      return;
    }

    await _scanSub?.cancel();
    // Reset per scan, not per screen: a failure from a previous attempt must
    // not suppress the result of this one.
    var couldNotSearch = false;
    _scanSub = widget.service.scan().listen(
      (devices) {
        if (mounted) setState(() => _devices = devices);
      },
      onError: (Object e) {
        if (e is! ScanNeverStarted) return;
        couldNotSearch = true;
        if (mounted) {
          setState(() {
            _message = t.connectCouldNotSearch;
            _messageDetail = '';
            _busyMessage = true;
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _scanning = false;
            // Only a scan that really ran gets to say the bike was not there.
            _searched = !couldNotSearch;
          });
        }
      },
    );
  }

  /// The scan results, with the likely ones first and everything else below.
  ///
  /// The "other devices" group is the whole point of the fix: a rider whose BMS
  /// does not announce itself as a JK can still see it and tap it, instead of
  /// being told nothing was found.
  Widget _deviceList(AppL10n t) {
    final likely = _devices.where((d) => d.likelyBms).toList();
    final others = _devices.where((d) => !d.likelyBms).toList();

    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: [
        for (final d in likely) _deviceTile(t, d, likely: true),
        if (others.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.connectOtherDevices.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.8,
                    color: AppTheme.textFaint,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.connectOtherDevicesHint,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: AppTheme.textFaint,
                  ),
                ),
              ],
            ),
          ),
          for (final d in others) _deviceTile(t, d, likely: false),
        ],
      ],
    );
  }

  Widget _deviceTile(AppL10n t, DiscoveredBms d, {required bool likely}) {
    final isConnected = _connected?.id == d.id;
    final cooling = _guard.cooldownLeft(deviceId: d.id, now: DateTime.now());

    // While inspecting, a pack already on record is the interesting one: the
    // second run on the same battery is what turns a reading into a finding,
    // and one address looks much like another in a list.
    final seenBefore = _inspecting ? (_inspectedBefore[d.id] ?? 0) : 0;

    final subtitle = switch (true) {
      _ when isConnected => t.tileConnected,
      _ when cooling != null => t.tileCooling('${cooling.inSeconds}'),
      _ when _guard.saturated => t.tileStackSaturated,
      _ when seenBefore > 0 =>
        '${d.id}   ${t.inspectionAlreadySeen('$seenBefore')}',
      _ when d.advertisesJkService =>
        '${d.id}   ${d.rssi} dBm  ·  ${t.connectByService}',
      _ => '${d.id}   ${d.rssi} dBm',
    };

    // Never disabled, whatever it is waiting for. It used to be, and that put
    // the rider's only way forward behind a repaint: miss the frame where the
    // countdown ends and the tile stays dead with no way to revive it. The
    // countdown is decoration now; [_onTap] is the gate, and it re-reads the
    // clock every time, so a stale drawing costs a sentence rather than a
    // stranded screen.
    return ListTile(
      leading: Icon(
        isConnected
            ? Icons.bluetooth_connected
            : likely
            ? Icons.battery_charging_full
            : Icons.bluetooth,
        color: isConnected
            ? AppTheme.good
            : likely
            ? AppTheme.good
            : AppTheme.textFaint,
      ),
      title: Text(
        d.name.isEmpty ? d.id : d.name,
        style: TextStyle(
          color: likely || isConnected ? null : AppTheme.textSecondary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11.5,
          color: isConnected
              ? AppTheme.good
              : cooling != null || _guard.saturated
              ? AppTheme.watch
              : null,
        ),
      ),
      trailing: isConnected
          ? Pill(t.tilePillOpen, color: AppTheme.good)
          : cooling != null
          ? Pill('${cooling.inSeconds} s', color: AppTheme.watch)
          : Pill('${d.rssi}', color: _rssiColour(d.rssi)),
      // Still tappable while cooling or saturated: the tap is refused with a
      // sentence saying why, which teaches more than a dead tile.
      onTap: () => _onTap(d),
    );
  }

  /// The pack this app is holding a link to, pinned above everything else.
  ///
  /// Its job is to answer the question the rider was left with: coming back
  /// from the pack screens used to land on a search list with no sign that
  /// anything was still connected, and the only apparent way back was to
  /// connect all over again.
  Widget _connectedCard(AppL10n t) {
    final device = _connected;
    if (device == null) return const SizedBox.shrink();
    final name = device.name.isEmpty ? device.id : device.name;
    final soc = _liveSnapshot?.soc;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: AppTheme.good.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.good.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bluetooth_connected,
                size: 17,
                color: AppTheme.good,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (soc != null)
                Pill('${soc.toStringAsFixed(0)} %', color: AppTheme.good),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            t.connectedCardNote,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _openHome(name),
                icon: const Icon(Icons.arrow_forward, size: 17),
                label: Text(t.connectedCardOpen),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: _disconnectByHand,
                icon: const Icon(Icons.link_off, size: 17),
                label: Text(t.connectedCardRelease),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Letting go, because the rider asked. The one explicit disconnect.
  ///
  /// It also clears the guard's ledger: a clean release is the opposite of the
  /// half-open links the failure count was counting, and the pack is free
  /// again straight away.
  Future<void> _disconnectByHand() async {
    await widget.service.disconnect();
    _guard.forgive();
    if (!mounted) return;
    setState(() {
      _message = null;
      _messageDetail = '';
      _liveSnapshot = null;
    });
    await _startScan();
  }

  /// Stops a scan the user started. Cancelling the subscription also stops the
  /// radio, so this genuinely ends the scan rather than just hiding it.
  Future<void> _cancelScan({String? message}) async {
    await _scanSub?.cancel();
    _scanSub = null;
    await FlutterBluePlus.stopScan();
    if (mounted) {
      setState(() {
        _scanning = false;
        if (message != null) _message = message;
      });
    }
  }

  /// The rider tapped a pack. Decides whether that becomes an attempt.
  ///
  /// The gate matters more than it looks. A tap that turns into a cancelled
  /// attempt can leave a connection the phone never reclaims, and those are
  /// shared across every app, so the way out of a bad patch is fewer attempts
  /// rather than more. Each refusal says which it is and what to do instead.
  Future<void> _onTap(DiscoveredBms device) async {
    final t = t0(context);

    // Already connected to this one: the tap means "take me back", not
    // "connect again". Reconnecting would drop a working link to rebuild it.
    if (_connected?.id == device.id && !_connecting) {
      await _openHome(device.name.isEmpty ? device.id : device.name);
      return;
    }

    final now = DateTime.now();
    switch (_guard.judge(deviceId: device.id, now: now, busy: _connecting)) {
      case TapVerdict.go:
        break;
      case TapVerdict.busy:
        setState(() {
          _message = t.tapBusy;
          _messageDetail = '';
          _busyMessage = true;
        });
        return;
      case TapVerdict.cooling:
        final left = _guard.cooldownLeft(deviceId: device.id, now: now);
        setState(() {
          _message = t.tapCooling('${left?.inSeconds ?? 0}');
          _messageDetail = '';
          _busyMessage = true;
        });
        return;
      case TapVerdict.saturated:
        setState(() {
          _message = t.tapStackSaturated('${_guard.consecutiveFailures}');
          _messageDetail = '';
          _busyMessage = true;
        });
        return;
    }

    // The phone's own list of open connections, asked before attempting. If
    // the pack is in it while this app holds nothing, its one connection
    // belongs to another app or to a link nothing can close, and no attempt
    // from here will win it.
    if (widget.service.activeDevice == null &&
        await widget.service.heldByPhone(device.id)) {
      if (!mounted) return;
      setState(() {
        _message = t.tapHeldByPhone;
        _messageDetail = '';
        _busyMessage = true;
      });
      return;
    }

    await _connect(device);
  }

  Future<void> _connect(DiscoveredBms device) async {
    await _cancelScan();
    _troubleDuringAttempt = false;
    if (mounted) {
      setState(() {
        _connecting = true;
        _message = t0(context).connectWaitingFirst;
        _messageDetail = '';
        _busyMessage = true;
      });
    }

    // Wait for proof that this is actually a BMS before opening anything.
    // Tapping a pair of headphones used to connect, open the live screens, and
    // sit on "waiting for the first reading" for as long as you let it: a
    // dead end with no way to tell a slow pack from the wrong device.
    //
    // The proof used to be a snapshot within fourteen seconds of the tap, and
    // anything else was called "almost certainly not a JK BMS". That verdict
    // landed on a real pack: fourteen seconds does not cover a failed connect
    // plus a retry, a snapshot needs device info to have named the protocol
    // variant first, and the screen then tore down a connect still in flight,
    // which left the pack held by a link nobody was listening to, so the next
    // tap found it mute too. [FirstContact] judges from what actually happened.
    final contact = FirstContact(
      startedAt: DateTime.now(),
      bytesBefore: widget.service.stats.bytesReceived,
    );
    final subs = <StreamSubscription<Object?>>[
      widget.service.linkState.listen(
        (state) => contact.onLinkState(state, DateTime.now()),
      ),
      widget.service.frameStats.listen(
        (stats) => contact.onBytesTotal(stats.bytesReceived),
      ),
      widget.service.deviceInfo.listen((_) => contact.onDecoded()),
      widget.service.snapshots.listen((_) => contact.onDecoded()),
    ];

    unawaited(
      widget.service.connect(
        device.id,
        name: device.name,
        inspecting: _inspecting,
      ),
    );

    final outcome = await _awaitVerdict(contact);
    for (final sub in subs) {
      await sub.cancel();
    }

    if (outcome != FirstContactOutcome.proven) {
      _guard.recordFailure(deviceId: device.id, at: DateTime.now());
      _settling = true;
      await widget.service.disconnect();
      _settling = false;
      _connecting = false;
      if (mounted) {
        final t = t0(context);
        // What the app saw, under "details": the headline says what happened,
        // this is the evidence, so a screenshot settles which failure it was.
        final evidence =
            '${contact.evidence(DateTime.now())} · MTU '
            '${widget.service.negotiatedMtu ?? '?'}';
        setState(() {
          switch (outcome) {
            case FirstContactOutcome.linkNeverCameUp:
              // The link error already on screen, when there was one, says
              // why. Only a silent failure needs words of its own.
              if (!_troubleDuringAttempt) {
                _message = t.connectLinkNeverCameUp;
                _messageDetail = evidence;
                _busyMessage = false;
              }
            case FirstContactOutcome.connectedButSilent:
              // A device that announces itself as JK and then says nothing is
              // a JK BMS with its attention elsewhere, not a pair of
              // headphones, and the advice is different.
              _message = device.likelyBms
                  ? t.connectSilentJk
                  : t.connectNotABms;
              _messageDetail = evidence;
              _busyMessage = false;
            case FirstContactOutcome.talkingButUndecoded:
              _message = t.connectTalkingUndecoded;
              _messageDetail = evidence;
              _busyMessage = false;
            case FirstContactOutcome.proven:
              break;
          }
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _message = null;
        _messageDetail = '';
      });
    }

    if (_inspecting) {
      // Somebody else's pack: nothing to remember, nothing to adopt. The
      // guided test runs, the verdict is shown, and the link is dropped.
      final again = await _openInspection(device.id, device.name);
      await widget.service.disconnect();
      _connecting = false;
      // Staying in the mode is the difference between one look and a second
      // opinion. The pack has to be tapped again because the link was just
      // dropped, and a fresh scan is what puts it back in the list.
      if (mounted) {
        setState(() => _inspecting = again);
        if (again) unawaited(_startScan());
      }
      return;
    }

    // A reading arrived, so every failure the guard was holding against this
    // pack, and against the phone, is disproved.
    _guard.recordSuccess(deviceId: device.id);

    // Only now is it worth remembering: the proximity watcher exists to
    // reconnect to a BMS, and remembering whatever was tapped last would have
    // it chasing a speaker.
    await widget.proximity.remember(device.id, device.name);

    _connecting = false;
    // The link belongs to the session, not to this screen. Coming back from
    // the pack screens used to tear it down, which meant the only way back in
    // was the whole connect sequence again -- the expensive, fragile part, and
    // the one that strands connections when it fails. Now going back lands on
    // the connected card, and letting go is something the rider asks for.
    await _openHome(device.name);
  }

  /// Asks the judge four times a second until it has a verdict.
  Future<FirstContactOutcome> _awaitVerdict(FirstContact contact) async {
    while (true) {
      final outcome = contact.judge(DateTime.now());
      if (outcome != null) return outcome;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  /// Localisations without needing them threaded through every helper.
  AppL10n t0(BuildContext context) => AppL10n.of(context);

  Future<void> _startDemo() async {
    final t = AppL10n.of(context);
    await _cancelScan();
    if (_inspecting) {
      // A rehearsal: the simulated pack plays a seller's battery with one
      // weak cell, so the rider can see the whole test once before doing it
      // in front of somebody.
      await widget.service.enterDemoMode(scenario: DemoScenario.inspection);
      final again = await _openInspection(
        BmsService.demoDeviceId,
        t.demoPackName,
      );
      await widget.service.exitDemoMode();
      if (mounted) setState(() => _inspecting = again);
      return;
    }
    await widget.service.enterDemoMode(scenario: DemoScenario.riding);
    await _openHome(t.demoPackName);
    await widget.service.exitDemoMode();
  }

  /// Switches the screen into inspection mode, if the licence allows it.
  ///
  /// With licensing switched off everything is allowed and this is just a
  /// toggle. With it on, a rider without credits is sent to the licence
  /// screen instead, and one with a finite number is told what the next
  /// inspection costs before they connect to anything.
  void _enterInspection() {
    final t = AppL10n.of(context);
    final controller = LicenseScope.of(context);
    final entitlements = controller.entitlements;
    if (!entitlements.allows(Feature.inspection)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.inspectionCreditsGone)));
      openLicenseScreen(context);
      return;
    }
    if (controller.enabled && !entitlements.isWorkshop) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.inspectionCreditsLeft('${entitlements.inspectionCreditsLeft}'),
          ),
        ),
      );
    }
    setState(() {
      _inspecting = true;
      _message = null;
      _messageDetail = '';
    });
    unawaited(_loadInspectedBefore());
  }

  Future<void> _loadInspectedBefore() async {
    final repo = widget.service.repository;
    if (repo == null) return;
    final counts = await repo.inspectionCountsByPack();
    if (mounted) setState(() => _inspectedBefore = counts);
  }

  /// Runs one guided test. True when the rider asked to run it again.
  Future<bool> _openInspection(String id, String name) async {
    if (!mounted) return false;
    final again = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            InspectionScreen(service: widget.service, bmsId: id, bmsName: name),
      ),
    );
    // What has been inspected has just changed, if the run was saved.
    // Reloading keeps the marks in the device list honest.
    unawaited(_loadInspectedBefore());
    return again ?? false;
  }

  Future<void> _openHome(String name) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HomeShell(
          service: widget.service,
          deviceName: name,
          localeController: widget.localeController,
          proximity: widget.proximity,
          settings: widget.settings,
          updateService: widget.updateService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.appTitle),
        actions: [
          IconButton(
            tooltip: t.appSettingsTitle,
            icon: const Icon(Icons.tune),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_inspecting) _inspectionBanner(t) else _oneConnectionNote(t),
            _connectedCard(t),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                child: LinkTroubleText(
                  message: _message!,
                  detail: _messageDetail,
                  color: _busyMessage ? AppTheme.watch : AppTheme.bad,
                ),
              ),
            // Always, not only when the scan came up empty. A battery you have
            // already used outranks whatever headphones happen to be in the
            // room, and opening its history needs no radio at all.
            _storedPacks(t),
            Expanded(
              child: _devices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_scanning) ...[
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.goodDim,
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          Text(
                            _scanning
                                ? t.connectScanning
                                : _searched
                                ? t.connectScanFinished
                                : t.connectNoDevices,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          // Only once the search has actually ended. While it is
                          // running there is nothing to explain yet, and the
                          // whole bug this replaced was a screen that could
                          // never reach this state at all.
                          if (!_scanning && _searched) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                t.connectSeenCount('${_devices.length}'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textFaint,
                                ),
                              ),
                            ),
                          ],
                          if (!_scanning && _searched)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                              child: Text(
                                t.connectNothingFoundHelp,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.5,
                                  color: AppTheme.textFaint,
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : _deviceList(t),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _scanning
                  ? OutlinedButton.icon(
                      // No message. Cancelling is something the rider chose to
                      // do, and reporting it in the same red banner the app uses
                      // for genuine failures makes a deliberate act look like
                      // something went wrong.
                      onPressed: _cancelScan,
                      icon: const Icon(Icons.stop_circle_outlined, size: 19),
                      label: Text(t.connectCancelScan),
                    )
                  : FilledButton.icon(
                      onPressed: _startScan,
                      icon: const Icon(Icons.bluetooth_searching, size: 19),
                      label: Text(_searched ? t.connectRetry : t.connectScan),
                    ),
            ),
            // Demo is a way to look around with no hardware, not something a
            // rider with a bike outside wants competing with the scan button.
            // A quiet text link, and the paragraph explaining it moves into the
            // screen it opens.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _connecting ? null : _startDemo,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textFaint,
                      textStyle: const TextStyle(fontSize: 12.5),
                    ),
                    child: Text(
                      _inspecting ? t.inspectionRehearse : t.connectDemoButton,
                    ),
                  ),
                  // Inspecting is something a buyer does a few times a year,
                  // so it sits beside the demo link rather than competing with
                  // the scan button the rider presses every day.
                  if (!_inspecting)
                    TextButton(
                      onPressed: _connecting ? null : _enterInspection,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textFaint,
                        textStyle: const TextStyle(fontSize: 12.5),
                      ),
                      child: Text(t.inspectionEntry),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _oneConnectionNote(AppL10n t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.hairline),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 17,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t.connectOneConnectionWarning,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  /// Replaces the one-connection note while inspecting. Same place, a
  /// different colour, so the mode is impossible to miss on the screen where
  /// the tap that matters happens.
  Widget _inspectionBanner(AppL10n t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Container(
      decoration: BoxDecoration(
        color: AppTheme.cool.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cool.withValues(alpha: 0.55)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fact_check_outlined,
                size: 18,
                color: AppTheme.cool,
              ),
              const SizedBox(width: 8),
              Text(
                t.inspectionModeTitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.cool,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            t.inspectionModeBanner,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppTheme.textSecondary,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _connecting
                  ? null
                  : () => setState(() => _inspecting = false),
              child: Text(t.inspectionModeExit),
            ),
          ),
        ],
      ),
    ),
  );

  Color _rssiColour(int rssi) {
    if (rssi > -60) return AppTheme.good;
    if (rssi > -80) return AppTheme.watch;
    return AppTheme.bad;
  }
}
