import '../data/database.dart';
import 'maintenance.dart';

/// Where a maintenance event sits on a trend chart.
class ChartMarker {
  const ChartMarker({required this.x, required this.kind, required this.at});

  /// Position along the x axis: days since the chart's first point. See
  /// [ChartMarkers.dayOf].
  final double x;

  final MaintenanceKind kind;
  final DateTime at;
}

/// Places maintenance events onto a trend chart whose x axis is time.
///
/// The trend charts used to plot point 0, 1, 2 along the x axis, which drew
/// three rides on consecutive days and three rides a month apart as the same
/// line, so a gap of a season looked like no time at all and a slope per
/// month could not be read off the picture. They now plot days since the
/// first point, and an event is placed the same way.
class ChartMarkers {
  const ChartMarkers();

  /// Days from [first] to [at], fractional: the x of a point or an event.
  static double dayOf(DateTime first, DateTime at) =>
      at.difference(first).inMinutes / (24 * 60);

  /// Returns a marker per event that falls inside the series.
  ///
  /// [pointDates] must be in the same order as the plotted points.
  ///
  /// Events outside the range are dropped rather than clamped to an edge. A
  /// marker pinned to the first point saying a cell was replaced would be a
  /// claim that it happened at the start of this data, and it did not: it
  /// happened before any of it. The maintenance card says that in words
  /// instead.
  static List<ChartMarker> place({
    required List<DateTime> pointDates,
    required List<MaintenanceEvent> events,
  }) {
    if (pointDates.length < 2 || events.isEmpty) return const [];

    final first = pointDates.first;
    final last = pointDates.last;
    final out = <ChartMarker>[];

    for (final e in events) {
      final at = e.at;
      if (at.isBefore(first) || at.isAfter(last)) continue;
      out.add(
        ChartMarker(
          x: dayOf(first, at),
          kind: MaintenanceKind.parse(e.kind),
          at: at,
        ),
      );
    }

    out.sort((a, b) => a.x.compareTo(b.x));
    return out;
  }
}
