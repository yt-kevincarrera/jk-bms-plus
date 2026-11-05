import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../bms_service.dart';
import '../../data/database.dart';
import '../theme.dart';
import 'common.dart';
import 'representative_question.dart';
import 'trip_grade_rows.dart';
import 'trip_learned_section.dart';
import 'trip_summary_view.dart';
import 'instruments.dart';
import 'cockpit.dart';
import 'energy_source_label.dart';

/// Opens the end-of-ride summary.
///
/// A function rather than a call site per screen: the sheet is opened from the
/// stop button, and also on opening the app for a ride that ended in a pocket,
/// and those two had no business drifting apart.
Future<void> showTripSummarySheet({
  required BuildContext context,
  required TripSummaryView view,
  required BmsService service,
  required AppL10n t,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: context.colors.surface,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => TripSummarySheet(view: view, service: service, t: t),
);

/// The end-of-ride summary sheet.
///
/// Used to live inside `trip_screen.dart` and take a `TripOutcome`, which only
/// exists in the instant the stop button is pressed. It takes a
/// [TripSummaryView] now so a ride that closed itself in a pocket gets the
/// same sheet, not a lesser one built by hand from a stored row.
class TripSummarySheet extends StatefulWidget {
  const TripSummarySheet({
    required this.view,
    required this.service,
    required this.t,
    super.key,
  });

  final TripSummaryView view;

  /// Handed to [RepresentativeQuestion], the only thing on this sheet that
  /// asks the rider for something.
  final BmsService service;

  final AppL10n t;

  @override
  State<TripSummarySheet> createState() => _TripSummarySheetState();
}

class _TripSummarySheetState extends State<TripSummarySheet> {
  TripSummaryView get view => widget.view;
  BmsService get service => widget.service;
  AppL10n get t => widget.t;

  /// Read once. A future built inside `build` would start a fresh query on
  /// every rebuild and blank the figures each time.
  late final Future<List<TripPoint>>? _points = view.tripId == null
      ? null
      : service.repository?.pointsFor(view.tripId!);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              t.tripSummaryTitle,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
            ),
          ),
          TripInstruments(
            distanceLabel: t.tripDistance,
            distance: view.distanceKm.toStringAsFixed(2),
            consumptionLabel: t.tripConsumption,
            consumption: view.whPerKm?.toStringAsFixed(0) ?? '--',
          ),
          // finishTrip writes the track before opening this summary.
          Section(
            title: t.tripTerrain,
            children: [TripGradeRows(points: _points, t: t, asTiles: true)],
          ),
          Section(
            title: t.tripTitle,
            children: [
              TelemetryStrip(
                padding: const EdgeInsets.only(top: 12),
                size: 28,
                items: [
                  TelemetryDatum(t.tripMoving, _long(view.movingDuration)),
                  TelemetryDatum(t.tripElapsed, _long(view.totalDuration)),
                  TelemetryDatum(t.tripStopped, _long(view.stoppedDuration)),
                ],
              ),
              TelemetryStrip(
                padding: const EdgeInsets.only(top: 14),
                size: 30,
                items: [
                  TelemetryDatum(
                    t.tripMaxSpeed,
                    view.maxSpeedKmh.toStringAsFixed(0),
                    unit: 'km/h',
                  ),
                  TelemetryDatum(
                    t.tripAvgSpeed,
                    view.averageSpeedKmh.toStringAsFixed(0),
                    unit: 'km/h',
                  ),
                ],
              ),
            ],
          ),
          Section(
            title: t.tripPackDuring,
            children: [
              ChargeJourney(
                startLabel: t.tripChargeStart,
                endLabel: t.tripChargeEnd,
                start: view.startSoc.toStringAsFixed(0),
                end: view.endSoc.toStringAsFixed(0),
              ),
              InfoRow(
                t.tripEnergyOut,
                view.energyMeasured
                    ? '${view.energyOutWh.toStringAsFixed(1)} Wh'
                    : t.tripNotMeasured,
                dim: !view.energyMeasured,
                hint: view.energyMeasured ? null : t.tripEnergyUnmeasuredWhy,
              ),
              if (energySourceLabel(t, view.energySource) case final source?)
                InfoRow(t.tripEnergySourceLabel, source),
              InfoRow(
                t.tripEnergyIn,
                view.energyMeasured
                    ? '${view.energyInWh.toStringAsFixed(1)} Wh'
                    : t.tripNotMeasured,
              ),
              InfoRow(
                t.tripEnergyNet,
                view.energyMeasured
                    ? '${(view.energyOutWh - view.energyInWh).toStringAsFixed(1)} Wh'
                    : t.tripNotMeasured,
              ),
              InfoRow(
                t.tripPackVoltage,
                '${_voltage(view.minPackVoltage)} / ${_voltage(view.maxPackVoltage)} V',
              ),
              InfoRow(t.tripSocUsed, '${view.socUsed.toStringAsFixed(0)} %'),
              InfoRow(
                t.tripSocPerKm,
                view.socPerKm == null
                    ? '--'
                    : '${view.socPerKm!.toStringAsFixed(2)} %/km',
                dim: view.socPerKm == null,
              ),
              if (view.packResistanceMilliohms case final r?)
                InfoRow(
                  t.tripResistance,
                  '${r.toStringAsFixed(0)} mΩ',
                  hint: t.tripResistanceHint,
                ),
              InfoRow(
                t.tripMaxCurrent,
                '${view.maxDischargeCurrent.toStringAsFixed(1)} A',
              ),
              // Empty when the pack has no battery probe, not 0 degC.
              InfoRow(
                t.tripMaxTemp,
                view.maxTemperature == null
                    ? '--'
                    : '${view.maxTemperature!.toStringAsFixed(1)} °C',
                dim: view.maxTemperature == null,
              ),
              InfoRow(
                t.tripMaxDelta,
                '${view.maxDeltaVolts.toStringAsFixed(3)} V',
                last: true,
              ),
            ],
          ),
          RepresentativeQuestion(
            view: view,
            service: service,
            learned: () => LearnedRange.ofService(service),
            t: t,
          ),
          TripLearnedSection(
            conclusions: view.conclusions,
            whPerKm: view.whPerKm,
            socUsed: view.socUsed,
            distanceKm: view.distanceKm,
            maxTemperature: view.maxTemperature,
            maxDeltaVolts: view.maxDeltaVolts,
            t: t,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              t.tripNotSaved,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: context.colors.textFaint,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.tripClose),
            ),
          ),
        ],
      ),
    );
  }

  static String _voltage(double value) =>
      value.isFinite && value > 0 ? value.toStringAsFixed(1) : '--';

  static String _long(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '$h h $m min $s s';
    // Minutes alone would round a 52 s leg and a 55 s wait both to "1 min",
    // which makes the two lines look like they disagree with each other.
    if (d.inMinutes < 10) return '$m:${s.toString().padLeft(2, '0')}';
    return '$m min $s s';
  }
}
