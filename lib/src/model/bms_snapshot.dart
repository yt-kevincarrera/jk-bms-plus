import 'dart:math' as math;

import '../protocol/protocol_variant.dart';
import 'bms_warning.dart';

/// One immutable reading of the pack, decoded from a single cell info frame.
///
/// Everything here is a value the BMS actually reported. Derived quantities
/// (delta, average, power) are computed getters and are deliberately not stored,
/// so there is exactly one place they can be wrong.
class BmsSnapshot {
  const BmsSnapshot({
    required this.timestamp,
    required this.variant,
    required this.frameCounter,
    required this.cellVoltages,
    required this.cellResistances,
    required this.enabledCellMask,
    required this.packVoltage,
    required this.current,
    required this.temperatures,
    required this.temperatureSensorMask,
    required this.mosfetTemp,
    required this.soc,
    required this.soh,
    required this.remainingCapacityAh,
    required this.nominalCapacityAh,
    required this.cycleCount,
    required this.cycleCapacityAh,
    required this.balancingAction,
    required this.balanceCurrent,
    required this.chargeMosfetOn,
    required this.dischargeMosfetOn,
    this.prechargeOn,
    required this.balancerActive,
    required this.heatingOn,
    required this.warnings,
    required this.wireResistanceWarningMask,
    required this.heatingCurrent,
    required this.totalRuntimeSeconds,
    this.batteryTypeCode,
    this.chargeStatusCode,
    this.chargerPlugged,
  });

  /// Phone clock, UTC. Never the BMS clock — it drifts and resets.
  final DateTime timestamp;

  final JkProtocolVariant variant;

  /// Frame counter from the BMS, for detecting dropped frames.
  final int frameCounter;

  /// Volts, one entry per *enabled* cell, in cell order starting at cell 1.
  final List<double> cellVoltages;

  /// Ohms, aligned index-for-index with [cellVoltages]. This is the BMS's own
  /// wire-resistance measurement, not the internal resistance the app derives
  /// from current steps.
  final List<double> cellResistances;

  /// Raw 32-bit "enabled cells" bitmask, kept so a cell count change is visible.
  final int enabledCellMask;

  /// Volts, as measured by the BMS across the whole pack.
  final double packVoltage;

  /// Amps. Sign convention is whatever the BMS reports; see
  /// [isCharging]/[isDischarging]. Verified empirically against the hardware.
  final double current;

  /// Celsius, one entry per probe slot the frame carries for this variant, in
  /// sensor order (index 0 = "Temperature Sensor 1"). Slots the BMS flags as
  /// absent are still included; use [isTemperatureSensorPresent] to filter.
  /// Every temperature the frame carried, including probes that are not
  /// connected. Filter with [connectedTemperatures] before showing them.
  final List<double> temperatures;

  /// The range a probe on a battery can physically be in.
  ///
  /// An unconnected JK probe reads far outside it: real packs report values
  /// like -200 C, which is not cold, it is nothing wired to that input. The
  /// bounds are deliberately generous, so a genuinely frozen or genuinely
  /// overheating pack still reads rather than being hidden as a fault.
  static const double minPlausibleTemp = -40;
  static const double maxPlausibleTemp = 150;

  static bool isPlausibleTemperature(double c) =>
      c >= minPlausibleTemp && c <= maxPlausibleTemp;

  /// The probes that are actually wired up, with their position kept.
  ///
  /// Position matters: probe 3 reading nothing must not make probe 4 look like
  /// probe 3. The index is the sensor number the BMS reported it at.
  List<({int index, double celsius})> get connectedTemperatures => [
        for (var i = 0; i < temperatures.length; i++)
          if (isPlausibleTemperature(temperatures[i]))
            (index: i, celsius: temperatures[i]),
      ];

  /// Just the readings from probes that exist, for anything computing a
  /// maximum, a minimum or an alert. Using the raw list would let a -200 C
  /// non-reading trip a cold-battery warning.
  List<double> get plausibleTemperatures =>
      [for (final c in temperatures) if (isPlausibleTemperature(c)) c];

  /// Probes the frame carried that are not wired to anything.

  List<int> get absentTemperatureProbes => [
        for (var i = 0; i < temperatures.length; i++)
          if (!isPlausibleTemperature(temperatures[i])) i,
      ];

  /// Raw bitmask at byte 182+offset.
  ///
  /// The reference implementation labels this "temperature sensor absent"
  /// (bit 0 MOSFET, bits 1..5 probes 1..5), but the captured JK02_24S frames
  /// report 0x07 while all three of those sensors are returning sane readings
  /// (19.0, 19.1 and 21.0 degC). So either the polarity is inverted or the
  /// label is wrong. Until that is settled against the real pack, this value is
  /// carried through untouched and is NOT used to hide any reading. Do not
  /// filter on it without verifying first.
  final int temperatureSensorMask;

  /// Celsius. Null on variants that do not report it.
  final double? mosfetTemp;

  /// Percent, 0-100, from the BMS coulomb counter.
  final double soc;

  /// Percent, 0-100.
  final double soh;

  final double remainingCapacityAh;
  final double nominalCapacityAh;
  final int cycleCount;
  final double cycleCapacityAh;

  /// 0x00 idle, 0x01 charging balancer, 0x02 discharging balancer.
  final int balancingAction;

