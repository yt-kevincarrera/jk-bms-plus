// The author's side of the licence scheme. Run from the repository root:
//
//   dart run tool/license_keygen.dart keygen  --out ~/.jkbms/license_signing.key
//   dart run tool/license_keygen.dart issue   --key ~/.jkbms/license_signing.key \
//       --device 7K3M-PX9W-4RTB-2HND --tier pro
//   dart run tool/license_keygen.dart inspect JKB1.xxxx.yyyy
//
// `keygen` writes the private seed to the file given and the public key into
// lib/src/license/license_public_key.dart. Do it once, back the seed up next to
// the APK signing key, and never run it again against a shipped build: a new
// pair invalidates every key already sold. See docs/LICENSING.md.
//
// `issue` prints a key for one phone, plus the message to send back to the
// buyer. Nothing is stored here; the buyer's phone is the record.
import 'dart:io';

import 'package:jk_bms/src/license/device_code.dart';
import 'package:jk_bms/src/license/license_key.dart';
import 'package:jk_bms/src/license/license_payload.dart';
import 'package:jk_bms/src/license/license_verifier.dart';

const _publicKeyFile = 'lib/src/license/license_public_key.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _usage();
    exit(64);
  }
  final command = args.first;
  final rest = args.sublist(1);
  try {
    switch (command) {
      case 'keygen':
        await _keygen(_options(rest));
      case 'issue':
        await _issue(_options(rest));
      case 'inspect':
        await _inspect(rest);
      default:
        _usage();
        exit(64);
    }
  } on _Fail catch (e) {
    stderr.writeln('error: ${e.message}');
    exit(1);
  }
}

void _usage() {
  stderr.writeln('''
Licence tool for JK BMS +

  keygen  --out <seed file> [--force]
      Generate the signing pair. Writes the 32-byte seed (hex) to <seed file>
      and the public key into $_publicKeyFile.

  issue   --key <seed file> --device XXXX-XXXX-XXXX-XXXX --tier pro|workshop|credits|admin
          [--expires YYYY-MM-DD] [--inspections N] [--certificates N] [--label "text"]
      Sign a key for one phone and print it with the message to send.

  inspect <key text> [--key <seed file>]
      Decode a key. Verifies the signature against the seed when given,
      otherwise against the public key compiled into the app.
''');
}

// --- keygen ---

Future<void> _keygen(Map<String, String> o) async {
  final out = o['out'];
  if (out == null) {
    throw const _Fail('--out <seed file> is required');
  }
  final file = File(out);
  if (file.existsSync() && !o.containsKey('force')) {
    throw _Fail(
      '$out exists. A second pair would invalidate every key signed with the '
      'first; pass --force only if you mean that.',
    );
  }

  final signer = await LicenseSigner.generate();
  final seed = await signer.seed;
  final public = await signer.publicKey;

  file.parent.createSync(recursive: true);
  file.writeAsStringSync('${_hex(seed)}\n');
  // Owner-only, where the platform lets us.
  if (!Platform.isWindows) {
    await Process.run('chmod', ['600', file.path]);
  }

  _writePublicKeyFile(public);

  stdout.writeln(
    'Seed written to ${file.path}  (back this up; it cannot be recreated)',
  );
  stdout.writeln('Public key written to $_publicKeyFile:');
  stdout.writeln('  ${_hex(public)}');
  stdout.writeln('Rebuild the app so it carries the new public key.');
}

void _writePublicKeyFile(List<int> public) {
  final f = File(_publicKeyFile);
  if (!f.existsSync()) {
    throw _Fail('$_publicKeyFile not found; run from the repo root');
  }
  final src = f.readAsStringSync();
  final start = src.indexOf('const List<int> licensePublicKey = [');
  final end = src.indexOf('];', start);
  if (start < 0 || end < 0) {
    throw const _Fail('could not find the constant to rewrite');
  }

  final rows = <String>[];
  for (var i = 0; i < 32; i += 8) {
    final row = public
        .sublist(i, i + 8)
        .map((b) => '0x${b.toRadixString(16).padLeft(2, '0').toUpperCase()}')
        .join(', ');
    rows.add('  $row, //');
  }
  final replacement =
      'const List<int> licensePublicKey = [\n${rows.join('\n')}\n';
  f.writeAsStringSync(src.replaceRange(start, end, replacement));
}

