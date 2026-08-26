// Draws the app icon. Run with:
//
//   dart run tool/generate_icon.dart && dart run flutter_launcher_icons
//
// The mark is the app in one glyph: a row of cell bars at slightly different
// heights, with one cell out of line in amber. That is the thing this app
// exists to show you, and it stays readable down to 48 dp where a battery
// outline would turn to mush.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart';

const _size = 1024;

// Matches the app's seed colour and dark surface.
final _background = ColorRgb8(0x08, 0x0A, 0x0F);
final _healthy = ColorRgb8(0x4C, 0x9A, 0xFF);
final _weak = ColorRgb8(0xF5, 0xA6, 0x23);
final _baseline = ColorRgb8(0x27, 0x2F, 0x3D);

/// Bar heights as a fraction of the tallest, and which one is the odd cell out.
const _heights = <double>[0.72, 0.86, 0.94, 0.55, 0.80];
const _weakIndex = 3;

void main() {
  Directory('assets/icon').createSync(recursive: true);

  // Full-bleed icon: legacy Android launchers and iOS.
  final full = Image(width: _size, height: _size, numChannels: 4);
  fill(full, color: _background);
  _drawBars(full, boxSize: (_size * 0.62).round());
  File('assets/icon/icon.png').writeAsBytesSync(encodePng(full));

  // Adaptive foreground: Android masks this and can crop to the centre 66%,
  // so the mark has to sit well inside that.
  final foreground = Image(width: _size, height: _size, numChannels: 4);
  fill(foreground, color: ColorRgba8(0, 0, 0, 0));
  _drawBars(foreground, boxSize: (_size * 0.52).round());
  File('assets/icon/icon_foreground.png').writeAsBytesSync(
    encodePng(foreground),
  );

  stdout.writeln('Wrote assets/icon/icon.png and icon_foreground.png');
}

void _drawBars(Image image, {required int boxSize}) {
  final left = (_size - boxSize) ~/ 2;
  final top = (_size - boxSize) ~/ 2;
  final bottom = top + boxSize;

  final gap = (boxSize * 0.055).round();
  final barWidth =
      ((boxSize - gap * (_heights.length - 1)) / _heights.length).floor();
  final radius = (barWidth * 0.34).round();

  // A baseline under the bars, so the shorter cell reads as short rather than
  // as floating.
  final baselineHeight = math.max(2, (boxSize * 0.05).round());
  _roundedBar(
    image,
    x: left,
    y: bottom - baselineHeight,
    width: boxSize,
    height: baselineHeight,
    radius: baselineHeight ~/ 2,
    color: _baseline,
  );

  // Bars sit directly on the baseline so the short cell reads as short.
  final maxBarHeight = (bottom - baselineHeight) - top;

  for (var i = 0; i < _heights.length; i++) {
    final height = (maxBarHeight * _heights[i]).round();
    final x = left + i * (barWidth + gap);
    final y = bottom - baselineHeight - height;
    final isWeak = i == _weakIndex;

    _roundedBar(
      image,
      x: x,
      y: y,
      width: barWidth,
      height: height,
      radius: radius,
      color: isWeak ? _weak : _healthy,
    );
  }
}

/// Filled rectangle with rounded corners, drawn by hand because the image
/// package has no rounded-rect primitive.
void _roundedBar(
  Image image, {
  required int x,
  required int y,
  required int width,
  required int height,
  required int radius,
  required Color color,
}) {
  final r = math.min(radius, math.min(width, height) ~/ 2);

  for (var py = y; py < y + height; py++) {
    for (var px = x; px < x + width; px++) {
      if (!_insideRounded(px - x, py - y, width, height, r)) continue;
      if (px < 0 || py < 0 || px >= image.width || py >= image.height) continue;
      image.setPixel(px, py, color);
    }
  }
}

bool _insideRounded(int px, int py, int width, int height, int r) {
  if (r <= 0) return true;

  final nearLeft = px < r;
  final nearRight = px >= width - r;
  final nearTop = py < r;
  final nearBottom = py >= height - r;

  if (!(nearLeft || nearRight) || !(nearTop || nearBottom)) return true;

  final cx = nearLeft ? r : width - r - 1;
  final cy = nearTop ? r : height - r - 1;
  final dx = px - cx;
  final dy = py - cy;
  return dx * dx + dy * dy <= r * r;
}
