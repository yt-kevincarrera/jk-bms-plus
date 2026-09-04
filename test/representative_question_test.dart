import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ui/widgets/representative_question.dart';

void main() {
  group('whether to ask about a ride', () {
    test('asks when the ride moves the figure past the threshold', () {
      expect(shouldAskAbout(shiftFraction: 0.08, answered: null), isTrue);
    });

    test('stays quiet under the threshold', () {
      // An ordinary fast day. Making a storm out of it is exactly what the
      // rider asked this not to do.
      expect(shouldAskAbout(shiftFraction: 0.03, answered: null), isFalse);
    });

    test('stays quiet once it has been answered', () {
      expect(shouldAskAbout(shiftFraction: 0.30, answered: true), isFalse);
      expect(shouldAskAbout(shiftFraction: 0.30, answered: false), isFalse);
    });
  });

  group('how far a ride moved the learned figure', () {
    test('a real ride against a real baseline', () {
      // The worked example this task was corrected over: a 40 km ride at
      // 24 Wh/km against a learned 17.5 moves the figure to 20.388..., a
      // real 16.5079%. The discarded fold-of-a-fold method read this same
      // ride as 8.33%; a regression back to that method would fail this.
      final shift = shiftFraction(before: 17.5, after: 20.388888888888889);
      expect(shift, closeTo(0.165079, 0.0001));
    });

    test('no baseline means nothing to compare, so no ask', () {
      // The first ride ever, or one stored before whPerKmBefore/After
      // existed. A naive division would hit a null check and crash rather
      // than quietly deciding there is nothing to ask about.
      expect(shiftFraction(before: null, after: 20), 0.0);
    });

    test('a zero or negative baseline does not divide', () {
      // A naive `(after - before).abs() / before` turns a zero baseline into
      // an infinite fraction, which would sail past any threshold and ask
      // about a ride that taught the app nothing.
      expect(shiftFraction(before: 0, after: 20), 0.0);
      expect(shiftFraction(before: -5, after: 20), 0.0);
    });

    test('no after figure means no shift to report', () {
      expect(shiftFraction(before: 17.5, after: null), 0.0);
    });
  });
}
