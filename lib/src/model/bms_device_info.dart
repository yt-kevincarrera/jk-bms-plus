import '../protocol/bms_brand.dart';
import '../protocol/protocol_variant.dart';
import 'jk_device_info.dart';

/// Who the pack says it is, in terms every brand can answer.
///
/// JK says a great deal more (passcodes, power-on count, the variant it
/// implies); that stays reachable through [jk]. ANT says a model and a
/// software string and has no serial number at all, which is written as ''
/// like every other unknown serial in this app.
class BmsDeviceInfo {
  const BmsDeviceInfo({
    required this.brand,
    required this.receivedAt,
    required this.model,
    required this.softwareVersion,
    this.hardwareVersion = '',
    this.serialNumber = '',
    this.jk,
  });

  factory BmsDeviceInfo.fromJk(JkDeviceInfo info) => BmsDeviceInfo(
        brand: BmsBrand.jk,
        receivedAt: info.receivedAt,
        model: info.model,
        softwareVersion: info.softwareVersion,
        hardwareVersion: info.hardwareVersion,
        serialNumber: info.serialNumber,
        jk: info,
      );

  final BmsBrand brand;
  final DateTime receivedAt;
  final String model;
  final String softwareVersion;
  final String hardwareVersion;
  final String serialNumber;
  final JkDeviceInfo? jk;

  JkProtocolVariant? get variant => jk?.variant;

  Map<String, Object?> toJson() => jk?.toJson() ?? {
        'brand': brand.stored,
        'receivedAt': receivedAt.toIso8601String(),
        'model': model,
        'softwareVersion': softwareVersion,
        'hardwareVersion': hardwareVersion,
        'serialNumber': serialNumber,
      };
}
