import 'package:home_widget/home_widget.dart';

import 'pack_widget.dart';

/// Pushes what the widget shows onto the home screen.
///
/// Throttled, because readings arrive at about 1 Hz and a home screen widget
/// redrawn once a second would cost more battery than the Bluetooth link it is
/// reporting on. The widget is glanced at; a minute-old number on it is
/// indistinguishable from a live one, and it carries its own age anyway.
class WidgetPublisher {
  WidgetPublisher({this.minimumGap = const Duration(minutes: 1)});

  final Duration minimumGap;

  static const _androidName = 'PackWidgetProvider';

  DateTime? _lastPush;
  PackWidgetContent? _lastContent;

  /// The last thing written, so a caller can tell whether the home screen is
  /// already showing this.
  PackWidgetContent? get lastPublished => _lastContent;

  /// Whether enough time has passed to write again.
  ///
  /// Purely the clock. It is tempting to also skip writes when the reading has
  /// not changed, but the age line changes on its own, so an idle pack still
  /// needs refreshing and "unchanged" would freeze it at "just now" forever.
  bool shouldPublish(DateTime at) {
    final last = _lastPush;
    return last == null || at.difference(last) >= minimumGap;
  }

  /// Writes [content] out, unless it was written too recently.
  ///
  /// Returns whether it actually pushed, which is what the tests assert on.
  Future<bool> publish(PackWidgetContent content, {DateTime? now}) async {
    final at = now ?? DateTime.now().toUtc();
    if (!shouldPublish(at)) return false;

    _lastPush = at;
    _lastContent = content;
    await _write(content);
    return true;
  }

  /// Writes immediately, for the moments where waiting is wrong: the app
  /// closing, or a pack being disconnected.
  Future<void> publishNow(PackWidgetContent content, {DateTime? now}) async {
    _lastPush = now ?? DateTime.now().toUtc();
    _lastContent = content;
    await _write(content);
  }

  Future<void> _write(PackWidgetContent content) async {
    try {
      for (final entry in content.toData().entries) {
        await HomeWidget.saveWidgetData<String>(entry.key, entry.value);
      }
      await HomeWidget.updateWidget(name: _androidName);
    } on Object catch (_) {
      // No widget on the home screen, or no platform at all. Neither is worth
      // interrupting anything over.
    }
  }
}
