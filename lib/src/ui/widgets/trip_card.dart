import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../bms_service.dart';
import '../../data/database.dart';
import '../../data/repository.dart';
import '../theme.dart';
import '../trip_detail_screen.dart';
import 'pro_gate.dart';
import 'representative_question.dart';

/// One stored ride, as a row.
///
/// Shared rather than private to the history tab because the saved-pack
/// screen shows the same rides with no radio involved, and two copies of this
/// card would drift.
class TripCard extends StatelessWidget {
  const TripCard({
    required this.trip,
    required this.service,
    required this.repository,
    required this.learned,
    required this.t,
    this.onChanged,
    super.key,
  });

  final Trip trip;
  final BmsService service;
  final BmsRepository repository;

  /// The figures of the pack these rides belong to, for the detail screen.
  final LearnedRange Function() learned;

  /// Refreshes the list after this ride is deleted or answered. Null in the
  /// history tab, which rebuilds itself.
  final Future<void> Function()? onChanged;

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
          await onChanged?.call();
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.historyDeleted)));
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TripDetailScreen(
                trip: trip,
                repository: repository,
                service: service,
                learned: learned,
                onChanged: onChanged,
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
                            whPerKm == null ? '--' : whPerKm.toStringAsFixed(0),
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
                        // No climb figure here any more. The uphill and
                        // downhill distances that replaced it are worked out
                        // from the track, and a list of cards is the one place
                        // that cannot afford to read a thousand points per row
                        // to fill in one line of small print.
                        '${(trip.startSoc - trip.endSoc).toStringAsFixed(0)} %',
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
/// The line where the free history ends.
class OlderRidesLocked extends StatelessWidget {
  const OlderRidesLocked({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => openLicenseScreen(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.hairline),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, size: 18, color: AppTheme.watch),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t.historyOlderLocked('$count'),
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const ProBadge(),
          ],
        ),
      ),
    );
  }
}
