import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/grade_profile.dart';

/// Metres per degree of latitude, on the sphere the app measures distance with.
const _metresPerDegree = 6371000 * math.pi / 180;

/// A track running due north, one sample every [stepM], climbing at [grade].
List<GradeSample> leg({
  required double lengthM,
  required double grade,
  double stepM = 40,
  double startAltitude = 100,
  double startLat = 23.14,
}) {
  final out = <GradeSample>[];
  final n = (lengthM / stepM).round();
  for (var i = 0; i <= n; i++) {
    out.add((
      latitude: startLat + (i * stepM) / _metresPerDegree,
      longitude: -82.28,
      altitudeM: startAltitude + i * stepM * grade,
    ));
  }
  return out;
}

/// Joins legs end to end, carrying latitude and altitude across the seam.
List<GradeSample> route(List<({double lengthM, double grade})> legs) {
  final out = <GradeSample>[];
  var lat = 23.14;
  var alt = 100.0;
  for (final l in legs) {
    final part = leg(
      lengthM: l.lengthM,
      grade: l.grade,
      startLat: lat,
      startAltitude: alt,
    );
    out.addAll(out.isEmpty ? part : part.skip(1));
    lat = part.last.latitude;
    alt = part.last.altitudeM;
  }
  return out;
}

void main() {
  group('a route of one kind throughout', () {
    test('flat ground is all flat', () {
      final p = profileOf(route([(lengthM: 4000, grade: 0)]));
      expect(p.flatKm, closeTo(4.0, 0.15));
      expect(p.uphillKm, 0);
      expect(p.downhillKm, 0);
    });

    test('a long climb is all uphill', () {
      // 1 km at 8%, the shape the rider described.
      final p = profileOf(route([(lengthM: 1000, grade: 0.08)]));
      expect(p.uphillKm, closeTo(1.0, 0.15));
      expect(p.downhillKm, 0);
    });

    test('a long descent is all downhill', () {
      final p = profileOf(route([(lengthM: 1000, grade: -0.08)]));
      expect(p.downhillKm, closeTo(1.0, 0.15));
      expect(p.uphillKm, 0);
    });
  });

  group('what counts as a slope', () {
    test('a grade gentler than the threshold is flat', () {
      // One percent over two kilometres is 20 m of climbing, and it is not a
      // hill anybody rides differently.
      final p = profileOf(route([(lengthM: 2000, grade: 0.01)]));
      expect(p.uphillKm, 0);
      expect(p.flatKm, closeTo(2.0, 0.15));
    });

    test('a grade steeper than the threshold is a slope', () {
      final p = profileOf(route([(lengthM: 2000, grade: 0.02)]));
      expect(p.uphillKm, closeTo(2.0, 0.15));
      expect(p.flatKm, 0);
    });
  });

  group('a real shape', () {
    // The rider's commute, as measured: about 13% of it climbing, 13%
    // descending and the rest flat, over 22 km.
    final commute = route([
      (lengthM: 4000, grade: 0.0),
      (lengthM: 1600, grade: 0.02),
      (lengthM: 1600, grade: -0.02),
      (lengthM: 6000, grade: 0.0),
      (lengthM: 1300, grade: 0.02),
      (lengthM: 1300, grade: -0.02),
      (lengthM: 6200, grade: 0.0),
    ]);

    test('splits into the three figures the ride is reported as', () {
      final p = profileOf(commute);
      expect(p.totalKm, closeTo(22.0, 0.3));
      expect(p.uphillKm, closeTo(2.9, 0.4));
      expect(p.downhillKm, closeTo(2.9, 0.4));
      expect(p.flatKm, closeTo(16.2, 0.6));
    });

    test('the three parts add up to the whole ride', () {
      final p = profileOf(commute);
      expect(p.uphillKm + p.flatKm + p.downhillKm, closeTo(p.totalKm, 0.001));
    });

    test('the answer does not depend on the resolution it is measured at', () {
      // The property that makes this trustworthy rather than an artefact. On
      // the rider's real tracks the split held to a percentage point across
      // 50, 100 and 200 m; noise would have blown up as the bins shrank, the
      // way summing every altitude step does.
      final coarse = profileOf(commute, binMetres: 200);
      final medium = profileOf(commute, binMetres: 100);
      final fine = profileOf(commute, binMetres: 50);

      expect(fine.uphillKm, closeTo(medium.uphillKm, 0.5));
      expect(coarse.uphillKm, closeTo(medium.uphillKm, 0.5));
      expect(fine.downhillKm, closeTo(medium.downhillKm, 0.5));
      expect(coarse.downhillKm, closeTo(medium.downhillKm, 0.5));
    });
  });

  group('GPS altitude being what it is', () {
    test('wander on flat ground does not invent hills', () {
      // The mistake the altitude tracker was written to avoid, in a new place.
      // Taking the grade between raw samples 40 m apart would call every
      // wobble a slope; resampling to 100 m bins is what stops it.
      final rnd = math.Random(7);
      final flat = route([(lengthM: 6000, grade: 0)]);
      final noisy = [
        for (final s in flat)
          (
            latitude: s.latitude,
            longitude: s.longitude,
            // Plus or minus a metre and a half, which is what a phone does
            // sitting still, after the recorder's own smoothing.
            altitudeM: s.altitudeM + (rnd.nextDouble() - 0.5) * 3,
          ),
      ];

      final p = profileOf(noisy);

      // Flat still dominates, and what leaks out is symmetric: noise has no
      // preferred direction, so it cannot manufacture a climb. That symmetry
      // is the property worth holding. A plain sum of altitude steps fails it
      // in the other direction -- it inflates climb and descent together and
      // reports hundreds of metres of both.
      expect(p.flatKm, greaterThan(p.totalKm * 0.8));
      expect(p.uphillKm, lessThan(p.totalKm * 0.12));
      expect(p.downhillKm, lessThan(p.totalKm * 0.12));
      expect(p.uphillKm - p.downhillKm, closeTo(0, p.totalKm * 0.05));
    });

    test('the real tracks are cleaner than that', () {
      // Worth writing down, because the tolerance above looks generous. The
      // altitude stored per point is already smoothed by the recorder, and on
      // the rider's seven real tracks the split moved by under a percentage
      // point across 50, 100 and 200 m bins. Half a metre is nearer what the
      // stored signal actually carries, and at that level almost nothing
      // leaks.
      final rnd = math.Random(7);
      final flat = route([(lengthM: 6000, grade: 0)]);
      final noisy = [
        for (final s in flat)
          (
            latitude: s.latitude,
            longitude: s.longitude,
            altitudeM: s.altitudeM + (rnd.nextDouble() - 0.5),
          ),
      ];

      expect(profileOf(noisy).flatKm, closeTo(profileOf(flat).totalKm, 0.2));
    });
  });

  group('tracks with nothing to say', () {
    test('an empty track is an empty profile', () {
      final p = profileOf(const []);
      expect(p.totalKm, 0);
      expect(p.hasAnything, isFalse);
    });

    test('a track shorter than one bin still reports its distance', () {
      // Two samples 40 m apart. The final stretch is whatever is left rather
      // than a whole bin, so the parts still sum to the distance ridden.
      final p = profileOf(route([(lengthM: 80, grade: 0.08)]));
      expect(p.totalKm, closeTo(0.08, 0.01));
      expect(p.uphillKm + p.flatKm + p.downhillKm, closeTo(p.totalKm, 0.001));
    });

    test('a ride too short to bother reporting says so', () {
      // Below this the split is three numbers that round to zero.
      expect(profileOf(route([(lengthM: 80, grade: 0)])).hasAnything, isFalse);
      expect(profileOf(route([(lengthM: 3000, grade: 0)])).hasAnything, isTrue);
    });
  });

  group("a stored track, counted the recorder's way", () {
    final t0 = DateTime.utc(2026, 9, 1, 8);

    /// [route] as fixes four seconds apart at 36 km/h.
    List<GradeFix> fixes(List<GradeSample> samples, {DateTime? from}) => [
      for (var i = 0; i < samples.length; i++)
        (
          latitude: samples[i].latitude,
          longitude: samples[i].longitude,
          altitudeM: samples[i].altitudeM,
          at: (from ?? t0).add(Duration(seconds: 4 * i)),
          speedKmh: 36,
        ),
    ];

    test('standing still adds nothing, so the split matches the distance', () {
      // Two kilometres, then a phone at a red light wandering a few metres
      // between fixes at walking-pace speeds. The recorder ignores the
      // wander; the split used to count it, and added up to more.
      final ride = fixes(route([(lengthM: 2000, grade: 0)]));
      final last = ride.last;
      final jitter = <GradeFix>[
        for (var i = 1; i <= 60; i++)
          (
            latitude: last.latitude + (i.isEven ? 3 : -3) / _metresPerDegree,
            longitude: last.longitude,
            altitudeM: last.altitudeM,
            at: last.at.add(Duration(seconds: 2 * i)),
            speedKmh: 0.8,
          ),
      ];
      final p = profileOfTrack([...ride, ...jitter]);
      expect(p.totalKm, closeTo(2.0, 0.05));
      expect(
        profileOf([
          for (final f in [...ride, ...jitter])
            (
              latitude: f.latitude,
              longitude: f.longitude,
              altitudeM: f.altitudeM,
            ),
        ]).totalKm,
        greaterThan(2.3),
      );
    });

    test('a GPS gap is not drawn as a straight line', () {
      final a = fixes(route([(lengthM: 1000, grade: 0)]));
      final rest = leg(
        lengthM: 1000,
        grade: 0,
        startLat: a.last.latitude + 2000 / _metresPerDegree,
      );
      final b = fixes(rest, from: a.last.at.add(const Duration(minutes: 2)));
      final p = profileOfTrack([...a, ...b]);
      expect(p.totalKm, closeTo(2.0, 0.05));
    });

    test('a single altitude spike does not make a hill', () {
      final ride = fixes(route([(lengthM: 3000, grade: 0)]));
      final spiked = [
        for (var i = 0; i < ride.length; i++)
          i == 30
              ? (
                  latitude: ride[i].latitude,
                  longitude: ride[i].longitude,
                  altitudeM: ride[i].altitudeM + 25,
                  at: ride[i].at,
                  speedKmh: ride[i].speedKmh,
                )
              : ride[i],
      ];
      final p = profileOfTrack(spiked);
      expect(p.flatKm, closeTo(p.totalKm, 0.01));
    });
  });
}
