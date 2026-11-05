import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';
import 'common.dart';
import 'cockpit.dart';

/// One segment is five percentage points, including a partly filled segment.
class ChargeSegments extends StatelessWidget {
  const ChargeSegments({required this.soc, required this.label, super.key});
  final double soc;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    value: '${soc.toStringAsFixed(0)} %',
    child: SizedBox(
      height: 19,
      width: double.infinity,
      child: CustomPaint(
        painter: _ChargePainter(
          fraction: soc.isFinite ? (soc / 100).clamp(0.0, 1.0) : 0,
          fill: context.colors.good,
          track: context.colors.hairline,
        ),
      ),
    ),
  );
}

class _ChargePainter extends CustomPainter {
  const _ChargePainter({
    required this.fraction,
    required this.fill,
    required this.track,
  });
  final double fraction;
  final Color fill;
  final Color track;
  @override
  void paint(Canvas canvas, Size size) {
    const count = 20;
    final step = size.width / count;
    final slant = math.min(7.0, step * 0.4);
    for (var i = 0; i < count; i++) {
      final x = i * step;
      final width = math.max(1.0, step - 3);
      final path = Path()
        ..moveTo(x + slant, 1)
        ..lineTo(x + width, 1)
        ..lineTo(x + width - slant, size.height - 1)
        ..lineTo(x, size.height - 1)
        ..close();
      canvas.drawPath(path, Paint()..color = track);
      final part = (fraction * count - i).clamp(0.0, 1.0);
      if (part > 0) {
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(x, 0, width * part, size.height));
        canvas.drawPath(path, Paint()..color = fill);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_ChargePainter old) =>
      old.fraction != fraction || old.fill != fill || old.track != track;
}

/// Current range is deliberately kept separate from the full-pack estimate.
class RangeInstrument extends StatelessWidget {
  const RangeInstrument({
    required this.rangeLabel,
    required this.rangeValue,
    required this.soc,
    required this.socLabel,
    required this.band,
    required this.capacity,
    this.note,
    super.key,
  });
  final String rangeLabel;
  final String rangeValue;
  final double soc;
  final String socLabel;
  final String band;
  final String capacity;
  final String? note;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: CockpitPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack =
              constraints.maxWidth < 260 ||
              MediaQuery.textScalerOf(context).scale(16) > 23;
          final range = InstrumentReading(
            rangeValue,
            unit: 'km',
            size: stack ? 100 : 130,
          );
          final charge = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Caption(socLabel),
              const SizedBox(height: 6),
              InstrumentReading(
                soc.toStringAsFixed(0),
                unit: '%',
                size: 38,
                color: context.colors.good,
              ),
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Caption(rangeLabel)),
                  const SportSignature(),
                ],
              ),
              const SizedBox(height: 18),
              ChargeSegments(soc: soc, label: socLabel),
              const SizedBox(height: 12),
              if (stack) ...[
                range,
                const SizedBox(height: 8),
                charge,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 3, child: range),
                    Container(
                      width: 1,
                      height: 64,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      color: context.colors.hairline,
                    ),
                    Expanded(child: charge),
                  ],
                ),
              const SizedBox(height: 8),
              Text(
                band,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: context.colors.hairline),
              const SizedBox(height: 12),
              Text(
                capacity,
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                ),
              ),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    note!,
                    style: TextStyle(fontSize: 13, color: context.colors.watch),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class TripInstruments extends StatelessWidget {
  const TripInstruments({
    required this.distance,
    required this.distanceLabel,
    required this.consumption,
    required this.consumptionLabel,
    super.key,
  });
  final String distance;
  final String distanceLabel;
  final String consumption;
  final String consumptionLabel;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final stack = MediaQuery.textScalerOf(context).scale(16) > 23;
        final metrics = [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Caption(distanceLabel),
              const SizedBox(height: 8),
              InstrumentReading(distance, unit: 'km', size: 86),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Caption(consumptionLabel),
              const SizedBox(height: 8),
              InstrumentReading(
                consumption,
                unit: 'Wh/km',
                size: 34,
                color: context.colors.good,
              ),
            ],
          ),
        ];
        return stack
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [metrics[0], const SizedBox(height: 10), metrics[1]],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: metrics[0]),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: metrics[1]),
                ],
              );
      },
    ),
  );
}
