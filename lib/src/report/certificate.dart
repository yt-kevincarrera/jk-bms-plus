import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../inspection/inspection_result.dart';
import '../inspection/inspection_series.dart';

/// A seller's certificate: an inspection, signed by the phone that ran it.
///
/// What it proves, exactly: these figures came out of this app on that day
/// and have not been altered since. Anybody can paste the token back into the
/// app, or scan the QR on the printed sheet, and see the same numbers with the
/// same date. Change one digit and the signature stops matching.
///
/// What it does not prove, and the document says so in as many words: that the
/// pack is good, that the seller is honest, or that the phone that signed it
/// belongs to anybody in particular. A quick test is a quick test. The
/// certificate exists so a buyer can tell a real measurement from a screenshot
/// somebody typed over, which is the fraud that actually happens in the
/// second-hand market.
///
/// The signing key is made on the phone at first use and never leaves it. The
/// author's licence key is deliberately not used: the app would then be
/// vouching for packs it has never seen, and the private half would have to
/// ship inside the APK, where the first person to unzip it could sign
/// anything they liked.
class Certificate {
  const Certificate({
    required this.token,
    required this.content,
    required this.issuerPublicKey,
    required this.signature,
  });

  /// `JKC1.<payload>.<public key>.<signature>`, all base64url without
  /// padding. The whole thing goes in the QR code; the printed sheet also
  /// carries [code] so it can be read out over the phone.
  final String token;

  final CertificateContent content;

  /// The 32 bytes the signature checks against. Travels inside the token, so
  /// verifying needs nothing but the token itself.
  final Uint8List issuerPublicKey;
  final Uint8List signature;

  static const String prefix = 'JKC1';

  /// A short human-readable identifier, `XXXX-XXXX-XXXX`.
  ///
  /// Not a security feature: two certificates could in principle share one,
  /// and it is far too short to be unguessable. It exists so a buyer reading
  /// a printed sheet can say "certificate 7K4M..." out loud and be sure they
  /// are talking about the same piece of paper.
  String get code => shortCode(signature);

  /// The issuing installation, in the same shape. Two certificates from the
  /// same phone show the same one, which is how a buyer notices that the
  /// "independent" inspections of five different bikes all came from one
  /// seller's phone.
  String get issuer => shortCode(issuerPublicKey);

  static String shortCode(List<int> bytes) {
    const alphabet = '23456789ABCDEFGHJKMNPQRSTVWXYZ';
    var n = BigInt.zero;
    for (final b in bytes.take(8)) {
      n = (n << 8) | BigInt.from(b);
    }
    final base = BigInt.from(alphabet.length);
    final symbols = <String>[];
    for (var i = 0; i < 12; i++) {
      symbols.add(alphabet[(n % base).toInt()]);
      n = n ~/ base;
    }
    final s = symbols.join();
    return '${s.substring(0, 4)}-${s.substring(4, 8)}-${s.substring(8, 12)}';
  }
}

/// What the signature covers.
///
/// The whole inspection result, not a summary of it: a certificate that only
/// carried the traffic light would let a seller keep the green and quietly
/// drop the cell that caused the caveat.
class CertificateContent {
  const CertificateContent({
    required this.issuedAt,
    required this.packName,
    required this.result,
    this.note = '',
    this.history = const [],
  });

  final DateTime issuedAt;

  /// Whatever the pack called itself over BLE, plus the model when the BMS
  /// gave one. Not identity: a name can be changed in the official app.
  final String packName;

  final InspectionResult result;

  /// The inspector's own words, when they wrote any.
  final String note;

  /// The earlier runs on this pack, oldest first, in summary.
  ///
  /// Signed along with everything else, and the reason is the whole point of
  /// repeating a test: one run showing a bad cell is a claim a seller can
  /// argue with, and three runs a month apart all naming the same cell is
  /// not. Only the few figures a reader can check are carried, because the
  /// whole thing has to fit in a QR code somebody can scan off a printed
  /// sheet.
  final List<CertifiedRun> history;

