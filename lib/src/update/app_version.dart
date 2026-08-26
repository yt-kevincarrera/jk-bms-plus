/// A released version of the app, as `major.minor.patch`.
///
/// Kept separate from anything that touches the network so the comparison —
/// the part that decides whether to offer an update at all — can be tested
/// without one. Getting this wrong in the direction of "newer" would push the
/// rider into installing the same build over and over; getting it wrong in the
/// direction of "older" would silently strand them on a stale version.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  /// Parses `1.2.3`, tolerating a `v` prefix and a `+buildNumber` or
  /// `-suffix` tail, which is how both pubspec and git tags tend to look.
  ///
  /// Returns null rather than throwing: a release tag someone typed by hand is
  /// not a programming error, it is bad input, and the right response is to
  /// ignore that release rather than to crash the update check.
  static AppVersion? tryParse(String raw) {
    var s = raw.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);

    // Drop the build metadata and any pre-release suffix.
    final plus = s.indexOf('+');
    if (plus >= 0) s = s.substring(0, plus);
    final dash = s.indexOf('-');
    if (dash >= 0) s = s.substring(0, dash);

    final parts = s.split('.');
    if (parts.isEmpty || parts.length > 3) return null;

    final numbers = <int>[];
    for (final p in parts) {
      final n = int.tryParse(p);
      // Refuse anything that is not plainly a number. "1.2.3rc" is not 1.2.3.
      if (n == null || n < 0) return null;
      numbers.add(n);
    }
    return AppVersion(
      numbers[0],
      numbers.length > 1 ? numbers[1] : 0,
      numbers.length > 2 ? numbers[2] : 0,
    );
  }

  final int major;
  final int minor;
  final int patch;

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool isNewerThan(AppVersion other) => compareTo(other) > 0;

  @override
  String toString() => '$major.$minor.$patch';

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);
}
