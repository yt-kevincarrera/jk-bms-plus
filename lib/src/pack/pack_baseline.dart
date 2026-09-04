import 'dart:math' as math;

import '../model/bms_snapshot.dart';
import '../model/jk_device_info.dart';
import '../model/jk_settings.dart';
import 'pack_config.dart';

/// What a pack looked like on the day it was taken on.
///
/// The point is to have something honest to compare against later. Without
/// it, "the delta has opened up" means "opened up since the app happened to
/// start looking", which on a pack adopted in poor condition reads as a
/// healthy battery and on a good one exaggerates every wobble. With it, the
/// question becomes what changed since day one, which is the question the
/// rider is actually asking.
///
/// What this is not: a capacity measurement. A snapshot cannot measure what a
/// pack holds, and nothing here is allowed to be presented as capacity or as
/// wear. Those still come from a counted discharge and from nowhere else.
class PackBaseline {
  const PackBaseline({
    required this.capturedAt,
    required this.cellVoltages,
    this.cellResistances = const [],
    this.wireResistances = const [],
    this.temperatures = const [],
    this.packVoltage = 0,
    this.current = 0,
    this.soc,
    this.soh,
    this.cycleCount,
    this.config = PackConfig.none,
    this.model = '',
    this.serialNumber = '',
    this.softwareVersion = '',
  });

  final DateTime capturedAt;

  /// Every cell, in order, as they read on day one.
  final List<double> cellVoltages;

  /// Internal resistance per cell as the BMS estimates it. The figure the
  /// PRD calls the initial IR: worth having because a cell's resistance
  /// climbing is the earliest sign of it going, and a number with nothing to
  /// compare it against says very little.
  final List<double> cellResistances;

  /// Resistance of each cell's wiring, as configured or measured by the BMS.
  /// A loose connection shows up here rather than in the cell.
  final List<double> wireResistances;

  final List<double> temperatures;
  final double packVoltage;

  /// What the pack was doing when the snapshot was taken. A baseline caught
  /// mid-ride is not a resting baseline, and the comparison has to say so.
  final double current;

  final double? soc;
  final double? soh;
  final int? cycleCount;

  /// The BMS configuration on day one, so a setting changed later can be
  /// named rather than suspected.
  final PackConfig config;

  final String model;
  final String serialNumber;
  final String softwareVersion;

  int get cellCount => cellVoltages.length;

  /// Whether the pack was still enough for the cell voltages to mean
  /// anything. Under load every cell reads low, and by different amounts.
  bool get wasAtRest => current.abs() <= restCurrentAmps;

  /// Anything under this is the BMS's own housekeeping rather than a load.
  static const double restCurrentAmps = 1.0;

  double get deltaVolts => cellVoltages.isEmpty
      ? 0
      : cellVoltages.reduce(math.max) - cellVoltages.reduce(math.min);

  double get averageCellVoltage => cellVoltages.isEmpty
      ? 0
      : cellVoltages.reduce((a, b) => a + b) / cellVoltages.length;

  /// The cell sitting lowest on day one, 1-based, or null with no cells.
  int? get lowestCell {
    if (cellVoltages.isEmpty) return null;
    var index = 0;
    for (var i = 1; i < cellVoltages.length; i++) {
      if (cellVoltages[i] < cellVoltages[index]) index = i;
    }
    return index + 1;
  }

  /// Takes the day-one copy from whatever the app is holding.
  static PackBaseline capture({
    required BmsSnapshot snapshot,
    JkSettings? settings,
    JkDeviceInfo? info,
    DateTime? at,
  }) => PackBaseline(
    capturedAt: at ?? DateTime.now().toUtc(),
    cellVoltages: List<double>.from(snapshot.cellVoltages),
    cellResistances: List<double>.from(snapshot.cellResistances),
    wireResistances: settings == null
        ? const []
        : List<double>.from(settings.connectionWireResistances),
    temperatures: List<double>.from(snapshot.plausibleTemperatures),
    packVoltage: snapshot.packVoltage,
    current: snapshot.current,
    soc: snapshot.soc,
    soh: snapshot.soh,
    cycleCount: snapshot.cycleCount,
    config: settings == null ? PackConfig.none : PackConfig.from(settings),
    model: info?.model ?? '',
    serialNumber: info?.serialNumber ?? '',
    softwareVersion: info?.softwareVersion ?? '',
  );

