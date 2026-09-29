# Soporte ANT BMS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Read a 2021+ ANT BMS over BLE with every feature the app already derives from readings, read-only, without changing JK behaviour.

**Architecture:** A pure ANT decoder (CRC, assembler, parser) sits beside the existing JK one. The BLE transport stops hard-coding JK commands and runs a `LinkScript` (pure data plus a pure tick decision) chosen per brand. `BmsService` routes bytes to the JK path (unchanged) or the ANT path, and both feed one shared "accept a snapshot" tail. The model grows a `BmsBrand`, the JK-only snapshot fields become nullable, and device info becomes brand-neutral.

**Tech Stack:** Flutter 3.41 / Dart, flutter_blue_plus, drift (codegen with build_runner), flutter_test, gen-l10n (`lib/l10n/app_es.arb` is the template).

**Spec:** `docs/superpowers/specs/2026-09-28-soporte-ant-design.md` (read it first; §3 holds the byte layout).

## Global Constraints

- Work only in the worktree `C:\Personal\Programming\Personal Projects\JK BMS\.claude\worktrees\soporte-ant`, branch `feat/soporte-ant`.
- Never `git add -A` or `git add .`; stage explicit paths. Run `git status` before every commit and stop if anything is not yours. Check `git log -1` after committing.
- Commit messages: no AI attribution, no Co-Authored-By trailers. Human author only.
- Read-only: the app never writes to an ANT anything other than `7E A1 01 00 00 BE 18 55 AA 55` (status) and `7E A1 02 6C 02 20 58 C4 AA 55` (device info). No constants for auth (0x23), write (0x51) or setting reads may exist.
- JK behaviour must not change: every byte the transport writes to a JK is identical to today, and the whole existing suite passes. Allowed edits to existing tests: type renames, the new `brand` argument, nullable field access.
- No em dashes (U+2014) anywhere: code comments, `.arb` strings, commit messages, docs.
- `.arb` files: edit surgically (add keys with Edit), never rewrite or reformat the whole file; they have CRLF/LF history that reformats wholesale.
- "null = este BMS no lo informa": a field ANT does not report is null in `BmsSnapshot`; the UI hides the row, it never shows 0.
- Run tests with `flutter test <file>`; full suite `flutter test`. Drift codegen: `dart run build_runner build --delete-conflicting-outputs`.
- Comment style: match the surrounding code (explain why, in full sentences, as the existing files do).

## Spec amendments decided while planning

These refine the approved spec after reading the code. Task 1 writes them into the spec file.

1. **JK decoding stays where it is.** The variant state and probing remain in `BmsService` untouched; there is no `JkProtocol` class. The seam is at the bytes (`_onBytes` routes by brand) and at the tail (`_acceptSnapshot`). Moving 400 lines of variant logic buys nothing for ANT and risks JK.
2. **`LinkScript` replaces the command half of `BmsProtocol`.** Commands are data; the tick decision (nudge, poll, release a mute link) is a pure function, so the read-only guarantee is testable without a radio.
3. **ANT -40 °C exactly is an unwired probe.** The real 14S/4T capture reads 28, 28, -40, 28 with the MOSFET and balancer at 28: the -40 input is empty. `AntParser` maps exactly -40 to `BmsSnapshot.absentProbeCelsius` (-200) so it is hidden and never trips a cold alert.
4. **No serial is `''`**, the existing `Devices.serialNumber` convention, not null.
5. **`Snapshots.cycleCount` stays non-null in the DB**; ANT rows store 0 there (recreating the largest table to make it nullable is not worth it). The live `BmsSnapshot.cycleCount` is null for ANT and nothing on screen reads the stored column.
6. **Diagnosis also goes to `LinkEvents`.** Raw frames are only stored once a pack is active (first decoded reading), so an ANT that never decodes would leave nothing. Rejected buffers and decode failures are also written as `LinkEvents` rows (deviceId may be null), which backups export unconditionally, capped at 20 per connection, with the hex in the detail.
7. **Passive detection needs a whole valid frame, and only before the chosen brand proves itself.** Matching two leading bytes of a notification would fire by chance inside a JK stream every few hours and switch a pack mid-ride. The other brand's assembler runs on the side until the chosen brand decodes its first frame; only a checksum-valid frame from it switches.

## Review Focus

1. A renamed ANT (name matches neither `^ANT[-@]` nor "JK") where the rider picks the wrong brand: silence, and the silence notice must name the other brand as the likely fix. Test in Task 8.
2. An ANT that answers status but never device info: readings must still flow and the pack must still be activated. Test in Task 8.
3. A link drop mid-frame: the ANT assembler must be reset on link down, so half a frame is not glued to the next session. Test in Task 8.
4. Auto-reconnect (proximity watcher) to a stored ANT calls `connect(id)` with no brand: the service must take the stored brand, not default to JK. Test in Task 8.
5. Entering demo mode after an ANT session: the simulator speaks JK, so brand and script must go back to JK. Test in Task 8.

---

## File Structure

New:
- `lib/src/protocol/bms_brand.dart`: `BmsBrand`, `brandFromName`, `BmsBrand.fromStored`.
- `lib/src/protocol/ant_crc.dart`: CRC-16/MODBUS.
- `lib/src/protocol/ant_constants.dart`: the two requests, function codes, status/MOSFET/balancer text tables, MOSFET-to-`BmsWarning` table.
- `lib/src/protocol/ant_frame.dart`: `AntFrame`, `AntRejection`, `AntRejected`.
- `lib/src/protocol/ant_frame_assembler.dart`: `AntFrameAssembler`.
- `lib/src/protocol/ant_parser.dart`: `AntParser`, `AntStatus`, `AntParseException`.
- `lib/src/protocol/jk_commands.dart`: `jkReadCommand(int register)` (moved out of the transport).
- `lib/src/protocol/raw_bms_frame.dart`: `RawBmsFrame`.
- `lib/src/ble/link_script.dart`: `LinkScript`, `TickAction`.
- `lib/src/model/bms_device_info.dart`: `BmsDeviceInfo`.
- Tests: `test/fixtures/ant_frames.dart`, `test/ant_crc_test.dart`, `test/ant_frame_assembler_test.dart`, `test/ant_parser_test.dart`, `test/link_script_test.dart`, `test/ant_service_test.dart`, `test/ant_backup_replay_test.dart`, `test/fixtures/ant_backup_synthetic.json`, `test/migration_15_test.dart`.

Modified (main ones): `bms_snapshot.dart`, `variant_prober.dart`, `jk_parser.dart`, `ble_transport.dart`, `bms_link.dart`, `switchable_link.dart`, `simulated_link.dart`, `bms_service.dart`, `database.dart` (+ regenerated `database.g.dart`), `repository.dart`, `backup.dart`, `exporter.dart`, `link_event.dart`, UI files listed per task, both `.arb` files, `test/support/fakes.dart`, `test/support/snapshot_builder.dart` (or wherever it lives: `grep -rl "JkProtocolVariant.jk02_24s" test/`).

---

### Task 1: Brand enum, ANT CRC, constants and fixtures

**Files:**
- Create: `lib/src/protocol/bms_brand.dart`, `lib/src/protocol/ant_crc.dart`, `lib/src/protocol/ant_constants.dart`, `test/fixtures/ant_frames.dart`, `test/ant_crc_test.dart`
- Modify: `docs/superpowers/specs/2026-09-28-soporte-ant-design.md` (append the six amendments above as a new "§11. Enmiendas del plan" section, in Spanish, no em dashes)

**Interfaces:**
- Produces: `enum BmsBrand { jk, ant }` with `String get stored` (`'jk'`/`'ant'`) and `static BmsBrand fromStored(String? s)` (null or unknown gives `jk`); `BmsBrand? brandFromName(String name)`; `int antCrc16(List<int> data, int start, int endExclusive)`; constants `antStatusRequest`, `antDeviceInfoRequest` (`List<int>`, unmodifiable), `antFnStatusReply = 0x11`, `antFnReadReply = 0x12`, `antDeviceInfoAddress = 0x026C`, `antMaxBuffer = 192`, `antChargeMosfetText`, `antDischargeMosfetText`, `antBalancerText`, `antBatteryStateText` (`List<String>`), `antChargeWarnings`, `antDischargeWarnings` (`Map<int, BmsWarning>`); fixtures `antStatus16s`, `antStatus14s4t`, `antInfo16zm`, `antInfo22ph` (`Uint8List`) and `hex(String)`.

- [ ] **Step 1: Write the fixtures file** `test/fixtures/ant_frames.dart`

```dart
import 'dart:typed_data';

/// Real ANT BMS (2021 protocol) frames, copied verbatim from
/// syssi/esphome-ant-bms: tests/components/ant_bms_ble/frames_16s_status.h,
/// docs/pdus/model2021-req-7ea1010000be1855aa55.txt and issue #172.
Uint8List hex(String s) {
  final clean = s.replaceAll(RegExp(r'\s+'), '');
  return Uint8List.fromList([
    for (var i = 0; i < clean.length; i += 2)
      int.parse(clean.substring(i, i + 2), radix: 16),
  ]);
}

/// 16S / 2T, 152 bytes. 52.84 V, +0.3 A, SOC 91, 280 Ah, 252.602325 Ah left,
/// probes 1 and 2 degC, MOSFET 2 degC, balancer 7 degC, both MOSFETs on.
final Uint8List antStatus16s = hex(
  '<paste the 16S/2T line from spec §9 verbatim, space-separated bytes>',
);

/// 14S / 4T, 152 bytes, real capture. 57.58 V, 0 A, SOC 96, 30 Ah,
/// probes 28, 28, -40 (unwired), 28. Discharge MOSFET reports 0x02.
final Uint8List antStatus14s4t = hex(
  '<paste the 14S/4T line from spec §9 verbatim>',
);

/// Device info "16ZM" / "16ZMUB00-211026A". 48 bytes although data_len says 0x20.
final Uint8List antInfo16zm = hex(
  '<paste the "16ZM" line from spec §9 verbatim>',
);

/// Device info "22PHB8TB130A" / "22AAUB00-241008A". Byte 26 is 0x55 ('U').
final Uint8List antInfo22ph = hex(
  '<paste the "22PHB8TB130A" line from spec §9 verbatim>',
);
```

Copy each hex line from the fenced blocks in spec §9 exactly (they are space-separated bytes, which `hex` accepts). Do not retype them: copy. Step 5's length and CRC checks prove the copy is exact.

- [ ] **Step 2: Write the failing test** `test/ant_crc_test.dart`

```dart
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
```

Note `'KevinJK'` contains "JK" so it is `jk`, matching today's `nameLooksLikeJk`. `'GIANT'` must not match (the ANT rule is anchored at the start).

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/ant_crc_test.dart`
Expected: FAIL, `ant_crc.dart` / `bms_brand.dart` not found.

- [ ] **Step 4: Implement** `bms_brand.dart`, `ant_crc.dart`, `ant_constants.dart`

```dart
// lib/src/protocol/bms_brand.dart
/// Which maker's protocol a pack speaks.
///
/// Both brands use the same GATT service and characteristic (FFE0/FFE1), so
/// nothing at the radio level tells them apart; the advertised name, the
/// rider's own answer and the bytes that arrive are what do.
enum BmsBrand {
  jk('jk'),
  ant('ant');

  const BmsBrand(this.stored);

  /// How it is written to the database and to backups.
  final String stored;

  /// Rows written before the app knew about a second brand have no value, and
  /// every one of them is a JK.
  static BmsBrand fromStored(String? s) =>
      s == ant.stored ? ant : jk;
}

final RegExp _antName = RegExp(r'^ANT[-@]', caseSensitive: false);

