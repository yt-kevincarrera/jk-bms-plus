import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/advice_engine.dart';
import 'package:jk_bms/src/metrics/advice_grouping.dart';

Advice _a(AdviceCode code, AdviceLevel level) =>
    Advice(code: code, level: level);

void main() {
  group('arranging findings by what they are about', () {
    test('a cause and its price come out as one card', () {
      // The whole point. These used to sit four rows apart with unrelated
      // findings between them, so they read as two findings saying the same
      // thing rather than a finding and what it costs.
      final grouped = groupAdvice([
        _a(AdviceCode.imbalanceAtRest, AdviceLevel.problem),
        _a(AdviceCode.runningHot, AdviceLevel.watch),
        _a(AdviceCode.imbalanceCostingRange, AdviceLevel.watch),
      ]);

      expect(grouped.cards.length, 2);
      final cells = grouped.cards.firstWhere(
        (c) => c.subject == AdviceSubject.cells,
      );
      expect(cells.headline.code, AdviceCode.imbalanceAtRest);
      expect(cells.rest.map((a) => a.code), [
        AdviceCode.imbalanceCostingRange,
      ]);
    });

    test('the worst finding in a subject gives the card its title', () {
      final grouped = groupAdvice([
        _a(AdviceCode.weakCellDominant, AdviceLevel.watch),
        _a(AdviceCode.imbalanceAtRest, AdviceLevel.problem),
        _a(AdviceCode.balancerNeverSeen, AdviceLevel.info),
      ]);

      final cells = grouped.cards.single;
      expect(cells.headline.code, AdviceCode.imbalanceAtRest);
      expect(cells.level, AdviceLevel.problem);
      // And the rest stay in severity order under it.
      expect(cells.rest.map((a) => a.level), [
        AdviceLevel.watch,
        AdviceLevel.info,
      ]);
    });

    test('cards are ordered by their worst finding', () {
      final grouped = groupAdvice([
        _a(AdviceCode.runningHot, AdviceLevel.info),
        _a(AdviceCode.imbalanceAtRest, AdviceLevel.problem),
        _a(AdviceCode.noCapacityTestYet, AdviceLevel.watch),
      ]);

      expect(grouped.cards.map((c) => c.subject), [
        AdviceSubject.cells,
        AdviceSubject.capacity,
        AdviceSubject.temperature,
      ]);
    });

    test('subjects tie-break in the order the enum declares', () {
      // Physical first, merely claimed last. Without a stable tie-break the
      // cards would shuffle between readings of the same pack.
      final grouped = groupAdvice([
        _a(AdviceCode.cycleCounterInflated, AdviceLevel.watch),
        _a(AdviceCode.imbalanceAtRest, AdviceLevel.watch),
        _a(AdviceCode.noCapacityTestYet, AdviceLevel.watch),
      ]);

      expect(grouped.cards.map((c) => c.subject), [
        AdviceSubject.cells,
        AdviceSubject.capacity,
        AdviceSubject.bmsClaims,
      ]);
    });

    test('a subject with nothing but good news draws no card', () {
      // A green card costs the same room as one with content. With six
      // subjects a healthy pack would fill the screen exactly as much as a
      // sick one, which tells the reader nothing.
      final grouped = groupAdvice([
        _a(AdviceCode.noCellDrifting, AdviceLevel.good),
        _a(AdviceCode.deltaUnderLoadNormal, AdviceLevel.good),
        _a(AdviceCode.runningHot, AdviceLevel.watch),
      ]);

      expect(grouped.cards.map((c) => c.subject), [AdviceSubject.temperature]);
      expect(grouped.checkedAndFine, [AdviceSubject.cells]);
    });

    test('one bad finding keeps the subject as a card, good news included', () {
      final grouped = groupAdvice([
        _a(AdviceCode.noCellDrifting, AdviceLevel.good),
        _a(AdviceCode.imbalanceAtRest, AdviceLevel.problem),
      ]);

      final cells = grouped.cards.single;
      expect(cells.headline.code, AdviceCode.imbalanceAtRest);
      // The reassurance is not thrown away, it just stops leading.
      expect(cells.rest.single.code, AdviceCode.noCellDrifting);
      expect(grouped.checkedAndFine, isEmpty);
    });

    test('a subject that produced nothing reads as unmeasured, not as fine',
        () {
      // The risk this design takes: a subject that vanishes could be fine or
      // could be unmeasured, and the app must not let those look alike.
      final grouped = groupAdvice(
        [_a(AdviceCode.imbalanceAtRest, AdviceLevel.problem)],
        expected: {
          AdviceSubject.cells,
          AdviceSubject.capacity,
          AdviceSubject.range,
        },
      );

      expect(grouped.checkedAndFine, isEmpty);
      expect(grouped.notChecked, [
        AdviceSubject.capacity,
        AdviceSubject.range,
      ]);
    });

    test('a screen that does not ask about a subject never reports it', () {
      // The configuration audit looks at three subjects. Saying "nothing to
      // say about range yet" on a screen that never asks about range is worse
      // than saying nothing.
      final grouped = groupAdvice([
        _a(AdviceCode.configOvpDangerous, AdviceLevel.problem),
      ]);

      expect(grouped.notChecked, isEmpty);
    });

    test('with nothing to report there is no summary line at all', () {
      final grouped = groupAdvice([
        _a(AdviceCode.imbalanceAtRest, AdviceLevel.problem),
      ]);

      expect(grouped.hasSummary, isFalse);
    });

    test('caveats about the measurement stay out of the cards', () {
      final grouped = groupAdvice([
        _a(AdviceCode.inspectionCellSagging, AdviceLevel.problem),
        _a(AdviceCode.inspectionNoHeavyLoad, AdviceLevel.watch),
      ]);

      expect(grouped.cards.single.subject, AdviceSubject.cells);
      expect(grouped.cards.single.rest, isEmpty);
      expect(grouped.caveats.single.code, AdviceCode.inspectionNoHeavyLoad);
    });

    test('nothing at all is not a crash', () {
      final grouped = groupAdvice(const []);
      expect(grouped.cards, isEmpty);
      expect(grouped.caveats, isEmpty);
      expect(grouped.hasSummary, isFalse);
    });
  });
}
