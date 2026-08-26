import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'release_info.dart';

/// How far along a download is.
class DownloadProgress {
  const DownloadProgress(this.received, this.total);

  final int received;
  final int total;

  /// Null when the server did not say how big the file is, which is possible
  /// and must not be turned into a fake percentage.
  double? get fraction => total > 0 ? (received / total).clamp(0.0, 1.0) : null;
}

/// Downloads a release asset to a file the installer can read.
class UpdateDownloader {
  /// Fetches [asset] and returns the file it landed in.
  ///
  /// Redirects are followed by hand for one specific reason: a private
  /// repository's asset is requested from api.github.com with an
  /// `Authorization` header, and GitHub answers with a redirect to object
  /// storage that rejects the request outright if that header comes along. The
  /// token is therefore dropped the moment the host changes — which is also the
  /// behaviour you want for a credential in general.
  static Future<File> download(
    ReleaseAsset asset, {
    String? token,
    void Function(DownloadProgress)? onProgress,
  }) async {
    final dir = await getApplicationSupportDirectory();
    final updates = Directory(p.join(dir.path, 'updates'));
    if (!updates.existsSync()) updates.createSync(recursive: true);

    // One file per asset name, overwritten. A half-finished download from a
    // previous attempt must not be mistaken for a complete one, so the bytes
    // go to a temporary name and are renamed only once the stream ends.
    final target = File(p.join(updates.path, asset.name));
    final partial = File('${target.path}.part');
    if (partial.existsSync()) partial.deleteSync();

    final usingToken = token != null && token.isNotEmpty;
    // The API URL is the one that works for a private repository; the plain
    // download URL is the one that works without a token.
    var uri = Uri.parse(usingToken ? asset.apiUrl : asset.downloadUrl);
    final originalHost = uri.host;

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      HttpClientResponse? response;
      for (var hop = 0; hop < 6; hop++) {
        final request = await client.getUrl(uri);
        request.followRedirects = false;
        request.headers.set('User-Agent', 'jk-bms-plus');
        request.headers.set('Accept', 'application/octet-stream');
        // Only while still talking to GitHub itself.
        if (usingToken && uri.host == originalHost) {
          request.headers.set('Authorization', 'Bearer $token');
        }

        final r = await request.close();
        if (r.isRedirect) {
          final location = r.headers.value(HttpHeaders.locationHeader);
          await r.drain<void>();
          if (location == null) {
            throw HttpException('redirect without a location', uri: uri);
          }
          uri = uri.resolve(location);
          continue;
        }
        response = r;
        break;
      }

      if (response == null) {
        throw HttpException('too many redirects', uri: uri);
      }
      if (response.statusCode >= 400) {
        await response.drain<void>();
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }

      final total = response.contentLength > 0
          ? response.contentLength
          : asset.sizeBytes;
      var received = 0;
      final sink = partial.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(DownloadProgress(received, total));
        }
      } finally {
        await sink.close();
      }

      // A truncated download is worse than a failed one: it installs as a
      // corrupt package, or does not install at all with an opaque error.
      if (total > 0 && received != total) {
        partial.deleteSync();
        throw HttpException(
          'incomplete download: $received of $total bytes',
          uri: uri,
        );
      }

      if (target.existsSync()) target.deleteSync();
      return partial.renameSync(target.path);
    } finally {
      client.close();
    }
  }

  /// Removes downloaded packages. Called after a successful install hand-off,
  /// so a 20 MB file does not sit in app storage forever.
  static Future<void> clearCache() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final updates = Directory(p.join(dir.path, 'updates'));
      if (updates.existsSync()) updates.deleteSync(recursive: true);
    } on Object catch (_) {
      // Housekeeping. Failing to tidy up is not worth surfacing.
    }
  }
}