/// A hint from the advertised name, or null when it says nothing.
///
/// ANT modules advertise `ANT-BLE16ZMUB` or, on 2024+ boards, `ANT@BLE22AAUB`.
/// Anchored at the start so a pack a rider named "GIANT" is not taken for one.
BmsBrand? brandFromName(String name) {
  if (_antName.hasMatch(name)) return BmsBrand.ant;
  if (name.toUpperCase().contains('JK')) return BmsBrand.jk;
  return null;
}
```

```dart
// lib/src/protocol/ant_crc.dart
/// CRC-16/MODBUS: init 0xFFFF, reflected polynomial 0xA001, no final XOR.
///
/// Source: `crc16()` in syssi/esphome-ant-bms components/ant_bms_ble. ANT
/// computes it from byte 1 (the A1 after the 7E) through the last data byte
/// and stores it little-endian.
int antCrc16(List<int> data, int start, int endExclusive) {
  var crc = 0xFFFF;
  for (var i = start; i < endExclusive; i++) {
    crc ^= data[i] & 0xFF;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xA001 : crc >> 1;
    }
  }
  return crc & 0xFFFF;
}
```

```dart
// lib/src/protocol/ant_constants.dart
import '../model/bms_warning.dart';

/// Everything the app will ever write to an ANT BMS: two read requests.
///
/// The protocol also has an authentication frame and register writes that
/// switch MOSFETs, reset the pack and so on. They are deliberately not here,
/// not even as constants: this app is read-only, and a write path that does
/// not exist cannot be reached by mistake.
const List<int> antStatusRequest = [
  0x7E, 0xA1, 0x01, 0x00, 0x00, 0xBE, 0x18, 0x55, 0xAA, 0x55, //
];
const List<int> antDeviceInfoRequest = [
  0x7E, 0xA1, 0x02, 0x6C, 0x02, 0x20, 0x58, 0xC4, 0xAA, 0x55, //
];

const int antFnStatusReply = 0x11;
const int antFnReadReply = 0x12;
const int antDeviceInfoAddress = 0x026C;

/// The reference drops its buffer past this; the largest status frame
/// (32 cells, 4 probes) is 188 bytes.
const int antMaxBuffer = 192;

const List<String> antBatteryStateText = [
  'Unknown', 'Idle', 'Charge', 'Discharge', 'Standby', 'Error', //
];

const List<String> antChargeMosfetText = [
  'Off', 'On', 'Overcharge protection', 'Over current protection',
  'Battery full', 'Total overpressure', 'Battery over temperature',
  'MOSFET over temperature', 'Abnormal current', 'Balanced line dropped string',
  'Motherboard over temperature', 'Reserved', 'Open failed',
  'Discharge MOSFET abnormality', 'Waiting', 'Manually turned off',
  'Two level exceed voltage', 'Low temperature protection',
  'Voltage difference exceeded', 'Reserved', 'Self detect error', //
];

const List<String> antDischargeMosfetText = [
  'Off', 'On', 'Overdischarge protection', 'Over current protection',
  'Two current exceeded', 'Total pressure undervoltage',
  'Battery over temperature', 'MOSFET over temperature', 'Abnormal current',
  'Balanced line dropped string', 'Motherboard over temperature',
  'Charge MOSFET on', 'Short circuit protection',
  'Discharge MOSFET abnormality', 'Open failed', 'Manually turned off',
  'Two level low voltage', 'Low temperature protection',
  'Voltage difference exceeded', 'Self detect error', //
];

const List<String> antBalancerText = [
  'Off', 'Exceeds the limit equilibrium', 'Charge differential pressure balance',
  'Balanced over temperature', 'Automatic equalization', 'Unknown', 'Unknown',
  'Unknown', 'Unknown', 'Unknown', 'Motherboard over temperature', //
];

/// Text for a code, or "Unknown (0xNN)" past the end of the table.
String antText(List<String> table, int code) => code < table.length
    ? table[code]
    : 'Unknown (0x${code.toRadixString(16).padLeft(2, '0')})';

/// Why the charge MOSFET is off, in the app's own warning vocabulary.
///
/// A closed table (spec §5.2). Codes with no clear equivalent produce no bit
/// and are shown as text instead; inventing a mapping would put words in the
/// BMS's mouth.
const Map<int, BmsWarning> antChargeWarnings = {
  0x02: BmsWarning.packOvervoltage, // JK02 has no cell-overvoltage bit
  0x03: BmsWarning.chargeOvercurrent,
  0x04: BmsWarning.batteryFullyCharged,
  0x05: BmsWarning.packOvervoltage,
  0x06: BmsWarning.chargeOvertemperature,
  0x07: BmsWarning.mosfetOvertemperature,
  0x11: BmsWarning.chargeUndertemperature,
};

const Map<int, BmsWarning> antDischargeWarnings = {
  0x02: BmsWarning.cellUndervoltage,
  0x03: BmsWarning.dischargeOvercurrent,
  0x04: BmsWarning.dischargeOcpII,
  0x05: BmsWarning.packUndervoltage,
  0x06: BmsWarning.dischargeOvertemperature,
  0x07: BmsWarning.mosfetOvertemperature,
  0x0C: BmsWarning.dischargeShortCircuit,
  0x0D: BmsWarning.dischargingMosfetAbnormal,
  0x0E: BmsWarning.dischargeOnFailed,
  0x11: BmsWarning.dischargeUndertemperatureAlarm,
};
```

If `dart format` would reflow the `//`-terminated lists, keep them as `dart format` leaves them; the trailing `//` only exists to stop it collapsing short lists onto one line.

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/ant_crc_test.dart`
Expected: PASS (5 tests). If a fixture length or CRC fails, the fixture hex was mistyped: compare it byte by byte with spec §9, do not change the CRC code.

- [ ] **Step 6: Append the amendments to the spec** (section "## 11. Enmiendas del plan", the seven items from this plan's "Spec amendments" list, translated to Spanish).

- [ ] **Step 7: Commit**

```bash
git add lib/src/protocol/bms_brand.dart lib/src/protocol/ant_crc.dart lib/src/protocol/ant_constants.dart test/fixtures/ant_frames.dart test/ant_crc_test.dart docs/superpowers/specs/2026-09-28-soporte-ant-design.md
git commit -m "Add the ANT brand, its CRC and its two read requests"
```

---

### Task 2: ANT frame assembler

**Files:**
- Create: `lib/src/protocol/ant_frame.dart`, `lib/src/protocol/ant_frame_assembler.dart`, `test/ant_frame_assembler_test.dart`

**Interfaces:**
- Consumes: `antCrc16`, `antMaxBuffer`, `antFnReadReply`, `antDeviceInfoAddress`, `antFnStatusReply`, `FrameStats` (from `jk_frame.dart`).
- Produces:
  - `class AntFrame { Uint8List bytes; DateTime receivedAt; int get function; int get address; int get dataLength; bool get isStatus; bool get isDeviceInfo; }`
  - `enum AntRejection { badCrc, badLength, notAFrame, overflow }`
  - `class AntRejected { AntRejection reason; Uint8List bytes; }`
  - `class AntFrameAssembler { AntFrameAssembler({DateTime Function()? clock}); FrameStats stats; void Function(AntRejected)? onRejected; List<AntFrame> addChunk(List<int> chunk); void reset(); int get bufferedBytes; }`

- [ ] **Step 1: Write the failing test**

```dart
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
      for (final f in [antStatus16s, antStatus14s4t, antInfo16zm, antInfo22ph]) {
        final out = feed(f, chunk);
        expect(out, hasLength(1));
        expect(out.single.bytes, f);
      }
      expect(rejected, isEmpty);
      expect(a.stats.accepted, 4);
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/ant_frame_assembler_test.dart`
Expected: FAIL, files not found.

- [ ] **Step 3: Implement**

```dart
// lib/src/protocol/ant_frame.dart
import 'dart:typed_data';

import 'ant_constants.dart';

/// One CRC-valid ANT response, preamble and trailer included.
class AntFrame {
  AntFrame({required this.bytes, required this.receivedAt});

  final Uint8List bytes;

  /// Phone clock, UTC.
  final DateTime receivedAt;

  /// Request function + 0x10: 0x11 status, 0x12 read (device info, settings).
  int get function => bytes[2];
  int get address => bytes[3] | (bytes[4] << 8);
  int get dataLength => bytes[5];

  bool get isStatus => function == antFnStatusReply;
  bool get isDeviceInfo =>
      function == antFnReadReply && address == antDeviceInfoAddress;
}

enum AntRejection {
  /// Shape was right, CRC was not.
  badCrc,

  /// Ended in AA 55 but the length disagrees with data_len.
  badLength,

  /// Ended in AA 55 without ever starting with 7E A1.
  notAFrame,

  /// Grew past [antMaxBuffer] without ending.
  overflow,
}

/// A buffer the assembler threw away, kept whole so it can be written down.
class AntRejected {
  const AntRejected(this.reason, this.bytes);
  final AntRejection reason;
  final Uint8List bytes;
}
```

```dart
// lib/src/protocol/ant_frame_assembler.dart
import 'dart:typed_data';

import 'ant_constants.dart';
import 'ant_crc.dart';
import 'ant_frame.dart';
import 'jk_frame.dart' show FrameStats;

/// Reassembles ANT responses from BLE notifications.
///
/// Follows `AntBmsBle::assemble()` in syssi/esphome-ant-bms: a notification
/// that starts with 7E A1 opens a new frame, the buffer is dropped past 192
/// bytes, and a frame ends when the last *two* bytes are AA 55. Checking one
/// byte is not enough: device info carries ASCII, and 'U' is 0x55.
class AntFrameAssembler {
  AntFrameAssembler({DateTime Function()? clock})
      : _clock = clock ?? (() => DateTime.now().toUtc());

  final DateTime Function() _clock;
  final BytesBuilder _buffer = BytesBuilder(copy: true);
  final FrameStats stats = FrameStats();

  void Function(AntRejected rejected)? onRejected;

  int get bufferedBytes => _buffer.length;

  void reset() => _buffer.clear();

  List<AntFrame> addChunk(List<int> chunk) {
    stats.bytesReceived += chunk.length;
    if (chunk.isEmpty) return const [];

    if (chunk.length >= 2 && chunk[0] == 0x7E && chunk[1] == 0xA1) {
      _buffer.clear();
    }
    if (_buffer.length > antMaxBuffer) {
      _reject(AntRejection.overflow, _buffer.takeBytes());
    }
    _buffer.add(chunk);

    final data = _buffer.toBytes();
    final n = data.length;
    if (n < 10 || data[n - 2] != 0xAA || data[n - 1] != 0x55) return const [];

    _buffer.clear();
    if (data[0] != 0x7E || data[1] != 0xA1) {
      _reject(AntRejection.notAFrame, data);
      return const [];
    }

    // Device info declares 0x20 bytes of data and carries 48 bytes in all;
    // its CRC is still where data_len says. Every other frame is exact.
    final isInfo = data[2] == antFnReadReply &&
        (data[3] | (data[4] << 8)) == antDeviceInfoAddress;
    final crcAt = 6 + data[5];
    final lengthOk = isInfo ? n >= crcAt + 4 : n == crcAt + 4;
    if (!lengthOk) {
      _reject(AntRejection.badLength, data);
      return const [];
    }

    final declared = data[crcAt] | (data[crcAt + 1] << 8);
    if (antCrc16(data, 1, crcAt) != declared) {
      stats.badChecksum++;
      _reject(AntRejection.badCrc, data);
      return const [];
    }

    stats.accepted++;
    return [AntFrame(bytes: data, receivedAt: _clock())];
  }

