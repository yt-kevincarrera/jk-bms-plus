import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/protocol/ant_constants.dart';
import 'package:jk_bms/src/protocol/ant_crc.dart';
import 'package:jk_bms/src/protocol/bms_brand.dart';

import 'fixtures/ant_frames.dart';

void main() {
  int declared(List<int> f, int at) => f[at] | (f[at + 1] << 8);

  test('fixtures have the lengths the reference documents', () {
    expect(antStatus16s.length, 152);
    expect(antStatus14s4t.length, 152);
    expect(antInfo16zm.length, 48);
    expect(antInfo22ph.length, 48);
  });

  test('status frames: CRC over bytes 1..len-5 matches the trailer', () {
    for (final f in [antStatus16s, antStatus14s4t]) {
      expect(antCrc16(f, 1, f.length - 4), declared(f, f.length - 4));
    }
  });

  test('device info: CRC sits at 6 + data_len, not at the end', () {
    for (final f in [antInfo16zm, antInfo22ph]) {
      final at = 6 + f[5];
      expect(antCrc16(f, 1, at), declared(f, at));
    }
  });

  test('the two requests carry valid CRCs and are the only ones', () {
    expect(antStatusRequest,
        [0x7E, 0xA1, 0x01, 0x00, 0x00, 0xBE, 0x18, 0x55, 0xAA, 0x55]);
    expect(antDeviceInfoRequest,
        [0x7E, 0xA1, 0x02, 0x6C, 0x02, 0x20, 0x58, 0xC4, 0xAA, 0x55]);
    for (final r in [antStatusRequest, antDeviceInfoRequest]) {
      expect(antCrc16(r, 1, 6), declared(r, 6));
    }
  });

  test('brand from advertised name', () {
    expect(brandFromName('ANT-BLE16ZMUB'), BmsBrand.ant);
    expect(brandFromName('ANT@BLE22AAUB'), BmsBrand.ant);
    expect(brandFromName('JK-BD6A20S6P'), BmsBrand.jk);
    expect(brandFromName('KevinJK'), BmsBrand.jk);
    expect(brandFromName('Moto'), isNull);
    expect(brandFromName('GIANT'), isNull);
    expect(BmsBrand.fromStored(null), BmsBrand.jk);
    expect(BmsBrand.fromStored('ant'), BmsBrand.ant);
  });
}
