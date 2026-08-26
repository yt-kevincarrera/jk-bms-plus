import '../protocol/protocol_variant.dart';

/// Decoded device info frame (record type 0x03).
///
/// Byte layout source: `decode_device_info_()` in
/// https://github.com/syssi/esphome-jk-bms/blob/main/components/jk_bms_ble/jk_bms_ble.cpp
class JkDeviceInfo {
  const JkDeviceInfo({
    required this.receivedAt,
    required this.model,
    required this.hardwareVersion,
    required this.softwareVersion,
    required this.uptimeSeconds,
    required this.powerOnCount,
    required this.deviceName,
    required this.manufacturingDate,
    required this.serialNumber,
    required this.devicePasscode,
    required this.setupPasscode,
    required this.detection,
  });

  final DateTime receivedAt;
  final String model;
  final String hardwareVersion;
  final String softwareVersion;
  final int uptimeSeconds;
  final int powerOnCount;
  final String deviceName;

  /// "YYYYMMDD"-ish string, empty when the device does not report one.
  final String manufacturingDate;
  final String serialNumber;

  /// The BMS hands its own passcode to any client that reads a device info
  /// frame, in clear text. No authentication is involved anywhere in this
  /// protocol: reading needs no password at all.
  final String devicePasscode;

  /// Same, for the settings passcode.
  final String setupPasscode;

  /// What variant we concluded from [softwareVersion], and how sure we are.
  final VariantDetection detection;

  JkProtocolVariant? get variant => detection.variant;

  Map<String, Object?> toJson() => {
        'receivedAt': receivedAt.toIso8601String(),
        'model': model,
        'hardwareVersion': hardwareVersion,
        'softwareVersion': softwareVersion,
        'uptimeSeconds': uptimeSeconds,
        'powerOnCount': powerOnCount,
        'deviceName': deviceName,
        'manufacturingDate': manufacturingDate,
        'serialNumber': serialNumber,
        'devicePasscode': devicePasscode,
        'setupPasscode': setupPasscode,
        'variant': variant?.name,
        'variantConfident': detection.confident,
        'variantReason': detection.reason,
      };
}
