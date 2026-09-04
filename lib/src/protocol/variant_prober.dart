import 'jk_frame.dart';
import 'jk_parser.dart';
import 'protocol_variant.dart';
import '../model/bms_snapshot.dart';

/// Judges whether a decoded reading describes a battery that could exist.
///
/// The whole reason this is possible: picking the wrong framing does not fail,
/// it reads at the wrong byte offsets, and the numbers that come out are not
/// merely wrong but impossible. Measured on the real captures in this repo, a
/// genuine 24-cell frame read as 32-cell reports a pack of 0.000 V while its
/// cells read 3.3 V each, a cell of 65.535 V, and a current of 75 038 A. A
/// genuine 32-cell frame read as 24-cell reports cells summing to 52.9 V and a
/// pack of 0.000 V.
///
/// So the rules below are physics, not preference, and the strongest of them
/// is the last: a BMS that reports cell voltages reports a pack voltage that is
/// their sum. No wrong offset lands on a number that happens to match.
///
/// Every rule is written to pass a *damaged* pack, because rejecting a real
/// reading would be far worse than failing to spot a wrong variant. A cell
/// collapsed to 0 V, a pack at rest, a probe reading below freezing: all fine.
class Plausibility {
  const Plausibility({
    this.maxCellVolts = 4.6,
    this.minTopCellVolts = 1.0,
    this.maxCurrentAmps = 1000,
    this.packSumTolerance = 0.05,
    this.packSumFloorVolts = 1.5,
    this.temperatureRange = const (-40.0, 125.0),
  });

  /// Above this no lithium chemistry sits. 4.6 V clears a Li-ion cell at its
  /// 4.35 V ceiling with room to spare, and rejects the 65.535 V that a 0xFFFF
  /// sentinel decodes to.
  final double maxCellVolts;

  /// The highest cell has to be a cell. A pack whose best cell reads under a
  /// volt is not a pack being read correctly, whatever is wrong with it.
  final double minTopCellVolts;

  /// No two-wheeler draws this. Rejects the tens of thousands of amps a
  /// misaligned 32-bit read produces.
  final double maxCurrentAmps;

  /// How far the reported pack voltage may sit from the sum of the cells,
  /// as a fraction. Real frames agree to within rounding; 5% is generous.
  final double packSumTolerance;

  /// Absolute slack underneath the fraction, so a small pack is not held to
  /// an impossibly tight absolute figure.
  final double packSumFloorVolts;

  final (double, double) temperatureRange;

  /// Every reason this reading cannot be real. Empty means it can.
  List<String> reject(BmsSnapshot s) {
    final reasons = <String>[];

    if (s.cellCount < 3) {
      reasons.add('${s.cellCount} cells');
    }
    if (s.cellCount > s.variant.cellSlots) {
      reasons.add('${s.cellCount} cells in ${s.variant.cellSlots} slots');
    }

    for (final v in s.cellVoltages) {
      if (v > maxCellVolts) {
        reasons.add('a cell at ${v.toStringAsFixed(3)} V');
        break;
      }
    }
    if (s.cellVoltages.isNotEmpty && s.maxCellVoltage < minTopCellVolts) {
      reasons.add('no cell above ${s.maxCellVoltage.toStringAsFixed(3)} V');
    }

    if (s.current.abs() > maxCurrentAmps) {
      reasons.add('${s.current.toStringAsFixed(0)} A');
    }
    if (s.soc < 0 || s.soc > 100) {
      reasons.add('${s.soc.toStringAsFixed(0)} % charge');
    }
    for (final t in s.temperatures) {
      if (t < temperatureRange.$1 || t > temperatureRange.$2) {
        reasons.add('a probe at ${t.toStringAsFixed(1)} C');
        break;
      }
    }

    // The decisive one. Kept last so the reasons read from the specific to the
    // structural.
    final sum = s.cellVoltages.fold<double>(0, (a, v) => a + v);
    if (sum > 0) {
      final slack = packSumFloorVolts > sum * packSumTolerance
          ? packSumFloorVolts
          : sum * packSumTolerance;
      if ((s.packVoltage - sum).abs() > slack) {
        reasons.add(
          'a pack of ${s.packVoltage.toStringAsFixed(3)} V over cells '
          'totalling ${sum.toStringAsFixed(3)} V',
        );
      }
    }

    return reasons;
  }

  bool accepts(BmsSnapshot s) => reject(s).isEmpty;
}

/// What probing a frame concluded.
class ProbeResult {
  const ProbeResult({required this.variant, required this.rejections});

  /// The one framing that produced a possible battery, or null when none did
  /// or more than one did.
  ///
  /// Refusing to answer when two candidates both look fine is the point. A
  /// prober that guesses between them would be the old version-number guess
  /// wearing a lab coat, and wrong numbers shown confidently are worse than a
  /// gap the rider can see.
  final JkProtocolVariant? variant;

  /// Why each candidate was turned down, for the notice and the frame console.
  final Map<JkProtocolVariant, List<String>> rejections;

  bool get decided => variant != null;
}

/// Reads one cell info frame with every framing this app decodes and keeps the
/// one that describes a battery that could exist.
///
/// Cheap on purpose: decoding a 300-byte frame is a few hundred arithmetic
/// operations, so trying both costs less than the notification that delivered
/// it. It is called at most once per connection, and never at all on a pack
/// whose firmware version already answered the question.
ProbeResult probeVariant({
  required JkFrame frame,
  JkParser parser = const JkParser(),
  Plausibility plausibility = const Plausibility(),
  List<JkProtocolVariant> candidates = const [
    JkProtocolVariant.jk02_24s,
    JkProtocolVariant.jk02_32s,
  ],
}) {
  final rejections = <JkProtocolVariant, List<String>>{};
  final survivors = <JkProtocolVariant>[];

  for (final candidate in candidates) {
    try {
      final snapshot = parser.parseCellInfo(frame, candidate);
      final reasons = plausibility.reject(snapshot);
      rejections[candidate] = reasons;
      if (reasons.isEmpty) survivors.add(candidate);
    } on Object catch (e) {
      rejections[candidate] = ['$e'];
    }
  }

  return ProbeResult(
    variant: survivors.length == 1 ? survivors.single : null,
    rejections: rejections,
  );
}
