import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/bms_write_gate.dart';
import 'package:jk_bms/src/ble/link_script.dart';
import 'package:jk_bms/src/model/bms_snapshot.dart';
import 'package:jk_bms/src/model/jk_settings.dart';
import 'package:jk_bms/src/protocol/bms_brand.dart';
import 'package:jk_bms/src/protocol/jk_commands.dart';
import 'package:jk_bms/src/protocol/jk_constants.dart';
import 'package:jk_bms/src/protocol/jk_frame.dart';
import 'package:jk_bms/src/protocol/jk_parser.dart';
import 'package:jk_bms/src/protocol/protocol_variant.dart';

import 'fixtures/real_kevinjk_frames.dart';

/// The app's first write path. Everything here is about the one property that
/// matters more than the feature: that nothing reaches a pack the rider did
/// not ask for, on a pack the bytes were not worked out for.
void main() {
  List<int> hex(String s) => [
    for (var i = 0; i < s.length; i += 2)
      int.parse(s.substring(i, i + 2), radix: 16),
  ];

  group('the write frame', () {
    // Worked out by hand from build_frame() and crc() in
    // syssi/esphome-jk-bms jk_bms_ble.cpp, not from this app's code:
    // AA 55 90 EB, register, length 04, value LE in bytes 6..9, zeros, and
    // byte 19 = (AA + 55 + 90 + EB + register + 04 + value) & FF.
    // AA+55+90+EB = 0x27A, so the sum is 0x27E + register + value.
    test('discharge off is the reference frame, checksum and all', () {
      expect(
        jkWriteRegisterCommand(0x1E, 0, length: 4),
        hex('AA5590EB1E0400000000000000000000000000' '9C'),
      );
    });

    test('every switch, both ways', () {
      final expected = {
        (0x1D, 1): 'AA5590EB1D0401000000000000000000000000' '9C',
        (0x1D, 0): 'AA5590EB1D0400000000000000000000000000' '9B',
        (0x1E, 1): 'AA5590EB1E0401000000000000000000000000' '9D',
        (0x1F, 1): 'AA5590EB1F0401000000000000000000000000' '9E',
        (0x1F, 0): 'AA5590EB1F0400000000000000000000000000' '9D',
      };
      for (final MapEntry(key: (reg, value), value: frame)
          in expected.entries) {
        expect(
          jkWriteRegisterCommand(reg, value, length: 4),
          hex(frame),
          reason: 'register 0x${reg.toRadixString(16)} value $value',
        );
      }
    });

    test('the read request is unchanged by the shared builder', () {
      // AA+55+90+EB+97 = 0x311: the device info request the app has always
      // sent on connect.
      expect(
        jkReadCommand(commandDeviceInfo),
        hex('AA5590EB970000000000000000000000000000' '11'),
      );
    });

    test('a value is little-endian across bytes 6 to 9', () {
      final f = jkWriteRegisterCommand(0x1D, 0x04030201, length: 4);
      expect(f.sublist(6, 10), [0x01, 0x02, 0x03, 0x04]);
    });

    test('a write of length 0 is refused, because that is a read', () {
      expect(
        () => jkWriteRegisterCommand(0x1E, 0, length: 0),
        throwsArgumentError,
      );
    });

    test('the read path can tell a write from a read', () {
      expect(isJkRegisterWrite(jkWriteRegisterCommand(0x1E, 0, length: 4)),
          isTrue);
      expect(isJkRegisterWrite(jkReadCommand(commandCellInfo)), isFalse);
      // Every frame either script can ever write is a read, so the guard on
      // the read path never refuses a request the app needs.
      for (final script in [LinkScript.jk(), LinkScript.ant]) {
        for (final f in [
          ...script.onConnect,
          script.askAgain,
          script.deviceInfo,
        ]) {
          expect(isJkRegisterWrite(f), isFalse);
        }
      }
    });
  });

  group('the registers', () {
    test('match the reference table on both JK02 framings, none on JK04', () {
      for (final v in [JkProtocolVariant.jk02_24s, JkProtocolVariant.jk02_32s]) {
        expect(BmsSwitch.charge.registerFor(v), 0x1D);
        expect(BmsSwitch.discharge.registerFor(v), 0x1E);
        expect(BmsSwitch.balancer.registerFor(v), 0x1F);
      }
      for (final s in BmsSwitch.values) {
        expect(s.registerFor(JkProtocolVariant.jk04), isNull);
      }
    });
  });

  group('the gate', () {
    final now = DateTime.utc(2026, 10, 1, 12);
    final settings = const JkParser().parseSettings(
      JkFrame(bytes: kevinJkSettings[0], receivedAt: now),
      JkProtocolVariant.jk02_32s,
    );
    final snapshot = const JkParser().parseCellInfo(
      JkFrame(bytes: kevinJkCellInfo[0], receivedAt: now),
      JkProtocolVariant.jk02_32s,
    );

    WriteContext ctx({
      bool permitted = true,
      BmsBrand brand = BmsBrand.jk,
      BleLinkState link = BleLinkState.connected,
      JkProtocolVariant? variant = JkProtocolVariant.jk02_32s,
      JkSettings? settingsFrame,
      bool noSettings = false,
      BmsSnapshot? reading,
      bool noReading = false,
      bool plausible = true,
      DateTime? at,
      bool riding = false,
      bool tripRecording = false,
      bool busy = false,
    }) => WriteContext(
      permitted: permitted,
      brand: brand,
      link: link,
      variant: variant,
      settings: noSettings ? null : (settingsFrame ?? settings),
      snapshot: noReading ? null : (reading ?? snapshot),
      snapshotPlausible: plausible,
      now: at ?? now,
      riding: riding,
      tripRecording: tripRecording,
      busy: busy,
    );

    WriteRefusal? refusal(WriteDecision d) =>
        d is WriteRefused ? d.reason : null;

    test('the real pack has all three switches on to begin with', () {
      expect(settings.chargeSwitchOn, isTrue);
      expect(settings.dischargeSwitchOn, isTrue);
      expect(settings.balancerSwitchOn, isTrue);
    });

    // The app is read-only again (2026-10-05). Everything below the first
    // test exercises the dormant gate through decideSwitchWriteAsIfShipped,
    // so it stays correct for whenever writes are reconsidered; the first
    // test is the one that matters today.
    test('while the writes are not shipped, nothing is ever granted', () {
      expect(bmsWritesShipped, isFalse);
      // Everything right, the stored permission on included: still refused,
      // and refused for the build, not for the preference.
      for (final s in BmsSwitch.values) {
        for (final on in [true, false]) {
          for (final permitted in [true, false]) {
            final d = decideSwitchWrite(
              s,
              on,
              ctx(
                permitted: permitted,
                // Discharge already on in the real settings, so ask for the
                // other state too: no request can slip through as granted.
                settingsFrame: settings,
              ),
            );
            expect(refusal(d), WriteRefusal.notShipped,
                reason: '${s.name} $on permitted=$permitted');
          }
        }
      }
    });

    test('with the permission off nothing else is even looked at', () {
      // Everything else wrong too: the permission is still the answer, so
      // the setting is the one thing that decides whether a frame exists.
      final d = decideSwitchWriteAsIfShipped(
        BmsSwitch.discharge,
        false,
        ctx(
          permitted: false,
          brand: BmsBrand.ant,
          link: BleLinkState.idle,
          variant: null,
          riding: true,
        ),
      );
      expect(refusal(d), WriteRefusal.notPermitted);
      for (final s in BmsSwitch.values) {
        for (final on in [true, false]) {
          expect(
            refusal(decideSwitchWriteAsIfShipped(s, on, ctx(permitted: false))),
            WriteRefusal.notPermitted,
          );
        }
      }
    });

    test('an ANT is never written to', () {
      expect(
        refusal(decideSwitchWriteAsIfShipped(BmsSwitch.balancer, false,
            ctx(brand: BmsBrand.ant))),
        WriteRefusal.notJk,
      );
    });

    test('JK04 and an unknown framing are refused', () {
      expect(
        refusal(decideSwitchWriteAsIfShipped(BmsSwitch.balancer, false,
            ctx(variant: JkProtocolVariant.jk04))),
        WriteRefusal.variantUnsupported,
      );
      expect(
        refusal(decideSwitchWriteAsIfShipped(BmsSwitch.charge, false,
            ctx(variant: null))),
        WriteRefusal.variantUnsupported,
      );
    });

    test('no link, no settings, an old reading or an impossible one', () {
      expect(
        refusal(decideSwitchWriteAsIfShipped(BmsSwitch.charge, false,
            ctx(link: BleLinkState.reconnecting))),
        WriteRefusal.notConnected,
      );
      expect(
        refusal(decideSwitchWriteAsIfShipped(BmsSwitch.charge, false,
            ctx(noSettings: true))),
        WriteRefusal.noSettings,
      );
      expect(
        refusal(decideSwitchWriteAsIfShipped(BmsSwitch.charge, false,
            ctx(noReading: true))),
        WriteRefusal.noRecentReading,
      );
      expect(
        refusal(decideSwitchWriteAsIfShipped(BmsSwitch.charge, false,
            ctx(at: now.add(const Duration(seconds: 11))))),
        WriteRefusal.noRecentReading,
      );
      expect(
        refusal(decideSwitchWriteAsIfShipped(BmsSwitch.charge, false,
            ctx(plausible: false))),
        WriteRefusal.readingImplausible,
      );
    });

    test('a switch already in that state is not written', () {
      expect(
        refusal(decideSwitchWriteAsIfShipped(BmsSwitch.discharge, true, ctx())),
        WriteRefusal.alreadySet,
      );
    });

    test('discharge off is refused while riding, however that is known', () {
      expect(
        refusal(decideSwitchWriteAsIfShipped(BmsSwitch.discharge, false,
            ctx(riding: true))),
        WriteRefusal.riding,
      );
      expect(
        refusal(decideSwitchWriteAsIfShipped(BmsSwitch.discharge, false,
            ctx(tripRecording: true))),
        WriteRefusal.riding,
      );
      // Drawing 2.5 A: the riding gate has not had its ten seconds yet, and
      // the bike may already be moving.
      expect(
        refusal(decideSwitchWriteAsIfShipped(BmsSwitch.discharge, false,
            ctx(reading: snapshot.withCurrent(-2.5)))),
        WriteRefusal.riding,
      );
    });

    test('a parked bike can be switched off: lights, or a wheel on a stand',
        () {
      for (final amps in [0.0, -0.44, -1.5]) {
        final d = decideSwitchWriteAsIfShipped(BmsSwitch.discharge, false,
            ctx(reading: snapshot.withCurrent(amps)));
        expect(d, isA<WriteGranted>(), reason: '$amps A');
      }
    });

    test('riding does not stop charge or balancer changes', () {
      expect(
        decideSwitchWriteAsIfShipped(BmsSwitch.charge, false, ctx(riding: true)),
        isA<WriteGranted>(),
      );
      expect(
        decideSwitchWriteAsIfShipped(BmsSwitch.balancer, false, ctx(riding: true)),
        isA<WriteGranted>(),
      );
    });

    test('one write at a time', () {
      expect(
        refusal(decideSwitchWriteAsIfShipped(BmsSwitch.balancer, false,
            ctx(busy: true))),
        WriteRefusal.busy,
      );
    });

    test('a granted write carries the reference frame', () {
      final d = decideSwitchWriteAsIfShipped(BmsSwitch.discharge, false, ctx());
      final w = (d as WriteGranted).write;
      expect(w.target, BmsSwitch.discharge);
      expect(w.on, isFalse);
      expect(w.address, 0x1E);
      expect(w.frame, hex('AA5590EB1E0400000000000000000000000000' '9C'));
      expect(w.hex, 'AA5590EB1E0400000000000000000000000000' '9C');
    });
  });
}