  void _reject(AntRejection reason, Uint8List bytes) =>
      onRejected?.call(AntRejected(reason, bytes));
}
```

Note: `badLength`/`notAFrame`/`overflow` do not bump `stats.badChecksum`; `FrameStats.rejected` is only checksum today and stays that way for JK. The overflow test appends `[0x11]` to a 202-byte buffer: the check runs before append, rejects, and the buffer then holds 1 byte.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/ant_frame_assembler_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/protocol/ant_frame.dart lib/src/protocol/ant_frame_assembler.dart test/ant_frame_assembler_test.dart
git commit -m "Reassemble ANT frames the way the reference does"
```

---

### Task 3: Brand-neutral BmsSnapshot

**Files:**
- Modify: `lib/src/model/bms_snapshot.dart`, `lib/src/protocol/jk_parser.dart` (every `BmsSnapshot(` it builds), `lib/src/protocol/variant_prober.dart:63-64`, `lib/src/pack/pack_baseline.dart:108,312`, `lib/src/ui/tabs/cells_tab.dart:105-158`, `lib/src/ui/tabs/thermal_tab.dart:127-133`, `lib/src/data/repository.dart:77`, `lib/src/ui/tabs/now_tab.dart:94`, `lib/src/ui/live_console_screen.dart` (variant name use), the test snapshot builder (`grep -rl "JkProtocolVariant.jk02_24s" test/`), and every other site the compiler flags.
- Test: `test/bms_snapshot_brand_test.dart` (create)

**Interfaces:**
- Consumes: `BmsBrand` (Task 1).
- Produces on `BmsSnapshot`: `required BmsBrand brand`; `JkProtocolVariant? variant`; nullable `int? frameCounter`, `List<double>? cellResistances`, `int? enabledCellMask`, `int? temperatureSensorMask`, `int? balancingAction`, `double? balanceCurrent`, `int? wireResistanceWarningMask`, `bool? heatingOn`, `double? heatingCurrent`, `int? cycleCount`. `toJson` gains `'brand': brand.stored` and writes `variant?.name`.

- [ ] **Step 1: Write the failing test** `test/bms_snapshot_brand_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/model/bms_snapshot.dart';
import 'package:jk_bms/src/model/bms_warning.dart';
import 'package:jk_bms/src/protocol/bms_brand.dart';
import 'package:jk_bms/src/protocol/variant_prober.dart';

BmsSnapshot antLike() => BmsSnapshot(
      timestamp: DateTime.utc(2026, 9, 28),
      brand: BmsBrand.ant,
      variant: null,
      frameCounter: null,
      cellVoltages: List.filled(16, 3.3),
      cellResistances: null,
      enabledCellMask: null,
      packVoltage: 52.8,
      current: 0.3,
      temperatures: const [20, 21],
      temperatureSensorMask: null,
      mosfetTemp: 22,
      soc: 91,
      soh: 100,
      remainingCapacityAh: 250,
      nominalCapacityAh: 280,
      cycleCount: null,
      cycleCapacityAh: 4862,
      balancingAction: null,
      balanceCurrent: null,
      chargeMosfetOn: true,
      dischargeMosfetOn: true,
      balancerActive: false,
      heatingOn: null,
      warnings: BmsWarnings.none,
      wireResistanceWarningMask: null,
      heatingCurrent: null,
      totalRuntimeSeconds: 100,
    );

void main() {
  test('an ANT reading carries its brand and no JK-only fields', () {
    final j = antLike().toJson();
    expect(j['brand'], 'ant');
    expect(j['variant'], isNull);
    expect(j['cellResistances'], isNull);
    expect(j['cycleCount'], isNull);
  });

  test('plausibility judges a reading with no JK variant', () {
    expect(const Plausibility().reject(antLike()), isEmpty);
  });

  test('balancing inference works without a balancing action', () {
    expect(antLike().inferredBalancingCells, List.filled(16, false));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/bms_snapshot_brand_test.dart`
Expected: FAIL to compile (`brand` is not a parameter, `variant` cannot be null).

- [ ] **Step 3: Change `BmsSnapshot`**

In the constructor add `required this.brand,` right after `required this.timestamp,`. Change the listed fields' types to nullable (keep them `required` so every construction site has to decide explicitly). Add:

```dart
  /// Which maker's protocol produced this reading.
  final BmsBrand brand;

  /// JK framing this was decoded with. Null for every other brand.
  final JkProtocolVariant? variant;
```

Update the doc of each newly nullable field with one line: "Null when the BMS does not report it (ANT does not)." In `toJson`: `'brand': brand.stored,`, `'variant': variant?.name,`, and for `enabledCellMask` write `enabledCellMask == null ? null : '0x${...}'`.

`inferredBalancingCells`: `balancingAction == 0x02` already handles null (false), no change.

- [ ] **Step 4: Fix `Plausibility`** in `variant_prober.dart:63`

```dart
    final slots = s.variant?.cellSlots ?? 32;
    if (s.cellCount > slots) {
      reasons.add('${s.cellCount} cells in $slots slots');
    }
```

(32 is the most cells an ANT status frame can declare; spec §5.1.)

- [ ] **Step 5: Fix every construction and consumer the compiler flags**

Run: `flutter analyze` and fix each error with the rule:
- `JkParser` (every `BmsSnapshot(`): pass `brand: BmsBrand.jk`; values unchanged.
- Test snapshot builder: add `brand: BmsBrand.jk`.
- `repository.dart:77`: `cycleCount: (s.cycleCount ?? 0).toDouble(),` with a comment: "ANT reports no cycle count; the column predates nullable readings and nothing on screen reads it back (spec §11.5)."
- `pack_baseline.dart:108`: `cellResistances: List<double>.from(snapshot.cellResistances ?? const [])` (the baseline already treats empty as "not captured", see its `if (cellResistances.isNotEmpty)`). Same pattern at :312.
- `cells_tab.dart`: wrap the resistance column/row, the balance-current row, the balancing-action row and the wire-resistance row in `if (s.X != null)`; inside, use `s.X!`. For the balancing switch at :136 use `switch (s.balancingAction!)`.
- `thermal_tab.dart`: same for the sensor-mask row, the heater row (`s.heatingOn`) and the heater-current row.
- `now_tab.dart:94` and `live_console_screen.dart`: `s.variant?.name ?? s.brand.name.toUpperCase()`.
- Any `frameCounter` read: none in lib today; if the compiler finds one, guard it.

- [ ] **Step 6: Run the new test and the full suite**

Run: `flutter test test/bms_snapshot_brand_test.dart` then `flutter test`
Expected: all PASS. JK tests must pass with no change beyond the builder's `brand:`.

- [ ] **Step 7: Commit** (stage each modified file by path; `git status` first)

```bash
git commit -m "Let a reading say which brand it came from and what it does not report"
```

---

### Task 4: ANT parser

**Files:**
- Create: `lib/src/protocol/ant_parser.dart`, `test/ant_parser_test.dart`
- Create: `lib/src/model/bms_device_info.dart` (the parser returns it; Task 5 wires it into the service)

**Interfaces:**
- Consumes: `AntFrame`, `BmsSnapshot` (Task 3), `BmsBrand`, `antChargeWarnings`, `antDischargeWarnings`, `BmsWarnings`.
- Produces:
  - `class BmsDeviceInfo { BmsBrand brand; DateTime receivedAt; String model; String softwareVersion; String hardwareVersion; String serialNumber; JkDeviceInfo? jk; JkProtocolVariant? get variant; factory BmsDeviceInfo.fromJk(JkDeviceInfo); Map<String, Object?> toJson(); }` (`hardwareVersion`, `serialNumber` default `''`)
  - `class AntStatus { BmsSnapshot snapshot; int batteryState; int chargeMosfetCode; int dischargeMosfetCode; int balancerCode; double balancerTemp; int balancingCellMask; }`
  - `class AntParseException implements Exception { String message; }`
  - `class AntParser { const AntParser(); AntStatus parseStatus(AntFrame f); BmsDeviceInfo parseDeviceInfo(AntFrame f); }`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/model/bms_snapshot.dart';
import 'package:jk_bms/src/model/bms_warning.dart';
import 'package:jk_bms/src/protocol/ant_frame.dart';
import 'package:jk_bms/src/protocol/ant_parser.dart';
import 'package:jk_bms/src/protocol/bms_brand.dart';

import 'fixtures/ant_frames.dart';

AntFrame frame(List<int> b) => AntFrame(
    bytes: Uint8List.fromList(b), receivedAt: DateTime.utc(2026, 9, 28));

