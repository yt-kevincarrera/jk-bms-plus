import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// The code a buyer reads off the licence screen and sends with the payment.
///
/// Eight bytes, derived from a stable identifier of the install by hashing,
/// shown as four groups of four in an alphabet with no `0/O` or `1/I/L`, so it
/// can be read out over a bad phone line or typed from a photo:
///
/// ```
/// 7K3M-PX9W-4RTB-2HND
/// ```
///
/// The key is bound to these eight bytes and nothing else. Hashing means the
/// raw Android identifier never leaves the phone, and eight bytes is plenty:
/// this is not a secret, it is an address.
class DeviceCode {
  const DeviceCode(this.bytes);

  static const int length = 8;

  /// Crockford-style base32: 32 symbols, none of them confusable.
  static const String alphabet = '23456789ABCDEFGHJKMNPQRSTVWXYZ';

  final List<int> bytes;

  /// Derives the code from any stable string the platform can hand over.
  static Future<DeviceCode> derive(String stableId) async {
    final hash = await Sha256().hash(utf8.encode('jkbms-device:$stableId'));
    return DeviceCode(List<int>.unmodifiable(hash.bytes.sublist(0, length)));
  }

  /// A random code, for a platform with no stable identifier to offer. Has to
  /// be stored by the caller or the next launch invents a different one.
  static DeviceCode random([Random? rng]) {
    final r = rng ?? Random.secure();
    return DeviceCode(
      List<int>.unmodifiable(
        Uint8List.fromList(List<int>.generate(length, (_) => r.nextInt(256))),
      ),
    );
  }

  /// `XXXX-XXXX-XXXX-XXXX`. 64 bits over a 30-symbol alphabet needs 14
  /// symbols; two more make it pad to four even groups. The tail symbols
  /// carry a small check so a typo is caught before the key is even asked
  /// for.
  String get display {
    var n = BigInt.zero;
    for (final b in bytes) {
      n = (n << 8) | BigInt.from(b);
    }
    final base = BigInt.from(alphabet.length);
    final symbols = <String>[];
    for (var i = 0; i < 14; i++) {
      symbols.add(alphabet[(n % base).toInt()]);
      n = n ~/ base;
    }
    // Two check symbols: the sum of the byte values modulo 900, in base 30.
    final sum = bytes.fold<int>(0, (a, b) => a + b) % 900;
    symbols.add(alphabet[sum ~/ 30]);
    symbols.add(alphabet[sum % 30]);
    final s = symbols.join();
    return [
      s.substring(0, 4),
      s.substring(4, 8),
      s.substring(8, 12),
      s.substring(12, 16),
    ].join('-');
  }

  /// Reads a code back from its display form. Forgiving about case, dashes
  /// and spaces, and about the letters people confuse: `O` reads as `0`
  /// would if the alphabet had one, so it is mapped to the nearest real
  /// symbol rather than rejected. Returns null when it does not check out.
  static DeviceCode? parse(String text) {
    var s = text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    s = s
        .replaceAll('O', '0')
        .replaceAll('I', '1')
        .replaceAll('L', '1')
        .replaceAll('U', 'V');
    if (s.length != 16) return null;
    // 0 and 1 are not in the alphabet, and after the substitutions above a
    // genuine typo is the only way they can still be here.
    if (s.contains('0') || s.contains('1')) return null;

    var n = BigInt.zero;
    final base = BigInt.from(alphabet.length);
    for (var i = 13; i >= 0; i--) {
      final v = alphabet.indexOf(s[i]);
      if (v < 0) return null;
      n = n * base + BigInt.from(v);
    }
    final bytes = List<int>.filled(length, 0);
    for (var i = length - 1; i >= 0; i--) {
      bytes[i] = (n & BigInt.from(0xFF)).toInt();
      n = n >> 8;
    }
    if (n != BigInt.zero) return null;

    final c0 = alphabet.indexOf(s[14]);
    final c1 = alphabet.indexOf(s[15]);
    if (c0 < 0 || c1 < 0) return null;
    final sum = bytes.fold<int>(0, (a, b) => a + b) % 900;
    if (c0 * 30 + c1 != sum) return null;
    return DeviceCode(List<int>.unmodifiable(bytes));
  }

  bool matches(List<int> other) {
    if (other.length != bytes.length) return false;
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] != other[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) => other is DeviceCode && matches(other.bytes);

  @override
  int get hashCode => Object.hashAll(bytes);

  @override
  String toString() => display;
}