  /// Compact and ordered, because these exact bytes are what gets signed:
  /// re-encoding must produce the same thing on any phone or the signature
  /// stops matching for no good reason.
  Uint8List encode() {
    final map = <String, Object?>{
      'v': 1,
      'at': issuedAt.toUtc().toIso8601String(),
      'n': packName,
      'r': result.toJson(),
      if (note.isNotEmpty) 'note': note,
      if (history.isNotEmpty) 'h': [for (final run in history) run.toJson()],
    };
    return Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(map))));
  }

  static CertificateContent decode(Uint8List payload) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(gzip.decode(payload)));
    } on Object {
      throw const CertificateFormatException('payload is not readable');
    }
    if (decoded is! Map) {
      throw const CertificateFormatException('payload is not an object');
    }
    final m = decoded.cast<String, Object?>();
    if (m['v'] != 1) {
      throw const CertificateFormatException('made by a newer version');
    }
    return CertificateContent(
      issuedAt:
          DateTime.tryParse(m['at'] as String? ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      packName: m['n'] as String? ?? '',
      result: InspectionResult.fromJson(
        (m['r'] as Map).cast<String, Object?>(),
      ),
      note: m['note'] as String? ?? '',
      history: [
        for (final e in (m['h'] as List<dynamic>? ?? const []))
          CertifiedRun.fromJson((e as Map).cast<String, Object?>()),
      ],
    );
  }
}

/// One earlier run, as much of it as fits on a certificate.
class CertifiedRun {
  const CertifiedRun({
    required this.at,
    this.worstCell,
    this.worstSagVolts,
    this.restDeltaVolts,
    this.currentStepAmps,
  });

  final DateTime at;

  /// Which cell gave up first that day, 1-based, when a load was pulled.
  final int? worstCell;
  final double? worstSagVolts;
  final double? restDeltaVolts;

  /// What the pull was, so a reader can see whether two runs are comparable.
  final double? currentStepAmps;

  static CertifiedRun from(PastInspection past) {
    final worst = past.result.worstSag;
    return CertifiedRun(
      at: past.at,
      worstCell: worst?.index,
      worstSagVolts: worst?.heavySagVolts,
      restDeltaVolts: past.result.restDeltaVolts,
      currentStepAmps: past.result.currentStepAmps,
    );
  }

  Map<String, Object?> toJson() => {
    't': at.toUtc().toIso8601String(),
    if (worstCell != null) 'c': worstCell,
    if (worstSagVolts != null) 's': _round(worstSagVolts!),
    if (restDeltaVolts != null) 'd': _round(restDeltaVolts!),
    if (currentStepAmps != null) 'i': _round(currentStepAmps!),
  };

  static CertifiedRun fromJson(Map<String, Object?> m) => CertifiedRun(
    at:
        DateTime.tryParse(m['t'] as String? ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    worstCell: (m['c'] as num?)?.toInt(),
    worstSagVolts: (m['s'] as num?)?.toDouble(),
    restDeltaVolts: (m['d'] as num?)?.toDouble(),
    currentStepAmps: (m['i'] as num?)?.toDouble(),
  );

  /// Three decimals is more than the measurement is worth and far less than
  /// a double prints, which matters when the result has to fit in a QR code.
  static double _round(double v) => (v * 1000).roundToDouble() / 1000;
}

class CertificateFormatException implements Exception {
  const CertificateFormatException(this.message);
  final String message;
  @override
  String toString() => 'CertificateFormatException: $message';
}

/// Why a certificate was not accepted.
enum CertificateRejection {
  /// Not a JKC1 token at all, or mangled in transit.
  malformed,

  /// Well formed, and the signature does not match the contents. Somebody
  /// edited the figures after the app produced them.
  badSignature,
}

/// The outcome of checking a pasted or scanned certificate.
class CertificateCheck {
  const CertificateCheck.accepted(this.certificate)
    : rejection = null,
      detail = '';
  const CertificateCheck.rejected(this.rejection, {this.detail = ''})
    : certificate = null;

  final Certificate? certificate;
  final CertificateRejection? rejection;
  final String detail;

  bool get ok => certificate != null;
}

/// Makes and checks certificates.
///
/// Verifying is a static concern: the public key is in the token, so any
/// install can check any certificate with no keys of its own. Signing needs
/// the phone's own key, which [CertificateIdentity] holds.
class Certificates {
  const Certificates();

