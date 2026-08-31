import '../data/database.dart';
import 'maintenance.dart';

/// Where a maintenance event sits on a chart whose x axis is the point index.
class ChartMarker {
  const ChartMarker({required this.x, required this.kind, required this.at});

  /// Position along the x axis, interpolated between the two readings the
  /// event falls between. Fractional on purpose: work done midway between two
  /// measurements belongs midway between them, not snapped onto one.
  final double x;

  final MaintenanceKind kind;
  final DateTime at;
}

/// Places maintenance events onto a series plotted by index rather than time.
///
/// The trend charts plot point 0, 1, 2 along the x axis, because the readings
/// are irregular and a real time axis would leave most of the chart empty. That
/// makes putting a dated event on one a mapping problem: the date has to be
/// turned into a position between whichever two points bracket it.
class ChartMarkers {
  const ChartMarkers();

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

      final x = _interpolate(pointDates, at);
      if (x == null) continue;
      out.add(
        ChartMarker(x: x, kind: MaintenanceKind.parse(e.kind), at: at),
      );
    }

    out.sort((a, b) => a.x.compareTo(b.x));
    return out;
  }

  static double? _interpolate(List<DateTime> dates, DateTime at) {
    for (var i = 0; i < dates.length - 1; i++) {
      final a = dates[i];
      final b = dates[i + 1];
      if (at.isBefore(a) || at.isAfter(b)) continue;

      final span = b.difference(a).inMilliseconds;
      // Two readings at the same instant. Anything between them is that point.
      if (span <= 0) return i.toDouble();
      final into = at.difference(a).inMilliseconds;
      return i + into / span;
    }
    // Exactly on the last point.
    if (!at.isBefore(dates.last) && !at.isAfter(dates.last)) {
      return (dates.length - 1).toDouble();
    }
    return null;
  }
}
