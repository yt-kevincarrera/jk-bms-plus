import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';

DiscoveredBms seen(
  String name, {
  String id = 'AA:BB:CC:DD:EE:FF',
  int rssi = -60,
  List<String> services = const [],
}) =>
    classifyAdvertisement(
      id: id,
      name: name,
      rssi: rssi,
      serviceUuids: services,
    );

void main() {
  group('deciding what a scan result is', () {
    test('the JK service UUID in the advertisement is the strongest signal',
        () {
      final d = seen('', services: ['0000ffe0-0000-1000-8000-00805f9b34fb']);
      expect(d.advertisesJkService, isTrue);
      expect(d.likelyBms, isTrue);
    });

    test('a JK-ish name counts, on its own', () {
      expect(seen('JK-B2A24S15P').nameLooksLikeJk, isTrue);
      expect(seen('jk_bms').nameLooksLikeJk, isTrue);
      expect(seen('JK-B2A24S15P').likelyBms, isTrue);
    });

    test('a device with neither marker is still reported', () {
      // This is the regression. The scan used to `continue` past anything that
      // failed both checks, so a BMS renamed in the official app -- or one
      // whose firmware advertises no service UUID -- was found by the radio,
      // thrown away, and the rider was shown an empty list. An absent pack and
      // a filtered one looked identical.
      final d = seen('Moto Kevin');
      expect(d.likelyBms, isFalse);
      // Reported anyway, with everything needed to connect to it.
      expect(d.id, 'AA:BB:CC:DD:EE:FF');
      expect(d.name, 'Moto Kevin');
    });

    test('an advertisement with no name at all is still reported', () {
      // Common: platformName is empty until the phone has bonded with the
      // device, so a never-connected BMS can advertise nothing but its address.
      final d = seen('');
      expect(d.likelyBms, isFalse);
      expect(d.id, isNotEmpty);
    });

    test('another vendor\'s service UUID is not mistaken for JK\'s', () {
      final d = seen('Speaker', services: ['0000180f-0000-1000-8000-00805f9b34fb']);
      expect(d.advertisesJkService, isFalse);
      expect(d.likelyBms, isFalse);
    });
  });

  group('ordering what was found', () {
    test('likely packs come before everything else', () {
      final list = [
        seen('Headphones', id: '1', rssi: -40),
        seen('JK-B2A24S15P', id: '2', rssi: -80),
      ]..sort(compareDiscovered);

      // Even though the headphones are much closer.
      expect(list.first.name, 'JK-B2A24S15P');
    });

    test('the service UUID outranks a matching name', () {
      final list = [
        seen('JK-something', id: '1', rssi: -50),
        seen('Renamed', id: '2', rssi: -70, services: ['ffe0']),
      ]..sort(compareDiscovered);

      expect(list.first.id, '2');
    });

    test('among equals, the closest comes first', () {
      final list = [
        seen('Far', id: '1', rssi: -90),
        seen('Near', id: '2', rssi: -45),
        seen('Middle', id: '3', rssi: -70),
      ]..sort(compareDiscovered);

      expect(list.map((d) => d.name), ['Near', 'Middle', 'Far']);
    });

    test('unlikely devices are ordered, not dropped', () {
      final list = [
        seen('TV', id: '1', rssi: -75),
        seen('JK-BMS', id: '2', rssi: -60),
        seen('Watch', id: '3', rssi: -50),
      ]..sort(compareDiscovered);

      expect(list, hasLength(3));
      expect(list.first.name, 'JK-BMS');
      // And the rest stay reachable, closest first.
      expect(list[1].name, 'Watch');
      expect(list[2].name, 'TV');
    });
  });
}
