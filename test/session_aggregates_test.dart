import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/snapshot_history.dart';

import 'fixtures/snapshot_builder.dart';

/// What the advice engine reads about a connection, kept for the whole of it
/// rather than scanned off a buffer of twenty-odd minutes, and counted the
/// way a finding about one cell has to be counted to mean anything.
void main() {
  final t0 = DateTime.utc(2026, 9, 1, 10);
  var n = 0;
  DateTime next() => t0.add(Duration(milliseconds: 400 * n++));

  List<double> cellsWith(Map<int, double> set, {double at = 3.90}) => [
    for (var i = 1; i <= 20; i++) set[i] ?? at,
  ];

  setUp(() => n = 0);

  group('the loaded delta', () {
    test('one wide frame is not the figure; several are', () {
      final a = SessionAggregates();
      // One frame whose cells were read a moment apart from its current.
      a.add(
        buildSnapshot(
          timestamp: next(),
          current: -40,
          cells: cellsWith({4: 3.70}),
        ),
      );
      for (var i = 0; i < 6; i++) {
        a.add(
          buildSnapshot(
            timestamp: next(),
            current: -40,
            cells: cellsWith({9: 3.87 - i * 0.0001}),
          ),
        );
      }
      // The median of the five widest: the stray 200 mV frame is one of
      // them, and does not decide it.
      expect(a.loadedDelta, closeTo(0.0304, 0.00005));
      expect(a.loadedDeltaCell, 9);
    });

    test('needs several distinct loaded readings before it says anything', () {
      final a = SessionAggregates();
      for (var i = 0; i < 4; i++) {
        a.add(
          buildSnapshot(
            timestamp: next(),
            current: -40,
            cells: cellsWith({9: 3.85 - i * 0.001}),
          ),
        );
      }
      expect(a.loadedDelta, isNull);
    });

    test('a frame the BMS merely repeats counts once', () {
      final a = SessionAggregates();
      final cells = cellsWith({9: 3.85});
      for (var i = 0; i < 10; i++) {
        a.add(buildSnapshot(timestamp: next(), current: -40, cells: cells));
      }
      expect(a.loadedFrames, 1);
      expect(a.loadedDelta, isNull);
    });

    test('counts the readings heavy enough to show a bad connection', () {
      final a = SessionAggregates();
      for (var i = 0; i < 5; i++) {
        a.add(
          buildSnapshot(
            timestamp: next(),
            current: -11,
            nominalCapacityAh: 100,
            cells: cellsWith({9: 3.85 - i * 0.001}),
          ),
        );
      }
      // 11 A on a 100 Ah pack is light; the line is 15 A there.
      expect(a.heavyLoadFrames, 0);
      expect(SessionAggregates.heavyLoadAmps(40), closeTo(12, 1e-9));
      expect(SessionAggregates.heavyLoadAmps(100), 15);
    });
  });

  group('the resting delta', () {
    test('keeps the cell that was lowest then, and leaves the charger out', () {
      final a = SessionAggregates()
        ..add(
          buildSnapshot(
            timestamp: next(),
            current: 0,
            cells: cellsWith({12: 3.86}),
          ),
        )
        // A charger tapering off at 0.6 A holds the cells further apart.
        ..add(
          buildSnapshot(
            timestamp: next(),
            current: 0.6,
            cells: cellsWith({3: 3.80}),
          ),
        );
      expect(a.restingDelta, closeTo(0.04, 1e-9));
      expect(a.restingDeltaCell, 12);
    });
  });

  group('which cell is lowest', () {
    test('only counts readings with the cells apart and no tie', () {
      final a = SessionAggregates()
        // 3 mV apart: noise, not a weakest cell.
        ..add(buildSnapshot(timestamp: next(), cells: cellsWith({5: 3.897})))
        // A tie: cell 1 used to win every one of these.
        ..add(
          buildSnapshot(
            timestamp: next(),
            cells: cellsWith({2: 3.88, 7: 3.88}),
          ),
        )
        // Lowest by 1 mV only.
        ..add(
          buildSnapshot(
            timestamp: next(),
            cells: cellsWith({2: 3.880, 7: 3.881}),
          ),
        )
        // Clearly cell 7.
        ..add(
          buildSnapshot(
            timestamp: next(),
            cells: cellsWith({2: 3.885, 7: 3.875}),
          ),
        );
      expect(a.weakCellCounts, {7: 1});
    });
  });

  test('the balancer is remembered for the whole connection', () {
    final h = SnapshotHistory(capacity: 5);
    h.add(buildSnapshot(timestamp: next()));
    expect(h.session.balancerEverSeen, isFalse);
    // Nothing in the snapshot builder switches the balancer on, so the
    // clear is what is checked: a new connection starts from nothing.
    h.clear();
    expect(h.session.restingDelta, isNull);
    expect(h.session.weakCellCounts, isEmpty);
  });
}
