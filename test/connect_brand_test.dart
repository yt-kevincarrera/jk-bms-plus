import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/protocol/bms_brand.dart';
import 'package:jk_bms/src/ui/connect_screen.dart';

void main() {
  test('stored brand wins, then the name, else ask', () {
    expect(knownBrandFor(stored: 'ant', hint: BmsBrand.jk), BmsBrand.ant);
    expect(knownBrandFor(stored: null, hint: BmsBrand.ant), BmsBrand.ant);
    expect(knownBrandFor(stored: null, hint: null), isNull);
  });

  // The proximity watcher walks the rider straight into a reconnect nobody is
  // necessarily looking at the phone for. A modal sheet with no one to answer
  // it is a connect that never finishes, so that path must never ask,
  // whatever is or is not already known about the pack.
  test('a proximity-triggered connect never asks, known brand or not', () {
    expect(
      shouldAskBrand(fromProximity: true, stored: null, hint: null),
      isFalse,
    );
    expect(
      shouldAskBrand(fromProximity: true, stored: 'jk', hint: null),
      isFalse,
    );
    expect(
      shouldAskBrand(fromProximity: true, stored: null, hint: BmsBrand.ant),
      isFalse,
    );
  });

  test('a rider-tapped connect asks only when nothing already answers', () {
    expect(
      shouldAskBrand(fromProximity: false, stored: null, hint: null),
      isTrue,
    );
    expect(
      shouldAskBrand(fromProximity: false, stored: 'ant', hint: null),
      isFalse,
    );
    expect(
      shouldAskBrand(fromProximity: false, stored: null, hint: BmsBrand.jk),
      isFalse,
    );
  });
}
