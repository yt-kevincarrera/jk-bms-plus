import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_settings.dart';

/// Holds the screen awake, or lets it sleep, according to what was asked for.
///
/// Two screens want this and both are rebuilt constantly, so the decision is
/// centralised and the platform is only told when the answer actually changes.
/// Otherwise every frame of a moving speed readout is a channel call.
class ScreenAwakeKeeper {
  ScreenAwakeKeeper._();

  static bool? _applied;

  /// Applies [mode], given whether a ride is currently open.
  ///
  /// Safe to call from build: repeated calls with the same answer do nothing.
  static void apply(ScreenAwake mode, {required bool riding}) {
    final wanted = switch (mode) {
      ScreenAwake.never => false,
      ScreenAwake.whileRiding => riding,
      ScreenAwake.always => true,
    };
    if (_applied == wanted) return;
    _applied = wanted;
    // Fire and forget. A refused wakelock means the screen sleeps, which is
    // the safe direction to fail in.
    if (wanted) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  /// Lets the screen sleep again, for leaving the screens that hold it.
  static void release() {
    if (_applied == false) return;
    _applied = false;
    WakelockPlus.disable();
  }
}
