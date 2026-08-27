import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';

void main() {
  group('knowing when a scan is over', () {
    test('the flag reported on subscribe does not end the scan', () {
      // FlutterBluePlus.isScanning hands you its current value the moment you
      // listen, and that value is false because the scan has not begun. Acting
      // on it would end the search before it started.
      final life = ScanLifecycle();
      expect(life.onScanningChanged(scanning: false), isFalse);
      expect(life.finished, isFalse);
    });

    test('the radio stopping ends it', () {
      final life = ScanLifecycle();
      life.onScanningChanged(scanning: false); // the subscribe echo
      expect(life.onScanningChanged(scanning: true), isFalse);
      expect(life.started, isTrue);

      // This is the transition that was never being acted on. Without it the
      // stream stayed open, onDone never fired, and the screen said
      // "searching" forever over a scan that had already stopped.
      expect(life.onScanningChanged(scanning: true), isFalse);
      expect(life.onScanningChanged(scanning: false), isTrue);
      expect(life.finished, isTrue);
    });

    test('it ends exactly once', () {
      // finish() cancels subscriptions and closes the controller; running it
      // twice would close an already-closed stream.
      final life = ScanLifecycle();
      life.onScanningChanged(scanning: true);
      expect(life.onScanningChanged(scanning: false), isTrue);
      expect(life.onScanningChanged(scanning: false), isFalse);
      expect(life.onDeadline(), isFalse);
    });

    test('the deadline ends a scan the radio never reported stopping', () {
      // The backstop. A screen stuck on "searching" is worse than one that
      // stops early, so something has to end it even if the flag never comes.
      final life = ScanLifecycle();
      life.onScanningChanged(scanning: true);
      expect(life.onDeadline(), isTrue);
      expect(life.finished, isTrue);
    });

    test('the deadline ends it even if scanning never started', () {
      // startScan throwing lands here: no scan, but the screen still has to
      // stop waiting.
      final life = ScanLifecycle();
      expect(life.onDeadline(), isTrue);
    });

    test('a late flag after the deadline changes nothing', () {
      final life = ScanLifecycle();
      life.onScanningChanged(scanning: true);
      life.onDeadline();
      expect(life.onScanningChanged(scanning: false), isFalse);
    });
  });
}
