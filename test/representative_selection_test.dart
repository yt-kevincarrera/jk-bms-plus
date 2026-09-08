import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations_es.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/metrics/trip_recorder.dart';
import 'package:jk_bms/src/ui/widgets/representative_question.dart';
import 'package:jk_bms/src/ui/widgets/trip_summary_view.dart';

import 'fixtures/captured_frames.dart';
import 'support/fakes.dart';

/// The chips have to change under the finger that taps them.
///
/// They did not. The control was rebuilt from the row it was handed, the tap
/// wrote to the database, and nothing re-read the row -- so the selection kept
/// showing the previous answer until the screen was left and opened again.
/// The rider reported it as "you have to leave and come back to notice it
/// changed", which is the second time this control has failed by not showing
/// its own state.
void main() {
  late AppDatabase db;
  late BmsRepository repo;
  late BmsService service;
  late int tripId;

  final t = AppL10nEs();

  setUp(() async {
    final link = FakeLink();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BmsRepository(database: db);
    service = BmsService(transport: link, locationFactory: StubLocation.new)
      ..repository = repo;
    await service.connect('AA:BB', name: 'KevinJK');
    await link.deliver(deviceInfoFrames[1]);
    await link.deliver(cellInfo24s[0]);

    tripId = await db.insertTrip(
      TripsCompanion.insert(
        deviceId: Value(service.activeDeviceId!),
        startedAt: DateTime.utc(2026, 9, 8, 8, 30),
        endedAt: DateTime.utc(2026, 9, 8, 9, 18),
        distanceKm: 22,
        movingSeconds: 2600,
        totalSeconds: 2880,
        maxSpeedKmh: 55,
        energyOutWh: 22 * 17.5,
        energyInWh: 0,
        startSoc: 98,
        endSoc: 70,
        minPackVoltage: 70,
        maxPackVoltage: 80,
        maxDischargeCurrent: 20,
        maxTemperature: 30,
        maxDeltaVolts: 0.02,
        climbM: 40,
        descentM: 40,
        ahOut: const Value(5.06),
        energySource: Value(EnergySource.coulombCount.name),
      ),
    );
  });

  tearDown(() async {
    service.dispose();
    // The repository owns a five second flush timer. Left running it fires
    // after the database below is closed, and the write lands as an
    // unhandled async error attributed to whichever test happens to be
    // running by then. That is how this file started failing only inside a
    // full-suite run, and only once the suite grew long enough to reach the
    // first tick.
    await repo.dispose();
    await db.close();
  });

  /// The control on its own, handed a row exactly as a screen would hand it.
  /// Nothing here rebuilds it from the outside, which is the point: the tap
  /// alone has to be enough.
  Future<void> pump(WidgetTester tester, {bool? answered}) async {
    final trip = (await db.tripById(tripId))!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RepresentativeQuestion(
              view: TripSummaryView.fromStored(
                trip.copyWith(representative: Value(answered)),
              ),
              service: service,
              learned: () => const LearnedRange(whPerKm: 17.5, fullKm: 40),
              t: t,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool selected(WidgetTester tester, String label) {
    final chip = tester.widget<ChoiceChip>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(ChoiceChip),
      ),
    );
    return chip.selected;
  }

  testWidgets('tapping the other answer moves the selection at once',
      (tester) async {
    await pump(tester, answered: false);
    expect(selected(tester, t.representativeNo), isTrue);
    expect(selected(tester, t.representativeYes), isFalse);

    await tester.tap(find.text(t.representativeYes));
    await tester.pumpAndSettle();

    // No reload, no re-entry, no rebuild from the parent.
    expect(selected(tester, t.representativeYes), isTrue);
    expect(selected(tester, t.representativeNo), isFalse);
  });

  testWidgets('and back again, as many times as tapped', (tester) async {
    await pump(tester, answered: false);

    await tester.tap(find.text(t.representativeYes));
    await tester.pumpAndSettle();
    expect(selected(tester, t.representativeYes), isTrue);

    await tester.tap(find.text(t.representativeNo));
    await tester.pumpAndSettle();
    expect(selected(tester, t.representativeNo), isTrue);
    expect(selected(tester, t.representativeYes), isFalse);
  });

  testWidgets('an unanswered ride shows neither until one is tapped',
      (tester) async {
    await pump(tester);
    expect(selected(tester, t.representativeYes), isFalse);
    expect(selected(tester, t.representativeNo), isFalse);

    await tester.tap(find.text(t.representativeNo));
    await tester.pumpAndSettle();
    expect(selected(tester, t.representativeNo), isTrue);
  });

  testWidgets('what it shows is what it wrote', (tester) async {
    // The selection is drawn ahead of the write landing, so it has to be
    // checked against the row rather than trusted.
    await pump(tester, answered: false);

    await tester.tap(find.text(t.representativeYes));
    await tester.pumpAndSettle();

    expect((await db.tripById(tripId))!.representative, isTrue);
  });
}
