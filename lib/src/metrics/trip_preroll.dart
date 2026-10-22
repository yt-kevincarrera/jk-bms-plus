import 'dart:collection';

import '../gps/location_source.dart';
import '../model/bms_snapshot.dart';

sealed class TripPreRollEvent {
  DateTime get at;
}

class TripPreRollReading extends TripPreRollEvent {
  TripPreRollReading(this.snapshot);
  final BmsSnapshot snapshot;
  @override
  DateTime get at => snapshot.timestamp;
}

class TripPreRollFix extends TripPreRollEvent {
  TripPreRollFix(this.fix);
  final GeoFix fix;
  @override
  DateTime get at => fix.timestamp;
}

class TripPreRollCapture {
  TripPreRollCapture(this.startedAt, this.seed, this.events);
  final DateTime startedAt;
  final BmsSnapshot? seed;
  final List<TripPreRollEvent> events;
}

/// Observed data only. Confirmation can retain its own twenty seconds without
/// claiming any route from before the GPS delivered usable positions.
class TripPreRoll {
  TripPreRoll({this.maxEvents = 512, this.maxAge = const Duration(minutes: 2)});
  final int maxEvents;
  final Duration maxAge;
  final _events = Queue<TripPreRollEvent>();
  int get length => _events.length;

  void add(TripPreRollEvent event) {
    _events.addLast(event);
    final cutoff = event.at.subtract(maxAge);
    while (_events.isNotEmpty &&
        (_events.length > maxEvents || _events.first.at.isBefore(cutoff))) {
      _events.removeFirst();
    }
  }

  void clear() => _events.clear();

  TripPreRollCapture? capture(
    DateTime candidateStartedAt,
    DateTime confirmedAt,
  ) {
    final ordered = _events.where((e) => !e.at.isAfter(confirmedAt)).toList()
      ..sort((a, b) {
        final byTime = a.at.compareTo(b.at);
        if (byTime != 0) return byTime;
        // A reading received at the same instant supplies that point's pack
        // context before the fix is replayed.
        return (a is TripPreRollReading ? 0 : 1).compareTo(
          b is TripPreRollReading ? 0 : 1,
        );
      });
    final fixes = ordered.whereType<TripPreRollFix>().where(
      (e) => !e.at.isBefore(candidateStartedAt),
    );
    if (fixes.isEmpty) return null;
    // A capacity limit can evict the start of a candidate. Keep the remaining
    // observed suffix rather than backdating a trip across missing positions.
    final start = fixes.first.at;
    BmsSnapshot? seed;
    for (final event in ordered.whereType<TripPreRollReading>()) {
      if (event.at.isAfter(start)) break;
      if (start.difference(event.at) <= const Duration(seconds: 10)) {
        seed = event.snapshot;
      }
    }
    if (seed == null) return null;
    return TripPreRollCapture(
      start,
      seed,
      List.unmodifiable(ordered.where((e) => !e.at.isBefore(start))),
    );
  }
}
