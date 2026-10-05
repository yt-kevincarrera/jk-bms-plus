import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards a plugin option whose name hides what it does.
///
/// `stopWithTask: true` in flutter_foreground_task's options also makes the
/// plugin stop the service whenever no activity is resumed: every screen off,
/// every switch to the music player, every pocket. 2.28.0 shipped it, and
/// rides recorded 0 km because Android stops the GPS for a backgrounded app
/// with no service. Neither the option nor its effect can be exercised off a
/// device, so the source is what gets checked.
void main() {
  test('the Dart options never ask the plugin to stop with the task', () {
    final source =
        File('lib/src/platform/live_notification.dart').readAsStringSync();
    expect(
      RegExp(r'^\s*stopWithTask\s*:', multiLine: true).hasMatch(source),
      isFalse,
    );
  });

  test('nor does the manifest', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, isNot(contains('android:stopWithTask="true"')));
  });
}
