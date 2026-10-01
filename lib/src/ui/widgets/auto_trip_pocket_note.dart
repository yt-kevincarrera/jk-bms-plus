import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../l10n/app_localizations.dart';
import '../theme.dart';

/// What a ride starting by itself with the phone in a pocket depends on, said
/// under the auto-start switch, with the one thing the rider can do about it.
///
/// The switch used to promise rides would record themselves and say nothing
/// about the conditions, and with the phone in a pocket two of them decide
/// everything: the app must still be reading the pack with the screen off,
/// and Android must still be handing it positions. The second holds with
/// "while in use" only while the service the app started on screen is still
/// running; once Android stopped it, or the app reconnected by itself with
/// the screen off, only "allow all the time" lets the GPS answer.
class AutoTripPocketNote extends StatefulWidget {
  const AutoTripPocketNote({
    required this.linkWatchOn,
    this.checkPermission = Geolocator.checkPermission,
    this.requestPermission = Geolocator.requestPermission,
    this.openSettings = Geolocator.openAppSettings,
    super.key,
  });

  final bool linkWatchOn;
  final Future<LocationPermission> Function() checkPermission;
  final Future<LocationPermission> Function() requestPermission;
  final Future<bool> Function() openSettings;

  @override
  State<AutoTripPocketNote> createState() => _AutoTripPocketNoteState();
}

class _AutoTripPocketNoteState extends State<AutoTripPocketNote>
    with WidgetsBindingObserver {
  LocationPermission? _permission;
  bool _sentToSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Asked again on return from the system settings, which is where the
  /// answer is usually changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    LocationPermission? p;
    try {
      p = await widget.checkPermission();
    } on Object catch (_) {
      // No platform to ask: say nothing rather than guess.
      p = null;
    }
    if (mounted) setState(() => _permission = p);
  }

  Future<void> _askAlways() async {
    LocationPermission? p;
    try {
      // With "while in use" already granted, this is Android's request for
      // the background half.
      p = await widget.requestPermission();
    } on Object catch (_) {
      p = null;
    }
    if (p != LocationPermission.always) {
      // Android 11 and later answer that request with the settings page, or
      // not at all once it has been refused; the page is where it is set.
      try {
        await widget.openSettings();
        _sentToSettings = true;
      } on Object catch (_) {}
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    const style = TextStyle(
      fontSize: 11.5,
      height: 1.4,
      color: AppTheme.textFaint,
    );
    final p = _permission;
    final lines = <Widget>[];
    if (!widget.linkWatchOn) {
      lines.add(Text(t.autoTripPocketNeedsLinkWatch, style: style));
    }
    if (p == LocationPermission.always) {
      lines.add(Text(t.autoTripPocketAlways, style: style));
    } else if (p == LocationPermission.whileInUse) {
      lines
        ..add(Text(t.autoTripPocketWhileInUse, style: style))
        ..add(
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _askAlways,
              child: Text(t.autoTripPocketAllowAlways),
            ),
          ),
        );
      if (_sentToSettings) {
        lines.add(Text(t.autoTripPocketSettingsHint, style: style));
      }
    }
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines,
      ),
    );
  }
}
