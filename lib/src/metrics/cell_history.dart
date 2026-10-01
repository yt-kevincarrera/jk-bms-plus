import '../data/database.dart';

/// One bucket of stored readings, as the database hands it over: the real
/// reading kept for it, and the first and last instants that had any.
class CellHistoryRow {
  const CellHistoryRow({
    required this.at,
    required this.firstAt,
    required this.lastAt,
    required this.cellVoltagesJson,
  });

  final DateTime at;
  final DateTime firstAt;
  final DateTime lastAt;
  final String cellVoltagesJson;
}

/// One point on the chart: a real reading, every cell of it.
class CellHistoryPoint {
  const CellHistoryPoint({
    required this.at,
    required this.cells,
    required this.gapBefore,
  });

  final DateTime at;

  /// Volts, cell 1 first.
  final List<double> cells;

  /// True when nothing was read for longer than [CellHistory.maxJoin]
  /// between this point and the one before it, so the line breaks here
  /// rather than drawing a straight run through a stretch nobody saw.
  final bool gapBefore;

  double get average => cells.reduce((a, b) => a + b) / cells.length;
}

/// Every cell's voltage over a window, thinned to a few hundred points.
///
/// The cell voltages of every reading are stored, and until now only ever
/// read back as a single number at a time: the last reading, a delta, a
/// trend. How the cells moved against each other through a ride or a charge,
/// which is where a weak cell shows itself, could not be seen at all.
///
/// Thinned in the database, one real reading per bucket rather than an
/// average: an averaged point would be a pack state that never existed, and
/// the app does not draw those. The cost is that a spike between two kept
/// readings is not drawn, which the screen says.
class CellHistory {
  const CellHistory({required this.points});

  /// Longer than this with no reading and the lines break. The BMS sends two
  /// or three readings a second; thirty seconds of nothing is the link gone,
  /// and joining across it would draw a voltage nobody measured.
  static const Duration maxJoin = Duration(seconds: 30);

  /// About as many points per cell as a phone-width chart can show.
  static const int maxPoints = 500;

  final List<CellHistoryPoint> points;

  static const CellHistory empty = CellHistory(points: []);

  bool get isEmpty => points.isEmpty;

  int get cellCount => points.isEmpty ? 0 : points.first.cells.length;

  /// The bucket width that keeps a window under [maxPoints]: never under a
  /// second, which is finer than the readings come.
  static Duration bucketFor(DateTime from, DateTime to) {
    final seconds = to.difference(from).inSeconds;
    final width = (seconds / maxPoints).ceil();
    return Duration(seconds: width < 1 ? 1 : width);
  }

  /// Builds the points from the database's buckets, oldest first.
  ///
  /// Readings with a different number of cells from the most common one are
  /// left out: a pack whose cell count changed half way (a cell disabled, a
  /// board swapped) cannot be drawn as one set of lines, and guessing which
  /// cell became which would be inventing.
  static CellHistory from(List<CellHistoryRow> rows) {
    final decoded = [
      for (final r in rows)
        (row: r, cells: decodeCellVoltages(r.cellVoltagesJson)),
    ];
    final counts = <int, int>{};
    for (final d in decoded) {
      if (d.cells.isEmpty) continue;
      counts[d.cells.length] = (counts[d.cells.length] ?? 0) + 1;
    }
    if (counts.isEmpty) return empty;
    final n = counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;

    final points = <CellHistoryPoint>[];
    DateTime? previousLast;
    for (final d in decoded) {
      if (d.cells.length != n) continue;
      final gap =
          previousLast != null &&
          d.row.firstAt.difference(previousLast) > maxJoin;
      points.add(
        CellHistoryPoint(at: d.row.at, cells: d.cells, gapBefore: gap),
      );
      previousLast = d.row.lastAt;
    }
    return CellHistory(points: points);
  }

  /// The cell that sat furthest under the pack average over the window, and
  /// the one furthest over it, one-based. Null for either on an empty window.
  ///
  /// Averaged over the points, so a cell that was lowest for one reading is
  /// not the one picked out: on a level pack which cell is lowest at a given
  /// instant is noise.
  ({int? lowest, int? highest}) extremes() {
    if (points.isEmpty) return (lowest: null, highest: null);
    final n = cellCount;
    final sum = List<double>.filled(n, 0);
    for (final p in points) {
      final avg = p.average;
      for (var i = 0; i < n; i++) {
        sum[i] += p.cells[i] - avg;
      }
    }
    var low = 0;
    var high = 0;
    for (var i = 1; i < n; i++) {
      if (sum[i] < sum[low]) low = i;
      if (sum[i] > sum[high]) high = i;
    }
    return (lowest: low + 1, highest: high + 1);
  }
}
