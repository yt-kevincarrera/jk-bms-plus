import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/waiting_diagnosis.dart';

void main() {
  // Why this exists. The rider connected, every tab said "waiting for the first
  // reading", and nothing said which of four different stalls it was. The
  // service knew; the screen never asked. Each test pins one stage.

  WaitingReason at({
    BleLinkState link = BleLinkState.connected,
    int accepted = 0,
    int cellInfo = 0,
    int heldBack = 0,
    int failures = 0,
    bool variantKnown = true,
    int rejected = 0,
  }) => diagnoseWaiting(
    link: link,
    framesAccepted: accepted,
    cellInfoFrames: cellInfo,
    heldBackFrames: heldBack,
    decodeFailures: failures,
    variantKnown: variantKnown,
    rejectedFrames: rejected,
  );

  test('a link that is not up comes first, whatever else was seen', () {
    expect(at(link: BleLinkState.reconnecting), WaitingReason.linkDown);
    expect(at(link: BleLinkState.connecting, accepted: 5), WaitingReason.linkDown);
  });

  test('up and not one frame', () {
    expect(at(), WaitingReason.noFrames);
  });

  test('device info only: the pack talks but never with cell info', () {
    expect(at(accepted: 3, cellInfo: 0), WaitingReason.onlyDeviceInfo);
  });

  test('cell info held back for want of a variant', () {
    expect(
      at(accepted: 10, cellInfo: 7, heldBack: 7, variantKnown: false),
      WaitingReason.variantUnknown,
    );
  });

  test('cell info that will not decode', () {
    expect(
      at(accepted: 10, cellInfo: 7, failures: 7),
      WaitingReason.decodeFailing,
    );
  });

  test('everything worked and the screen still has nothing: say so', () {
    expect(at(accepted: 10, cellInfo: 7), WaitingReason.unexplained);
  });

  // ANT has no framing to guess, so its buffers either become a frame or are
  // thrown away before that -- there is no held-back-for-variant stage, and a
  // thrown-away buffer never reaches cellInfoFrames or decodeFailures. Its
  // rejected count is what proves the pack is talking, and what tells "still
  // silent" apart from "talking, but none of it decodes".
  test('an ANT that only sends buffers nothing can frame is not silent', () {
    expect(
      at(accepted: 0, cellInfo: 0, rejected: 6),
      WaitingReason.decodeFailing,
    );
  });

  test('an ANT with nothing at all, not even a rejected buffer, is silent', () {
    expect(at(accepted: 0, cellInfo: 0, rejected: 0), WaitingReason.noFrames);
  });

  test('an ANT reading real status frames is unaffected by rejects seen '
      'earlier on the same connection', () {
    expect(
      at(accepted: 10, cellInfo: 7, rejected: 3),
      WaitingReason.unexplained,
    );
  });
}
