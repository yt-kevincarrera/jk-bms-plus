import 'dart:async';

import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:jk_bms/src/ble/connect_recovery.dart';

/// A [RecoveryRadio] that does nothing and says what it was asked, in order.
///
/// Shares [log] with [FakeFbpPlatform] when a test needs the order across
/// both: the escalation is only right if the release and the scan happen
/// before the connect they prepare for.
class FakeRecoveryRadio implements RecoveryRadio {
  FakeRecoveryRadio({List<String>? log}) : log = log ?? [];

  final List<String> log;

  String adapter = 'on';
  List<String> appIds = [];
  List<String>? systemIds = [];

  /// What [freshAdvert] answers. Null is "not heard".
  AdvertSighting? advert;

  final adapterChanges = StreamController<String>.broadcast(sync: true);

  @override
  String adapterState() => adapter;

  @override
  List<String> appConnectedIds() => appIds;

  @override
  Future<List<String>?> systemConnectedIds() async => systemIds;

  @override
  Future<void> release(String deviceId) async => log.add('release $deviceId');

  @override
  Future<String> closeStranded(String deviceId) async {
    log.add('closeStranded $deviceId');
    return 'joined and released';
  }

  @override
  Future<AdvertSighting?> freshAdvert(
    String deviceId, {
    required Duration within,
    required bool Function() stillWanted,
  }) async {
    log.add('freshAdvert $deviceId ${within.inSeconds}s');
    return advert;
  }

  @override
  Future<String> resetAll() async {
    log.add('resetAll');
    return 'released 0 plugin link(s)';
  }

  @override
  Stream<String> get adapterStates => adapterChanges.stream;
}

/// The plugin's platform side, answered from the test.
///
/// flutter_blue_plus has no platform in a test, so the real transport could
/// never be run, and its attach, retry and letting-go logic went untested.
/// This stands in for Android: [onConnect] decides what each connect request
/// turns into, and every connect and disconnect request is logged.
final class FakeFbpPlatform extends FlutterBluePlusPlatform {
  FakeFbpPlatform({List<String>? log}) : log = log ?? [];

  final List<String> log;

  /// Connect requests, by id, in order.
  final List<String> connects = [];

  /// Disconnect requests, by id, in order.
  final List<String> disconnects = [];

  /// What a connect request turns into. Left null, the request is accepted
  /// and nothing ever comes of it, like a pack that never answers.
  void Function(String id)? onConnect;

  final Set<String> _connecting = {};

  final _states = StreamController<BmConnectionStateResponse>.broadcast();

  @override
  Stream<BmConnectionStateResponse> get onConnectionStateChanged =>
      _states.stream;

  void emit(
    String id,
    BmConnectionStateEnum state, {
    int code = 0,
    String reason = '',
  }) {
    _connecting.remove(id);
    _states.add(
      BmConnectionStateResponse(
        remoteId: DeviceIdentifier(id),
        connectionState: state,
        disconnectReasonCode: code,
        disconnectReasonString: reason,
      ),
    );
  }

  @override
  Future<bool> connect(BmConnectRequest request) async {
    final id = request.remoteId.str;
    connects.add(id);
    log.add('connect $id');
    _connecting.add(id);
    final behave = onConnect;
    if (behave != null) scheduleMicrotask(() => behave(id));
    return true;
  }

  @override
  Future<bool> disconnect(BmDisconnectRequest request) async {
    final id = request.remoteId.str;
    disconnects.add(id);
    log.add('disconnect $id');
    // As the Android plugin does: a connect still in progress is cancelled
    // and reported as such. Anything else is "already disconnected".
    if (_connecting.contains(id)) {
      scheduleMicrotask(
        () => emit(
          id,
          BmConnectionStateEnum.disconnected,
          code: 23789258,
          reason: 'connection canceled',
        ),
      );
      return true;
    }
    return false;
  }
}
