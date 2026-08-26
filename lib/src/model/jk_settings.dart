/// Decoded settings frame (record type 0x01). Read-only: this app never writes
/// settings back to the BMS.
///
/// Byte layout source: `decode_jk02_settings_()` in
/// https://github.com/syssi/esphome-jk-bms/blob/main/components/jk_bms_ble/jk_bms_ble.cpp
class JkSettings {
  const JkSettings({
    required this.receivedAt,
    required this.smartSleepVoltage,
    required this.cellUvp,
    required this.cellUvpRecovery,
    required this.cellOvp,
    required this.cellOvpRecovery,
    required this.balanceTriggerVoltage,
    required this.soc100Voltage,
    required this.soc0Voltage,
    required this.cellRequestChargeVoltage,
    required this.cellRequestFloatVoltage,
    required this.powerOffVoltage,
    required this.maxChargeCurrent,
    required this.chargeOcpDelaySeconds,
    required this.chargeOcpRecoverySeconds,
    required this.maxDischargeCurrent,
    required this.dischargeOcpDelaySeconds,
    required this.dischargeOcpRecoverySeconds,
    required this.scpRecoverySeconds,
    required this.maxBalanceCurrent,
    required this.chargeOtp,
    required this.chargeOtpRecovery,
    required this.dischargeOtp,
    required this.dischargeOtpRecovery,
    required this.chargeUtp,
    required this.chargeUtpRecovery,
    required this.mosfetOtp,
    required this.mosfetOtpRecovery,
    required this.cellCount,
    required this.chargeSwitchOn,
    required this.dischargeSwitchOn,
    required this.balancerSwitchOn,
    required this.nominalCapacityAh,
    required this.scpDelayMicroseconds,
    required this.balanceStartVoltage,
    required this.connectionWireResistances,
  });

  final DateTime receivedAt;

  final double smartSleepVoltage;
  final double cellUvp;
  final double cellUvpRecovery;
  final double cellOvp;
  final double cellOvpRecovery;
  final double balanceTriggerVoltage;
  final double soc100Voltage;
  final double soc0Voltage;
  final double cellRequestChargeVoltage;
  final double cellRequestFloatVoltage;
  final double powerOffVoltage;

  final double maxChargeCurrent;
  final int chargeOcpDelaySeconds;
  final int chargeOcpRecoverySeconds;
  final double maxDischargeCurrent;
  final int dischargeOcpDelaySeconds;
  final int dischargeOcpRecoverySeconds;
  final int scpRecoverySeconds;
  final double maxBalanceCurrent;

  final double chargeOtp;
  final double chargeOtpRecovery;
  final double dischargeOtp;
  final double dischargeOtpRecovery;
  final double chargeUtp;
  final double chargeUtpRecovery;
  final double mosfetOtp;
  final double mosfetOtpRecovery;

  final int cellCount;
  final bool chargeSwitchOn;
  final bool dischargeSwitchOn;
  final bool balancerSwitchOn;
  final double nominalCapacityAh;
  final int scpDelayMicroseconds;
  final double balanceStartVoltage;

  /// Ohms, one per cell slot in the frame.
  final List<double> connectionWireResistances;

  Map<String, Object?> toJson() => {
        'receivedAt': receivedAt.toIso8601String(),
        'smartSleepVoltage': smartSleepVoltage,
        'cellUvp': cellUvp,
        'cellUvpRecovery': cellUvpRecovery,
        'cellOvp': cellOvp,
        'cellOvpRecovery': cellOvpRecovery,
        'balanceTriggerVoltage': balanceTriggerVoltage,
        'soc100Voltage': soc100Voltage,
        'soc0Voltage': soc0Voltage,
        'cellRequestChargeVoltage': cellRequestChargeVoltage,
        'cellRequestFloatVoltage': cellRequestFloatVoltage,
        'powerOffVoltage': powerOffVoltage,
        'maxChargeCurrent': maxChargeCurrent,
        'chargeOcpDelaySeconds': chargeOcpDelaySeconds,
        'chargeOcpRecoverySeconds': chargeOcpRecoverySeconds,
        'maxDischargeCurrent': maxDischargeCurrent,
        'dischargeOcpDelaySeconds': dischargeOcpDelaySeconds,
        'dischargeOcpRecoverySeconds': dischargeOcpRecoverySeconds,
        'scpRecoverySeconds': scpRecoverySeconds,
        'maxBalanceCurrent': maxBalanceCurrent,
        'chargeOtp': chargeOtp,
        'chargeOtpRecovery': chargeOtpRecovery,
        'dischargeOtp': dischargeOtp,
        'dischargeOtpRecovery': dischargeOtpRecovery,
        'chargeUtp': chargeUtp,
        'chargeUtpRecovery': chargeUtpRecovery,
        'mosfetOtp': mosfetOtp,
        'mosfetOtpRecovery': mosfetOtpRecovery,
        'cellCount': cellCount,
        'chargeSwitchOn': chargeSwitchOn,
        'dischargeSwitchOn': dischargeSwitchOn,
        'balancerSwitchOn': balancerSwitchOn,
        'nominalCapacityAh': nominalCapacityAh,
        'scpDelayMicroseconds': scpDelayMicroseconds,
        'balanceStartVoltage': balanceStartVoltage,
        'connectionWireResistances': connectionWireResistances,
      };
}
