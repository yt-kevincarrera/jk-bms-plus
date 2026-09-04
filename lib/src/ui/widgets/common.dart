import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../model/bms_snapshot.dart';
import '../../model/bms_warning.dart';
import '../theme.dart';

/// How healthy the pack looks at a glance.
enum PackHealth { good, watch, bad }

extension PackHealthColors on PackHealth {
  Color get color => switch (this) {
        PackHealth.good => AppTheme.good,
        PackHealth.watch => AppTheme.watch,
        PackHealth.bad => AppTheme.bad,
      };

  IconData get icon => switch (this) {
        PackHealth.good => Icons.check_circle_outline,
        PackHealth.watch => Icons.error_outline,
        PackHealth.bad => Icons.warning_amber_rounded,
      };
}

/// A caption above a measurement.
class Caption extends StatelessWidget {
  const Caption(this.text, {this.color, super.key});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: AppTheme.caption(context).copyWith(color: color),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
}

/// The main instrument: caption, big number, unit.
class Readout extends StatelessWidget {
  const Readout({
    required this.label,
    required this.value,
    this.unit,
    this.color,
    this.size = 34,
    this.footnote,
    this.align = CrossAxisAlignment.start,
    super.key,
  });

  final String label;
  final String value;
  final String? unit;
  final Color? color;
  final double size;
  final String? footnote;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Caption(label),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: AppTheme.readout(size, color: color)),
            if (unit != null) ...[
              const SizedBox(width: 3),
              Padding(
                padding: EdgeInsets.only(bottom: size * 0.08),
                child: Text(
                  unit!,
                  style: TextStyle(
                    fontSize: math.max(11, size * 0.32),
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (footnote != null) ...[
          const SizedBox(height: 4),
          Text(
            footnote!,
            style: const TextStyle(fontSize: 11, color: AppTheme.textFaint),
          ),
        ],
      ],
    );
  }
}

/// A boxed instrument, for laying several out in a row.
class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.label,
    required this.value,
    this.unit,
    this.color,
    this.footnote,
    super.key,
  });

  final String label;
  final String value;
  final String? unit;
  final Color? color;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 13),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Readout(
        label: label,
        value: value,
        unit: unit,
        color: color,
        size: 26,
        footnote: footnote,
      ),
    );
  }
}

/// Label left, value right, hairline underneath.
class InfoRow extends StatelessWidget {
  const InfoRow(
    this.label,
    this.value, {
    this.dim = false,
    this.valueColor,
    this.hint,
    this.last = false,
    super.key,
  });

  final String label;
  final String value;
  final bool dim;
  final Color? valueColor;

  /// A line of explanation under the row, for numbers that need one.
  final String? hint;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.hairline)),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppTheme.tabular,
                    color: valueColor ??
                        (dim ? AppTheme.textFaint : AppTheme.textPrimary),
                  ),
                ),
              ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 5),
            Text(
              hint!,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: AppTheme.textFaint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A titled block.
class Section extends StatelessWidget {
  const Section({
    required this.title,
    required this.children,
    this.trailing,
    this.intro,
    this.accent,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final String? intro;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.hairline),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Caption(title, color: accent ?? AppTheme.good)),
                ?trailing,
              ],
            ),
            if (intro != null) ...[
              const SizedBox(height: 8),
              Text(
                intro!,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// The one colour that tells you whether to worry, across the top of a screen.
class StatusBand extends StatelessWidget {
  const StatusBand({
    required this.health,
    required this.message,
    this.badge,
    this.explanation,
    super.key,
  });

  final PackHealth health;
  final String message;
  final Widget? badge;

  /// Shown when the band is tapped. A colour nobody can interrogate is a
  /// colour people learn to ignore.
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    final colour = health.color;
    final band = Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colour.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Icon(health.icon, size: 18, color: colour),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colour,
              ),
            ),
          ),
          ?badge,
          if (explanation != null) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.help_outline,
              size: 15,
              color: colour.withValues(alpha: 0.7),
            ),
          ],
        ],
      ),
    );

    if (explanation == null) return band;

    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppTheme.surfaceRaised,
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(health.icon, size: 18, color: colour),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colour,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  explanation!,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      child: band,
    );
  }
}

/// Small pill, for a state word next to a title.
class Pill extends StatelessWidget {
  const Pill(this.text, {this.color = AppTheme.good, this.icon, super.key});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown while no reading has arrived yet.
class WaitingForData extends StatelessWidget {
  const WaitingForData({
    required this.message,
    this.children = const <Widget>[],
    super.key,
  });

