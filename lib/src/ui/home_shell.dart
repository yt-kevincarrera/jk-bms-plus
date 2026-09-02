import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../ble/ble_transport.dart';
import '../ble/link_trouble.dart';
import '../app_settings.dart';
import '../ble/proximity_watcher.dart';
import '../bms_service.dart';
import '../model/bms_snapshot.dart';
import 'locale_controller.dart';
import 'tabs/cells_tab.dart';
import 'tabs/health_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/now_tab.dart';
import 'tabs/system_tab.dart';
import 'tabs/thermal_tab.dart';
import 'theme.dart';
import 'widgets/link_trouble_text.dart';
import '../update/update_service.dart';

/// The five tabs, all views of the same snapshot stream.
///
/// They live in an [IndexedStack] rather than a `TabBarView` on purpose: a
/// `TabBarView` disposes the pages you are not looking at, which throws away
/// scroll position and chart state on every switch and leaves the tab blank
/// until the next frame arrives.
class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.service,
    required this.deviceName,
    required this.localeController,
    required this.proximity,
    required this.settings,
    required this.updateService,
    super.key,
  });

  final BmsService service;
  final String deviceName;
  final LocaleController localeController;
  final ProximityWatcher proximity;
  final AppSettings settings;
  final UpdateService updateService;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  BmsSnapshot? _snapshot;
  late BleLinkState _link;
  final List<StreamSubscription<Object?>> _subs = [];

  /// The last trouble the link reported, so the banner can say what happened
  /// rather than only that something did.
  LinkTrouble? _trouble;

  /// When the last reading arrived, for the age line.
  DateTime? _lastReadingAt;

  /// Redraws the banner so the age keeps counting up on its own.
  Timer? _ageTick;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.service.lastSnapshot;
    _link = widget.service.lastLinkState;
    _subs.addAll([
      widget.service.snapshots.listen((s) {
        if (mounted) {
          setState(() {
            _snapshot = s;
            _lastReadingAt = DateTime.now();
            // A reading arriving is the only proof that matters. Whatever the
            // link last complained about is over.
            _trouble = null;
          });
        }
      }),
      widget.service.linkState.listen((s) {
        if (mounted) setState(() => _link = s);
      }),
      widget.service.linkErrors.listen((e) {
        final trouble = e.trouble;
        if (!mounted || trouble == null || !trouble.isNoteworthy) return;
        setState(() => _trouble = trouble);
      }),
    ]);

    // Once every two seconds while something is wrong. Cheap, and it is what
    // turns "the connection is gone" into "the connection is gone and it has
    // been four minutes", which is the part that says whether to go back.
    _ageTick = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && _link != BleLinkState.connected) setState(() {});
    });
  }

  @override
  void dispose() {
    _ageTick?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  /// The strip under the app bar, or nothing when all is well.
  PreferredSizeWidget? _appBarBottom(AppL10n t, BmsService service) {
    // The demo link never drops, and a warning about a simulated radio would
    // be a claim about a pack that does not exist.
    final down = !service.isDemo && _link != BleLinkState.connected;
    return _appBarBottomFor(
      demo: service.isDemo,
      demoText: t.demoBanner,
      linkBanner: down
          ? _LinkBanner(
              state: _link,
              trouble: _trouble,
              lastReadingAt: _lastReadingAt,
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final service = widget.service;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceName),
        bottom: _appBarBottom(t, service),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: [
            NowTab(
              service: service,
              snapshot: _snapshot,
              settings: widget.settings,
            ),
            CellsTab(service: service, snapshot: _snapshot),
            ThermalTab(service: service, snapshot: _snapshot),
            HealthTab(service: service, snapshot: _snapshot),
            HistoryTab(service: service, settings: widget.settings),
            SystemTab(
              service: service,
              snapshot: _snapshot,
              link: _link,
              localeController: widget.localeController,
              proximity: widget.proximity,
              settings: widget.settings,
              updateService: widget.updateService,
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.speed_outlined),
            selectedIcon: const Icon(Icons.speed),
            label: t.tabNow,
          ),
          NavigationDestination(
            icon: const Icon(Icons.grid_view_outlined),
            selectedIcon: const Icon(Icons.grid_view),
            label: t.tabCells,
          ),
          NavigationDestination(
            icon: const Icon(Icons.thermostat_outlined),
            selectedIcon: const Icon(Icons.thermostat),
            label: t.tabThermal,
          ),
          NavigationDestination(
            icon: const Icon(Icons.monitor_heart_outlined),
            selectedIcon: const Icon(Icons.monitor_heart),
            label: t.tabHealth,
          ),
          NavigationDestination(
            icon: const Icon(Icons.timeline_outlined),
            selectedIcon: const Icon(Icons.timeline),
            label: t.tabHistory,
          ),
          NavigationDestination(
            icon: const Icon(Icons.tune_outlined),
            selectedIcon: const Icon(Icons.tune),
            label: t.tabSystem,
          ),
        ],
      ),
    );
  }
}

/// The strip under the app bar: the demo notice, the link warning, or both.
///
/// A warning belongs here rather than on one tab, and it must never navigate
/// anywhere. Losing the link used to be silent until the rider left for the
/// scan screen, where a raw exception was waiting; being thrown off the page
/// you are reading because the bike went out of range is the other half of
/// that same mistake.
PreferredSizeWidget? _appBarBottomFor({
  required bool demo,
  required String demoText,
  required Widget? linkBanner,
}) {
  final bars = <Widget>[
    if (demo) _DemoBanner(text: demoText),
    ?linkBanner,
  ];
  if (bars.isEmpty) return null;
  const demoHeight = 22.0;
  const linkHeight = 62.0;
  return PreferredSize(
    preferredSize: Size.fromHeight(
      (demo ? demoHeight : 0) + (linkBanner != null ? linkHeight : 0),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: bars),
  );
}

/// Says the link is down, how long the reading on screen has been sitting
/// there, and why, without moving anybody off the page.
class _LinkBanner extends StatelessWidget {
  const _LinkBanner({
    required this.state,
    required this.trouble,
    required this.lastReadingAt,
  });

  final BleLinkState state;
  final LinkTrouble? trouble;
  final DateTime? lastReadingAt;

  String _age(AppL10n t) {
    final at = lastReadingAt;
    if (at == null) return '';
    final d = DateTime.now().difference(at);
    if (d.inSeconds < 60) return t.linkReadingAge('${d.inSeconds} s');
    if (d.inMinutes < 60) return t.linkReadingAge('${d.inMinutes} min');
    return t.linkReadingAge('${d.inHours} h');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final title = switch (state) {
      BleLinkState.reconnecting => t.linkReconnectingTitle,
      BleLinkState.connecting ||
      BleLinkState.negotiating =>
        t.linkConnectingTitle,
      _ => t.linkLostTitle,
    };
    final why =
        trouble == null ? t.linkLostBody : linkTroubleWording(t, trouble!);
    final age = _age(t);

    return Container(
      width: double.infinity,
      color: AppTheme.watch.withValues(alpha: 0.16),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: AppTheme.watch,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.watch,
                      ),
                    ),
                    if (age.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          age,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppTheme.textFaint,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  why,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.3,
                    color: AppTheme.textFaint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.cool.withValues(alpha: 0.16),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: AppTheme.cool,
        ),
      ),
    );
  }
}
