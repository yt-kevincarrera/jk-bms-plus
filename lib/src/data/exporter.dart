import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database.dart';
import 'repository.dart';

/// Writes what the app has recorded to files you can take elsewhere.
///
/// Data you cannot get out is data you do not really own. Three exports, each
/// answering a different question:
///
///  * Trips as CSV, for a spreadsheet.
///  * Readings as CSV, for plotting the pack over time.
///  * Raw frames as hex, for reparsing history if a byte offset in this app
///    turns out to have been wrong.
class BmsExporter {
  BmsExporter(this.repository);

  final BmsRepository repository;

  /// One row per stored ride.
  Future<File> exportTrips() async {
    final trips = await repository.db.recentTrips(limit: 10000);
    final rows = StringBuffer()
      ..writeln(
        'started_at,ended_at,demo,distance_km,moving_s,total_s,max_speed_kmh,'
        'energy_out_wh,energy_in_wh,wh_per_km,start_soc,end_soc,'
        'min_pack_v,max_pack_v,max_discharge_a,max_temp_c,max_delta_v,'
        'climb_m,descent_m,note',
      );

    for (final t in trips) {
      final net = t.energyOutWh - t.energyInWh;
      final whPerKm = t.distanceKm >= 0.2 ? net / t.distanceKm : null;
      rows.writeln([
        t.startedAt.toIso8601String(),
        t.endedAt.toIso8601String(),
        t.demo,
        _n(t.distanceKm, 3),
        t.movingSeconds,
        t.totalSeconds,
        _n(t.maxSpeedKmh, 1),
        _n(t.energyOutWh, 2),
        _n(t.energyInWh, 2),
        whPerKm == null ? '' : _n(whPerKm, 2),
        _n(t.startSoc, 1),
        _n(t.endSoc, 1),
        _n(t.minPackVoltage, 3),
        _n(t.maxPackVoltage, 3),
        _n(t.maxDischargeCurrent, 2),
        _n(t.maxTemperature, 1),
        _n(t.maxDeltaVolts, 4),
        _n(t.climbM, 1),
        _n(t.descentM, 1),
        _csv(t.note),
      ].join(','));
    }

    return _write('jk-bms-trips', 'csv', rows.toString());
  }

  /// One row per decoded reading, with every cell voltage as its own column.
  ///
  /// [since] keeps the file to a size a spreadsheet can open: a month of
  /// continuous recording is millions of rows.
  Future<File> exportReadings({Duration since = const Duration(days: 7)}) async {
    final from = DateTime.now().toUtc().subtract(since);
    final rows = await repository.db.snapshotsBetween(
      from,
      DateTime.now().toUtc(),
    );

    // Cell count is taken from the data rather than assumed, so a pack with a
    // different number of cells exports correctly.
    var cellCount = 0;
    for (final r in rows) {
      final n = decodeCellVoltages(r.cellVoltagesJson).length;
      if (n > cellCount) cellCount = n;
    }

    final out = StringBuffer()
      ..writeln([
        'timestamp',
        'trip_id',
        'pack_v',
        'current_a',
        'power_w',
        'soc',
        'soh',
        'remaining_ah',
        'cycles',
        'delta_v',
        'min_cell_v',
        'max_cell_v',
        'max_temp_c',
        'mosfet_temp_c',
        'warnings_mask',
        'balancing',
        for (var i = 1; i <= cellCount; i++) 'cell_$i',
      ].join(','));

    for (final r in rows) {
      final cells = decodeCellVoltages(r.cellVoltagesJson);
      out.writeln([
        r.timestamp.toIso8601String(),
        r.tripId ?? '',
        _n(r.packVoltage, 3),
        _n(r.current, 3),
        _n(r.packVoltage * r.current, 1),
        _n(r.soc, 1),
        _n(r.soh, 1),
        _n(r.remainingAh, 3),
        _n(r.cycleCount, 0),
        _n(r.deltaVolts, 4),
        _n(r.minCellVoltage, 3),
        _n(r.maxCellVoltage, 3),
        _n(r.maxTemperature, 1),
        r.mosfetTemp == null ? '' : _n(r.mosfetTemp!, 1),
        r.warningsMask,
        r.balancerActive,
        for (var i = 0; i < cellCount; i++)
          i < cells.length ? _n(cells[i], 3) : '',
      ].join(','));
    }

    return _write('jk-bms-readings', 'csv', out.toString());
  }

  /// The raw frames, in hex, one per line, with the time they arrived.
  ///
  /// This is the file that makes a decoding mistake survivable: feed it back
  /// through a corrected parser and the history comes back rather than being
  /// lost.
  Future<File> exportRawFrames({
    Duration since = const Duration(days: 1),
  }) async {
    final from = DateTime.now().toUtc().subtract(since);
    final frames = await repository.db.rawFramesSince(from);

    final out = StringBuffer()
      ..writeln('# JK BMS raw frames, 300 bytes each, hex')
      ..writeln('# timestamp,record_type,bytes');
    for (final f in frames) {
      final hex = f.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join()
          .toUpperCase();
      out.writeln(
        '${f.timestamp.toIso8601String()},'
        '0x${f.recordType.toRadixString(16).padLeft(2, '0')},$hex',
      );
    }

    return _write('jk-bms-frames', 'txt', out.toString());
  }

  /// One ride's track, as GPX, so it opens in any map tool.
  Future<File> exportTrack(int tripId) async {
    final points = await repository.pointsFor(tripId);
    final out = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<gpx version="1.1" creator="JK BMS +" '
        'xmlns="http://www.topografix.com/GPX/1/1">',
      )
      ..writeln('  <trk><name>Trip $tripId</name><trkseg>');
    for (final p in points) {
      out
        ..writeln(
          '    <trkpt lat="${p.latitude}" lon="${p.longitude}">',
        )
        ..writeln('      <ele>${_n(p.altitudeM, 1)}</ele>')
        ..writeln('      <time>${p.timestamp.toIso8601String()}</time>')
        ..writeln('    </trkpt>');
    }
    out
      ..writeln('  </trkseg></trk>')
      ..writeln('</gpx>');

    return _write('jk-bms-trip-$tripId', 'gpx', out.toString());
  }

  Future<File> _write(String stem, String extension, String contents) async {
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File(p.join(dir.path, '$stem-$stamp.$extension'));
    await file.writeAsString(contents, encoding: utf8);
    return file;
  }

  static String _n(double v, int decimals) => v.toStringAsFixed(decimals);

  /// Quotes a field only when it needs it, so the common case stays readable.
  static String _csv(String value) {
    if (!value.contains(',') && !value.contains('"') && !value.contains('\n')) {
      return value;
    }
    return '"${value.replaceAll('"', '""')}"';
  }
}
