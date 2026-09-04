import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../bms_service.dart';
import '../../pack/chemistry.dart';
import '../../pack/config_audit.dart';
import '../../pack/pack_baseline.dart';
import '../../pack/pack_config.dart';
import '../theme.dart';
import '../widgets/advice_list.dart';
import '../widgets/common.dart';
import 'pack_profile_card.dart';
import 'pack_profile_sheet.dart';

/// What the BMS is configured to do, read against what the cells can take.
///
/// Read only, and it says so twice: once at the top of the list of findings
/// and once at the bottom under the settings themselves. This app has never
/// written a byte to a BMS and this screen is not where that changes — a
/// wrong value written to a battery management system is a fire, and the
/// protocol's write path is reverse-engineered rather than documented.
class ConfigAuditScreen extends StatefulWidget {
  const ConfigAuditScreen({required this.service, super.key});

  final BmsService service;

  @override
  State<ConfigAuditScreen> createState() => _ConfigAuditScreenState();
}

class _ConfigAuditScreenState extends State<ConfigAuditScreen> {
  CellChemistry _chemistry = CellChemistry.unknown;
  double? _soldAsAh;
  PackBaseline? _baseline;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
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
      _chemistry = CellChemistry.byName(device?.chemistry);
      _soldAsAh = device?.catalogueCapacityAh;
      _baseline = baseline;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final settings = widget.service.lastSettings;

    return Scaffold(
      appBar: AppBar(title: Text(t.configAuditTitle)),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.goodDim,
                  ),
                ),
              )
            : settings == null
            ? _waiting(t)
            : _body(t, PackConfig.from(settings)),
      ),
    );
  }

  Widget _waiting(AppL10n t) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        t.configAuditNoSettings,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13.5,
          height: 1.5,
          color: AppTheme.textSecondary,
        ),
      ),
    ),
  );

  Widget _body(AppL10n t, PackConfig config) {
    final findings = const ConfigAudit().evaluate(
      config: config,
      chemistry: _chemistry,
      soldAsAh: _soldAsAh,
      cellsSeen: widget.service.lastSnapshot?.cellCount,
      dayOne: _baseline?.config,
    );

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 28),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Text(
            t.configAuditIntro,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        AdviceList(
          advice: findings,
          title: t.configAuditTitle,
          showHonestyNote: false,
        ),
        // The chemistry drives every voltage check, so it is stated here
        // rather than left to be remembered from another screen, with the way
        // to change it one tap away.
        Section(
          title: t.configAuditSettings,
          children: [
            InfoRow(
              t.configAuditChemistryRow,
              chemistryLabel(t, _chemistry),
              dim: !_chemistry.isKnown,
            ),
            for (final field in ConfigField.values)
              if (config[field] != null)
                InfoRow(
                  configFieldLabel(t, field),
                  formatConfigValue(t, field, config[field]!),
                  last: field == ConfigField.values.last,
                ),
            if (!_chemistry.isKnown) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _completeProfile,
                icon: const Icon(Icons.tune, size: 18),
                label: Text(t.configAuditNeedsProfile),
              ),
            ],
            const SizedBox(height: 4),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Text(
            t.configAuditReadOnly,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: AppTheme.textFaint,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _completeProfile() async {
    final repo = widget.service.repository;
    final id = widget.service.activeDeviceId;
    if (repo == null || id == null) return;
    final device = await repo.device(id);
    if (device == null || !mounted) return;

    final saved = await PackProfileSheet.show(
      context: context,
      service: widget.service,
      device: device,
      suggestion: ChemistryHint.from(
        cellOvp: widget.service.lastSettings?.cellOvp,
        highestCellVolts: widget.service.lastSnapshot?.maxCellVoltage,
      ),
    );
    if (saved) await _load();
  }
}
