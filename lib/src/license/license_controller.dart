import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_code.dart';
import 'device_identity.dart';
import 'entitlements.dart';
import 'license_key.dart';
import 'license_payload.dart';
import 'license_public_key.dart';
import 'license_verifier.dart';

/// One key on this phone, as stored.
class ActivatedLicense {
  const ActivatedLicense({
    required this.key,
    required this.payload,
    required this.activatedAt,
  });

  final LicenseKey key;
  final LicensePayload payload;
  final DateTime activatedAt;

  String get id => key.id;
}

/// The outcome of pasting a key.
class ActivationResult {
  const ActivationResult._({
    this.rejection,
    this.detail = '',
    this.duplicate = false,
  });

  const ActivationResult.ok() : this._();

  const ActivationResult.alreadyActive() : this._(duplicate: true);

  const ActivationResult.rejected(LicenseRejection why, {String detail = ''})
    : this._(rejection: why, detail: detail);

  final LicenseRejection? rejection;
  final String detail;

  /// The same key was already on this phone. Not an error, not a second set
  /// of credits either.
  final bool duplicate;

  bool get accepted => rejection == null;
}

/// Owns the licence state of this phone.
///
/// Loads the trial clock and the activated keys from preferences, re-checks
/// every key against the public key on each load (a key that stopped
/// verifying, because the binary's public key changed, drops out rather than
/// staying unlocked), and exposes one [Entitlements] object for the screens.
///
/// Credits are counted here too. A key says how many inspections were paid
/// for; this keeps how many were used, on this phone, across every key. The
/// difference is what is left. Re-pasting a key already on the phone adds
/// nothing, because the key's id is what it is stored under.
class LicenseController extends ChangeNotifier {
  LicenseController({
    DeviceIdentity? identity,
    LicenseVerifier? verifier,
    DateTime Function()? clock,
  }) : _identity = identity ?? PlatformDeviceIdentity(),
       _verifier = verifier ?? LicenseVerifier(publicKey: licensePublicKey),
       _clock = clock ?? (() => DateTime.now().toUtc());

  static const _installedAtKey = 'license_installed_at';
  static const _keysKey = 'license_keys';
  static const _inspectionsSpentKey = 'license_inspections_spent';
  static const _certificatesSpentKey = 'license_certificates_spent';

  final DeviceIdentity _identity;
  final LicenseVerifier _verifier;
  final DateTime Function() _clock;

  DeviceCode? _device;
  DateTime? _installedAt;
  final List<ActivatedLicense> _active = [];
  int _inspectionsSpent = 0;
  int _certificatesSpent = 0;
  bool _loaded = false;

  Entitlements _entitlements = Entitlements.none;

  /// What this phone may do. [Entitlements.none] until [load] has run, which
  /// means a screen drawn before then gates everything for a frame, rather
  /// than unlocking anything it should not.
  Entitlements get entitlements => _entitlements;

  bool get isLoaded => _loaded;

  /// The code to send with the payment. Null until [load] has run.
  DeviceCode? get deviceCode => _device;

  /// When the trial clock started.
  DateTime? get installedAt => _installedAt;

  List<ActivatedLicense> get activeLicenses => List.unmodifiable(_active);

  /// Whether this build can accept keys at all. False until the author has
  /// generated a key pair and baked the public half in.
  bool get canActivate => licensePublicKeyIsSet;

  int get inspectionsSpent => _inspectionsSpent;
  int get certificatesSpent => _certificatesSpent;

  Future<void> load() async {
    _device = await _identity.code();
    try {
      final prefs = await SharedPreferences.getInstance();
      final at = prefs.getInt(_installedAtKey);
      if (at == null) {
        // First launch of a build that knows about licences. The trial starts
        // now, for a fresh install and for somebody updating from an older
        // build alike; the latter has already been using everything for
        // free, and a week's notice before it gates is the polite version.
        _installedAt = _clock();
        await prefs.setInt(
          _installedAtKey,
          _installedAt!.millisecondsSinceEpoch,
        );
      } else {
        _installedAt = DateTime.fromMillisecondsSinceEpoch(at, isUtc: true);
      }
      _inspectionsSpent = prefs.getInt(_inspectionsSpentKey) ?? 0;
      _certificatesSpent = prefs.getInt(_certificatesSpentKey) ?? 0;

      _active.clear();
      for (final stored in prefs.getStringList(_keysKey) ?? const <String>[]) {
        final parsed = await _restore(stored);
        if (parsed != null) _active.add(parsed);
      }
    } on Exception catch (_) {
      // Without preferences there is no trial clock to read, so the trial
      // starts at every launch. Generous, and the only honest fallback.
      _installedAt ??= _clock();
    }
    _loaded = true;
    _recompute();
  }

