import '../../l10n/app_localizations.dart';
import '../model/bms_warning.dart';

/// The rider-facing name of a BMS fault.
///
/// The names in `jk02ErrorBitNames` are the reference implementation's, in
/// English, and they stay that way: they are protocol documentation, and the
/// raw JSON in an export should match what someone reading the reference would
/// expect. What gets shown on screen is this instead.
///
/// A bit with no translation falls back to the protocol name rather than to
/// nothing — an untranslated fault is still a fault worth seeing.
String warningLabel(AppL10n t, BmsWarning w) => switch (w) {
      BmsWarning.wireResistance => t.warnWireResistance,
      BmsWarning.mosfetOvertemperature => t.warnMosfetOvertemp,
      BmsWarning.cellCountMismatch => t.warnCellCountMismatch,
      BmsWarning.batteryFullyCharged => t.warnFullyCharged,
      BmsWarning.packOvervoltage => t.warnPackOvervoltage,
      BmsWarning.chargeOvercurrent => t.warnChargeOvercurrent,
      BmsWarning.chargeShortCircuit => t.warnChargeShortCircuit,
      BmsWarning.chargeOvertemperature => t.warnChargeOvertemp,
      BmsWarning.chargeUndertemperature => t.warnChargeUndertemp,
      BmsWarning.coprocessorCommunicationError => t.warnCoprocessor,
      BmsWarning.cellUndervoltage => t.warnCellUndervoltage,
      BmsWarning.packUndervoltage => t.warnPackUndervoltage,
      BmsWarning.dischargeOvercurrent => t.warnDischargeOvercurrent,
      BmsWarning.dischargeShortCircuit => t.warnDischargeShortCircuit,
      BmsWarning.dischargeOvertemperature => t.warnDischargeOvertemp,
      BmsWarning.chargingMosfetAbnormal => t.warnChargeMosfet,
      BmsWarning.dischargingMosfetAbnormal => t.warnDischargeMosfet,
      BmsWarning.gpsDisconnected => t.warnGpsDisconnected,
      BmsWarning.modifyPasswordInTime => t.warnChangePassword,
      BmsWarning.dischargeOnFailed => t.warnDischargeOnFailed,
      BmsWarning.batteryOvertemperature => t.warnPackOvertemp,
      BmsWarning.temperatureSensorAnomaly => t.warnTempSensor,
      BmsWarning.plModuleAnomaly => t.warnPlModule,
      BmsWarning.scpReleaseFailed => t.warnScpRelease,
      BmsWarning.dischargeOcpII => t.warnDischargeOcp2,
      BmsWarning.dischargeOcpIII => t.warnDischargeOcp3,
      BmsWarning.dischargeUndertemperatureAlarm => t.warnDischargeUndertemp,
      BmsWarning.gpsRemoteLock => t.warnGpsRemoteLock,
    };
