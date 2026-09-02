import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/license/device_code.dart';
import 'package:jk_bms/src/license/license_key.dart';
import 'package:jk_bms/src/license/license_payload.dart';
import 'package:jk_bms/src/license/license_verifier.dart';

void main() {
  final device = DeviceCode(const [1, 2, 3, 4, 5, 6, 7, 8]);
  final issued = DateTime.utc(2026, 9, 2, 12, 0, 0);

  group('device code', () {
    test('displays as four groups and reads back to the same bytes', () async {
      final code = await DeviceCode.derive('abc123');
      final shown = code.display;
      expect(
        shown,
        matches(RegExp(r'^[2-9A-HJKMNP-TV-Z]{4}(-[2-9A-HJKMNP-TV-Z]{4}){3}$')),
      );
      expect(DeviceCode.parse(shown), equals(code));
    });

    test('is forgiving about what a person types', () async {
      final code = await DeviceCode.derive('phone-7');
      final shown = code.display;
      // Lower case, spaces instead of dashes, and no separators at all.
      expect(DeviceCode.parse(shown.toLowerCase()), equals(code));
      expect(DeviceCode.parse(shown.replaceAll('-', ' ')), equals(code));
      expect(DeviceCode.parse(shown.replaceAll('-', '')), equals(code));
    });

    test('catches a mistyped symbol', () async {
      final code = await DeviceCode.derive('phone-7');
      final shown = code.display;
      // Flip one symbol to a different valid one; the check should fail.
      final i = shown.indexOf(RegExp(r'[2-9A-Z]'));
      final replacement = shown[i] == 'K' ? 'M' : 'K';
      final bad = shown.replaceRange(i, i + 1, replacement);
      expect(DeviceCode.parse(bad), isNull);
    });

    test(
      'same identifier, same code; different identifier, different code',
      () async {
        expect(
          await DeviceCode.derive('x'),
          equals(await DeviceCode.derive('x')),
        );
        expect(
          await DeviceCode.derive('x'),
          isNot(equals(await DeviceCode.derive('y'))),
        );
      },
    );
  });

  group('payload', () {
    test('round-trips every field', () {
      final p = LicensePayload(
        tier: LicenseTier.workshop,
        deviceCode: device.bytes,
        issuedAt: issued,
        expiresAt: DateTime.utc(2027, 9, 2),
        inspectionCredits: 3,
        certificateCredits: 1,
        label: 'Taller Ñandú',
      );
      final back = LicensePayload.decode(p.encode());
      expect(back.tier, LicenseTier.workshop);
      expect(back.deviceCode, device.bytes);
      expect(back.issuedAt, issued);
      expect(back.expiresAt, DateTime.utc(2027, 9, 2));
      expect(back.inspectionCredits, 3);
      expect(back.certificateCredits, 1);
      expect(back.label, 'Taller Ñandú');
    });

    test('a plain Pro key is 23 bytes with no label', () {
      final p = LicensePayload(
        tier: LicenseTier.pro,
        deviceCode: device.bytes,
        issuedAt: issued,
      );
      expect(p.encode().length, 23);
      expect(LicensePayload.decode(p.encode()).neverExpires, isTrue);
    });

    test('refuses a payload it does not understand', () {
      final p = LicensePayload(
        tier: LicenseTier.pro,
        deviceCode: device.bytes,
        issuedAt: issued,
      ).encode();
      final wrongVersion = List<int>.from(p)..[0] = 2;
      expect(
        () => LicensePayload.decode(wrongVersion),
        throwsA(isA<LicenseFormatException>()),
      );
      final unknownTier = List<int>.from(p)..[1] = 99;
      expect(
        () => LicensePayload.decode(unknownTier),
        throwsA(isA<LicenseFormatException>()),
      );
      expect(
        () => LicensePayload.decode(p.sublist(0, 10)),
        throwsA(isA<LicenseFormatException>()),
      );
    });
  });

  group('key text', () {
    late LicenseSigner signer;
    late LicenseVerifier verifier;

    setUp(() async {
      signer = await LicenseSigner.generate();
      verifier = LicenseVerifier(publicKey: await signer.publicKey);
    });

    LicensePayload pro({
      DateTime? expires,
      LicenseTier tier = LicenseTier.pro,
    }) => LicensePayload(
      tier: tier,
      deviceCode: device.bytes,
      issuedAt: issued,
      expiresAt: expires,
    );

    test('a signed key verifies for its phone', () async {
      final key = await signer.sign(pro());
      final text = key.encode();
      expect(text, startsWith('JKB1.'));
      final check = await verifier.check(text, device: device, now: issued);
      expect(check.accepted, isTrue);
      expect(check.payload!.tier, LicenseTier.pro);
    });

    test('survives being pasted with line breaks and spaces', () async {
      final text = (await signer.sign(pro())).encode();
      final wrapped =
          '${text.substring(0, 30)}\n ${text.substring(30, 70)} \n${text.substring(70)}';
      final check = await verifier.check(wrapped, device: device, now: issued);
      expect(check.accepted, isTrue);
    });

    test('a single changed character is a bad signature, not a key', () async {
      final text = (await signer.sign(pro())).encode();
      // Flip a character inside the payload part.
      final dot = text.indexOf('.') + 3;
      final flipped = text.replaceRange(
        dot,
        dot + 1,
        text[dot] == 'A' ? 'B' : 'A',
      );
      final check = await verifier.check(flipped, device: device, now: issued);
      expect(check.accepted, isFalse);
      expect(
        check.rejection,
        anyOf(LicenseRejection.badSignature, LicenseRejection.malformed),
      );
    });

    test('a key signed by somebody else is refused', () async {
      final impostor = await LicenseSigner.generate();
      final text = (await impostor.sign(pro())).encode();
      final check = await verifier.check(text, device: device, now: issued);
      expect(check.rejection, LicenseRejection.badSignature);
    });

    test('a key for another phone is refused, and says so', () async {
      final text = (await signer.sign(pro())).encode();
      final other = DeviceCode(const [9, 9, 9, 9, 9, 9, 9, 9]);
      final check = await verifier.check(text, device: other, now: issued);
      expect(check.rejection, LicenseRejection.wrongDevice);
    });

    test('an expired workshop key is refused on activation', () async {
      final text = (await signer.sign(
        pro(tier: LicenseTier.workshop, expires: DateTime.utc(2027, 1, 1)),
      )).encode();
      final before = await verifier.check(
        text,
        device: device,
        now: DateTime.utc(2026, 12, 31),
      );
      expect(before.accepted, isTrue);
      final after = await verifier.check(
        text,
        device: device,
        now: DateTime.utc(2027, 1, 1),
      );
      expect(after.rejection, LicenseRejection.expired);
    });

    test('nonsense is malformed, with a reason', () async {
      for (final junk in [
        '',
        'hello',
        'JKB1.abc',
        'JKB1.a.b.c',
        'JKB2.AAAA.BBBB',
      ]) {
        final check = await verifier.check(junk, device: device, now: issued);
        expect(check.rejection, LicenseRejection.malformed, reason: junk);
      }
    });

    test('a Pro key is short enough to type from a photo', () async {
      final text = (await signer.sign(pro())).encode();
      // Prefix, 23-byte payload, 64-byte signature: about 125 characters.
      expect(text.length, lessThan(135));
    });

    test('the key id is stable and distinct per key', () async {
      final a = await signer.sign(pro());
      final b = await signer.sign(pro(expires: DateTime.utc(2030)));
      expect(LicenseKey.parse(a.encode()).id, a.id);
      expect(a.id, isNot(b.id));
    });

    test('an all-zero public key accepts nothing', () async {
      final unset = LicenseVerifier(publicKey: List.filled(32, 0));
      final text = (await signer.sign(pro())).encode();
      final check = await unset.check(text, device: device, now: issued);
      expect(check.accepted, isFalse);
    });
  });
}
