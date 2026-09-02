import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../bms_service.dart';
import '../data/database.dart';
import '../metrics/cell_drift.dart';
import '../metrics/degradation.dart';
import '../metrics/range_estimator.dart';
import '../metrics/range_outlook.dart';
import 'theme.dart';
import 'trends_screen.dart';
import 'widgets/common.dart';
import 'widgets/maintenance_card.dart';

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
  RangeOutlook _outlook = RangeOutlook.unknown;
  DateTime? _firstAt;
  int _readingCount = 0;
  CellDrift? _drift;
  List<CellDrift> _driftRanking = const [];

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

    // Before reading anything. The startup pass may still be running, and this
    // screen must not race it into showing "nothing learned yet" against rides
    // the app can measure. Idempotent, and finds nothing after the first pass.
    await repo.repairTripEnergy(id);

    // A bounded window. This used to ask for ten years of readings just to
    // find the last one and count them, which at 1 Hz is hundreds of thousands
    // of rows pulled into memory to answer two questions that are one SQL
    // query each. Six months is what the cell-drift analysis needs, and that
    // one genuinely needs the readings themselves.
    final readings = await repo.allSnapshots(id, days: 180);
    final totalReadings = await repo.db.snapshotCountFor(id);
    final oldest = await repo.db.firstSnapshotAt(id);
    final newest = await repo.db.lastSnapshotFor(id);
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

    // Both figures, built exactly as the live screen builds them. This screen
    // used to quote one range with a label that did not say which question it
    // answered, and it happened to be the full-pack one computed a third
    // different way. One definition now, in one place.
    final measured = _bestMeasured(tests);
    final capacity = measured ?? widget.device.catalogueCapacityAh;

    final cells = newest == null
        ? const <double>[]
        : decodeCellVoltages(newest.cellVoltagesJson);
    final averageCell = cells.isEmpty
        ? 0.0
        : cells.reduce((a, b) => a + b) / cells.length;
    // The pack's own cutoff is not stored with a reading, so the app's default
    // stands in. It is the same figure the live screen falls back to before the
    // settings frame arrives.
    const cutoffPerCell = 3.0;

    final usableFraction = newest == null || cells.isEmpty
        ? 1.0
        : RangeEstimator.usableFractionOf(
            minCellVoltage: newest.minCellVoltage,
            averageCellVoltage: averageCell,
            cutoffVoltagePerCell: cutoffPerCell,
          );

    final usableNow = newest == null || cells.isEmpty
        ? 0.0
        : RangeEstimator.usableWh(
            remainingAh: newest.remainingAh,
            packVoltage: newest.packVoltage,
            cellCount: cells.length,
            minCellVoltage: newest.minCellVoltage,
            averageCellVoltage: averageCell,
            cutoffVoltagePerCell: cutoffPerCell,
          );

    final outlook = RangeOutlook.from(
      estimator: estimator,
      usableWhNow: usableNow,
      fullCapacityAh: capacity,
      fullPackVoltage: cells.isEmpty ? null : cells.length * 3.7,
      usableFraction: usableFraction,
      capacityWasMeasured: measured != null,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _last = newest;
      _trips = trips;
      _tests = tests;
      _firstAt = oldest;
      _readingCount = totalReadings;
      _driftRanking = const CellDriftAnalysis().analyse(readings);
      _drift = _driftRanking.isNotEmpty && _driftRanking.first.isWorsening
          ? _driftRanking.first
          : null;
      _outlook = outlook;
    });
  }

  /// Whether the newest reading is old enough that anything derived from the
  /// charge in it should be read as history.
  ///
  /// Three days is generous. A pack ridden without the app open, or simply
  /// left standing, has moved on from whatever it read last.
  bool get _readingIsStale {
    final at = _last?.timestamp;
    if (at == null) return true;
    return DateTime.now().toUtc().difference(at.toUtc()) >
        const Duration(days: 3);
  }

  /// The best capacity this pack has ever measured, ignoring tests with a hole
  /// in the middle: those count low, and counting low here would understate
  /// the pack for good.
  static double? _bestMeasured(List<CapacityTest> tests) {
    double? best;
    for (final test in tests) {
      if (!test.completed || test.measuredAh <= 0) continue;
      if (test.gapSeconds > 120) continue;
      if (best == null || test.measuredAh > best) best = test.measuredAh;
    }
    return best;
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

    // The capacity the BMS's own coulomb counter implies: remaining divided by
    // the charge it reports. Only meaningful away from the extremes, where
    // dividing by a rounded percentage is noise rather than a figure.
    final socFraction = last == null ? 0.0 : last.soc / 100.0;
    final implied = last != null && socFraction >= 0.15 && socFraction <= 0.95
        ? last.remainingAh / socFraction
        : null;

    // Wear, measured, or nothing. It used to be the implied capacity over the
    // catalogue figure, which on this pack was 40 divided by 40: a guaranteed
    // 99% that would have read the same on a ruined battery. Checked against a
    // real pack at every charge from 53% to 70% and it gave 40.0 Ah every
    // time. See [CapacitySource.configured].
    final wear = Degradation.from(
      tests: _tests,
      readings: const [],
      advertisedAh: widget.device.catalogueCapacityAh,
    );
    final lost = wear.lostFraction;

    // Which cell sat lowest in the last reading. Not the same as the one that
    // is always lowest, but it is what the stored row can answer.
    (int, double)? weakest;
    if (last != null) {
      final cells = decodeCellVoltages(last.cellVoltagesJson);
      if (cells.isNotEmpty) {
        var idx = 0;
        for (var i = 1; i < cells.length; i++) {
          if (cells[i] < cells[idx]) idx = i;
        }
        weakest = (idx, cells[idx]);
      }
    }

    // The one figure here that is a measurement rather than arithmetic on what
    // the BMS says about itself.
    final measured = completed.map((x) => x.measuredAh).toList();
    final bestMeasured = measured.isEmpty
        ? null
        : measured.reduce((a, b) => a > b ? a : b);

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
        title: t.offlineHealthTitle,
        children: [
          InfoRow(
            t.offlineMeasuredHealth,
            lost == null ? '--' : '${(lost * 100).toStringAsFixed(1)} %',
            dim: lost == null,
            valueColor: lost == null ? null : _healthTone(100 - lost * 100),
            hint: lost != null
                ? null
                : wear.current == null
                    ? t.offlineHealthNeedsTests
                    : t.offlineHealthOneTest(
                        wear.current!.ah.toStringAsFixed(1),
                      ),
          ),
          InfoRow(
            t.offlineImplied,
            implied == null ? '--' : '${implied.toStringAsFixed(1)} Ah',
            dim: implied == null,
            hint: implied == null
                ? t.offlineImpliedUnusable
                : t.offlineImpliedHint,
          ),
          if (last != null) ...[
            InfoRow(t.offlineSoh, '${last.soh.toStringAsFixed(0)} %'),
            InfoRow(t.offlineCycles, last.cycleCount.toStringAsFixed(0)),
            if (weakest != null)
              InfoRow(
                t.offlineWeakest,
                t.offlineWeakestValue(
                  '${weakest.$1 + 1}',
                  weakest.$2.toStringAsFixed(3),
                ),
              ),
            InfoRow(
              t.offlineMaxTemp,
              '${last.maxTemperature.toStringAsFixed(0)} °C',
            ),
          ],
          if (bestMeasured != null)
            InfoRow(
              t.offlineBestMeasured,
              '${bestMeasured.toStringAsFixed(1)} Ah',
              valueColor: AppTheme.good,
            ),
          InfoRow(
            t.offlineHistorySince,
            _firstAt == null ? '--' : _date(_firstAt!),
            dim: _firstAt == null,
            hint: t.offlineReadings('$_readingCount'),
            last: true,
          ),
        ],
      ),
      Section(
        title: t.driftTitle,
        intro: t.driftWhy,
        children: [
          if (_drift == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                _driftRanking.isEmpty ? t.driftNotEnough : t.driftNone,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: AppTheme.textFaint,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                t.driftFound(
                  '${_drift!.index + 1}',
                  _drift!.currentDeviationVolts.toStringAsFixed(3),
                  _drift!.changeVoltsPerMonth.toStringAsFixed(3),
                ),
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: AppTheme.watch,
                ),
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
      if (widget.service.repository != null)
        MaintenanceCard(
          db: widget.service.repository!.db,
          deviceId: widget.device.id,
          onChanged: _load,
        ),
      Section(
        title: t.offlineTrips,
        children: [
          InfoRow(t.offlineTrips, t.offlineTripsCount('${_trips.length}')),
          InfoRow(
            t.offlineTotalKm,
            '${totalKm.toStringAsFixed(1)} km',
          ),
          // Full pack first: with nothing connected, "how far can it go" is
          // the question somebody is actually asking, and the charge the pack
          // happened to be at when it was last seen is not it.
          InfoRow(
            t.rangeFull,
            _outlook.fullKm == null
                ? t.offlineRangeUnknown
                : '${_outlook.fullKm!.toStringAsFixed(0)} km',
            dim: _outlook.fullKm == null,
            valueColor: _outlook.fullFromMeasuredCapacity
                ? AppTheme.good
                : null,
          ),
          InfoRow(
            t.offlineRangeAtLastSeen,
            _outlook.nowKm == null
                ? t.offlineRangeUnknown
                : '${_outlook.nowKm!.toStringAsFixed(0)} km',
            // Dimmed once the reading behind it is old. This figure is only
            // ever as fresh as that reading, and after a few days the pack has
            // very likely been ridden or has sat and self-discharged, so the
            // number stops describing the battery and starts describing a
            // moment.
            dim: _outlook.nowKm == null || _readingIsStale,
            last: completed.isEmpty,
          ),
          if (_outlook.nowKm != null && _readingIsStale && last != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                t.offlineRangeStale(_ago(t, last.timestamp)),
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: AppTheme.textFaint,
                ),
              ),
            ),
          if (_outlook.fullKm != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _outlook.fullFromMeasuredCapacity
                    ? t.rangeFullFromMeasured
                    : t.rangeFullFromAdvert,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: AppTheme.textFaint,
                ),
              ),
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
                builder: (_) => TrendsScreen(
                  service: widget.service,
                  deviceId: widget.device.id,
                ),
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

  static Color _healthTone(double percent) {
    if (percent >= 92) return AppTheme.good;
    if (percent >= 80) return AppTheme.watch;
    return AppTheme.bad;
  }

  static String _date(DateTime utc) {
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}
