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
}
