import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../bms_service.dart';
import '../../data/database.dart';
import '../../pack/chemistry.dart';
import '../../pack/pack_baseline.dart';
import '../../pack/pack_config.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'pack_profile_sheet.dart';

/// What this battery is, and what it looked like on day one.
///
/// Everything here was either stated by the rider or captured once and left
/// alone. It sits apart from the live readings on purpose: those change every
/// second and describe the moment, and these describe the battery.
class PackProfileCard extends StatefulWidget {
  const PackProfileCard({required this.service, super.key});

  final BmsService service;

  @override
  State<PackProfileCard> createState() => _PackProfileCardState();
}

class _PackProfileCardState extends State<PackProfileCard> {
  Device? _device;
  PackBaseline? _baseline;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PackProfileCard old) {
    super.didUpdateWidget(old);
    if (widget.service.activeDeviceId != _device?.id) _load();
  }

  Future<void> _load() async {
    final repo = widget.service.repository;
    final id = widget.service.activeDeviceId;
    if (repo == null || id == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final device = await repo.device(id);
    final baseline = await repo.baseline(id);
    if (!mounted) return;
    setState(() {
      _device = device;
      _baseline = baseline;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final device = _device;
    if (_loading || device == null) return const SizedBox.shrink();

    final chemistry = CellChemistry.byName(device.chemistry);
    final baseline = _baseline;
    final snapshot = widget.service.lastSnapshot;
    final comparison = baseline == null || snapshot == null
        ? null
        : BaselineComparison.compute(
            baseline: baseline,
            now: snapshot,
            settings: widget.service.lastSettings,
          );

    return Section(
      title: t.profileTitle,
      intro: baseline == null ? t.profileNoBaselineIntro : null,
      children: [
        InfoRow(
          t.profileChemistry,
          chemistryLabel(t, chemistry),
          dim: !chemistry.isKnown,
        ),
        InfoRow(
          t.profileSoldAs,
          device.catalogueCapacityAh == null
              ? t.catalogueUnset
              : '${device.catalogueCapacityAh!.toStringAsFixed(0)} Ah',
          dim: device.catalogueCapacityAh == null,
        ),
        InfoRow(
          t.profileAcquired,
          device.acquiredAt == null
              ? t.profileAcquiredUnknown
              : _date(device.acquiredAt!),
          dim: device.acquiredAt == null,
          hint: device.acquiredAt == null
              ? null
              : t.profileAgeYears(_years(device.acquiredAt!)),
        ),
        InfoRow(
          t.profileBaseline,
          baseline == null
              ? t.profileBaselineMissing
              : _date(baseline.capturedAt),
          dim: baseline == null,
          valueColor: baseline == null ? null : AppTheme.good,
          last: comparison == null,
        ),
        if (comparison != null) ..._sinceDayOne(t, comparison),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _edit(device),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(
                  baseline == null && !chemistry.isKnown
                      ? t.profileComplete
                      : t.profileEdit,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  /// The part of the story a stored snapshot can honestly tell.
  ///
  /// No capacity and no wear: those come from a counted discharge. What is
  /// here is how the cells sit relative to each other, how their resistances
  /// have moved, and which settings are not what they were.
  List<Widget> _sinceDayOne(AppL10n t, BaselineComparison c) {
    final worst = c.worstDrift;
    final changed = c.configChanged;
    return [
      const SizedBox(height: 10),
      Caption(
        t.profileSinceDayOne(_date(c.baseline.capturedAt)),
        color: AppTheme.textFaint,
      ),
      const SizedBox(height: 6),
      if (!c.comparable)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            t.profileNotComparable,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: AppTheme.watch,
            ),
          ),
        ),
      InfoRow(
        t.profileDeltaThenNow,
        '${c.thenDeltaVolts.toStringAsFixed(3)} → '
        '${c.nowDeltaVolts.toStringAsFixed(3)} V',
        valueColor: c.deltaChange > 0.010
            ? AppTheme.watch
            : (c.deltaChange < -0.010 ? AppTheme.good : null),
      ),
      if (worst != null)
        InfoRow(
          t.profileWorstDrift,
          t.profileWorstDriftValue(
            '${worst.index}',
            (worst.driftVolts * 1000).toStringAsFixed(0),
          ),
          valueColor: AppTheme.watch,
        ),
      if (c.cyclesSince != null)
        InfoRow(t.profileCyclesSince, '${c.cyclesSince}'),
      InfoRow(
        t.profileConfigChanged,
        changed.isEmpty
            ? t.profileConfigUnchanged
            : t.profileConfigChangedCount('${changed.length}'),
        dim: changed.isEmpty,
        valueColor: changed.isEmpty ? null : AppTheme.watch,
        hint: changed.isEmpty
            ? null
            : changed.map((e) => _changeLine(t, e)).join('\n'),
        last: true,
      ),
    ];
  }

  String _changeLine(AppL10n t, ConfigChange change) =>
      '${configFieldLabel(t, change.field)}: '
      '${formatConfigValue(t, change.field, change.before)} → '
      '${formatConfigValue(t, change.field, change.after)}';

  Future<void> _edit(Device device) async {
    final saved = await PackProfileSheet.show(
      context: context,
      service: widget.service,
      device: device,
      suggestion: ChemistryHint.from(
        cellOvp: widget.service.lastSettings?.cellOvp,
        highestCellVolts: widget.service.lastSnapshot?.maxCellVoltage,
      ),
      offerBaseline: true,
    );
    if (saved) await _load();
  }

  static String _date(DateTime utc) {
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  static String _years(DateTime acquired) {
    final days = DateTime.now().difference(acquired.toLocal()).inDays;
    return (days / 365).toStringAsFixed(1);
  }
}

/// The name of a setting, in the reader's language.
String configFieldLabel(AppL10n t, ConfigField f) => switch (f) {
  ConfigField.cellOvp => t.configCellOvp,
  ConfigField.cellUvp => t.configCellUvp,
  ConfigField.balanceStartVoltage => t.configBalanceStart,
  ConfigField.soc100Voltage => t.configSoc100,
  ConfigField.soc0Voltage => t.configSoc0,
  ConfigField.maxChargeCurrent => t.configMaxCharge,
  ConfigField.maxDischargeCurrent => t.configMaxDischarge,
  ConfigField.maxBalanceCurrent => t.configMaxBalance,
  ConfigField.chargeOtp => t.configChargeOtp,
  ConfigField.dischargeOtp => t.configDischargeOtp,
  ConfigField.chargeUtp => t.configChargeUtp,
  ConfigField.mosfetOtp => t.configMosfetOtp,
  ConfigField.nominalCapacityAh => t.configNominalCapacity,
  ConfigField.cellCount => t.configCellCount,
  ConfigField.chargeSwitchOn => t.configChargeSwitch,
  ConfigField.dischargeSwitchOn => t.configDischargeSwitch,
  ConfigField.balancerSwitchOn => t.configBalancerSwitch,
};

/// A setting's value with its unit, or on and off for a switch.
String formatConfigValue(AppL10n t, ConfigField f, double value) {
  if (f.isSwitch) return value >= 0.5 ? t.configOn : t.configOff;
  final text = value.toStringAsFixed(f.decimals);
  return switch (f.unit) {
    ConfigUnit.volts => '$text V',
    ConfigUnit.amps => '$text A',
    ConfigUnit.celsius => '$text °C',
    ConfigUnit.ampHours => '$text Ah',
    ConfigUnit.count => text,
    ConfigUnit.onOff => text,
  };
}
