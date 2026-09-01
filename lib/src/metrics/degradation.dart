import '../data/database.dart';

/// Where a capacity figure came from, because it changes what it is worth.
enum CapacitySource {
  /// A full discharge counted amp-hour by amp-hour. The only real measurement
  /// this app makes.
  measured,

  /// Remaining amp-hours divided by the charge the BMS reports. Arithmetic on
  /// what the BMS says about itself, useful and not the same thing.
  implied,
}

/// One capacity figure with its provenance and date.
class CapacityPointOfRecord {
  const CapacityPointOfRecord({
    required this.ah,
    required this.at,
    required this.source,
  });

  final double ah;
  final DateTime at;
  final CapacitySource source;
}

/// What a pack can actually be said to have lost.
///
/// This replaces measuring health against what the pack was advertised as,
/// which conflated two unrelated questions and answered neither well:
///
/// 1. **Has this battery degraded?** That is wear, and it can only be measured
///    against what this battery really held when it was new. Measuring it
///    against a marketing figure reports a pack sold as 45 Ah that was always
///    40 as permanently 89% healthy, on day one, before it has lost anything
///    at all. The number never described wear and never would.
///
/// 2. **Did I get what I paid for?** That is a fact about a purchase, decided
///    once, and it does not change as the pack ages. It belongs in a sentence,
///    not in a health gauge that is supposed to move.
///
/// So degradation is measured against the best this pack has ever actually
/// managed, and the advertised figure is kept only to answer the second
/// question, plainly, once.
class Degradation {
  const Degradation({
    required this.current,
    this.baseline,
    this.advertisedAh,
    this.observations = 0,
  });

  /// What the pack holds now.
  final CapacityPointOfRecord? current;

  /// The best it has ever held, which is the honest baseline for wear.
  ///
  /// Not what it was sold as, and not what the BMS is configured for. Both of
  /// those are claims; this is the high-water mark of what was observed.
  final CapacityPointOfRecord? baseline;

  /// What the seller said, when the rider has said so.
  final double? advertisedAh;

  /// How many capacity figures the picture is built from.
  ///
  /// The gate on reporting any degradation at all. One observation is a
  /// capacity, not a decline; two or more can honestly report no loss, which
  /// is different from being unable to tell.
  final int observations;

  /// How much of the original capacity is gone, as a fraction.
  ///
  /// Null unless there is a baseline and a current figure that are genuinely
  /// different observations. One measurement is a capacity, not a
  /// degradation: with a single point there is nothing to have declined from,
  /// and reporting 0% would be a claim that the pack is provably as good as
  /// new.
  double? get lostFraction {
    final now = current;
    final was = baseline;
    if (now == null || was == null || was.ah <= 0) return null;
    // Two observations can report no loss. One cannot report anything.
    if (observations < 2) return null;
    final lost = 1 - now.ah / was.ah;
    // Capacity measurements wobble by a few percent, and a pack reading
    // slightly above its old best has not gained capacity.
    return lost <= 0 ? 0 : lost;
  }

  /// Whether the baseline is a real measurement rather than arithmetic.
  bool get baselineIsMeasured => baseline?.source == CapacitySource.measured;

  /// How far short of the advert the pack came, as a fraction.
  ///
  /// A fact about the purchase, not about wear. Uses the best the pack ever
  /// managed, because that is the fairest reading of what was delivered: what
  /// it holds today includes any ageing since, which the seller is not
  /// responsible for.
  double? get shortOfAdvertisedFraction {
    final advertised = advertisedAh;
    final was = baseline;
    if (advertised == null || advertised <= 0 || was == null) return null;
    final short = 1 - was.ah / advertised;
    return short <= 0 ? 0 : short;
  }

  /// Builds the picture from what is stored.
  ///
  /// Real measurements outrank implied ones entirely: one capacity test is
  /// worth more than a year of dividing remaining by percent, and mixing the
  /// two would let a noisy implied high-water mark stand in as a baseline the
  /// pack never actually reached.
  static Degradation from({
    required List<CapacityTest> tests,
    required List<Snapshot> readings,
    double? advertisedAh,
  }) {
    final measured = [
      for (final t in tests)
        if (t.completed && t.measuredAh > 0)
          CapacityPointOfRecord(
            ah: t.measuredAh,
            at: t.endedAt ?? t.startedAt,
            source: CapacitySource.measured,
          ),
    ]..sort((a, b) => a.at.compareTo(b.at));

    if (measured.length >= 2) {
      final best = measured.reduce((a, b) => a.ah >= b.ah ? a : b);
      return Degradation(
        current: measured.last,
        baseline: best,
        advertisedAh: advertisedAh,
        observations: measured.length,
      );
    }

    // Fewer than two measurements: fall back to what the BMS implies, which
    // is available immediately and is at least about this pack rather than
    // about an advert.
    final implied = _impliedPoints(readings);
    if (implied.isEmpty) {
      return Degradation(
        current: measured.isEmpty ? null : measured.single,
        baseline: measured.isEmpty ? null : measured.single,
        advertisedAh: advertisedAh,
        observations: measured.length,
      );
    }

    final best = implied.reduce((a, b) => a.ah >= b.ah ? a : b);
    return Degradation(
      // A single real measurement is still the better answer for "what does it
      // hold now" than any amount of arithmetic.
      current: measured.isNotEmpty ? measured.single : implied.last,
      baseline: best,
      advertisedAh: advertisedAh,
      observations: measured.isNotEmpty ? 1 + implied.length : implied.length,
    );
  }

  /// Capacity implied by the coulomb counter, from readings where that
  /// division means anything.
  static List<CapacityPointOfRecord> _impliedPoints(List<Snapshot> readings) {
    final out = <CapacityPointOfRecord>[];
    for (final r in readings) {
      final fraction = r.soc / 100.0;
      // Near the extremes this divides by a rounded percentage and becomes
      // noise, and noise at the top would set a baseline no pack ever reached.
      if (fraction < 0.25 || fraction > 0.9) continue;
      if (r.remainingAh <= 0) continue;
      out.add(
        CapacityPointOfRecord(
          ah: r.remainingAh / fraction,
          at: r.timestamp,
          source: CapacitySource.implied,
        ),
      );
    }
    return out;
  }
}