  Map<String, Object?> toJson() => {
    'at': capturedAt.toUtc().toIso8601String(),
    'cells': cellVoltages,
    if (cellResistances.isNotEmpty) 'ir': cellResistances,
    if (wireResistances.isNotEmpty) 'wire': wireResistances,
    if (temperatures.isNotEmpty) 'temps': temperatures,
    'packV': packVoltage,
    'current': current,
    if (soc != null) 'soc': soc,
    if (soh != null) 'soh': soh,
    if (cycleCount != null) 'cycles': cycleCount,
    if (config.isNotEmpty) 'config': config.toJson(),
    if (model.isNotEmpty) 'model': model,
    if (serialNumber.isNotEmpty) 'serial': serialNumber,
    if (softwareVersion.isNotEmpty) 'sw': softwareVersion,
  };

  static PackBaseline fromJson(Map<String, Object?> m) => PackBaseline(
    capturedAt:
        DateTime.tryParse(m['at'] as String? ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    cellVoltages: _doubles(m['cells']),
    cellResistances: _doubles(m['ir']),
    wireResistances: _doubles(m['wire']),
    temperatures: _doubles(m['temps']),
    packVoltage: (m['packV'] as num?)?.toDouble() ?? 0,
    current: (m['current'] as num?)?.toDouble() ?? 0,
    soc: (m['soc'] as num?)?.toDouble(),
    soh: (m['soh'] as num?)?.toDouble(),
    cycleCount: (m['cycles'] as num?)?.toInt(),
    config: m['config'] is Map
        ? PackConfig.fromJson((m['config'] as Map).cast<String, Object?>())
        : PackConfig.none,
    model: m['model'] as String? ?? '',
    serialNumber: m['serial'] as String? ?? '',
    softwareVersion: m['sw'] as String? ?? '',
  );

  static List<double> _doubles(Object? raw) => [
    for (final v in (raw as List<dynamic>? ?? const []))
      if (v is num) v.toDouble(),
  ];
}

/// One cell, then and now.
class CellSince {
  const CellSince({
    required this.index,
    required this.thenVolts,
    required this.nowVolts,
    this.thenResistanceOhms,
    this.nowResistanceOhms,
  });

  /// 1-based, as written on the pack.
  final int index;

  /// How far this cell sat from the pack average, on day one and today.
  ///
  /// Deviations rather than raw volts, because the two readings were taken at
  /// different charge levels and comparing 3.31 V against 3.42 V would say
  /// nothing except that the pack was fuller one day than the other.
  final double thenVolts;
  final double nowVolts;

  final double? thenResistanceOhms;
  final double? nowResistanceOhms;

  double get driftVolts => nowVolts - thenVolts;

  double? get resistanceRise {
    final was = thenResistanceOhms;
    final now = nowResistanceOhms;
    if (was == null || now == null || was <= 0) return null;
    return now / was - 1;
  }
}

/// Today against day one.
///
/// Only the things a snapshot can honestly answer: how the cells sit relative
/// to each other, how their resistances have moved, and which settings are
/// not what they were. Capacity is absent on purpose.
class BaselineComparison {
  const BaselineComparison({
    required this.baseline,
    required this.at,
    required this.cells,
    required this.configChanged,
    required this.thenDeltaVolts,
    required this.nowDeltaVolts,
    this.comparable = true,
    this.thenCycleCount,
    this.nowCycleCount,
  });

  final PackBaseline baseline;
  final DateTime at;

  /// One entry per cell present in both readings, worst drift first.
  final List<CellSince> cells;

  /// Settings that are not what they were on day one.
  final List<ConfigChange> configChanged;

