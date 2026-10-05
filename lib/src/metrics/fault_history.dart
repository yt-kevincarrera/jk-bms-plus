import '../model/bms_warning.dart';

/// One stored reading at which the BMS's warning bits changed, or after a
/// silence long enough to matter. See [AppDatabase.warningTransitions].
///
/// [index] is the reading's position in the pack's whole history, oldest
/// first, so the number of readings between two transitions is the
/// difference of their indexes: everything between them carried the earlier
/// one's mask, or it would have been a transition itself.
class WarningTransition {
  const WarningTransition({
    required this.index,
    required this.at,
    required this.mask,
    required this.previousMask,
    required this.previousAt,
    required this.current,
    required this.soc,
    required this.maxCellVoltage,
    required this.minCellVoltage,
  });

  final int index;
  final DateTime at;
  final int mask;

  /// The reading just before this one, or null for the first reading.
  final int? previousMask;
  final DateTime? previousAt;

  final double current;
  final double soc;
  final double maxCellVoltage;
  final double minCellVoltage;
}

/// One stretch during which the BMS held one warning bit.
class FaultEpisode {
  const FaultEpisode({
    required this.bit,
    required this.start,
    required this.end,
    required this.readings,
    required this.unobservedGap,
    required this.ongoing,
    required this.current,
    required this.soc,
    required this.maxCellVoltage,
    required this.minCellVoltage,
  });

  /// The bit in the BMS's warning mask.
  final int bit;

  /// The first and last readings that carried it. Not when the BMS raised
  /// and cleared it: only when this app saw it.
  final DateTime start;
  final DateTime end;

  /// How many stored readings carried it.
  final int readings;

  /// True when the link was out for more than [FaultHistory.noDataGap]
  /// inside the episode or at either edge of it, so it may have started
  /// earlier, ended later, or come and gone in between without anybody
  /// seeing.
  final bool unobservedGap;

  /// True when the newest stored reading still carried it.
  final bool ongoing;

  /// What the pack was doing in the first reading that carried it.
  final double current;
  final double soc;
  final double maxCellVoltage;
  final double minCellVoltage;

  Duration get duration => end.difference(start);

  /// The named warning, or null for a bit the reference has no name for.
  BmsWarning? get warning {
    for (final w in BmsWarning.values) {
      if (w.bit == bit) return w;
    }
    return null;
  }
}

/// Turns the BMS's warning mask, as stored with every reading, into
/// episodes: one per bit per stretch it was held.
///
/// The mask has been written with every reading since the first version and
/// read only by the backup and the CSV export. A fault the BMS raised for
/// ten seconds on a hill last Tuesday is in there, and nothing could show it.
///
/// Two rules decide where one episode ends and the next begins:
///
///  * readings that carry the bit with fewer than [mergeWithin] between them
///    are one episode, even with readings that do not carry it in between.
///    A BMS that flickers a protection on and off for a minute raised one
///    fault, not thirty;
///  * a stretch with no readings at all ends nothing by itself. The link
///    drops for long stretches on a moving bike, and a fault on both sides of
///    a silence is far more likely to have stayed than to have cleared and
///    come back. When that silence is longer than [noDataGap], the episode
///    says so ([FaultEpisode.unobservedGap]), because then nobody knows.
///
/// "Battery fully charged" is not a fault and is left out.
class FaultHistory {
  const FaultHistory._();

  static const Duration mergeWithin = Duration(seconds: 30);
  static const Duration noDataGap = Duration(minutes: 5);

  /// [transitions] oldest first. [totalReadings] is how many readings the
  /// pack has in all and [lastAt] when the newest was taken, which together
  /// close whatever the last transition left open. Newest episode first.
  static List<FaultEpisode> episodes(
    List<WarningTransition> transitions, {
    required int totalReadings,
    required DateTime? lastAt,
  }) {
    final open = <int, _Episode>{};
    final pending = <int, _Episode>{};
    final done = <_Episode>[];
    WarningTransition? last;

    for (final r in transitions) {
      final before = r.previousMask ?? 0;
      final previousAt = r.previousAt;
      final silence = previousAt == null ? null : r.at.difference(previousAt);
      final unobserved = silence != null && silence > noDataGap;

      // Every reading from the last transition up to this one carried the
      // last transition's mask.
      if (last != null) {
        for (final b in _bits(last.mask)) {
          open[b]?.readings += r.index - last.index;
        }
      }
      for (final b in _bits(before)) {
        if (previousAt != null) open[b]?.end = previousAt;
      }
      for (final b in _bits(before & r.mask)) {
        if (unobserved) open[b]?.unobservedGap = true;
      }
      for (final b in _bits(before & ~r.mask)) {
        final e = open.remove(b);
        if (e == null) continue;
        if (unobserved) e.unobservedGap = true;
        final stale = pending.remove(b);
        if (stale != null) done.add(stale);
        pending[b] = e;
      }
      for (final b in _bits(r.mask & ~before)) {
        final held = pending.remove(b);
        if (held != null && r.at.difference(held.end) < mergeWithin) {
          open[b] = held;
          continue;
        }
        if (held != null) done.add(held);
        open[b] = _Episode(b, r)..unobservedGap = unobserved;
      }
      for (final b in _bits(r.mask)) {
        open[b]?.end = r.at;
      }
      last = r;
    }

    if (last != null) {
      for (final b in _bits(last.mask)) {
        final e = open[b];
        if (e == null) continue;
        e.readings += totalReadings - last.index + 1;
        if (lastAt != null && lastAt.isAfter(e.end)) e.end = lastAt;
        e.ongoing = true;
      }
    }

    final out = [
      for (final e in [...done, ...pending.values, ...open.values])
        if (e.bit != BmsWarning.batteryFullyCharged.bit) e.freeze(),
    ]..sort((a, b) => b.start.compareTo(a.start));
    return out;
  }

  static Iterable<int> _bits(int mask) sync* {
    for (var b = 0; b < 32; b++) {
      if ((mask >> b) & 1 == 1) yield b;
    }
  }
}

class _Episode {
  _Episode(this.bit, this.first) : end = first.at;

  final int bit;
  final WarningTransition first;
  DateTime end;
  int readings = 0;
  bool unobservedGap = false;
  bool ongoing = false;

  FaultEpisode freeze() => FaultEpisode(
    bit: bit,
    start: first.at,
    end: end,
    // An episode closed by the very next transition was counted there; one
    // reading at least, since a bit is only ever seen in a reading.
    readings: readings < 1 ? 1 : readings,
    unobservedGap: unobservedGap,
    ongoing: ongoing,
    current: first.current,
    soc: first.soc,
    maxCellVoltage: first.maxCellVoltage,
    minCellVoltage: first.minCellVoltage,
  );
}