void main() {
  const p = AntParser();

  group('16S / 2T fixture', () {
    final st = p.parseStatus(frame(antStatus16s));
    final s = st.snapshot;

    test('identity', () {
      expect(s.brand, BmsBrand.ant);
      expect(s.variant, isNull);
      expect(s.cellCount, 16);
    });
    test('cells', () {
      expect(s.cellVoltages.first, closeTo(3.300, 1e-9));
      expect(s.cellVoltages.last, closeTo(3.305, 1e-9));
    });
    test('pack, current, charge', () {
      expect(s.packVoltage, closeTo(52.84, 1e-9));
      // Positive while charging, same as the app's convention: not inverted.
      expect(s.current, closeTo(0.3, 1e-9));
      expect(s.isCharging, isTrue);
      expect(s.soc, 91);
      expect(s.soh, 100);
    });
    test('temperatures', () {
      expect(s.temperatures, [1.0, 2.0]);
      expect(s.mosfetTemp, 2.0);
      expect(st.balancerTemp, 7.0);
    });
    test('capacities and runtime', () {
      expect(s.nominalCapacityAh, closeTo(280.0, 1e-6));
      expect(s.remainingCapacityAh, closeTo(252.602325, 1e-6));
      expect(s.cycleCapacityAh, closeTo(4862.65, 1e-6));
      expect(s.totalRuntimeSeconds, 0x022E5810);
    });
    test('MOSFETs, balancer, no warnings', () {
      expect(s.chargeMosfetOn, isTrue);
      expect(s.dischargeMosfetOn, isTrue);
      expect(s.balancerActive, isFalse);
      expect(s.warnings.active, isEmpty);
    });
    test('JK-only fields are null, not zero', () {
      expect(s.cellResistances, isNull);
      expect(s.cycleCount, isNull);
      expect(s.frameCounter, isNull);
      expect(s.heatingOn, isNull);
    });
  });

  group('14S / 4T real capture', () {
    final st = p.parseStatus(frame(antStatus14s4t));
    final s = st.snapshot;

    test('values', () {
      expect(s.cellCount, 14);
      expect(s.packVoltage, closeTo(57.58, 1e-9));
      expect(s.current, 0);
      expect(s.soc, 96);
      expect(s.nominalCapacityAh, closeTo(30.0, 1e-6));
      expect(s.remainingCapacityAh, closeTo(28.53, 1e-6));
    });
    test('an exact -40 degC is an unwired probe and is hidden', () {
      expect(s.temperatures[2], BmsSnapshot.absentProbeCelsius);
      expect(s.connectedTemperatures.map((t) => t.index), [0, 1, 3]);
      expect(s.plausibleTemperatures, [28.0, 28.0, 28.0]);
    });
    test('discharge MOSFET 0x02 is reported literally', () {
      expect(st.dischargeMosfetCode, 0x02);
      expect(s.dischargeMosfetOn, isFalse);
      expect(s.warnings.active, {BmsWarning.cellUndervoltage});
    });
  });

  group('warning table', () {
    for (final e in {
      (true, 0x02): BmsWarning.packOvervoltage,
      (true, 0x03): BmsWarning.chargeOvercurrent,
      (true, 0x04): BmsWarning.batteryFullyCharged,
      (true, 0x05): BmsWarning.packOvervoltage,
      (true, 0x06): BmsWarning.chargeOvertemperature,
      (true, 0x07): BmsWarning.mosfetOvertemperature,
      (true, 0x11): BmsWarning.chargeUndertemperature,
      (false, 0x02): BmsWarning.cellUndervoltage,
      (false, 0x03): BmsWarning.dischargeOvercurrent,
      (false, 0x04): BmsWarning.dischargeOcpII,
      (false, 0x05): BmsWarning.packUndervoltage,
      (false, 0x06): BmsWarning.dischargeOvertemperature,
      (false, 0x07): BmsWarning.mosfetOvertemperature,
      (false, 0x0C): BmsWarning.dischargeShortCircuit,
      (false, 0x0D): BmsWarning.dischargingMosfetAbnormal,
      (false, 0x0E): BmsWarning.dischargeOnFailed,
      (false, 0x11): BmsWarning.dischargeUndertemperatureAlarm,
    }.entries) {
      test('${e.key.$1 ? "charge" : "discharge"} 0x${e.key.$2.toRadixString(16)}', () {
        expect(antWarnings(charge: e.key.$1 ? e.key.$2 : 1,
                discharge: e.key.$1 ? 1 : e.key.$2).active,
            {e.value});
      });
    }
    test('off, on, manual and unknown codes raise nothing', () {
      for (final c in [0x00, 0x01, 0x0F, 0x13, 0x55]) {
        expect(antWarnings(charge: c, discharge: c).active, isEmpty);
      }
    });
  });

  group('device info', () {
    test('16ZM', () {
      final i = p.parseDeviceInfo(frame(antInfo16zm));
      expect(i.brand, BmsBrand.ant);
      expect(i.model, '16ZM');
      expect(i.softwareVersion, '16ZMUB00-211026A');
      expect(i.serialNumber, '');
      expect(i.jk, isNull);
    });
    test('22PH', () {
      final i = p.parseDeviceInfo(frame(antInfo22ph));
      expect(i.model, '22PHB8TB130A');
      expect(i.softwareVersion, '22AAUB00-241008A');
    });
  });

  test('a frame whose cell count disagrees with its length throws', () {
    final wrong = List<int>.from(antStatus16s)..[9] = 17;
    expect(() => p.parseStatus(frame(wrong)), throwsA(isA<AntParseException>()));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/ant_parser_test.dart`
Expected: FAIL, files not found.

- [ ] **Step 3: Implement `bms_device_info.dart`**

```dart
import '../protocol/bms_brand.dart';
import '../protocol/protocol_variant.dart';
import 'jk_device_info.dart';

/// Who the pack says it is, in terms every brand can answer.
///
/// JK says a great deal more (passcodes, power-on count, the variant it
/// implies); that stays reachable through [jk]. ANT says a model and a
/// software string and has no serial number at all, which is written as ''
/// like every other unknown serial in this app.
class BmsDeviceInfo {
  const BmsDeviceInfo({
    required this.brand,
    required this.receivedAt,
    required this.model,
    required this.softwareVersion,
    this.hardwareVersion = '',
    this.serialNumber = '',
    this.jk,
  });

  factory BmsDeviceInfo.fromJk(JkDeviceInfo info) => BmsDeviceInfo(
        brand: BmsBrand.jk,
        receivedAt: info.receivedAt,
        model: info.model,
        softwareVersion: info.softwareVersion,
        hardwareVersion: info.hardwareVersion,
        serialNumber: info.serialNumber,
        jk: info,
      );

  final BmsBrand brand;
  final DateTime receivedAt;
  final String model;
  final String softwareVersion;
  final String hardwareVersion;
  final String serialNumber;
  final JkDeviceInfo? jk;

  JkProtocolVariant? get variant => jk?.variant;

  Map<String, Object?> toJson() => jk?.toJson() ?? {
        'brand': brand.stored,
        'receivedAt': receivedAt.toIso8601String(),
        'model': model,
        'softwareVersion': softwareVersion,
        'hardwareVersion': hardwareVersion,
        'serialNumber': serialNumber,
      };
}
```

- [ ] **Step 4: Implement `ant_parser.dart`**

```dart
import 'dart:convert';

import '../model/bms_device_info.dart';
import '../model/bms_snapshot.dart';
import '../model/bms_warning.dart';
import 'ant_constants.dart';
import 'ant_frame.dart';
import 'bms_brand.dart';

class AntParseException implements Exception {
  const AntParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A decoded status frame: the reading, plus the ANT-only details the System
/// tab shows as text.
class AntStatus {
  const AntStatus({
    required this.snapshot,
    required this.batteryState,
    required this.chargeMosfetCode,
    required this.dischargeMosfetCode,
    required this.balancerCode,
    required this.balancerTemp,
    required this.balancingCellMask,
  });

  final BmsSnapshot snapshot;
  final int batteryState;
  final int chargeMosfetCode;
  final int dischargeMosfetCode;
  final int balancerCode;
  final double balancerTemp;
  final int balancingCellMask;
}

/// The MOSFET codes, in the app's warning vocabulary (spec §5.2).
BmsWarnings antWarnings({required int charge, required int discharge}) {
  var mask = 0;
  final c = antChargeWarnings[charge];
  final d = antDischargeWarnings[discharge];
  if (c != null) mask |= 1 << c.bit;
  if (d != null) mask |= 1 << d.bit;
  return BmsWarnings.fromBitmask(mask);
}

/// Decodes ANT 2021 frames. Layout: `ant_bms_ble.cpp` in
/// syssi/esphome-ant-bms, reproduced in spec §3.4. Everything little-endian.
class AntParser {
  const AntParser();

  /// What an ANT reads on a probe input with nothing wired to it. The real
  /// 14S capture shows three probes at 28 degC and the fourth at exactly -40,
  /// with the MOSFET and balancer also at 28: that input is empty.
  static const double unwiredProbeCelsius = -40;

  AntStatus parseStatus(AntFrame f) {
    final b = f.bytes;
    if (!f.isStatus) {
      throw AntParseException(
          'Not a status frame (function 0x${f.function.toRadixString(16)}).');
    }
    final t = b[8];
    final n = b[9];
    if (n == 0 || n > 32 || t > 8) {
      throw AntParseException('Implausible layout: $n cells, $t probes.');
    }
    final expected = 116 + 2 * (n + t);
    if (b.length != expected) {
      throw AntParseException(
          '$n cells and $t probes need $expected bytes, frame has ${b.length}.');
    }
    final o = 2 * n + 2 * t;

    int u16(int i) => b[i] | (b[i + 1] << 8);
    int i16(int i) => u16(i).toSigned(16);
    int u32(int i) => u16(i) | (u16(i + 2) << 16);
    int i32(int i) => u32(i).toSigned(32);

    final probes = [
      for (var j = 0; j < t; j++)
        i16(34 + 2 * n + 2 * j).toDouble() == unwiredProbeCelsius
            ? BmsSnapshot.absentProbeCelsius
            : i16(34 + 2 * n + 2 * j).toDouble(),
    ];
    final charge = b[46 + o];
    final discharge = b[47 + o];
    final balancer = b[48 + o];

    final snapshot = BmsSnapshot(
      timestamp: f.receivedAt,
      brand: BmsBrand.ant,
      variant: null,
      frameCounter: null,
      cellVoltages: [for (var i = 0; i < n; i++) u16(34 + 2 * i) / 1000],
      cellResistances: null,
      enabledCellMask: null,
      packVoltage: u16(38 + o) / 100,
      // Positive while charging, which is already this app's convention.
      current: i16(40 + o) / 10,
      temperatures: probes,
      temperatureSensorMask: null,
      mosfetTemp: i16(34 + o).toDouble(),
      soc: i16(42 + o).toDouble(),
      soh: u16(44 + o).toDouble(),
      remainingCapacityAh: u32(54 + o) / 1e6,
      nominalCapacityAh: u32(50 + o) / 1e6,
      cycleCount: null,
      cycleCapacityAh: u32(58 + o) / 1000,
      balancingAction: null,
      balanceCurrent: null,
      chargeMosfetOn: charge == 0x01,
      dischargeMosfetOn: discharge == 0x01,
      balancerActive: balancer != 0,
      heatingOn: null,
      warnings: antWarnings(charge: charge, discharge: discharge),
      wireResistanceWarningMask: null,
      heatingCurrent: null,
      totalRuntimeSeconds: u32(66 + o),
    );
    // Power (62+o, i32) is not stored: BmsSnapshot.power is V x I, one place.
    assert(i32(62 + o) == i32(62 + o));
    return AntStatus(
      snapshot: snapshot,
      batteryState: b[7],
      chargeMosfetCode: charge,
      dischargeMosfetCode: discharge,
      balancerCode: balancer,
      balancerTemp: i16(36 + o).toDouble(),
      balancingCellMask: u32(70 + o),
    );
  }

  BmsDeviceInfo parseDeviceInfo(AntFrame f) {
    if (!f.isDeviceInfo || f.bytes.length < 38) {
      throw const AntParseException('Not a device info frame.');
    }
    String ascii(int from) => latin1
        .decode(f.bytes.sublist(from, from + 16))
        .replaceAll('\u0000', '')
        .trim();
    return BmsDeviceInfo(
      brand: BmsBrand.ant,
      receivedAt: f.receivedAt,
      model: ascii(6),
      softwareVersion: ascii(22),
    );
  }
}
```

Remove the `assert(i32(...))` line and the `i32` helper if the analyzer flags `i32` as unused; it is only there to document that power exists and is ignored. Prefer deleting both and keeping the comment.

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/ant_parser_test.dart`
Expected: PASS. The 16S last cell: bytes `E9 0C` = 3305 mV.

- [ ] **Step 6: Commit**

```bash
git add lib/src/model/bms_device_info.dart lib/src/protocol/ant_parser.dart test/ant_parser_test.dart
git commit -m "Decode ANT status and device info frames"
```

---

### Task 5: Brand-neutral device info in the service and screens

**Files:**
- Modify: `lib/src/bms_service.dart` (`_deviceInfoController`, `deviceInfo`, `lastDeviceInfo`, `_handleDeviceInfo`, `_recordDeviceDetails`, `overrideVariant`), `lib/src/ui/tabs/system_tab.dart:62-75`, `lib/src/ui/live_console_screen.dart:43-77,238`, `lib/src/ui/connect_screen.dart:1032`, `lib/src/ui/pack/pack_profile_card.dart:75,207`, `lib/src/ui/pack/pack_profile_sheet.dart:332`, `lib/src/pack/pack_baseline.dart` (`capture(settings, info)`), `lib/src/ui/inspection/inspection_screen.dart:75-84`, and whatever else `flutter analyze` flags.
- Test: extend `test/bms_service_test.dart` with one case.

**Interfaces:**
- Consumes: `BmsDeviceInfo` (Task 4).
- Produces: `Stream<BmsDeviceInfo> BmsService.deviceInfo`; `BmsDeviceInfo? BmsService.lastDeviceInfo`; `JkDeviceInfo? BmsService.jkDeviceInfo` (= `lastDeviceInfo?.jk`). `PackBaseline.capture` takes `BmsDeviceInfo?`. Internally `_lastDeviceInfo` becomes `BmsDeviceInfo?`; `overrideVariant` uses `_lastDeviceInfo?.variant`.

- [ ] **Step 1: Write the failing test** (append to `test/bms_service_test.dart`, reusing its existing setup that delivers `deviceInfoFrames` from `captured_frames.dart`; copy the arrange part from the nearest existing device-info test in that file)

```dart
  test('device info is published brand-neutral, JK details still reachable',
      () async {
    // arrange exactly like the existing device-info test in this file
    final info = await service.deviceInfo.first; // after delivering a JK02 device-info frame
    expect(info.brand, BmsBrand.jk);
    expect(info.model, isNotEmpty);
    expect(info.jk, isNotNull);
    expect(service.jkDeviceInfo, same(info.jk));
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/bms_service_test.dart`
Expected: FAIL to compile (`brand` not on `JkDeviceInfo`).

- [ ] **Step 3: Implement.** In `_dispatch` JK branch: `_handleDeviceInfo(BmsDeviceInfo.fromJk(_parser.parseDeviceInfo(frame)))`. `_handleDeviceInfo(BmsDeviceInfo info)`: variant logic runs only when `info.jk != null` (use `info.jk!.variant` / `info.jk!.detection.confident`); `_recordDeviceDetails` takes `BmsDeviceInfo`. Screens: replace `JkDeviceInfo` with `BmsDeviceInfo`; passcode/variant/power-on reads go through `.jk?.` and their rows are hidden when null. `live_console_screen.dart:238`: `deviceInfo!.variant?.name ?? deviceInfo!.brand.name.toUpperCase()`.

- [ ] **Step 4: Run** `flutter analyze` (zero errors) and `flutter test`
Expected: all PASS.

- [ ] **Step 5: Commit** (explicit paths)

```bash
git commit -m "Publish device info in terms every brand can answer"
```

---

### Task 6: LinkScript and a transport that only runs it

**Files:**
- Create: `lib/src/protocol/jk_commands.dart`, `lib/src/ble/link_script.dart`, `test/link_script_test.dart`
- Modify: `lib/src/ble/ble_transport.dart` (`_writeCommand`, `requestDeviceInfo`, `requestCellInfo`, `_nudgeIfQuiet`, the attach sequence at :627-634, `NotAJkBmsException`), `lib/src/ble/bms_link.dart`, `lib/src/ble/switchable_link.dart`, `lib/src/ble/simulator/simulated_link.dart`, `lib/src/bms_service.dart` (`_armCellInfoRequests`, `_onBytes` call to `frameAccepted`), `test/support/fakes.dart`, any test double implementing `BmsLink` (`grep -rln "implements BmsLink" lib test`).

**Interfaces:**
- Consumes: `antStatusRequest`, `antDeviceInfoRequest`, `BmsBrand`, `shouldNudge` (`link_quiet.dart`).
- Produces:
  - `List<int> jkReadCommand(int register)`
  - `sealed class TickAction`; `class NoAction`, `class WriteFrame { List<int> bytes; bool countsAsNudge; }`, `class ReleaseMute`
  - `class LinkScript { BmsBrand brand; List<List<int>> onConnect; Duration tickEvery; List<int> askAgain; Set<String> get everyFrameHex; TickAction tick({required DateTime now, DateTime? lastFrameAt, DateTime? connectedAt, required int tickNumber, required bool deviceInfoSeen, required Duration quietBefore, required Duration muteBefore}); factory LinkScript.jk({Duration tickEvery}); static const LinkScript ant; static LinkScript forBrand(BmsBrand b); }`
  - On `BmsLink`: `set script(LinkScript value)`, `Future<void> askAgain()`, and `void frameAccepted({bool deviceInfo = false})` (signature change).
  - `NotABmsException` (renamed from `NotAJkBmsException`).

- [ ] **Step 1: Write the failing test** `test/link_script_test.dart`

```dart
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/link_script_test.dart`
Expected: FAIL, files not found.

- [ ] **Step 3: Implement `jk_commands.dart`** by moving the body of `_writeCommand`'s frame building:

```dart
import 'jk_constants.dart';

/// A JK read request for [register].
///
/// The only kind of frame the app ever writes to a JK: a read. Frame layout
/// source: `build_frame()` in syssi/esphome-jk-bms jk_bms_ble.cpp.
List<int> jkReadCommand(int register) {
  final frame = List<int>.filled(commandFrameSize, 0);
  frame.setRange(0, 4, commandPreamble);
  frame[4] = register; // holding register
  frame[5] = 0x00; // value length in bytes; 0 for a read
  var sum = 0;
  for (var i = 0; i < commandFrameSize - 1; i++) {
    sum = (sum + frame[i]) & 0xFF;
  }
  frame[commandFrameSize - 1] = sum;
  return List.unmodifiable(frame);
}
```

- [ ] **Step 4: Implement `link_script.dart`**

```dart
import '../protocol/ant_constants.dart';
import '../protocol/bms_brand.dart';
import '../protocol/jk_commands.dart';
import '../protocol/jk_constants.dart';
import 'link_quiet.dart';

sealed class TickAction {
  const TickAction();
}

class NoAction extends TickAction {
  const NoAction();
}

class WriteFrame extends TickAction {
  const WriteFrame(this.bytes, {this.countsAsNudge = false});
  final List<int> bytes;

  /// Whether this write was prompted by silence, for [LinkHealth.nudges].
  final bool countsAsNudge;
}

/// The link has been up and mute for too long; let go and come back.
class ReleaseMute extends TickAction {
  const ReleaseMute();
}

/// What the transport writes, and when, for one brand.
///
/// Data plus one pure decision, so the transport stays ignorant of every
/// protocol and the read-only promise can be tested without a radio: the
/// frames a script can ever produce are exactly [everyFrameHex].
class LinkScript {
  const LinkScript._({
    required this.brand,
    required this.onConnect,
    required this.tickEvery,
    required this.askAgain,
    required this.pollsAlways,
    required this.deviceInfo,
  });

  /// JK streams on its own; the script only nudges a pack that went quiet.
  factory LinkScript.jk({Duration tickEvery = const Duration(seconds: 5)}) =>
      LinkScript._(
        brand: BmsBrand.jk,
        onConnect: [
          jkReadCommand(commandDeviceInfo),
          jkReadCommand(commandCellInfo),
        ],
        tickEvery: tickEvery,
        askAgain: jkReadCommand(commandCellInfo),
        pollsAlways: false,
        deviceInfo: jkReadCommand(commandDeviceInfo),
      );

  /// ANT says nothing unless asked, so it is asked for its status every tick.
  static const LinkScript ant = LinkScript._(
    brand: BmsBrand.ant,
    onConnect: [antDeviceInfoRequest, antStatusRequest],
    tickEvery: Duration(seconds: 2),
    askAgain: antStatusRequest,
    pollsAlways: true,
    deviceInfo: antDeviceInfoRequest,
  );

  static LinkScript forBrand(BmsBrand b) =>
      b == BmsBrand.ant ? ant : LinkScript.jk();

  final BmsBrand brand;
  final List<List<int>> onConnect;
  final Duration tickEvery;
  final List<int> askAgain;
  final bool pollsAlways;
  final List<int> deviceInfo;

  Set<String> get everyFrameHex => {
        for (final f in [...onConnect, askAgain, deviceInfo])
          f.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      };

  TickAction tick({
    required DateTime now,
    DateTime? lastFrameAt,
    DateTime? connectedAt,
    required int tickNumber,
    required bool deviceInfoSeen,
    required Duration quietBefore,
    required Duration muteBefore,
  }) {
    final lastSign = lastFrameAt ?? connectedAt;
    if (lastSign != null && now.difference(lastSign) > muteBefore) {
      return const ReleaseMute();
    }
    final quiet = shouldNudge(
      lastHeardAt: lastFrameAt,
      now: now,
      quietBefore: quietBefore,
    );
    if (!pollsAlways) {
      return quiet ? WriteFrame(askAgain, countsAsNudge: true) : const NoAction();
    }
    if (!deviceInfoSeen && tickNumber % 5 == 0) return WriteFrame(deviceInfo);
    return WriteFrame(askAgain, countsAsNudge: quiet);
  }
}
```

Check the JK constant names in `jk_constants.dart:58-60` (`commandDeviceInfo`, `commandCellInfo`); use whatever they are called there.

- [ ] **Step 5: Run the script test**

Run: `flutter test test/link_script_test.dart`
Expected: PASS.

- [ ] **Step 6: Make the transport run the script**

In `BleTransport`:
- Add fields `LinkScript _script;` (initialise in the constructor: `_script = LinkScript.jk(tickEvery: pollInterval)`), `int _tick = 0;`, `bool _deviceInfoSeen = false;`.
- `@override set script(LinkScript value) { _script = value; }`. If connected, the next attach uses it; switching mid-link restarts the timer: cancel `_pollTimer` and re-arm with `value.tickEvery` if `_pollTimer != null`.
- Attach sequence (:627-634): replace the two requests with `for (final f in _script.onConnect) { await _write(f); }`, reset `_tick = 0; _deviceInfoSeen = false;`, and `_pollTimer = Timer.periodic(_script.tickEvery, (_) => _onTick());`.
- Replace `_nudgeIfQuiet` with:

```dart
  Future<void> _onTick() async {
    _tick++;
    final action = _script.tick(
      now: DateTime.now(),
      lastFrameAt: _lastFrameAt,
      connectedAt: _connectedAt,
      tickNumber: _tick,
      deviceInfoSeen: _deviceInfoSeen,
      quietBefore: quietBefore,
      muteBefore: muteBefore,
    );
    switch (action) {
      case NoAction():
        return;
      case ReleaseMute():
        await _resetMuteLink();
      case WriteFrame(:final bytes, :final countsAsNudge):
        if (countsAsNudge) {
          nudges++;
          _nudgesThisLink++;
        }
        await _write(bytes);
    }
  }
```

- Replace `_writeCommand(int)` with `Future<void> _write(List<int> frame)` (same body minus the frame building; keep the doc comment, reworded: "the only place the app writes to a BMS, and it only writes frames a [LinkScript] produced, all of them read requests").
- `requestDeviceInfo()` / `requestCellInfo()`: delete. `@override Future<void> askAgain() => _write(_script.askAgain);`
- `frameAccepted({bool deviceInfo = false})`: add `if (deviceInfo) _deviceInfoSeen = true;`.
- Rename `NotAJkBmsException` to `NotABmsException` everywhere (`grep -rn NotAJkBms lib test`).
- Keep the `pollInterval` doc comment; it now documents the JK tick.

In `BmsLink`: add

```dart
  /// What to write and when, for the brand being spoken. A transport that
  /// writes nothing (simulated, captured bytes) ignores it.
  set script(LinkScript value) {}

  /// Asks again now, with the script's own request. Nothing for a transport
  /// that cannot be asked.
  Future<void> askAgain() async {}
```

and change `void frameAccepted()` to `void frameAccepted({bool deviceInfo = false}) {}`, doc: "[deviceInfo] says the frame was the pack identifying itself, so a script that keeps asking until it hears that can stop." Replace "checksum-valid JK frame" with "checksum-valid frame".

`SwitchableLink`: forward `script` and `askAgain` to `_real` (`set script(v) => _real.script = v;`, `askAgain() => isSimulated ? Future.value() : _real.askAgain()`), and `frameAccepted({deviceInfo})` to the active link. `SimulatedLink`, `FakeLink` and any other double: add the no-op `script` setter, `askAgain` (FakeLink: `int asks = 0; Future<void> askAgain() async => asks++;` and `LinkScript? scriptSet; set script(v) => scriptSet = v;`), and the new `frameAccepted` signature (FakeLink: also `int deviceInfoHeard = 0;` incremented when `deviceInfo` is true).

In `BmsService._armCellInfoRequests`: replace `final real = _switchable?.real; if (real == null) return; ... unawaited(real.requestCellInfo());` with `unawaited(_transport.askAgain());` (keep `if (isDemo || ...) return;`). In `_onBytes` JK branch: `_transport.frameAccepted(deviceInfo: frame.type == JkRecordType.deviceInfo);`.

- [ ] **Step 7: Run everything**

Run: `flutter analyze` then `flutter test`
Expected: zero analyzer errors; all tests PASS (the JK link tests, persist_retries, link_liveness in particular).

- [ ] **Step 8: Commit** (explicit paths)

```bash
git commit -m "Let the transport run a per-brand script instead of writing JK commands itself"
```

---

### Task 7: Persistence, backup, export and scan know the brand

**Files:**
- Create: `lib/src/protocol/raw_bms_frame.dart`, `test/migration_15_test.dart`
- Modify: `lib/src/data/database.dart` (Devices, RawFrames, schema 15, migration, `newColumns` in the `from < 5` step), regenerate `lib/src/data/database.g.dart`, `lib/src/data/repository.dart` (`addRawFrame`, `rememberDevice`, new `setDeviceBrand`), `lib/src/data/backup.dart` (format 2), `lib/src/data/exporter.dart` (`exportRawFrames`), `lib/src/ble/ble_transport.dart` (`DiscoveredBms`, `classifyAdvertisement`), `lib/src/data/link_event.dart` (new kinds), `lib/src/bms_service.dart` (`_dispatch` stores `RawBmsFrame`).
- Test: `test/migration_15_test.dart`, extend `test/scan_discovery_test.dart`, extend the existing backup round-trip test (`grep -rl "includeRawFrames" test/`).

**Interfaces:**
- Consumes: `BmsBrand`.
- Produces:
  - `class RawBmsFrame { BmsBrand brand; int recordType; Uint8List bytes; DateTime receivedAt; factory RawBmsFrame.jk(JkFrame f); factory RawBmsFrame.ant(AntFrame f); factory RawBmsFrame.antRejected(Uint8List bytes, DateTime at); }` (`antRejected` uses `recordType 0x00`)
  - `Devices.brand` / `RawFrames.brand`: `TextColumn ... nullable()`; generated `Device.brand` / `RawFrame.brand` are `String?`.
  - `BmsRepository.addRawFrame(RawBmsFrame f)`; `rememberDevice({..., BmsBrand? brand})`; `Future<void> setDeviceBrand(String id, BmsBrand brand)`.
  - `DiscoveredBms.brandHint` (`BmsBrand?`); `likelyBms` true also for `brandHint == ant`.
  - `LinkEventKind.protocolSwitched`, `antFrameRejected`, `antDecodeFailed`, `oldAntProtocolSeen`.
  - `BackupService.formatVersion == 2`.

- [ ] **Step 1: Write the failing tests**

`test/migration_15_test.dart`: follow the pattern of the newest existing migration test (`grep -rl "schemaVersion\|from: 13\|onUpgrade" test/`; if there is one for 14, copy its harness). The assertions:

```dart
  test('14 to 15: existing devices and frames read as JK', () async {
    // Build a v14 database with one device row and one raw frame row, using
    // the same harness as the existing migration test, then open it at 15.
    final device = await db.device('AA:BB');
    expect(device!.brand, isNull);
    expect(BmsBrand.fromStored(device.brand), BmsBrand.jk);
    final frames = await db.allRawFramesForBackup();
    expect(frames.single.brand, isNull);
  });

  test('fresh 15 database stores the brand', () async {
    final repo = BmsRepository(AppDatabase.forTesting(NativeDatabase.memory()));
    await repo.rememberDevice(id: 'X', name: 'ANT-BLE16ZMUB', demo: false,
        brand: BmsBrand.ant);
    expect((await repo.db.device('X'))!.brand, 'ant');
    await repo.setDeviceBrand('X', BmsBrand.jk);
    expect((await repo.db.device('X'))!.brand, 'jk');
  });
```

If no migration test harness exists, drop the first test and instead add to the second: open an in-memory DB at 15 and assert `db.schemaVersion == 15`; the migration code is reviewed by reading (Step 3 notes the trap).

`test/scan_discovery_test.dart`, add:

```dart
  test('an ANT module is recognised as a likely BMS with a brand hint', () {
    final d = classifyAdvertisement(
        id: '1', name: 'ANT-BLE16ZMUB', rssi: -60, serviceUuids: const []);
    expect(d.brandHint, BmsBrand.ant);
    expect(d.likelyBms, isTrue);
  });
  test('a name that says nothing has no hint', () {
    final d = classifyAdvertisement(
        id: '2', name: 'Moto', rssi: -60, serviceUuids: const ['ffe0']);
    expect(d.brandHint, isNull);
    expect(d.likelyBms, isTrue); // the service UUID still counts
  });
```

Backup test, add: after exporting with one ANT device (`brand: BmsBrand.ant`) and one `RawBmsFrame.ant` frame, restoring into a fresh DB keeps `device.brand == 'ant'` and `frame.brand == 'ant'`; and a v1 payload (copy of an existing fixture or a hand-built map with `'format': 1` and no `brand` keys) restores with `brand == null`.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/migration_15_test.dart test/scan_discovery_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement the schema**

In `Devices`:

```dart
  /// Which maker's protocol this pack speaks, by [BmsBrand.stored]. Null for
  /// every row written before the app knew a second brand, all of them JK.
  TextColumn get brand => text().nullable()();
```

In `RawFrames` the same column, doc: "Which protocol these bytes are, so a reparse picks the right decoder. Null means JK." Update the `RawFrames` class doc: "The raw frames exactly as they arrived (300 bytes for JK, variable for ANT)."

`schemaVersion => 15`. In the `from < 5` `TableMigration(devices, newColumns: [...])` add `devices.brand`. Append:

```dart
      if (from < 15) {
        // Raw frames were never recreated, so every older version gets the
        // column here. Devices were rebuilt from the current schema by the
        // from < 5 step, which already carries it: adding it again would
        // fail with a duplicate column and stop the app opening.
        await m.addColumn(rawFrames, rawFrames.brand);
        if (from >= 5) await m.addColumn(devices, devices.brand);
      }
```

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 4: Implement `RawBmsFrame`, repository, backup, exporter, scan, link events**

```dart
// lib/src/protocol/raw_bms_frame.dart
import 'dart:typed_data';

import 'ant_frame.dart';
import 'bms_brand.dart';
import 'jk_frame.dart';

/// Bytes as they arrived, labelled with the protocol that can read them.
class RawBmsFrame {
  const RawBmsFrame({
    required this.brand,
    required this.recordType,
    required this.bytes,
    required this.receivedAt,
  });

  factory RawBmsFrame.jk(JkFrame f) => RawBmsFrame(
      brand: BmsBrand.jk, recordType: f.rawType, bytes: f.bytes,
      receivedAt: f.receivedAt);

  factory RawBmsFrame.ant(AntFrame f) => RawBmsFrame(
      brand: BmsBrand.ant, recordType: f.function, bytes: f.bytes,
      receivedAt: f.receivedAt);

  /// A buffer the ANT assembler threw away. Record type 0x00, which no ANT
  /// response uses, so these rows are easy to find and never reparsed as data.
  factory RawBmsFrame.antRejected(Uint8List bytes, DateTime at) => RawBmsFrame(
      brand: BmsBrand.ant, recordType: 0x00, bytes: bytes, receivedAt: at);

  final BmsBrand brand;
  final int recordType;
  final Uint8List bytes;
  final DateTime receivedAt;
}
```

`repository.addRawFrame(RawBmsFrame frame)`: same body with `timestamp: frame.receivedAt, recordType: frame.recordType, bytes: frameBytes(frame.bytes), brand: Value(frame.brand.stored)`. `rememberDevice` gains `BmsBrand? brand`: on insert `brand: Value(brand?.stored)`; on update `brand: brand == null ? const Value.absent() : Value(brand.stored)`. `setDeviceBrand(id, brand)` = `db.updateDevice(id, DevicesCompanion(brand: Value(brand.stored)))`.

`BmsService._dispatch` (JK): `repository?.addRawFrame(RawBmsFrame.jk(frame));`.

`backup.dart`: `formatVersion = 2`; `_device` adds `'brand': d.brand`; `_frame` adds `'brand': f.brand`; restore: `brand: Value(d['brand'] as String?)` and `brand: Value(f['brand'] as String?)`. Add a line to the class doc: "Format 2 adds the brand to devices and raw frames; a format 1 file restores as JK."

`exporter.dart`: header lines become `'# BMS raw frames, hex. JK frames are 300 bytes; ANT frames vary. Type 0x00 on ANT is a rejected buffer.'` and `'# timestamp,brand,record_type,bytes'`; each line writes `BmsBrand.fromStored(f.brand).stored` after the timestamp.

`DiscoveredBms`: add `this.brandHint` (`final BmsBrand? brandHint;`, doc "From the advertised name; see [brandFromName]."); `likelyBms => advertisesJkService || nameLooksLikeJk || brandHint == BmsBrand.ant`; `classifyAdvertisement` passes `brandHint: brandFromName(name)`. Update the class doc from "A JK BMS advertising nearby." to "A BMS, or something that might be one, advertising nearby."

`link_event.dart`: add a new section:

```dart
  // --- Which protocol the pack speaks ---

  /// The bytes said the pack speaks another brand than the one chosen, and
  /// the app switched. Detail carries from and to.
  protocolSwitched,

  /// The ANT assembler threw a buffer away. Detail carries the reason and the
  /// hex, so a decoding mistake can be fixed from a backup. At most 20 per
  /// connection.
  antFrameRejected,

  /// An ANT frame passed its CRC and still could not be decoded. Detail
  /// carries the error and the hex.
  antDecodeFailed,

  /// Bytes starting AA 55 AA FF arrived: the pre-2021 ANT protocol, which the
  /// app does not read yet.
  oldAntProtocolSeen,
```

- [ ] **Step 5: Run**

Run: `flutter analyze` then `flutter test`
Expected: all PASS, including the extended backup and scan tests.

- [ ] **Step 6: Commit** (explicit paths, including `database.g.dart`)

```bash
git commit -m "Remember each pack's brand in the database, backups, exports and scan"
```

---

### Task 8: The ANT path through BmsService

**Files:**
- Modify: `lib/src/bms_service.dart`
- Create: `test/ant_service_test.dart`

**Interfaces:**
- Consumes: everything above. `FakeLink.scriptSet`, `FakeLink.asks`, `FakeLink.deliver`, `FakeLink.announce`, `FakeLink.deviceInfoHeard` (Task 6).
- Produces on `BmsService`:
  - `Future<void> connect(String deviceId, {String name = '', bool inspecting = false, BmsBrand? brand})`
  - `BmsBrand get brand` (current), `AntStatus? get lastAntStatus`
  - counters `int antStatusFrames`, `int antInfoFrames`, `int antRejectedFrames`, `String? lastDecodeError`
  - `Stream<AntStatus> get antStatus` (for the System tab)
  - private: `_brand`, `_antAssembler`, `_antParser`, `_onAntBytes`, `_acceptSnapshot(BmsSnapshot)`, `_switchBrand(BmsBrand to, String why)`, `_rejectedNoted` (per-connection cap 20).

- [ ] **Step 1: Write the failing tests** `test/ant_service_test.dart`

Use the setup style of `test/bms_service_test.dart` (a `FakeLink`, `BmsService(transport: link, locationFactory: () => StubLocation())`, an in-memory repository if that file attaches one: copy that exact setup). Then:

```dart
  test('a named ANT connects with the ANT script and produces readings', () async {
    await service.connect('ANT1', name: 'ANT-BLE16ZMUB');
    expect(link.scriptSet?.brand, BmsBrand.ant);
    link.announce(BleLinkState.connected);
    final next = service.snapshots.first;
    await link.deliver(antStatus16s);
    final s = await next;
    expect(s.brand, BmsBrand.ant);
    expect(s.packVoltage, closeTo(52.84, 1e-9));
    expect(link.framesHeard, 1);
  });

  test('device info arrives neutral and tells the link it was heard', () async {
    await service.connect('ANT1', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    final info = service.deviceInfo.first;
    await link.deliver(antInfo16zm);
    expect((await info).model, '16ZM');
    expect(link.deviceInfoHeard, 1);
  });

  // Review focus 2
  test('status without device info still activates the pack', () async {
    await service.connect('ANT1', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    await link.deliver(antStatus16s);
    await pumpEventQueue();
    expect(service.activeDeviceId, 'ANT1');
    expect(service.lastDeviceInfo, isNull);
  });

  test('the pack adopts the ANT nominal capacity when none is set', () async {
    await service.connect('ANT1', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    await link.deliver(antStatus16s);
    await pumpEventQueue();
    expect(service.activeDevice?.catalogueCapacityAh, closeTo(280, 1e-6));
    expect(service.activeDevice?.catalogueFromBms, isTrue);
  });

  test('the brand is stored on the pack', () async {
    await service.connect('ANT1', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    await link.deliver(antStatus16s);
    await pumpEventQueue();
    expect(service.activeDevice?.brand, 'ant');
  });

  // Review focus 4
  test('reconnecting by id alone uses the stored brand', () async {
    await service.repository!.rememberDevice(
        id: 'ANT1', name: 'Mi moto', demo: false, brand: BmsBrand.ant);
    await service.connect('ANT1');
    expect(link.scriptSet?.brand, BmsBrand.ant);
  });

  test('an explicit brand beats the name', () async {
    await service.connect('X', name: 'KevinJK', brand: BmsBrand.ant);
    expect(service.brand, BmsBrand.ant);
  });

  test('passive detection: ANT bytes on a JK connection switch the brand', () async {
    await service.connect('X', name: 'Moto', brand: BmsBrand.jk);
    link.announce(BleLinkState.connected);
    await link.deliver(antStatus16s);
    await pumpEventQueue();
    expect(service.brand, BmsBrand.ant);
    expect(link.scriptSet?.brand, BmsBrand.ant);
  });

  test('passive detection works the other way too', () async {
    await service.connect('X', name: 'Moto', brand: BmsBrand.ant);
    link.announce(BleLinkState.connected);
    await link.deliver(cellInfo24s); // from fixtures/captured_frames.dart
    await pumpEventQueue();
    expect(service.brand, BmsBrand.jk);
  });

  test('old ANT bytes are named, and nothing switches', () async {
    await service.connect('X', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    await link.deliver(Uint8List.fromList([0xAA, 0x55, 0xAA, 0xFF, ...List.filled(136, 0)]));
    expect(service.recentProblems.first, contains('2021'));
    expect(service.brand, BmsBrand.ant);
  });

  test('a bad CRC is counted and written down with its bytes', () async {
    await service.connect('X', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    final bad = Uint8List.fromList(antStatus16s)..[40] ^= 0xFF;
    await link.deliver(bad);
    await pumpEventQueue();
    expect(service.antRejectedFrames, 1);
    final events = await service.repository!.recentLinkEvents();
    expect(events.any((e) => e.kind == LinkEventKind.antFrameRejected.name &&
        e.detail.contains('7ea1')), isTrue);
  });

  test('rejections written down are capped at 20 per connection', () async {
    await service.connect('X', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    final bad = Uint8List.fromList(antStatus16s)..[40] ^= 0xFF;
    for (var i = 0; i < 30; i++) {
      await link.deliver(bad);
    }
    await pumpEventQueue();
    final events = await service.repository!.recentLinkEvents();
    expect(events.where((e) => e.kind == LinkEventKind.antFrameRejected.name),
        hasLength(20));
    expect(service.antRejectedFrames, 30);
  });

  test('an implausible ANT reading feeds nothing', () async {
    await service.connect('X', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    // Every cell at 9.999 V: CRC-valid, physically impossible.
    await link.deliver(antFrameWithCells(antStatus16s, 9999)); // helper below
    await pumpEventQueue();
    expect(service.history.isEmpty, isTrue);
    expect(service.recentProblems.first, contains('battery'));
  });

  // Review focus 3
  test('a link drop resets the ANT assembler', () async {
    await service.connect('X', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    await link.deliver(antStatus16s.sublist(0, 60), chunk: 60);
    link.announce(BleLinkState.disconnected);
    link.announce(BleLinkState.connected);
    final next = service.snapshots.first;
    // Tail of a frame without its 7E A1 head, then a whole frame.
    await link.deliver(antStatus16s.sublist(60), chunk: 200);
    await link.deliver(antStatus14s4t);
    expect((await next).cellCount, 14);
  });

  // Review focus 5
  test('demo mode after an ANT session goes back to JK', () async {
    // Only meaningful with a SwitchableLink; if this file's service uses
    // FakeLink, construct a second service with SwitchableLink(real: BleTransport())
    // exactly as test/demo_mode_test.dart does, connect it with brand: ant,
    // then enterDemoMode() and assert service.brand == BmsBrand.jk.
  });

  // Review focus 1
  test('silence on a rider-chosen brand suggests the other one', () {
    fakeAsync((clock) {
      service.connect('X', name: 'Moto', brand: BmsBrand.ant);
      link.announce(BleLinkState.connected);
      clock.elapse(const Duration(seconds: 13));
      expect(service.recentProblems.first, contains('JK'));
    });
  });
```

Write the demo-mode test fully following `test/demo_mode_test.dart`'s construction (do not leave the comment as the body). Helper for the implausible test, at the bottom of the file:

```dart
/// A copy of [f] with every cell set to [mv] and the CRC recomputed.
Uint8List antFrameWithCells(Uint8List f, int mv) {
  final b = Uint8List.fromList(f);
  final n = b[9];
  for (var i = 0; i < n; i++) {
    b[34 + 2 * i] = mv & 0xFF;
    b[35 + 2 * i] = mv >> 8;
  }
  final crc = antCrc16(b, 1, b.length - 4);
  b[b.length - 4] = crc & 0xFF;
  b[b.length - 3] = crc >> 8;
  return b;
}
```

If `fakeAsync` is not already a dev dependency (`grep fake_async pubspec.yaml`), use the pattern the existing silence-watchdog test uses instead; do not add a dependency.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/ant_service_test.dart`
Expected: FAIL to compile (`brand` parameter, `antRejectedFrames`, etc.).

- [ ] **Step 3: Implement in `BmsService`**

1. Fields: `BmsBrand _brand = BmsBrand.jk; BmsBrand get brand => _brand;` `bool _brandChosenByRider = false;` `final AntFrameAssembler _antAssembler = AntFrameAssembler(); final AntParser _antParser = const AntParser();` `AntStatus? _lastAntStatus;` getter, `final _antStatusController = StreamController<AntStatus>.broadcast();` + getter, counters, `int _rejectedNoted = 0; bool _oldAntNoted = false;`. In the constructor: `_antAssembler.onRejected = _onAntRejected;`. Close the controller in `dispose`.

2. `connect(... BmsBrand? brand)`: after `_resetCounters()`:

```dart
    final stored = (await repository?.device(deviceId))?.brand;
    _brandChosenByRider = brand != null && stored == null;
    _useBrand(brand ??
        (stored != null ? BmsBrand.fromStored(stored) : null) ??
        brandFromName(name) ??
        BmsBrand.jk);
    _rejectedNoted = 0;
    _oldAntNoted = false;
    _antAssembler.reset();
```

`_armCellInfoRequests()` only when `_brand == BmsBrand.jk` (ANT is polled by its script).

```dart
  void _useBrand(BmsBrand b) {
    _brand = b;
    _transport.script = LinkScript.forBrand(b);
  }
```

3. `_onBytes(chunk)`:

```dart
  void _onBytes(List<int> chunk) {
    _detectBrand(chunk);
    if (_brand == BmsBrand.ant) {
      _onAntBytes(chunk);
      return;
    }
    // ... existing JK body unchanged, with frameAccepted(deviceInfo: ...)
  }

  static bool _startsWith(List<int> c, List<int> p) {
    if (c.length < p.length) return false;
    for (var i = 0; i < p.length; i++) {
      if (c[i] != p[i]) return false;
    }
    return true;
  }

  /// Whether this connection has decoded anything yet. Passive detection only
  /// runs before that: once the chosen brand has produced a frame, the brand
  /// is proved, and any two bytes can start a notification by chance. At two
  /// or three frames a second, "a chunk starting 7E A1" happens inside a JK
  /// stream every few hours, and switching a pack mid-ride over that would be
  /// far worse than never switching.
  bool _brandProved = false;

  /// A second assembler for the brand not chosen, fed only until the chosen
  /// one proves itself.
  final FrameAssembler _jkProbe = FrameAssembler();
  final AntFrameAssembler _antProbe = AntFrameAssembler();

  /// Reads the brand off the bytes themselves. Writes nothing: the only
  /// evidence used is what the pack chose to send, and only a whole frame
  /// with a valid checksum counts.
  void _detectBrand(List<int> chunk) {
    if (_brandProved) return;
    if (_brand == BmsBrand.jk && _antProbe.addChunk(chunk).isNotEmpty) {
      _switchBrand(BmsBrand.ant, 'a CRC-valid ANT frame arrived');
    } else if (_brand == BmsBrand.ant && _jkProbe.addChunk(chunk).isNotEmpty) {
      _switchBrand(BmsBrand.jk, 'a checksum-valid JK frame arrived');
    } else if (_startsWith(chunk, const [0xAA, 0x55, 0xAA, 0xFF]) &&
        !_oldAntNoted) {
      _oldAntNoted = true;
      _problem('This ANT speaks the protocol from before 2021, which the app '
          'cannot read yet. Nothing was changed on the pack.');
      unawaited(repository?.note(LinkEventKind.oldAntProtocolSeen,
          deviceId: activeDeviceId ?? _pendingDeviceId));
    }
  }

  void _switchBrand(BmsBrand to, String why) {
    final from = _brand;
    _useBrand(to);
    _assembler.reset();
    _antAssembler.reset();
    _problem('Switched from ${from.name.toUpperCase()} to '
        '${to.name.toUpperCase()}: $why.');
    final id = activeDeviceId ?? _pendingDeviceId;
    unawaited(repository?.note(LinkEventKind.protocolSwitched,
        detail: '${from.stored}->${to.stored}: $why', deviceId: id));
    if (activeDeviceId != null) {
      unawaited(repository?.setDeviceBrand(activeDeviceId!, to));
    }
  }
```

(`responsePreamble` is the JK constant from `jk_constants.dart`.) `_activate` passes `brand: _brand` to `rememberDevice`.

`_brandProved` bookkeeping: set it to `true` for every frame the chosen brand's own assembler accepts (in the JK loop of `_onBytes` and in `_onAntBytes`); set it to `false` and `reset()` both probes in `connect()`. The frame that triggered a switch was consumed by the probe, not decoded; that is fine, because the next one arrives within a second (JK streams) or two (ANT is polled), and the probe's `onRejected` is left unset so a probe never writes anything down.

Add this test to `test/ant_service_test.dart` next to the passive-detection ones:

```dart
  test('once a JK frame decodes, ANT-looking bytes never switch the brand', () async {
    await service.connect('X', name: 'KevinJK');
    link.announce(BleLinkState.connected);
    await link.deliver(cellInfo24s);
    await link.deliver(antStatus16s);
    await pumpEventQueue();
    expect(service.brand, BmsBrand.jk);
  });
```

4. The ANT path:

```dart
  void _onAntBytes(List<int> chunk) {
    for (final frame in _antAssembler.addChunk(chunk)) {
      _transport.frameAccepted(deviceInfo: frame.isDeviceInfo);
      repository?.addRawFrame(RawBmsFrame.ant(frame));
      try {
        if (frame.isStatus) {
          antStatusFrames++;
          unawaited(_handleAntStatus(_antParser.parseStatus(frame)));
        } else if (frame.isDeviceInfo) {
          antInfoFrames++;
          _handleDeviceInfo(_antParser.parseDeviceInfo(frame));
        }
      } on AntParseException catch (e) {
        decodeFailures++;
        lastDecodeError = e.message;
        _problem('Could not decode an ANT frame: ${e.message}');
        if (_rejectedNoted < 20) {
          _rejectedNoted++;
          unawaited(repository?.note(LinkEventKind.antDecodeFailed,
              detail: '${e.message} ${_hex(frame.bytes)}',
              deviceId: activeDeviceId ?? _pendingDeviceId));
        }
      }
    }
    _statsController.add(_antAssembler.stats);
  }

  void _onAntRejected(AntRejected r) {
    antRejectedFrames++;
    lastDecodeError = r.reason.name;
    repository?.addRawFrame(RawBmsFrame.antRejected(r.bytes, DateTime.now().toUtc()));
    if (_rejectedNoted >= 20) return;
    _rejectedNoted++;
    unawaited(repository?.note(LinkEventKind.antFrameRejected,
        detail: '${r.reason.name} ${_hex(r.bytes)}',
        deviceId: activeDeviceId ?? _pendingDeviceId));
  }

  static String _hex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

  Future<void> _handleAntStatus(AntStatus status) async {
    final reasons = plausibility.reject(status.snapshot);
    if (reasons.isNotEmpty) {
      heldBackFrames++;
      if (heldBackFrames == 1 || heldBackFrames % 100 == 0) {
        _problem('This ANT reading does not describe a battery that could '
            'exist (${reasons.join('; ')}). Not used; its bytes are kept.');
      }
      return;
    }
    _lastAntStatus = status;
    _antStatusController.add(status);
    await _acceptSnapshot(status.snapshot);
    unawaited(_adoptNominalFromSnapshot(status.snapshot));
  }
```

Note `repository.addRawFrame` already drops frames while no pack is active; the `LinkEvents` rows are what survive in that case (spec §11.6).

5. Extract `_acceptSnapshot(BmsSnapshot snapshot)`: move everything in `_handleCellInfo` from `_silenceTimer?.cancel();` to the end into it, and call `await _acceptSnapshot(snapshot);` there. No behaviour change for JK.

6. Capacity: rename the body of `_adoptCapacityFromBms(JkSettings)` into `_adoptNominal(double nominal)`; `_adoptCapacityFromBms(settings) => _adoptNominal(settings.nominalCapacityAh)`; `_adoptNominalFromSnapshot(s) => _adoptNominal(s.nominalCapacityAh)`, called only once per connection (guard with a bool reset in `_resetDecoding`).

7. `_resetDecoding()`: also `_antAssembler.reset(); _lastAntStatus = null;`. On link down (`_onLinkDown`), reset both assemblers (the JK one already survives drops by resynchronising; resetting it too is harmless). `enterDemoMode`: call `_useBrand(BmsBrand.jk)` before `link.useSimulator`.

8. Silence watchdog text (`_armSilenceWatchdog`): make it brand-aware:

```dart
      final other = _brand == BmsBrand.ant ? 'JK' : 'ANT';
      _problem(_brandChosenByRider
          ? 'Connected, but no readings have arrived. You said this pack is '
              '${_brand.name.toUpperCase()}; if it is a $other, connect again '
              'and pick $other.'
          : 'Connected, but no readings have arrived. Reading this BMS needs '
              'no password, so this is not an authentication problem. The usual '
              'causes are another client still holding the channel, or a '
              'firmware whose frames this app does not recognise yet; check '
              'the raw frame console.');
```

Keep the JK wording otherwise identical except "a JK BMS" to "this BMS" and the em dash replaced by a semicolon (the old string contains one).

- [ ] **Step 4: Run**

Run: `flutter test test/ant_service_test.dart` then `flutter test`
Expected: all PASS.

- [ ] **Step 5: Commit** (explicit paths)

```bash
git commit -m "Read an ANT pack end to end through the service"
```

---

### Task 9: Screens and copy

**Files:**
- Modify: `lib/src/ui/connect_screen.dart` (list rows :721-777, connect flow :997-1140, evidence string :1075, failure copy :1091), `lib/src/ui/tabs/system_tab.dart` (variant section :337-389, settings section :670, new ANT section), `lib/src/ui/tabs/now_tab.dart` (`WaitingReason.variantUnknown` :74-80), `lib/src/ui/live_console_screen.dart`, `lib/src/ui/pack/config_audit_screen.dart` (:64,82,186), `lib/src/ui/pack/pack_profile_card.dart`, `lib/l10n/app_es.arb`, `lib/l10n/app_en.arb`.
- Test: `test/connect_brand_test.dart` (create) for the pure brand-decision helper.

**Interfaces:**
- Consumes: `DiscoveredBms.brandHint`, `Device.brand`, `BmsService.brand`, `BmsService.lastAntStatus`, `BmsService.antStatus`, counters from Task 8, `antText`, the text tables.
- Produces: `BmsBrand? knownBrandFor({String? stored, BmsBrand? hint})` in `connect_screen.dart` (top-level, `@visibleForTesting` not needed): stored wins, else hint, else null (null means ask).

- [ ] **Step 1: Write the failing test** `test/connect_brand_test.dart`

```dart
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
```

Run: `flutter test test/connect_brand_test.dart`. Expected: FAIL (not defined).

- [ ] **Step 2: Add the strings (surgical Edit, both files)**

Add these keys to `app_es.arb` (template) and `app_en.arb`, near the existing connect/system keys. Spanish values (no em dashes):

| Key | es | en |
|---|---|---|
| `brandAskTitle` | `¿Qué BMS es?` | `Which BMS is this?` |
| `brandAskBody` | `El nombre no lo dice. Elige la marca una vez; la app la recuerda.` | `The name does not say. Pick the brand once; the app remembers it.` |
| `brandJk` | `JK (Jikong)` | `JK (Jikong)` |
| `brandAnt` | `ANT` | `ANT` |
| `systemBrand` | `Marca` | `Brand` |
| `antBatteryState` | `Estado de la batería` | `Battery state` |
| `antChargeMosfet` | `MOSFET de carga` | `Charge MOSFET` |
| `antDischargeMosfet` | `MOSFET de descarga` | `Discharge MOSFET` |
| `antBalancer` | `Balanceador` | `Balancer` |
| `antBalancerTemp` | `Temperatura del balanceador` | `Balancer temperature` |
| `settingsNotExposed` | `Este BMS no expone su configuración a la app.` | `This BMS does not expose its configuration to the app.` |
| `connectSilent` | `Conectó pero no llegaron lecturas. Si elegiste la marca, prueba con la otra.` | `Connected but no readings arrived. If you picked the brand, try the other one.` |
| `antEvidence` | `ANT: {status} de estado, {info} de info, {rejected} rechazadas` | `ANT: {status} status, {info} info, {rejected} rejected` |

`antEvidence` needs placeholders metadata (`"@antEvidence": {"placeholders": {"status": {"type": "int"}, "info": {"type": "int"}, "rejected": {"type": "int"}}}`) in the template. Replace uses of `connectSilentJk` in code with `connectSilent`; leave the old key in the `.arb` files only if something else still uses it (grep), otherwise remove it surgically.

The MOSFET/balancer/status enum texts stay in English from `ant_constants.dart` (they are the BMS's own vocabulary, as the JK warning labels are shown today via `jk02ErrorBitNames`); do not translate them in this task.

Regenerate: `flutter gen-l10n`.

- [ ] **Step 3: Connect screen**

- `knownBrandFor` top-level function as specified.
- Each list row: a small chip with `brandHint` (`JK`/`ANT`) when known; saved rows show the stored brand.
- In the connect flow, before `widget.service.connect(...)`: `final brand = knownBrandFor(stored: storedRow?.brand, hint: device.brandHint) ?? await _askBrand();` where `_askBrand()` shows a modal bottom sheet with `brandAskTitle`, `brandAskBody` and two `ListTile`s; dismissing returns null and aborts the connect. Pass `brand: brand` only when it came from the sheet (so the service can tell a rider's choice: pass it always; the service treats "explicit and not stored" as rider-chosen).
- Evidence string: when `service.brand == BmsBrand.ant` use `antEvidence(...)` plus `lastDecodeError` if any; otherwise the existing JK string.
- Failure copy: `connectSilent` replaces `connectSilentJk`.

- [ ] **Step 4: System tab, Now tab, console, audit**

- System tab: `InfoRow(t.systemBrand, service.brand.name.toUpperCase())` at the top of the device section. Variant section (`:337-389`) only when `service.brand == BmsBrand.jk`. When `service.lastAntStatus` is non-null, a section with `antBatteryState` (`antText(antBatteryStateText, st.batteryState)`), `antChargeMosfet`, `antDischargeMosfet`, `antBalancer` (same with their tables) and `antBalancerTemp` (`'${st.balancerTemp.toStringAsFixed(0)} °C'`), rebuilt from `service.antStatus`. Settings section: when `service.brand == BmsBrand.ant`, a single line `settingsNotExposed` instead of the JK settings.
- Now tab: `WaitingReason.variantUnknown` only when `service.brand == BmsBrand.jk`.
- Live console: show the ANT counters and `lastDecodeError` when brand is ANT.
- Config audit screen and pack profile card: when `service.brand == BmsBrand.ant` show `settingsNotExposed` instead of building `PackConfig.from(lastSettings)`.
- Grep for leftover user-facing "JK" in `lib/src/ui` and `lib/src/bms_service.dart` problem strings; neutralise the ones shown while an ANT is connected ("JK framing" messages only fire on the JK path and stay).

- [ ] **Step 5: Run**

Run: `flutter test test/connect_brand_test.dart`, `flutter analyze`, `flutter test`
Expected: all PASS, zero analyzer errors. `grep -rn "—" lib/l10n/app_es.arb lib/l10n/app_en.arb` shows no new occurrences on lines you added.

- [ ] **Step 6: Commit** (explicit paths, including the regenerated `app_localizations*.dart`)

```bash
git commit -m "Show the brand, ask for it when the name is silent, and hide what ANT does not have"
```

---

### Task 10: Backup replay harness and final verification

**Files:**
- Create: `test/fixtures/ant_backup_synthetic.json`, `test/ant_backup_replay_test.dart`
- Modify: `README.md` (one paragraph: ANT 2021 support, read-only, and the "bring me a backup" diagnosis procedure)

**Interfaces:**
- Consumes: backup format 2 (`rawFrames[].brand`, `rawFrames[].bytes` hex, `linkEvents[]`), `AntFrameAssembler`, `AntParser`.

- [ ] **Step 1: Build the synthetic fixture** by hand: a JSON object `{"format": 2, "devices": [{"id": "ANT1", "brand": "ant", ...minimal fields...}], "rawFrames": [four entries with "brand": "ant", "recordType": 17/17/18/18, "bytes": lower-case hex of antStatus16s, antStatus14s4t, antInfo16zm, antInfo22ph], "linkEvents": []}`. Generate the hex with a throwaway `dart run` one-liner or by reusing `test/fixtures/ant_frames.dart` in a scratch script; commit only the JSON.

- [ ] **Step 2: Write the replay test**

```dart
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
```

- [ ] **Step 3: Run it**

Run: `flutter test test/ant_backup_replay_test.dart`
Expected: PASS.

- [ ] **Step 4: README paragraph** (Spanish or English to match the README, which is English; no em dashes), e.g. under "What it does": "**ANT BMS (2021 and later).** Read the same way as a JK, read-only: the app only ever sends the two ANT read requests. If a pack does not decode, connect for a minute, make a backup with raw frames and use it as a fixture in `test/ant_backup_replay_test.dart`."

- [ ] **Step 5: Full verification**

Run: `flutter analyze` (zero issues) and `flutter test` (all pass). Then check the global constraints:
- `git diff main --stat` touches only planned files.
- `grep -rn "0x23\|0x51" lib/src/protocol/ant_*.dart` finds no write/auth constants.
- `git diff main -- . ":!docs/superpowers/plans" | grep "^+" | grep -P "\x{2014}"` must print nothing (the plan itself names the character, so it is excluded).

- [ ] **Step 6: Commit**

```bash
git add test/fixtures/ant_backup_synthetic.json test/ant_backup_replay_test.dart README.md
git commit -m "Replay ANT frames from a backup, so a field failure is fixed from a file"
```
