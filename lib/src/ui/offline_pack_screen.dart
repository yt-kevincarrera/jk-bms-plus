import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../bms_service.dart';
import '../data/database.dart';
import '../metrics/range_estimator.dart';
import 'theme.dart';
import 'trends_screen.dart';
import 'widgets/common.dart';

/// What is known about one battery without talking to it.
///
/// The app used to be useless with the bike out of reach: months of stored
/// readings existed and nothing could open them, because every screen hung off
/// the live snapshot stream. But the whole point of storing history is that it
/// outlives the connection — checking how a pack has been doing while sitting
/// on the sofa is the normal case, not an edge case.
///
/// Everything here is read from disk. Nothing on this screen needs the radio,
/// and it says so at the top so no figure is mistaken for a live one.
class OfflinePackScreen extends StatefulWidget {
  const OfflinePackScreen({
    required this.service,
    required this.device,
    super.key,
  });

  final BmsService service;
  final Device device;

  @override
  State<OfflinePackScreen> createState() => _OfflinePackScreenState();
}

class _OfflinePackScreenState extends State<OfflinePackScreen> {
  bool _loading = true;
  Snapshot? _last;
  List<Trip> _trips = const [];
  List<CapacityTest> _tests = const [];
  double? _rangeKm;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = widget.service.repository;
    if (repo == null) {
      setState(() => _loading = false);
      return;
    }

    final id = widget.device.id;
    final readings = await repo.allSnapshots(id, days: 3650);
    final trips = await repo.db.recentTrips(id, limit: 500);
    final tests = await repo.capacityTests(id);

    // The range is rebuilt from this pack's own rides rather than read off the
    // live service, which knows only about whatever is connected.
    final estimator = RangeEstimator();
    for (final t in trips.where(
      (t) => t.distanceKm >= 0.2 && t.energyOutWh > t.energyInWh,
    )) {
      estimator.addSegment(
        wh: t.energyOutWh - t.energyInWh,
        km: t.distanceKm,
      );
    }

    // Quoted from a full pack, using this pack's stated capacity when there is
    // one. With none, there is no usable-energy figure to divide, so the range
    // stays unknown rather than being invented from a nominal voltage.
    final catalogue = widget.device.catalogueCapacityAh;
    final usableWh = catalogue == null || readings.isEmpty
        ? null
        : catalogue * readings.last.packVoltage;

    if (!mounted) return;
    setState(() {
      _loading = false;
      _last = readings.isEmpty ? null : readings.last;
      _trips = trips;
      _tests = tests;
      _rangeKm = estimator.hasLearned && usableWh != null
          ? estimator.rangeKm(usableWh)
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final d = widget.device;
    final name = d.name.isEmpty ? d.id : d.name;

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              color: AppTheme.surfaceRaised,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                t.offlineBanner,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: AppTheme.textFaint,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 28),
                      children: _body(t),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(AppL10n t) {
    final last = _last;
    final totalKm = _trips.fold<double>(0, (a, b) => a + b.distanceKm);
    final completed = _tests.where((x) => x.completed).toList();

    return [
      Section(
        title: t.offlineTitle,
        children: [
          if (last == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                t.offlineNoData,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: AppTheme.textFaint,
                ),
              ),
            )
          else ...[
            InfoRow(t.offlineLastReading, _ago(t, last.timestamp)),
            InfoRow(
              t.offlineStateOfCharge,
              '${last.soc.toStringAsFixed(0)} %  ·  '
              '${last.packVoltage.toStringAsFixed(1)} V',
            ),
            InfoRow(
              t.healthCardCapacity,
              '${last.remainingAh.toStringAsFixed(1)} Ah',
            ),
            InfoRow(
              t.cellDelta,
              '${last.deltaVolts.toStringAsFixed(3)} V',
              valueColor: last.deltaVolts > 0.04 ? AppTheme.watch : null,
            ),
          ],
          InfoRow(
            t.settingsCatalogue,
            widget.device.catalogueCapacityAh == null
                ? t.catalogueUnset
                : '${widget.device.catalogueCapacityAh!.toStringAsFixed(0)} Ah',
            dim: widget.device.catalogueCapacityAh == null,
            valueColor: widget.device.catalogueCapacityAh == null
                ? AppTheme.watch
                : null,
            last: true,
          ),
        ],
      ),
      Section(
        title: t.offlineTrips,
        children: [
          InfoRow(t.offlineTrips, t.offlineTripsCount('${_trips.length}')),
          InfoRow(
            t.offlineTotalKm,
            '${totalKm.toStringAsFixed(1)} km',
          ),
          InfoRow(
            t.offlineRange,
            _rangeKm == null
                ? t.offlineRangeUnknown
                : '${_rangeKm!.toStringAsFixed(0)} km',
            dim: _rangeKm == null,
            last: completed.isEmpty,
          ),
          if (completed.isNotEmpty) ...[
            const SizedBox(height: 8),
            Caption(t.capacityHistory, color: AppTheme.textFaint),
            const SizedBox(height: 4),
            for (final test in completed.take(5))
              InfoRow(
                _date(test.endedAt ?? test.startedAt),
                test.catalogueAh == null
                    ? '${test.measuredAh.toStringAsFixed(1)} Ah'
                    : '${test.measuredAh.toStringAsFixed(1)} Ah  ·  '
                        '${(test.measuredAh / test.catalogueAh! * 100).toStringAsFixed(0)} %',
                last: test == completed.last,
              ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TrendsScreen(service: widget.service),
              ),
            ),
            icon: const Icon(Icons.show_chart, size: 18),
            label: Text(t.trendsTitle),
          ),
          const SizedBox(height: 6),
        ],
      ),
    ];
  }

  /// How long ago, in words, because "hace 3 días" answers the question that
  /// a timestamp only implies.
  String _ago(AppL10n t, DateTime utc) {
    final gap = DateTime.now().toUtc().difference(utc);
    if (gap.inMinutes < 60) {
      return '${t.agoPrefix} ${gap.inMinutes} min ${t.agoSuffix}'.trim();
    }
    if (gap.inHours < 48) {
      return '${t.agoPrefix} ${gap.inHours} h ${t.agoSuffix}'.trim();
    }
    return _date(utc);
  }

  static String _date(DateTime utc) {
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}
