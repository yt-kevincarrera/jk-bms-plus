import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/protocol/frame_assembler.dart';
import 'package:jk_bms/src/protocol/jk_checksum.dart';
import 'package:jk_bms/src/protocol/jk_constants.dart';
import 'package:jk_bms/src/protocol/jk_frame.dart';

import 'fixtures/captured_frames.dart';

/// Splits a frame the way BLE delivers it before MTU negotiation succeeds.
List<List<int>> chunked(Uint8List frame, int size) => [
      for (var i = 0; i < frame.length; i += size)
        frame.sublist(i, (i + size).clamp(0, frame.length)),
    ];

void main() {
  final clock = DateTime.utc(2026, 1, 1);
  FrameAssembler build() => FrameAssembler(clock: () => clock);

  group('checksum', () {
    test('every captured frame validates', () {
      final all = [...cellInfo24s, ...deviceInfoFrames, ...settingsFrames];
      expect(all, hasLength(11));
      for (final frame in all) {
        expect(frame, hasLength(responseFrameSize));
        expect(
          jkChecksum(frame, responseFrameSize - 1),
          frame[responseFrameSize - 1],
          reason: 'checksum mismatch on a frame captured from real hardware',
        );
      }
    });
  });

  group('FrameAssembler', () {
    test('reassembles a frame from 20-byte notification chunks', () {
      final a = build();
      final out = <JkFrame>[];
      for (final chunk in chunked(cellInfo24s[0], 20)) {
        out.addAll(a.addChunk(chunk));
      }

      expect(out, hasLength(1));
      expect(out.single.type, JkRecordType.cellInfo);
      expect(out.single.counter, 0x8C);
      expect(out.single.receivedAt, clock);
      expect(a.stats.accepted, 1);
      expect(a.stats.rejected, 0);
    });

    test('reassembles from a single large chunk when MTU negotiation worked',
        () {
      final a = build();
      final out = a.addChunk(cellInfo24s[0]);
      expect(out, hasLength(1));
      expect(a.stats.accepted, 1);
    });

    test('handles several frames arriving back to back', () {
      final a = build();
      final stream = <int>[
        ...cellInfo24s[0],
        ...cellInfo24s[1],
        ...cellInfo24s[2],
      ];
      final out = <JkFrame>[];
      for (final chunk in chunked(Uint8List.fromList(stream), 20)) {
        out.addAll(a.addChunk(chunk));
      }
      expect(out.map((f) => f.counter), [0x8C, 0x8D, 0x8E]);
      expect(a.stats.accepted, 3);
    });

    test('discards junk in front of the preamble', () {
      final a = build();
      final out = a.addChunk([
        ...[0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x01],
        ...cellInfo24s[0],
      ]);
      expect(out, hasLength(1));
      expect(out.single.counter, 0x8C);
      expect(a.stats.rejected, 0);
    });

    test('rejects a frame whose checksum was corrupted in transit', () {
      final a = build();
      final corrupt = Uint8List.fromList(cellInfo24s[0]);
      corrupt[100] ^= 0xFF;

      final rejections = <FrameRejection>[];
      a.onRejected = rejections.add;

      final out = a.addChunk(corrupt);
      expect(out, isEmpty);
      expect(rejections, [FrameRejection.badChecksum]);
      expect(a.stats.badChecksum, 1);
      expect(a.stats.accepted, 0);
    });

    test('a corrupt frame costs exactly one frame, not the one after it', () {
      final a = build();
      final corrupt = Uint8List.fromList(cellInfo24s[0]);
      corrupt[10] ^= 0x01;

      final out = a.addChunk([...corrupt, ...cellInfo24s[1]]);

      expect(out, hasLength(1));
      expect(out.single.counter, 0x8D);
      expect(a.stats.badChecksum, 1);
      expect(a.stats.accepted, 1);
    });

    test('resynchronises when a frame is truncated by a disconnect', () {
      final a = build();
      // Half a frame, then the link drops and a fresh frame starts.
      final out = a.addChunk([
        ...cellInfo24s[0].sublist(0, 137),
        ...cellInfo24s[2],
      ]);

      expect(out, hasLength(1));
      expect(out.single.counter, 0x8E);
    });

    test('a stub preamble in front of a real frame is skipped', () {
      final a = build();
      final out = a.addChunk([
        ...responsePreamble,
        ...responsePreamble,
        ...cellInfo24s[1],
      ]);
      expect(out, hasLength(1));
      expect(out.single.counter, 0x8D);
    });

    test('recovers cleanly after reset', () {
      final a = build();
      a.addChunk(cellInfo24s[0].sublist(0, 50));
      a.reset();
      final out = a.addChunk(cellInfo24s[1]);
      expect(out, hasLength(1));
      expect(out.single.counter, 0x8D);
    });

    test('a preamble split across two chunks is still found', () {
      final a = build();
      final frame = cellInfo24s[0];
      a.addChunk([0x11, 0x22, frame[0], frame[1]]);
      final out = a.addChunk(frame.sublist(2));
      expect(out, hasLength(1));
      expect(out.single.counter, 0x8C);
    });

    test('the buffer stays bounded under a sustained garbage stream', () {
      final a = build();
      // 60 KB of noise that never forms a valid frame.
      for (var i = 0; i < 3000; i++) {
        a.addChunk(List.generate(20, (k) => (i * 20 + k) & 0xFF));
        expect(a.bufferedBytes, lessThan(maxResponseBufferSize));
      }
      // And it still decodes the next real frame.
      a.reset();
      expect(a.addChunk(cellInfo24s[0]), hasLength(1));
    });

    test('tracks bytes received for link statistics', () {
      final a = build();
      a.addChunk(cellInfo24s[0]);
      expect(a.stats.bytesReceived, responseFrameSize);
      expect(a.stats.acceptRate, 1.0);
    });
  });
}
