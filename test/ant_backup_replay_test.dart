import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/protocol/ant_frame.dart';
import 'package:jk_bms/src/protocol/ant_frame_assembler.dart';
import 'package:jk_bms/src/protocol/ant_parser.dart';

/// Replays the ANT frames in a backup through the decoder.
///
/// This is how a field failure gets fixed without the pack: the rider makes a
/// backup with raw frames, the file lands in test/fixtures, and this test
/// grows a case for it.
///
/// Two places in a backup carry ANT bytes. Raw frames that decoded (any
/// record type but 0x00) are checked against physics. LinkEvents of kind
/// antFrameRejected and antDecodeFailed carry the bytes of everything that
/// did not, as the last space-separated token of their detail; they are the
/// only copy when the pack never became active, because raw frames are not
/// stored until then. Each of those is fed through the assembler and the
/// parser again and its outcome printed, so running this test against a
/// failure backup shows, frame by frame, where the decoder stops.
void main() {
  for (final path in [
    'test/fixtures/ant_backup_synthetic.json',
    // Add the real backup here when it arrives.
  ]) {
    test('replays $path', () {
      final backup =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      final frames = (backup['rawFrames'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .where((f) => f['brand'] == 'ant' && f['recordType'] != 0)
          .toList();
      const parser = AntParser();
      var statuses = 0;
      for (final f in frames) {
        final a = AntFrameAssembler();
        final hexStr = f['bytes'] as String;
        final out = a.addChunk(_bytes(hexStr));
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
      // A backup from a session where the pack never became active has no
      // raw frames at all, and its evidence is in the LinkEvents below.
      if (frames.isNotEmpty) expect(statuses, greaterThan(0));

      final events = (backup['linkEvents'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .where(
            (e) =>
                e['kind'] == 'antFrameRejected' ||
                e['kind'] == 'antDecodeFailed',
          )
          .toList();
      final outcomes = [for (final e in events) _replayEvent(e, parser)];
      for (var i = 0; i < events.length; i++) {
        // Printed on purpose: this is what someone fixing the decoder reads.
        // ignore: avoid_print
        print('${events[i]['kind']} at ${events[i]['at']}: ${outcomes[i]}');
      }

      if (path.endsWith('ant_backup_synthetic.json')) {
        // The synthetic backup carries one bad-CRC copy of a real status
        // frame, so the harness is proved to read and judge these rows.
        expect(outcomes, contains('rejected badCrc'));
      }
    });
  }
}

/// What the decoder makes of the bytes a LinkEvents row carries today.
String _replayEvent(Map<String, dynamic> e, AntParser parser) {
  final detail = (e['detail'] as String? ?? '').trim();
  final hexStr = detail.split(' ').last;
  if (hexStr.isEmpty ||
      hexStr.length.isOdd ||
      !RegExp(r'^[0-9a-fA-F]+$').hasMatch(hexStr)) {
    return 'no bytes in "$detail"';
  }
  final rejected = <AntRejection>[];
  final a = AntFrameAssembler()..onRejected = (r) => rejected.add(r.reason);
  final out = a.addChunk(_bytes(hexStr));
  if (rejected.isNotEmpty) return 'rejected ${rejected.first.name}';
  if (out.isEmpty) return 'incomplete (${hexStr.length ~/ 2} bytes)';
  final frame = out.single;
  try {
    if (frame.isStatus) {
      final s = parser.parseStatus(frame).snapshot;
      return 'status ${s.cellVoltages.length} cells, '
          '${s.packVoltage.toStringAsFixed(2)} V, '
          '${s.current.toStringAsFixed(2)} A, '
          'cells ${s.cellVoltages.map((v) => v.toStringAsFixed(3)).join(' ')}';
    }
    if (frame.isDeviceInfo) {
      return 'device info ${parser.parseDeviceInfo(frame).model}';
    }
    return 'unrecognised fn=0x'
        '${frame.function.toRadixString(16).padLeft(2, '0')}';
  } on AntParseException catch (x) {
    return 'parse failed: ${x.message}';
  }
}

List<int> _bytes(String hexStr) => [
  for (var i = 0; i + 1 < hexStr.length; i += 2)
    int.parse(hexStr.substring(i, i + 2), radix: 16),
];