// --- issue ---

Future<void> _issue(Map<String, String> o) async {
  final signer = await _signerFrom(o['key']);
  final deviceText = o['device'];
  if (deviceText == null) {
    throw const _Fail('--device is required');
  }
  final device = DeviceCode.parse(deviceText);
  if (device == null) {
    throw _Fail(
      '"$deviceText" is not a device code: 16 symbols from ${DeviceCode.alphabet}, '
      'and its check symbols must agree. Ask the buyer to copy it again.',
    );
  }

  final tier = switch (o['tier']) {
    'pro' => LicenseTier.pro,
    'workshop' || 'taller' => LicenseTier.workshop,
    'credits' || 'chequeos' => LicenseTier.credits,
    'admin' => LicenseTier.admin,
    final other => throw _Fail(
      '--tier must be pro, workshop, credits or admin (got $other)',
    ),
  };

  DateTime? expires;
  final expiresText = o['expires'];
  if (expiresText != null) {
    final parsed = DateTime.tryParse('${expiresText}T00:00:00Z');
    if (parsed == null) {
      throw _Fail('--expires must be YYYY-MM-DD (got $expiresText)');
    }
    expires = parsed;
  }
  if (tier == LicenseTier.workshop && expires == null) {
    throw const _Fail('a workshop key needs --expires: it is sold by the year');
  }
  if ((tier == LicenseTier.pro || tier == LicenseTier.admin) &&
      expires != null) {
    throw const _Fail('a Pro or admin key is for life; drop --expires');
  }

  final inspections = int.tryParse(o['inspections'] ?? '0') ?? -1;
  final certificates = int.tryParse(o['certificates'] ?? '0') ?? -1;
  if (inspections < 0 || certificates < 0) {
    throw const _Fail('--inspections and --certificates must be whole numbers');
  }
  if (tier == LicenseTier.credits && inspections == 0 && certificates == 0) {
    throw const _Fail('a credits key with no credits unlocks nothing');
  }

  final payload = LicensePayload(
    tier: tier,
    deviceCode: device.bytes,
    issuedAt: DateTime.now().toUtc(),
    expiresAt: expires,
    inspectionCredits: inspections,
    certificateCredits: certificates,
    label: o['label'] ?? '',
  );
  final key = await signer.sign(payload);
  final text = key.encode();

  // Belt and braces: check the key the way the phone will before handing it
  // over, so a bug here is caught by the author and not by the buyer.
  final verifier = LicenseVerifier(publicKey: await signer.publicKey);
  final check = await verifier.check(text, device: device);
  if (!check.accepted) {
    throw _Fail(
      'the key just signed does not verify (${check.rejection}); not issuing',
    );
  }

  stdout.writeln('Key (${text.length} chars):');
  stdout.writeln();
  stdout.writeln(text);
  stdout.writeln();
  stdout.writeln('--- message to send ---');
  stdout.writeln(_messageFor(payload, text));
}

String _messageFor(LicensePayload p, String text) {
  final what = switch (p.tier) {
    LicenseTier.pro => 'JK BMS + Pro, de por vida para este teléfono',
    LicenseTier.workshop =>
      'JK BMS + Pro Taller, hasta el ${_date(p.expiresAt!)}',
    LicenseTier.credits => [
      if (p.inspectionCredits > 0) '${p.inspectionCredits} chequeo(s)',
      if (p.certificateCredits > 0) '${p.certificateCredits} certificado(s)',
    ].join(' y '),
    LicenseTier.admin =>
      'JK BMS + acceso total (admin), sin límites ni caducidad',
  };
  final extras = <String>[
    if (p.tier != LicenseTier.credits && p.inspectionCredits > 0)
      'Incluye ${p.inspectionCredits} chequeo(s).',
    if (p.tier != LicenseTier.credits && p.certificateCredits > 0)
      'Incluye ${p.certificateCredits} certificado(s).',
  ];
  return [
    'Listo: $what.',
    ...extras,
    '',
    'Tu clave:',
    text,
    '',
    'En la app: Ajustes → Licencia → Pegar clave → Activar. '
        'No hace falta internet. Guarda este mensaje: si reinstalas la app, '
        'la misma clave vuelve a servir.',
  ].join('\n');
}

