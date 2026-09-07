import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ui/pack_trips_screen.dart';

void main() {
  final now = DateTime.utc(2026, 9, 7, 12);

  // The rides of one pack, read with no radio involved. What is worth pinning
  // is the cut, not the layout: reading a pack offline must not become a way
  // around what the free tier shows, and the count behind the cut has to be
  // right or the locked row lies about how much is there.

  List<DateTime> at(List<int> daysAgo) =>
      [for (final d in daysAgo) now.subtract(Duration(days: d))];

  test('with no window, every ride is shown', () {
    final cut = RideWindow.apply(
      startedAt: at([1, 40, 400]),
      window: null,
      now: now,
    );
    expect(cut.shown, 3);
    expect(cut.hidden, 0);
  });

  test('a window hides the rides behind it and counts them', () {
    final cut = RideWindow.apply(
      startedAt: at([1, 10, 40, 400]),
      window: const Duration(days: 30),
      now: now,
    );
    expect(cut.shown, 2);
    expect(cut.hidden, 2);
  });

  test('a ride exactly on the edge is not shown', () {
    // The boundary has to fall one way on purpose rather than by accident.
    // Out, so the window is never quoted as longer than it is.
    final cut = RideWindow.apply(
      startedAt: at([30]),
      window: const Duration(days: 30),
      now: now,
    );
    expect(cut.shown, 0);
    expect(cut.hidden, 1);
  });

  test('nothing stored is not the same as everything hidden', () {
    final cut = RideWindow.apply(
      startedAt: const [],
      window: const Duration(days: 30),
      now: now,
    );
    expect(cut.shown, 0);
    expect(cut.hidden, 0);
  });
}
