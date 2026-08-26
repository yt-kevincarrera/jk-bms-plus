/// The three mutually incompatible framings the JK BLE protocol has shipped in.
///
/// Picking the wrong one does not fail loudly — it decodes at the wrong byte
/// offsets and produces plausible-looking garbage. Detection lives in
/// [JkProtocolVariantDetector] and is deliberately conservative.
enum JkProtocolVariant {
  /// Old balancer family (JK-B2A16S v3, JK-B5A24S). Cell voltages are IEEE
  /// floats, not fixed point. Not supported by this app.
  jk04,

  /// Firmware major version < 11. Cell block is 24 cells wide.
  jk02_24s,

  /// Firmware major version >= 11. Cell block is 32 cells wide, which shifts
  /// every field after it by a fixed amount.
  jk02_32s;

  /// Byte shift applied to the fields that follow the per-cell voltage block.
  ///
  /// Source: `decode_jk02_cell_info_()` in jk_bms_ble.cpp — `offset = 16` for
  /// JK02_32S (8 extra cells x 2 bytes), later doubled to 32 once past the
  /// per-cell resistance block.
  int get cellBlockOffset => this == JkProtocolVariant.jk02_32s ? 16 : 0;

  /// Number of cell slots present in the frame, enabled or not.
  int get cellSlots => this == JkProtocolVariant.jk02_32s ? 32 : 24;

  bool get isJk02 =>
      this == JkProtocolVariant.jk02_24s || this == JkProtocolVariant.jk02_32s;
}

/// Why the detector concluded what it did.
///
/// A code rather than a sentence, so the UI can say it in the reader's own
/// language instead of hard-coding English into a protocol class.
enum VariantReason {
  /// No major version could be read out of the version string.
  unreadableVersion,

  /// Major version 11 or above, which is unambiguously JK02_32S.
  modernFirmware,

  /// Major version below 11. Implies JK02_24S, but overlaps with JK04.
  legacyFirmware,
}

/// Result of trying to work out which variant a device speaks.
class VariantDetection {
  const VariantDetection({
    required this.variant,
    required this.confident,
    required this.reason,
    required this.model,
    required this.softwareVersion,
    this.majorVersion,
  });

  final JkProtocolVariant? variant;

  /// False when the software version was ambiguous and the caller should let
  /// the user confirm or override before trusting parsed values.
  final bool confident;

  final VariantReason reason;
  final String model;
  final String softwareVersion;
  final int? majorVersion;
}

/// Derives the protocol variant from the software version reported in the
/// device info frame.
///
/// The rule comes from the compatibility table in
/// https://github.com/syssi/esphome-jk-bms/blob/main/README.md — every listed
/// device with a software major version of 11 or above uses JK02_32S, and every
/// device below 11 uses JK02_24S, with no counterexamples in either direction.
///
/// Software versions below 11 are ambiguous with the JK04 balancer family
/// (JK-B2A16S sw 3.3.0, JK-B5A24S sw 8.0.3M), so those are reported as
/// non-confident rather than silently assumed.
class JkProtocolVariantDetector {
  static VariantDetection detect({
    required String model,
    required String softwareVersion,
  }) {
    final major = _majorVersion(softwareVersion);
    if (major == null) {
      return VariantDetection(
        variant: null,
        confident: false,
        reason: VariantReason.unreadableVersion,
        model: model,
        softwareVersion: softwareVersion,
      );
    }

    if (major >= 11) {
      return VariantDetection(
        variant: JkProtocolVariant.jk02_32s,
        confident: true,
        reason: VariantReason.modernFirmware,
        model: model,
        softwareVersion: softwareVersion,
        majorVersion: major,
      );
    }

    // Known JK04 devices are all below major 11 too, so this branch is a guess
    // that happens to be right for every JK02 device in the compatibility list.
    return VariantDetection(
      variant: JkProtocolVariant.jk02_24s,
      confident: false,
      reason: VariantReason.legacyFirmware,
      model: model,
      softwareVersion: softwareVersion,
      majorVersion: major,
    );
  }

  static int? _majorVersion(String version) {
    final match = RegExp(r'^\s*(\d+)').firstMatch(version);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }
}