  /// Stored form: `<activatedAt millis>|<key text>`.
  Future<ActivatedLicense?> _restore(String stored) async {
    final bar = stored.indexOf('|');
    if (bar < 0) return null;
    final at = int.tryParse(stored.substring(0, bar));
    final text = stored.substring(bar + 1);
    final device = _device;
    if (at == null || device == null) return null;
    // Re-verified on every load, and without the expiry rule: an expired key
    // stays on the list so the screen can say it expired, rather than the
    // phone quietly forgetting it ever paid.
    final check = await _verifier.check(
      text,
      device: device,
      now: DateTime.utc(2000),
    );
    final payload = check.payload;
    if (payload == null) return null;
    return ActivatedLicense(
      key: LicenseKey.parse(text),
      payload: payload,
      activatedAt: DateTime.fromMillisecondsSinceEpoch(at, isUtc: true),
    );
  }

  /// Checks and, if it holds, keeps a pasted key.
  Future<ActivationResult> activate(String text) async {
    final device = _device ?? await _identity.code();
    _device = device;
    final check = await _verifier.check(text, device: device, now: _clock());
    final payload = check.payload;
    if (payload == null) {
      return ActivationResult.rejected(check.rejection!, detail: check.detail);
    }
    final key = LicenseKey.parse(text);
    if (_active.any((a) => a.id == key.id)) {
      return const ActivationResult.alreadyActive();
    }
    _active.add(
      ActivatedLicense(key: key, payload: payload, activatedAt: _clock()),
    );
    await _persistKeys();
    _recompute();
    return const ActivationResult.ok();
  }

  /// Forgets a key. The credits it carried go with it; the ones already
  /// spent stay spent.
  Future<void> remove(String id) async {
    _active.removeWhere((a) => a.id == id);
    await _persistKeys();
    _recompute();
  }

  /// Uses up one inspection. Returns false, and changes nothing, when there
  /// was none to use. The workshop tier never spends.
  Future<bool> consumeInspection() async {
    if (_entitlements.isWorkshop) return true;
    if (_entitlements.inspectionCreditsLeft <= 0) return false;
    _inspectionsSpent += 1;
    await _writeInt(_inspectionsSpentKey, _inspectionsSpent);
    _recompute();
    return true;
  }

  Future<bool> consumeCertificate() async {
    if (_entitlements.isWorkshop) return true;
    if (_entitlements.certificateCreditsLeft <= 0) return false;
    _certificatesSpent += 1;
    await _writeInt(_certificatesSpentKey, _certificatesSpent);
    _recompute();
    return true;
  }

  /// Rebuilds the entitlements for the current moment. Cheap, and worth
  /// calling from a screen that has been open across midnight on the last
  /// day of a trial.
  void refresh() => _recompute();

  void _recompute() {
    final installed = _installedAt ?? _clock();
    _entitlements = Entitlements.compute(
      keys: [for (final a in _active) a.payload],
      installedAt: installed,
      now: _clock(),
      inspectionsSpent: _inspectionsSpent,
      certificatesSpent: _certificatesSpent,
    );
    notifyListeners();
  }

  Future<void> _persistKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keysKey, [
        for (final a in _active)
          '${a.activatedAt.millisecondsSinceEpoch}|${a.key.encode()}',
      ]);
    } on Exception catch (_) {
      // Kept for this session. The buyer still has the key text.
    }
  }

  Future<void> _writeInt(String key, int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, value);
    } on Exception catch (_) {
      // Same.
    }
  }
}
