import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_version.dart';
import 'release_info.dart';
import 'update_checker.dart';
import 'update_downloader.dart';

/// Where this app publishes its builds.
///
/// Not a setting: an app that can be pointed at an arbitrary repository is an
/// app that can be talked into installing an arbitrary package.
const String kUpdateOwner = String.fromEnvironment(
  'UPDATE_OWNER',
  defaultValue: 'yt-kevincarrera',
);
const String kUpdateRepo = String.fromEnvironment(
  'UPDATE_REPO',
  defaultValue: 'jk-bms-plus',
);

enum UpdatePhase { idle, checking, downloading, readyToInstall, failed }

/// Checking for, fetching and handing over an update.
///
/// The whole flow is manual by design. Nothing is checked on a timer, nothing
/// downloads on mobile data behind your back, and nothing installs without the
/// system's own prompt. An app that installs packages is exactly the kind of
/// thing that should not be doing anything clever on its own.
class UpdateService extends ChangeNotifier {
  UpdateService({this.currentVersion, UpdateChecker? checker})
      : _checker = checker ??
            UpdateChecker(owner: kUpdateOwner, repo: kUpdateRepo) {
    // Tests hand the version in directly; the app reads it from the platform
    // and completes this later.
    if (currentVersion != null) _versionKnown.complete();
  }

  static const _channel = MethodChannel('dev.selector.jk_bms/installer');

  /// The version actually installed, once the platform has been asked.
  ///
  /// Null until then, and nothing checks for an update while it is null. It
  /// used to start at 0.0.0 and be filled in asynchronously, which raced the
  /// check that runs at startup: the comparison ran against 0.0.0, every
  /// published release looked newer, and the app announced an update to
  /// somebody already running it. Recording that as a check made the wrong
  /// answer stick for a day.
  AppVersion? currentVersion;

  final Completer<void> _versionKnown = Completer<void>();

  set version(AppVersion v) {
    currentVersion = v;
    if (!_versionKnown.isCompleted) _versionKnown.complete();
  }

  /// Completes once the installed version is known. Nothing can sensibly
  /// compare against a release before this.
  Future<void> get ready => _versionKnown.future;
  final UpdateChecker _checker;

  UpdatePhase phase = UpdatePhase.idle;
  UpdateCheck? lastCheck;
  DownloadProgress? progress;
  String? error;
  File? _downloaded;

  /// The token used for a private repository, supplied by the rider.
  ///
  /// Never compiled into the binary: a token baked into an APK is a token
  /// published to everyone the APK reaches. Held here, from preferences, and
  /// only ever sent to api.github.com.
  String? token;

  bool get busy =>
      phase == UpdatePhase.checking || phase == UpdatePhase.downloading;

  /// The instruction sets this phone can run, best first.
  Future<List<String>> _supportedAbis() async {
    try {
      final abis = await _channel.invokeListMethod<String>('supportedAbis');
      if (abis != null && abis.isNotEmpty) return abis;
    } on Object catch (_) {
      // Not Android, or the channel is not up. Fall through.
    }
    return const ['arm64-v8a'];
  }

  /// Asks once a day, in the background, so a new build can announce itself.
  ///
  /// The only thing this app does on the network unasked. It is one request to
  /// api.github.com that sends nothing about the pack, the rides or where you
  /// are, it never downloads anything, and a failure is swallowed: a banner
  /// that did not appear is not worth an error message.
  ///
  /// Returns true if there is an update worth showing.
  Future<bool> checkQuietly({
    required DateTime? lastCheckedAt,
    required Duration interval,
    required Future<void> Function(DateTime) onChecked,
  }) async {
    if (busy) return false;
    // Never against a version the app has not read yet.
    await ready;
    final current = currentVersion;
    if (current == null) return false;
    final now = DateTime.now().toUtc();
    if (lastCheckedAt != null && now.difference(lastCheckedAt) < interval) {
      // Already asked recently. Reuse whatever the last answer was.
      return lastCheck?.hasUpdate ?? false;
    }

    try {
      final result = await _checker.check(
        current: current,
        supportedAbis: await _supportedAbis(),
        token: token,
      );
      lastCheck = result;
      // A check that could not reach GitHub is not a check. Recording it would
      // stand the app down for a day over a moment without signal, which is
      // exactly when this runs: the app opens, the radio is busy, the request
      // fails, and the update stays invisible until tomorrow.
      if (result.status != UpdateStatus.failed &&
          result.status != UpdateStatus.needsToken) {
        await onChecked(now);
      }
      notifyListeners();
      return result.hasUpdate;
    } on Object catch (_) {
      return false;
    }
  }

  Future<UpdateCheck> check() async {
    // Clears any package left from a previous run. This is the only safe
    // moment to do it: the system installer reads the file asynchronously
    // after the intent is handed over, so deleting right after the hand-off
    // pulls it out from under the installer. By the next check that install
    // has either finished or been abandoned, and either way the file is dead
    // weight -- 21 MB of it.
    await UpdateDownloader.clearCache();
    _downloaded = null;

    phase = UpdatePhase.checking;
    error = null;
    notifyListeners();

    // The installed version has to be known before anything can be compared
    // against it.
    await ready;
    final current = currentVersion!;

    final result = await _checker.check(
      current: current,
      supportedAbis: await _supportedAbis(),
      token: token,
    );

    lastCheck = result;
    phase = result.status == UpdateStatus.failed
        ? UpdatePhase.failed
        : UpdatePhase.idle;
    error = result.error;
    notifyListeners();
    return result;
  }

  /// Fetches the package for the release found by the last check.
  Future<bool> download() async {
    final asset = lastCheck?.asset;
    if (asset == null) return false;

    phase = UpdatePhase.downloading;
    progress = DownloadProgress(0, asset.sizeBytes);
    error = null;
    notifyListeners();

    try {
      _downloaded = await UpdateDownloader.download(
        asset,
        token: token,
        onProgress: (p) {
          progress = p;
          notifyListeners();
        },
      );
      phase = UpdatePhase.readyToInstall;
      notifyListeners();
      return true;
    } on Object catch (e) {
      error = e.toString();
      phase = UpdatePhase.failed;
      notifyListeners();
      return false;
    }
  }

  /// Whether Android will let this app ask to install a package.
  Future<bool> canInstall() async {
    try {
      return await _channel.invokeMethod<bool>('canInstall') ?? false;
    } on Object catch (_) {
      return false;
    }
  }

  Future<void> openInstallSettings() async {
    try {
      await _channel.invokeMethod<void>('openInstallSettings');
    } on Object catch (_) {
      // Nothing useful to do if the settings screen will not open.
    }
  }

  /// Hands the downloaded package to the system installer.
  ///
  /// Returns false if the hand-off itself failed. A rider who then declines the
  /// system prompt is not a failure — it is the prompt working.
  Future<bool> install() async {
    final file = _downloaded;
    if (file == null) return false;
    try {
      await _channel.invokeMethod<bool>('installApk', {'path': file.path});
      return true;
    } on Object catch (e) {
      error = e.toString();
      phase = UpdatePhase.failed;
      notifyListeners();
      return false;
    }
  }

  void reset() {
    phase = UpdatePhase.idle;
    progress = null;
    error = null;
    notifyListeners();
  }
}
