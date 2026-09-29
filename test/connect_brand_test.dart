import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/protocol/bms_brand.dart';
import 'package:jk_bms/src/ui/connect_screen.dart';

void main() {
  test('stored brand wins, then the name, else ask', () {
    expect(knownBrandFor(stored: 'ant', hint: BmsBrand.jk), BmsBrand.ant);
    expect(knownBrandFor(stored: null, hint: BmsBrand.ant), BmsBrand.ant);
    expect(knownBrandFor(stored: null, hint: null), isNull);
  });
}
