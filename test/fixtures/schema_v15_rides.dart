/// The ride, reading and capacity tables exactly as versions 14 and 15
/// shipped them, with the hottest probe and the cycle count still NOT NULL.
///
/// Shared by the migration tests of both versions: the from < 16 step
/// rebuilds these, so any database a test upgrades past 15 has to have them.
/// Written out longhand, like the older schemas in migration_test.dart, so
/// the steps run against what is on the phone rather than against the
/// current classes.
const v15RideTables = [
  '''
  CREATE TABLE trips (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    started_at INTEGER NOT NULL,
    ended_at INTEGER NOT NULL,
    distance_km REAL NOT NULL,
    moving_seconds INTEGER NOT NULL,
    total_seconds INTEGER NOT NULL,
    max_speed_kmh REAL NOT NULL,
    energy_out_wh REAL NOT NULL,
    energy_in_wh REAL NOT NULL,
    start_soc REAL NOT NULL,
    end_soc REAL NOT NULL,
    min_pack_voltage REAL NOT NULL,
    max_pack_voltage REAL NOT NULL,
    max_discharge_current REAL NOT NULL,
    max_temperature REAL NOT NULL,
    max_delta_volts REAL NOT NULL,
    climb_m REAL NOT NULL,
    descent_m REAL NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    demo INTEGER NOT NULL DEFAULT 0 CHECK (demo IN (0, 1)),
    device_id TEXT,
    wh_per_km_before REAL,
    wh_per_km_after REAL,
    learned_km REAL,
    range_km_at_end REAL,
    confidence TEXT,
    ah_out REAL,
    energy_source TEXT,
    representative INTEGER CHECK (representative IN (0, 1)),
    summary_seen INTEGER NOT NULL DEFAULT 0 CHECK (summary_seen IN (0, 1))
  )''',
  '''
  CREATE TABLE trip_points (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    trip_id INTEGER NOT NULL REFERENCES trips (id) ON DELETE CASCADE,
    timestamp INTEGER NOT NULL,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    speed_kmh REAL NOT NULL,
    altitude_m REAL NOT NULL,
    pack_voltage REAL NOT NULL,
    current REAL NOT NULL,
    soc REAL NOT NULL
  )''',
  '''
  CREATE TABLE snapshots (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    timestamp INTEGER NOT NULL,
    trip_id INTEGER,
    pack_voltage REAL NOT NULL,
    current REAL NOT NULL,
    soc REAL NOT NULL,
    soh REAL NOT NULL,
    remaining_ah REAL NOT NULL,
    cycle_count REAL NOT NULL,
    cycle_capacity_ah REAL NOT NULL DEFAULT 0,
    delta_volts REAL NOT NULL,
    min_cell_voltage REAL NOT NULL,
    max_cell_voltage REAL NOT NULL,
    max_temperature REAL NOT NULL,
    mosfet_temp REAL,
    warnings_mask INTEGER NOT NULL,
    balancer_active INTEGER NOT NULL CHECK (balancer_active IN (0, 1)),
    cell_voltages_json TEXT NOT NULL,
    device_id TEXT
  )''',
  // Unchanged from version 5 to 16. Here because the from < 17 step adds to
  // it and marks its finished rows, so every database upgraded past 16 has
  // to have it, as every real one does.
  '''
  CREATE TABLE capacity_tests (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    started_at INTEGER NOT NULL,
    ended_at INTEGER,
    start_soc REAL NOT NULL,
    end_soc REAL NOT NULL,
    start_pack_voltage REAL NOT NULL,
    end_pack_voltage REAL NOT NULL,
    measured_ah REAL NOT NULL,
    measured_wh REAL NOT NULL,
    catalogue_ah REAL,
    completed INTEGER NOT NULL DEFAULT 0 CHECK (completed IN (0, 1)),
    automatic INTEGER NOT NULL DEFAULT 0 CHECK (automatic IN (0, 1)),
    gap_seconds INTEGER NOT NULL DEFAULT 0,
    note TEXT NOT NULL DEFAULT '',
    device_id TEXT
  )''',
];
