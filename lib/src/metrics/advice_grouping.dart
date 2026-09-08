import 'advice_engine.dart';

/// What a finding is about.
///
/// The screens used to draw every finding in one flat list ordered by nothing
/// but severity. That put a cause and its price in different places: a wide
/// resting delta came out as a problem near the top, and the kilometres that
/// delta was costing came out as a watch four rows down with unrelated
/// findings in between. Read that way they look like two findings saying the
/// same thing, when they are one finding and what it costs.
///
/// Grouping by what the finding is *about* rather than by how loud it is fixes
/// both halves of that: the cause and the price end up in one card, and twenty
/// rows become five or six blocks. Severity still decides the colour and the
/// order; it just stops being the only thing that decides anything.
///
/// The order of these matters: it is the tie-break when two subjects carry
/// findings of the same severity, and it runs from what the battery physically
/// is towards what it merely claims about itself.
enum AdviceSubject { cells, capacity, range, temperature, configuration, bmsClaims }

/// Which subject a code belongs to, or null when it is not about the battery.
///
/// Null is a real answer, not a gap. Three of the inspection codes say the
/// *test* was weak rather than that the pack is: no heavy load was seen, the
/// load differed from last time, the counters had been reset. Those are
/// caveats about the measurement, and putting them in a card next to findings
/// about cells is what makes a reader doubt the findings that are sound.
///
/// Written as an exhaustive switch with no `default` on purpose. A code added
/// later has to fail the build rather than fall into a bucket nobody chose,
/// because a finding with the wrong subject is worse than one with none: it is
/// filed under a heading that makes it read as something it is not.
AdviceSubject? subjectOf(AdviceCode code) => switch (code) {
  // --- Cells: what the cells are doing to each other ---
  AdviceCode.cellDrifting ||
  AdviceCode.noCellDrifting ||
  AdviceCode.deltaUnderLoadNormal ||
  AdviceCode.imbalanceAtRest ||
  AdviceCode.imbalanceUnderLoad ||
  AdviceCode.weakCellDominant ||
  AdviceCode.balancerNeverSeen ||
  // The price of the imbalance lives with the imbalance. Filing it under
  // range would recreate the very split this grouping exists to close.
  AdviceCode.imbalanceCostingRange ||
  AdviceCode.inspectionCellSagging ||
  AdviceCode.inspectionSagUniform ||
  AdviceCode.inspectionRestDeltaWide ||
  AdviceCode.inspectionRestDeltaOk ||
  AdviceCode.inspectionWeakUnderLightLoad ||
  AdviceCode.inspectionSlowRecovery ||
  AdviceCode.inspectionRecoveryOk ||
  AdviceCode.inspectionRepeatSameCell ||
  AdviceCode.inspectionRepeatCellMoved ||
  AdviceCode.inspectionRepeatWorse ||
  AdviceCode.inspectionRepeatSteady => AdviceSubject.cells,

  // --- Capacity: how much the pack still holds ---
  AdviceCode.healthMeasured ||
  AdviceCode.healthNotMeasurable ||
  AdviceCode.capacityBelowCatalogue ||
  AdviceCode.noCapacityTestYet => AdviceSubject.capacity,

  // --- Range: how far that charge goes ---
  AdviceCode.rangeNow || AdviceCode.rangeStillLearning => AdviceSubject.range,

  // --- Temperature: heat and cold, wherever they were found ---
  AdviceCode.runningHot ||
  AdviceCode.inspectionHot ||
  AdviceCode.configChargesWhenFrozen ||
  AdviceCode.configColdCutoffOk ||
  AdviceCode.configChargeHotLimit ||
  AdviceCode.configDischargeHotLimit => AdviceSubject.temperature,

  // --- Configuration: the limits and switches somebody set ---
  AdviceCode.overvoltageSetHigh ||
  AdviceCode.configOvpDangerous ||
  AdviceCode.configOvpHigh ||
  AdviceCode.configUvpDangerous ||
  AdviceCode.configUvpLow ||
  AdviceCode.configChargeCurrentHigh ||
  AdviceCode.configBalancerOff ||
  AdviceCode.configChargeOff ||
  AdviceCode.configDischargeOff ||
  AdviceCode.configBalanceStartLow ||
  AdviceCode.configChangedSinceDayOne ||
  AdviceCode.configChemistryUnknown ||
  AdviceCode.configLooksSane => AdviceSubject.configuration,

  // --- What the BMS says about itself ---
  //
  // Scattered across three screens these repeat one idea in three voices:
  // the numbers the BMS reports are claims, and a claim can be typed into it
  // from the official app in under a minute. Together they argue it once.
  AdviceCode.cycleCounterInflated ||
  AdviceCode.healthFigureDecorative ||
  AdviceCode.socCounterAhead ||
  AdviceCode.socCounterBehind ||
  AdviceCode.inspectionCountersEditable ||
  AdviceCode.configCapacityDisagrees ||
  AdviceCode.configCellCountDisagrees ||
  // A fault the BMS raised during the test is the BMS reporting on itself,
  // which is what this card collects. It does not go under a physical subject
  // because the frame does not say which protection tripped, and filing it
  // under cells or heat on a guess would read as a finding about something
  // that was never measured.
  AdviceCode.inspectionAlarmsSeen => AdviceSubject.bmsClaims,

  // --- Not about the battery: how much this measurement is worth ---
  AdviceCode.inspectionNoHeavyLoad ||
  AdviceCode.inspectionRepeatLoadDiffers ||
  AdviceCode.inspectionRepeatCountersReset => null,
};

