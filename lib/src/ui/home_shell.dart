import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../ble/ble_transport.dart';
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

  @override
  void initState() {
    super.initState();
    _snapshot = widget.service.lastSnapshot;
    _link = widget.service.lastLinkState;
    _subs.addAll([
      widget.service.snapshots.listen((s) {
        if (mounted) setState(() => _snapshot = s);
      }),
      widget.service.linkState.listen((s) {
        if (mounted) setState(() => _link = s);
      }),
    ]);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final service = widget.service;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceName),
        bottom: service.isDemo
            ? PreferredSize(
                preferredSize: const Size.fromHeight(22),
                child: _DemoBanner(text: t.demoBanner),
              )
            : null,
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
            HistoryTab(service: service),
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
