import 'package:drift/drift.dart';

import '../data/database.dart';

/// The kinds of thing a rider does to a pack.
///
/// A short list on purpose. Long lists of categories go unread and everything
/// ends up under "other"; these are the ones that actually move a line on a
/// chart, and anything else has the note field.
enum MaintenanceKind {
  /// A cell swapped out. The one that most obviously changes what the history
  /// means: capacity, delta and the weakest-cell verdict all reset.
  cellReplaced,

  /// Cells brought back level by hand, rather than by the balancer.
  manualBalance,

  /// Connections cleaned or retightened. Fixes a delta that only shows under
  /// load, which is a different fault from a delta at rest.
  connectionsServiced,

  /// A different charger, or the same one set differently.
  chargerChanged,

  /// Settings changed in the official app. Worth recording because this app
  /// never writes them, so it cannot know it happened.
  bmsSettingsChanged,

  /// Anything else, described in the note.
  other;

  /// Stored by name rather than index, so reordering this enum cannot silently
  /// relabel history that is already written.
  static MaintenanceKind parse(String raw) => MaintenanceKind.values.firstWhere(
        (k) => k.name == raw,
        orElse: () => MaintenanceKind.other,
      );
}

/// Reading and writing the maintenance log.
class MaintenanceLog {
  const MaintenanceLog(this.db);

  final AppDatabase db;

  Future<List<MaintenanceEvent>> forPack(String deviceId) =>
      db.maintenanceFor(deviceId);

  Future<int> add({
    required String deviceId,
    required DateTime at,
    required MaintenanceKind kind,
    String note = '',
  }) =>
      db.insertMaintenance(
        MaintenanceEventsCompanion.insert(
          deviceId: deviceId,
          // Stored in UTC like every other timestamp here. The BMS's own clock
          // is never used anywhere in this app and this is no exception.
          at: at.toUtc(),
          kind: kind.name,
          note: Value(note.trim()),
        ),
      );

  Future<void> remove(int id) => db.deleteMaintenance(id);

  Future<void> edit(int id, {DateTime? at, MaintenanceKind? kind, String? note}) =>
      db.updateMaintenance(
        id,
        MaintenanceEventsCompanion(
          at: at == null ? const Value.absent() : Value(at.toUtc()),
          kind: kind == null ? const Value.absent() : Value(kind.name),
          note: note == null ? const Value.absent() : Value(note.trim()),
        ),
      );

  /// Events inside a window, oldest first, for drawing onto a chart.
  ///
  /// Charts are the reason this log exists: a capacity that jumps or a delta
  /// that collapses looks like noise until a marker says a cell was replaced
  /// that week.
  static List<MaintenanceEvent> within(
    List<MaintenanceEvent> events,
    DateTime from,
    DateTime to,
  ) {
    final inRange = events
        .where((e) => !e.at.isBefore(from) && !e.at.isAfter(to))
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    return inRange;
  }

  /// The most recent event of a given kind, if there is one.
  ///
  /// Used to date the history that is still meaningful: readings from before a
  /// cell was replaced describe a pack that no longer exists.
  static MaintenanceEvent? lastOf(
    List<MaintenanceEvent> events,
    MaintenanceKind kind,
  ) {
    MaintenanceEvent? best;
    for (final e in events) {
      if (MaintenanceKind.parse(e.kind) != kind) continue;
      if (best == null || e.at.isAfter(best.at)) best = e;
    }
    return best;
  }
}
