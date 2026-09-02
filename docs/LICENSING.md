# Licences

The app is sold without a store, a server or an account. A licence is a short
string the buyer pastes in once, and the phone checks it by itself. This
document is the whole mechanism; the product reasoning is in
[PRD-monetizacion-inspeccion.md](PRD-monetizacion-inspeccion.md), section 6.

## Tiers

| Status | How it comes about | What it unlocks |
|---|---|---|
| Free | No key, trial over | The complete live viewer, 24 h of history |
| Trial | First 7 days after the build that knows about licences is first run | Everything Pro |
| Pro | A `pro` key | Unlimited history, degradation and curves, verdicts, alerts with the app closed, backup export/import, and the rest of `Feature` |
| Pro Taller | A `workshop` key, with an end date | Everything Pro, inspections and certificates without counting, workshop extras |
| Credits | A `credits` key | N inspections and/or N certificates, nothing else |

The list of what is gated lives in one place, `Entitlements.allows` in
`lib/src/license/entitlements.dart`. Screens ask it and do not decide for
themselves. A Pro key never expires. A workshop key always does. Credits are
counted on the phone: the key says how many were bought, the phone remembers
how many were used, and the difference is what is left.

Everything below `BmsSnapshot` — reading, decoding, showing — is free and stays
free. A free tier worse than the official JK app sends people back to it.

## What the buyer does

1. Ajustes → Licencia. The screen shows a **device code**, sixteen symbols in
   four groups (`7K3M-PX9W-4RTB-2HND`). "Copiar mensaje de solicitud" puts a
   ready-to-send message on the clipboard with the code and the app version.
2. They pay (Transfermóvil, EnZona, Zelle — see the PRD) and send the proof
   plus the code by Telegram or WhatsApp.
3. They receive a key, ~125 characters starting `JKB1.`, and paste it in the
   same screen. Line breaks and spaces from the chat do not matter.
4. The phone verifies the signature, checks the code matches, and unlocks. No
   internet at any point.

## What the author does

Once, ever:

```bash
dart run tool/license_keygen.dart keygen --out ~/.jkbms/license_signing.key
```

This writes a 32-byte Ed25519 seed to the file and the matching public key into
`lib/src/license/license_public_key.dart`. Commit the Dart file; **never** the
seed. Back the seed up alongside the APK signing key described in
[RELEASING.md](RELEASING.md), and treat it the same way: lose it and no more
keys can be issued for any build already out there; leak it and anybody can
issue keys.

Until `keygen` has been run the public key constant is all zeros. Such a build
accepts no key at all, says so on the licence screen, and still runs the trial.

For every sale:

```bash
# Pro individual, for life
dart run tool/license_keygen.dart issue --key ~/.jkbms/license_signing.key \
    --device 7K3M-PX9W-4RTB-2HND --tier pro

# Pro Taller, one year, with the workshop's name on its reports
dart run tool/license_keygen.dart issue --key ~/.jkbms/license_signing.key \
    --device 7K3M-PX9W-4RTB-2HND --tier workshop --expires 2027-09-02 \
    --label "Taller El Rayo"

# Three inspection checks for somebody buying one battery
dart run tool/license_keygen.dart issue --key ~/.jkbms/license_signing.key \
    --device 7K3M-PX9W-4RTB-2HND --tier credits --inspections 3
```

The tool refuses a device code whose check symbols do not agree (a typo in the
buyer's message), verifies the key it just signed the way the phone will, and
prints the message to send back. Nothing is recorded anywhere; if a record of
sales is wanted, keep it by hand or let the future Telegram bot keep it.

To read a key back:

```bash
dart run tool/license_keygen.dart inspect JKB1.xxxx.yyyy
```

## Key format

```
JKB1.<payload, base64url without padding>.<Ed25519 signature, 64 bytes, base64url>
```

The payload is a fixed little-endian layout (`LicensePayload` documents every
byte): version, tier, the 8-byte device code, issued-at, expires-at (0 = never),
inspection credits, certificate credits, and a short UTF-8 label. A Pro key is
23 bytes of payload and 64 of signature, about 125 characters in all.

The device code is the first 8 bytes of SHA-256 over Android's `ANDROID_ID`,
which on Android 8+ is per app-signing-key and per user, and survives a
reinstall of the same app. The raw identifier never leaves the phone, only the
hash. Where there is no such identifier the phone draws a random code once and
keeps it in preferences.

## What this does not defend against

Somebody will pull the APK apart, replace the public key with their own and
issue themselves keys, or clear the app's data to restart the trial. Both are
known and accepted, per the PRD: the key is per device, the honest buyer's path
is short, and the time goes into the product rather than into an arms race. Do
not add obfuscation, server checks or anti-tamper here.

## Re-issuing

A factory reset changes `ANDROID_ID`, so the buyer's old key stops matching.
They send the new code, the author issues again. Cheap, and rare.
