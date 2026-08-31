import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/platform/pack_widget.dart';
import 'package:jk_bms/src/platform/widget_publisher.dart';

const strings = PackWidgetStrings(
  justNow: 'ahora',
  minutesAgo: _min,
  hoursAgo: _hours,
  daysAgo: _days,
);

String _min(int n) => 'hace $n min';
String _hours(int n) => 'hace $n h';
String _days(int n) => 'hace $n d';

void main() {
  final now = DateTime.utc(2026, 8, 31, 12);

  group('what the widget says', () {
    test('carries the pack, the charge and how old the reading is', () {
      final c = PackWidgetContent.from(
        packName: 'KevinJK',
        soc: 78.4,
        readingAt: now.subtract(const Duration(minutes: 30)),
        now: now,
        rangeKm: 62.3,
        strings: strings,
      );

      expect(c.packName, 'KevinJK');
      expect(c.soc, '78');
      expect(c.range, '62 km');
      expect(c.age, 'hace 30 min');
    });

    test('never leaves the age blank when there is a reading', () {
      // The whole risk with a widget on an app that is connected for a few
      // minutes a day: a percentage with no timestamp reads as live.
      for (final gap in [
        Duration.zero,
        const Duration(minutes: 45),
        const Duration(hours: 20),
        const Duration(days: 9),
      ]) {
        final c = PackWidgetContent.from(
          packName: 'p',
          soc: 50,
          readingAt: now.subtract(gap),
          now: now,
          strings: strings,
        );
        expect(c.age, isNotEmpty);
      }
    });

    test('quotes no range until one has been learned', () {
      // A range guessed from a default consumption would look exactly like one
      // the app had earned from real rides.
      final c = PackWidgetContent.from(
        packName: 'p',
        soc: 50,
        readingAt: now,
        now: now,
        strings: strings,
      );
      expect(c.range, isEmpty);
    });
  });

  group('how old, in words', () {
    String age(Duration gap) => PackWidgetContent.ageLabel(
          readingAt: now.subtract(gap),
          now: now,
          strings: strings,
        );

    test('a fresh reading', () {
      expect(age(Duration.zero), 'ahora');
      expect(age(const Duration(seconds: 90)), 'ahora');
    });

    test('minutes, then hours, then days', () {
      expect(age(const Duration(minutes: 20)), 'hace 20 min');
      expect(age(const Duration(hours: 5)), 'hace 5 h');
      expect(age(const Duration(hours: 47)), 'hace 47 h');
      expect(age(const Duration(days: 3)), 'hace 3 d');
    });

    test('a clock that went backwards does not print a negative age', () {
      // Phones change timezone and get their clock corrected. "hace -3 h" is
      // the kind of thing that makes somebody distrust the whole screen.
      expect(age(const Duration(hours: -3)), 'ahora');
    });
  });

  group('with nothing ever read', () {
    test('says so rather than showing a zero', () {
      // 0% is a claim about a battery. Dashes are not.
      expect(PackWidgetContent.empty.soc, '--');
      expect(PackWidgetContent.empty.age, isEmpty);
      expect(PackWidgetContent.empty.range, isEmpty);
    });
  });

  group('how often it writes to the home screen', () {
    test('the first reading always goes out', () {
      final p = WidgetPublisher();
      expect(p.shouldPublish(now), isTrue);
    });

    test('holds off inside the gap', () async {
      // Readings arrive at about 1 Hz. Redrawing a home screen widget that
      // often would cost more battery than the link it is reporting on.
      final p = WidgetPublisher(minimumGap: const Duration(minutes: 1));
      await p.publish(PackWidgetContent.empty, now: now);

      expect(p.shouldPublish(now.add(const Duration(seconds: 5))), isFalse);
      expect(p.shouldPublish(now.add(const Duration(seconds: 59))), isFalse);
    });

    test('writes again once the gap has passed', () async {
      final p = WidgetPublisher(minimumGap: const Duration(minutes: 1));
      await p.publish(PackWidgetContent.empty, now: now);
      expect(p.shouldPublish(now.add(const Duration(minutes: 1))), isTrue);
    });

    test('an idle pack still refreshes, because the age line moves', () async {
      // Skipping unchanged readings would freeze the widget at 'just now'
      // forever, which is the one thing it must never claim wrongly.
      final p = WidgetPublisher(minimumGap: const Duration(minutes: 1));
      await p.publish(PackWidgetContent.empty, now: now);
      expect(p.shouldPublish(now.add(const Duration(minutes: 2))), isTrue);
    });
  });
}
