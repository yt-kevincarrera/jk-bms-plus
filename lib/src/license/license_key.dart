import 'dart:convert';
import 'dart:typed_data';

import 'license_payload.dart';

/// The text form of a licence: what the buyer pastes into the app.
///
/// ```
/// JKB1.<payload, base64url>.<signature, base64url>
/// ```
///
/// Three parts joined by dots. Base64url has no `+` or `/`, and the padding
/// is dropped, so the string survives a WhatsApp message, a Telegram forward
/// and a screenshot-and-retype without picking up characters it cannot hold.
/// [parse] also strips whitespace and line breaks, because a key copied off a
/// chat bubble arrives wrapped.
class LicenseKey {
  const LicenseKey({required this.payloadBytes, required this.signature});

  static const String prefix = 'JKB1';

  final Uint8List payloadBytes;

  /// 64 bytes of Ed25519 signature over [payloadBytes].
  final Uint8List signature;

  LicensePayload get payload => LicensePayload.decode(payloadBytes);

  /// A short, stable name for this key, for keeping track of which ones have
  /// been activated on a phone. The first bytes of the signature are as
  /// unique as anything gets.
  String get id => _b64(signature.sublist(0, 9));

  String encode() => '$prefix.${_b64(payloadBytes)}.${_b64(signature)}';

  /// Reads the pasted text. Throws [LicenseFormatException] with a reason a
  /// person can act on.
  static LicenseKey parse(String text) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) {
      throw const LicenseFormatException('empty');
    }
    final parts = cleaned.split('.');
    if (parts.length != 3 || parts[0].toUpperCase() != prefix) {
      throw const LicenseFormatException('not a JKB1 key');
    }
    final payload = _unb64(parts[1]);
    final signature = _unb64(parts[2]);
    if (signature.length != 64) {
      throw const LicenseFormatException('signature has the wrong length');
    }
    // Decoded here only to reject nonsense early; the verifier decodes again
    // after checking the signature, which is the order that matters.
    LicensePayload.decode(payload);
    return LicenseKey(payloadBytes: payload, signature: signature);
  }

  static String _b64(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List _unb64(String s) {
    try {
      final padded = s + '=' * ((4 - s.length % 4) % 4);
      return base64Url.decode(padded);
    } on FormatException {
      throw const LicenseFormatException('not base64url');
    }
  }
}
