import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/update/app_version.dart';
import 'package:jk_bms/src/update/release_info.dart';
import 'package:jk_bms/src/update/update_checker.dart';

/// A GitHub release payload shaped like the real one, trimmed to the fields the
/// app reads.
String releaseJson({
  required String tag,
  List<String> assetNames = const [
    'jk-bms-plus-arm64-v8a.apk',
    'jk-bms-plus-armeabi-v7a.apk',
    'jk-bms-plus-x86_64.apk',
  ],
}) =>
    jsonEncode({
      'tag_name': tag,
      'body': 'Notes for $tag',
      'html_url': 'https://github.com/owner/repo/releases/tag/$tag',
      'assets': [
        for (final n in assetNames)
          {
            'name': n,
            'browser_download_url':
                'https://github.com/owner/repo/releases/download/$tag/$n',
            'url': 'https://api.github.com/repos/owner/repo/releases/assets/1',
            'size': 21700000,
          },
      ],
    });

void main() {
  group('AppVersion', () {
    test('parses the shapes a release tag actually takes', () {
      expect(AppVersion.tryParse('1.2.3'), const AppVersion(1, 2, 3));
      expect(AppVersion.tryParse('v1.2.3'), const AppVersion(1, 2, 3));
      expect(AppVersion.tryParse('  v1.2.3 '), const AppVersion(1, 2, 3));
      // pubspec carries a build number the comparison must ignore.
      expect(AppVersion.tryParse('1.2.3+7'), const AppVersion(1, 2, 3));
      expect(AppVersion.tryParse('1.2'), const AppVersion(1, 2, 0));
      expect(AppVersion.tryParse('2'), const AppVersion(2, 0, 0));
    });

    test('refuses what it cannot read rather than guessing', () {
      // Guessing here would offer a phantom update, or hide a real one.
      expect(AppVersion.tryParse('latest'), isNull);
      expect(AppVersion.tryParse('1.2.3.4'), isNull);
      expect(AppVersion.tryParse('1.x.3'), isNull);
      expect(AppVersion.tryParse(''), isNull);
      expect(AppVersion.tryParse('-1.0.0'), isNull);
    });

    test('orders by each part in turn, not by string', () {
      // The bug this guards: '1.10.0' sorts before '1.9.0' as text.
      expect(
        const AppVersion(1, 10, 0).isNewerThan(const AppVersion(1, 9, 0)),
        isTrue,
      );
      expect(
        const AppVersion(2, 0, 0).isNewerThan(const AppVersion(1, 99, 99)),
        isTrue,
      );
      expect(
        const AppVersion(1, 0, 1).isNewerThan(const AppVersion(1, 0, 0)),
        isTrue,
      );
      expect(
        const AppVersion(1, 0, 0).isNewerThan(const AppVersion(1, 0, 0)),
        isFalse,
      );
    });
  });

  group('release parsing', () {
    test('reads the tag, notes and assets', () {
      final r = UpdateChecker.parse(releaseJson(tag: 'v1.4.0'))!;
      expect(r.version, const AppVersion(1, 4, 0));
      expect(r.tag, 'v1.4.0');
      expect(r.notes, contains('1.4.0'));
      expect(r.assets, hasLength(3));
      expect(r.assets.first.sizeMb, closeTo(20.7, 0.2));
    });

    test('a release tagged something unparseable is ignored, not crashed on',
        () {
      expect(UpdateChecker.parse(releaseJson(tag: 'nightly')), isNull);
      expect(UpdateChecker.parse('not json at all'), isNull);
    });

    test('survives a release with no assets', () {
      final r = UpdateChecker.parse(releaseJson(tag: 'v1.0.0', assetNames: []))!;
      expect(r.assets, isEmpty);
      expect(r.assetForAbis(const ['arm64-v8a']), isNull);
    });
  });

  group('picking the build for this phone', () {
    final release = UpdateChecker.parse(releaseJson(tag: 'v1.1.0'))!;

    test('takes the first ABI the phone prefers', () {
      // A Pixel 6 reports arm64 first, then the 32-bit fallback.
      final a = release.assetForAbis(const ['arm64-v8a', 'armeabi-v7a']);
      expect(a!.name, contains('arm64-v8a'));
    });

    test('falls back to the 32-bit build on an older phone', () {
      final a = release.assetForAbis(const ['armeabi-v7a']);
      expect(a!.name, contains('armeabi-v7a'));
    });

    test('takes a universal APK when no split matches', () {
      final r = UpdateChecker.parse(
        releaseJson(tag: 'v1.1.0', assetNames: ['jk-bms-plus.apk']),
      )!;
      expect(r.assetForAbis(const ['arm64-v8a'])!.name, 'jk-bms-plus.apk');
    });

    test('refuses to hand over a build for another architecture', () {
      // Installing this would fail with an error that explains nothing, so
      // saying "no build for your phone" is the more useful answer.
      final r = UpdateChecker.parse(
        releaseJson(tag: 'v1.1.0', assetNames: ['jk-bms-plus-x86_64.apk']),
      )!;
      expect(r.assetForAbis(const ['arm64-v8a', 'armeabi-v7a']), isNull);
    });

    test('ignores attachments that are not packages', () {
      final r = UpdateChecker.parse(
        releaseJson(
          tag: 'v1.1.0',
          assetNames: ['checksums-arm64-v8a.txt', 'app-arm64-v8a.apk'],
        ),
      )!;
      expect(r.assetForAbis(const ['arm64-v8a'])!.name, endsWith('.apk'));
    });
  });

  group('UpdateChecker', () {
    UpdateChecker checkerReturning(String body, {List<Uri>? seen}) =>
        UpdateChecker(
          owner: 'owner',
          repo: 'repo',
          fetcher: (uri, headers) async {
            seen?.add(uri);
            return body;
          },
        );

    test('offers an update when the release is newer', () async {
      final c = checkerReturning(releaseJson(tag: 'v1.2.0'));
      final result = await c.check(
        current: const AppVersion(1, 1, 0),
        supportedAbis: const ['arm64-v8a'],
      );
      expect(result.status, UpdateStatus.available);
      expect(result.hasUpdate, isTrue);
      expect(result.asset!.name, contains('arm64-v8a'));
    });

    test('says nothing to do when the release matches what is installed',
        () async {
      final c = checkerReturning(releaseJson(tag: 'v1.2.0'));
      final result = await c.check(
        current: const AppVersion(1, 2, 0),
        supportedAbis: const ['arm64-v8a'],
      );
      expect(result.status, UpdateStatus.upToDate);
      expect(result.hasUpdate, isFalse);
    });

    test('never offers to go backwards', () async {
      // Publishing an old release as "latest" by mistake must not downgrade a
      // working install.
      final c = checkerReturning(releaseJson(tag: 'v1.0.0'));
      final result = await c.check(
        current: const AppVersion(1, 5, 0),
        supportedAbis: const ['arm64-v8a'],
      );
      expect(result.status, UpdateStatus.upToDate);
    });

    test('reports a newer release with nothing installable, distinctly',
        () async {
      final c = checkerReturning(
        releaseJson(tag: 'v2.0.0', assetNames: ['sources.zip']),
      );
      final result = await c.check(
        current: const AppVersion(1, 0, 0),
        supportedAbis: const ['arm64-v8a'],
      );
      expect(result.status, UpdateStatus.noAssetForDevice);
      expect(result.release!.tag, 'v2.0.0');
    });

    test('asks the right endpoint', () async {
      final seen = <Uri>[];
      final c = checkerReturning(releaseJson(tag: 'v1.0.0'), seen: seen);
      await c.check(
        current: const AppVersion(1, 0, 0),
        supportedAbis: const ['arm64-v8a'],
      );
      expect(seen.single.host, 'api.github.com');
      expect(seen.single.path, '/repos/owner/repo/releases/latest');
    });

    test('a network failure is reported, not swallowed', () async {
      final c = UpdateChecker(
        owner: 'owner',
        repo: 'repo',
        fetcher: (uri, headers) async => throw const SocketExceptionStub(),
      );
      final result = await c.check(
        current: const AppVersion(1, 0, 0),
        supportedAbis: const ['arm64-v8a'],
      );
      expect(result.status, UpdateStatus.failed);
      expect(result.error, isNotNull);
    });

    test('sends the token when there is one, and no header when there is not',
        () async {
      Map<String, String>? sent;
      final c = UpdateChecker(
        owner: 'owner',
        repo: 'repo',
        fetcher: (uri, headers) async {
          sent = headers;
          return releaseJson(tag: 'v1.0.0');
        },
      );

      await c.check(
        current: const AppVersion(1, 0, 0),
        supportedAbis: const ['arm64-v8a'],
      );
      expect(sent!.containsKey('Authorization'), isFalse);

      await c.check(
        current: const AppVersion(1, 0, 0),
        supportedAbis: const ['arm64-v8a'],
        token: 'ghp_example',
      );
      expect(sent!['Authorization'], 'Bearer ghp_example');
    });
  });
}

/// Stands in for a real socket failure without needing dart:io in the test.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
  @override
  String toString() => 'No internet';
}
