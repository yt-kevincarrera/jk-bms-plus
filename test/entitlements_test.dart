import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/license/entitlements.dart';
import 'package:jk_bms/src/license/license_payload.dart';

void main() {
  final installed = DateTime.utc(2026, 9, 1);
  const device = [1, 2, 3, 4, 5, 6, 7, 8];

  LicensePayload key(
    LicenseTier tier, {
    DateTime? expires,
    int inspections = 0,
    int certificates = 0,
    String label = '',
  }) => LicensePayload(
    tier: tier,
    deviceCode: device,
    issuedAt: installed,
    expiresAt: expires,
    inspectionCredits: inspections,
    certificateCredits: certificates,
    label: label,
  );

  group('trial', () {
    test('is the whole of Pro for seven days from install', () {
      final e = Entitlements.compute(
        keys: const [],
        installedAt: installed,
        now: installed.add(const Duration(days: 3)),
      );
      expect(e.status, LicenseStatus.trial);
      expect(e.isPro, isTrue);
      expect(e.allows(Feature.unlimitedHistory), isTrue);
      expect(e.allows(Feature.degradation), isTrue);
      expect(e.allows(Feature.backupExportImport), isTrue);
      expect(e.trialDaysLeft(installed.add(const Duration(days: 3))), 4);
    });

    test('does not include inspections, which need a credit', () {
      final e = Entitlements.compute(
        keys: const [],
        installedAt: installed,
        now: installed,
      );
      expect(e.allows(Feature.inspection), isFalse);
      expect(e.allows(Feature.sellerCertificate), isFalse);
    });

    test('ends on the dot and falls to free', () {
      final end = installed.add(const Duration(days: 7));
      final before = Entitlements.compute(
        keys: const [],
        installedAt: installed,
        now: end.subtract(const Duration(seconds: 1)),
      );
      final after = Entitlements.compute(
        keys: const [],
        installedAt: installed,
        now: end,
      );
      expect(before.status, LicenseStatus.trial);
      expect(before.trialDaysLeft(end.subtract(const Duration(seconds: 1))), 1);
      expect(after.status, LicenseStatus.free);
      expect(after.isPro, isFalse);
      expect(after.allows(Feature.unlimitedHistory), isFalse);
      expect(after.historyWindow, const Duration(hours: 24));
      expect(after.trialDaysLeft(end), 0);
    });
  });

  group('keys', () {
    final later = installed.add(const Duration(days: 400));

    test('a Pro key is Pro for good', () {
      final e = Entitlements.compute(
        keys: [key(LicenseTier.pro)],
        installedAt: installed,
        now: later,
      );
      expect(e.status, LicenseStatus.pro);
      expect(e.isPro, isTrue);
      expect(e.isWorkshop, isFalse);
      expect(e.historyWindow, isNull);
      expect(e.allows(Feature.workshopExtras), isFalse);
      expect(e.allows(Feature.inspection), isFalse);
    });

    test('a workshop key is everything, until it runs out', () {
      final expiry = installed.add(const Duration(days: 365));
      final live = Entitlements.compute(
        keys: [
          key(LicenseTier.workshop, expires: expiry, label: 'Taller Pepe'),
        ],
        installedAt: installed,
        now: installed.add(const Duration(days: 100)),
      );
      expect(live.status, LicenseStatus.workshop);
      expect(live.allows(Feature.inspection), isTrue);
      expect(live.allows(Feature.sellerCertificate), isTrue);
      expect(live.allows(Feature.workshopExtras), isTrue);
      expect(live.workshopExpiresAt, expiry);
      expect(live.label, 'Taller Pepe');

      final dead = Entitlements.compute(
        keys: [key(LicenseTier.workshop, expires: expiry)],
        installedAt: installed,
        now: later,
      );
      expect(dead.status, LicenseStatus.workshopExpired);
      expect(dead.isPro, isFalse);
      expect(dead.allows(Feature.inspection), isFalse);
    });

    test('a renewal extends to the later date', () {
      final first = installed.add(const Duration(days: 365));
      final second = installed.add(const Duration(days: 730));
      final e = Entitlements.compute(
        keys: [
          key(LicenseTier.workshop, expires: first),
          key(LicenseTier.workshop, expires: second),
        ],
        installedAt: installed,
        now: installed.add(const Duration(days: 400)),
      );
      expect(e.status, LicenseStatus.workshop);
      expect(e.workshopExpiresAt, second);
    });

    test('an expired workshop with a Pro key underneath is still Pro', () {
      final e = Entitlements.compute(
        keys: [
          key(LicenseTier.pro),
          key(
            LicenseTier.workshop,
            expires: installed.add(const Duration(days: 30)),
          ),
        ],
        installedAt: installed,
        now: later,
      );
      expect(e.status, LicenseStatus.pro);
    });

    test('credits add up across keys and count down as they are spent', () {
      final e = Entitlements.compute(
        keys: [
          key(LicenseTier.credits, inspections: 3),
          key(LicenseTier.credits, inspections: 2, certificates: 1),
        ],
        installedAt: installed,
        now: later,
        inspectionsSpent: 4,
      );
      // Credits alone unlock nothing else.
      expect(e.status, LicenseStatus.free);
      expect(e.isPro, isFalse);
      expect(e.inspectionCreditsLeft, 1);
      expect(e.certificateCreditsLeft, 1);
      expect(e.allows(Feature.inspection), isTrue);
      expect(e.allows(Feature.sellerCertificate), isTrue);

      final spent = Entitlements.compute(
        keys: [key(LicenseTier.credits, inspections: 3)],
        installedAt: installed,
        now: later,
        inspectionsSpent: 3,
      );
      expect(spent.inspectionCreditsLeft, 0);
      expect(spent.allows(Feature.inspection), isFalse);
    });

    test('a Pro key can carry credits too', () {
      final e = Entitlements.compute(
        keys: [key(LicenseTier.pro, inspections: 3)],
        installedAt: installed,
        now: later,
      );
      expect(e.isPro, isTrue);
      expect(e.inspectionCreditsLeft, 3);
    });
  });
}
