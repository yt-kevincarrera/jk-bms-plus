import '../model/jk_settings.dart';

/// The settings worth watching, out of everything the BMS will hand over.
///
/// A curated list rather than the whole frame. Two reasons: the audit has an
/// opinion about these and about nothing else, and a stored day-one copy of
/// the entire settings frame would break the first time the protocol layer
/// learned a new field. Values are all doubles, switches included, so the
/// comparison and the storage stay one shape.
enum ConfigField {
  /// Volts per cell at which the BMS cuts the charge.
  cellOvp,

  /// Volts per cell at which it cuts the load.
  cellUvp,

  /// Where balancing starts.
  balanceStartVoltage,

  /// What the BMS calls full and empty, which is what every percentage on
  /// every screen is derived from.
  soc100Voltage,
  soc0Voltage,

  maxChargeCurrent,
  maxDischargeCurrent,
  maxBalanceCurrent,

  /// Temperature cutoffs, in Celsius.
  chargeOtp,
  dischargeOtp,

  /// The one that matters in winter: below this the BMS refuses to charge.
  chargeUtp,
  mosfetOtp,

  /// Amp-hours the BMS is configured to hold. A setting, never a measurement.
  nominalCapacityAh,
  cellCount,

  /// Switches, stored as one and zero.
  chargeSwitchOn,
  dischargeSwitchOn,
  balancerSwitchOn;

  bool get isSwitch =>
      this == ConfigField.chargeSwitchOn ||
      this == ConfigField.dischargeSwitchOn ||
      this == ConfigField.balancerSwitchOn;

  /// How many decimals the figure deserves on screen and on paper.
  int get decimals => switch (this) {
    ConfigField.cellOvp ||
    ConfigField.cellUvp ||
    ConfigField.balanceStartVoltage ||
    ConfigField.soc100Voltage ||
    ConfigField.soc0Voltage => 3,
    ConfigField.maxChargeCurrent ||
    ConfigField.maxDischargeCurrent ||
    ConfigField.maxBalanceCurrent ||
    ConfigField.nominalCapacityAh => 1,
    ConfigField.chargeOtp ||
    ConfigField.dischargeOtp ||
    ConfigField.chargeUtp ||
    ConfigField.mosfetOtp => 1,
    ConfigField.cellCount ||
    ConfigField.chargeSwitchOn ||
    ConfigField.dischargeSwitchOn ||
    ConfigField.balancerSwitchOn => 0,
  };

  /// The unit, for a screen that would otherwise print bare numbers.
  ConfigUnit get unit => switch (this) {
    ConfigField.cellOvp ||
    ConfigField.cellUvp ||
    ConfigField.balanceStartVoltage ||
    ConfigField.soc100Voltage ||
    ConfigField.soc0Voltage => ConfigUnit.volts,
    ConfigField.maxChargeCurrent ||
    ConfigField.maxDischargeCurrent ||
    ConfigField.maxBalanceCurrent => ConfigUnit.amps,
    ConfigField.chargeOtp ||
    ConfigField.dischargeOtp ||
    ConfigField.chargeUtp ||
    ConfigField.mosfetOtp => ConfigUnit.celsius,
    ConfigField.nominalCapacityAh => ConfigUnit.ampHours,
    ConfigField.cellCount => ConfigUnit.count,
    ConfigField.chargeSwitchOn ||
    ConfigField.dischargeSwitchOn ||
    ConfigField.balancerSwitchOn => ConfigUnit.onOff,
  };

  static ConfigField? byName(String name) {
    for (final f in ConfigField.values) {
      if (f.name == name) return f;
    }
    return null;
  }
}

enum ConfigUnit { volts, amps, celsius, ampHours, count, onOff }

/// What the BMS was set to at one moment.
class PackConfig {
  const PackConfig(this.values);

  /// Empty, for a pack whose settings frame has never arrived.
  static const PackConfig none = PackConfig({});

  final Map<ConfigField, double> values;

  bool get isEmpty => values.isEmpty;
  bool get isNotEmpty => values.isNotEmpty;

  double? operator [](ConfigField field) => values[field];

  /// Reads a settings frame into the fields worth keeping.
  static PackConfig from(JkSettings s) => PackConfig({
    ConfigField.cellOvp: s.cellOvp,
    ConfigField.cellUvp: s.cellUvp,
    ConfigField.balanceStartVoltage: s.balanceStartVoltage,
    ConfigField.soc100Voltage: s.soc100Voltage,
    ConfigField.soc0Voltage: s.soc0Voltage,
    ConfigField.maxChargeCurrent: s.maxChargeCurrent,
    ConfigField.maxDischargeCurrent: s.maxDischargeCurrent,
    ConfigField.maxBalanceCurrent: s.maxBalanceCurrent,
    ConfigField.chargeOtp: s.chargeOtp,
    ConfigField.dischargeOtp: s.dischargeOtp,
    ConfigField.chargeUtp: s.chargeUtp,
    ConfigField.mosfetOtp: s.mosfetOtp,
    ConfigField.nominalCapacityAh: s.nominalCapacityAh,
    ConfigField.cellCount: s.cellCount.toDouble(),
    ConfigField.chargeSwitchOn: s.chargeSwitchOn ? 1 : 0,
    ConfigField.dischargeSwitchOn: s.dischargeSwitchOn ? 1 : 0,
    ConfigField.balancerSwitchOn: s.balancerSwitchOn ? 1 : 0,
  });

  Map<String, Object?> toJson() => {
    for (final e in values.entries) e.key.name: e.value,
  };

  static PackConfig fromJson(Map<String, Object?> m) {
    final out = <ConfigField, double>{};
    for (final e in m.entries) {
      final field = ConfigField.byName(e.key);
      final value = e.value;
      if (field != null && value is num) out[field] = value.toDouble();
    }
    return PackConfig(out);
  }
}

/// One setting that is not what it was.
class ConfigChange {
  const ConfigChange({
    required this.field,
    required this.before,
    required this.after,
  });

  final ConfigField field;
  final double before;
  final double after;

  bool get rose => after > before;
}

/// Compares two sets of settings.
///
/// Only fields present on both sides can have changed; a field the older
/// copy never held is not news, it is a field the app learned to read later.
List<ConfigChange> configChanges(PackConfig before, PackConfig after) {
  final out = <ConfigChange>[];
  for (final field in ConfigField.values) {
    final was = before[field];
    final now = after[field];
    if (was == null || now == null) continue;
    // Voltages come off the wire in millivolts and back as doubles, so exact
    // equality would report a change nobody made.
    final epsilon = field.decimals >= 3 ? 0.0005 : 0.05;
    if ((now - was).abs() > epsilon) {
      out.add(ConfigChange(field: field, before: was, after: now));
    }
  }
  return out;
}
