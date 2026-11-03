import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../bms_service.dart';
import '../../model/bms_snapshot.dart';
import 'cells_tab.dart';
import 'thermal_tab.dart';

/// Two views of one battery, with independent scroll positions kept alive.
class BatteryTab extends StatefulWidget {
  const BatteryTab({required this.service, required this.snapshot, super.key});
  final BmsService service;
  final BmsSnapshot? snapshot;
  @override
  State<BatteryTab> createState() => _BatteryTabState();
}

class _BatteryTabState extends State<BatteryTab> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(t.tabCells),
                avatar: const Icon(Icons.grid_view_outlined, size: 18),
                selected: _index == 0,
                onSelected: (_) => setState(() => _index = 0),
              ),
              ChoiceChip(
                label: Text(t.tabThermal),
                avatar: const Icon(Icons.thermostat_outlined, size: 18),
                selected: _index == 1,
                onSelected: (_) => setState(() => _index = 1),
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _index,
            children: [
              CellsTab(service: widget.service, snapshot: widget.snapshot),
              ThermalTab(service: widget.service, snapshot: widget.snapshot),
            ],
          ),
        ),
      ],
    );
  }
}
