import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/metrics/chart_markers.dart';
import 'package:jk_bms/src/metrics/maintenance.dart';

MaintenanceEvent event(DateTime at, {MaintenanceKind kind = MaintenanceKind.cellReplaced}) =>
    MaintenanceEvent(
      id: 0,
      deviceId: 'AA:BB',
      at: at,
      kind: kind.name,
      note: '',
    );

void main() {
  // Four readings, one a month apart.
  final dates = [
    DateTime.utc(2026, 1, 1),
    DateTime.utc(2026, 2, 1),
    DateTime.utc(2026, 3, 1),
    DateTime.utc(2026, 4, 1),
  ];

  group('placing an event on a chart plotted by index', () {
    test('lands exactly on a reading it shares a date with', () {
      final markers = ChartMarkers.place(
        pointDates: dates,
        events: [event(DateTime.utc(2026, 2, 1))],
      );
      expect(markers.single.x, closeTo(1.0, 0.0001));
    });

    test('lands between the two readings that bracket it', () {
      // Work done midway between two measurements belongs midway between them,
      // not snapped onto one: snapping would put a cell replacement on a
      // reading taken before it happened.
      final markers = ChartMarkers.place(
        pointDates: dates,
        events: [DateTime.utc(2026, 2, 15)].map(event).toList(),
      );
      expect(markers.single.x, greaterThan(1.0));
      expect(markers.single.x, lessThan(2.0));
      expect(markers.single.x, closeTo(1.5, 0.05));
    });

    test('lands on the first and last readings', () {
      final markers = ChartMarkers.place(
        pointDates: dates,
        events: [event(dates.first), event(dates.last)],
      );
      expect(markers.first.x, closeTo(0, 0.0001));
      expect(markers.last.x, closeTo(3, 0.0001));
    });

    test('keeps what kind it was', () {
      final markers = ChartMarkers.place(
        pointDates: dates,
        events: [
          event(DateTime.utc(2026, 2, 1), kind: MaintenanceKind.chargerChanged),
        ],
      );
      expect(markers.single.kind, MaintenanceKind.chargerChanged);
    });

    test('comes back in chart order', () {
      final markers = ChartMarkers.place(
        pointDates: dates,
        events: [
          event(DateTime.utc(2026, 3, 15)),
          event(DateTime.utc(2026, 1, 15)),
        ],
      );
      expect(markers.first.x, lessThan(markers.last.x));
    });
  });

  group('what it refuses to draw', () {
    test('an event from before the chart begins', () {
      // Clamping it to the first point would claim the work happened at the
      // start of this data. It happened before any of it, and the maintenance
      // card says so in words instead.
      final markers = ChartMarkers.place(
        pointDates: dates,
        events: [event(DateTime.utc(2025, 6, 1))],
      );
      expect(markers, isEmpty);
    });

    test('an event from after it ends', () {
      final markers = ChartMarkers.place(
        pointDates: dates,
        events: [event(DateTime.utc(2027, 1, 1))],
      );
      expect(markers, isEmpty);
    });

    test('anything at all, on a series too short to have a shape', () {
      expect(
        ChartMarkers.place(
          pointDates: [dates.first],
          events: [event(dates.first)],
        ),
        isEmpty,
      );
      expect(
        ChartMarkers.place(pointDates: const [], events: [event(dates.first)]),
        isEmpty,
      );
    });

    test('nothing, when there is nothing logged', () {
      expect(ChartMarkers.place(pointDates: dates, events: const []), isEmpty);
    });
  });

  group('awkward data', () {
    test('two readings at the same instant do not divide by zero', () {
      final same = [
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 2, 1),
      ];
      final markers = ChartMarkers.place(
        pointDates: same,
        events: [event(DateTime.utc(2026, 1, 1))],
      );
      expect(markers.single.x, 0);
    });
  });
}
