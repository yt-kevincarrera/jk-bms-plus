import 'ble_transport.dart';

/// Why a connected app has no reading to show yet, by the stage it is stuck at.
///
/// Exists because the answer used to be a spinner. The rider connected, every
/// tab said "waiting for the first reading", and nothing on any of them said
/// whether the link was down, the pack was silent, the pack was talking but
/// never with cell info, or the frames were arriving and being refused. Those
/// are four different problems with four different fixes, and the service
/// already knew which one it was.
enum WaitingReason {
  /// The link is not up. The transport is retrying on its own.
  linkDown,

  /// The link is up and not one frame has decoded from it.
  noFrames,

  /// Frames arrive, device info among them, but no cell info frame ever has.
  /// The service is asking for it again every few seconds.
  onlyDeviceInfo,

  /// Cell info frames arrive and are held back: the protocol variant is not
  /// known, and picking one by hand in the System tab is what unblocks it.
  variantUnknown,

  /// Cell info frames arrive and the parser cannot decode them.
  decodeFailing,

  /// Readings decoded and were emitted, yet none reached this screen. The
  /// app's own fault, and the notices are where the evidence is.
  unexplained,
}

WaitingReason diagnoseWaiting({
  required BleLinkState link,
  required int framesAccepted,
  required int cellInfoFrames,
  required int heldBackFrames,
  required int decodeFailures,
  required bool variantKnown,
}) {
  if (link != BleLinkState.connected) return WaitingReason.linkDown;
  if (framesAccepted == 0) return WaitingReason.noFrames;
  if (cellInfoFrames == 0) return WaitingReason.onlyDeviceInfo;
  if (!variantKnown && heldBackFrames > 0) return WaitingReason.variantUnknown;
  if (decodeFailures > 0) return WaitingReason.decodeFailing;
  return WaitingReason.unexplained;
}
