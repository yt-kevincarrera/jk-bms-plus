import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../bms_service.dart';
import '../../data/database.dart';
import '../../pack/chemistry.dart';
import '../../pack/pack_baseline.dart';
import '../theme.dart';

/// What the app asks about a battery, once.
///
/// Four questions, none of them measurements: what it is called, what it was
/// sold as, what the cells are, and when the rider got it. Everything the app
/// later says about wear, safe settings and age is built on these, and none
/// of them can be read off the wire — the BMS knows what it was configured
/// with, not what somebody paid for.
///
/// Offered when a pack is first taken on, and reachable afterwards from the
/// profile card. Every field can be left alone: unknown has to stay a real
/// answer, because a made-up capacity is indistinguishable on screen from a
/// stated one.
class PackProfileSheet extends StatefulWidget {
  const PackProfileSheet({
    required this.service,
    required this.device,
    this.suggestion = ChemistryHint.none,
    this.offerBaseline = true,
    super.key,
  });

  final BmsService service;
  final Device device;

  /// What the pack's own settings suggest the cells are, shown next to the
  /// choice rather than applied silently.
  final ChemistryHint suggestion;

  /// Whether to offer keeping today's reading as the day-one baseline.
  final bool offerBaseline;

  /// Opens the sheet. True when something was saved.
  static Future<bool> show({
    required BuildContext context,
    required BmsService service,
    required Device device,
    ChemistryHint suggestion = ChemistryHint.none,
    bool offerBaseline = true,
  }) async =>
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppTheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => PackProfileSheet(
          service: service,
          device: device,
          suggestion: suggestion,
          offerBaseline: offerBaseline,
        ),
      ) ??
      false;

  @override
  State<PackProfileSheet> createState() => _PackProfileSheetState();
}

class _PackProfileSheetState extends State<PackProfileSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.device.name,
  );
  late final TextEditingController _capacity = TextEditingController(
    text: widget.device.catalogueCapacityAh?.toStringAsFixed(0) ?? '',
  );
  late CellChemistry _chemistry = CellChemistry.byName(widget.device.chemistry);
  late DateTime? _acquired = widget.device.acquiredAt;
  late bool _captureBaseline = widget.offerBaseline;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _capacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final canCapture =
        widget.offerBaseline && widget.service.lastSnapshot != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t.profileTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              t.profileIntro,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 18),

            _label(t.profileName),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: widget.device.id,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            _label(t.profileSoldAs),
            TextField(
              controller: _capacity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                hintText: t.profileSoldAsHint,
                suffixText: 'Ah',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            _label(t.profileChemistry),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (final c in CellChemistry.values)
                  ChoiceChip(
                    label: Text(chemistryLabel(t, c)),
                    selected: _chemistry == c,
                    onSelected: (_) => setState(() => _chemistry = c),
                  ),
              ],
            ),
            if (widget.suggestion.hasSuggestion) ...[
              const SizedBox(height: 8),
              Text(
                _suggestionLine(t),
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: AppTheme.textFaint,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              t.profileChemistryWhy,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: AppTheme.textFaint,
              ),
            ),
            const SizedBox(height: 16),

            _label(t.profileAcquired),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(
                      _acquired == null
                          ? t.profileAcquiredUnknown
                          : _date(_acquired!),
                    ),
                  ),
                ),
                if (_acquired != null)
                  IconButton(
                    onPressed: () => setState(() => _acquired = null),
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: t.profileAcquiredClear,
                  ),
              ],
            ),

            if (canCapture) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _captureBaseline,
                onChanged: (v) => setState(() => _captureBaseline = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: Text(
                  t.profileCaptureBaseline,
                  style: const TextStyle(fontSize: 13.5),
                ),
                subtitle: Text(
                  t.profileCaptureBaselineHint,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: AppTheme.textFaint,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : () => _save(t),
              child: Text(t.profileSave),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t.profileLater),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: AppTheme.caption(context)),
  );

  String _suggestionLine(AppL10n t) {
    final s = widget.suggestion;
    final value = (s.value ?? 0).toStringAsFixed(2);
    return switch (s.evidence) {
      ChemistryEvidence.overvoltageSetting => t.profileChemistryFromOvp(
        chemistryLabel(t, s.chemistry),
        value,
      ),
      ChemistryEvidence.observedCellVoltage => t.profileChemistryFromCell(
        chemistryLabel(t, s.chemistry),
        value,
      ),
      ChemistryEvidence.none => '',
    };
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _acquired ?? now,
      // Nothing lithium on a bike predates this by much, and a date the rider
      // cannot reach is a date they will type wrong somewhere else.
      firstDate: DateTime(2005),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _acquired = picked);
  }

  Future<void> _save(AppL10n t) async {
    final repo = widget.service.repository;
    if (repo == null) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _saving = true);

    final id = widget.device.id;
    final name = _name.text.trim();
    if (name.isNotEmpty && name != widget.device.name) {
      await repo.setDeviceName(id, name);
    }

    final capacity = double.tryParse(
      _capacity.text.trim().replaceAll(',', '.'),
    );
    if (capacity != null && capacity > 0) {
      await repo.setDeviceCatalogue(id, capacity);
    }

    await repo.setPackProfile(
      id,
      chemistry: _chemistry.name,
      acquiredAt: _acquired,
      // A date cleared is a date the rider wants gone, which is different
      // from a date they did not touch.
      clearAcquiredAt: _acquired == null,
    );

    final snapshot = widget.service.lastSnapshot;
    if (_captureBaseline && snapshot != null) {
      await repo.saveBaseline(
        id,
        PackBaseline.capture(
          snapshot: snapshot,
          settings: widget.service.lastSettings,
          info: widget.service.lastDeviceInfo,
        ),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  static String _date(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}

/// The name for a chemistry, in the reader's language.
String chemistryLabel(AppL10n t, CellChemistry c) => switch (c) {
  CellChemistry.lfp => t.chemistryLfp,
  CellChemistry.nmc => t.chemistryNmc,
  CellChemistry.unknown => t.chemistryUnknown,
};
