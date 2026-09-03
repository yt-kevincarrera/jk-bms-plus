import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';

import '../../l10n/app_localizations.dart';
import '../ble/ble_transport.dart';
import '../ble/first_contact.dart';
import '../app_settings.dart';
import '../ble/proximity_watcher.dart';
import '../ble/simulator/simulated_pack.dart';
import '../bms_service.dart';
import 'home_shell.dart';
import 'locale_controller.dart';
import 'theme.dart';
import 'widgets/link_trouble_text.dart';
import '../data/database.dart';
import 'app_settings_screen.dart';
import 'offline_pack_screen.dart';
import 'widgets/common.dart';
import '../update/update_service.dart';

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
  String? _message;
  bool _busyMessage = false;

  /// Whether a link error was shown during the attempt in progress. When the
  /// link never comes up, that error is the explanation and the verdict must
  /// not paper over it.
  bool _troubleDuringAttempt = false;

  /// Set while a failed attempt is being torn down. A connect cancelled midway
  /// complains on its way out, and that complaint is not news.
  bool _settling = false;

  /// The raw exception behind [_message], when there was one.
  ///
  /// Kept separate so the screen can lead with a sentence and still hand over
  /// the original text on request. It used to be the message.
  String _messageDetail = '';

  @override
  void initState() {
    super.initState();
    // When the watcher spots the bike, walk straight in. This is the whole
    // point of the feature: get on, ride, and the app is already recording.
    _foundSub = widget.proximity.found.listen((device) {
      if (!mounted || _connecting) return;
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

    _loadStored();
    unawaited(_checkForUpdateQuietly());

    // Scanning is what anybody opens this screen to do, so it starts on its
    // own. The button below becomes a retry rather than the way in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startScan();
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _errorSub?.cancel();
    _foundSub?.cancel();
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
                  Text(
                    t.storedTitle,
                    style: const TextStyle(fontSize: 15),
                  ),
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
              child: Text(
                label,
                style: const TextStyle(fontSize: 15),
              ),
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

  Widget _deviceTile(AppL10n t, DiscoveredBms d, {required bool likely}) =>
      ListTile(
        leading: Icon(
          likely ? Icons.battery_charging_full : Icons.bluetooth,
          color: likely ? AppTheme.good : AppTheme.textFaint,
        ),
        title: Text(
          d.name.isEmpty ? d.id : d.name,
          style: TextStyle(color: likely ? null : AppTheme.textSecondary),
        ),
        subtitle: Text(
          d.advertisesJkService
              ? '${d.id}   ${d.rssi} dBm  ·  ${t.connectByService}'
              : '${d.id}   ${d.rssi} dBm',
          style: const TextStyle(fontSize: 11.5),
        ),
        trailing: Pill('${d.rssi}', color: _rssiColour(d.rssi)),
        onTap: () => _connect(d),
      );

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

    unawaited(widget.service.connect(device.id, name: device.name));

    final outcome = await _awaitVerdict(contact);
    for (final sub in subs) {
      await sub.cancel();
    }

    if (outcome != FirstContactOutcome.proven) {
      _settling = true;
      await widget.service.disconnect();
      _settling = false;
      _connecting = false;
      if (mounted) {
        final t = t0(context);
        // What the app saw, under "details": the headline says what happened,
        // this is the evidence, so a screenshot settles which failure it was.
        final evidence = '${contact.evidence(DateTime.now())} · MTU '
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
              _message =
                  device.likelyBms ? t.connectSilentJk : t.connectNotABms;
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

    // Only now is it worth remembering: the proximity watcher exists to
    // reconnect to a BMS, and remembering whatever was tapped last would have
    // it chasing a speaker.
    await widget.proximity.remember(device.id, device.name);
    if (mounted) {
      setState(() {
        _message = null;
        _messageDetail = '';
      });
    }

    await _openHome(device.name);
    await widget.service.disconnect();
    _connecting = false;
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
    await widget.service.enterDemoMode(scenario: DemoScenario.riding);
    await _openHome(t.demoPackName);
    await widget.service.exitDemoMode();
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
            onPressed: _openSettings,          ),
        ],
      ),
      body: SafeArea(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
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
          ),
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
                    icon: const Icon(
                      Icons.bluetooth_searching,
                      size: 19,
                    ),
                    label: Text(_searched ? t.connectRetry : t.connectScan),
                  ),
          ),
          // Demo is a way to look around with no hardware, not something a
          // rider with a bike outside wants competing with the scan button.
          // A quiet text link, and the paragraph explaining it moves into the
          // screen it opens.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextButton(
              onPressed: _startDemo,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textFaint,
                textStyle: const TextStyle(fontSize: 12.5),
              ),
              child: Text(t.connectDemoButton),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Color _rssiColour(int rssi) {
    if (rssi > -60) return AppTheme.good;
    if (rssi > -80) return AppTheme.watch;
    return AppTheme.bad;
  }
}
