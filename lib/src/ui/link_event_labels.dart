import '../../l10n/app_localizations.dart';
import '../data/link_event.dart';

/// What a link event was, in the rider's language. The enum names are the
/// stored form and stay English, like the protocol names; this is what the
/// screen shows.
String linkEventLabel(AppL10n t, LinkEventKind k) => switch (k) {
  LinkEventKind.ridingCurrentSeen => t.linkEventRidingCurrentSeen,
  LinkEventKind.idleSpeedSeen => t.linkEventIdleSpeedSeen,
  LinkEventKind.locationArmed => t.linkEventLocationArmed,
  LinkEventKind.locationStoodDown => t.linkEventLocationStoodDown,
  LinkEventKind.locationRefused => t.linkEventLocationRefused,
  LinkEventKind.tripWithoutFixes => t.linkEventTripWithoutFixes,
  LinkEventKind.locationStreamError => t.linkEventLocationStreamError,
  LinkEventKind.foregroundServiceRefused => t.linkEventForegroundServiceRefused,
  LinkEventKind.foregroundServiceLost => t.linkEventForegroundServiceLost,
  LinkEventKind.autoTripStarted => t.linkEventAutoTripStarted,
  LinkEventKind.autoTripStopped => t.linkEventAutoTripStopped,
  LinkEventKind.autoTripBlocked => t.linkEventAutoTripBlocked,
  LinkEventKind.readingsResumed => t.linkEventReadingsResumed,
  LinkEventKind.linkDropped => t.linkEventLinkDropped,
  LinkEventKind.muteLinkReleased => t.linkEventMuteLinkReleased,
  LinkEventKind.reconnectAttempted => t.linkEventReconnectAttempted,
  LinkEventKind.reconnectFailed => t.linkEventReconnectFailed,
  LinkEventKind.reconnectGaveUp => t.linkEventReconnectGaveUp,
  LinkEventKind.reconnectPersisting => t.linkEventReconnectPersisting,
  LinkEventKind.reconnectRelaxed => t.linkEventReconnectRelaxed,
  LinkEventKind.connectAttempt => t.linkEventConnectAttempt,
  LinkEventKind.bluetoothLooksStuck => t.linkEventBluetoothLooksStuck,
  LinkEventKind.bluetoothRemedy => t.linkEventBluetoothRemedy,
  LinkEventKind.bluetoothRecovered => t.linkEventBluetoothRecovered,
  LinkEventKind.protocolSwitched => t.linkEventProtocolSwitched,
  LinkEventKind.antFrameRejected => t.linkEventAntFrameRejected,
  LinkEventKind.antDecodeFailed => t.linkEventAntDecodeFailed,
  LinkEventKind.oldAntProtocolSeen => t.linkEventOldAntProtocolSeen,
  LinkEventKind.jkFrameRejected => t.linkEventJkFrameRejected,
  LinkEventKind.jkFrameUndecoded => t.linkEventJkFrameUndecoded,
  LinkEventKind.antCurrentSignInverted => t.linkEventAntCurrentSignInverted,
  LinkEventKind.bmsWriteRefused => t.linkEventBmsWriteRefused,
  LinkEventKind.bmsWriteNotSent => t.linkEventBmsWriteNotSent,
  LinkEventKind.bmsWriteSent => t.linkEventBmsWriteSent,
  LinkEventKind.bmsWriteConfirmed => t.linkEventBmsWriteConfirmed,
  LinkEventKind.bmsWriteUnconfirmed => t.linkEventBmsWriteUnconfirmed,
};
