import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations.dart';
import 'package:jk_bms/src/protocol/ant_constants.dart';

void main() {
  // Why this exists. The ANT state texts live twice: in English tables that
  // the logs and the console use, and in the .arb files the System tab reads.
  // If the two drift, the rider and the log describe the same code
  // differently, so the English translation is pinned to the tables.
  final en = lookupAppL10n(const Locale('en'));
  final es = lookupAppL10n(const Locale('es'));

  final tables = <String, (List<String>, String Function(AppL10n, String))>{
    'battery state': (antBatteryStateText, (t, c) => t.antBatteryStateCode(c)),
    'charge MOSFET': (antChargeMosfetText, (t, c) => t.antChargeMosfetCode(c)),
    'discharge MOSFET': (
      antDischargeMosfetText,
      (t, c) => t.antDischargeMosfetCode(c),
    ),
    'balancer': (antBalancerText, (t, c) => t.antBalancerCode(c)),
  };

  for (final MapEntry(key: name, value: (table, text)) in tables.entries) {
    test('the English $name texts match the table code for code', () {
      for (var code = 0; code < table.length; code++) {
        expect(text(en, '$code'), table[code], reason: 'code $code');
      }
    });

    test('every $name code has Spanish text', () {
      for (var code = 0; code < table.length; code++) {
        expect(text(es, '$code'), isNotEmpty, reason: 'code $code');
      }
    });
  }

  test('a code past the end of a table is shown with its value', () {
    expect(es.antUnknownCode('2a'), 'Desconocido (0x2a)');
    expect(en.antUnknownCode('2a'), 'Unknown (0x2a)');
    expect(es.antChargeMosfetCode('2'), 'Protección por sobrecarga');
  });
}
