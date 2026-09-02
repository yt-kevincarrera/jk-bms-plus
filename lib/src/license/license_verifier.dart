import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'device_code.dart';
import 'license_key.dart';
import 'license_payload.dart';

/// Why a key was turned down. Each one has a sentence on the licence screen.
enum LicenseRejection {
  /// The text is not a key at all.
  malformed,

  /// Well-formed, but not signed by the author's key. Somebody made it up,
  /// or a character was mistyped.
  badSignature,

  /// Signed for a different phone.
  wrongDevice,

  /// Signed, for this phone, and past its end date.
  expired,
}

/// What checking a key produced.
class LicenseCheck {
  const LicenseCheck._({this.payload, this.rejection, this.detail = ''});

  const LicenseCheck.accepted(LicensePayload payload)
    : this._(payload: payload);

  const LicenseCheck.rejected(LicenseRejection why, {String detail = ''})
    : this._(rejection: why, detail: detail);

  final LicensePayload? payload;
  final LicenseRejection? rejection;

  /// Free text for the malformed case, from the parser.
  final String detail;

  bool get accepted => payload != null;
}

/// Checks a licence key against the author's public key, on the phone, with
/// no network.
///
/// Ed25519. The private half lives on the author's machine and nowhere else;
/// the public half is compiled into the app. A key checks out when the
/// signature covers exactly the payload bytes, the payload names this phone,
/// and it has not run out.
///
/// Nothing here phones home, and nothing ever will: the whole point of the
/// scheme is that it works on a phone with no data plan.
class LicenseVerifier {
  LicenseVerifier({required List<int> publicKey})
    : _publicKey = SimplePublicKey(
        Uint8List.fromList(publicKey),
        type: KeyPairType.ed25519,
      );

  final SimplePublicKey _publicKey;
  static final Ed25519 _algorithm = Ed25519();

  /// [now] is injectable so the expiry rule can be tested without waiting a
  /// year.
  Future<LicenseCheck> check(
    String text, {
    required DeviceCode device,
    DateTime? now,
  }) async {
    final LicenseKey key;
    try {
      key = LicenseKey.parse(text);
    } on LicenseFormatException catch (e) {
      return LicenseCheck.rejected(
        LicenseRejection.malformed,
        detail: e.message,
      );
    }

    final ok = await _algorithm.verify(
      key.payloadBytes,
      signature: Signature(key.signature, publicKey: _publicKey),
    );
    if (!ok) return const LicenseCheck.rejected(LicenseRejection.badSignature);

    // Decoded only now. A payload is data the phone acts on, and acting on
    // unsigned data is how every licence scheme gets its first crack.
    final payload = key.payload;
    if (!device.matches(payload.deviceCode)) {
      return const LicenseCheck.rejected(LicenseRejection.wrongDevice);
    }
    if (payload.isExpiredAt(now ?? DateTime.now().toUtc())) {
      return const LicenseCheck.rejected(LicenseRejection.expired);
    }
    return LicenseCheck.accepted(payload);
  }
}

/// The signing side. Used by the author's tool and by the tests; the app
/// never holds a private key and must never import this into a screen.
class LicenseSigner {
  const LicenseSigner(this._keyPair);

  final SimpleKeyPair _keyPair;

  static final Ed25519 _algorithm = Ed25519();

  static Future<LicenseSigner> generate() async =>
      LicenseSigner(await _algorithm.newKeyPair());

  /// Rebuilds the pair from the 32-byte seed the tool keeps on disk.
  static Future<LicenseSigner> fromSeed(List<int> seed) async =>
      LicenseSigner(await _algorithm.newKeyPairFromSeed(seed));

  Future<List<int>> get seed => _keyPair.extractPrivateKeyBytes();

  Future<List<int>> get publicKey async =>
      (await _keyPair.extractPublicKey()).bytes;

  Future<LicenseKey> sign(LicensePayload payload) async {
    final bytes = payload.encode();
    final sig = await _algorithm.sign(bytes, keyPair: _keyPair);
    return LicenseKey(
      payloadBytes: bytes,
      signature: Uint8List.fromList(sig.bytes),
    );
  }
}
