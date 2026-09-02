import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../license/entitlements.dart';
import '../license_scope.dart';
import '../license_screen.dart';
import '../theme.dart';
import 'common.dart';

/// Shows [child] when the phone is licensed for [feature], and a card saying
/// what is locked and why otherwise.
///
/// The card is deliberately not a blurred preview or a teaser: it says in one
/// sentence what the thing is, that it is Pro, and how to get there. A screen
/// that hides half of itself behind a fog teaches people the app is broken.
class ProGate extends StatelessWidget {
  const ProGate({
    required this.feature,
    required this.child,
    this.compact = false,
    super.key,
  });

  final Feature feature;
  final Widget child;

  /// A one-line version, for a spot inside a section rather than a section.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (LicenseScope.allows(context, feature)) return child;
    return ProLockedCard(feature: feature, compact: compact);
  }
}

/// What a gated spot shows when it is locked.
class ProLockedCard extends StatelessWidget {
  const ProLockedCard({required this.feature, this.compact = false, super.key});

  final Feature feature;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final e = LicenseScope.entitlements(context);
    final body = t.proGateBody(featureName(t, feature));
    final trialOver =
        e.status == LicenseStatus.free ||
        e.status == LicenseStatus.workshopExpired;

    if (compact) {
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => openLicenseScreen(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, size: 16, color: AppTheme.watch),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const ProBadge(),
            ],
          ),
        ),
      );
    }

    return Section(
      title: t.proGateTitle,
      accent: AppTheme.watch,
      trailing: const ProBadge(),
      children: [
        Text(
          body,
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.45,
            color: AppTheme.textSecondary,
          ),
        ),
        if (trialOver) ...[
          const SizedBox(height: 4),
          Text(
            t.proGateTrialEnded,
            style: const TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => openLicenseScreen(context),
          icon: const Icon(Icons.key_outlined, size: 18),
          label: Text(t.licenseOpen),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

/// The small amber tag.
class ProBadge extends StatelessWidget {
  const ProBadge({super.key});

  @override
  Widget build(BuildContext context) =>
      Pill(AppL10n.of(context).proBadge, color: AppTheme.watch);
}

/// The wording for each gated thing, in one place.
String featureName(AppL10n t, Feature feature) => switch (feature) {
  Feature.unlimitedHistory => t.proFeatureHistory,
  Feature.degradation => t.proFeatureDegradation,
  Feature.verdicts => t.proFeatureVerdicts,
  Feature.backgroundAlerts => t.proFeatureBackgroundAlerts,
  Feature.backupExportImport => t.proFeatureBackup,
  Feature.configAudit => t.proFeatureConfigAudit,
  Feature.batteryReport => t.proFeatureBatteryReport,
  Feature.inspection => t.proFeatureInspection,
  Feature.sellerCertificate => t.proFeatureCertificate,
  Feature.workshopExtras => t.proFeatureWorkshop,
};

Future<void> openLicenseScreen(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const LicenseScreen()));
