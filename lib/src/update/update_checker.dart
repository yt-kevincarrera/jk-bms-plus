import 'dart:convert';
import 'dart:io';

import 'app_version.dart';
import 'release_info.dart';

/// Fetches a URL and returns the body, or throws. Injected so the whole update
/// decision can be tested against canned GitHub responses.
typedef JsonFetcher = Future<String> Function(
  Uri uri,
  Map<String, String> headers,
);

/// Asks GitHub whether there is a newer build than the one running.
///
/// Deliberately read-only and deliberately manual: nothing here downloads or
/// installs anything, it only reports what exists. The rider decides.
class UpdateChecker {
  UpdateChecker({
    required this.owner,
    required this.repo,
    JsonFetcher? fetcher,
  }) : _fetch = fetcher ?? _httpGet;

  final String owner;
  final String repo;
  final JsonFetcher _fetch;

  /// GitHub's own advice: pin the API version so a future change cannot alter
  /// the shape of what comes back.
  static const _apiVersion = '2022-11-28';

  Future<UpdateCheck> check({
    required AppVersion current,
    required List<String> supportedAbis,
    String? token,
  }) async {
    final uri = Uri.https(
      'api.github.com',
      '/repos/$owner/$repo/releases/latest',
    );
    final headers = <String, String>{
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': _apiVersion,
      'User-Agent': 'jk-bms-plus',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    String body;
    try {
      body = await _fetch(uri, headers);
    } on _HttpFailure catch (e) {
      // A private repository is indistinguishable from a missing one without a
      // token — GitHub returns 404 either way, on purpose, so that a private
      // repo's existence is not leakable. Say the useful thing rather than
      // "not found".
      if ((e.statusCode == 404 || e.statusCode == 401) &&
          (token == null || token.isEmpty)) {
        return UpdateCheck(
          status: UpdateStatus.needsToken,
          currentVersion: current,
        );
      }
      return UpdateCheck(
        status: UpdateStatus.failed,
        currentVersion: current,
        error: 'HTTP ${e.statusCode}',
      );
    } on Object catch (e) {
      return UpdateCheck(
        status: UpdateStatus.failed,
        currentVersion: current,
        error: e.toString(),
      );
    }

    final ReleaseInfo? release;
    try {
      release = _parseRelease(body);
    } on Object catch (e) {
      return UpdateCheck(
        status: UpdateStatus.failed,
        currentVersion: current,
        error: e.toString(),
      );
    }
    if (release == null) {
      return UpdateCheck(
        status: UpdateStatus.failed,
        currentVersion: current,
        error: 'unparseable release',
      );
    }

    if (!release.version.isNewerThan(current)) {
      return UpdateCheck(
        status: UpdateStatus.upToDate,
        currentVersion: current,
        release: release,
      );
    }

    final asset = release.assetForAbis(supportedAbis);
    if (asset == null) {
      return UpdateCheck(
        status: UpdateStatus.noAssetForDevice,
        currentVersion: current,
        release: release,
      );
    }

    return UpdateCheck(
      status: UpdateStatus.available,
      currentVersion: current,
      release: release,
      asset: asset,
    );
  }

  /// Turns GitHub's release JSON into [ReleaseInfo]. Static and public so the
  /// parsing can be tested against a captured response.
  static ReleaseInfo? parse(String json) => _parseRelease(json);

  /// Returns null for anything it cannot make sense of, including a body that
  /// is not JSON at all -- a captive portal answering with an HTML login page
  /// is a normal thing to receive, not a reason to throw.
  static ReleaseInfo? _parseRelease(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    final tag = decoded['tag_name'];
    if (tag is! String) return null;
    final version = AppVersion.tryParse(tag);
    if (version == null) return null;

    final assets = <ReleaseAsset>[];
    final rawAssets = decoded['assets'];
    if (rawAssets is List) {
      for (final a in rawAssets) {
        if (a is! Map) continue;
        final name = a['name'];
        final url = a['browser_download_url'];
        final apiUrl = a['url'];
        if (name is! String || url is! String || apiUrl is! String) continue;
        final size = a['size'];
        assets.add(
          ReleaseAsset(
            name: name,
            downloadUrl: url,
            apiUrl: apiUrl,
            sizeBytes: size is int ? size : 0,
          ),
        );
      }
    }

    return ReleaseInfo(
      version: version,
      tag: tag,
      notes: decoded['body'] is String ? decoded['body'] as String : '',
      assets: assets,
      htmlUrl: decoded['html_url'] is String
          ? decoded['html_url'] as String
          : 'https://github.com/',
      publishedAt: decoded['published_at'] is String
          ? DateTime.tryParse(decoded['published_at'] as String)
          : null,
    );
  }
}

class _HttpFailure implements Exception {
  const _HttpFailure(this.statusCode);
  final int statusCode;

  @override
  String toString() => 'HTTP $statusCode';
}

Future<String> _httpGet(Uri uri, Map<String, String> headers) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.getUrl(uri);
    headers.forEach(request.headers.set);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode >= 400) throw _HttpFailure(response.statusCode);
    return body;
  } finally {
    client.close();
  }
}
