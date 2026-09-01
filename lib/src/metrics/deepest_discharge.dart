import '../data/database.dart';

/// The deepest continuous discharge found in stored readings.
class DeepestDischarge {
  const DeepestDischarge({
    required this.startSoc,
    required this.endSoc,
    required this.at,
  });

  final double startSoc;
  final double endSoc;
  final DateTime at;

  /// Percentage points covered, which is how close it came to being usable.
  double get span => startSoc - endSoc;
}

/// Finds how deep the pack has ever been run, in one go.
///
/// This exists to answer a fair question: if the app is connected all the time
/// and records every ride, why does it still want a full discharge?
///
/// Because everything else is circular. The BMS reports a charge percentage
/// that it works out by counting coulombs and dividing by the capacity it is
/// *configured* for. So amp-hours measured across a partial discharge, divided
/// by the percentage the BMS says was used, returns the configured capacity
/// again, no matter what the pack really holds. Twenty rides of that are worth
/// exactly as much as one: nothing.
///
/// What breaks the circle is the ends. A pack charged until the cells reach
/// their limit, and discharged until the BMS opens on voltage, has both ends
/// anchored to volts rather than to counting. Only the amp-hours between those
/// two points are a measurement rather than a restatement.
///
/// Nobody has to sit through one deliberately. The app already scans stored
/// readings for full discharges that happened anyway. This is for telling the
/// rider how close they have come, instead of asking again.
class DeepestDischargeFinder {
  const DeepestDischargeFinder({
    this.chargingCurrent = 1.0,
    this.maxGap = const Duration(minutes: 30),
  });

  /// Current in, above which the run is broken by a charge.
  final double chargingCurrent;

  /// A hole longer than this ends a run: what happened while the app was away
  /// is unknown, and assuming it was more of the same would invent depth.
  final Duration maxGap;

  DeepestDischarge? find(List<Snapshot> readings) {
    DeepestDischarge? best;
    double? runStartSoc;
    DateTime? runStartAt;
    Snapshot? previous;

    void close(Snapshot at) {
      if (runStartSoc == null || runStartAt == null) return;
      final candidate = DeepestDischarge(
        startSoc: runStartSoc!,
        endSoc: at.soc,
        at: runStartAt!,
      );
      if (candidate.span > 0 && (best == null || candidate.span > best!.span)) {
        best = candidate;
      }
      runStartSoc = null;
      runStartAt = null;
    }

    for (final s in readings) {
      final charging = s.current > chargingCurrent;
      final gapTooBig = previous != null &&
          s.timestamp.difference(previous.timestamp) > maxGap;

      if (charging || gapTooBig) {
        if (previous != null) close(previous);
        // A gap ends the old run and this reading begins the next one. It used
        // to be thrown away, which cost a point off the front of every run
        // that followed a break.
        runStartSoc = charging ? null : s.soc;
        runStartAt = charging ? null : s.timestamp;
        previous = s;
        continue;
      }

      runStartSoc ??= s.soc;
      runStartAt ??= s.timestamp;
      // A run that climbs without charging current is noise; restart from the
      // higher point rather than counting the dip as depth.
      if (s.soc > runStartSoc!) {
        runStartSoc = s.soc;
        runStartAt = s.timestamp;
      }
      previous = s;
    }

    if (previous != null) close(previous);
    return best;
  }
}
