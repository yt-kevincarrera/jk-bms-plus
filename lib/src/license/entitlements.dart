import 'license_payload.dart';

/// Everything in the app that is not part of the free viewer.
///
/// The free tier is the whole live view, on purpose: the official JK app
/// shows the live numbers, and a free tier that showed fewer would send
/// people back to it. What is gated is what the JK app cannot do by design:
/// remembering, comparing, concluding, and inspecting a stranger's battery.
///
/// A screen asks `entitlements.allows(Feature.x)` and nothing else. Which
/// tier includes what is decided here, once.
enum Feature {
  /// Rides and readings older than a day.
  unlimitedHistory,

  /// Degradation against the pack's own best, and the long-term curves.
  degradation,

  /// The plain-language conclusions on the Health tab.
  verdicts,

  /// Holding the link open while charging so the alerts reach a closed app.
  backgroundAlerts,

  /// Whole-database export and import.
  backupExportImport,

  /// The read-only comparison of BMS settings against safe ranges.
  configAudit,

  /// The "my battery" PDF.
  batteryReport,

  /// One guided quick inspection of somebody else's pack. Consumes a credit
  /// unless the tier includes inspections.
  inspection,

  /// A signed seller certificate. Consumes a credit.
  sellerCertificate,

  /// Unlimited packs on record, the workshop's own logo on the PDFs.
  workshopExtras,
}

/// How the phone is licensed right now, in one word.
enum LicenseStatus {
  /// No key, trial over.
  free,

  /// No key, inside the first week.
  trial,

  /// A Pro key is active.
  pro,

  /// A workshop key is active and in date.
  workshop,

  /// A workshop key was active and has run out. Back to Pro? No: back to
  /// free, said plainly, because that is what was sold.
  workshopExpired,

  /// An admin key is active: the author's own phone, or a tester's.
  admin,

  /// Licensing is not switched on in this build, so there is nothing to
  /// gate. This is every build until the author generates the signing pair;
  /// see `licensePublicKey`. Behaves like [admin] and shows no licence UI.
  unrestricted,
}

/// What this phone may do, worked out from the keys it holds and the day.
///
/// Immutable and cheap to build. The controller rebuilds one whenever a key
/// is added or a credit is spent, and screens read it.
class Entitlements {
  const Entitlements({
    required this.status,
    this.trialEndsAt,
    this.workshopExpiresAt,
    this.inspectionCreditsLeft = 0,
    this.certificateCreditsLeft = 0,
    this.label = '',
  });

  static const Duration trialLength = Duration(days: 7);

  /// The starting point for a phone with nothing stored yet.
  static const Entitlements none = Entitlements(status: LicenseStatus.free);

  /// A build with licensing switched off: everything, no clock, no UI.
  static const Entitlements unrestricted = Entitlements(
    status: LicenseStatus.unrestricted,
  );

  /// Works the status out.
  ///
  /// [keys] are the payloads of every key that verified against this phone,
  /// expired ones included: an expired workshop key still says something
  /// about what the phone was. [creditsSpent] is how many inspections and
  /// certificates have been used on this phone, all keys together.
  factory Entitlements.compute({
    required List<LicensePayload> keys,
    required DateTime installedAt,
    required DateTime now,
    int inspectionsSpent = 0,
    int certificatesSpent = 0,
  }) {
    final trialEnd = installedAt.add(trialLength);
    final inTrial = now.isBefore(trialEnd);

    var status = inTrial ? LicenseStatus.trial : LicenseStatus.free;
    DateTime? workshopUntil;
    var label = '';
    var inspections = 0;
    var certificates = 0;

    var hasPro = false;
    var hasLiveWorkshop = false;
    var hadWorkshop = false;
    var hasAdmin = false;

    for (final k in keys) {
      inspections += k.inspectionCredits;
      certificates += k.certificateCredits;
      if (k.label.isNotEmpty && label.isEmpty) label = k.label;
      switch (k.tier) {
        case LicenseTier.pro:
          hasPro = true;
        case LicenseTier.workshop:
          if (k.isExpiredAt(now)) {
            hadWorkshop = true;
          } else {
            hasLiveWorkshop = true;
            final e = k.expiresAt;
            // Several workshop keys in a row (renewals) end at the latest one.
            if (e != null &&
                (workshopUntil == null || e.isAfter(workshopUntil))) {
              workshopUntil = e;
            } else if (e == null) {
              workshopUntil = null;
            }
          }
        case LicenseTier.credits:
          break;
        case LicenseTier.admin:
          hasAdmin = true;
      }
    }

    if (hasAdmin) {
      status = LicenseStatus.admin;
    } else if (hasLiveWorkshop) {
      status = LicenseStatus.workshop;
    } else if (hasPro) {
      status = LicenseStatus.pro;
    } else if (hadWorkshop && !inTrial) {
      status = LicenseStatus.workshopExpired;
    }

    return Entitlements(
      status: status,
      trialEndsAt: inTrial ? trialEnd : null,
      workshopExpiresAt: hasLiveWorkshop ? workshopUntil : null,
      inspectionCreditsLeft: (inspections - inspectionsSpent).clamp(0, 0xFFFF),
      certificateCreditsLeft: (certificates - certificatesSpent).clamp(
        0,
        0xFFFF,
      ),
      label: label,
    );
  }

  final LicenseStatus status;

  /// Set only while the trial is running.
  final DateTime? trialEndsAt;

  /// Set only while a dated workshop key is running. Null on a workshop key
  /// with no end date.
  final DateTime? workshopExpiresAt;

  final int inspectionCreditsLeft;
  final int certificateCreditsLeft;

  /// From the first key that carried one: the workshop's name, usually.
  final String label;

  /// Everything the Pro tier includes, trial included.
  bool get isPro => switch (status) {
    LicenseStatus.trial ||
    LicenseStatus.pro ||
    LicenseStatus.workshop ||
    LicenseStatus.admin ||
    LicenseStatus.unrestricted => true,
    LicenseStatus.free || LicenseStatus.workshopExpired => false,
  };

  /// Everything the workshop tier includes, which an admin also has.
  bool get isWorkshop => switch (status) {
    LicenseStatus.workshop ||
    LicenseStatus.admin ||
    LicenseStatus.unrestricted => true,
    _ => false,
  };

  /// True when nothing is gated and nothing should be shown about it:
  /// no card, no badge, no trial countdown.
  bool get isUnrestricted => status == LicenseStatus.unrestricted;

  bool get isTrial => status == LicenseStatus.trial;

  /// Days left of the trial, rounded up, or 0.
  int trialDaysLeft(DateTime now) {
    final end = trialEndsAt;
    if (end == null || !now.isBefore(end)) return 0;
    final left = end.difference(now);
    return (left.inSeconds / Duration.secondsPerDay).ceil();
  }

  bool allows(Feature feature) => switch (feature) {
    Feature.unlimitedHistory ||
    Feature.degradation ||
    Feature.verdicts ||
    Feature.backgroundAlerts ||
    Feature.backupExportImport ||
    Feature.configAudit ||
    Feature.batteryReport => isPro,
    // The workshop inspects without counting. Everybody else, the trial
    // included, needs a credit: a free week of unlimited inspections
    // would be the whole product for a buyer who needs it once.
    Feature.inspection => isWorkshop || inspectionCreditsLeft > 0,
    Feature.sellerCertificate => isWorkshop || certificateCreditsLeft > 0,
    Feature.workshopExtras => isWorkshop,
  };

  /// How far back the history goes for this phone. Null means all of it.
  Duration? get historyWindow =>
      allows(Feature.unlimitedHistory) ? null : const Duration(hours: 24);
}
