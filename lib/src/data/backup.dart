import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database.dart';

/// Everything the app knows, in one file, and back again.
///
/// The app spends its whole life accumulating history, which is exactly what
/// makes losing a phone expensive: the CSV and GPX exports are for reading
/// elsewhere, not for coming back. Months of readings, every ride, every
/// capacity measurement and the raw frames that make a decoding mistake
/// recoverable all live in one sqlite file with no copy anywhere.
///
/// The format is JSON rather than a copy of the database file. A raw copy
/// would be smaller and simpler, and would also be unreadable by anything
/// except this exact schema version: restoring it onto a newer app would mean
/// running migrations over a file of unknown vintage. JSON with a stated
/// schema version can be read by a human, repaired by hand, and imported into
/// any later version that knows what to do with it.
class BackupCodec {
  BackupCodec(this.db);

  final AppDatabase db;

  /// Bumped only when the shape changes in a way an older reader could not
  /// cope with. Stored so an import can refuse rather than guess.
  static const int formatVersion = 1;

  /// Writes the backup and returns the file.
  ///
  /// Raw frames are the bulk of the data by a wide margin: roughly 25 MB a day
  /// against a few hundred kilobytes of everything else. Included by default
  /// because they are the reason a wrongly-decoded byte offset is survivable,
  /// but skippable for a backup meant to be small enough to email.
  ///
  /// [into] is where it lands. Injected rather than always asking the platform
  /// for the documents directory, so the round trip can be tested without a
  /// device attached: a backup nobody has ever restored is not a backup.
  Future<File> export({bool includeRawFrames = true, Directory? into}) async {
    final devices = await db.allDevices();
    final trips = await db.allTripsForBackup();
    final points = await db.allTripPointsForBackup();
    final snapshots = await db.allSnapshotsForBackup();
    final tests = await db.allCapacityTestsForBackup();
    final maintenance = await db.allMaintenanceForBackup();
    final frames = includeRawFrames
        ? await db.allRawFramesForBackup()
        : const <RawFrame>[];

    final payload = <String, Object?>{
      'format': formatVersion,
      'schema': db.schemaVersion,
      // The phone's clock, in UTC, like every other timestamp in this app.
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'includesRawFrames': includeRawFrames,
      'devices': devices.map(_device).toList(),
      'trips': trips.map(_trip).toList(),
      'tripPoints': points.map(_point).toList(),
      'snapshots': snapshots.map(_snapshot).toList(),
      'capacityTests': tests.map(_test).toList(),
      'maintenance': maintenance.map(_maintenance).toList(),
      'rawFrames': frames.map(_frame).toList(),
    };

    final dir = into ?? await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().toUtc().toIso8601String().split('.').first
        .replaceAll(':', '-');
    final file = File(p.join(dir.path, 'jk-bms-backup-$stamp.json'));
    await file.writeAsString(jsonEncode(payload));
    return file;
  }

