/// What the home screen widget should say, given what is stored.
///
/// Pure, and separate from the plugin call, so the decisions can be tested:
/// which pack to show, whether a range is worth quoting, and how to phrase the
/// age of a reading. Those are the parts that can be wrong in a way nobody
/// notices, because a widget is glanced at rather than read.
class PackWidgetContent {
  const PackWidgetContent({
    required this.packName,
    required this.soc,
    required this.range,
    required this.age,
  });

  final String packName;
  final String soc;
  final String range;

  /// How long ago the reading is. Never empty when there is a reading: a
  /// charge percentage with no timestamp reads as live, and the app is
  /// connected for a few minutes a day.
  final String age;

  /// Nothing has ever been read.
  static const PackWidgetContent empty = PackWidgetContent(
    packName: '',
    soc: '--',
    range: '',
    age: '',
  );

  Map<String, String> toData() => {
        'pack_name': packName,
        'soc': soc,
        'range': range,
        'age': age,
      };

  /// Builds the content from a reading.
  ///
  /// [rangeKm] is quoted only when the app has actually learned a consumption
  /// figure for this pack. A range guessed from a default Wh/km on the home
  /// screen would be indistinguishable from one it had earned.
  static PackWidgetContent from({
    required String packName,
    required double soc,
    required DateTime readingAt,
    required DateTime now,
    double? rangeKm,
    required PackWidgetStrings strings,
  }) {
    return PackWidgetContent(
      packName: packName,
      soc: soc.toStringAsFixed(0),
      range: rangeKm == null ? '' : '${rangeKm.toStringAsFixed(0)} km',
      age: ageLabel(readingAt: readingAt, now: now, strings: strings),
    );
  }

  /// "just now", "3 h", "2 d". Coarse on purpose: the exact minute does not
  /// change what anybody does, and the only distinction that matters is
  /// whether the number can still be trusted.
  static String ageLabel({
    required DateTime readingAt,
    required DateTime now,
    required PackWidgetStrings strings,
  }) {
    final gap = now.difference(readingAt);
    if (gap.isNegative || gap.inMinutes < 2) return strings.justNow;
    if (gap.inMinutes < 60) return strings.minutesAgo(gap.inMinutes);
    if (gap.inHours < 48) return strings.hoursAgo(gap.inHours);
    return strings.daysAgo(gap.inDays);
  }
}

/// The words, injected so the pure part stays free of Flutter localisations.
class PackWidgetStrings {
  const PackWidgetStrings({
    required this.justNow,
    required this.minutesAgo,
    required this.hoursAgo,
    required this.daysAgo,
  });

  final String justNow;
  final String Function(int) minutesAgo;
  final String Function(int) hoursAgo;
  final String Function(int) daysAgo;
}