  final double thenDeltaVolts;
  final double nowDeltaVolts;

  /// False when one of the two readings was taken under load, which makes
  /// the cell figures a comparison of throttle positions rather than of
  /// batteries.
  final bool comparable;

  final int? thenCycleCount;
  final int? nowCycleCount;

  Duration get age => at.difference(baseline.capturedAt);
  int get days => age.inDays;

  double get deltaChange => nowDeltaVolts - thenDeltaVolts;

  /// Below this, a cell has not moved: it is the same reading twice with the
  /// BMS's own measurement noise on top, and calling it drift would have
  /// every pack in the world drifting.
  static const double driftFloorVolts = 0.005;

  /// The cell that has fallen furthest behind the pack since day one, or null
  /// when nobody has moved enough to be worth naming.
  CellSince? get worstDrift {
    if (cells.isEmpty) return null;
    final worst = cells.first;
    return worst.driftVolts <= -driftFloorVolts ? worst : null;
  }

  /// Cycles the BMS counted between the two readings, when it counted any.
  int? get cyclesSince {
    final was = thenCycleCount;
    final now = nowCycleCount;
    if (was == null || now == null || now < was) return null;
    return now - was;
  }

  /// Builds the comparison from a live reading.
  static BaselineComparison? compute({
    required PackBaseline baseline,
    required BmsSnapshot now,
    JkSettings? settings,
  }) => computeFrom(
    baseline: baseline,
    at: now.timestamp,
    cells: now.cellVoltages,
    cellResistances: now.cellResistances,
    current: now.current,
    cycleCount: now.cycleCount,
    settings: settings,
  );

  /// The same, from parts, or null when the two readings cannot be lined up.
  ///
  /// Exists because the stored rows are not snapshots: the saved-pack screen
  /// and the printed sheet work from the database, where a reading is a row
  /// with its cells as JSON and no per-cell resistances at all. Rather than
  /// assemble a half-empty snapshot to satisfy a signature, this takes what
  /// it needs and reports on whatever it was given.
  static BaselineComparison? computeFrom({
    required PackBaseline baseline,
    required DateTime at,
    required List<double> cells,
    required double current,
    List<double> cellResistances = const [],
    int? cycleCount,
    JkSettings? settings,
  }) {
    final thenCells = baseline.cellVoltages;
    final nowCells = cells;
    if (thenCells.isEmpty || nowCells.isEmpty) return null;
    // A pack that has had cells added or removed is not the same pack, and
    // pretending cell 9 of sixteen is cell 9 of twenty would invent a fault.
    if (thenCells.length != nowCells.length) return null;

    final thenAverage = baseline.averageCellVoltage;
    final nowAverage = nowCells.reduce((a, b) => a + b) / nowCells.length;

    final since = <CellSince>[
      for (var i = 0; i < nowCells.length; i++)
        CellSince(
          index: i + 1,
          thenVolts: thenCells[i] - thenAverage,
          nowVolts: nowCells[i] - nowAverage,
          thenResistanceOhms: i < baseline.cellResistances.length
              ? _positive(baseline.cellResistances[i])
              : null,
          nowResistanceOhms: i < cellResistances.length
              ? _positive(cellResistances[i])
              : null,
        ),
    ]..sort((a, b) => a.driftVolts.compareTo(b.driftVolts));

    return BaselineComparison(
      baseline: baseline,
      at: at,
      cells: since,
      configChanged: settings == null || baseline.config.isEmpty
          ? const []
          : configChanges(baseline.config, PackConfig.from(settings)),
      thenDeltaVolts: baseline.deltaVolts,
      nowDeltaVolts: nowCells.reduce(math.max) - nowCells.reduce(math.min),
      comparable:
          baseline.wasAtRest && current.abs() <= PackBaseline.restCurrentAmps,
      thenCycleCount: baseline.cycleCount,
      nowCycleCount: cycleCount,
    );
  }

  static double? _positive(double v) => v > 0 ? v : null;
}