// --- inspect ---

Future<void> _inspect(List<String> args) async {
  // The key text is whatever is not an option. Options take their value
  // from the next argument, so `--key path` is not two pieces of key.
  final positional = <String>[];
  final flags = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i].startsWith('--')) {
      flags.add(args[i]);
      if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
        flags.add(args[++i]);
      }
    } else {
      positional.add(args[i]);
    }
  }
  final o = _options(flags);
  if (positional.isEmpty) {
    throw const _Fail('give the key text to inspect');
  }
  final text = positional.join();

  final LicenseKey key;
  try {
    key = LicenseKey.parse(text);
  } on LicenseFormatException catch (e) {
    throw _Fail('not a key: ${e.message}');
  }
  final payload = key.payload;
  stdout.writeln('id:            ${key.id}');
  stdout.writeln('tier:          ${payload.tier.name}');
  stdout.writeln('device code:   ${DeviceCode(payload.deviceCode).display}');
  stdout.writeln('issued:        ${payload.issuedAt.toIso8601String()}');
  stdout.writeln(
    'expires:       ${payload.expiresAt?.toIso8601String() ?? 'never'}',
  );
  stdout.writeln('inspections:   ${payload.inspectionCredits}');
  stdout.writeln('certificates:  ${payload.certificateCredits}');
  stdout.writeln(
    'label:         ${payload.label.isEmpty ? '(none)' : payload.label}',
  );

  final List<int> publicKey;
  if (o['key'] != null) {
    publicKey = await (await _signerFrom(o['key'])).publicKey;
  } else {
    publicKey = _publicKeyFromSource();
  }
  final check = await LicenseVerifier(
    publicKey: publicKey,
  ).check(text, device: DeviceCode(payload.deviceCode));
  stdout.writeln(
    'signature:     ${check.accepted ? 'valid' : 'INVALID (${check.rejection?.name})'}',
  );
}

List<int> _publicKeyFromSource() {
  final src = File(_publicKeyFile).readAsStringSync();
  final start = src.indexOf('const List<int> licensePublicKey = [');
  final end = src.indexOf('];', start);
  final body = src.substring(start, end);
  final bytes = RegExp(
    r'0x([0-9A-Fa-f]{2})',
  ).allMatches(body).map((m) => int.parse(m.group(1)!, radix: 16)).toList();
  if (bytes.length != 32) {
    throw const _Fail('public key constant is not 32 bytes');
  }
  if (bytes.every((b) => b == 0)) {
    throw const _Fail('the app has no public key yet; run keygen first');
  }
  return bytes;
}

// --- helpers ---

Future<LicenseSigner> _signerFrom(String? path) async {
  if (path == null) {
    throw const _Fail('--key <seed file> is required');
  }
  final file = File(path);
  if (!file.existsSync()) {
    throw _Fail('$path not found');
  }
  final hex = file.readAsStringSync().trim();
  if (hex.length != 64) {
    throw _Fail('$path does not hold a 32-byte hex seed');
  }
  final seed = [
    for (var i = 0; i < 64; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ];
  return LicenseSigner.fromSeed(seed);
}

Map<String, String> _options(List<String> args) {
  final out = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (!a.startsWith('--')) {
      throw _Fail('unexpected argument $a');
    }
    final name = a.substring(2);
    final hasValue = i + 1 < args.length && !args[i + 1].startsWith('--');
    out[name] = hasValue ? args[++i] : '';
  }
  return out;
}

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

String _date(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

class _Fail implements Exception {
  const _Fail(this.message);
  final String message;
}
