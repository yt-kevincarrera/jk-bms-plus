/// How long until the pack is full.
class ChargeEta {
  const ChargeEta({required this.remaining, required this.isTapering});

  /// Time left, or null when it cannot honestly be worked out.
  final Duration? remaining;

  /// Whether the pack is in the constant-voltage tail, where the current falls
  /// away and the last few percent take far longer than the arithmetic
  /// suggests.
  final bool isTapering;

  static const ChargeEta unknown =
      ChargeEta(remaining: null, isTapering: false);
}

/// Estimates time to full from what is charging into the pack right now.
///
/// The naive version, amp-hours left over amps going in, is right for most of
/// a charge and badly wrong at the end. Above roughly 90% a lithium charger
/// stops holding current and starts holding voltage, the current tails off
/// towards nothing, and the remaining time stretches: a pack that says twelve
/// minutes at 92% can genuinely take forty.
///
/// So the taper is modelled rather than ignored, and the result is flagged as
/// an estimate in the tail so the number is not read as a promise.
class ChargeEtaEstimator {
  const ChargeEtaEstimator({
    this.taperStartsAt = 0.90,
    this.minimumCurrent = 0.5,
    this.fullAt = 0.995,
  });

  /// Charge fraction at which the charger stops giving full current.
  final double taperStartsAt;

  /// Below this many amps in, nothing useful can be said: the pack is either
  /// finished or not really charging.
  final double minimumCurrent;

  /// Where "full" is called.
  final double fullAt;

  /// [current] is positive charging, in the app's convention.
  ChargeEta estimate({
    required double current,
    required double soc,
    required double capacityAh,
  }) {
    if (current < minimumCurrent || capacityAh <= 0) return ChargeEta.unknown;

    final fraction = (soc / 100).clamp(0.0, 1.0);
    if (fraction >= fullAt) {
      return const ChargeEta(remaining: Duration.zero, isTapering: true);
    }

    // The flat part: amp-hours still to put in at the current rate.
    final toTaper = ((taperStartsAt - fraction).clamp(0.0, 1.0)) * capacityAh;
    final flatHours = toTaper / current;

    // The tail. Current falls roughly linearly to nothing across it, so the
    // average rate over that stretch is about half of what is flowing now,
    // which doubles the time the naive arithmetic would give.
    final inTaper = fraction > taperStartsAt;
    final taperAh = ((fullAt - (inTaper ? fraction : taperStartsAt))
            .clamp(0.0, 1.0)) *
        capacityAh;
    // In the tail the current already reflects the taper, so it is halved
    // relative to now rather than to the bulk rate.
    final averageTaperCurrent = (inTaper ? current : current) * 0.5;
    final taperHours =
        averageTaperCurrent <= 0 ? 0.0 : taperAh / averageTaperCurrent;

    final hours = flatHours + taperHours;
    if (!hours.isFinite || hours < 0) return ChargeEta.unknown;

    return ChargeEta(
      remaining: Duration(seconds: (hours * 3600).round()),
      isTapering: inTaper,
    );
  }
}
