import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The charge gauge: a thick arc that reads at a glance from a phone mount.
///
/// An arc rather than a bar because peripheral vision reads a filled angle far
/// faster than it reads a number, and this is the one figure you glance at
/// while moving.
class SocGauge extends StatelessWidget {
  const SocGauge({
    required this.soc,
    required this.color,
    required this.centreLabel,
    required this.centreValue,
    this.subtitle,
    this.size = 180,
    super.key,
  });

  /// 0 to 100.
  final double soc;
  final Color color;
  final String centreLabel;
  final String centreValue;
  final String? subtitle;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.78,
      child: CustomPaint(
        painter: _ArcPainter(fraction: (soc / 100).clamp(0.0, 1.0), color: color),
        child: Padding(
          padding: EdgeInsets.only(top: size * 0.20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centreValue,
                style: AppTheme.readout(size * 0.30, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                centreLabel.toUpperCase(),
                style: AppTheme.caption(context),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textFaint,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  /// Leaves a gap at the bottom so the arc reads as a dial, not a ring.
  static const double _startAngle = math.pi * 0.78;
  static const double _sweep = math.pi * 1.44;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.075;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.width - stroke,
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.surfaceHigh;

    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(rect, _startAngle, _sweep, false, track);
    if (fraction > 0.005) {
      canvas.drawArc(rect, _startAngle, _sweep * fraction, false, fill);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.fraction != fraction || old.color != color;
}

/// A compact line of recent values, for showing shape rather than magnitude.
class Sparkline extends StatelessWidget {
  const Sparkline({
    required this.values,
    required this.color,
    this.height = 44,
    this.fillBelow = true,
    this.baselineAtZero = true,
    super.key,
  });

  final List<double> values;
  final Color color;
  final double height;
  final bool fillBelow;

  /// When true the vertical scale includes zero, so a line hovering just above
  /// nothing does not get stretched into looking dramatic.
  final bool baselineAtZero;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          color: color,
          fillBelow: fillBelow,
          baselineAtZero: baselineAtZero,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.fillBelow,
    required this.baselineAtZero,
  });

  final List<double> values;
  final Color color;
  final bool fillBelow;
  final bool baselineAtZero;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    var minV = values.reduce(math.min);
    var maxV = values.reduce(math.max);
    if (baselineAtZero) {
      minV = math.min(minV, 0);
      maxV = math.max(maxV, 0);
    }
    if ((maxV - minV).abs() < 1e-9) {
      minV -= 1;
      maxV += 1;
    }

    double y(double v) =>
        size.height - ((v - minV) / (maxV - minV)) * size.height;
    double x(int i) => i / (values.length - 1) * size.width;

    final path = Path()..moveTo(x(0), y(values.first));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i]));
    }

    if (fillBelow) {
      final area = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.28),
              color.withValues(alpha: 0.0),
            ],
          ).createShader(Offset.zero & size),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}

/// One cell as a tile: number, voltage, and a bar showing how far it sits from
/// the pack average.
class CellTile extends StatelessWidget {
  const CellTile({
    required this.index,
    required this.voltage,
    required this.deviation,
    required this.color,
    required this.balancing,
    required this.isExtreme,
    this.resistance,
    super.key,
  });

  final int index;
  final double voltage;

  /// Volts away from the pack average, signed.
  final double deviation;
  final Color color;
  final bool balancing;

  /// True for the highest and lowest cells.
  final bool isExtreme;
  final double? resistance;

  /// Full deflection of the deviation bar.
  static const double fullScale = 0.050;

  @override
  Widget build(BuildContext context) {
    final fraction = (deviation / fullScale).clamp(-1.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
      decoration: BoxDecoration(
        // A cell being balanced is a thing happening, not a thing wrong, so it
        // gets its own tint rather than borrowing the warning colours.
        color: balancing
            ? AppTheme.cool.withValues(alpha: 0.13)
            : AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: balancing
              ? AppTheme.cool.withValues(alpha: 0.7)
              : isExtreme
                  ? color.withValues(alpha: 0.6)
                  : AppTheme.hairline,
          width: balancing || isExtreme ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                '$index',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textFaint,
                  fontFeatures: AppTheme.tabular,
                ),
              ),
              const Spacer(),
              if (balancing)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: AppTheme.cool,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bolt,
                    size: 9,
                    color: AppTheme.ink,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            voltage.toStringAsFixed(3),
            style: TextStyle(
              fontSize: 16,
              height: 1.0,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
              color: color,
              fontFeatures: AppTheme.tabular,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 4,
            child: CustomPaint(
              painter: _DeviationBar(fraction: fraction, color: color),
              size: Size.infinite,
            ),
          ),
          if (resistance != null) ...[
            const SizedBox(height: 5),
            Text(
              '${(resistance! * 1000).toStringAsFixed(1)} mΩ',
              style: const TextStyle(
                fontSize: 9.5,
                color: AppTheme.textFaint,
                fontFeatures: AppTheme.tabular,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeviationBar extends CustomPainter {
  _DeviationBar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = AppTheme.surfaceHigh,
    );

    final centre = size.width / 2;
    final extent = centre * fraction.abs();
    if (extent > 0.4) {
      final rect = fraction >= 0
          ? Rect.fromLTWH(centre, 0, extent, size.height)
          : Rect.fromLTWH(centre - extent, 0, extent, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()..color = color,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(centre - 0.5, 0, 1, size.height),
      Paint()..color = AppTheme.textFaint.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_DeviationBar old) =>
      old.fraction != fraction || old.color != color;
}
