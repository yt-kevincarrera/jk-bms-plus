import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/protocol/ant_frame.dart';
import 'package:jk_bms/src/protocol/ant_frame_assembler.dart';

import 'fixtures/ant_frames.dart';

void main() {
  late AntFrameAssembler a;
  late List<AntRejected> rejected;

  setUp(() {
    a = AntFrameAssembler(clock: () => DateTime.utc(2026, 9, 28));
    rejected = [];
    a.onRejected = rejected.add;
  });

  List<AntFrame> feed(Uint8List f, int chunk) => [
        for (var i = 0; i < f.length; i += chunk)
          ...a.addChunk(f.sublist(i, (i + chunk).clamp(0, f.length))),
      ];

  for (final chunk in [20, 244, 1000]) {
    test('whole frames in $chunk-byte notifications', () {
      for (final f in [
        antStatus16s,
        antStatus14s4t,
        antStatus20s4tCharging,
        antInfo16zm,
        antInfo22ph,
      ]) {
        final out = feed(f, chunk);
        expect(out, hasLength(1));
        expect(out.single.bytes, f);
      }
      expect(rejected, isEmpty);
      expect(a.stats.accepted, 5);
    });
  }

  test('a lone 0x55 inside ASCII does not end the frame (esphome #172)', () {
    // Byte 26 of this frame is 0x55; the first chunk ends right after it.
    expect(a.addChunk(antInfo22ph.sublist(0, 27)), isEmpty);
    final out = a.addChunk(antInfo22ph.sublist(27));
    expect(out.single.isDeviceInfo, isTrue);
  });

  test('status and info are told apart by function and address', () {
    expect(feed(antStatus16s, 244).single.isStatus, isTrue);
    expect(feed(antInfo16zm, 244).single.isDeviceInfo, isTrue);
  });

  test('a new 7E A1 notification discards a half frame', () {
    a.addChunk(antStatus16s.sublist(0, 40));
    final out = feed(antStatus14s4t, 244);
    expect(out.single.bytes, antStatus14s4t);
  });

  test('bad CRC is rejected with its bytes kept', () {
    final bad = Uint8List.fromList(antStatus16s)..[40] ^= 0xFF;
    expect(feed(bad, 244), isEmpty);
    expect(rejected.single.reason, AntRejection.badCrc);
    expect(rejected.single.bytes, bad);
    expect(a.stats.badChecksum, 1);
  });

  test('length that does not match data_len is rejected', () {
    final short = Uint8List.fromList([
      ...antStatus16s.sublist(0, 100),
      ...antStatus16s.sublist(148),
    ]);
    expect(feed(short, 244), isEmpty);
    expect(rejected.single.reason, AntRejection.badLength);
  });

  test('bytes that end in AA 55 but never started with 7E A1', () {
    expect(a.addChunk([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0xAA, 0x55]),
        isEmpty);
    expect(rejected.single.reason, AntRejection.notAFrame);
  });

  test('a buffer past 192 bytes is dropped, not grown', () {
    a.addChunk([0x7E, 0xA1, ...List.filled(200, 0x11)]);
    a.addChunk([0x11]);
    expect(rejected.single.reason, AntRejection.overflow);
    expect(a.bufferedBytes, lessThanOrEqualTo(1));
  });

  test('reset drops what is buffered', () {
    a.addChunk(antStatus16s.sublist(0, 60));
    a.reset();
    expect(a.bufferedBytes, 0);
  });
}
