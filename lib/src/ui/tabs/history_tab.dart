import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app_settings.dart';
import '../../bms_service.dart';
import '../../data/database.dart';
import '../../data/repository.dart';
import '../../metrics/learning_report.dart';
import '../theme.dart';
import '../widgets/representative_question.dart';
import '../widgets/trip_card.dart';
import '../trends_screen.dart';
import '../trip_screen.dart';
import '../widgets/common.dart';
import '../widgets/learning_why_card.dart';
import '../license_scope.dart';

/// Every ride that has been recorded, newest first.
///
/// This is the tab that only becomes worth anything with time behind it, which
/// is why it was built last: a degradation curve drawn from two days of data
/// would be a drawing, not a measurement.
class HistoryTab extends StatelessWidget {
  const HistoryTab({required this.service, required this.settings, super.key});

  final BmsService service;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final repository = service.repository;

    final device = service.activeDeviceId;
    if (repository == null || device == null) return _empty(t, service);

    return StreamBuilder<List<Trip>>(
      stream: repository.watchTrips(device),
      builder: (context, snapshot) {
        final trips = snapshot.data ?? const <Trip>[];
        if (trips.isEmpty) return _empty(t, service);

        // The free tier keeps a day. The rows are all still stored -- nothing
        // is thrown away, and the estimator still learns from every ride --
        // only the list is cut, and it says how much is behind the cut.
        final window = LicenseScope.entitlements(context).historyWindow;
        final cutoff = window == null
            ? null
            : DateTime.now().toUtc().subtract(window);
        final shown = cutoff == null
            ? trips
            : trips.where((tr) => tr.startedAt.isAfter(cutoff)).toList();
        final hidden = trips.length - shown.length;

        // A trip row exists from the moment recording starts, so the one in
        // progress is here too. It has no distance yet and would skew the
        // averages, so it is left out of the totals.
        final finished = trips.where((tr) => tr.distanceKm > 0).toList();

        final totalKm = finished.fold<double>(0, (a, tr) => a + tr.distanceKm);
        final totalWh = finished.fold<double>(
          0,
          (a, tr) => a + (tr.energyOutWh - tr.energyInWh),
        );

        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 28),
          children: [
            _StartTripButton(service: service, settings: settings),
            // Right under the totals, which is where somebody notices that
            // eight recorded rides have taught the estimate nothing and comes
            // looking for a reason.
            LearningWhyCard(
              report: LearningReport.from(
                trips,
                learnedKm: service.rangeEstimator.learnedKm,
              ),
              t: t,
            ),
            Section(
              title: t.historyTotals,
              children: [
                InfoRow(t.historyTotalTrips, '${finished.length}'),
                InfoRow(
                  t.historyTotalDistance,
                  '${totalKm.toStringAsFixed(1)} km',
                ),
                InfoRow(
                  t.historyTotalEnergy,
                  '${(totalWh / 1000).toStringAsFixed(2)} kWh',
                ),
                InfoRow(
                  t.historyAverage,
                  totalKm < 0.5
                      ? '--'
                      : '${(totalWh / totalKm).toStringAsFixed(1)} Wh/km',
                  dim: totalKm < 0.5,
                  last: true,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TrendsScreen(service: service),
                  ),
                ),
                icon: const Icon(Icons.insights_outlined, size: 19),
                label: Text(t.trendsTitle),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Caption(t.historyTrips),
            ),
            for (final trip in shown)
              TripCard(
                trip: trip,
                service: service,
                repository: repository,
                // Connected, so the figures are the live pack's and the
                // service relearns on every write; nothing to refresh here.
                learned: () => LearnedRange.ofService(service),
                t: t,
              ),
            if (hidden > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: OlderRidesLocked(count: hidden),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Text(
                t.tripSwipeHint,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textFaint,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _empty(AppL10n t, BmsService service) => ListView(
    padding: const EdgeInsets.only(top: 8),
    children: [
      _StartTripButton(service: service, settings: settings),
      const SizedBox(height: 40),
      const Icon(Icons.timeline, size: 40, color: AppTheme.textFaint),
      const SizedBox(height: 18),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            Text(
              t.historyEmpty,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              t.historyEmptyHint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}


/// Starting a ride from the list of rides is where a hand goes looking for it.
class _StartTripButton extends StatefulWidget {
  const _StartTripButton({required this.service, required this.settings});

  final BmsService service;
  final AppSettings settings;

  @override
  State<_StartTripButton> createState() => _StartTripButtonState();
}

class _StartTripButtonState extends State<_StartTripButton> {
  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final active = widget.service.trip.isActive;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: active
          ? OutlinedButton.icon(
              onPressed: _open,
              icon: const Icon(Icons.fiber_manual_record, size: 16),
              label: Text(
                '${t.tripRecording}  ·  '
                '${widget.service.trip.distanceKm.toStringAsFixed(2)} km',
              ),
            )
          : FilledButton.icon(
              onPressed: _open,
              icon: const Icon(Icons.play_arrow, size: 20),
              label: Text(t.tripStartFromHistory),
            ),
    );
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            TripScreen(service: widget.service, settings: widget.settings),
      ),
    );
    if (mounted) setState(() {});
  }
}


/// What the database is costing, and why it is worth it.
class StorageSection extends StatelessWidget {
  const StorageSection({required this.repository, required this.t, super.key});

  final BmsRepository repository;
  final AppL10n t;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StorageStats>(
      future: repository.storageStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data;
        return Section(
          title: t.historyStorage,
          accent: AppTheme.textFaint,
          children: [
            InfoRow(
              t.historyStorageSnapshots,
              stats == null ? '--' : '${stats.snapshots}',
            ),
            InfoRow(
              t.historyStorageFrames,
              stats == null ? '--' : '${stats.rawFrames}',
            ),
            InfoRow(
              t.historyStorageSize,
              stats == null ? '--' : '${stats.megabytes.toStringAsFixed(1)} MB',
              hint: t.historyStorageNote,
              last: true,
            ),
          ],
        );
      },
    );
  }
}
