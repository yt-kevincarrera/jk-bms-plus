import '../data/database.dart';
import 'sampling.dart';
import 'trip_recorder.dart';

/// What a repair pass found and mended.
class TripRepairReport {
  const TripRepairReport({
    required this.examined,
    required this.repaired,
    required this.unrepairable,
  });

  final int examined;
  final int repaired;

  /// Rides whose readings are no longer on disk, or whose coulomb counter did
  /// not move enough to answer. Nothing can be done for these.
  final int unrepairable;

  bool get didAnything => repaired > 0;

  static const TripRepairReport none =
      TripRepairReport(examined: 0, repaired: 0, unrepairable: 0);
}

/// Groups items into runs whose total span stays within [maxSpan].
///
/// Exists because reading every stale ride's readings in one query was right
/// for the case it was written for and catastrophic for the case that actually
/// happens. An evening's rides are dozens of rows minutes apart, and one query
/// covering all of them beats a query each. Rides spread over weeks are the
/// same code reading every reading stored in those weeks, unbounded, on the
/// first decoded frame of a connection -- which is what left the rider's own
/// pack sitting on "waiting for the first reading" while a pack with no
/// history connected instantly.
///
/// Generic over the accessors so it can be tested without building database
/// rows.
List<List<T>> groupBySpan<T>(
  List<T> items, {
  required DateTime Function(T) startOf,
  required DateTime Function(T) endOf,
  required Duration maxSpan,
}) {
  if (items.isEmpty) return const [];
  final sorted = [...items]
    ..sort((a, b) => startOf(a).compareTo(startOf(b)));

  final groups = <List<T>>[];
  var current = <T>[sorted.first];
  var from = startOf(sorted.first);
  var to = endOf(sorted.first);

  for (final item in sorted.skip(1)) {
    final end = endOf(item).isAfter(to) ? endOf(item) : to;
    if (end.difference(from) > maxSpan) {
      groups.add(current);
      current = <T>[item];
      from = startOf(item);
      to = endOf(item);
      continue;
    }
    current.add(item);
    to = end;
  }
  groups.add(current);
  return groups;
}

/// Recomputes the energy of rides recorded before the integration bug was
/// fixed.
///
/// Every ride recorded up to version 2.5.0 has an energy figure that is far too
/// low, because almost every reading was discarded before it could be
/// integrated. Those rides are not lost, though, and that is the point of this
/// file: the readings themselves were always stored correctly, at full
/// resolution, including the pack's own coulomb counter. The ride can be
/// measured again from them, years later if need be.
///
/// It works the same way the recorder now does. The counter is preferred over
/// integrating power, because it kept counting through every second the
/// Bluetooth link was down, and on the ride that exposed all this the link was
/// down for 998 of 1286 seconds.
class TripEnergyRepair {
  const TripEnergyRepair({
    this.minimumAh = 0.01,
    this.window = const Duration(seconds: 2),
  });

  /// Below this the counter has not moved past its own quantisation.
  final double minimumAh;

  /// How far outside the ride's own timestamps to look for readings, since the
  /// row's start and end are written a moment apart from the readings around
  /// them.
  final Duration window;

  /// Works out what a ride really cost, from the readings stored during it.
  ///
  /// Returns null when there is nothing better than what is already stored.
  RepairedEnergy? recompute(Trip trip, List<Snapshot> readings) {
    final from = trip.startedAt.subtract(window);
    final to = trip.endedAt.add(window);
    final during = [
      for (final s in readings)
        if (!s.timestamp.isBefore(from) && !s.timestamp.isAfter(to)) s,
    ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (during.length < 2) return null;

    // The counter, first choice.
    final ah = during.first.remainingAh - during.last.remainingAh;
    var voltageSum = 0.0;
    var voltageCount = 0;
    for (final s in during) {
      if (s.packVoltage > 0) {
        voltageSum += s.packVoltage;
        voltageCount++;
      }
    }
    final meanVolts = voltageCount == 0 ? 0.0 : voltageSum / voltageCount;

    if (ah >= minimumAh && meanVolts > 0) {
      return RepairedEnergy(
        outWh: ah * meanVolts,
        ahOut: ah,
        source: EnergySource.coulombCount,
      );
    }

    // Falling back to integration, now done properly. Worth having: a short
    // ride can finish inside one step of the counter and still have drawn a
    // measurable amount.
    var outWh = 0.0;
    var inWh = 0.0;
    for (var i = 1; i < during.length; i++) {
      final dt = usableInterval(during[i - 1].timestamp, during[i].timestamp);
      if (dt == null) continue;
      final previous = during[i - 1].packVoltage * during[i - 1].current;
      final now = during[i].packVoltage * during[i].current;
      final wh = (previous + now) / 2 * hoursIn(dt);
      if (wh < 0) {
        outWh += -wh;
      } else {
        inWh += wh;
      }
    }

    if (outWh <= 0) return null;
    return RepairedEnergy(
      outWh: outWh,
      inWh: inWh,
      source: EnergySource.integrated,
    );
  }
}

/// One ride's energy, measured again.
class RepairedEnergy {
  const RepairedEnergy({
    required this.outWh,
    required this.source,
    this.inWh = 0,
    this.ahOut,
  });

  final double outWh;
  final double inWh;
  final double? ahOut;
  final EnergySource source;
}
