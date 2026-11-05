# BLE startup recovery without useful readings

Date: 2026-11-05. Baseline: `e2349c3` (v2.32.1).
Release version: `2.32.2+2080`. The checks below describe source verification
before release packaging; physical BMS acceptance remains pending.

The rider reports repeatedly needing to restart the phone, an approximate
`connected / negotiating / reconnecting / idle` sequence, and the diagnostic
`Asked the pack for cell info again ... no usable cell readings have arrived
on this link`. The BMS is unavailable during this investigation. That message
matches `BmsService._armCellInfoRequests`; it proves that useful readings are
missing, without identifying whether the peripheral is silent or sending
undecodable data.

## Reproduced defects

1. `ConnectScreen` feeds service events into `FirstContact` and disconnects
   after any unsuccessful verdict. Its old silence budget was 12 seconds,
   whereas `BleTransport` releases a mute link after 20 seconds, checked every
   five seconds. The screen therefore cancelled the recovery before it ran.
   The regression reached `connectedButSilent` at exactly 12 seconds and left
   the actual service in `idle`. A pre-fix control with a longer contact budget
   passed: mute release, second GATT connection, captured JK device/cell frames,
   decoded snapshots and a successful initial-contact verdict.
2. Recovery recorded a successful attempt after two seconds of GATT connection,
   even without a usable reading. Each apparent success cleared its failure
   streak, preventing the release/fresh-advert preparation intended for repeated
   failures. A real-transport regression made at least three mute connections
   and expected `freshAdvert ... 8s`; the observed recovery log was empty.

Both reproductions use the real FlutterBluePlus 2.3.12 Dart plugin and transport
with a fake platform. They are evidence of application defects, not evidence
that either is the sole cause of the physical phone requiring a restart.

## Changes

- Initial contact gives each connected link 30 seconds and waits through retry
  negotiation, with an absolute 75-second budget measured from the original
  attempt. Duplicate connected events do not extend a link's budget.
- GATT readiness keeps the recovery outcome pending. Only a usable battery
  reading, together with the existing hold time, confirms success.
- A mute timeout counts toward the recovery streak. After two such failures,
  the next attempt releases the link and checks for a fresh advertisement.
- A drop while still waiting for readings counts as a failed attempt even after
  the GATT hold interval. Deliberate disconnect still cancels the attempt.
- An injectable transport clock lets regression tests use the production mute
  and polling intervals deterministically. The startup regression recovers at
  the 25-second poll, waits the three-second retry pause, and reads on attempt 2.

## Verification

The regression tests exercise the actual transport, service streams, parser and
initial-contact decision. Existing coverage also exercises bootstrap readings,
split/combined GATT, ANT reads, manual/automatic recovery and retry exhaustion.

| Local check | Result |
| --- | --- |
| Contact decision and integrated startup recovery | 14 tests passed |
| Existing BLE/recovery/proximity/hands-free coverage | 104 tests passed |
| GATT drop after the hold time without readings | 1 test passed |
| Independent source review | No blocking findings; suggested late-drop coverage added |
| `flutter analyze --no-pub` | No issues found (233.6 seconds) |
| `git diff --check` | Passed |
| Android build and device installation | Not run |

The checks use `flutter test --no-pub --concurrency 1 --reporter expanded`.
The startup and reading-accounting regressions are
`test/first_contact_transport_test.dart` and
`test/ble_transport_reading_recovery_test.dart`; the late-drop regression is
`test/ble_transport_pending_reading_test.dart`. Static analysis runs with
`flutter analyze --no-pub`.

Physical acceptance remains pending: install the corrected build on the affected
phone, reproduce the problematic startup without restarting, verify new cell
readings after recovery, and retain the diagnostic attempt records. If the
problem persists, the useful evidence is received bytes, valid frames, decode
failures, MTU, variant and the attempts' recovery steps. Phone model and installed
app version were requested but were not available for this investigation.
