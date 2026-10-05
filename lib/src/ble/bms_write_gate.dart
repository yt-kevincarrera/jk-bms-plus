import '../model/bms_snapshot.dart';
import '../model/jk_settings.dart';
import '../protocol/bms_brand.dart';
import '../protocol/jk_commands.dart';
import '../protocol/jk_constants.dart';
import '../protocol/protocol_variant.dart';
import 'ble_transport.dart';

/// The three switches the app can turn on and off on a JK, and nothing else.
///
/// Every other register stays out of reach on purpose. A switch has two
/// states and the BMS reports which one it is in, so a write can be checked
/// against the pack's own answer; a voltage or a current limit written wrong
/// disables a protection and nothing on the screen would say so.
enum BmsSwitch {
  /// The charge MOSFET: off, a charger plugged in does nothing.
  charge(registerChargeSwitch),

  /// The discharge MOSFET: off, the pack gives no power. On a bike that is
  /// the motor, the lights and the controller, all at once.
  discharge(registerDischargeSwitch),

  /// The balancer: off, the cells drift apart and nothing brings them back.
  balancer(registerBalancerSwitch);

  const BmsSwitch(this._jk02Register);

  final int _jk02Register;

  /// The holding register for this switch on [variant], or null where the
  /// app does not write it. Only the two JK02 framings have one here; see
  /// [registerChargeSwitch] for the source and why JK04 is left out.
  int? registerFor(JkProtocolVariant variant) => switch (variant) {
    JkProtocolVariant.jk02_24s || JkProtocolVariant.jk02_32s => _jk02Register,
    JkProtocolVariant.jk04 => null,
  };

  /// What the settings frame says this switch is set to.
  bool stateIn(JkSettings s) => switch (this) {
    BmsSwitch.charge => s.chargeSwitchOn,
    BmsSwitch.discharge => s.dischargeSwitchOn,
    BmsSwitch.balancer => s.balancerSwitchOn,
  };
}

/// Why a switch write was not made. In the order they are checked: the first
/// that applies is the one reported.
enum WriteRefusal {
  /// The rider has not turned on "let the app change the BMS".
  notPermitted,

  /// The pack is not a JK. ANT is not written to at all.
  notJk,

  /// No live link to write over.
  notConnected,

  /// The framing is JK04, or not known. Writing an address worked out for
  /// another framing is how a different register gets changed.
  variantUnsupported,

  /// No settings frame on this connection, so the current state is unknown
  /// and a change could never be confirmed.
  noSettings,

  /// No reading in the last [staleAfter]: the app cannot tell whether the
  /// bike is moving, nor expect an answer.
  noRecentReading,

  /// The latest reading does not describe a battery that could exist with
  /// the framing in use, which is what a wrong framing looks like.
  readingImplausible,

  /// The settings frame already shows the requested state. Nothing to write,
  /// and a write that changes nothing could never be told apart from one the
  /// BMS ignored.
  alreadySet,

  /// Discharge off while the bike is being ridden.
  riding,

  /// Another write is waiting for its answer.
  busy,
}

/// One switch write the gate allowed: the only thing a link will write that
/// is not a read request.
///
/// Its constructor is private to this file, so nothing but [decideSwitchWrite]
/// can make one, and [BmsLink.writeRegister] takes nothing else. That is what
/// makes the gate the single place a write can be let through: there is no
/// other way to hand a transport a write frame, and the transport's ordinary
/// path refuses any frame [isJkRegisterWrite] recognises.
final class RegisterWrite {
  RegisterWrite._({
    required this.target,
    required this.on,
    required this.address,
    required this.frame,
  });

  final BmsSwitch target;
  final bool on;
  final int address;

  /// The 20 bytes to write.
  final List<int> frame;

  String get hex => frame
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join();
}

sealed class WriteDecision {
  const WriteDecision();
}

final class WriteGranted extends WriteDecision {
  const WriteGranted(this.write);
  final RegisterWrite write;
}

final class WriteRefused extends WriteDecision {
  const WriteRefused(this.reason);
  final WriteRefusal reason;
}

/// How a switch write ended, for the screen to say.
enum SwitchWriteStatus {
  /// The gate refused it; nothing was written. [SwitchWriteOutcome.refusal]
  /// says why.
  refused,

