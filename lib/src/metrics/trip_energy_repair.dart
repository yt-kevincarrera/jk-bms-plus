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
    this.bracketReach = const Duration(minutes: 10),
  });

  /// Below this the counter has not moved past its own quantisation.
  final double minimumAh;

  /// How far outside the ride's own timestamps to look for readings, since the
  /// row's start and end are written a moment apart from the readings around
  /// them.
  final Duration window;

  /// How far either side of a ride to look for the readings that bracket it,
  /// when nothing at all arrived during the ride itself.
  ///
  /// Short on purpose. The pack is parked in that time and draws next to
  /// nothing, so a few minutes of it costs the figure almost nothing -- but
  /// the amp-hours counted across the gap belong to *everything* that happened
  /// in it, and the only defence against that is for the gap to be too short
  /// for anything else to fit. Ten minutes covers connecting before setting
  /// off and reconnecting on arrival; it does not cover another ride.
  final Duration bracketReach;

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

    // Two readings from inside the ride are not the same as two readings that
    // cover it. This used to ask only the first question, so a link that died
    // a minute into a 53-minute ride left a 0.13 Ah difference that measured
    // that minute, and the repair would have confirmed it as the cost of the
    // whole ride: 0.5 Wh/km on a bike that really does 17.
    //
    // The file's own doc for [_fromBrackets] had the principle all along --
    // part of a ride "would cover only part of it and quietly under-report the
    // rest, which is worse than admitting the ride cannot be measured" -- but
    // applied it only where nothing arrived at all. It holds just as well
    // where a little arrived, so the brackets are preferred there too: they at
    // least span the ride.
    if (during.length < 2 ||
        !readingsCoverRide(
          rideDuration: trip.endedAt.difference(trip.startedAt),
          firstReading: during.first.timestamp,
          lastReading: during.last.timestamp,
        )) {
      return _fromBrackets(trip, readings);
    }

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

  /// Measures a ride nothing was received during, from the readings either
  /// side of it.
  ///
  /// The link being down is not the counter being down. The BMS accumulated
  /// amp-hours through every second of the blackout, so the last reading
  /// before setting off and the first one on arrival still have the whole ride
  /// between them, and the difference is what it cost.
  ///
  /// Both sides are required. One of them plus a reading from inside the ride
  /// would cover only part of it and quietly under-report the rest, which is
  /// worse than admitting the ride cannot be measured.
  RepairedEnergy? _fromBrackets(Trip trip, List<Snapshot> readings) {
    Snapshot? before;
    Snapshot? after;
    final earliest = trip.startedAt.subtract(bracketReach);
    final latest = trip.endedAt.add(bracketReach);

    for (final s in readings) {
      if (!s.timestamp.isAfter(trip.startedAt) &&
          !s.timestamp.isBefore(earliest)) {
        if (before == null || s.timestamp.isAfter(before.timestamp)) {
          before = s;
        }
      }
      if (!s.timestamp.isBefore(trip.endedAt) &&
          !s.timestamp.isAfter(latest)) {
        if (after == null || s.timestamp.isBefore(after.timestamp)) after = s;
      }
    }
    if (before == null || after == null) return null;
    if (before.packVoltage <= 0 || after.packVoltage <= 0) return null;

    // A counter that went up means the pack was charged somewhere in there,
    // and a net figure cannot separate the two directions. Nothing to say.
    final ah = before.remainingAh - after.remainingAh;
    if (ah < minimumAh) return null;

    // Priced at the mean of the two ends. There are no readings from the ride
    // to average, and the ends are where the pack actually was.
    final meanVolts = (before.packVoltage + after.packVoltage) / 2;

    return RepairedEnergy(
      outWh: ah * meanVolts,
      ahOut: ah,
      startSoc: before.soc,
      endSoc: after.soc,
      source: EnergySource.bracketedCoulombCount,
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
    this.startSoc,
    this.endSoc,
  });

  final double outWh;
  final double inWh;
  final double? ahOut;

  /// The charge either side of the ride, when the repair had to reach outside
  /// it to find any reading at all.
  ///
  /// Only set by the bracketing path. A ride the link was up for already has
  /// these, recorded as it happened, and they are not to be overwritten with a
  /// worse version of themselves.
  final double? startSoc;
  final double? endSoc;

  final EnergySource source;
}
