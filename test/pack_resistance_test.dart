import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/pack_resistance.dart';

void main() {
  final t0 = DateTime.utc(2026, 9, 1, 8);

  /// A pack at [ocv] volts with [ohms] of resistance, the current swinging
  /// between [lo] and [hi] amps every few readings, at 2.5 readings a second.
  List<(DateTime, double, double)> ride({
    required int seconds,
    double ocv = 78,
    double ohms = 0.022,
    double lo = -4,
    double hi = -28,
    double? sagFromSoc,
  }) {
    final out = <(DateTime, double, double)>[];
    for (var i = 0; i < seconds * 5 ~/ 2; i++) {
      final at = t0.add(Duration(milliseconds: 400 * i));
      final amps = (i ~/ 5).isEven ? lo : hi;
      // The state of charge falling along the ride, as it does.
      final v = ocv - (sagFromSoc ?? 0) * i / (seconds * 2.5) + amps * ohms;
      out.add((at, v, amps));
    }
    return out;
  }

  test('reads the resistance from the swings of the current', () {
    final r = PackResistance.fromReadings(ride(seconds: 600));
    expect(r, closeTo(22, 0.5));
  });

  test('is not the fall in charge over the ride', () {
    // "Worst sag" took the ride's highest voltage minus its lowest over the
    // peak current: six volts of discharge over 28 A came out as 200 mOhm on
    // a pack of 22.
    final readings = ride(seconds: 1200, sagFromSoc: 6);
    expect(PackResistance.fromReadings(readings), closeTo(22, 1.5));
  });

  test('says nothing from a steady ride with no swings', () {
    final readings = ride(seconds: 600, lo: -15, hi: -15);
    expect(PackResistance.fromReadings(readings), isNull);
  });

  test('says nothing from a few swings', () {
    expect(PackResistance.fromReadings(ride(seconds: 60)), isNull);
  });

  test('leaves charging out', () {
    final readings = ride(seconds: 600, lo: 2, hi: 15);
    expect(PackResistance.fromReadings(readings), isNull);
  });

  test('a pause in the readings is not one stretch', () {
    // Readings either side of a dropped link are not the same instant, and a
    // line through them would read the charge used in between.
    final r = PackResistance();
    for (var i = 0; i < 40; i++) {
      r.add(t0.add(Duration(seconds: i * 30)), 78 - i * 0.1, i.isEven ? -4 : -28);
    }
    expect(r.milliohms, isNull);
  });
}
