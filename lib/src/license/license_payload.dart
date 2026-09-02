import 'dart:convert';
import 'dart:typed_data';

/// What a paid key unlocks.
///
/// Free and trial are not tiers a key can carry: free is the absence of a
/// key, and the trial is a clock that starts at install. A key only ever
/// makes things available.
enum LicenseTier {
  /// Pro individual. One payment, one phone, for good.
  pro(1),

  /// Pro Taller. Everything Pro plus the workshop extras, and it expires.
  workshop(2),

  /// A key that carries only credits (inspection checks, certificates) and
  /// unlocks nothing else. For the person buying one battery, once.
  credits(3);

  const LicenseTier(this.code);

  /// The byte the tier is stored as. Explicit, so reordering the enum can
  /// never silently relabel a key somebody has already paid for.
  final int code;

  static LicenseTier? fromCode(int code) {
    for (final t in values) {
      if (t.code == code) return t;
    }
    return null;
  }
}

/// The signed part of a licence key, as bytes.
///
/// Fixed layout, little-endian, so the author's tool and the phone agree on
/// it without a schema:
///
/// ```
/// 0      version (1 byte, currently 1)
/// 1      tier code (1 byte)
/// 2..9   device code (8 bytes) — see DeviceCode
/// 10..13 issued at, unix seconds (uint32)
/// 14..17 expires at, unix seconds (uint32), 0 for never
/// 18..19 inspection credits (uint16)
/// 20..21 certificate credits (uint16)
/// 22     label length (1 byte)
/// 23..   label, UTF-8 (workshop name, buyer's nickname; free text)
/// ```
///
/// Short on purpose. The whole key is pasted by hand from a WhatsApp message
/// on a phone in the street, and every byte here costs about 1.3 characters.
class LicensePayload {
  const LicensePayload({
    required this.tier,
    required this.deviceCode,
    required this.issuedAt,
    this.expiresAt,
    this.inspectionCredits = 0,
    this.certificateCredits = 0,
    this.label = '',
  });

  static const int version = 1;
  static const int deviceCodeLength = 8;
  static const int _fixedLength = 23;
  static const int maxLabelBytes = 64;

  final LicenseTier tier;

  /// The 8-byte device code this key is bound to. See [DeviceCode].
  final List<int> deviceCode;

  /// UTC, whole seconds.
  final DateTime issuedAt;

  /// UTC, or null for a key that never expires. Only workshop keys are
  /// expected to carry one, but nothing here enforces that: the payload
  /// records what was issued, the entitlements decide what it means.
  final DateTime? expiresAt;

  /// Quick inspections this key pays for. Zero on a plain Pro key.
  final int inspectionCredits;

  /// Seller certificates this key pays for.
  final int certificateCredits;

  /// Free text shown on the licence screen and, for a workshop, on its PDFs.
  final String label;

  bool get neverExpires => expiresAt == null;

  bool isExpiredAt(DateTime now) {
    final e = expiresAt;
    return e != null && !now.isBefore(e);
  }

  Uint8List encode() {
    final labelBytes = utf8.encode(label);
    if (labelBytes.length > maxLabelBytes) {
      throw ArgumentError.value(
        label,
        'label',
        'longer than $maxLabelBytes bytes',
      );
    }
    if (deviceCode.length != deviceCodeLength) {
      throw ArgumentError.value(
        deviceCode,
        'deviceCode',
        'must be $deviceCodeLength bytes',
      );
    }
    _checkU16(inspectionCredits, 'inspectionCredits');
    _checkU16(certificateCredits, 'certificateCredits');

    final out = ByteData(_fixedLength + labelBytes.length);
    out.setUint8(0, version);
    out.setUint8(1, tier.code);
    for (var i = 0; i < deviceCodeLength; i++) {
      out.setUint8(2 + i, deviceCode[i]);
    }
    out.setUint32(10, _seconds(issuedAt), Endian.little);
    out.setUint32(
      14,
      expiresAt == null ? 0 : _seconds(expiresAt!),
      Endian.little,
    );
    out.setUint16(18, inspectionCredits, Endian.little);
    out.setUint16(20, certificateCredits, Endian.little);
    out.setUint8(22, labelBytes.length);
    final bytes = out.buffer.asUint8List();
    bytes.setRange(_fixedLength, bytes.length, labelBytes);
    return bytes;
  }

  /// Throws [LicenseFormatException] on anything that is not a payload this
  /// version of the app understands.
  static LicensePayload decode(List<int> bytes) {
    if (bytes.length < _fixedLength) {
      throw const LicenseFormatException('payload too short');
    }
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    final v = data.getUint8(0);
    if (v != version) {
      throw LicenseFormatException('unsupported payload version $v');
    }
    final tier = LicenseTier.fromCode(data.getUint8(1));
    if (tier == null) {
      throw const LicenseFormatException('unknown tier');
    }
    final labelLength = data.getUint8(22);
    if (bytes.length != _fixedLength + labelLength) {
      throw const LicenseFormatException('label length does not match');
    }
    final expires = data.getUint32(14, Endian.little);
    return LicensePayload(
      tier: tier,
      deviceCode: List<int>.unmodifiable(
        bytes.sublist(2, 2 + deviceCodeLength),
      ),
      issuedAt: _fromSeconds(data.getUint32(10, Endian.little)),
      expiresAt: expires == 0 ? null : _fromSeconds(expires),
      inspectionCredits: data.getUint16(18, Endian.little),
      certificateCredits: data.getUint16(20, Endian.little),
      label: utf8.decode(bytes.sublist(_fixedLength), allowMalformed: true),
    );
  }

  static int _seconds(DateTime t) {
    final s = t.toUtc().millisecondsSinceEpoch ~/ 1000;
    if (s < 0 || s > 0xFFFFFFFF) {
      throw ArgumentError.value(t, 'time', 'outside the uint32 range');
    }
    return s;
  }

  static DateTime _fromSeconds(int s) =>
      DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);

  static void _checkU16(int v, String name) {
    if (v < 0 || v > 0xFFFF) {
      throw ArgumentError.value(v, name, 'must fit in 16 bits');
    }
  }

  Map<String, Object?> toJson() => {
    'tier': tier.name,
    'deviceCode': deviceCode,
    'issuedAt': issuedAt.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'inspectionCredits': inspectionCredits,
    'certificateCredits': certificateCredits,
    'label': label,
  };
}

/// The key text could not be read as a key. Says why, in words the licence
/// screen can show as-is.
class LicenseFormatException implements Exception {
  const LicenseFormatException(this.message);
  final String message;

  @override
  String toString() => 'LicenseFormatException: $message';
}