  /// Amps flowing through the balancer.
  final double balanceCurrent;

  final bool chargeMosfetOn;
  final bool dischargeMosfetOn;

  /// Null on JK02_24S, where the byte the reference reads for this holds
  /// something that is plainly not a boolean. See the note in JkParser.
  final bool? prechargeOn;

  /// On JK02_32S this is the BMS's own "balancer working" flag. On JK02_24S it
  /// is derived from the balancing-action byte instead.
  final bool balancerActive;

  final bool heatingOn;

  final BmsWarnings warnings;

  /// Raw per-cell wire-resistance warning bitmask (byte 114+offset).
  final int wireResistanceWarningMask;

  /// Amps drawn by the pack heater, where fitted.
  final double heatingCurrent;

  final int totalRuntimeSeconds;

  /// JK02_32S only.
  final int? batteryTypeCode;
  final int? chargeStatusCode;
  final bool? chargerPlugged;

  // --- Derived, never stored ---

  int get cellCount => cellVoltages.length;

  double get minCellVoltage =>
      cellVoltages.isEmpty ? 0 : cellVoltages.reduce(math.min);

  double get maxCellVoltage =>
      cellVoltages.isEmpty ? 0 : cellVoltages.reduce(math.max);

  /// 1-based index of the lowest cell, or 0 when there are no cells.
  int get minCellIndex => _indexOf(minCellVoltage);

  /// 1-based index of the highest cell, or 0 when there are no cells.
  int get maxCellIndex => _indexOf(maxCellVoltage);

  double get deltaCellVoltage => maxCellVoltage - minCellVoltage;

  double get averageCellVoltage => cellVoltages.isEmpty
      ? 0
      : cellVoltages.reduce((a, b) => a + b) / cellVoltages.length;

  /// Watts. Computed from V x I rather than read from the frame, because the
  /// frame's power field is unsigned and therefore loses the charge/discharge
  /// direction.
  ///
  /// Source for that caveat: the "Don't use byte 122 because it's unsigned"
  /// comment in `decode_jk02_cell_info_()` in jk_bms_ble.cpp.
  double get power => packVoltage * current;

  bool get isCharging => current > 0.05;
  bool get isDischarging => current < -0.05;

  /// Which cells the balancer is working on right now. The JK02 frame reports
  /// only that balancing is happening and at what current, not which cell, so
  /// this is inferred: while balancing, the cells at the extreme the balancer
  /// is pulling toward are the ones being worked on.
  ///
  /// Kept separate from the reported fields so it is obvious this is our
  /// inference, not the BMS's claim.
  List<bool> get inferredBalancingCells {
    if (!balancerActive || cellVoltages.isEmpty) {
      return List.filled(cellCount, false);
    }
    // Action 0x01 is the charging balancer, which pushes charge into the cells
    // sitting lowest; 0x02 is the discharging balancer, which pulls it out of
    // the highest. Either way the cells at that end are the ones being worked
    // on. The window is 2 mV so a group of cells tied at the extreme all show,
    // rather than only whichever one rounded lowest this frame.
    final target =
        balancingAction == 0x02 ? maxCellVoltage : minCellVoltage;
    return [for (final v in cellVoltages) (v - target).abs() <= 0.002];
  }

  int _indexOf(double value) {
    for (var i = 0; i < cellVoltages.length; i++) {
      if (cellVoltages[i] == value) return i + 1;
    }
    return 0;
  }

  Map<String, Object?> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'variant': variant.name,
        'frameCounter': frameCounter,
        'cellVoltages': cellVoltages,
        'cellResistances': cellResistances,
        'enabledCellMask':
            '0x${enabledCellMask.toRadixString(16).padLeft(8, '0').toUpperCase()}',
        'cellCount': cellCount,
        'minCellVoltage': minCellVoltage,
        'maxCellVoltage': maxCellVoltage,
        'minCellIndex': minCellIndex,
        'maxCellIndex': maxCellIndex,
        'deltaCellVoltage': deltaCellVoltage,
        'averageCellVoltage': averageCellVoltage,
        'packVoltage': packVoltage,
        'current': current,
        'power': power,
        'temperatures': temperatures,
        'temperatureSensorMask': temperatureSensorMask,
        'mosfetTemp': mosfetTemp,
        'soc': soc,
        'soh': soh,
        'remainingCapacityAh': remainingCapacityAh,
        'nominalCapacityAh': nominalCapacityAh,
        'cycleCount': cycleCount,
        'cycleCapacityAh': cycleCapacityAh,
        'balancingAction': balancingAction,
        'balanceCurrent': balanceCurrent,
        'balancerActive': balancerActive,
        'chargeMosfetOn': chargeMosfetOn,
        'dischargeMosfetOn': dischargeMosfetOn,
        'prechargeOn': prechargeOn,
        'heatingOn': heatingOn,
        'warnings': warnings.toJson(),
        'wireResistanceWarningMask': wireResistanceWarningMask,
        'heatingCurrent': heatingCurrent,
        'totalRuntimeSeconds': totalRuntimeSeconds,
        'batteryTypeCode': batteryTypeCode,
        'chargeStatusCode': chargeStatusCode,
        'chargerPlugged': chargerPlugged,
      };
}
