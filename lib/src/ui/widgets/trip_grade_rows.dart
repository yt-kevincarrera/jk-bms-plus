import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/database.dart';
import '../../metrics/grade_profile.dart';
import 'common.dart';
import 'cockpit.dart';
import '../theme.dart';

/// How far the ride went uphill, along the flat, and downhill.
///
/// Replaces the two rows that quoted total climb and total descent. Those were
/// honest numbers nobody could use: "you gained 86 m over 25 km" is trivia,
/// and it also read low, because the hysteresis that keeps GPS wander out of
/// the total keeps some real rolling ground out with it.
///
/// Worked out from the stored track rather than from a column, so it applies
/// to every ride already on disk and needs no migration. Two ends of the same
/// trade: it costs a query, and it means the figures cannot appear anywhere
/// that has not loaded the track.
class TripGradeRows extends StatelessWidget {
  const TripGradeRows({
    required this.points,
    required this.t,
    this.last = false,
    this.asTiles = false,
    super.key,
  });

  /// Null where no track can be loaded, in which case nothing is drawn.
  final Future<List<TripPoint>>? points;
  final AppL10n t;

  /// Whether these are the closing rows of their section.
  final bool last;
  final bool asTiles;

  @override
  Widget build(BuildContext context) {
    final future = points;
    if (future == null) return _rows(context, null);
    return FutureBuilder<List<TripPoint>>(
      future: future,
      builder: (context, snapshot) {
        final track = snapshot.data;
        if (track == null) return _rows(context, null);
        // Counted the recorder's way, so the three add up to the distance
        // tile above them.
        final profile = profileOfTrack([
          for (final p in track)
            (
              latitude: p.latitude,
              longitude: p.longitude,
              altitudeM: p.altitudeM,
              at: p.timestamp,
              speedKmh: p.speedKmh,
            ),
        ]);
        return _rows(context, profile.hasAnything ? profile : null);
      },
    );
  }

  /// The rows are drawn either way, dimmed and dashed where there is no track
  /// to split or the ride was too short to bother. Three zeroes would read as
  /// a bug, and drawing nothing at all would leave whatever row sits above
  /// these as the unclosed end of its section.
  Widget _rows(BuildContext context, GradeProfile? profile) {
    String km(double? v) => v == null ? '--' : '${v.toStringAsFixed(1)} km';
    final dim = profile == null;
    if (asTiles) {
      final distances = [
        profile?.uphillKm,
        profile?.flatKm,
        profile?.downhillKm,
      ];
      final colors = [
        context.colors.good,
        context.colors.textSecondary,
        context.colors.cool,
      ];
      final total = distances.fold<double>(
        0,
        (sum, value) => sum + (value ?? 0),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TelemetryStrip(
            padding: const EdgeInsets.only(top: 12),
            size: 34,
            items: [
              TelemetryDatum(
                '↑ ${t.tripUphill}',
                distances[0]?.toStringAsFixed(1) ?? '--',
                unit: 'km',
                color: colors[0],
              ),
              TelemetryDatum(
                '→ ${t.tripFlat}',
                distances[1]?.toStringAsFixed(1) ?? '--',
                unit: 'km',
                color: colors[1],
              ),
              TelemetryDatum(
                '↓ ${t.tripDownhill}',
                distances[2]?.toStringAsFixed(1) ?? '--',
                unit: 'km',
                color: colors[2],
              ),
            ],
          ),
          if (total > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    height: 6,
                    child: Row(
                      children: [
                        for (var i = 0; i < distances.length; i++)
                          if ((distances[i] ?? 0) > 0)
                            Expanded(
                              flex: ((distances[i]! / total) * 10000)
                                  .round()
                                  .clamp(1, 10000),
                              child: ColoredBox(
                                color: colors[i],
                                child: const SizedBox.expand(),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }
    return Column(
      children: [
        InfoRow(t.tripUphill, km(profile?.uphillKm), dim: dim),
        InfoRow(t.tripFlat, km(profile?.flatKm), dim: dim),
        InfoRow(t.tripDownhill, km(profile?.downhillKm), dim: dim, last: last),
      ],
    );
  }
}
