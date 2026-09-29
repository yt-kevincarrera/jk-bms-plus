import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/link_script.dart';
import 'package:jk_bms/src/protocol/ant_constants.dart';
import 'package:jk_bms/src/protocol/jk_commands.dart';

String h(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  const quiet = Duration(seconds: 6);
  const mute = Duration(seconds: 20);
  final t0 = DateTime(2026, 9, 28, 20);

  test('JK read commands are byte-for-byte what the transport sent before', () {
    expect(jkReadCommand(0x97),
        [0xAA, 0x55, 0x90, 0xEB, 0x97, ...List.filled(14, 0), 0x11]);
    expect(jkReadCommand(0x96),
        [0xAA, 0x55, 0x90, 0xEB, 0x96, ...List.filled(14, 0), 0x10]);
  });

  test('JK connects with device info then cell info, ticks every 5 s', () {
    final s = LinkScript.jk();
    expect(s.onConnect, [jkReadCommand(0x97), jkReadCommand(0x96)]);
    expect(s.tickEvery, const Duration(seconds: 5));
    expect(s.askAgain, jkReadCommand(0x96));
  });

  test('JK stays silent while frames flow, nudges when quiet, lets go when mute', () {
    final s = LinkScript.jk();
    TickAction at(int secondsSinceFrame) => s.tick(
        now: t0.add(Duration(seconds: secondsSinceFrame)),
        lastFrameAt: t0,
        connectedAt: t0,
        tickNumber: 1,
        deviceInfoSeen: true,
        quietBefore: quiet,
        muteBefore: mute);
    expect(at(2), isA<NoAction>());
    final w = at(7) as WriteFrame;
    expect(w.bytes, jkReadCommand(0x96));
    expect(w.countsAsNudge, isTrue);
    expect(at(21), isA<ReleaseMute>());
  });

  test('ANT asks for status every tick, even while frames flow', () {
    final w = LinkScript.ant.tick(
        now: t0.add(const Duration(seconds: 2)),
        lastFrameAt: t0.add(const Duration(seconds: 1)),
        connectedAt: t0,
        tickNumber: 1,
        deviceInfoSeen: true,
        quietBefore: quiet,
        muteBefore: mute) as WriteFrame;
    expect(w.bytes, antStatusRequest);
    expect(w.countsAsNudge, isFalse);
    expect(LinkScript.ant.tickEvery, const Duration(seconds: 2));
    expect(LinkScript.ant.onConnect, [antDeviceInfoRequest, antStatusRequest]);
  });

  test('ANT repeats device info every fifth tick until it has one', () {
    WriteFrame at(int n, bool seen) => LinkScript.ant.tick(
        now: t0, lastFrameAt: t0, connectedAt: t0, tickNumber: n,
        deviceInfoSeen: seen, quietBefore: quiet, muteBefore: mute) as WriteFrame;
    expect(at(5, false).bytes, antDeviceInfoRequest);
    expect(at(6, false).bytes, antStatusRequest);
    expect(at(5, true).bytes, antStatusRequest);
  });

  test('read-only: across a long ANT session only the two requests are written', () {
    final written = <String>{};
    for (final f in LinkScript.ant.onConnect) {
      written.add(h(f));
    }
    for (var n = 1; n <= 500; n++) {
      final a = LinkScript.ant.tick(
          now: t0.add(Duration(seconds: 2 * n)),
          lastFrameAt: n % 7 == 0 ? null : t0.add(Duration(seconds: 2 * n - 3)),
          connectedAt: t0,
          tickNumber: n,
          deviceInfoSeen: n > 40,
          quietBefore: quiet,
          muteBefore: mute);
      if (a is WriteFrame) written.add(h(a.bytes));
    }
    written.add(h(LinkScript.ant.askAgain));
    expect(written, {h(antStatusRequest), h(antDeviceInfoRequest)});
    expect(LinkScript.ant.everyFrameHex, written);
  });
}
