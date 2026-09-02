import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/license/device_code.dart';
import 'package:jk_bms/src/license/device_identity.dart';
import 'package:jk_bms/src/license/entitlements.dart';
import 'package:jk_bms/src/license/license_controller.dart';
import 'package:jk_bms/src/license/license_payload.dart';
import 'package:jk_bms/src/license/license_verifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final device = DeviceCode(const [10, 20, 30, 40, 50, 60, 70, 80]);
  final t0 = DateTime.utc(2026, 9, 2, 10);
  late LicenseSigner signer;
  late LicenseVerifier verifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    signer = await LicenseSigner.generate();
    verifier = LicenseVerifier(publicKey: await signer.publicKey);
  });

  // `enabled` is said explicitly: the repository's public key is the all-zero
  // placeholder, so a controller built with the defaults is switched off.
  LicenseController controller(DateTime Function() clock) => LicenseController(
    identity: FixedDeviceIdentity(device),
    verifier: verifier,
    clock: clock,
    enabled: true,
  );

  Future<String> issue(
    LicenseTier tier, {
    DateTime? expires,
    int inspections = 0,
    DeviceCode? forDevice,
  }) async => (await signer.sign(
    LicensePayload(
      tier: tier,
      deviceCode: (forDevice ?? device).bytes,
      issuedAt: t0,
      expiresAt: expires,
      inspectionCredits: inspections,
    ),
  )).encode();

  test('first load starts the trial and remembers when', () async {
    final c = controller(() => t0);
    expect(c.entitlements, Entitlements.none);
    await c.load();
    expect(c.isLoaded, isTrue);
    expect(c.deviceCode, device);
    expect(c.installedAt, t0);
    expect(c.entitlements.status, LicenseStatus.trial);

    // A later launch reads the same clock rather than restarting it.
    final later = controller(() => t0.add(const Duration(days: 10)));
    await later.load();
    expect(later.installedAt, t0);
    expect(later.entitlements.status, LicenseStatus.free);
  });

  test(
    'a good key activates, persists, and is re-verified next launch',
    () async {
      // Installed at t0, so the trial is over by the time the key arrives.
      await controller(() => t0).load();
      final now = t0.add(const Duration(days: 30));
      final c = controller(() => now);
      await c.load();
      expect(c.entitlements.isPro, isFalse);

      var notified = 0;
      c.addListener(() => notified++);
      final result = await c.activate(await issue(LicenseTier.pro));
      expect(result.accepted, isTrue);
      expect(c.entitlements.status, LicenseStatus.pro);
      expect(notified, greaterThan(0));
      expect(c.activeLicenses, hasLength(1));

      final again = controller(() => now);
      await again.load();
      expect(again.entitlements.status, LicenseStatus.pro);
      expect(again.activeLicenses.single.payload.tier, LicenseTier.pro);
    },
  );

  test('pasting the same key twice adds nothing', () async {
    final c = controller(() => t0);
    await c.load();
    final key = await issue(LicenseTier.credits, inspections: 3);
    expect((await c.activate(key)).accepted, isTrue);
    final second = await c.activate(key);
    expect(second.accepted, isTrue);
    expect(second.duplicate, isTrue);
    expect(c.entitlements.inspectionCreditsLeft, 3);
    expect(c.activeLicenses, hasLength(1));
  });

  test('a key for another phone is refused with the reason', () async {
    final c = controller(() => t0);
    await c.load();
    final other = DeviceCode(const [1, 1, 1, 1, 1, 1, 1, 1]);
    final result = await c.activate(
      await issue(LicenseTier.pro, forDevice: other),
    );
    expect(result.accepted, isFalse);
    expect(result.rejection, LicenseRejection.wrongDevice);
    expect(c.activeLicenses, isEmpty);
  });

  test('a stored key that stops verifying drops out on load', () async {
    final c = controller(() => t0);
    await c.load();
    await c.activate(await issue(LicenseTier.pro));

    // Same preferences, different public key: the build changed underneath.
    final otherSigner = await LicenseSigner.generate();
    final rebuilt = LicenseController(
      identity: FixedDeviceIdentity(device),
      verifier: LicenseVerifier(publicKey: await otherSigner.publicKey),
      clock: () => t0.add(const Duration(days: 30)),
      enabled: true,
    );
    await rebuilt.load();
    expect(rebuilt.activeLicenses, isEmpty);
    expect(rebuilt.entitlements.status, LicenseStatus.free);
  });

  test('credits are spent on this phone and stay spent', () async {
    await controller(() => t0).load();
    final c = controller(() => t0.add(const Duration(days: 30)));
    await c.load();
    await c.activate(await issue(LicenseTier.credits, inspections: 2));
    expect(c.entitlements.allows(Feature.inspection), isTrue);
    expect(await c.consumeInspection(), isTrue);
    expect(await c.consumeInspection(), isTrue);
    expect(await c.consumeInspection(), isFalse);
    expect(c.entitlements.inspectionCreditsLeft, 0);

    final again = controller(() => t0.add(const Duration(days: 31)));
    await again.load();
    expect(again.inspectionsSpent, 2);
    expect(again.entitlements.inspectionCreditsLeft, 0);
  });

  test('the workshop never spends a credit', () async {
    final c = controller(() => t0);
    await c.load();
    await c.activate(
      await issue(
        LicenseTier.workshop,
        expires: t0.add(const Duration(days: 365)),
      ),
    );
    expect(await c.consumeInspection(), isTrue);
    expect(c.inspectionsSpent, 0);
  });

  test('an expired key stays listed but unlocks nothing', () async {
    var now = t0;
    final c = controller(() => now);
    await c.load();
    await c.activate(
      await issue(
        LicenseTier.workshop,
        expires: t0.add(const Duration(days: 30)),
      ),
    );
    expect(c.entitlements.status, LicenseStatus.workshop);

    now = t0.add(const Duration(days: 60));
    final later = controller(() => now);
    await later.load();
    expect(later.activeLicenses, hasLength(1));
    expect(later.entitlements.status, LicenseStatus.workshopExpired);
  });

  test(
    'with licensing off, everything is open and nothing is written',
    () async {
      final c = LicenseController(
        identity: FixedDeviceIdentity(device),
        verifier: verifier,
        clock: () => t0,
        enabled: false,
      );
      await c.load();
      expect(c.isLoaded, isTrue);
      expect(c.canActivate, isFalse);
      expect(c.entitlements.isUnrestricted, isTrue);
      expect(c.entitlements.allows(Feature.unlimitedHistory), isTrue);
      expect(await c.consumeInspection(), isTrue);

      // The trial clock must not have started: the day licensing is switched
      // on, the week has to begin then, not months earlier.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);

      final live = controller(() => t0.add(const Duration(days: 400)));
      await live.load();
      expect(live.installedAt, t0.add(const Duration(days: 400)));
      expect(live.entitlements.status, LicenseStatus.trial);
    },
  );

  test('the switch follows the public key by default', () {
    // The placeholder is all zeros, so a build straight from the repo has
    // licensing off. See license_public_key.dart.
    expect(
      LicenseController(identity: FixedDeviceIdentity(device)).enabled,
      isFalse,
    );
  });

  test('an admin key never spends and never expires', () async {
    await controller(() => t0).load();
    final c = controller(() => t0.add(const Duration(days: 3000)));
    await c.load();
    final result = await c.activate(await issue(LicenseTier.admin));
    expect(result.accepted, isTrue);
    expect(c.entitlements.status, LicenseStatus.admin);
    expect(await c.consumeInspection(), isTrue);
    expect(await c.consumeCertificate(), isTrue);
    expect(c.inspectionsSpent, 0);
  });

  test('removing a key takes its unlocks with it', () async {
    await controller(() => t0).load();
    final c = controller(() => t0.add(const Duration(days: 30)));
    await c.load();
    await c.activate(await issue(LicenseTier.pro));
    await c.remove(c.activeLicenses.single.id);
    expect(c.activeLicenses, isEmpty);
    expect(c.entitlements.status, LicenseStatus.free);
  });
}
