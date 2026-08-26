import 'app_version.dart';

/// One file attached to a GitHub release.
class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.apiUrl,
    required this.sizeBytes,
  });

  final String name;

  /// The public URL. Works only while the repository is public.
  final String downloadUrl;

  /// The API URL for the asset, which is what a private repository needs:
  /// requested with a token and `Accept: application/octet-stream`, it
  /// redirects to the real file.
  final String apiUrl;

  final int sizeBytes;

  double get sizeMb => sizeBytes / (1024 * 1024);
}

/// A release as the app cares about it.
class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.tag,
    required this.notes,
    required this.assets,
    required this.htmlUrl,
    this.publishedAt,
  });

  final AppVersion version;
  final String tag;
  final String notes;
  final List<ReleaseAsset> assets;
  final String htmlUrl;

  /// When GitHub says it was published. Null if it did not say.
  final DateTime? publishedAt;

  /// Picks the build for this phone's instruction set.
  ///
  /// The releases are split per ABI, so an arm64 phone downloads 20 MB instead
  /// of the 58 MB a universal APK costs. Android reports the ABIs it supports
  /// best-first, so the first one with a matching asset is the right answer.
  ///
  /// Falls back to a universal APK if one is published, and returns null rather
  /// than guessing when nothing matches — installing an APK built for another
  /// architecture fails at install time with an error that explains nothing.
  ReleaseAsset? assetForAbis(List<String> supportedAbis) {
    for (final abi in supportedAbis) {
      for (final a in assets) {
        if (a.name.endsWith('.apk') && a.name.contains(abi)) return a;
      }
    }
    for (final a in assets) {
      final n = a.name.toLowerCase();
      if (n.endsWith('.apk') &&
          !n.contains('arm') &&
          !n.contains('x86') &&
          !n.contains('mips')) {
        return a;
      }
    }
    return null;
  }
}

/// What an update check concluded.
enum UpdateStatus {
  /// Nothing newer published.
  upToDate,

  /// A newer release exists and has a build for this phone.
  available,

  /// A newer release exists but published no APK this phone can install.
  noAssetForDevice,

  /// The check could not be made: no network, or GitHub said no.
  failed,

  /// The repository is private and no token has been provided.
  needsToken,
}

class UpdateCheck {
  const UpdateCheck({
    required this.status,
    required this.currentVersion,
    this.release,
    this.asset,
    this.error,
  });

  final UpdateStatus status;
  final AppVersion currentVersion;
  final ReleaseInfo? release;
  final ReleaseAsset? asset;
  final String? error;

  bool get hasUpdate => status == UpdateStatus.available;
}
