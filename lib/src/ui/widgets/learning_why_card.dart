import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../metrics/learning_report.dart';
import '../theme.dart';
import 'common.dart';

/// Explains a learned figure that has not appeared.
///
/// Only drawn when there are rides on record and none of them taught the
/// estimator anything. That combination is not the app waiting for more data,
/// it is the app rejecting everything it has, and each reason for rejecting a
/// ride points somewhere specific.
class LearningWhyCard extends StatelessWidget {
  const LearningWhyCard({required this.report, required this.t, super.key});

  final LearningReport report;
  final AppL10n t;

  @override
  Widget build(BuildContext context) {
    if (!report.allRejected) return const SizedBox.shrink();

    final lines = <String>[
      t.learnWhyCount('${report.used}', '${report.considered}'),
      if (report.noDistance > 0) t.learnWhyShort('${report.noDistance}'),
      if (report.noEnergyOut > 0) t.learnWhyNoEnergy('${report.noEnergyOut}'),
      if (report.implausible > 0)
        t.learnWhyImplausible('${report.implausible}'),
    ];

    return Section(
      title: t.learnWhyTitle,
      accent: AppTheme.watch,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              line,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        // The sign is worth calling out separately, because unlike a short ride
        // it is a fault rather than a circumstance, and it would be breaking
        // several things at once while nothing on screen looked wrong.
        if (report.blocker == LearningBlocker.noEnergyOut)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Text(
              t.learnWhySignWarning,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppTheme.watch,
              ),
            ),
          ),
        if (report.blocker == LearningBlocker.ridesTooShort)
          Text(
            t.learnWhyNeedMore,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AppTheme.textFaint,
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}
