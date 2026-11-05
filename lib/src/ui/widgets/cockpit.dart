import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

/// Instrument typography without a container or an extra label.
class InstrumentReading extends StatelessWidget {
  const InstrumentReading(
    this.value, {
    this.unit,
    this.size = 32,
    this.color,
    this.alignment = WrapAlignment.start,
    super.key,
  });
  final String value;
  final String? unit;
  final double size;
  final Color? color;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Stack the surrounding layout first, then fit oversized display digits
      // as one reading. A wrapped "12.8 / 0" changes how the value is read.
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: AppTheme.readout(size, color: color),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width = painter.width;
      painter.dispose();
      final fittedSize =
          constraints.maxWidth.isFinite &&
              width > constraints.maxWidth &&
              width > 0
          ? size * math.max(1, constraints.maxWidth - 2) / width
          : size;
      return Wrap(
        alignment: alignment,
        spacing: 5,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          Text(
            value,
            softWrap: false,
            style: AppTheme.readout(fittedSize, color: color),
          ),
          if (unit != null)
            Padding(
              padding: EdgeInsets.only(bottom: size * .09),
              child: Text(
                unit!,
                style: TextStyle(
                  fontSize: math.max(12, math.min(22, size * .28)),
                  color: context.colors.textSecondary,
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// Three slashes are the recurring mark of the R instrument face.
class SportSignature extends StatelessWidget {
  const SportSignature({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 32,
      height: 12,
      child: CustomPaint(painter: _SignaturePainter(context.colors.good)),
    ),
  );
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3;
    for (var i = 0; i < 3; i++) {
      final x = 3.0 + i * 10;
      canvas.drawLine(Offset(x, size.height), Offset(x + 6, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => old.color != color;
}

/// The main instrument earns a panel. Supporting telemetry uses open strips.
class CockpitPanel extends StatelessWidget {
  const CockpitPanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.surfaceRaised,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: context.colors.hairline),
    ),
    child: Padding(padding: padding, child: child),
  );
}

@immutable
class TelemetryDatum {
  const TelemetryDatum(
    this.label,
    this.value, {
    this.unit,
    this.color,
    this.note,
  });
  final String label;
  final String value;
  final String? unit;
  final Color? color;
  final String? note;
}

class TelemetryStrip extends StatelessWidget {
  const TelemetryStrip({
    required this.items,
    this.size = 32,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    super.key,
  });
  final List<TelemetryDatum> items;
  final double size;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => items.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: padding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final large = MediaQuery.textScalerOf(context).scale(16) > 23;
              final columns = large
                  ? 1
                  : math.min(items.length, constraints.maxWidth < 280 ? 2 : 3);
              final width =
                  (constraints.maxWidth - 16 * (columns - 1)) / columns;
              return DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: context.colors.hairline),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 18,
                    children: [
                      for (final item in items)
                        SizedBox(
                          width: width,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 7),
                              InstrumentReading(
                                item.value,
                                unit: item.unit,
                                size: size,
                                color: item.color,
                              ),
                              if (item.note != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  item.note!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
}

class RidingSpeedometer extends StatelessWidget {
  const RidingSpeedometer({
    required this.value,
    this.available = true,
    super.key,
  });
  final String value;
  final bool available;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: CustomPaint(
      painter: _SpeedWings(context.colors.good.withValues(alpha: .36)),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            InstrumentReading(
              value,
              alignment: WrapAlignment.center,
              size: 158,
              color: available
                  ? context.colors.textPrimary
                  : context.colors.textSecondary,
            ),
            const SizedBox(height: 2),
            Text(
              'km/h · GPS',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.2,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SpeedWings extends CustomPainter {
  const _SpeedWings(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    for (final flip in [false, true]) {
      canvas.save();
      if (flip) {
        canvas.translate(size.width, 0);
        canvas.scale(-1, 1);
      }
      for (var i = 0; i < 3; i++) {
        final offset = i * 8.0;
        canvas.drawPath(
          Path()
            ..moveTo(0, size.height * .79 - offset)
            ..lineTo(size.width * .10, size.height * .74 - offset)
            ..lineTo(size.width * .17, size.height * .22 - offset),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SpeedWings old) => old.color != color;
}

class ChargeJourney extends StatelessWidget {
  const ChargeJourney({
    required this.startLabel,
    required this.endLabel,
    required this.start,
    required this.end,
    super.key,
  });
  final String startLabel, endLabel, start, end;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 16),
    child: LayoutBuilder(
      builder: (context, constraints) {
        Widget endpoint(String label, String value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            InstrumentReading(
              value,
              unit: '%',
              size: 44,
              color: context.colors.good,
            ),
          ],
        );
        if (MediaQuery.textScalerOf(context).scale(16) > 23) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              endpoint(startLabel, start),
              const SizedBox(height: 12),
              endpoint(endLabel, end),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: endpoint(startLabel, start)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Icon(
                Icons.east,
                size: 24,
                color: context.colors.textSecondary,
              ),
            ),
            Expanded(child: endpoint(endLabel, end)),
          ],
        );
      },
    ),
  );
}