  final String message;

  /// What to say under the spinner about why the wait is happening. A spinner
  /// alone is a promise; a spinner with a reason is information.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.goodDim,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Why the pack is being called what it is being called.
enum PackStatusReason {
  /// Nothing is out of line.
  allClear,

  /// The BMS itself raised a fault.
  bmsWarning,

  /// The spread between the highest and lowest cell is wide.
  cellSpread,

  /// Something is too hot.
  temperature,
}

/// The verdict every screen colours itself by, and the reason for it.
///
/// The reason matters as much as the colour. A band that says "watch" without
/// saying what to watch is decoration; one that says "watch — the cells are
/// 66 mV apart" is information, and the rider can act on it or dismiss it.
class PackStatus {
  const PackStatus({
    required this.health,
    required this.reason,
    this.value,
    this.warnings = const [],
  });

  final PackHealth health;
  final PackStatusReason reason;

  /// The number behind the verdict: volts of spread, or degrees.
  final double? value;

  /// The faults the BMS raised, when that is the reason.
  ///
  /// Carried as the enum rather than as text: the names in the protocol tables
  /// are English, and a fault shown to the rider has to be in their language.
  final List<BmsWarning> warnings;
}

/// Judges the pack from one reading.
///
/// Thresholds are deliberately conservative for a 20S NMC pack: a spread over
/// 40 mV is worth a look and over 100 mV means a cell is genuinely misbehaving,
/// while anything the BMS itself flags as a fault jumps straight to red.
///
/// Note what this does *not* consider: charge level. A pack at 8% is not
/// unhealthy, it is empty, and colouring it red would teach you to ignore the
/// colour on every long ride.
PackStatus packStatusOf(BmsSnapshot s) {
  if (s.warnings.hasFault) {
    return PackStatus(
      health: PackHealth.bad,
      reason: PackStatusReason.bmsWarning,
      warnings: s.warnings.faults.toList(),
    );
  }

  final temps = <double>[
    ...s.temperatures,
    if (s.mosfetTemp != null) s.mosfetTemp!,
  ];
  final hottest = temps.isEmpty ? 0.0 : temps.reduce(math.max);

  if (hottest > 55) {
    return PackStatus(
      health: PackHealth.bad,
      reason: PackStatusReason.temperature,
      value: hottest,
    );
  }
  if (s.deltaCellVoltage > 0.10) {
    return PackStatus(
      health: PackHealth.bad,
      reason: PackStatusReason.cellSpread,
      value: s.deltaCellVoltage,
    );
  }
  if (hottest > 45) {
    return PackStatus(
      health: PackHealth.watch,
      reason: PackStatusReason.temperature,
      value: hottest,
    );
  }
  if (s.deltaCellVoltage > 0.04) {
    return PackStatus(
      health: PackHealth.watch,
      reason: PackStatusReason.cellSpread,
      value: s.deltaCellVoltage,
    );
  }
  return const PackStatus(
    health: PackHealth.good,
    reason: PackStatusReason.allClear,
  );
}

/// Convenience for the screens that only need the colour.
PackHealth packHealthOf(BmsSnapshot s) => packStatusOf(s).health;

/// A small stat: number, unit, label, optionally colour-coded.
///
/// The compact alternative to a labelled row. Six of these in a grid say what
/// six paragraphs would, and fit on one screen.
class StatCard extends StatelessWidget {
  const StatCard({
    required this.label,
    required this.value,
    this.unit,
    this.color,
    this.emphasis = false,
    super.key,
  });

  final String label;
  final String value;
  final String? unit;
  final Color? color;

  /// Draws the border in [color] too, for the one or two that matter most.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? AppTheme.textPrimary;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 10, 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: emphasis && color != null
              ? tone.withValues(alpha: 0.45)
              : AppTheme.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.readout(23, color: tone),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(
                  unit!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 11,
              height: 1.25,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Long explanations, folded away until asked for.
///
/// The reasoning behind these numbers matters, but not on every glance. Behind
/// a disclosure it stays available without turning the screen into an essay.
class Explainer extends StatelessWidget {
  const Explainer({required this.title, required this.paragraphs, super.key});

  final String title;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.hairline),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Row(
              children: [
                const Icon(
                  Icons.help_outline,
                  size: 15,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            children: [
              for (final p in paragraphs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    p,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
