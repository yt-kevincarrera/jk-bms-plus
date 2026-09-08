import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/database.dart';
import '../../metrics/grade_profile.dart';
import 'common.dart';

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
    super.key,
  });

  /// Null where no track can be loaded, in which case nothing is drawn.
  final Future<List<TripPoint>>? points;
  final AppL10n t;

  /// Whether these are the closing rows of their section.
  final bool last;

  @override
  Widget build(BuildContext context) {
    final future = points;
    if (future == null) return _rows(null);
    return FutureBuilder<List<TripPoint>>(
      future: future,
      builder: (context, snapshot) {
        final track = snapshot.data;
        if (track == null) return _rows(null);
        final profile = profileOf([
          for (final p in track)
            (
              latitude: p.latitude,
              longitude: p.longitude,
              altitudeM: p.altitudeM,
            ),
        ]);
        return _rows(profile.hasAnything ? profile : null);
      },
    );
  }

  /// The rows are drawn either way, dimmed and dashed where there is no track
  /// to split or the ride was too short to bother. Three zeroes would read as
  /// a bug, and drawing nothing at all would leave whatever row sits above
  /// these as the unclosed end of its section.
  Widget _rows(GradeProfile? profile) {
    String km(double? v) => v == null ? '--' : '${v.toStringAsFixed(1)} km';
    final dim = profile == null;
    return Column(
      children: [
        InfoRow(t.tripUphill, km(profile?.uphillKm), dim: dim),
        InfoRow(t.tripFlat, km(profile?.flatKm), dim: dim),
        InfoRow(t.tripDownhill, km(profile?.downhillKm), dim: dim, last: last),
      ],
    );
  }
}
