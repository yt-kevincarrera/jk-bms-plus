import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations_es.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/metrics/charge_alerts.dart';
import 'package:jk_bms/src/metrics/ride_alerts.dart';
import 'package:jk_bms/src/ui/app_settings_screen.dart';

void main() {
  final t = AppL10nEs();

  group('the alert switches, gathered by subject', () {
    // Twelve switches in one flat column read as twelve unrelated things, and
    // several read as the same thing said twice: cells apart while riding next
    // to cells apart at the top of a charge. The grouping says the repeated
    // half once, at the top.

    test('every alert the app can raise still has a switch', () {
      // The risk of grouping by hand: an alert left out of every group has no
      // switch, so it can never be turned off and nothing says why. Silent,
      // and only findable by a rider who cannot make it stop.
      final covered = {
        for (final group in alertGroups(t))
          for (final item in group.items) item.name,
      };

      final expected = {
        ...RideAlert.values.map((a) => a.name),
        ...ChargeAlert.values.map((a) => a.name),
        BmsService.linkLostAlertKey,
      };

      expect(covered, expected);
    });

    test('and none appears twice', () {
      // Two switches writing the same stored key would disagree on screen:
      // turning one off would leave the other reading on.
      final names = [
        for (final group in alertGroups(t))
          for (final item in group.items) item.name,
      ];
      expect(names.length, names.toSet().length);
    });

    test('the subjects that repeat are the ones that share a heading', () {
      // The specific complaint. Cells apart and heat each appeared twice in
      // the flat list, once for riding and once for charging, and read as
      // duplicates. They are one subject in two situations.
      final groups = {
        for (final group in alertGroups(t))
          group.heading: group.items.map((i) => i.name).toList(),
      };

      expect(groups[t.alertGroupSpread], [
        RideAlert.cellSpread.name,
        ChargeAlert.spreadAtTop.name,
      ]);
      expect(groups[t.alertGroupHeat], [
        RideAlert.temperature.name,
        ChargeAlert.hotWhileCharging.name,
      ]);
    });

    test('no group is empty, and no heading is blank', () {
      for (final group in alertGroups(t)) {
        expect(group.items, isNotEmpty, reason: group.heading);
        expect(group.heading.trim(), isNotEmpty);
      }
    });

    test('every label says something', () {
      // A row whose label is the empty string is a switch nobody can identify.
      for (final group in alertGroups(t)) {
        for (final item in group.items) {
          expect(item.label.trim(), isNotEmpty, reason: item.name);
        }
      }
    });

    test('it stays short enough to read at a glance', () {
      // The point was to stop the column being a wall. If a later change grows
      // this back past a handful of headings, that is worth noticing.
      expect(alertGroups(t).length, lessThanOrEqualTo(6));
    });
  });
}
