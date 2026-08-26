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
  UpdateService({required this.currentVersion, UpdateChecker? checker})
      : _checker = checker ??
            UpdateChecker(owner: kUpdateOwner, repo: kUpdateRepo);

  static const _channel = MethodChannel('dev.selector.jk_bms/installer');

  AppVersion currentVersion;
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

    final result = await _checker.check(
      current: currentVersion,
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
