import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../bms_service.dart';
import '../theme.dart';
import 'common.dart';
import 'trip_learned_section.dart';
import 'trip_summary_view.dart';

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
  backgroundColor: AppTheme.surface,
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
class TripSummarySheet extends StatelessWidget {
  const TripSummarySheet({
    required this.view,
    required this.service,
    required this.t,
    super.key,
  });

  final TripSummaryView view;

  /// Threaded through rather than used here: a screen further along this plan
  /// hands it to the widget that records whether this ride was representative.
  final BmsService service;

  final AppL10n t;

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
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: MetricTile(
                    label: t.tripDistance,
                    value: view.distanceKm.toStringAsFixed(2),
                    unit: 'km',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MetricTile(
                    label: t.tripConsumption,
                    value: view.whPerKm?.toStringAsFixed(0) ?? '--',
                    unit: 'Wh/km',
                  ),
                ),
              ],
            ),
          ),
          Section(
            title: t.tripTitle,
            children: [
              InfoRow(t.tripMoving, _long(view.movingDuration)),
              InfoRow(t.tripElapsed, _long(view.totalDuration)),
              InfoRow(
                t.tripStopped,
                _long(view.totalDuration - view.movingDuration),
              ),
              InfoRow(
                t.tripMaxSpeed,
                '${view.maxSpeedKmh.toStringAsFixed(0)} km/h',
              ),
              InfoRow(
                t.tripAvgSpeed,
                '${view.averageSpeedKmh.toStringAsFixed(0)} km/h',
              ),
              InfoRow(t.tripClimb, '${view.climbM.toStringAsFixed(0)} m'),
              InfoRow(
                t.tripDescent,
                '${view.descentM.toStringAsFixed(0)} m',
                last: true,
              ),
            ],
          ),
          Section(
            title: t.tripPackDuring,
            children: [
              InfoRow(
                t.tripEnergyOut,
                '${view.energyOutWh.toStringAsFixed(1)} Wh',
              ),
              InfoRow(
                t.tripEnergyIn,
                '${view.energyInWh.toStringAsFixed(1)} Wh',
              ),
              InfoRow(
                t.tripSocUsed,
                '${view.socUsed.toStringAsFixed(0)} %',
              ),
              InfoRow(
                t.tripSocPerKm,
                view.socPerKm == null
                    ? '--'
                    : '${view.socPerKm!.toStringAsFixed(2)} %/km',
                dim: view.socPerKm == null,
              ),
              InfoRow(
                t.tripSag,
                '${view.sagVolts.toStringAsFixed(2)} V',
              ),
              InfoRow(
                t.tripMaxCurrent,
                '${view.maxDischargeCurrent.toStringAsFixed(1)} A',
              ),
              InfoRow(
                t.tripMaxTemp,
                '${view.maxTemperature.toStringAsFixed(1)} °C',
              ),
              InfoRow(
                t.tripMaxDelta,
                view.maxDeltaVolts.toStringAsFixed(3),
                last: true,
              ),
            ],
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
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: AppTheme.textFaint,
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

  static String _long(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '$h h $m min';
    // Minutes alone would round a 52 s leg and a 55 s wait both to "1 min",
    // which makes the two lines look like they disagree with each other.
    if (d.inMinutes < 10) return '$m:${s.toString().padLeft(2, '0')}';
    return '$m min';
  }
}