/// One subject's findings, ready to draw.
class AdviceCard {
  const AdviceCard({
    required this.subject,
    required this.headline,
    required this.rest,
  });

  final AdviceSubject subject;

  /// The worst thing this subject has to say. It gives the card its title and
  /// its colour, because that is what a reader scanning the screen needs.
  final Advice headline;

  /// The rest, worst first. Read under the headline, so a cause and its price
  /// are one glance apart.
  final List<Advice> rest;

  AdviceLevel get level => headline.level;

  /// Everything in the card, headline included.
  List<Advice> get all => [headline, ...rest];
}

/// The findings, arranged.
class GroupedAdvice {
  const GroupedAdvice({
    required this.cards,
    required this.checkedAndFine,
    required this.notChecked,
    required this.caveats,
  });

  /// Subjects with something to say, worst first.
  final List<AdviceCard> cards;

  /// Subjects that were looked at and had only good news. These deliberately
  /// draw no card: a green card costs the same room as one with content, and
  /// with six subjects a healthy pack would fill the screen exactly as much as
  /// a sick one. The summary line carries them instead.
  final List<AdviceSubject> checkedAndFine;

  /// Subjects the caller expects to evaluate that produced nothing at all.
  ///
  /// Tracked separately from [checkedAndFine] because collapsing them would
  /// tell the rider a lie by omission: a subject that vanished could be fine
  /// or could be unmeasured, and this app does not let those two look alike.
  final List<AdviceSubject> notChecked;

  /// Findings about the measurement rather than the battery.
  final List<Advice> caveats;

  /// Whether there is anything honest for a summary line to say.
  bool get hasSummary => checkedAndFine.isNotEmpty || notChecked.isNotEmpty;
}

/// Arranges findings into one card per subject.
///
/// [expected] is the set of subjects the caller actually evaluates. The health
/// tab looks at all six; the configuration audit looks at three. Without it,
/// the audit screen would report "nothing to say about range yet" on a screen
/// that never asks about range, which is worse than saying nothing.
GroupedAdvice groupAdvice(
  List<Advice> advice, {
  Set<AdviceSubject> expected = const {},
}) {
  final bySubject = <AdviceSubject, List<Advice>>{};
  final caveats = <Advice>[];

  for (final item in advice) {
    final subject = subjectOf(item.code);
    if (subject == null) {
      caveats.add(item);
      continue;
    }
    bySubject.putIfAbsent(subject, () => []).add(item);
  }

  final cards = <AdviceCard>[];
  final fine = <AdviceSubject>[];

  // Iterating the enum rather than the map keeps the tie-break stable: two
  // subjects whose worst finding is equally loud come out in the order the
  // enum declares, which runs from the physical to the merely claimed.
  for (final subject in AdviceSubject.values) {
    final found = bySubject[subject];
    if (found == null || found.isEmpty) continue;

    found.sort((a, b) => b.level.index.compareTo(a.level.index));
    if (found.every((a) => a.level == AdviceLevel.good)) {
      fine.add(subject);
      continue;
    }
    cards.add(
      AdviceCard(
        subject: subject,
        headline: found.first,
        rest: found.sublist(1),
      ),
    );
  }

  cards.sort((a, b) {
    final bySeverity = b.level.index.compareTo(a.level.index);
    if (bySeverity != 0) return bySeverity;
    return a.subject.index.compareTo(b.subject.index);
  });

  return GroupedAdvice(
    cards: cards,
    checkedAndFine: fine,
    notChecked: [
      for (final subject in AdviceSubject.values)
        if (expected.contains(subject) && !bySubject.containsKey(subject))
          subject,
    ],
    caveats: caveats,
  );
}