  /// The gate allowed it and the radio would not take the bytes.
  notSent,

  /// A settings frame arrived after the write showing the new state.
  confirmed,

  /// The bytes went out and no settings frame showed the new state within
  /// the window. Not "failed": the pack may have done it and not said so.
  unconfirmed,
}

class SwitchWriteOutcome {
  const SwitchWriteOutcome(this.status, {this.refusal});
  final SwitchWriteStatus status;
  final WriteRefusal? refusal;
}

/// Everything the decision depends on, read from the service at the moment
/// of the tap.
class WriteContext {
  const WriteContext({
    required this.permitted,
    required this.brand,
    required this.link,
    required this.variant,
    required this.settings,
    required this.snapshot,
    required this.snapshotPlausible,
    required this.now,
    required this.riding,
    required this.tripRecording,
    this.busy = false,
  });

  /// The rider's "let the app change the BMS" setting.
  final bool permitted;
  final BmsBrand brand;
  final BleLinkState link;
  final JkProtocolVariant? variant;
  final JkSettings? settings;
  final BmsSnapshot? snapshot;

  /// Whether [snapshot] passes the plausibility rules with [variant].
  final bool snapshotPlausible;
  final DateTime now;

  /// The service's riding gate: sustained discharge or a ride recording.
  final bool riding;
  final bool tripRecording;
  final bool busy;
}

/// A reading older than this is not good enough to judge whether the bike is
/// moving. The pack sends two or three a second, so ten seconds without one
/// is a link in trouble.
const Duration staleAfter = Duration(seconds: 10);

/// Above this draw the bike counts as moving for the discharge switch,
/// whatever the riding gate says. Above the lights (0.44 A) and a wheel
/// spinning on a stand (about 1.5 A), so a parked bike can still be switched
/// off; the gate needs ten seconds of 3 A to say "riding", and this check
/// cannot wait ten seconds.
const double movingDrawAmps = 2.0;

/// Decides whether [target] may be set to [on]. The only function that can
/// produce a [RegisterWrite].
///
/// The permission is checked first and alone: with it off the answer is
/// [WriteRefusal.notPermitted] whatever else is true, and no frame is built.
WriteDecision decideSwitchWrite(BmsSwitch target, bool on, WriteContext c) {
  if (!c.permitted) return const WriteRefused(WriteRefusal.notPermitted);
  if (c.brand != BmsBrand.jk) return const WriteRefused(WriteRefusal.notJk);
  if (c.link != BleLinkState.connected) {
    return const WriteRefused(WriteRefusal.notConnected);
  }
  final variant = c.variant;
  final address = variant == null ? null : target.registerFor(variant);
  if (address == null) {
    return const WriteRefused(WriteRefusal.variantUnsupported);
  }
  final settings = c.settings;
  if (settings == null) return const WriteRefused(WriteRefusal.noSettings);
  final snapshot = c.snapshot;
  if (snapshot == null || c.now.difference(snapshot.timestamp) > staleAfter) {
    return const WriteRefused(WriteRefusal.noRecentReading);
  }
  // The version string only implies a framing, and a JK04 shares its version
  // range with JK02_24S. A reading that decodes into a battery that could
  // exist is the frame itself agreeing; a wrong framing produces impossible
  // numbers (see Plausibility), so a write is never made on one.
  if (!c.snapshotPlausible) {
    return const WriteRefused(WriteRefusal.readingImplausible);
  }
  if (target.stateIn(settings) == on) {
    return const WriteRefused(WriteRefusal.alreadySet);
  }
  if (target == BmsSwitch.discharge && !on) {
    final moving =
        c.riding || c.tripRecording || snapshot.current < -movingDrawAmps;
    if (moving) return const WriteRefused(WriteRefusal.riding);
  }
  if (c.busy) return const WriteRefused(WriteRefusal.busy);
  return WriteGranted(
    RegisterWrite._(
      target: target,
      on: on,
      address: address,
      frame: jkWriteRegisterCommand(
        address,
        on ? 1 : 0,
        length: switchValueLength,
      ),
    ),
  );
}
