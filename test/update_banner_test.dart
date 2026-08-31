import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/update/app_version.dart';
import 'package:jk_bms/src/update/update_checker.dart';
import 'package:jk_bms/src/update/update_service.dart';

String releaseJson(String tag) => jsonEncode({
      'tag_name': tag,
      'body': '',
      'html_url': 'https://github.com/o/r/releases/tag/$tag',
      'assets': [
        {
          'name': 'jk-bms-plus-arm64-v8a.apk',
          'browser_download_url': 'https://example.invalid/a.apk',
          'url': 'https://api.github.com/repos/o/r/releases/assets/1',
          'size': 21700000,
        },
      ],
    });

UpdateService serviceReturning(String tag, {List<Uri>? calls}) => UpdateService(
      currentVersion: const AppVersion(1, 0, 0),
      checker: UpdateChecker(
        owner: 'o',
        repo: 'r',
        fetcher: (uri, headers) async {
          calls?.add(uri);
          return releaseJson(tag);
        },
      ),
    );

void main() {
  group('the quiet check behind the update banner', () {
    test('asks when it has never asked, and reports an update', () async {
      final calls = <Uri>[];
      final s = serviceReturning('v1.4.0', calls: calls);
      DateTime? recorded;

      final found = await s.checkQuietly(
        lastCheckedAt: null,
        interval: const Duration(hours: 24),
        onChecked: (at) async => recorded = at,
      );

      expect(found, isTrue);
      expect(calls, hasLength(1));
      expect(recorded, isNotNull);
    });

    test('does not ask again inside the interval', () async {
      // The point of the interval: this is the only unprompted network call
      // the app makes, and it should stay one a day rather than one per launch.
      final calls = <Uri>[];
      final s = serviceReturning('v1.4.0', calls: calls);
      await s.checkQuietly(
        lastCheckedAt: null,
        interval: const Duration(hours: 24),
        onChecked: (_) async {},
      );
      expect(calls, hasLength(1));

      final again = await s.checkQuietly(
        lastCheckedAt: DateTime.now().toUtc(),
        interval: const Duration(hours: 24),
        onChecked: (_) async {},
      );
      // No second request, but the previous answer still stands.
      expect(calls, hasLength(1));
      expect(again, isTrue);
    });

    test('asks again once the interval has passed', () async {
      final calls = <Uri>[];
      final s = serviceReturning('v1.4.0', calls: calls);
      await s.checkQuietly(
        lastCheckedAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
        interval: const Duration(hours: 24),
        onChecked: (_) async {},
      );
      expect(calls, hasLength(1));
    });

    test('reports nothing when the published version is not newer', () async {
      final s = serviceReturning('v1.0.0');
      final found = await s.checkQuietly(
        lastCheckedAt: null,
        interval: const Duration(hours: 24),
        onChecked: (_) async {},
      );
      expect(found, isFalse);
    });

    test('a failure is swallowed rather than surfaced', () async {
      // A banner that did not appear is not worth an error message on a screen
      // the rider opened to do something else.
      final s = UpdateService(
        currentVersion: const AppVersion(1, 0, 0),
        checker: UpdateChecker(
          owner: 'o',
          repo: 'r',
          fetcher: (uri, headers) async => throw const FormatException('down'),
        ),
      );
      var recorded = false;

      final found = await s.checkQuietly(
        lastCheckedAt: null,
        interval: const Duration(hours: 24),
        onChecked: (_) async => recorded = true,
      );

      expect(found, isFalse);
      // And a failed check does not count as having checked, so it will retry
      // on the next launch rather than going quiet for a day.
      expect(recorded, isFalse);
    });
  });
}
