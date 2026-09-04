# JK BMS +

A phone app for a JK (Jikong) Smart BMS over Bluetooth LE. Read-only, on
purpose: it never writes settings to the BMS.

Target pack: Yoazaky 72 V 45 Ah, 20S Li-ion NMC, on an electric motorcycle.

The official JK app works but forgets everything the moment you close it. The
phone has three things the BMS does not — storage, GPS and a decent screen — and
that is where all the value here comes from.

## What it does

**Live pack view.** Every cell, coloured so the one out of line is findable
without reading a number. Temperatures against current over time. Full read
parity with the official app.

**Adaptive range.** The app measures the watt-hours actually leaving the pack
and divides them by the kilometres from the phone's GPS. Every ride corrects the
estimate, so the number settles onto how you ride, on your terrain, with your
load. It is quoted as a band, and the band narrows as the estimate earns it.

**Trip mode.** Speedometer, distance, top and average speed, climb and descent,
with pause and resume — alongside what the pack did over that same ride. Keeps
recording with the screen off. Every trip is stored with its track.

**The numbers the vendor would rather not show.** Implied real capacity against
what the pack was sold as. Honest full-equivalent cycles against the BMS's
inflated counter. Amp-hours stranded by the weakest cell. Which cell keeps
coming last.

**Verdicts.** Plain-language conclusions from what has actually been measured —
a delta present at rest means capacity mismatch, a delta that only appears under
load means a connection, and those are different jobs with different fixes. Each
sentence opens on a tap to show the numbers it rests on, and the app says
"nothing to do" out loud when it checked and found nothing, because silence and
a clean bill of health look the same on a screen. Figures the BMS lets anyone
edit, cycles and configured capacity, are always set against what the amp-hours
actually say.

**Capacity test.** The one honest measurement here: charge to full, ride to
cutoff, and it counts the amp-hours that actually came out. Everything else in
the app is arithmetic on what the BMS says about itself; this is the number that
settles whether the pack is what it was sold as.

**Charge report.** Above 4.0 V per cell the voltage curve turns steep, so a
small mismatch in capacity becomes a large gap in voltage. That window is the
best diagnosis a pack ever offers and the one nobody watches, because charging
happens overnight. Recorded whenever the app happens to be connected.

**Alerts while riding.** Nobody looks at the screen at 60 km/h, so the phone
buzzes when the spread, the temperature, a cell near cutoff or the BMS itself
crosses a line. Each one fires once and needs to genuinely clear before it can
fire again.

**Over time.** Consumption per ride, measured capacity, sag as apparent internal
resistance, and delta plotted against charge — all from rows already being
stored. Each says how many days of history is behind it.

**Export.** Trips and readings as CSV, tracks as GPX, and the raw frames as hex
so the history can be re-read if a byte offset here turns out to be wrong.

**Updates from inside the app.** There is no store, so the System tab asks
GitHub whether a newer release exists and installs it if you say so. Nothing
checks on a timer, nothing downloads on its own, and Android's own install
prompt appears every time. The builds are split per architecture, so the phone
fetches ~21 MB instead of the 58 MB a universal package costs.

**Several batteries, kept apart.** Everything the app concludes — capacity,
degradation, which cell lags, what a kilometre costs — is about one specific
pack. Each BMS the phone connects to gets its own history, its own catalogue
capacity and its own learned consumption, keyed on the BLE address. Pooling two
packs would not average them; it would describe a battery that does not exist.

**Free, trial, Pro.** The live viewer is free and stays free, so nobody has a
reason to go back to the official app. What the official app cannot do —
history past a day, degradation and the long-term curves, the verdicts, alerts
with the app closed, backup — is Pro: a single payment, for life, bound to a
device code shown in Ajustes → Licencia. A 7-day trial of the full thing runs
from first launch. Keys are Ed25519 signatures checked on the phone; there is
no account and no server. None of this is switched on yet: until the signing
key pair exists the app is fully open and shows nothing about licences.
[docs/LICENSING.md](docs/LICENSING.md) has the mechanism, the switch and the
tool that issues keys.

**Demo mode.**

 A simulated 20S pack generating real 300-byte frames through the
real parser, so every screen can be judged with no BMS in the room. Demo rides
are stored and learned from in their own world, so you can watch the learning
work without it ever touching what the app believes about the real pack.

Spanish by default, English available, remembered across restarts.

## Status

| Milestone | State |
|---|---|
| M1 — transport, frame assembly, parser | Done, pending validation against the real BMS |
| M2 — SQLite persistence | Done: trips, tracks, readings, raw frames with 30-day rotation |
| M3 — trips and GPS | Done: recording, pause/resume, background, stored history |
| M4 — parity UI | Done |
| M5 — reconnection robustness | Partly: auto-reconnect and resync are in, not yet exercised against a real radio |
| M6 — derived metrics | Done: range learning, health report, advice, capacity test, charge report and the long-term curves. The curves need months of riding before they mean much, and say so themselves |
| M7 — licences | Done, and switched off: device code, Ed25519 keys checked on the phone, 7-day Pro trial, Pro/Workshop/credits/admin tiers, gating. Nothing shows and nothing is gated until the author generates the key pair, which is the launch switch (see [docs/LICENSING.md](docs/LICENSING.md)) |
| M8 — verdicts | Done: every sentence the app says about a pack carries the measured facts behind it, one tap away. Headlines for measured wear, a cell drifting over weeks, kilometres left in the rider's own terms, and an explicit all-clear on the delta under load. One engine feeds the Health tab and the saved-pack screen. Thresholds live in one object, to be calibrated on real packs |
| M9 — inspection | Done: a separate mode on the connect screen for somebody else's pack. One instruction at a time in large letters (rest, light load, heavy load, release), the step advances on the current the BMS reports, no timers and no next button. The analysis runs once at the end over everything captured: per-cell sag under load, resistance from the current step, recovery time, the resting spread, temperature and alarms; the verdict is one traffic light plus the same evidence-backed sentences the Health tab uses, next to what the BMS reports about itself marked as editable. The stranger's pack is never adopted, so the rider's history and range never learn from it; inspections are stored on their own and listed from Settings. A demo rehearsal plays a seller's battery with one weak cell |
| M10 — PDF and certificate | Done: two printable sheets. The battery sheet is what a rider takes to a workshop or attaches to an advert, with the measured capacity, the wear against the pack's own best, the learned range, the drifting cells, the verdicts with their evidence, and the recorded maintenance; what the BMS merely claims is printed apart from what was measured. The inspection sheet is the same verdict a buyer saw in the yard, cell table included. Either can be signed as a seller certificate: the phone makes its own Ed25519 key at first use, the signature covers the whole result, and a QR plus a short code let anybody check it back in the app with no key, no account and no network. The signature proves the figures were not edited after the app produced them, and the sheet says in as many words that it proves nothing else |
| M11 — onboarding, M12 — background alerts, M13 — config audit | Not started. Specified in [docs/PRD-monetizacion-inspeccion.md](docs/PRD-monetizacion-inspeccion.md) |

