import '../data/database.dart';
import 'snapshot_history.dart';

/// Which cells sat clearly lowest at rest over the last month, and how often.
///
/// The cells tab used to count this over the current connection only, every
/// reading included. Two things were wrong with that. A connection is a few
/// minutes to an hour, so the ranking started from nothing every time the
/// pack was met again and mostly read "needs more readings". And under load
/// the lowest cell is the one with the most resistance on its lead, which is
/// a different finding from the cell with the least charge in it.
///
/// So this reads the stored readings instead, and keeps only the ones that
/// can answer the question:
///
///  * at rest: under [restingAmps] either way, and not charging, because a
///    charger tapering off holds the cells apart by more than they sit;
///  * with the cells at least [SessionAggregates.weakCellMinDelta] apart, as
///    the weak-cell finding requires, because below that which cell is lowest
///    is measurement noise;
///  * with the lowest cell lowest by [SessionAggregates.weakCellMinLead], so a
///    tie does not go to whichever cell has the smaller number.
///
/// What it does not do is say which cell is weak. A cell that is lowest at
/// rest most of the time is the one with the least charge in it, which is a
/// capacity question or a balancing one; the drift analysis is what says
/// whether that is getting worse.
class WeakCellRanking {
  const WeakCellRanking({required this.top, required this.readings});

  /// Below this a reading is resting, either way.
  static const double restingAmps = 1.0;

  /// From this a reading is charging, and left out.
  static const double chargingAmps = 0.05;

  /// How far back the ranking reaches.
  static const Duration window = Duration(days: 30);

  /// The readings are asked for one per this, so a night on the charger
  /// watch at three readings a second does not pull a quarter of a million
  /// rows into memory to count the same few cells. Each one kept is still a
  /// real reading, not an average.
  static const Duration thinTo = Duration(seconds: 10);

  /// Up to three cells, most often lowest first. One-based cell numbers.
  final List<({int cell, double share})> top;

  /// How many readings qualified and were counted.
  final int readings;

  static const WeakCellRanking empty = WeakCellRanking(top: [], readings: 0);

  /// Whether there are enough readings for the ranking to mean anything.
  bool isEnough(int minReadings) => readings >= minReadings && top.isNotEmpty;

  /// Counts the readings [rows] hands over: cell voltages as stored, and the
  /// current they were taken at. Rows that do not qualify are skipped here as
  /// well as in the query, so the rule lives in one place that a test can
  /// read.
  static WeakCellRanking from(
    Iterable<({double current, String cellVoltagesJson})> rows,
  ) {
    final counts = <int, int>{};
    var total = 0;
    for (final r in rows) {
      if (r.current.abs() >= restingAmps || r.current > chargingAmps) continue;
      final cells = decodeCellVoltages(r.cellVoltagesJson);
      if (cells.length < 2) continue;
      var low = 0;
      for (var i = 1; i < cells.length; i++) {
        if (cells[i] < cells[low]) low = i;
      }
      var second = double.infinity;
      var high = cells[0];
      for (var i = 0; i < cells.length; i++) {
        if (cells[i] > high) high = cells[i];
        if (i != low && cells[i] < second) second = cells[i];
      }
      // Rounded to the millivolt the BMS reports in, so 10 mV stored as
      // 0.0099999 still counts as 10.
      final delta = ((high - cells[low]) * 1000).round();
      final lead = ((second - cells[low]) * 1000).round();
      if (delta < (SessionAggregates.weakCellMinDelta * 1000).round()) continue;
      if (lead < (SessionAggregates.weakCellMinLead * 1000).round()) continue;
      counts[low + 1] = (counts[low + 1] ?? 0) + 1;
      total++;
    }
    if (total == 0) return empty;
    final ranked = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return WeakCellRanking(
      top: [
        for (final e in ranked.take(3)) (cell: e.key, share: e.value / total),
      ],
      readings: total,
    );
  }
}
