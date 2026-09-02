import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app_settings.dart';
import '../../bms_service.dart';
import '../../data/database.dart';
import '../../data/repository.dart';
import '../../metrics/learning_report.dart';
import '../theme.dart';
import '../trip_detail_screen.dart';
import '../trends_screen.dart';
import '../trip_screen.dart';
import '../widgets/common.dart';
import '../widgets/learning_why_card.dart';

/// Every ride that has been recorded, newest first.
///
/// This is the tab that only becomes worth anything with time behind it, which
/// is why it was built last: a degradation curve drawn from two days of data
/// would be a drawing, not a measurement.
class HistoryTab extends StatelessWidget {
  const HistoryTab({
    required this.service,
    required this.settings,
    super.key,
  });

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

        // A trip row exists from the moment recording starts, so the one in
        // progress is here too. It has no distance yet and would skew the
        // averages, so it is left out of the totals.
        final finished = trips.where((tr) => tr.distanceKm > 0).toList();

        final totalKm =
            finished.fold<double>(0, (a, tr) => a + tr.distanceKm);
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
                InfoRow(
                  t.historyTotalTrips,
                  '${finished.length}',
                ),
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
            for (final trip in trips)
              _TripCard(
                trip: trip,
                service: service,
                repository: repository,
                t: t,
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.service,
    required this.repository,
    required this.t,
  });

  final Trip trip;
  final BmsService service;
  final BmsRepository repository;
  final AppL10n t;

  @override
  Widget build(BuildContext context) {
    final whPerKm = trip.distanceKm < 0.2
        ? null
        : (trip.energyOutWh - trip.energyInWh) / trip.distanceKm;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Dismissible(
        key: ValueKey(trip.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppTheme.bad.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.delete_outline, color: AppTheme.bad),
        ),
        // Confirm before deleting: a trip carries its whole track, and a swipe
        // is easy to do by accident on a phone in a jacket pocket.
        confirmDismiss: (_) async => _confirmDelete(context),
        onDismissed: (_) async {
          // Goes through the service, not the repository, so the range
          // estimate is rebuilt without this trip rather than quietly keeping
          // what it taught.
          await service.deleteTrip(trip.id);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.historyDeleted)),
          );
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TripDetailScreen(
                trip: trip,
                repository: repository,
              ),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceRaised,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.hairline),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _date(trip.startedAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textFaint,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            trip.distanceKm.toStringAsFixed(1),
                            style: AppTheme.readout(24),
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            'km',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            whPerKm == null
                                ? '--'
                                : whPerKm.toStringAsFixed(0),
                            style: AppTheme.readout(24),
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            'Wh/km',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_duration(trip.movingSeconds)} / '
                        '${_duration(trip.totalSeconds)}  ·  '
                        '${trip.maxSpeedKmh.toStringAsFixed(0)} km/h  ·  '
                        '${(trip.startSoc - trip.endSoc).toStringAsFixed(0)} %'
                        '${trip.climbM >= 5 ? "  ·  +${trip.climbM.toStringAsFixed(0)} m" : ""}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                          fontFeatures: AppTheme.tabular,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppTheme.textFaint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceRaised,
        title: Text(t.tripDeleteConfirmTitle),
        content: Text(
          t.tripDeleteConfirmBody,
          style: const TextStyle(fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.bad),
            child: Text(t.tripDeleteConfirm),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  static String _date(DateTime utc) {
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }

  static String _duration(int seconds) {
    final d = Duration(seconds: seconds);
    // A two-minute ride around the block is still a ride, and "0min" tells you
    // nothing about it.
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '${h}h ${m}min' : '${m}min';
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
              stats == null
                  ? '--'
                  : '${stats.megabytes.toStringAsFixed(1)} MB',
              hint: t.historyStorageNote,
              last: true,
            ),
          ],
        );
      },
    );
  }
}