  static final Ed25519 _algorithm = Ed25519();

  Future<Certificate> issue(
    CertificateContent content,
    SimpleKeyPair keyPair,
  ) async {
    final payload = content.encode();
    final signature = await _algorithm.sign(payload, keyPair: keyPair);
    final publicKey = Uint8List.fromList(
      (await keyPair.extractPublicKey()).bytes,
    );
    final sig = Uint8List.fromList(signature.bytes);
    return Certificate(
      token: [
        Certificate.prefix,
        _b64(payload),
        _b64(publicKey),
        _b64(sig),
      ].join('.'),
      content: content,
      issuerPublicKey: publicKey,
      signature: sig,
    );
  }

  /// Checks a token from a QR scan or a paste.
  ///
  /// The contents are decoded only after the signature has been checked.
  /// Reading a payload first and validating it afterwards is how this kind of
  /// thing gets broken.
  Future<CertificateCheck> check(String text) async {
    final cleaned = text.replaceAll(RegExp(r'\s+'), '');
    final parts = cleaned.split('.');
    if (parts.length != 4 || parts[0].toUpperCase() != Certificate.prefix) {
      return const CertificateCheck.rejected(
        CertificateRejection.malformed,
        detail: 'not a JKC1 certificate',
      );
    }

    final Uint8List payload;
    final Uint8List publicKey;
    final Uint8List signature;
    try {
      payload = _unb64(parts[1]);
      publicKey = _unb64(parts[2]);
      signature = _unb64(parts[3]);
    } on FormatException {
      return const CertificateCheck.rejected(
        CertificateRejection.malformed,
        detail: 'not base64url',
      );
    }
    if (publicKey.length != 32 || signature.length != 64) {
      return const CertificateCheck.rejected(
        CertificateRejection.malformed,
        detail: 'key or signature has the wrong length',
      );
    }

    final ok = await _algorithm.verify(
      payload,
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
      ),
    );
    if (!ok) {
      return const CertificateCheck.rejected(CertificateRejection.badSignature);
    }

    final CertificateContent content;
    try {
      content = CertificateContent.decode(payload);
    } on CertificateFormatException catch (e) {
      return CertificateCheck.rejected(
        CertificateRejection.malformed,
        detail: e.message,
      );
    }
    return CertificateCheck.accepted(
      Certificate(
        token: cleaned,
        content: content,
        issuerPublicKey: publicKey,
        signature: signature,
      ),
    );
  }

  static String _b64(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List _unb64(String s) =>
      base64Url.decode(s + '=' * ((4 - s.length % 4) % 4));
}

/// The phone's own signing key, made once and kept.
///
/// Stored beside the licence state rather than in the database, because it
/// belongs to the installation and not to any pack: a restored backup should
/// not start signing certificates as somebody else's phone.
class CertificateIdentity {
  CertificateIdentity({List<int>? seed}) : _seed = seed;

  static const String seedKey = 'certificate_seed';
  static final Ed25519 _algorithm = Ed25519();

  List<int>? _seed;
  SimpleKeyPair? _pair;

  /// Loads the key, making one on first use.
  Future<SimpleKeyPair> keyPair() async {
    final cached = _pair;
    if (cached != null) return cached;

    var seed = _seed;
    if (seed == null) {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(seedKey);
      if (stored != null) {
        try {
          seed = base64Url.decode(stored);
        } on FormatException {
          seed = null;
        }
      }
      if (seed == null || seed.length != 32) {
        final rng = Random.secure();
        seed = List<int>.generate(32, (_) => rng.nextInt(256));
        await prefs.setString(seedKey, base64Url.encode(seed));
      }
      _seed = seed;
    }

    final pair = await _algorithm.newKeyPairFromSeed(seed);
    _pair = pair;
    return pair;
  }

  /// The short form of this installation's public key, for showing next to
  /// the certificates it issued.
  Future<String> issuerCode() async {
    final pair = await keyPair();
    return Certificate.shortCode((await pair.extractPublicKey()).bytes);
  }
}
