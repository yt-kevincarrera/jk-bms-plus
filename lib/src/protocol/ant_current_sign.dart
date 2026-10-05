import 'ant_constants.dart';

/// Cross-checks the sign of an ANT's current against its own battery state.
///
/// Why this exists. The app takes positive current as charging, which is
/// measured on the rider's JK (discharge reads negative). For an ANT it is an
/// assumption: every capture there is so far is of an idle pack, the 16S one
/// included, whose state byte says "idle" (0x01) with 0.3 A on the wire. If an
/// ANT reports the other way round, every figure built on the sign is wrong
/// at once: charging reads as riding, the energy counters run backwards, and
/// the charge alerts never fire.
///
/// The frame carries its own witness. Byte 7 says charging or discharging, so
/// a current that is clearly the opposite sign for several frames running is
/// the BMS telling us the convention is reversed. One frame is not enough:
/// the state and the current are not guaranteed to be sampled at the same
/// instant, and the moment a charger is plugged in or pulled is exactly when
/// they can disagree briefly.
///
/// It decides once per pack and then stays decided: a sign that flipped back
/// and forth would be worse than either answer.
class AntCurrentSign {
  AntCurrentSign({this.clearAmps = 0.5, this.framesToDecide = 3});

  /// Below this the sign says nothing. ANT reports current in 0.1 A steps,
  /// and a pack sitting at a few tenths of an amp is at rest whatever its
  /// state byte says.
  final double clearAmps;

  /// Consecutive frames needed, agreeing or disagreeing, before deciding.
  final int framesToDecide;

  bool? _inverted;
  int _against = 0;
  int _with = 0;

  /// Whether this pack's current has been found to run backwards.
  bool get inverted => _inverted ?? false;

  /// Whether enough has been seen to say either way.
  bool get decided => _inverted != null;

  /// Feeds one decoded frame's state and raw current. Returns true exactly
  /// once: on the frame that settles the sign as inverted.
  bool observe({required int batteryState, required double current}) {
    if (_inverted != null) return false;
    final charging = batteryState == antStateCharge;
    final discharging = batteryState == antStateDischarge;
    if (!charging && !discharging) return false;
    if (current.abs() < clearAmps) return false;

    final agrees = charging == (current > 0);
    if (agrees) {
      _against = 0;
      if (++_with >= framesToDecide) _inverted = false;
      return false;
    }
    _with = 0;
    if (++_against >= framesToDecide) {
      _inverted = true;
      return true;
    }
    return false;
  }
}
