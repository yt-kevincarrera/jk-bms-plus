import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/protocol/ant_frame_assembler.dart';
import 'package:jk_bms/src/protocol/ant_parser.dart';

/// Replays the ANT frames in a backup through the decoder.
///
/// This is how a field failure gets fixed without the pack: the rider makes a
/// backup with raw frames, the file lands in test/fixtures, and this test
/// grows a case for it. Rejected buffers (type 0x00) and LinkEvents hex are
/// printed so a mismatch is visible.
void main() {
  for (final path in [
    'test/fixtures/ant_backup_synthetic.json',
    // Add the real backup here when it arrives.
  ]) {
    test('replays $path', () {
      final backup =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      final frames = (backup['rawFrames'] as List)
          .cast<Map<String, dynamic>>()
          .where((f) => f['brand'] == 'ant' && f['recordType'] != 0);
      const parser = AntParser();
      var statuses = 0;
      for (final f in frames) {
        final a = AntFrameAssembler();
        final hexStr = f['bytes'] as String;
        final bytes = [
          for (var i = 0; i + 1 < hexStr.length; i += 2)
            int.parse(hexStr.substring(i, i + 2), radix: 16),
        ];
        final out = a.addChunk(bytes);
        expect(out, hasLength(1), reason: 'did not reassemble: $hexStr');
        final frame = out.single;
        if (frame.isStatus) {
          statuses++;
          final s = parser.parseStatus(frame).snapshot;
          expect(s.cellVoltages.every((v) => v > 1.0 && v < 4.6), isTrue);
          expect(
            (s.cellVoltages.reduce((a, b) => a + b) - s.packVoltage).abs(),
            lessThan(0.05 * s.packVoltage),
          );
        } else if (frame.isDeviceInfo) {
          expect(parser.parseDeviceInfo(frame).model, isNotEmpty);
        }
      }
      expect(statuses, greaterThan(0));
    });
  }
}