## Running it

```bash
flutter run
```

**Close the official JK app first.** The BMS accepts exactly one Bluetooth
connection at a time. There is no multiplexing, which also rules out running an
ESP32 logger in parallel.

Android permissions: `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`,
`ACCESS_FINE_LOCATION` (Android requires location permission for BLE scanning),
plus `FOREGROUND_SERVICE_LOCATION` and `POST_NOTIFICATIONS` so a trip survives
the screen going off and can carry its live readout. `INTERNET` and
`REQUEST_INSTALL_PACKAGES` exist only for the self-update, which talks to
api.github.com and nothing else -- no pack data, ride or location ever leaves
the phone, because there is no server to send it to.

The catalogue capacity, the alert buzz and raw-frame capture are settings in the
System tab. The catalogue figure is worth setting correctly: every health number
in the app is measured against it. Set it to **what the pack was sold as**, not
to what the BMS is configured for -- those are two different claims by two
different people, and when they disagree the app says so rather than quietly
adopting the smaller one.

## Verifying against the real pack

The open questions are listed in [docs/PROTOCOL.md](docs/PROTOCOL.md). While
watching the first real connection, settle these:

1. Does the System tab report the variant you expect for this firmware?
2. Is the cell count 20?
3. Does the pack voltage match the sum of the cells, and a multimeter?
4. Which sign does `current` take while discharging under load?
5. How many temperature probes read plausible values?
6. Does the passcode shown in the System tab match the one you set in the
   official app? If it does, the BMS is broadcasting its own password to any
   client that asks, and the official app's prompt is a local check.

## Tests

```bash
flutter test
```

576 tests, no device needed. The protocol ones run against 11 real 300-byte
frames captured from JK hardware, with expected values taken from the reference
implementation's byte-layout tables rather than from this parser's own output.

## Layout

```
lib/src/
  protocol/   jk_constants, jk_checksum, byte_reader, jk_frame,
              frame_assembler, protocol_variant, jk_parser
  model/      bms_snapshot, jk_device_info, jk_settings, bms_warning
  ble/        bms_link (interface), ble_transport, switchable_link,
              simulator/ (frame builder, pack model, simulated link)
  gps/        location_source, simulated_location_source
  metrics/    snapshot_history, range_estimator, trip_recorder,
              altitude_tracker, pack_health_report, advice_engine,
              capacity_test_runner, charge_session, ride_alerts,
              long_term_analysis
  data/       database (drift), repository, exporter
  update/     app_version, release_info, update_checker, update_downloader,
              update_service
  license/    license_payload, license_key, device_code, license_verifier,
              entitlements, license_controller, device_identity,
              license_public_key (the author's public key; see docs/LICENSING.md)
  inspection/ inspection_session (the guided steps, driven by the readings),
              inspection_result (the analysis), inspection_verdicts
  report/     report_data, pdf_reports (the printed sheets), certificate
              (signing and checking), report_sharing
  platform/   live_notification (the foreground service)
  ui/         theme, tabs/, widgets/, inspection/, trip_screen,
              trip_detail_screen, trends_screen
  bms_service.dart   the single stream everything else reads from
```

The layering is the point. One connection, one assembler, one parser, one
snapshot stream, and screens are views of it. Everything above `BmsSnapshot` —
the metrics, the health report, the trip recorder, all six tabs — knows nothing
about JK, which is what would make another vendor's BMS a new parser rather than
a new app.

## Protocol

The BLE protocol is not documented by the vendor. Every constant and byte offset
came from community reverse engineering and is cited in the code. Read
[docs/PROTOCOL.md](docs/PROTOCOL.md) before touching `lib/src/protocol/` — it
also lists where the reference and the captured data disagree, and what still
has to be checked against the pack.

## Installing on your own phone

```bash
./tool/install.sh
```

Builds only the ABI the connected phone reports and installs over the existing
app, keeping its data. No GitHub and no token involved -- that path is for
phones that are not plugged into the machine that builds them.

## Releasing

The in-app updater has been exercised end to end on a Pixel 6: check, download
over the public release, and hand-off to the system installer.


Builds are published as GitHub releases, split per ABI, and the app updates
itself from them. The signing key is what makes that possible and losing it
ends it permanently -- read [docs/RELEASING.md](docs/RELEASING.md) before
cutting one.

## Out of scope


Writing to the BMS. Multi-pack support. Cloud, accounts, sync. Store
publication. Other BMS brands, for now.