  /// Reads a backup back in.
  ///
  /// Additive by default: rows are merged in rather than replacing what is
  /// already there, so restoring an old backup onto a phone that has kept
  /// riding does not throw away the newer rides. [replace] wipes first, for
  /// moving to a new phone where whatever is there is not wanted.
  ///
  /// Row ids are not preserved. They are local to a database and reusing them
  /// would collide with rows already present; trip points are re-pointed at
  /// the new trip ids as they are written.
  Future<BackupImportResult> import(
    File file, {
    bool replace = false,
  }) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } on Object {
      throw const BackupFormatException('not a readable backup file');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const BackupFormatException('not a readable backup file');
    }

    final format = decoded['format'];
    if (format is! int) {
      throw const BackupFormatException('no format version');
    }
    if (format > formatVersion) {
      // Refusing beats guessing: a newer file may carry tables this build has
      // never heard of, and half-importing it would leave a database that
      // looks complete and is not.
      throw BackupFormatException(
        'made by a newer version of the app (format $format)',
      );
    }

    if (replace) await db.wipeEverything();

    final devices = _list(decoded['devices']);
    final trips = _list(decoded['trips']);
    final points = _list(decoded['tripPoints']);
    final snapshots = _list(decoded['snapshots']);
    final tests = _list(decoded['capacityTests']);
    final frames = _list(decoded['rawFrames']);
    final maintenance = _list(decoded['maintenance']);

    for (final d in devices) {
      await db.upsertDevice(
        DevicesCompanion.insert(
          id: d['id'] as String,
          name: Value(d['name'] as String? ?? ''),
          serialNumber: Value(d['serialNumber'] as String? ?? ''),
          model: Value(d['model'] as String? ?? ''),
          catalogueCapacityAh: Value(_double(d['catalogueCapacityAh'])),
          catalogueFromBms: Value(d['catalogueFromBms'] as bool? ?? false),
          firstSeenAt: _time(d['firstSeenAt'])!,
          lastSeenAt: _time(d['lastSeenAt'])!,
          demo: Value(d['demo'] as bool? ?? false),
        ),
      );
    }

    // Old trip id to new, so the track follows its ride.
    final tripIds = <int, int>{};
    for (final t in trips) {
      final newId = await db.insertTrip(_tripCompanion(t));
      final oldId = t['id'];
      if (oldId is int) tripIds[oldId] = newId;
    }

    final pointRows = <TripPointsCompanion>[];
    for (final pt in points) {
      final mapped = tripIds[pt['tripId']];
      // A track with no ride is not worth keeping: nothing can ever show it.
      if (mapped == null) continue;
      pointRows.add(_pointCompanion(pt, mapped));
    }
    if (pointRows.isNotEmpty) await db.insertTripPoints(pointRows);

    final snapshotRows = [
      for (final s in snapshots) _snapshotCompanion(s, tripIds),
    ];
    if (snapshotRows.isNotEmpty) await db.insertSnapshots(snapshotRows);

    for (final t in tests) {
      await db.insertCapacityTest(_testCompanion(t));
    }

    for (final m in maintenance) {
      final deviceId = m['deviceId'];
      final at = _time(m['at']);
      // An event with no pack or no date is a note about nothing.
      if (deviceId is! String || at == null) continue;
      await db.insertMaintenance(
        MaintenanceEventsCompanion.insert(
          deviceId: deviceId,
          at: at,
          kind: m['kind'] as String? ?? 'other',
          note: Value(m['note'] as String? ?? ''),
        ),
      );
    }

    final frameRows = [for (final f in frames) _frameCompanion(f)];
    if (frameRows.isNotEmpty) await db.insertRawFrames(frameRows);

    return BackupImportResult(
      devices: devices.length,
      trips: trips.length,
      tripPoints: pointRows.length,
      snapshots: snapshotRows.length,
      capacityTests: tests.length,
      rawFrames: frameRows.length,
      maintenance: maintenance.length,
      exportedAt: _time(decoded['exportedAt']),
    );
  }

  // --- to JSON ---

  static Map<String, Object?> _device(Device d) => {
        'id': d.id,
        'name': d.name,
        'serialNumber': d.serialNumber,
        'model': d.model,
        'catalogueCapacityAh': d.catalogueCapacityAh,
        'catalogueFromBms': d.catalogueFromBms,
        'firstSeenAt': d.firstSeenAt.toIso8601String(),
        'lastSeenAt': d.lastSeenAt.toIso8601String(),
        'demo': d.demo,
      };

  static Map<String, Object?> _trip(Trip t) => {
        'id': t.id,
        'deviceId': t.deviceId,
        'startedAt': t.startedAt.toIso8601String(),
        'endedAt': t.endedAt.toIso8601String(),
        'distanceKm': t.distanceKm,
        'movingSeconds': t.movingSeconds,
        'totalSeconds': t.totalSeconds,
        'maxSpeedKmh': t.maxSpeedKmh,
        'energyOutWh': t.energyOutWh,
        'energyInWh': t.energyInWh,
        'startSoc': t.startSoc,
        'endSoc': t.endSoc,
        'minPackVoltage': t.minPackVoltage,
        'maxPackVoltage': t.maxPackVoltage,
        'maxDischargeCurrent': t.maxDischargeCurrent,
        'maxTemperature': t.maxTemperature,
        'maxDeltaVolts': t.maxDeltaVolts,
        'climbM': t.climbM,
        'descentM': t.descentM,
        'note': t.note,
        'demo': t.demo,
        // Nullable, and written as null rather than zero. A restored ride from
        // before conclusions were kept must stay a ride with no conclusions.
        'whPerKmBefore': t.whPerKmBefore,
        'whPerKmAfter': t.whPerKmAfter,
        'learnedKm': t.learnedKm,
        'rangeKmAtEnd': t.rangeKmAtEnd,
        'confidence': t.confidence,
      };

  static Map<String, Object?> _point(TripPoint p) => {
        'tripId': p.tripId,
        'timestamp': p.timestamp.toIso8601String(),
        'latitude': p.latitude,
        'longitude': p.longitude,
        'speedKmh': p.speedKmh,
        'altitudeM': p.altitudeM,
        'packVoltage': p.packVoltage,
        'current': p.current,
        'soc': p.soc,
      };

  static Map<String, Object?> _snapshot(Snapshot s) => {
        'deviceId': s.deviceId,
        'timestamp': s.timestamp.toIso8601String(),
        'tripId': s.tripId,
        'packVoltage': s.packVoltage,
        'current': s.current,
        'soc': s.soc,
        'soh': s.soh,
        'remainingAh': s.remainingAh,
        'cycleCount': s.cycleCount,
        'cycleCapacityAh': s.cycleCapacityAh,
        'deltaVolts': s.deltaVolts,
        'minCellVoltage': s.minCellVoltage,
        'maxCellVoltage': s.maxCellVoltage,
        'maxTemperature': s.maxTemperature,
        'mosfetTemp': s.mosfetTemp,
        'warningsMask': s.warningsMask,
        'balancerActive': s.balancerActive,
        'cellVoltagesJson': s.cellVoltagesJson,
      };

  static Map<String, Object?> _test(CapacityTest t) => {
        'deviceId': t.deviceId,
        'startedAt': t.startedAt.toIso8601String(),
        'endedAt': t.endedAt?.toIso8601String(),
        'startSoc': t.startSoc,
        'endSoc': t.endSoc,
        'startPackVoltage': t.startPackVoltage,
        'endPackVoltage': t.endPackVoltage,
        'measuredAh': t.measuredAh,
        'measuredWh': t.measuredWh,
        'catalogueAh': t.catalogueAh,
        'completed': t.completed,
        'automatic': t.automatic,
        'gapSeconds': t.gapSeconds,
        'note': t.note,
      };

  static Map<String, Object?> _maintenance(MaintenanceEvent e) => {
        'deviceId': e.deviceId,
        'at': e.at.toIso8601String(),
        'kind': e.kind,
        'note': e.note,
      };

  static Map<String, Object?> _frame(RawFrame f) => {
        'deviceId': f.deviceId,
        'timestamp': f.timestamp.toIso8601String(),
        'recordType': f.recordType,
        // Hex, so the file stays readable and diffable. Base64 would be
        // shorter; being able to eyeball a frame is worth the bytes.
        'bytes': f.bytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(),
      };

  // --- from JSON ---

  static List<Map<String, dynamic>> _list(Object? raw) => raw is List
      ? raw.whereType<Map<String, dynamic>>().toList()
      : const [];

  static DateTime? _time(Object? raw) =>
      raw is String ? DateTime.tryParse(raw)?.toUtc() : null;

  static double? _double(Object? raw) =>
      raw is num ? raw.toDouble() : null;

  static double _d(Object? raw, [double fallback = 0]) =>
      raw is num ? raw.toDouble() : fallback;

  static int _i(Object? raw, [int fallback = 0]) =>
      raw is num ? raw.toInt() : fallback;

  /// A number, or null. Distinct from [_d]: for a nullable column, absent has
  /// to stay absent rather than becoming a measurement of zero.
  static double? _dn(Object? raw) => raw is num ? raw.toDouble() : null;

  static TripsCompanion _tripCompanion(Map<String, dynamic> t) =>
      TripsCompanion.insert(
        deviceId: Value(t['deviceId'] as String?),
        startedAt: _time(t['startedAt'])!,
        endedAt: _time(t['endedAt'])!,
        distanceKm: _d(t['distanceKm']),
        movingSeconds: _i(t['movingSeconds']),
        totalSeconds: _i(t['totalSeconds']),
        maxSpeedKmh: _d(t['maxSpeedKmh']),
        energyOutWh: _d(t['energyOutWh']),
        energyInWh: _d(t['energyInWh']),
        startSoc: _d(t['startSoc']),
        endSoc: _d(t['endSoc']),
        minPackVoltage: _d(t['minPackVoltage']),
        maxPackVoltage: _d(t['maxPackVoltage']),
        maxDischargeCurrent: _d(t['maxDischargeCurrent']),
        maxTemperature: _d(t['maxTemperature']),
        maxDeltaVolts: _d(t['maxDeltaVolts']),
        climbM: _d(t['climbM']),
        descentM: _d(t['descentM']),
        note: Value(t['note'] as String? ?? ''),
        demo: Value(t['demo'] as bool? ?? false),
        whPerKmBefore: Value(_dn(t['whPerKmBefore'])),
        whPerKmAfter: Value(_dn(t['whPerKmAfter'])),
        learnedKm: Value(_dn(t['learnedKm'])),
        rangeKmAtEnd: Value(_dn(t['rangeKmAtEnd'])),
        confidence: Value(t['confidence'] as String?),
      );

  static TripPointsCompanion _pointCompanion(
    Map<String, dynamic> p,
    int tripId,
  ) =>
      TripPointsCompanion.insert(
        tripId: tripId,
        timestamp: _time(p['timestamp'])!,
        latitude: _d(p['latitude']),
        longitude: _d(p['longitude']),
        speedKmh: _d(p['speedKmh']),
        altitudeM: _d(p['altitudeM']),
        packVoltage: _d(p['packVoltage']),
        current: _d(p['current']),
        soc: _d(p['soc']),
      );

  static SnapshotsCompanion _snapshotCompanion(
    Map<String, dynamic> s,
    Map<int, int> tripIds,
  ) =>
      SnapshotsCompanion.insert(
        deviceId: Value(s['deviceId'] as String?),
        timestamp: _time(s['timestamp'])!,
        tripId: Value(tripIds[s['tripId']]),
        packVoltage: _d(s['packVoltage']),
        current: _d(s['current']),
        soc: _d(s['soc']),
        soh: _d(s['soh']),
        remainingAh: _d(s['remainingAh']),
        cycleCount: _d(s['cycleCount']),
        cycleCapacityAh: Value(_d(s['cycleCapacityAh'])),
        deltaVolts: _d(s['deltaVolts']),
        minCellVoltage: _d(s['minCellVoltage']),
        maxCellVoltage: _d(s['maxCellVoltage']),
        maxTemperature: _d(s['maxTemperature']),
        mosfetTemp: Value(_double(s['mosfetTemp'])),
        warningsMask: _i(s['warningsMask']),
        balancerActive: s['balancerActive'] as bool? ?? false,
        cellVoltagesJson: s['cellVoltagesJson'] as String? ?? '[]',
      );

  static CapacityTestsCompanion _testCompanion(Map<String, dynamic> t) =>
      CapacityTestsCompanion.insert(
        deviceId: Value(t['deviceId'] as String?),
        startedAt: _time(t['startedAt'])!,
        endedAt: Value(_time(t['endedAt'])),
        startSoc: _d(t['startSoc']),
        endSoc: _d(t['endSoc']),
        startPackVoltage: _d(t['startPackVoltage']),
        endPackVoltage: _d(t['endPackVoltage']),
        measuredAh: _d(t['measuredAh']),
        measuredWh: _d(t['measuredWh']),
        catalogueAh: Value(_double(t['catalogueAh'])),
        completed: Value(t['completed'] as bool? ?? false),
        automatic: Value(t['automatic'] as bool? ?? false),
        gapSeconds: Value(_i(t['gapSeconds'])),
        note: Value(t['note'] as String? ?? ''),
      );

  static RawFramesCompanion _frameCompanion(Map<String, dynamic> f) {
    final hex = f['bytes'] as String? ?? '';
    final bytes = <int>[];
    for (var i = 0; i + 1 < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return RawFramesCompanion.insert(
      deviceId: Value(f['deviceId'] as String?),
      timestamp: _time(f['timestamp'])!,
      recordType: _i(f['recordType']),
      bytes: Uint8List.fromList(bytes),
    );
  }
}

/// What came back in.
class BackupImportResult {
  const BackupImportResult({
    required this.devices,
    required this.trips,
    required this.tripPoints,
    required this.snapshots,
    required this.capacityTests,
    required this.rawFrames,
    this.maintenance = 0,
    this.exportedAt,
  });

  final int devices;
  final int trips;
  final int tripPoints;
  final int snapshots;
  final int capacityTests;
  final int rawFrames;
  final int maintenance;
  final DateTime? exportedAt;
}

/// The file is not a backup this app can read.
class BackupFormatException implements Exception {
  const BackupFormatException(this.reason);
  final String reason;

  @override
  String toString() => reason;
}
