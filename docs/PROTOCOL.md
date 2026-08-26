# JK BMS BLE protocol — provenance and open questions

## Where every constant came from

Jikong publishes no specification, SDK or firmware for the JK BMS BLE
interface. Everything in `lib/src/protocol/` was transcribed from the community
reverse-engineering work in:

| Source | Use here |
|---|---|
| [`syssi/esphome-jk-bms`](https://github.com/syssi/esphome-jk-bms), `components/jk_bms_ble/jk_bms_ble.cpp` | Primary. All byte offsets, the checksum, frame framing, command registers. |
| [`syssi/esphome-jk-bms`](https://github.com/syssi/esphome-jk-bms), `components/jk_bms_ble/__init__.py` | Error/warning bit names (`DEFAULT_ERRORS_JK02`). |
| [`syssi/esphome-jk-bms`](https://github.com/syssi/esphome-jk-bms), `README.md` | The device compatibility table the variant-detection rule is derived from. |

**Rule for this repo: no offset or protocol constant may be written from
memory.** Every one carries a comment naming the field it maps to in the
reference. A wrong offset does not raise an error — it decodes into
plausible-looking garbage, which is the worst failure mode this app has.

## Test fixtures

`test/fixtures/captured_frames.dart` holds 11 real 300-byte frames copied
verbatim from the documentation comments of the reference implementation:

- 6 cell info frames (record `0x02`) from a JK02_24S device, 16 cells enabled
- 3 device info frames (record `0x03`), one per variant: JK04, JK02_24S, JK02_32S
- 2 settings frames (record `0x01`): one JK02_24S, one JK04

All 11 pass the checksum test. Expected values asserted in
`test/jk_parser_test.dart` are read off the byte-layout tables in the reference,
not produced by this parser.

## What is confirmed

Confirmed here means: verified against the captured frames, and consistent with
the reference.

- Service `0xFFE0`, characteristic `0xFFE1` (notify + write).
- Response preamble `55 AA EB 90`; command preamble is byte-swapped,
  `AA 55 90 EB`.
- Frames are 300 bytes with the checksum in byte 299. Newer firmware sends
  longer frames but keeps the checksum at 299, followed by another preamble.
- The "CRC" is a plain sum of all preceding bytes, low byte only.
- Commands are 20 bytes: preamble, register, value length, 4-byte value, zero
  padding, checksum in byte 19.
- Read registers: `0x96` cell info, `0x97` device info, `0xA1` logbook.
- Record types: `0x01` settings, `0x02` cell info, `0x03` device info,
  `0x05` logbook.

## Variant detection

The three framings (JK04, JK02_24S, JK02_32S) put fields at different offsets.
`JkProtocolVariantDetector` picks one from the software version reported in the
device info frame:

- software major version **>= 11** → JK02_32S
- software major version **< 11** → JK02_24S, **not confidently**

The rule was derived from the reference's compatibility table, which has no
counterexamples in either direction (checked explicitly: no JK02_24S device with
software >= 11, no JK02_32S device with software < 11). Hardware version does
not work as a discriminator — the table lists a device with hardware 10.XW and
software 11.21h that uses JK02_32S.

Software versions below 11 are flagged as low confidence because the JK04
balancer family also reports versions below 11 (JK-B2A16S sw 3.3.0, JK-B5A24S sw
8.0.3M). When detection is not confident the app says so and lets you override
the variant by hand.

When no variant is known, cell info frames are **held back rather than decoded**.
An obvious gap is better than confident wrong numbers.

## Open questions — verify against the real pack

These are places where the reference and the captured data disagree, or where no
capture exists. Each is handled conservatively in the code; each needs settling
against the Yoazaky 20S pack.

### 1. Current sign convention

`BmsSnapshot.isCharging` assumes positive current means charging, following the
reference's use of `std::max(0.0f, power)` for charging power. **The captured
frames are all from an idle pack (current = 0), so this is unverified.**

To settle it: connect, note the sign while discharging under load, then note it
while charging. Fix `isCharging` / `isDischarging` if reversed.

### 2. Temperature sensor bitmask at byte 182

The reference labels this "temperature sensor absent bitmask" with bit 0 for the
MOSFET sensor and bits 1..5 for probes 1..5. The captured JK02_24S frames report
`0x07` — bits 0, 1 and 2 set — while those exact three sensors are returning sane
readings (19.0, 19.1 and 21.0 °C).

So either the polarity is inverted (it is a *present* mask) or the label is
wrong. **Nothing is filtered on this field.** It is carried through raw as
`BmsSnapshot.temperatureSensorMask`. Do not use it to hide readings until this
is settled.

### 3. Bytes 168 and 169 on JK02_24S

The reference reads byte 168 as "precharging" and 169 as "balancer working" for
every variant. In the captured JK02_24S frames those bytes hold `0xAA` and
`0x06`, which are not booleans. The reference's byte table was written from a
JK02_32S capture, so these fields most likely do not exist in the 24S framing.

Handled as:

- `prechargeOn` is **null** on JK02_24S.
- `balancerActive` on JK02_24S is derived from byte 140, the balancing-action
  byte, which the reference calls the legacy balancing indicator and which reads
  a sane `0x00` in the same captures.

### 4. Which cells are balancing

The JK02 frame reports *that* balancing is happening and at what current, but
not *which* cell. `BmsSnapshot.inferredBalancingCells` is this app's inference
(cells at the extreme the balancer is pulling toward), deliberately named so it
cannot be mistaken for something the BMS said.

### 5. No JK02_32S cell info or settings capture

The reference file contains no JK02_32S cell info frame and no JK02_32S settings
frame. That code path is exercised structurally only — the offset arithmetic is
tested, the values are not. If the pack turns out to be JK02_32S, check the
decoded values against the official app before trusting them.

### 6. Push cadence

The BMS is assumed to push cell info at roughly 1 Hz once asked. `BleTransport`
re-requests every 5 seconds as a nudge in case it goes quiet. Measure the actual
rate and adjust.

## Why raw frames get stored

Every one of the questions above could turn out to have been decoded wrongly for
months. Storing the raw 300-byte frames means the fix is a reparse rather than a
loss. See section 8 of the PRD.

## What this app never does

It never writes settings to the BMS. The only writes are the 20-byte read
requests in `BleTransport._writeCommand`, and the only registers used are the
read-only ones. The protocol is reverse-engineered; a wrong value written to a
protection register can brick the BMS or disable a protection.

## What the app does with all this

Worth recording alongside the protocol notes, because several of these lean on
byte offsets that are still open questions above.

**The capacity test** counts amp-hours out between full and cutoff. It ends on
the discharge MOSFET opening (byte 167) rather than on the charge percentage,
because that byte is the pack actually refusing to give more, while the
percentage is a coulomb counter that drifts. If byte 167 turns out to be wrong
for this framing, the test will run past the end instead of stopping.

**The charge report** keys off cell voltages crossing 4.0 V, which come from the
per-cell block at byte 6 onwards. That block is the best-confirmed part of the
whole protocol, so this one rests on solid ground.

**Ride alerts** use the warning bitmask, the per-cell voltages and the
temperatures. The warning bits are named from the reference's own table; on
JK02_24S only the low 16 exist, so the alerts that map to bits 16-28 can never
fire on that framing. That is a property of the protocol, not a bug here.

**The cutoff voltage** used by both the usable-energy figure and the near-cutoff
alert comes from the settings frame at byte 10 (cell UVP), so it follows how the
pack is actually configured rather than a constant chosen here.
