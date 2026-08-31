// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $DevicesTable extends Devices with TableInfo<$DevicesTable, Device> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _serialNumberMeta = const VerificationMeta(
    'serialNumber',
  );
  @override
  late final GeneratedColumn<String> serialNumber = GeneratedColumn<String>(
    'serial_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _catalogueCapacityAhMeta =
      const VerificationMeta('catalogueCapacityAh');
  @override
  late final GeneratedColumn<double> catalogueCapacityAh =
      GeneratedColumn<double>(
        'catalogue_capacity_ah',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _firstSeenAtMeta = const VerificationMeta(
    'firstSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> firstSeenAt = GeneratedColumn<DateTime>(
    'first_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _demoMeta = const VerificationMeta('demo');
  @override
  late final GeneratedColumn<bool> demo = GeneratedColumn<bool>(
    'demo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("demo" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    serialNumber,
    model,
    catalogueCapacityAh,
    firstSeenAt,
    lastSeenAt,
    demo,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<Device> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('serial_number')) {
      context.handle(
        _serialNumberMeta,
        serialNumber.isAcceptableOrUnknown(
          data['serial_number']!,
          _serialNumberMeta,
        ),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('catalogue_capacity_ah')) {
      context.handle(
        _catalogueCapacityAhMeta,
        catalogueCapacityAh.isAcceptableOrUnknown(
          data['catalogue_capacity_ah']!,
          _catalogueCapacityAhMeta,
        ),
      );
    }
    if (data.containsKey('first_seen_at')) {
      context.handle(
        _firstSeenAtMeta,
        firstSeenAt.isAcceptableOrUnknown(
          data['first_seen_at']!,
          _firstSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstSeenAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    if (data.containsKey('demo')) {
      context.handle(
        _demoMeta,
        demo.isAcceptableOrUnknown(data['demo']!, _demoMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Device map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Device(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      serialNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}serial_number'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      catalogueCapacityAh: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}catalogue_capacity_ah'],
      ),
      firstSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}first_seen_at'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      )!,
      demo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}demo'],
      )!,
    );
  }

  @override
  $DevicesTable createAlias(String alias) {
    return $DevicesTable(attachedDatabase, alias);
  }
}

class Device extends DataClass implements Insertable<Device> {
  final String id;

  /// What the BMS advertises, or whatever the rider renames it to.
  final String name;

  /// From the device info frame, once one has arrived.
  final String serialNumber;
  final String model;

  /// What *this* pack was sold as, or null when nobody has said.
  ///
  /// Nullable, with no default, because a default here is a claim about a
  /// battery nobody made. A new pack used to be born holding 45 Ah -- so
  /// connecting to a 35 Ah bike produced a health figure measured against a
  /// number this app invented, indistinguishable on screen from one the rider
  /// had entered. Unknown has to look like unknown.
  final double? catalogueCapacityAh;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;

  /// True for the simulated pack, so demo data stays in its own world.
  final bool demo;
  const Device({
    required this.id,
    required this.name,
    required this.serialNumber,
    required this.model,
    this.catalogueCapacityAh,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.demo,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['serial_number'] = Variable<String>(serialNumber);
    map['model'] = Variable<String>(model);
    if (!nullToAbsent || catalogueCapacityAh != null) {
      map['catalogue_capacity_ah'] = Variable<double>(catalogueCapacityAh);
    }
    map['first_seen_at'] = Variable<DateTime>(firstSeenAt);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    map['demo'] = Variable<bool>(demo);
    return map;
  }

  DevicesCompanion toCompanion(bool nullToAbsent) {
    return DevicesCompanion(
      id: Value(id),
      name: Value(name),
      serialNumber: Value(serialNumber),
      model: Value(model),
      catalogueCapacityAh: catalogueCapacityAh == null && nullToAbsent
          ? const Value.absent()
          : Value(catalogueCapacityAh),
      firstSeenAt: Value(firstSeenAt),
      lastSeenAt: Value(lastSeenAt),
      demo: Value(demo),
    );
  }

  factory Device.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Device(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      serialNumber: serializer.fromJson<String>(json['serialNumber']),
      model: serializer.fromJson<String>(json['model']),
      catalogueCapacityAh: serializer.fromJson<double?>(
        json['catalogueCapacityAh'],
      ),
      firstSeenAt: serializer.fromJson<DateTime>(json['firstSeenAt']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
      demo: serializer.fromJson<bool>(json['demo']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'serialNumber': serializer.toJson<String>(serialNumber),
      'model': serializer.toJson<String>(model),
      'catalogueCapacityAh': serializer.toJson<double?>(catalogueCapacityAh),
      'firstSeenAt': serializer.toJson<DateTime>(firstSeenAt),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
      'demo': serializer.toJson<bool>(demo),
    };
  }

  Device copyWith({
    String? id,
    String? name,
    String? serialNumber,
    String? model,
    Value<double?> catalogueCapacityAh = const Value.absent(),
    DateTime? firstSeenAt,
    DateTime? lastSeenAt,
    bool? demo,
  }) => Device(
    id: id ?? this.id,
    name: name ?? this.name,
    serialNumber: serialNumber ?? this.serialNumber,
    model: model ?? this.model,
    catalogueCapacityAh: catalogueCapacityAh.present
        ? catalogueCapacityAh.value
        : this.catalogueCapacityAh,
    firstSeenAt: firstSeenAt ?? this.firstSeenAt,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    demo: demo ?? this.demo,
  );
  Device copyWithCompanion(DevicesCompanion data) {
    return Device(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      serialNumber: data.serialNumber.present
          ? data.serialNumber.value
          : this.serialNumber,
      model: data.model.present ? data.model.value : this.model,
      catalogueCapacityAh: data.catalogueCapacityAh.present
          ? data.catalogueCapacityAh.value
          : this.catalogueCapacityAh,
      firstSeenAt: data.firstSeenAt.present
          ? data.firstSeenAt.value
          : this.firstSeenAt,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
      demo: data.demo.present ? data.demo.value : this.demo,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Device(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('serialNumber: $serialNumber, ')
          ..write('model: $model, ')
          ..write('catalogueCapacityAh: $catalogueCapacityAh, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('demo: $demo')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    serialNumber,
    model,
    catalogueCapacityAh,
    firstSeenAt,
    lastSeenAt,
    demo,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Device &&
          other.id == this.id &&
          other.name == this.name &&
          other.serialNumber == this.serialNumber &&
          other.model == this.model &&
          other.catalogueCapacityAh == this.catalogueCapacityAh &&
          other.firstSeenAt == this.firstSeenAt &&
          other.lastSeenAt == this.lastSeenAt &&
          other.demo == this.demo);
}

class DevicesCompanion extends UpdateCompanion<Device> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> serialNumber;
  final Value<String> model;
  final Value<double?> catalogueCapacityAh;
  final Value<DateTime> firstSeenAt;
  final Value<DateTime> lastSeenAt;
  final Value<bool> demo;
  final Value<int> rowid;
  const DevicesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.serialNumber = const Value.absent(),
    this.model = const Value.absent(),
    this.catalogueCapacityAh = const Value.absent(),
    this.firstSeenAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.demo = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DevicesCompanion.insert({
    required String id,
    this.name = const Value.absent(),
    this.serialNumber = const Value.absent(),
    this.model = const Value.absent(),
    this.catalogueCapacityAh = const Value.absent(),
    required DateTime firstSeenAt,
    required DateTime lastSeenAt,
    this.demo = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       firstSeenAt = Value(firstSeenAt),
       lastSeenAt = Value(lastSeenAt);
  static Insertable<Device> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? serialNumber,
    Expression<String>? model,
    Expression<double>? catalogueCapacityAh,
    Expression<DateTime>? firstSeenAt,
    Expression<DateTime>? lastSeenAt,
    Expression<bool>? demo,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (serialNumber != null) 'serial_number': serialNumber,
      if (model != null) 'model': model,
      if (catalogueCapacityAh != null)
        'catalogue_capacity_ah': catalogueCapacityAh,
      if (firstSeenAt != null) 'first_seen_at': firstSeenAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (demo != null) 'demo': demo,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DevicesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? serialNumber,
    Value<String>? model,
    Value<double?>? catalogueCapacityAh,
    Value<DateTime>? firstSeenAt,
    Value<DateTime>? lastSeenAt,
    Value<bool>? demo,
    Value<int>? rowid,
  }) {
    return DevicesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      serialNumber: serialNumber ?? this.serialNumber,
      model: model ?? this.model,
      catalogueCapacityAh: catalogueCapacityAh ?? this.catalogueCapacityAh,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      demo: demo ?? this.demo,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (serialNumber.present) {
      map['serial_number'] = Variable<String>(serialNumber.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (catalogueCapacityAh.present) {
      map['catalogue_capacity_ah'] = Variable<double>(
        catalogueCapacityAh.value,
      );
    }
    if (firstSeenAt.present) {
      map['first_seen_at'] = Variable<DateTime>(firstSeenAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (demo.present) {
      map['demo'] = Variable<bool>(demo.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DevicesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('serialNumber: $serialNumber, ')
          ..write('model: $model, ')
          ..write('catalogueCapacityAh: $catalogueCapacityAh, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('demo: $demo, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TripsTable extends Trips with TableInfo<$TripsTable, Trip> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _distanceKmMeta = const VerificationMeta(
    'distanceKm',
  );
  @override
  late final GeneratedColumn<double> distanceKm = GeneratedColumn<double>(
    'distance_km',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _movingSecondsMeta = const VerificationMeta(
    'movingSeconds',
  );
  @override
  late final GeneratedColumn<int> movingSeconds = GeneratedColumn<int>(
    'moving_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalSecondsMeta = const VerificationMeta(
    'totalSeconds',
  );
  @override
  late final GeneratedColumn<int> totalSeconds = GeneratedColumn<int>(
    'total_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _maxSpeedKmhMeta = const VerificationMeta(
    'maxSpeedKmh',
  );
  @override
  late final GeneratedColumn<double> maxSpeedKmh = GeneratedColumn<double>(
    'max_speed_kmh',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _energyOutWhMeta = const VerificationMeta(
    'energyOutWh',
  );
  @override
  late final GeneratedColumn<double> energyOutWh = GeneratedColumn<double>(
    'energy_out_wh',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _energyInWhMeta = const VerificationMeta(
    'energyInWh',
  );
  @override
  late final GeneratedColumn<double> energyInWh = GeneratedColumn<double>(
    'energy_in_wh',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startSocMeta = const VerificationMeta(
    'startSoc',
  );
  @override
  late final GeneratedColumn<double> startSoc = GeneratedColumn<double>(
    'start_soc',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endSocMeta = const VerificationMeta('endSoc');
  @override
  late final GeneratedColumn<double> endSoc = GeneratedColumn<double>(
    'end_soc',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minPackVoltageMeta = const VerificationMeta(
    'minPackVoltage',
  );
  @override
  late final GeneratedColumn<double> minPackVoltage = GeneratedColumn<double>(
    'min_pack_voltage',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _maxPackVoltageMeta = const VerificationMeta(
    'maxPackVoltage',
  );
  @override
  late final GeneratedColumn<double> maxPackVoltage = GeneratedColumn<double>(
    'max_pack_voltage',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _maxDischargeCurrentMeta =
      const VerificationMeta('maxDischargeCurrent');
  @override
  late final GeneratedColumn<double> maxDischargeCurrent =
      GeneratedColumn<double>(
        'max_discharge_current',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _maxTemperatureMeta = const VerificationMeta(
    'maxTemperature',
  );
  @override
  late final GeneratedColumn<double> maxTemperature = GeneratedColumn<double>(
    'max_temperature',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _maxDeltaVoltsMeta = const VerificationMeta(
    'maxDeltaVolts',
  );
  @override
  late final GeneratedColumn<double> maxDeltaVolts = GeneratedColumn<double>(
    'max_delta_volts',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _climbMMeta = const VerificationMeta('climbM');
  @override
  late final GeneratedColumn<double> climbM = GeneratedColumn<double>(
    'climb_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descentMMeta = const VerificationMeta(
    'descentM',
  );
  @override
  late final GeneratedColumn<double> descentM = GeneratedColumn<double>(
    'descent_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _demoMeta = const VerificationMeta('demo');
  @override
  late final GeneratedColumn<bool> demo = GeneratedColumn<bool>(
    'demo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("demo" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    endedAt,
    distanceKm,
    movingSeconds,
    totalSeconds,
    maxSpeedKmh,
    energyOutWh,
    energyInWh,
    startSoc,
    endSoc,
    minPackVoltage,
    maxPackVoltage,
    maxDischargeCurrent,
    maxTemperature,
    maxDeltaVolts,
    climbM,
    descentM,
    note,
    demo,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trips';
  @override
  VerificationContext validateIntegrity(
    Insertable<Trip> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endedAtMeta);
    }
    if (data.containsKey('distance_km')) {
      context.handle(
        _distanceKmMeta,
        distanceKm.isAcceptableOrUnknown(data['distance_km']!, _distanceKmMeta),
      );
    } else if (isInserting) {
      context.missing(_distanceKmMeta);
    }
    if (data.containsKey('moving_seconds')) {
      context.handle(
        _movingSecondsMeta,
        movingSeconds.isAcceptableOrUnknown(
          data['moving_seconds']!,
          _movingSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_movingSecondsMeta);
    }
    if (data.containsKey('total_seconds')) {
      context.handle(
        _totalSecondsMeta,
        totalSeconds.isAcceptableOrUnknown(
          data['total_seconds']!,
          _totalSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalSecondsMeta);
    }
    if (data.containsKey('max_speed_kmh')) {
      context.handle(
        _maxSpeedKmhMeta,
        maxSpeedKmh.isAcceptableOrUnknown(
          data['max_speed_kmh']!,
          _maxSpeedKmhMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_maxSpeedKmhMeta);
    }
    if (data.containsKey('energy_out_wh')) {
      context.handle(
        _energyOutWhMeta,
        energyOutWh.isAcceptableOrUnknown(
          data['energy_out_wh']!,
          _energyOutWhMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_energyOutWhMeta);
    }
    if (data.containsKey('energy_in_wh')) {
      context.handle(
        _energyInWhMeta,
        energyInWh.isAcceptableOrUnknown(
          data['energy_in_wh']!,
          _energyInWhMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_energyInWhMeta);
    }
    if (data.containsKey('start_soc')) {
      context.handle(
        _startSocMeta,
        startSoc.isAcceptableOrUnknown(data['start_soc']!, _startSocMeta),
      );
    } else if (isInserting) {
      context.missing(_startSocMeta);
    }
    if (data.containsKey('end_soc')) {
      context.handle(
        _endSocMeta,
        endSoc.isAcceptableOrUnknown(data['end_soc']!, _endSocMeta),
      );
    } else if (isInserting) {
      context.missing(_endSocMeta);
    }
    if (data.containsKey('min_pack_voltage')) {
      context.handle(
        _minPackVoltageMeta,
        minPackVoltage.isAcceptableOrUnknown(
          data['min_pack_voltage']!,
          _minPackVoltageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_minPackVoltageMeta);
    }
    if (data.containsKey('max_pack_voltage')) {
      context.handle(
        _maxPackVoltageMeta,
        maxPackVoltage.isAcceptableOrUnknown(
          data['max_pack_voltage']!,
          _maxPackVoltageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_maxPackVoltageMeta);
    }
    if (data.containsKey('max_discharge_current')) {
      context.handle(
        _maxDischargeCurrentMeta,
        maxDischargeCurrent.isAcceptableOrUnknown(
          data['max_discharge_current']!,
          _maxDischargeCurrentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_maxDischargeCurrentMeta);
    }
    if (data.containsKey('max_temperature')) {
      context.handle(
        _maxTemperatureMeta,
        maxTemperature.isAcceptableOrUnknown(
          data['max_temperature']!,
          _maxTemperatureMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_maxTemperatureMeta);
    }
    if (data.containsKey('max_delta_volts')) {
      context.handle(
        _maxDeltaVoltsMeta,
        maxDeltaVolts.isAcceptableOrUnknown(
          data['max_delta_volts']!,
          _maxDeltaVoltsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_maxDeltaVoltsMeta);
    }
    if (data.containsKey('climb_m')) {
      context.handle(
        _climbMMeta,
        climbM.isAcceptableOrUnknown(data['climb_m']!, _climbMMeta),
      );
    } else if (isInserting) {
      context.missing(_climbMMeta);
    }
    if (data.containsKey('descent_m')) {
      context.handle(
        _descentMMeta,
        descentM.isAcceptableOrUnknown(data['descent_m']!, _descentMMeta),
      );
    } else if (isInserting) {
      context.missing(_descentMMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('demo')) {
      context.handle(
        _demoMeta,
        demo.isAcceptableOrUnknown(data['demo']!, _demoMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Trip map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Trip(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      )!,
      distanceKm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance_km'],
      )!,
      movingSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}moving_seconds'],
      )!,
      totalSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_seconds'],
      )!,
      maxSpeedKmh: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_speed_kmh'],
      )!,
      energyOutWh: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}energy_out_wh'],
      )!,
      energyInWh: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}energy_in_wh'],
      )!,
      startSoc: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}start_soc'],
      )!,
      endSoc: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}end_soc'],
      )!,
      minPackVoltage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}min_pack_voltage'],
      )!,
      maxPackVoltage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_pack_voltage'],
      )!,
      maxDischargeCurrent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_discharge_current'],
      )!,
      maxTemperature: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_temperature'],
      )!,
      maxDeltaVolts: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_delta_volts'],
      )!,
      climbM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}climb_m'],
      )!,
      descentM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}descent_m'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      demo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}demo'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
    );
  }

  @override
  $TripsTable createAlias(String alias) {
    return $TripsTable(attachedDatabase, alias);
  }
}

class Trip extends DataClass implements Insertable<Trip> {
  final int id;
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceKm;
  final int movingSeconds;
  final int totalSeconds;
  final double maxSpeedKmh;
  final double energyOutWh;
  final double energyInWh;
  final double startSoc;
  final double endSoc;
  final double minPackVoltage;
  final double maxPackVoltage;
  final double maxDischargeCurrent;
  final double maxTemperature;
  final double maxDeltaVolts;
  final double climbM;
  final double descentM;

  /// Free-text note the rider can add afterwards.
  final String note;

  /// True for a ride recorded against the simulated pack.
  ///
  /// Kept and shown rather than discarded, because a demo ride is useful for
  /// checking the app works. But it is excluded from the range learning and
  /// from the totals: a made-up ride teaching the real range estimate is
  /// exactly the kind of quiet wrongness this app is built to avoid.
  final bool demo;

  /// Which pack this was recorded on. Null for rows written before the app
  /// tracked packs at all -- see [BmsRepository.orphanCounts].
  final String? deviceId;
  const Trip({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.distanceKm,
    required this.movingSeconds,
    required this.totalSeconds,
    required this.maxSpeedKmh,
    required this.energyOutWh,
    required this.energyInWh,
    required this.startSoc,
    required this.endSoc,
    required this.minPackVoltage,
    required this.maxPackVoltage,
    required this.maxDischargeCurrent,
    required this.maxTemperature,
    required this.maxDeltaVolts,
    required this.climbM,
    required this.descentM,
    required this.note,
    required this.demo,
    this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['ended_at'] = Variable<DateTime>(endedAt);
    map['distance_km'] = Variable<double>(distanceKm);
    map['moving_seconds'] = Variable<int>(movingSeconds);
    map['total_seconds'] = Variable<int>(totalSeconds);
    map['max_speed_kmh'] = Variable<double>(maxSpeedKmh);
    map['energy_out_wh'] = Variable<double>(energyOutWh);
    map['energy_in_wh'] = Variable<double>(energyInWh);
    map['start_soc'] = Variable<double>(startSoc);
    map['end_soc'] = Variable<double>(endSoc);
    map['min_pack_voltage'] = Variable<double>(minPackVoltage);
    map['max_pack_voltage'] = Variable<double>(maxPackVoltage);
    map['max_discharge_current'] = Variable<double>(maxDischargeCurrent);
    map['max_temperature'] = Variable<double>(maxTemperature);
    map['max_delta_volts'] = Variable<double>(maxDeltaVolts);
    map['climb_m'] = Variable<double>(climbM);
    map['descent_m'] = Variable<double>(descentM);
    map['note'] = Variable<String>(note);
    map['demo'] = Variable<bool>(demo);
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    return map;
  }

  TripsCompanion toCompanion(bool nullToAbsent) {
    return TripsCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      endedAt: Value(endedAt),
      distanceKm: Value(distanceKm),
      movingSeconds: Value(movingSeconds),
      totalSeconds: Value(totalSeconds),
      maxSpeedKmh: Value(maxSpeedKmh),
      energyOutWh: Value(energyOutWh),
      energyInWh: Value(energyInWh),
      startSoc: Value(startSoc),
      endSoc: Value(endSoc),
      minPackVoltage: Value(minPackVoltage),
      maxPackVoltage: Value(maxPackVoltage),
      maxDischargeCurrent: Value(maxDischargeCurrent),
      maxTemperature: Value(maxTemperature),
      maxDeltaVolts: Value(maxDeltaVolts),
      climbM: Value(climbM),
      descentM: Value(descentM),
      note: Value(note),
      demo: Value(demo),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
    );
  }

  factory Trip.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Trip(
      id: serializer.fromJson<int>(json['id']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime>(json['endedAt']),
      distanceKm: serializer.fromJson<double>(json['distanceKm']),
      movingSeconds: serializer.fromJson<int>(json['movingSeconds']),
      totalSeconds: serializer.fromJson<int>(json['totalSeconds']),
      maxSpeedKmh: serializer.fromJson<double>(json['maxSpeedKmh']),
      energyOutWh: serializer.fromJson<double>(json['energyOutWh']),
      energyInWh: serializer.fromJson<double>(json['energyInWh']),
      startSoc: serializer.fromJson<double>(json['startSoc']),
      endSoc: serializer.fromJson<double>(json['endSoc']),
      minPackVoltage: serializer.fromJson<double>(json['minPackVoltage']),
      maxPackVoltage: serializer.fromJson<double>(json['maxPackVoltage']),
      maxDischargeCurrent: serializer.fromJson<double>(
        json['maxDischargeCurrent'],
      ),
      maxTemperature: serializer.fromJson<double>(json['maxTemperature']),
      maxDeltaVolts: serializer.fromJson<double>(json['maxDeltaVolts']),
      climbM: serializer.fromJson<double>(json['climbM']),
      descentM: serializer.fromJson<double>(json['descentM']),
      note: serializer.fromJson<String>(json['note']),
      demo: serializer.fromJson<bool>(json['demo']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime>(endedAt),
      'distanceKm': serializer.toJson<double>(distanceKm),
      'movingSeconds': serializer.toJson<int>(movingSeconds),
      'totalSeconds': serializer.toJson<int>(totalSeconds),
      'maxSpeedKmh': serializer.toJson<double>(maxSpeedKmh),
      'energyOutWh': serializer.toJson<double>(energyOutWh),
      'energyInWh': serializer.toJson<double>(energyInWh),
      'startSoc': serializer.toJson<double>(startSoc),
      'endSoc': serializer.toJson<double>(endSoc),
      'minPackVoltage': serializer.toJson<double>(minPackVoltage),
      'maxPackVoltage': serializer.toJson<double>(maxPackVoltage),
      'maxDischargeCurrent': serializer.toJson<double>(maxDischargeCurrent),
      'maxTemperature': serializer.toJson<double>(maxTemperature),
      'maxDeltaVolts': serializer.toJson<double>(maxDeltaVolts),
      'climbM': serializer.toJson<double>(climbM),
      'descentM': serializer.toJson<double>(descentM),
      'note': serializer.toJson<String>(note),
      'demo': serializer.toJson<bool>(demo),
      'deviceId': serializer.toJson<String?>(deviceId),
    };
  }

  Trip copyWith({
    int? id,
    DateTime? startedAt,
    DateTime? endedAt,
    double? distanceKm,
    int? movingSeconds,
    int? totalSeconds,
    double? maxSpeedKmh,
    double? energyOutWh,
    double? energyInWh,
    double? startSoc,
    double? endSoc,
    double? minPackVoltage,
    double? maxPackVoltage,
    double? maxDischargeCurrent,
    double? maxTemperature,
    double? maxDeltaVolts,
    double? climbM,
    double? descentM,
    String? note,
    bool? demo,
    Value<String?> deviceId = const Value.absent(),
  }) => Trip(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    distanceKm: distanceKm ?? this.distanceKm,
    movingSeconds: movingSeconds ?? this.movingSeconds,
    totalSeconds: totalSeconds ?? this.totalSeconds,
    maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
    energyOutWh: energyOutWh ?? this.energyOutWh,
    energyInWh: energyInWh ?? this.energyInWh,
    startSoc: startSoc ?? this.startSoc,
    endSoc: endSoc ?? this.endSoc,
    minPackVoltage: minPackVoltage ?? this.minPackVoltage,
    maxPackVoltage: maxPackVoltage ?? this.maxPackVoltage,
    maxDischargeCurrent: maxDischargeCurrent ?? this.maxDischargeCurrent,
    maxTemperature: maxTemperature ?? this.maxTemperature,
    maxDeltaVolts: maxDeltaVolts ?? this.maxDeltaVolts,
    climbM: climbM ?? this.climbM,
    descentM: descentM ?? this.descentM,
    note: note ?? this.note,
    demo: demo ?? this.demo,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
  );
  Trip copyWithCompanion(TripsCompanion data) {
    return Trip(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      distanceKm: data.distanceKm.present
          ? data.distanceKm.value
          : this.distanceKm,
      movingSeconds: data.movingSeconds.present
          ? data.movingSeconds.value
          : this.movingSeconds,
      totalSeconds: data.totalSeconds.present
          ? data.totalSeconds.value
          : this.totalSeconds,
      maxSpeedKmh: data.maxSpeedKmh.present
          ? data.maxSpeedKmh.value
          : this.maxSpeedKmh,
      energyOutWh: data.energyOutWh.present
          ? data.energyOutWh.value
          : this.energyOutWh,
      energyInWh: data.energyInWh.present
          ? data.energyInWh.value
          : this.energyInWh,
      startSoc: data.startSoc.present ? data.startSoc.value : this.startSoc,
      endSoc: data.endSoc.present ? data.endSoc.value : this.endSoc,
      minPackVoltage: data.minPackVoltage.present
          ? data.minPackVoltage.value
          : this.minPackVoltage,
      maxPackVoltage: data.maxPackVoltage.present
          ? data.maxPackVoltage.value
          : this.maxPackVoltage,
      maxDischargeCurrent: data.maxDischargeCurrent.present
          ? data.maxDischargeCurrent.value
          : this.maxDischargeCurrent,
      maxTemperature: data.maxTemperature.present
          ? data.maxTemperature.value
          : this.maxTemperature,
      maxDeltaVolts: data.maxDeltaVolts.present
          ? data.maxDeltaVolts.value
          : this.maxDeltaVolts,
      climbM: data.climbM.present ? data.climbM.value : this.climbM,
      descentM: data.descentM.present ? data.descentM.value : this.descentM,
      note: data.note.present ? data.note.value : this.note,
      demo: data.demo.present ? data.demo.value : this.demo,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Trip(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('distanceKm: $distanceKm, ')
          ..write('movingSeconds: $movingSeconds, ')
          ..write('totalSeconds: $totalSeconds, ')
          ..write('maxSpeedKmh: $maxSpeedKmh, ')
          ..write('energyOutWh: $energyOutWh, ')
          ..write('energyInWh: $energyInWh, ')
          ..write('startSoc: $startSoc, ')
          ..write('endSoc: $endSoc, ')
          ..write('minPackVoltage: $minPackVoltage, ')
          ..write('maxPackVoltage: $maxPackVoltage, ')
          ..write('maxDischargeCurrent: $maxDischargeCurrent, ')
          ..write('maxTemperature: $maxTemperature, ')
          ..write('maxDeltaVolts: $maxDeltaVolts, ')
          ..write('climbM: $climbM, ')
          ..write('descentM: $descentM, ')
          ..write('note: $note, ')
          ..write('demo: $demo, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    startedAt,
    endedAt,
    distanceKm,
    movingSeconds,
    totalSeconds,
    maxSpeedKmh,
    energyOutWh,
    energyInWh,
    startSoc,
    endSoc,
    minPackVoltage,
    maxPackVoltage,
    maxDischargeCurrent,
    maxTemperature,
    maxDeltaVolts,
    climbM,
    descentM,
    note,
    demo,
    deviceId,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Trip &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.distanceKm == this.distanceKm &&
          other.movingSeconds == this.movingSeconds &&
          other.totalSeconds == this.totalSeconds &&
          other.maxSpeedKmh == this.maxSpeedKmh &&
          other.energyOutWh == this.energyOutWh &&
          other.energyInWh == this.energyInWh &&
          other.startSoc == this.startSoc &&
          other.endSoc == this.endSoc &&
          other.minPackVoltage == this.minPackVoltage &&
          other.maxPackVoltage == this.maxPackVoltage &&
          other.maxDischargeCurrent == this.maxDischargeCurrent &&
          other.maxTemperature == this.maxTemperature &&
          other.maxDeltaVolts == this.maxDeltaVolts &&
          other.climbM == this.climbM &&
          other.descentM == this.descentM &&
          other.note == this.note &&
          other.demo == this.demo &&
          other.deviceId == this.deviceId);
}

class TripsCompanion extends UpdateCompanion<Trip> {
  final Value<int> id;
  final Value<DateTime> startedAt;
  final Value<DateTime> endedAt;
  final Value<double> distanceKm;
  final Value<int> movingSeconds;
  final Value<int> totalSeconds;
  final Value<double> maxSpeedKmh;
  final Value<double> energyOutWh;
  final Value<double> energyInWh;
  final Value<double> startSoc;
  final Value<double> endSoc;
  final Value<double> minPackVoltage;
  final Value<double> maxPackVoltage;
  final Value<double> maxDischargeCurrent;
  final Value<double> maxTemperature;
  final Value<double> maxDeltaVolts;
  final Value<double> climbM;
  final Value<double> descentM;
  final Value<String> note;
  final Value<bool> demo;
  final Value<String?> deviceId;
  const TripsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.distanceKm = const Value.absent(),
    this.movingSeconds = const Value.absent(),
    this.totalSeconds = const Value.absent(),
    this.maxSpeedKmh = const Value.absent(),
    this.energyOutWh = const Value.absent(),
    this.energyInWh = const Value.absent(),
    this.startSoc = const Value.absent(),
    this.endSoc = const Value.absent(),
    this.minPackVoltage = const Value.absent(),
    this.maxPackVoltage = const Value.absent(),
    this.maxDischargeCurrent = const Value.absent(),
    this.maxTemperature = const Value.absent(),
    this.maxDeltaVolts = const Value.absent(),
    this.climbM = const Value.absent(),
    this.descentM = const Value.absent(),
    this.note = const Value.absent(),
    this.demo = const Value.absent(),
    this.deviceId = const Value.absent(),
  });
  TripsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime startedAt,
    required DateTime endedAt,
    required double distanceKm,
    required int movingSeconds,
    required int totalSeconds,
    required double maxSpeedKmh,
    required double energyOutWh,
    required double energyInWh,
    required double startSoc,
    required double endSoc,
    required double minPackVoltage,
    required double maxPackVoltage,
    required double maxDischargeCurrent,
    required double maxTemperature,
    required double maxDeltaVolts,
    required double climbM,
    required double descentM,
    this.note = const Value.absent(),
    this.demo = const Value.absent(),
    this.deviceId = const Value.absent(),
  }) : startedAt = Value(startedAt),
       endedAt = Value(endedAt),
       distanceKm = Value(distanceKm),
       movingSeconds = Value(movingSeconds),
       totalSeconds = Value(totalSeconds),
       maxSpeedKmh = Value(maxSpeedKmh),
       energyOutWh = Value(energyOutWh),
       energyInWh = Value(energyInWh),
       startSoc = Value(startSoc),
       endSoc = Value(endSoc),
       minPackVoltage = Value(minPackVoltage),
       maxPackVoltage = Value(maxPackVoltage),
       maxDischargeCurrent = Value(maxDischargeCurrent),
       maxTemperature = Value(maxTemperature),
       maxDeltaVolts = Value(maxDeltaVolts),
       climbM = Value(climbM),
       descentM = Value(descentM);
  static Insertable<Trip> custom({
    Expression<int>? id,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<double>? distanceKm,
    Expression<int>? movingSeconds,
    Expression<int>? totalSeconds,
    Expression<double>? maxSpeedKmh,
    Expression<double>? energyOutWh,
    Expression<double>? energyInWh,
    Expression<double>? startSoc,
    Expression<double>? endSoc,
    Expression<double>? minPackVoltage,
    Expression<double>? maxPackVoltage,
    Expression<double>? maxDischargeCurrent,
    Expression<double>? maxTemperature,
    Expression<double>? maxDeltaVolts,
    Expression<double>? climbM,
    Expression<double>? descentM,
    Expression<String>? note,
    Expression<bool>? demo,
    Expression<String>? deviceId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (movingSeconds != null) 'moving_seconds': movingSeconds,
      if (totalSeconds != null) 'total_seconds': totalSeconds,
      if (maxSpeedKmh != null) 'max_speed_kmh': maxSpeedKmh,
      if (energyOutWh != null) 'energy_out_wh': energyOutWh,
      if (energyInWh != null) 'energy_in_wh': energyInWh,
      if (startSoc != null) 'start_soc': startSoc,
      if (endSoc != null) 'end_soc': endSoc,
      if (minPackVoltage != null) 'min_pack_voltage': minPackVoltage,
      if (maxPackVoltage != null) 'max_pack_voltage': maxPackVoltage,
      if (maxDischargeCurrent != null)
        'max_discharge_current': maxDischargeCurrent,
      if (maxTemperature != null) 'max_temperature': maxTemperature,
      if (maxDeltaVolts != null) 'max_delta_volts': maxDeltaVolts,
      if (climbM != null) 'climb_m': climbM,
      if (descentM != null) 'descent_m': descentM,
      if (note != null) 'note': note,
      if (demo != null) 'demo': demo,
      if (deviceId != null) 'device_id': deviceId,
    });
  }

  TripsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? startedAt,
    Value<DateTime>? endedAt,
    Value<double>? distanceKm,
    Value<int>? movingSeconds,
    Value<int>? totalSeconds,
    Value<double>? maxSpeedKmh,
    Value<double>? energyOutWh,
    Value<double>? energyInWh,
    Value<double>? startSoc,
    Value<double>? endSoc,
    Value<double>? minPackVoltage,
    Value<double>? maxPackVoltage,
    Value<double>? maxDischargeCurrent,
    Value<double>? maxTemperature,
    Value<double>? maxDeltaVolts,
    Value<double>? climbM,
    Value<double>? descentM,
    Value<String>? note,
    Value<bool>? demo,
    Value<String?>? deviceId,
  }) {
    return TripsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      distanceKm: distanceKm ?? this.distanceKm,
      movingSeconds: movingSeconds ?? this.movingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      energyOutWh: energyOutWh ?? this.energyOutWh,
      energyInWh: energyInWh ?? this.energyInWh,
      startSoc: startSoc ?? this.startSoc,
      endSoc: endSoc ?? this.endSoc,
      minPackVoltage: minPackVoltage ?? this.minPackVoltage,
      maxPackVoltage: maxPackVoltage ?? this.maxPackVoltage,
      maxDischargeCurrent: maxDischargeCurrent ?? this.maxDischargeCurrent,
      maxTemperature: maxTemperature ?? this.maxTemperature,
      maxDeltaVolts: maxDeltaVolts ?? this.maxDeltaVolts,
      climbM: climbM ?? this.climbM,
      descentM: descentM ?? this.descentM,
      note: note ?? this.note,
      demo: demo ?? this.demo,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (distanceKm.present) {
      map['distance_km'] = Variable<double>(distanceKm.value);
    }
    if (movingSeconds.present) {
      map['moving_seconds'] = Variable<int>(movingSeconds.value);
    }
    if (totalSeconds.present) {
      map['total_seconds'] = Variable<int>(totalSeconds.value);
    }
    if (maxSpeedKmh.present) {
      map['max_speed_kmh'] = Variable<double>(maxSpeedKmh.value);
    }
    if (energyOutWh.present) {
      map['energy_out_wh'] = Variable<double>(energyOutWh.value);
    }
    if (energyInWh.present) {
      map['energy_in_wh'] = Variable<double>(energyInWh.value);
    }
    if (startSoc.present) {
      map['start_soc'] = Variable<double>(startSoc.value);
    }
    if (endSoc.present) {
      map['end_soc'] = Variable<double>(endSoc.value);
    }
    if (minPackVoltage.present) {
      map['min_pack_voltage'] = Variable<double>(minPackVoltage.value);
    }
    if (maxPackVoltage.present) {
      map['max_pack_voltage'] = Variable<double>(maxPackVoltage.value);
    }
    if (maxDischargeCurrent.present) {
      map['max_discharge_current'] = Variable<double>(
        maxDischargeCurrent.value,
      );
    }
    if (maxTemperature.present) {
      map['max_temperature'] = Variable<double>(maxTemperature.value);
    }
    if (maxDeltaVolts.present) {
      map['max_delta_volts'] = Variable<double>(maxDeltaVolts.value);
    }
    if (climbM.present) {
      map['climb_m'] = Variable<double>(climbM.value);
    }
    if (descentM.present) {
      map['descent_m'] = Variable<double>(descentM.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (demo.present) {
      map['demo'] = Variable<bool>(demo.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('distanceKm: $distanceKm, ')
          ..write('movingSeconds: $movingSeconds, ')
          ..write('totalSeconds: $totalSeconds, ')
          ..write('maxSpeedKmh: $maxSpeedKmh, ')
          ..write('energyOutWh: $energyOutWh, ')
          ..write('energyInWh: $energyInWh, ')
          ..write('startSoc: $startSoc, ')
          ..write('endSoc: $endSoc, ')
          ..write('minPackVoltage: $minPackVoltage, ')
          ..write('maxPackVoltage: $maxPackVoltage, ')
          ..write('maxDischargeCurrent: $maxDischargeCurrent, ')
          ..write('maxTemperature: $maxTemperature, ')
          ..write('maxDeltaVolts: $maxDeltaVolts, ')
          ..write('climbM: $climbM, ')
          ..write('descentM: $descentM, ')
          ..write('note: $note, ')
          ..write('demo: $demo, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }
}

class $TripPointsTable extends TripPoints
    with TableInfo<$TripPointsTable, TripPoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripPointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<int> tripId = GeneratedColumn<int>(
    'trip_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES trips (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _speedKmhMeta = const VerificationMeta(
    'speedKmh',
  );
  @override
  late final GeneratedColumn<double> speedKmh = GeneratedColumn<double>(
    'speed_kmh',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _altitudeMMeta = const VerificationMeta(
    'altitudeM',
  );
  @override
  late final GeneratedColumn<double> altitudeM = GeneratedColumn<double>(
    'altitude_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _packVoltageMeta = const VerificationMeta(
    'packVoltage',
  );
  @override
  late final GeneratedColumn<double> packVoltage = GeneratedColumn<double>(
    'pack_voltage',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentMeta = const VerificationMeta(
    'current',
  );
  @override
  late final GeneratedColumn<double> current = GeneratedColumn<double>(
    'current',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _socMeta = const VerificationMeta('soc');
  @override
  late final GeneratedColumn<double> soc = GeneratedColumn<double>(
    'soc',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tripId,
    timestamp,
    latitude,
    longitude,
    speedKmh,
    altitudeM,
    packVoltage,
    current,
    soc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trip_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<TripPoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('speed_kmh')) {
      context.handle(
        _speedKmhMeta,
        speedKmh.isAcceptableOrUnknown(data['speed_kmh']!, _speedKmhMeta),
      );
    } else if (isInserting) {
      context.missing(_speedKmhMeta);
    }
    if (data.containsKey('altitude_m')) {
      context.handle(
        _altitudeMMeta,
        altitudeM.isAcceptableOrUnknown(data['altitude_m']!, _altitudeMMeta),
      );
    } else if (isInserting) {
      context.missing(_altitudeMMeta);
    }
    if (data.containsKey('pack_voltage')) {
      context.handle(
        _packVoltageMeta,
        packVoltage.isAcceptableOrUnknown(
          data['pack_voltage']!,
          _packVoltageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_packVoltageMeta);
    }
    if (data.containsKey('current')) {
      context.handle(
        _currentMeta,
        current.isAcceptableOrUnknown(data['current']!, _currentMeta),
      );
    } else if (isInserting) {
      context.missing(_currentMeta);
    }
    if (data.containsKey('soc')) {
      context.handle(
        _socMeta,
        soc.isAcceptableOrUnknown(data['soc']!, _socMeta),
      );
    } else if (isInserting) {
      context.missing(_socMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TripPoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TripPoint(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trip_id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      speedKmh: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed_kmh'],
      )!,
      altitudeM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}altitude_m'],
      )!,
      packVoltage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pack_voltage'],
      )!,
      current: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}current'],
      )!,
      soc: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}soc'],
      )!,
    );
  }

  @override
  $TripPointsTable createAlias(String alias) {
    return $TripPointsTable(attachedDatabase, alias);
  }
}

class TripPoint extends DataClass implements Insertable<TripPoint> {
  final int id;
  final int tripId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double speedKmh;

  /// Smoothed altitude, in metres. See [AltitudeTracker] for why it is not raw.
  final double altitudeM;
  final double packVoltage;
  final double current;
  final double soc;
  const TripPoint({
    required this.id,
    required this.tripId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.altitudeM,
    required this.packVoltage,
    required this.current,
    required this.soc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trip_id'] = Variable<int>(tripId);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['speed_kmh'] = Variable<double>(speedKmh);
    map['altitude_m'] = Variable<double>(altitudeM);
    map['pack_voltage'] = Variable<double>(packVoltage);
    map['current'] = Variable<double>(current);
    map['soc'] = Variable<double>(soc);
    return map;
  }

  TripPointsCompanion toCompanion(bool nullToAbsent) {
    return TripPointsCompanion(
      id: Value(id),
      tripId: Value(tripId),
      timestamp: Value(timestamp),
      latitude: Value(latitude),
      longitude: Value(longitude),
      speedKmh: Value(speedKmh),
      altitudeM: Value(altitudeM),
      packVoltage: Value(packVoltage),
      current: Value(current),
      soc: Value(soc),
    );
  }

  factory TripPoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TripPoint(
      id: serializer.fromJson<int>(json['id']),
      tripId: serializer.fromJson<int>(json['tripId']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      speedKmh: serializer.fromJson<double>(json['speedKmh']),
      altitudeM: serializer.fromJson<double>(json['altitudeM']),
      packVoltage: serializer.fromJson<double>(json['packVoltage']),
      current: serializer.fromJson<double>(json['current']),
      soc: serializer.fromJson<double>(json['soc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tripId': serializer.toJson<int>(tripId),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'speedKmh': serializer.toJson<double>(speedKmh),
      'altitudeM': serializer.toJson<double>(altitudeM),
      'packVoltage': serializer.toJson<double>(packVoltage),
      'current': serializer.toJson<double>(current),
      'soc': serializer.toJson<double>(soc),
    };
  }

  TripPoint copyWith({
    int? id,
    int? tripId,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    double? speedKmh,
    double? altitudeM,
    double? packVoltage,
    double? current,
    double? soc,
  }) => TripPoint(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    timestamp: timestamp ?? this.timestamp,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    speedKmh: speedKmh ?? this.speedKmh,
    altitudeM: altitudeM ?? this.altitudeM,
    packVoltage: packVoltage ?? this.packVoltage,
    current: current ?? this.current,
    soc: soc ?? this.soc,
  );
  TripPoint copyWithCompanion(TripPointsCompanion data) {
    return TripPoint(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      speedKmh: data.speedKmh.present ? data.speedKmh.value : this.speedKmh,
      altitudeM: data.altitudeM.present ? data.altitudeM.value : this.altitudeM,
      packVoltage: data.packVoltage.present
          ? data.packVoltage.value
          : this.packVoltage,
      current: data.current.present ? data.current.value : this.current,
      soc: data.soc.present ? data.soc.value : this.soc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TripPoint(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('timestamp: $timestamp, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('speedKmh: $speedKmh, ')
          ..write('altitudeM: $altitudeM, ')
          ..write('packVoltage: $packVoltage, ')
          ..write('current: $current, ')
          ..write('soc: $soc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tripId,
    timestamp,
    latitude,
    longitude,
    speedKmh,
    altitudeM,
    packVoltage,
    current,
    soc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TripPoint &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.timestamp == this.timestamp &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.speedKmh == this.speedKmh &&
          other.altitudeM == this.altitudeM &&
          other.packVoltage == this.packVoltage &&
          other.current == this.current &&
          other.soc == this.soc);
}

class TripPointsCompanion extends UpdateCompanion<TripPoint> {
  final Value<int> id;
  final Value<int> tripId;
  final Value<DateTime> timestamp;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<double> speedKmh;
  final Value<double> altitudeM;
  final Value<double> packVoltage;
  final Value<double> current;
  final Value<double> soc;
  const TripPointsCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.speedKmh = const Value.absent(),
    this.altitudeM = const Value.absent(),
    this.packVoltage = const Value.absent(),
    this.current = const Value.absent(),
    this.soc = const Value.absent(),
  });
  TripPointsCompanion.insert({
    this.id = const Value.absent(),
    required int tripId,
    required DateTime timestamp,
    required double latitude,
    required double longitude,
    required double speedKmh,
    required double altitudeM,
    required double packVoltage,
    required double current,
    required double soc,
  }) : tripId = Value(tripId),
       timestamp = Value(timestamp),
       latitude = Value(latitude),
       longitude = Value(longitude),
       speedKmh = Value(speedKmh),
       altitudeM = Value(altitudeM),
       packVoltage = Value(packVoltage),
       current = Value(current),
       soc = Value(soc);
  static Insertable<TripPoint> custom({
    Expression<int>? id,
    Expression<int>? tripId,
    Expression<DateTime>? timestamp,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? speedKmh,
    Expression<double>? altitudeM,
    Expression<double>? packVoltage,
    Expression<double>? current,
    Expression<double>? soc,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (timestamp != null) 'timestamp': timestamp,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (speedKmh != null) 'speed_kmh': speedKmh,
      if (altitudeM != null) 'altitude_m': altitudeM,
      if (packVoltage != null) 'pack_voltage': packVoltage,
      if (current != null) 'current': current,
      if (soc != null) 'soc': soc,
    });
  }

  TripPointsCompanion copyWith({
    Value<int>? id,
    Value<int>? tripId,
    Value<DateTime>? timestamp,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<double>? speedKmh,
    Value<double>? altitudeM,
    Value<double>? packVoltage,
    Value<double>? current,
    Value<double>? soc,
  }) {
    return TripPointsCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speedKmh: speedKmh ?? this.speedKmh,
      altitudeM: altitudeM ?? this.altitudeM,
      packVoltage: packVoltage ?? this.packVoltage,
      current: current ?? this.current,
      soc: soc ?? this.soc,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<int>(tripId.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (speedKmh.present) {
      map['speed_kmh'] = Variable<double>(speedKmh.value);
    }
    if (altitudeM.present) {
      map['altitude_m'] = Variable<double>(altitudeM.value);
    }
    if (packVoltage.present) {
      map['pack_voltage'] = Variable<double>(packVoltage.value);
    }
    if (current.present) {
      map['current'] = Variable<double>(current.value);
    }
    if (soc.present) {
      map['soc'] = Variable<double>(soc.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripPointsCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('timestamp: $timestamp, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('speedKmh: $speedKmh, ')
          ..write('altitudeM: $altitudeM, ')
          ..write('packVoltage: $packVoltage, ')
          ..write('current: $current, ')
          ..write('soc: $soc')
          ..write(')'))
        .toString();
  }
}

class $SnapshotsTable extends Snapshots
    with TableInfo<$SnapshotsTable, Snapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<int> tripId = GeneratedColumn<int>(
    'trip_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _packVoltageMeta = const VerificationMeta(
    'packVoltage',
  );
  @override
  late final GeneratedColumn<double> packVoltage = GeneratedColumn<double>(
    'pack_voltage',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentMeta = const VerificationMeta(
    'current',
  );
  @override
  late final GeneratedColumn<double> current = GeneratedColumn<double>(
    'current',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _socMeta = const VerificationMeta('soc');
  @override
  late final GeneratedColumn<double> soc = GeneratedColumn<double>(
    'soc',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sohMeta = const VerificationMeta('soh');
  @override
  late final GeneratedColumn<double> soh = GeneratedColumn<double>(
    'soh',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remainingAhMeta = const VerificationMeta(
    'remainingAh',
  );
  @override
  late final GeneratedColumn<double> remainingAh = GeneratedColumn<double>(
    'remaining_ah',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cycleCountMeta = const VerificationMeta(
    'cycleCount',
  );
  @override
  late final GeneratedColumn<double> cycleCount = GeneratedColumn<double>(
    'cycle_count',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deltaVoltsMeta = const VerificationMeta(
    'deltaVolts',
  );
  @override
  late final GeneratedColumn<double> deltaVolts = GeneratedColumn<double>(
    'delta_volts',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minCellVoltageMeta = const VerificationMeta(
    'minCellVoltage',
  );
  @override
  late final GeneratedColumn<double> minCellVoltage = GeneratedColumn<double>(
    'min_cell_voltage',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _maxCellVoltageMeta = const VerificationMeta(
    'maxCellVoltage',
  );
  @override
  late final GeneratedColumn<double> maxCellVoltage = GeneratedColumn<double>(
    'max_cell_voltage',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _maxTemperatureMeta = const VerificationMeta(
    'maxTemperature',
  );
  @override
  late final GeneratedColumn<double> maxTemperature = GeneratedColumn<double>(
    'max_temperature',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mosfetTempMeta = const VerificationMeta(
    'mosfetTemp',
  );
  @override
  late final GeneratedColumn<double> mosfetTemp = GeneratedColumn<double>(
    'mosfet_temp',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _warningsMaskMeta = const VerificationMeta(
    'warningsMask',
  );
  @override
  late final GeneratedColumn<int> warningsMask = GeneratedColumn<int>(
    'warnings_mask',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _balancerActiveMeta = const VerificationMeta(
    'balancerActive',
  );
  @override
  late final GeneratedColumn<bool> balancerActive = GeneratedColumn<bool>(
    'balancer_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("balancer_active" IN (0, 1))',
    ),
  );
  static const VerificationMeta _cellVoltagesJsonMeta = const VerificationMeta(
    'cellVoltagesJson',
  );
  @override
  late final GeneratedColumn<String> cellVoltagesJson = GeneratedColumn<String>(
    'cell_voltages_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    timestamp,
    tripId,
    packVoltage,
    current,
    soc,
    soh,
    remainingAh,
    cycleCount,
    deltaVolts,
    minCellVoltage,
    maxCellVoltage,
    maxTemperature,
    mosfetTemp,
    warningsMask,
    balancerActive,
    cellVoltagesJson,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<Snapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    }
    if (data.containsKey('pack_voltage')) {
      context.handle(
        _packVoltageMeta,
        packVoltage.isAcceptableOrUnknown(
          data['pack_voltage']!,
          _packVoltageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_packVoltageMeta);
    }
    if (data.containsKey('current')) {
      context.handle(
        _currentMeta,
        current.isAcceptableOrUnknown(data['current']!, _currentMeta),
      );
    } else if (isInserting) {
      context.missing(_currentMeta);
    }
    if (data.containsKey('soc')) {
      context.handle(
        _socMeta,
        soc.isAcceptableOrUnknown(data['soc']!, _socMeta),
      );
    } else if (isInserting) {
      context.missing(_socMeta);
    }
    if (data.containsKey('soh')) {
      context.handle(
        _sohMeta,
        soh.isAcceptableOrUnknown(data['soh']!, _sohMeta),
      );
    } else if (isInserting) {
      context.missing(_sohMeta);
    }
    if (data.containsKey('remaining_ah')) {
      context.handle(
        _remainingAhMeta,
        remainingAh.isAcceptableOrUnknown(
          data['remaining_ah']!,
          _remainingAhMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remainingAhMeta);
    }
    if (data.containsKey('cycle_count')) {
      context.handle(
        _cycleCountMeta,
        cycleCount.isAcceptableOrUnknown(data['cycle_count']!, _cycleCountMeta),
      );
    } else if (isInserting) {
      context.missing(_cycleCountMeta);
    }
    if (data.containsKey('delta_volts')) {
      context.handle(
        _deltaVoltsMeta,
        deltaVolts.isAcceptableOrUnknown(data['delta_volts']!, _deltaVoltsMeta),
      );
    } else if (isInserting) {
      context.missing(_deltaVoltsMeta);
    }
    if (data.containsKey('min_cell_voltage')) {
      context.handle(
        _minCellVoltageMeta,
        minCellVoltage.isAcceptableOrUnknown(
          data['min_cell_voltage']!,
          _minCellVoltageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_minCellVoltageMeta);
    }
    if (data.containsKey('max_cell_voltage')) {
      context.handle(
        _maxCellVoltageMeta,
        maxCellVoltage.isAcceptableOrUnknown(
          data['max_cell_voltage']!,
          _maxCellVoltageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_maxCellVoltageMeta);
    }
    if (data.containsKey('max_temperature')) {
      context.handle(
        _maxTemperatureMeta,
        maxTemperature.isAcceptableOrUnknown(
          data['max_temperature']!,
          _maxTemperatureMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_maxTemperatureMeta);
    }
    if (data.containsKey('mosfet_temp')) {
      context.handle(
        _mosfetTempMeta,
        mosfetTemp.isAcceptableOrUnknown(data['mosfet_temp']!, _mosfetTempMeta),
      );
    }
    if (data.containsKey('warnings_mask')) {
      context.handle(
        _warningsMaskMeta,
        warningsMask.isAcceptableOrUnknown(
          data['warnings_mask']!,
          _warningsMaskMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_warningsMaskMeta);
    }
    if (data.containsKey('balancer_active')) {
      context.handle(
        _balancerActiveMeta,
        balancerActive.isAcceptableOrUnknown(
          data['balancer_active']!,
          _balancerActiveMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_balancerActiveMeta);
    }
    if (data.containsKey('cell_voltages_json')) {
      context.handle(
        _cellVoltagesJsonMeta,
        cellVoltagesJson.isAcceptableOrUnknown(
          data['cell_voltages_json']!,
          _cellVoltagesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cellVoltagesJsonMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Snapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Snapshot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trip_id'],
      ),
      packVoltage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pack_voltage'],
      )!,
      current: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}current'],
      )!,
      soc: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}soc'],
      )!,
      soh: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}soh'],
      )!,
      remainingAh: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}remaining_ah'],
      )!,
      cycleCount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cycle_count'],
      )!,
      deltaVolts: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}delta_volts'],
      )!,
      minCellVoltage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}min_cell_voltage'],
      )!,
      maxCellVoltage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_cell_voltage'],
      )!,
      maxTemperature: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_temperature'],
      )!,
      mosfetTemp: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mosfet_temp'],
      ),
      warningsMask: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}warnings_mask'],
      )!,
      balancerActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}balancer_active'],
      )!,
      cellVoltagesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cell_voltages_json'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
    );
  }

  @override
  $SnapshotsTable createAlias(String alias) {
    return $SnapshotsTable(attachedDatabase, alias);
  }
}

class Snapshot extends DataClass implements Insertable<Snapshot> {
  final int id;
  final DateTime timestamp;
  final int? tripId;
  final double packVoltage;
  final double current;
  final double soc;
  final double soh;
  final double remainingAh;
  final double cycleCount;
  final double deltaVolts;
  final double minCellVoltage;
  final double maxCellVoltage;
  final double maxTemperature;
  final double? mosfetTemp;
  final int warningsMask;
  final bool balancerActive;

  /// Cell voltages as a JSON array. A column per cell would mean a schema
  /// migration every time a pack with a different cell count turns up.
  final String cellVoltagesJson;

  /// Which pack this was recorded on. Null for rows written before the app
  /// tracked packs at all -- see [BmsRepository.orphanCounts].
  final String? deviceId;
  const Snapshot({
    required this.id,
    required this.timestamp,
    this.tripId,
    required this.packVoltage,
    required this.current,
    required this.soc,
    required this.soh,
    required this.remainingAh,
    required this.cycleCount,
    required this.deltaVolts,
    required this.minCellVoltage,
    required this.maxCellVoltage,
    required this.maxTemperature,
    this.mosfetTemp,
    required this.warningsMask,
    required this.balancerActive,
    required this.cellVoltagesJson,
    this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    if (!nullToAbsent || tripId != null) {
      map['trip_id'] = Variable<int>(tripId);
    }
    map['pack_voltage'] = Variable<double>(packVoltage);
    map['current'] = Variable<double>(current);
    map['soc'] = Variable<double>(soc);
    map['soh'] = Variable<double>(soh);
    map['remaining_ah'] = Variable<double>(remainingAh);
    map['cycle_count'] = Variable<double>(cycleCount);
    map['delta_volts'] = Variable<double>(deltaVolts);
    map['min_cell_voltage'] = Variable<double>(minCellVoltage);
    map['max_cell_voltage'] = Variable<double>(maxCellVoltage);
    map['max_temperature'] = Variable<double>(maxTemperature);
    if (!nullToAbsent || mosfetTemp != null) {
      map['mosfet_temp'] = Variable<double>(mosfetTemp);
    }
    map['warnings_mask'] = Variable<int>(warningsMask);
    map['balancer_active'] = Variable<bool>(balancerActive);
    map['cell_voltages_json'] = Variable<String>(cellVoltagesJson);
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    return map;
  }

  SnapshotsCompanion toCompanion(bool nullToAbsent) {
    return SnapshotsCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      tripId: tripId == null && nullToAbsent
          ? const Value.absent()
          : Value(tripId),
      packVoltage: Value(packVoltage),
      current: Value(current),
      soc: Value(soc),
      soh: Value(soh),
      remainingAh: Value(remainingAh),
      cycleCount: Value(cycleCount),
      deltaVolts: Value(deltaVolts),
      minCellVoltage: Value(minCellVoltage),
      maxCellVoltage: Value(maxCellVoltage),
      maxTemperature: Value(maxTemperature),
      mosfetTemp: mosfetTemp == null && nullToAbsent
          ? const Value.absent()
          : Value(mosfetTemp),
      warningsMask: Value(warningsMask),
      balancerActive: Value(balancerActive),
      cellVoltagesJson: Value(cellVoltagesJson),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
    );
  }

  factory Snapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Snapshot(
      id: serializer.fromJson<int>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      tripId: serializer.fromJson<int?>(json['tripId']),
      packVoltage: serializer.fromJson<double>(json['packVoltage']),
      current: serializer.fromJson<double>(json['current']),
      soc: serializer.fromJson<double>(json['soc']),
      soh: serializer.fromJson<double>(json['soh']),
      remainingAh: serializer.fromJson<double>(json['remainingAh']),
      cycleCount: serializer.fromJson<double>(json['cycleCount']),
      deltaVolts: serializer.fromJson<double>(json['deltaVolts']),
      minCellVoltage: serializer.fromJson<double>(json['minCellVoltage']),
      maxCellVoltage: serializer.fromJson<double>(json['maxCellVoltage']),
      maxTemperature: serializer.fromJson<double>(json['maxTemperature']),
      mosfetTemp: serializer.fromJson<double?>(json['mosfetTemp']),
      warningsMask: serializer.fromJson<int>(json['warningsMask']),
      balancerActive: serializer.fromJson<bool>(json['balancerActive']),
      cellVoltagesJson: serializer.fromJson<String>(json['cellVoltagesJson']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'tripId': serializer.toJson<int?>(tripId),
      'packVoltage': serializer.toJson<double>(packVoltage),
      'current': serializer.toJson<double>(current),
      'soc': serializer.toJson<double>(soc),
      'soh': serializer.toJson<double>(soh),
      'remainingAh': serializer.toJson<double>(remainingAh),
      'cycleCount': serializer.toJson<double>(cycleCount),
      'deltaVolts': serializer.toJson<double>(deltaVolts),
      'minCellVoltage': serializer.toJson<double>(minCellVoltage),
      'maxCellVoltage': serializer.toJson<double>(maxCellVoltage),
      'maxTemperature': serializer.toJson<double>(maxTemperature),
      'mosfetTemp': serializer.toJson<double?>(mosfetTemp),
      'warningsMask': serializer.toJson<int>(warningsMask),
      'balancerActive': serializer.toJson<bool>(balancerActive),
      'cellVoltagesJson': serializer.toJson<String>(cellVoltagesJson),
      'deviceId': serializer.toJson<String?>(deviceId),
    };
  }

  Snapshot copyWith({
    int? id,
    DateTime? timestamp,
    Value<int?> tripId = const Value.absent(),
    double? packVoltage,
    double? current,
    double? soc,
    double? soh,
    double? remainingAh,
    double? cycleCount,
    double? deltaVolts,
    double? minCellVoltage,
    double? maxCellVoltage,
    double? maxTemperature,
    Value<double?> mosfetTemp = const Value.absent(),
    int? warningsMask,
    bool? balancerActive,
    String? cellVoltagesJson,
    Value<String?> deviceId = const Value.absent(),
  }) => Snapshot(
    id: id ?? this.id,
    timestamp: timestamp ?? this.timestamp,
    tripId: tripId.present ? tripId.value : this.tripId,
    packVoltage: packVoltage ?? this.packVoltage,
    current: current ?? this.current,
    soc: soc ?? this.soc,
    soh: soh ?? this.soh,
    remainingAh: remainingAh ?? this.remainingAh,
    cycleCount: cycleCount ?? this.cycleCount,
    deltaVolts: deltaVolts ?? this.deltaVolts,
    minCellVoltage: minCellVoltage ?? this.minCellVoltage,
    maxCellVoltage: maxCellVoltage ?? this.maxCellVoltage,
    maxTemperature: maxTemperature ?? this.maxTemperature,
    mosfetTemp: mosfetTemp.present ? mosfetTemp.value : this.mosfetTemp,
    warningsMask: warningsMask ?? this.warningsMask,
    balancerActive: balancerActive ?? this.balancerActive,
    cellVoltagesJson: cellVoltagesJson ?? this.cellVoltagesJson,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
  );
  Snapshot copyWithCompanion(SnapshotsCompanion data) {
    return Snapshot(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      packVoltage: data.packVoltage.present
          ? data.packVoltage.value
          : this.packVoltage,
      current: data.current.present ? data.current.value : this.current,
      soc: data.soc.present ? data.soc.value : this.soc,
      soh: data.soh.present ? data.soh.value : this.soh,
      remainingAh: data.remainingAh.present
          ? data.remainingAh.value
          : this.remainingAh,
      cycleCount: data.cycleCount.present
          ? data.cycleCount.value
          : this.cycleCount,
      deltaVolts: data.deltaVolts.present
          ? data.deltaVolts.value
          : this.deltaVolts,
      minCellVoltage: data.minCellVoltage.present
          ? data.minCellVoltage.value
          : this.minCellVoltage,
      maxCellVoltage: data.maxCellVoltage.present
          ? data.maxCellVoltage.value
          : this.maxCellVoltage,
      maxTemperature: data.maxTemperature.present
          ? data.maxTemperature.value
          : this.maxTemperature,
      mosfetTemp: data.mosfetTemp.present
          ? data.mosfetTemp.value
          : this.mosfetTemp,
      warningsMask: data.warningsMask.present
          ? data.warningsMask.value
          : this.warningsMask,
      balancerActive: data.balancerActive.present
          ? data.balancerActive.value
          : this.balancerActive,
      cellVoltagesJson: data.cellVoltagesJson.present
          ? data.cellVoltagesJson.value
          : this.cellVoltagesJson,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Snapshot(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('tripId: $tripId, ')
          ..write('packVoltage: $packVoltage, ')
          ..write('current: $current, ')
          ..write('soc: $soc, ')
          ..write('soh: $soh, ')
          ..write('remainingAh: $remainingAh, ')
          ..write('cycleCount: $cycleCount, ')
          ..write('deltaVolts: $deltaVolts, ')
          ..write('minCellVoltage: $minCellVoltage, ')
          ..write('maxCellVoltage: $maxCellVoltage, ')
          ..write('maxTemperature: $maxTemperature, ')
          ..write('mosfetTemp: $mosfetTemp, ')
          ..write('warningsMask: $warningsMask, ')
          ..write('balancerActive: $balancerActive, ')
          ..write('cellVoltagesJson: $cellVoltagesJson, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    timestamp,
    tripId,
    packVoltage,
    current,
    soc,
    soh,
    remainingAh,
    cycleCount,
    deltaVolts,
    minCellVoltage,
    maxCellVoltage,
    maxTemperature,
    mosfetTemp,
    warningsMask,
    balancerActive,
    cellVoltagesJson,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Snapshot &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.tripId == this.tripId &&
          other.packVoltage == this.packVoltage &&
          other.current == this.current &&
          other.soc == this.soc &&
          other.soh == this.soh &&
          other.remainingAh == this.remainingAh &&
          other.cycleCount == this.cycleCount &&
          other.deltaVolts == this.deltaVolts &&
          other.minCellVoltage == this.minCellVoltage &&
          other.maxCellVoltage == this.maxCellVoltage &&
          other.maxTemperature == this.maxTemperature &&
          other.mosfetTemp == this.mosfetTemp &&
          other.warningsMask == this.warningsMask &&
          other.balancerActive == this.balancerActive &&
          other.cellVoltagesJson == this.cellVoltagesJson &&
          other.deviceId == this.deviceId);
}

class SnapshotsCompanion extends UpdateCompanion<Snapshot> {
  final Value<int> id;
  final Value<DateTime> timestamp;
  final Value<int?> tripId;
  final Value<double> packVoltage;
  final Value<double> current;
  final Value<double> soc;
  final Value<double> soh;
  final Value<double> remainingAh;
  final Value<double> cycleCount;
  final Value<double> deltaVolts;
  final Value<double> minCellVoltage;
  final Value<double> maxCellVoltage;
  final Value<double> maxTemperature;
  final Value<double?> mosfetTemp;
  final Value<int> warningsMask;
  final Value<bool> balancerActive;
  final Value<String> cellVoltagesJson;
  final Value<String?> deviceId;
  const SnapshotsCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.tripId = const Value.absent(),
    this.packVoltage = const Value.absent(),
    this.current = const Value.absent(),
    this.soc = const Value.absent(),
    this.soh = const Value.absent(),
    this.remainingAh = const Value.absent(),
    this.cycleCount = const Value.absent(),
    this.deltaVolts = const Value.absent(),
    this.minCellVoltage = const Value.absent(),
    this.maxCellVoltage = const Value.absent(),
    this.maxTemperature = const Value.absent(),
    this.mosfetTemp = const Value.absent(),
    this.warningsMask = const Value.absent(),
    this.balancerActive = const Value.absent(),
    this.cellVoltagesJson = const Value.absent(),
    this.deviceId = const Value.absent(),
  });
  SnapshotsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime timestamp,
    this.tripId = const Value.absent(),
    required double packVoltage,
    required double current,
    required double soc,
    required double soh,
    required double remainingAh,
    required double cycleCount,
    required double deltaVolts,
    required double minCellVoltage,
    required double maxCellVoltage,
    required double maxTemperature,
    this.mosfetTemp = const Value.absent(),
    required int warningsMask,
    required bool balancerActive,
    required String cellVoltagesJson,
    this.deviceId = const Value.absent(),
  }) : timestamp = Value(timestamp),
       packVoltage = Value(packVoltage),
       current = Value(current),
       soc = Value(soc),
       soh = Value(soh),
       remainingAh = Value(remainingAh),
       cycleCount = Value(cycleCount),
       deltaVolts = Value(deltaVolts),
       minCellVoltage = Value(minCellVoltage),
       maxCellVoltage = Value(maxCellVoltage),
       maxTemperature = Value(maxTemperature),
       warningsMask = Value(warningsMask),
       balancerActive = Value(balancerActive),
       cellVoltagesJson = Value(cellVoltagesJson);
  static Insertable<Snapshot> custom({
    Expression<int>? id,
    Expression<DateTime>? timestamp,
    Expression<int>? tripId,
    Expression<double>? packVoltage,
    Expression<double>? current,
    Expression<double>? soc,
    Expression<double>? soh,
    Expression<double>? remainingAh,
    Expression<double>? cycleCount,
    Expression<double>? deltaVolts,
    Expression<double>? minCellVoltage,
    Expression<double>? maxCellVoltage,
    Expression<double>? maxTemperature,
    Expression<double>? mosfetTemp,
    Expression<int>? warningsMask,
    Expression<bool>? balancerActive,
    Expression<String>? cellVoltagesJson,
    Expression<String>? deviceId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (tripId != null) 'trip_id': tripId,
      if (packVoltage != null) 'pack_voltage': packVoltage,
      if (current != null) 'current': current,
      if (soc != null) 'soc': soc,
      if (soh != null) 'soh': soh,
      if (remainingAh != null) 'remaining_ah': remainingAh,
      if (cycleCount != null) 'cycle_count': cycleCount,
      if (deltaVolts != null) 'delta_volts': deltaVolts,
      if (minCellVoltage != null) 'min_cell_voltage': minCellVoltage,
      if (maxCellVoltage != null) 'max_cell_voltage': maxCellVoltage,
      if (maxTemperature != null) 'max_temperature': maxTemperature,
      if (mosfetTemp != null) 'mosfet_temp': mosfetTemp,
      if (warningsMask != null) 'warnings_mask': warningsMask,
      if (balancerActive != null) 'balancer_active': balancerActive,
      if (cellVoltagesJson != null) 'cell_voltages_json': cellVoltagesJson,
      if (deviceId != null) 'device_id': deviceId,
    });
  }

  SnapshotsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? timestamp,
    Value<int?>? tripId,
    Value<double>? packVoltage,
    Value<double>? current,
    Value<double>? soc,
    Value<double>? soh,
    Value<double>? remainingAh,
    Value<double>? cycleCount,
    Value<double>? deltaVolts,
    Value<double>? minCellVoltage,
    Value<double>? maxCellVoltage,
    Value<double>? maxTemperature,
    Value<double?>? mosfetTemp,
    Value<int>? warningsMask,
    Value<bool>? balancerActive,
    Value<String>? cellVoltagesJson,
    Value<String?>? deviceId,
  }) {
    return SnapshotsCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      tripId: tripId ?? this.tripId,
      packVoltage: packVoltage ?? this.packVoltage,
      current: current ?? this.current,
      soc: soc ?? this.soc,
      soh: soh ?? this.soh,
      remainingAh: remainingAh ?? this.remainingAh,
      cycleCount: cycleCount ?? this.cycleCount,
      deltaVolts: deltaVolts ?? this.deltaVolts,
      minCellVoltage: minCellVoltage ?? this.minCellVoltage,
      maxCellVoltage: maxCellVoltage ?? this.maxCellVoltage,
      maxTemperature: maxTemperature ?? this.maxTemperature,
      mosfetTemp: mosfetTemp ?? this.mosfetTemp,
      warningsMask: warningsMask ?? this.warningsMask,
      balancerActive: balancerActive ?? this.balancerActive,
      cellVoltagesJson: cellVoltagesJson ?? this.cellVoltagesJson,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<int>(tripId.value);
    }
    if (packVoltage.present) {
      map['pack_voltage'] = Variable<double>(packVoltage.value);
    }
    if (current.present) {
      map['current'] = Variable<double>(current.value);
    }
    if (soc.present) {
      map['soc'] = Variable<double>(soc.value);
    }
    if (soh.present) {
      map['soh'] = Variable<double>(soh.value);
    }
    if (remainingAh.present) {
      map['remaining_ah'] = Variable<double>(remainingAh.value);
    }
    if (cycleCount.present) {
      map['cycle_count'] = Variable<double>(cycleCount.value);
    }
    if (deltaVolts.present) {
      map['delta_volts'] = Variable<double>(deltaVolts.value);
    }
    if (minCellVoltage.present) {
      map['min_cell_voltage'] = Variable<double>(minCellVoltage.value);
    }
    if (maxCellVoltage.present) {
      map['max_cell_voltage'] = Variable<double>(maxCellVoltage.value);
    }
    if (maxTemperature.present) {
      map['max_temperature'] = Variable<double>(maxTemperature.value);
    }
    if (mosfetTemp.present) {
      map['mosfet_temp'] = Variable<double>(mosfetTemp.value);
    }
    if (warningsMask.present) {
      map['warnings_mask'] = Variable<int>(warningsMask.value);
    }
    if (balancerActive.present) {
      map['balancer_active'] = Variable<bool>(balancerActive.value);
    }
    if (cellVoltagesJson.present) {
      map['cell_voltages_json'] = Variable<String>(cellVoltagesJson.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('tripId: $tripId, ')
          ..write('packVoltage: $packVoltage, ')
          ..write('current: $current, ')
          ..write('soc: $soc, ')
          ..write('soh: $soh, ')
          ..write('remainingAh: $remainingAh, ')
          ..write('cycleCount: $cycleCount, ')
          ..write('deltaVolts: $deltaVolts, ')
          ..write('minCellVoltage: $minCellVoltage, ')
          ..write('maxCellVoltage: $maxCellVoltage, ')
          ..write('maxTemperature: $maxTemperature, ')
          ..write('mosfetTemp: $mosfetTemp, ')
          ..write('warningsMask: $warningsMask, ')
          ..write('balancerActive: $balancerActive, ')
          ..write('cellVoltagesJson: $cellVoltagesJson, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }
}

class $RawFramesTable extends RawFrames
    with TableInfo<$RawFramesTable, RawFrame> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RawFramesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordTypeMeta = const VerificationMeta(
    'recordType',
  );
  @override
  late final GeneratedColumn<int> recordType = GeneratedColumn<int>(
    'record_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    timestamp,
    recordType,
    bytes,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'raw_frames';
  @override
  VerificationContext validateIntegrity(
    Insertable<RawFrame> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('record_type')) {
      context.handle(
        _recordTypeMeta,
        recordType.isAcceptableOrUnknown(data['record_type']!, _recordTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_recordTypeMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RawFrame map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RawFrame(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      recordType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}record_type'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}bytes'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
    );
  }

  @override
  $RawFramesTable createAlias(String alias) {
    return $RawFramesTable(attachedDatabase, alias);
  }
}

class RawFrame extends DataClass implements Insertable<RawFrame> {
  final int id;
  final DateTime timestamp;
  final int recordType;
  final Uint8List bytes;

  /// Which pack this was recorded on. Null for rows written before the app
  /// tracked packs at all -- see [BmsRepository.orphanCounts].
  final String? deviceId;
  const RawFrame({
    required this.id,
    required this.timestamp,
    required this.recordType,
    required this.bytes,
    this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['record_type'] = Variable<int>(recordType);
    map['bytes'] = Variable<Uint8List>(bytes);
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    return map;
  }

  RawFramesCompanion toCompanion(bool nullToAbsent) {
    return RawFramesCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      recordType: Value(recordType),
      bytes: Value(bytes),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
    );
  }

  factory RawFrame.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RawFrame(
      id: serializer.fromJson<int>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      recordType: serializer.fromJson<int>(json['recordType']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'recordType': serializer.toJson<int>(recordType),
      'bytes': serializer.toJson<Uint8List>(bytes),
      'deviceId': serializer.toJson<String?>(deviceId),
    };
  }

  RawFrame copyWith({
    int? id,
    DateTime? timestamp,
    int? recordType,
    Uint8List? bytes,
    Value<String?> deviceId = const Value.absent(),
  }) => RawFrame(
    id: id ?? this.id,
    timestamp: timestamp ?? this.timestamp,
    recordType: recordType ?? this.recordType,
    bytes: bytes ?? this.bytes,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
  );
  RawFrame copyWithCompanion(RawFramesCompanion data) {
    return RawFrame(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      recordType: data.recordType.present
          ? data.recordType.value
          : this.recordType,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RawFrame(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('recordType: $recordType, ')
          ..write('bytes: $bytes, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    timestamp,
    recordType,
    $driftBlobEquality.hash(bytes),
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RawFrame &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.recordType == this.recordType &&
          $driftBlobEquality.equals(other.bytes, this.bytes) &&
          other.deviceId == this.deviceId);
}

class RawFramesCompanion extends UpdateCompanion<RawFrame> {
  final Value<int> id;
  final Value<DateTime> timestamp;
  final Value<int> recordType;
  final Value<Uint8List> bytes;
  final Value<String?> deviceId;
  const RawFramesCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.recordType = const Value.absent(),
    this.bytes = const Value.absent(),
    this.deviceId = const Value.absent(),
  });
  RawFramesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime timestamp,
    required int recordType,
    required Uint8List bytes,
    this.deviceId = const Value.absent(),
  }) : timestamp = Value(timestamp),
       recordType = Value(recordType),
       bytes = Value(bytes);
  static Insertable<RawFrame> custom({
    Expression<int>? id,
    Expression<DateTime>? timestamp,
    Expression<int>? recordType,
    Expression<Uint8List>? bytes,
    Expression<String>? deviceId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (recordType != null) 'record_type': recordType,
      if (bytes != null) 'bytes': bytes,
      if (deviceId != null) 'device_id': deviceId,
    });
  }

  RawFramesCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? timestamp,
    Value<int>? recordType,
    Value<Uint8List>? bytes,
    Value<String?>? deviceId,
  }) {
    return RawFramesCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      recordType: recordType ?? this.recordType,
      bytes: bytes ?? this.bytes,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (recordType.present) {
      map['record_type'] = Variable<int>(recordType.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RawFramesCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('recordType: $recordType, ')
          ..write('bytes: $bytes, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }
}

class $CapacityTestsTable extends CapacityTests
    with TableInfo<$CapacityTestsTable, CapacityTest> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CapacityTestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startSocMeta = const VerificationMeta(
    'startSoc',
  );
  @override
  late final GeneratedColumn<double> startSoc = GeneratedColumn<double>(
    'start_soc',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endSocMeta = const VerificationMeta('endSoc');
  @override
  late final GeneratedColumn<double> endSoc = GeneratedColumn<double>(
    'end_soc',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startPackVoltageMeta = const VerificationMeta(
    'startPackVoltage',
  );
  @override
  late final GeneratedColumn<double> startPackVoltage = GeneratedColumn<double>(
    'start_pack_voltage',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endPackVoltageMeta = const VerificationMeta(
    'endPackVoltage',
  );
  @override
  late final GeneratedColumn<double> endPackVoltage = GeneratedColumn<double>(
    'end_pack_voltage',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _measuredAhMeta = const VerificationMeta(
    'measuredAh',
  );
  @override
  late final GeneratedColumn<double> measuredAh = GeneratedColumn<double>(
    'measured_ah',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _measuredWhMeta = const VerificationMeta(
    'measuredWh',
  );
  @override
  late final GeneratedColumn<double> measuredWh = GeneratedColumn<double>(
    'measured_wh',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _catalogueAhMeta = const VerificationMeta(
    'catalogueAh',
  );
  @override
  late final GeneratedColumn<double> catalogueAh = GeneratedColumn<double>(
    'catalogue_ah',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _automaticMeta = const VerificationMeta(
    'automatic',
  );
  @override
  late final GeneratedColumn<bool> automatic = GeneratedColumn<bool>(
    'automatic',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("automatic" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _gapSecondsMeta = const VerificationMeta(
    'gapSeconds',
  );
  @override
  late final GeneratedColumn<int> gapSeconds = GeneratedColumn<int>(
    'gap_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    endedAt,
    startSoc,
    endSoc,
    startPackVoltage,
    endPackVoltage,
    measuredAh,
    measuredWh,
    catalogueAh,
    completed,
    automatic,
    gapSeconds,
    note,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'capacity_tests';
  @override
  VerificationContext validateIntegrity(
    Insertable<CapacityTest> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('start_soc')) {
      context.handle(
        _startSocMeta,
        startSoc.isAcceptableOrUnknown(data['start_soc']!, _startSocMeta),
      );
    } else if (isInserting) {
      context.missing(_startSocMeta);
    }
    if (data.containsKey('end_soc')) {
      context.handle(
        _endSocMeta,
        endSoc.isAcceptableOrUnknown(data['end_soc']!, _endSocMeta),
      );
    } else if (isInserting) {
      context.missing(_endSocMeta);
    }
    if (data.containsKey('start_pack_voltage')) {
      context.handle(
        _startPackVoltageMeta,
        startPackVoltage.isAcceptableOrUnknown(
          data['start_pack_voltage']!,
          _startPackVoltageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startPackVoltageMeta);
    }
    if (data.containsKey('end_pack_voltage')) {
      context.handle(
        _endPackVoltageMeta,
        endPackVoltage.isAcceptableOrUnknown(
          data['end_pack_voltage']!,
          _endPackVoltageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_endPackVoltageMeta);
    }
    if (data.containsKey('measured_ah')) {
      context.handle(
        _measuredAhMeta,
        measuredAh.isAcceptableOrUnknown(data['measured_ah']!, _measuredAhMeta),
      );
    } else if (isInserting) {
      context.missing(_measuredAhMeta);
    }
    if (data.containsKey('measured_wh')) {
      context.handle(
        _measuredWhMeta,
        measuredWh.isAcceptableOrUnknown(data['measured_wh']!, _measuredWhMeta),
      );
    } else if (isInserting) {
      context.missing(_measuredWhMeta);
    }
    if (data.containsKey('catalogue_ah')) {
      context.handle(
        _catalogueAhMeta,
        catalogueAh.isAcceptableOrUnknown(
          data['catalogue_ah']!,
          _catalogueAhMeta,
        ),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('automatic')) {
      context.handle(
        _automaticMeta,
        automatic.isAcceptableOrUnknown(data['automatic']!, _automaticMeta),
      );
    }
    if (data.containsKey('gap_seconds')) {
      context.handle(
        _gapSecondsMeta,
        gapSeconds.isAcceptableOrUnknown(data['gap_seconds']!, _gapSecondsMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CapacityTest map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CapacityTest(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      startSoc: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}start_soc'],
      )!,
      endSoc: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}end_soc'],
      )!,
      startPackVoltage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}start_pack_voltage'],
      )!,
      endPackVoltage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}end_pack_voltage'],
      )!,
      measuredAh: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}measured_ah'],
      )!,
      measuredWh: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}measured_wh'],
      )!,
      catalogueAh: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}catalogue_ah'],
      ),
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      automatic: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}automatic'],
      )!,
      gapSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gap_seconds'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
    );
  }

  @override
  $CapacityTestsTable createAlias(String alias) {
    return $CapacityTestsTable(attachedDatabase, alias);
  }
}

class CapacityTest extends DataClass implements Insertable<CapacityTest> {
  final int id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double startSoc;
  final double endSoc;
  final double startPackVoltage;
  final double endPackVoltage;

  /// Amp-hours actually drawn out between the two ends.
  final double measuredAh;
  final double measuredWh;

  /// What the pack was sold as at the time, or null if it was never stated.
  ///
  /// The amp-hours measured are worth keeping either way: the measurement is
  /// the fact, the comparison is the opinion.
  final double? catalogueAh;
  final bool completed;

  /// True when the app found this cycle in the history rather than the rider
  /// starting it by hand. Both are real measurements; the distinction matters
  /// because an automatic one may have gaps where the app was not connected.
  final bool automatic;

  /// Seconds of the discharge that were not observed. Zero on a clean run.
  final int gapSeconds;
  final String note;

  /// Which pack this was recorded on. Null for rows written before the app
  /// tracked packs at all -- see [BmsRepository.orphanCounts].
  final String? deviceId;
  const CapacityTest({
    required this.id,
    required this.startedAt,
    this.endedAt,
    required this.startSoc,
    required this.endSoc,
    required this.startPackVoltage,
    required this.endPackVoltage,
    required this.measuredAh,
    required this.measuredWh,
    this.catalogueAh,
    required this.completed,
    required this.automatic,
    required this.gapSeconds,
    required this.note,
    this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['start_soc'] = Variable<double>(startSoc);
    map['end_soc'] = Variable<double>(endSoc);
    map['start_pack_voltage'] = Variable<double>(startPackVoltage);
    map['end_pack_voltage'] = Variable<double>(endPackVoltage);
    map['measured_ah'] = Variable<double>(measuredAh);
    map['measured_wh'] = Variable<double>(measuredWh);
    if (!nullToAbsent || catalogueAh != null) {
      map['catalogue_ah'] = Variable<double>(catalogueAh);
    }
    map['completed'] = Variable<bool>(completed);
    map['automatic'] = Variable<bool>(automatic);
    map['gap_seconds'] = Variable<int>(gapSeconds);
    map['note'] = Variable<String>(note);
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    return map;
  }

  CapacityTestsCompanion toCompanion(bool nullToAbsent) {
    return CapacityTestsCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      startSoc: Value(startSoc),
      endSoc: Value(endSoc),
      startPackVoltage: Value(startPackVoltage),
      endPackVoltage: Value(endPackVoltage),
      measuredAh: Value(measuredAh),
      measuredWh: Value(measuredWh),
      catalogueAh: catalogueAh == null && nullToAbsent
          ? const Value.absent()
          : Value(catalogueAh),
      completed: Value(completed),
      automatic: Value(automatic),
      gapSeconds: Value(gapSeconds),
      note: Value(note),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
    );
  }

  factory CapacityTest.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CapacityTest(
      id: serializer.fromJson<int>(json['id']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      startSoc: serializer.fromJson<double>(json['startSoc']),
      endSoc: serializer.fromJson<double>(json['endSoc']),
      startPackVoltage: serializer.fromJson<double>(json['startPackVoltage']),
      endPackVoltage: serializer.fromJson<double>(json['endPackVoltage']),
      measuredAh: serializer.fromJson<double>(json['measuredAh']),
      measuredWh: serializer.fromJson<double>(json['measuredWh']),
      catalogueAh: serializer.fromJson<double?>(json['catalogueAh']),
      completed: serializer.fromJson<bool>(json['completed']),
      automatic: serializer.fromJson<bool>(json['automatic']),
      gapSeconds: serializer.fromJson<int>(json['gapSeconds']),
      note: serializer.fromJson<String>(json['note']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'startSoc': serializer.toJson<double>(startSoc),
      'endSoc': serializer.toJson<double>(endSoc),
      'startPackVoltage': serializer.toJson<double>(startPackVoltage),
      'endPackVoltage': serializer.toJson<double>(endPackVoltage),
      'measuredAh': serializer.toJson<double>(measuredAh),
      'measuredWh': serializer.toJson<double>(measuredWh),
      'catalogueAh': serializer.toJson<double?>(catalogueAh),
      'completed': serializer.toJson<bool>(completed),
      'automatic': serializer.toJson<bool>(automatic),
      'gapSeconds': serializer.toJson<int>(gapSeconds),
      'note': serializer.toJson<String>(note),
      'deviceId': serializer.toJson<String?>(deviceId),
    };
  }

  CapacityTest copyWith({
    int? id,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    double? startSoc,
    double? endSoc,
    double? startPackVoltage,
    double? endPackVoltage,
    double? measuredAh,
    double? measuredWh,
    Value<double?> catalogueAh = const Value.absent(),
    bool? completed,
    bool? automatic,
    int? gapSeconds,
    String? note,
    Value<String?> deviceId = const Value.absent(),
  }) => CapacityTest(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    startSoc: startSoc ?? this.startSoc,
    endSoc: endSoc ?? this.endSoc,
    startPackVoltage: startPackVoltage ?? this.startPackVoltage,
    endPackVoltage: endPackVoltage ?? this.endPackVoltage,
    measuredAh: measuredAh ?? this.measuredAh,
    measuredWh: measuredWh ?? this.measuredWh,
    catalogueAh: catalogueAh.present ? catalogueAh.value : this.catalogueAh,
    completed: completed ?? this.completed,
    automatic: automatic ?? this.automatic,
    gapSeconds: gapSeconds ?? this.gapSeconds,
    note: note ?? this.note,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
  );
  CapacityTest copyWithCompanion(CapacityTestsCompanion data) {
    return CapacityTest(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      startSoc: data.startSoc.present ? data.startSoc.value : this.startSoc,
      endSoc: data.endSoc.present ? data.endSoc.value : this.endSoc,
      startPackVoltage: data.startPackVoltage.present
          ? data.startPackVoltage.value
          : this.startPackVoltage,
      endPackVoltage: data.endPackVoltage.present
          ? data.endPackVoltage.value
          : this.endPackVoltage,
      measuredAh: data.measuredAh.present
          ? data.measuredAh.value
          : this.measuredAh,
      measuredWh: data.measuredWh.present
          ? data.measuredWh.value
          : this.measuredWh,
      catalogueAh: data.catalogueAh.present
          ? data.catalogueAh.value
          : this.catalogueAh,
      completed: data.completed.present ? data.completed.value : this.completed,
      automatic: data.automatic.present ? data.automatic.value : this.automatic,
      gapSeconds: data.gapSeconds.present
          ? data.gapSeconds.value
          : this.gapSeconds,
      note: data.note.present ? data.note.value : this.note,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CapacityTest(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('startSoc: $startSoc, ')
          ..write('endSoc: $endSoc, ')
          ..write('startPackVoltage: $startPackVoltage, ')
          ..write('endPackVoltage: $endPackVoltage, ')
          ..write('measuredAh: $measuredAh, ')
          ..write('measuredWh: $measuredWh, ')
          ..write('catalogueAh: $catalogueAh, ')
          ..write('completed: $completed, ')
          ..write('automatic: $automatic, ')
          ..write('gapSeconds: $gapSeconds, ')
          ..write('note: $note, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    startedAt,
    endedAt,
    startSoc,
    endSoc,
    startPackVoltage,
    endPackVoltage,
    measuredAh,
    measuredWh,
    catalogueAh,
    completed,
    automatic,
    gapSeconds,
    note,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CapacityTest &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.startSoc == this.startSoc &&
          other.endSoc == this.endSoc &&
          other.startPackVoltage == this.startPackVoltage &&
          other.endPackVoltage == this.endPackVoltage &&
          other.measuredAh == this.measuredAh &&
          other.measuredWh == this.measuredWh &&
          other.catalogueAh == this.catalogueAh &&
          other.completed == this.completed &&
          other.automatic == this.automatic &&
          other.gapSeconds == this.gapSeconds &&
          other.note == this.note &&
          other.deviceId == this.deviceId);
}

class CapacityTestsCompanion extends UpdateCompanion<CapacityTest> {
  final Value<int> id;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<double> startSoc;
  final Value<double> endSoc;
  final Value<double> startPackVoltage;
  final Value<double> endPackVoltage;
  final Value<double> measuredAh;
  final Value<double> measuredWh;
  final Value<double?> catalogueAh;
  final Value<bool> completed;
  final Value<bool> automatic;
  final Value<int> gapSeconds;
  final Value<String> note;
  final Value<String?> deviceId;
  const CapacityTestsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.startSoc = const Value.absent(),
    this.endSoc = const Value.absent(),
    this.startPackVoltage = const Value.absent(),
    this.endPackVoltage = const Value.absent(),
    this.measuredAh = const Value.absent(),
    this.measuredWh = const Value.absent(),
    this.catalogueAh = const Value.absent(),
    this.completed = const Value.absent(),
    this.automatic = const Value.absent(),
    this.gapSeconds = const Value.absent(),
    this.note = const Value.absent(),
    this.deviceId = const Value.absent(),
  });
  CapacityTestsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    required double startSoc,
    required double endSoc,
    required double startPackVoltage,
    required double endPackVoltage,
    required double measuredAh,
    required double measuredWh,
    this.catalogueAh = const Value.absent(),
    this.completed = const Value.absent(),
    this.automatic = const Value.absent(),
    this.gapSeconds = const Value.absent(),
    this.note = const Value.absent(),
    this.deviceId = const Value.absent(),
  }) : startedAt = Value(startedAt),
       startSoc = Value(startSoc),
       endSoc = Value(endSoc),
       startPackVoltage = Value(startPackVoltage),
       endPackVoltage = Value(endPackVoltage),
       measuredAh = Value(measuredAh),
       measuredWh = Value(measuredWh);
  static Insertable<CapacityTest> custom({
    Expression<int>? id,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<double>? startSoc,
    Expression<double>? endSoc,
    Expression<double>? startPackVoltage,
    Expression<double>? endPackVoltage,
    Expression<double>? measuredAh,
    Expression<double>? measuredWh,
    Expression<double>? catalogueAh,
    Expression<bool>? completed,
    Expression<bool>? automatic,
    Expression<int>? gapSeconds,
    Expression<String>? note,
    Expression<String>? deviceId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (startSoc != null) 'start_soc': startSoc,
      if (endSoc != null) 'end_soc': endSoc,
      if (startPackVoltage != null) 'start_pack_voltage': startPackVoltage,
      if (endPackVoltage != null) 'end_pack_voltage': endPackVoltage,
      if (measuredAh != null) 'measured_ah': measuredAh,
      if (measuredWh != null) 'measured_wh': measuredWh,
      if (catalogueAh != null) 'catalogue_ah': catalogueAh,
      if (completed != null) 'completed': completed,
      if (automatic != null) 'automatic': automatic,
      if (gapSeconds != null) 'gap_seconds': gapSeconds,
      if (note != null) 'note': note,
      if (deviceId != null) 'device_id': deviceId,
    });
  }

  CapacityTestsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<double>? startSoc,
    Value<double>? endSoc,
    Value<double>? startPackVoltage,
    Value<double>? endPackVoltage,
    Value<double>? measuredAh,
    Value<double>? measuredWh,
    Value<double?>? catalogueAh,
    Value<bool>? completed,
    Value<bool>? automatic,
    Value<int>? gapSeconds,
    Value<String>? note,
    Value<String?>? deviceId,
  }) {
    return CapacityTestsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      startSoc: startSoc ?? this.startSoc,
      endSoc: endSoc ?? this.endSoc,
      startPackVoltage: startPackVoltage ?? this.startPackVoltage,
      endPackVoltage: endPackVoltage ?? this.endPackVoltage,
      measuredAh: measuredAh ?? this.measuredAh,
      measuredWh: measuredWh ?? this.measuredWh,
      catalogueAh: catalogueAh ?? this.catalogueAh,
      completed: completed ?? this.completed,
      automatic: automatic ?? this.automatic,
      gapSeconds: gapSeconds ?? this.gapSeconds,
      note: note ?? this.note,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (startSoc.present) {
      map['start_soc'] = Variable<double>(startSoc.value);
    }
    if (endSoc.present) {
      map['end_soc'] = Variable<double>(endSoc.value);
    }
    if (startPackVoltage.present) {
      map['start_pack_voltage'] = Variable<double>(startPackVoltage.value);
    }
    if (endPackVoltage.present) {
      map['end_pack_voltage'] = Variable<double>(endPackVoltage.value);
    }
    if (measuredAh.present) {
      map['measured_ah'] = Variable<double>(measuredAh.value);
    }
    if (measuredWh.present) {
      map['measured_wh'] = Variable<double>(measuredWh.value);
    }
    if (catalogueAh.present) {
      map['catalogue_ah'] = Variable<double>(catalogueAh.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (automatic.present) {
      map['automatic'] = Variable<bool>(automatic.value);
    }
    if (gapSeconds.present) {
      map['gap_seconds'] = Variable<int>(gapSeconds.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CapacityTestsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('startSoc: $startSoc, ')
          ..write('endSoc: $endSoc, ')
          ..write('startPackVoltage: $startPackVoltage, ')
          ..write('endPackVoltage: $endPackVoltage, ')
          ..write('measuredAh: $measuredAh, ')
          ..write('measuredWh: $measuredWh, ')
          ..write('catalogueAh: $catalogueAh, ')
          ..write('completed: $completed, ')
          ..write('automatic: $automatic, ')
          ..write('gapSeconds: $gapSeconds, ')
          ..write('note: $note, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DevicesTable devices = $DevicesTable(this);
  late final $TripsTable trips = $TripsTable(this);
  late final $TripPointsTable tripPoints = $TripPointsTable(this);
  late final $SnapshotsTable snapshots = $SnapshotsTable(this);
  late final $RawFramesTable rawFrames = $RawFramesTable(this);
  late final $CapacityTestsTable capacityTests = $CapacityTestsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    devices,
    trips,
    tripPoints,
    snapshots,
    rawFrames,
    capacityTests,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('trip_points', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$DevicesTableCreateCompanionBuilder =
    DevicesCompanion Function({
      required String id,
      Value<String> name,
      Value<String> serialNumber,
      Value<String> model,
      Value<double?> catalogueCapacityAh,
      required DateTime firstSeenAt,
      required DateTime lastSeenAt,
      Value<bool> demo,
      Value<int> rowid,
    });
typedef $$DevicesTableUpdateCompanionBuilder =
    DevicesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> serialNumber,
      Value<String> model,
      Value<double?> catalogueCapacityAh,
      Value<DateTime> firstSeenAt,
      Value<DateTime> lastSeenAt,
      Value<bool> demo,
      Value<int> rowid,
    });

class $$DevicesTableFilterComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serialNumber => $composableBuilder(
    column: $table.serialNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get catalogueCapacityAh => $composableBuilder(
    column: $table.catalogueCapacityAh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get demo => $composableBuilder(
    column: $table.demo,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DevicesTableOrderingComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serialNumber => $composableBuilder(
    column: $table.serialNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get catalogueCapacityAh => $composableBuilder(
    column: $table.catalogueCapacityAh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get demo => $composableBuilder(
    column: $table.demo,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DevicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get serialNumber => $composableBuilder(
    column: $table.serialNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<double> get catalogueCapacityAh => $composableBuilder(
    column: $table.catalogueCapacityAh,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get demo =>
      $composableBuilder(column: $table.demo, builder: (column) => column);
}

class $$DevicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DevicesTable,
          Device,
          $$DevicesTableFilterComposer,
          $$DevicesTableOrderingComposer,
          $$DevicesTableAnnotationComposer,
          $$DevicesTableCreateCompanionBuilder,
          $$DevicesTableUpdateCompanionBuilder,
          (Device, BaseReferences<_$AppDatabase, $DevicesTable, Device>),
          Device,
          PrefetchHooks Function()
        > {
  $$DevicesTableTableManager(_$AppDatabase db, $DevicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> serialNumber = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<double?> catalogueCapacityAh = const Value.absent(),
                Value<DateTime> firstSeenAt = const Value.absent(),
                Value<DateTime> lastSeenAt = const Value.absent(),
                Value<bool> demo = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DevicesCompanion(
                id: id,
                name: name,
                serialNumber: serialNumber,
                model: model,
                catalogueCapacityAh: catalogueCapacityAh,
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
                demo: demo,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> name = const Value.absent(),
                Value<String> serialNumber = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<double?> catalogueCapacityAh = const Value.absent(),
                required DateTime firstSeenAt,
                required DateTime lastSeenAt,
                Value<bool> demo = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DevicesCompanion.insert(
                id: id,
                name: name,
                serialNumber: serialNumber,
                model: model,
                catalogueCapacityAh: catalogueCapacityAh,
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
                demo: demo,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DevicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DevicesTable,
      Device,
      $$DevicesTableFilterComposer,
      $$DevicesTableOrderingComposer,
      $$DevicesTableAnnotationComposer,
      $$DevicesTableCreateCompanionBuilder,
      $$DevicesTableUpdateCompanionBuilder,
      (Device, BaseReferences<_$AppDatabase, $DevicesTable, Device>),
      Device,
      PrefetchHooks Function()
    >;
typedef $$TripsTableCreateCompanionBuilder =
    TripsCompanion Function({
      Value<int> id,
      required DateTime startedAt,
      required DateTime endedAt,
      required double distanceKm,
      required int movingSeconds,
      required int totalSeconds,
      required double maxSpeedKmh,
      required double energyOutWh,
      required double energyInWh,
      required double startSoc,
      required double endSoc,
      required double minPackVoltage,
      required double maxPackVoltage,
      required double maxDischargeCurrent,
      required double maxTemperature,
      required double maxDeltaVolts,
      required double climbM,
      required double descentM,
      Value<String> note,
      Value<bool> demo,
      Value<String?> deviceId,
    });
typedef $$TripsTableUpdateCompanionBuilder =
    TripsCompanion Function({
      Value<int> id,
      Value<DateTime> startedAt,
      Value<DateTime> endedAt,
      Value<double> distanceKm,
      Value<int> movingSeconds,
      Value<int> totalSeconds,
      Value<double> maxSpeedKmh,
      Value<double> energyOutWh,
      Value<double> energyInWh,
      Value<double> startSoc,
      Value<double> endSoc,
      Value<double> minPackVoltage,
      Value<double> maxPackVoltage,
      Value<double> maxDischargeCurrent,
      Value<double> maxTemperature,
      Value<double> maxDeltaVolts,
      Value<double> climbM,
      Value<double> descentM,
      Value<String> note,
      Value<bool> demo,
      Value<String?> deviceId,
    });

final class $$TripsTableReferences
    extends BaseReferences<_$AppDatabase, $TripsTable, Trip> {
  $$TripsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TripPointsTable, List<TripPoint>>
  _tripPointsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.tripPoints,
    aliasName: 'trips__id__trip_points__trip_id',
  );

  $$TripPointsTableProcessedTableManager get tripPointsRefs {
    final manager = $$TripPointsTableTableManager(
      $_db,
      $_db.tripPoints,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_tripPointsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TripsTableFilterComposer extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distanceKm => $composableBuilder(
    column: $table.distanceKm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get movingSeconds => $composableBuilder(
    column: $table.movingSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalSeconds => $composableBuilder(
    column: $table.totalSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxSpeedKmh => $composableBuilder(
    column: $table.maxSpeedKmh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get energyOutWh => $composableBuilder(
    column: $table.energyOutWh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get energyInWh => $composableBuilder(
    column: $table.energyInWh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get startSoc => $composableBuilder(
    column: $table.startSoc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get endSoc => $composableBuilder(
    column: $table.endSoc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get minPackVoltage => $composableBuilder(
    column: $table.minPackVoltage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxPackVoltage => $composableBuilder(
    column: $table.maxPackVoltage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxDischargeCurrent => $composableBuilder(
    column: $table.maxDischargeCurrent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxTemperature => $composableBuilder(
    column: $table.maxTemperature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxDeltaVolts => $composableBuilder(
    column: $table.maxDeltaVolts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get climbM => $composableBuilder(
    column: $table.climbM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get descentM => $composableBuilder(
    column: $table.descentM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get demo => $composableBuilder(
    column: $table.demo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tripPointsRefs(
    Expression<bool> Function($$TripPointsTableFilterComposer f) f,
  ) {
    final $$TripPointsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripPoints,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripPointsTableFilterComposer(
            $db: $db,
            $table: $db.tripPoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TripsTableOrderingComposer
    extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distanceKm => $composableBuilder(
    column: $table.distanceKm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get movingSeconds => $composableBuilder(
    column: $table.movingSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalSeconds => $composableBuilder(
    column: $table.totalSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxSpeedKmh => $composableBuilder(
    column: $table.maxSpeedKmh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get energyOutWh => $composableBuilder(
    column: $table.energyOutWh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get energyInWh => $composableBuilder(
    column: $table.energyInWh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get startSoc => $composableBuilder(
    column: $table.startSoc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get endSoc => $composableBuilder(
    column: $table.endSoc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get minPackVoltage => $composableBuilder(
    column: $table.minPackVoltage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxPackVoltage => $composableBuilder(
    column: $table.maxPackVoltage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxDischargeCurrent => $composableBuilder(
    column: $table.maxDischargeCurrent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxTemperature => $composableBuilder(
    column: $table.maxTemperature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxDeltaVolts => $composableBuilder(
    column: $table.maxDeltaVolts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get climbM => $composableBuilder(
    column: $table.climbM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get descentM => $composableBuilder(
    column: $table.descentM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get demo => $composableBuilder(
    column: $table.demo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TripsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<double> get distanceKm => $composableBuilder(
    column: $table.distanceKm,
    builder: (column) => column,
  );

  GeneratedColumn<int> get movingSeconds => $composableBuilder(
    column: $table.movingSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalSeconds => $composableBuilder(
    column: $table.totalSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxSpeedKmh => $composableBuilder(
    column: $table.maxSpeedKmh,
    builder: (column) => column,
  );

  GeneratedColumn<double> get energyOutWh => $composableBuilder(
    column: $table.energyOutWh,
    builder: (column) => column,
  );

  GeneratedColumn<double> get energyInWh => $composableBuilder(
    column: $table.energyInWh,
    builder: (column) => column,
  );

  GeneratedColumn<double> get startSoc =>
      $composableBuilder(column: $table.startSoc, builder: (column) => column);

  GeneratedColumn<double> get endSoc =>
      $composableBuilder(column: $table.endSoc, builder: (column) => column);

  GeneratedColumn<double> get minPackVoltage => $composableBuilder(
    column: $table.minPackVoltage,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxPackVoltage => $composableBuilder(
    column: $table.maxPackVoltage,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxDischargeCurrent => $composableBuilder(
    column: $table.maxDischargeCurrent,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxTemperature => $composableBuilder(
    column: $table.maxTemperature,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxDeltaVolts => $composableBuilder(
    column: $table.maxDeltaVolts,
    builder: (column) => column,
  );

  GeneratedColumn<double> get climbM =>
      $composableBuilder(column: $table.climbM, builder: (column) => column);

  GeneratedColumn<double> get descentM =>
      $composableBuilder(column: $table.descentM, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get demo =>
      $composableBuilder(column: $table.demo, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  Expression<T> tripPointsRefs<T extends Object>(
    Expression<T> Function($$TripPointsTableAnnotationComposer a) f,
  ) {
    final $$TripPointsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripPoints,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripPointsTableAnnotationComposer(
            $db: $db,
            $table: $db.tripPoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TripsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TripsTable,
          Trip,
          $$TripsTableFilterComposer,
          $$TripsTableOrderingComposer,
          $$TripsTableAnnotationComposer,
          $$TripsTableCreateCompanionBuilder,
          $$TripsTableUpdateCompanionBuilder,
          (Trip, $$TripsTableReferences),
          Trip,
          PrefetchHooks Function({bool tripPointsRefs})
        > {
  $$TripsTableTableManager(_$AppDatabase db, $TripsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime> endedAt = const Value.absent(),
                Value<double> distanceKm = const Value.absent(),
                Value<int> movingSeconds = const Value.absent(),
                Value<int> totalSeconds = const Value.absent(),
                Value<double> maxSpeedKmh = const Value.absent(),
                Value<double> energyOutWh = const Value.absent(),
                Value<double> energyInWh = const Value.absent(),
                Value<double> startSoc = const Value.absent(),
                Value<double> endSoc = const Value.absent(),
                Value<double> minPackVoltage = const Value.absent(),
                Value<double> maxPackVoltage = const Value.absent(),
                Value<double> maxDischargeCurrent = const Value.absent(),
                Value<double> maxTemperature = const Value.absent(),
                Value<double> maxDeltaVolts = const Value.absent(),
                Value<double> climbM = const Value.absent(),
                Value<double> descentM = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<bool> demo = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
              }) => TripsCompanion(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                distanceKm: distanceKm,
                movingSeconds: movingSeconds,
                totalSeconds: totalSeconds,
                maxSpeedKmh: maxSpeedKmh,
                energyOutWh: energyOutWh,
                energyInWh: energyInWh,
                startSoc: startSoc,
                endSoc: endSoc,
                minPackVoltage: minPackVoltage,
                maxPackVoltage: maxPackVoltage,
                maxDischargeCurrent: maxDischargeCurrent,
                maxTemperature: maxTemperature,
                maxDeltaVolts: maxDeltaVolts,
                climbM: climbM,
                descentM: descentM,
                note: note,
                demo: demo,
                deviceId: deviceId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime startedAt,
                required DateTime endedAt,
                required double distanceKm,
                required int movingSeconds,
                required int totalSeconds,
                required double maxSpeedKmh,
                required double energyOutWh,
                required double energyInWh,
                required double startSoc,
                required double endSoc,
                required double minPackVoltage,
                required double maxPackVoltage,
                required double maxDischargeCurrent,
                required double maxTemperature,
                required double maxDeltaVolts,
                required double climbM,
                required double descentM,
                Value<String> note = const Value.absent(),
                Value<bool> demo = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
              }) => TripsCompanion.insert(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                distanceKm: distanceKm,
                movingSeconds: movingSeconds,
                totalSeconds: totalSeconds,
                maxSpeedKmh: maxSpeedKmh,
                energyOutWh: energyOutWh,
                energyInWh: energyInWh,
                startSoc: startSoc,
                endSoc: endSoc,
                minPackVoltage: minPackVoltage,
                maxPackVoltage: maxPackVoltage,
                maxDischargeCurrent: maxDischargeCurrent,
                maxTemperature: maxTemperature,
                maxDeltaVolts: maxDeltaVolts,
                climbM: climbM,
                descentM: descentM,
                note: note,
                demo: demo,
                deviceId: deviceId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TripsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({tripPointsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (tripPointsRefs) db.tripPoints],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tripPointsRefs)
                    await $_getPrefetchedData<Trip, $TripsTable, TripPoint>(
                      currentTable: table,
                      referencedTable: $$TripsTableReferences
                          ._tripPointsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TripsTableReferences(db, table, p0).tripPointsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tripId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TripsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TripsTable,
      Trip,
      $$TripsTableFilterComposer,
      $$TripsTableOrderingComposer,
      $$TripsTableAnnotationComposer,
      $$TripsTableCreateCompanionBuilder,
      $$TripsTableUpdateCompanionBuilder,
      (Trip, $$TripsTableReferences),
      Trip,
      PrefetchHooks Function({bool tripPointsRefs})
    >;
typedef $$TripPointsTableCreateCompanionBuilder =
    TripPointsCompanion Function({
      Value<int> id,
      required int tripId,
      required DateTime timestamp,
      required double latitude,
      required double longitude,
      required double speedKmh,
      required double altitudeM,
      required double packVoltage,
      required double current,
      required double soc,
    });
typedef $$TripPointsTableUpdateCompanionBuilder =
    TripPointsCompanion Function({
      Value<int> id,
      Value<int> tripId,
      Value<DateTime> timestamp,
      Value<double> latitude,
      Value<double> longitude,
      Value<double> speedKmh,
      Value<double> altitudeM,
      Value<double> packVoltage,
      Value<double> current,
      Value<double> soc,
    });

final class $$TripPointsTableReferences
    extends BaseReferences<_$AppDatabase, $TripPointsTable, TripPoint> {
  $$TripPointsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TripsTable _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('trip_points__trip_id__trips__id');

  $$TripsTableProcessedTableManager get tripId {
    final $_column = $_itemColumn<int>('trip_id')!;

    final manager = $$TripsTableTableManager(
      $_db,
      $_db.trips,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TripPointsTableFilterComposer
    extends Composer<_$AppDatabase, $TripPointsTable> {
  $$TripPointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speedKmh => $composableBuilder(
    column: $table.speedKmh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get altitudeM => $composableBuilder(
    column: $table.altitudeM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get packVoltage => $composableBuilder(
    column: $table.packVoltage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get current => $composableBuilder(
    column: $table.current,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get soc => $composableBuilder(
    column: $table.soc,
    builder: (column) => ColumnFilters(column),
  );

  $$TripsTableFilterComposer get tripId {
    final $$TripsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableFilterComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripPointsTableOrderingComposer
    extends Composer<_$AppDatabase, $TripPointsTable> {
  $$TripPointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speedKmh => $composableBuilder(
    column: $table.speedKmh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get altitudeM => $composableBuilder(
    column: $table.altitudeM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get packVoltage => $composableBuilder(
    column: $table.packVoltage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get current => $composableBuilder(
    column: $table.current,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get soc => $composableBuilder(
    column: $table.soc,
    builder: (column) => ColumnOrderings(column),
  );

  $$TripsTableOrderingComposer get tripId {
    final $$TripsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableOrderingComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripPointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripPointsTable> {
  $$TripPointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get speedKmh =>
      $composableBuilder(column: $table.speedKmh, builder: (column) => column);

  GeneratedColumn<double> get altitudeM =>
      $composableBuilder(column: $table.altitudeM, builder: (column) => column);

  GeneratedColumn<double> get packVoltage => $composableBuilder(
    column: $table.packVoltage,
    builder: (column) => column,
  );

  GeneratedColumn<double> get current =>
      $composableBuilder(column: $table.current, builder: (column) => column);

  GeneratedColumn<double> get soc =>
      $composableBuilder(column: $table.soc, builder: (column) => column);

  $$TripsTableAnnotationComposer get tripId {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableAnnotationComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripPointsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TripPointsTable,
          TripPoint,
          $$TripPointsTableFilterComposer,
          $$TripPointsTableOrderingComposer,
          $$TripPointsTableAnnotationComposer,
          $$TripPointsTableCreateCompanionBuilder,
          $$TripPointsTableUpdateCompanionBuilder,
          (TripPoint, $$TripPointsTableReferences),
          TripPoint,
          PrefetchHooks Function({bool tripId})
        > {
  $$TripPointsTableTableManager(_$AppDatabase db, $TripPointsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripPointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripPointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripPointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> tripId = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<double> speedKmh = const Value.absent(),
                Value<double> altitudeM = const Value.absent(),
                Value<double> packVoltage = const Value.absent(),
                Value<double> current = const Value.absent(),
                Value<double> soc = const Value.absent(),
              }) => TripPointsCompanion(
                id: id,
                tripId: tripId,
                timestamp: timestamp,
                latitude: latitude,
                longitude: longitude,
                speedKmh: speedKmh,
                altitudeM: altitudeM,
                packVoltage: packVoltage,
                current: current,
                soc: soc,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int tripId,
                required DateTime timestamp,
                required double latitude,
                required double longitude,
                required double speedKmh,
                required double altitudeM,
                required double packVoltage,
                required double current,
                required double soc,
              }) => TripPointsCompanion.insert(
                id: id,
                tripId: tripId,
                timestamp: timestamp,
                latitude: latitude,
                longitude: longitude,
                speedKmh: speedKmh,
                altitudeM: altitudeM,
                packVoltage: packVoltage,
                current: current,
                soc: soc,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TripPointsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tripId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (tripId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tripId,
                                referencedTable: $$TripPointsTableReferences
                                    ._tripIdTable(db),
                                referencedColumn: $$TripPointsTableReferences
                                    ._tripIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TripPointsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TripPointsTable,
      TripPoint,
      $$TripPointsTableFilterComposer,
      $$TripPointsTableOrderingComposer,
      $$TripPointsTableAnnotationComposer,
      $$TripPointsTableCreateCompanionBuilder,
      $$TripPointsTableUpdateCompanionBuilder,
      (TripPoint, $$TripPointsTableReferences),
      TripPoint,
      PrefetchHooks Function({bool tripId})
    >;
typedef $$SnapshotsTableCreateCompanionBuilder =
    SnapshotsCompanion Function({
      Value<int> id,
      required DateTime timestamp,
      Value<int?> tripId,
      required double packVoltage,
      required double current,
      required double soc,
      required double soh,
      required double remainingAh,
      required double cycleCount,
      required double deltaVolts,
      required double minCellVoltage,
      required double maxCellVoltage,
      required double maxTemperature,
      Value<double?> mosfetTemp,
      required int warningsMask,
      required bool balancerActive,
      required String cellVoltagesJson,
      Value<String?> deviceId,
    });
typedef $$SnapshotsTableUpdateCompanionBuilder =
    SnapshotsCompanion Function({
      Value<int> id,
      Value<DateTime> timestamp,
      Value<int?> tripId,
      Value<double> packVoltage,
      Value<double> current,
      Value<double> soc,
      Value<double> soh,
      Value<double> remainingAh,
      Value<double> cycleCount,
      Value<double> deltaVolts,
      Value<double> minCellVoltage,
      Value<double> maxCellVoltage,
      Value<double> maxTemperature,
      Value<double?> mosfetTemp,
      Value<int> warningsMask,
      Value<bool> balancerActive,
      Value<String> cellVoltagesJson,
      Value<String?> deviceId,
    });

class $$SnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $SnapshotsTable> {
  $$SnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get packVoltage => $composableBuilder(
    column: $table.packVoltage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get current => $composableBuilder(
    column: $table.current,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get soc => $composableBuilder(
    column: $table.soc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get soh => $composableBuilder(
    column: $table.soh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get remainingAh => $composableBuilder(
    column: $table.remainingAh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cycleCount => $composableBuilder(
    column: $table.cycleCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get deltaVolts => $composableBuilder(
    column: $table.deltaVolts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get minCellVoltage => $composableBuilder(
    column: $table.minCellVoltage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxCellVoltage => $composableBuilder(
    column: $table.maxCellVoltage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxTemperature => $composableBuilder(
    column: $table.maxTemperature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get mosfetTemp => $composableBuilder(
    column: $table.mosfetTemp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get warningsMask => $composableBuilder(
    column: $table.warningsMask,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get balancerActive => $composableBuilder(
    column: $table.balancerActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cellVoltagesJson => $composableBuilder(
    column: $table.cellVoltagesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $SnapshotsTable> {
  $$SnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get packVoltage => $composableBuilder(
    column: $table.packVoltage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get current => $composableBuilder(
    column: $table.current,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get soc => $composableBuilder(
    column: $table.soc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get soh => $composableBuilder(
    column: $table.soh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get remainingAh => $composableBuilder(
    column: $table.remainingAh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cycleCount => $composableBuilder(
    column: $table.cycleCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get deltaVolts => $composableBuilder(
    column: $table.deltaVolts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get minCellVoltage => $composableBuilder(
    column: $table.minCellVoltage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxCellVoltage => $composableBuilder(
    column: $table.maxCellVoltage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxTemperature => $composableBuilder(
    column: $table.maxTemperature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get mosfetTemp => $composableBuilder(
    column: $table.mosfetTemp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get warningsMask => $composableBuilder(
    column: $table.warningsMask,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get balancerActive => $composableBuilder(
    column: $table.balancerActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cellVoltagesJson => $composableBuilder(
    column: $table.cellVoltagesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SnapshotsTable> {
  $$SnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<int> get tripId =>
      $composableBuilder(column: $table.tripId, builder: (column) => column);

  GeneratedColumn<double> get packVoltage => $composableBuilder(
    column: $table.packVoltage,
    builder: (column) => column,
  );

  GeneratedColumn<double> get current =>
      $composableBuilder(column: $table.current, builder: (column) => column);

  GeneratedColumn<double> get soc =>
      $composableBuilder(column: $table.soc, builder: (column) => column);

  GeneratedColumn<double> get soh =>
      $composableBuilder(column: $table.soh, builder: (column) => column);

  GeneratedColumn<double> get remainingAh => $composableBuilder(
    column: $table.remainingAh,
    builder: (column) => column,
  );

  GeneratedColumn<double> get cycleCount => $composableBuilder(
    column: $table.cycleCount,
    builder: (column) => column,
  );

  GeneratedColumn<double> get deltaVolts => $composableBuilder(
    column: $table.deltaVolts,
    builder: (column) => column,
  );

  GeneratedColumn<double> get minCellVoltage => $composableBuilder(
    column: $table.minCellVoltage,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxCellVoltage => $composableBuilder(
    column: $table.maxCellVoltage,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxTemperature => $composableBuilder(
    column: $table.maxTemperature,
    builder: (column) => column,
  );

  GeneratedColumn<double> get mosfetTemp => $composableBuilder(
    column: $table.mosfetTemp,
    builder: (column) => column,
  );

  GeneratedColumn<int> get warningsMask => $composableBuilder(
    column: $table.warningsMask,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get balancerActive => $composableBuilder(
    column: $table.balancerActive,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cellVoltagesJson => $composableBuilder(
    column: $table.cellVoltagesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$SnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SnapshotsTable,
          Snapshot,
          $$SnapshotsTableFilterComposer,
          $$SnapshotsTableOrderingComposer,
          $$SnapshotsTableAnnotationComposer,
          $$SnapshotsTableCreateCompanionBuilder,
          $$SnapshotsTableUpdateCompanionBuilder,
          (Snapshot, BaseReferences<_$AppDatabase, $SnapshotsTable, Snapshot>),
          Snapshot,
          PrefetchHooks Function()
        > {
  $$SnapshotsTableTableManager(_$AppDatabase db, $SnapshotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<int?> tripId = const Value.absent(),
                Value<double> packVoltage = const Value.absent(),
                Value<double> current = const Value.absent(),
                Value<double> soc = const Value.absent(),
                Value<double> soh = const Value.absent(),
                Value<double> remainingAh = const Value.absent(),
                Value<double> cycleCount = const Value.absent(),
                Value<double> deltaVolts = const Value.absent(),
                Value<double> minCellVoltage = const Value.absent(),
                Value<double> maxCellVoltage = const Value.absent(),
                Value<double> maxTemperature = const Value.absent(),
                Value<double?> mosfetTemp = const Value.absent(),
                Value<int> warningsMask = const Value.absent(),
                Value<bool> balancerActive = const Value.absent(),
                Value<String> cellVoltagesJson = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
              }) => SnapshotsCompanion(
                id: id,
                timestamp: timestamp,
                tripId: tripId,
                packVoltage: packVoltage,
                current: current,
                soc: soc,
                soh: soh,
                remainingAh: remainingAh,
                cycleCount: cycleCount,
                deltaVolts: deltaVolts,
                minCellVoltage: minCellVoltage,
                maxCellVoltage: maxCellVoltage,
                maxTemperature: maxTemperature,
                mosfetTemp: mosfetTemp,
                warningsMask: warningsMask,
                balancerActive: balancerActive,
                cellVoltagesJson: cellVoltagesJson,
                deviceId: deviceId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime timestamp,
                Value<int?> tripId = const Value.absent(),
                required double packVoltage,
                required double current,
                required double soc,
                required double soh,
                required double remainingAh,
                required double cycleCount,
                required double deltaVolts,
                required double minCellVoltage,
                required double maxCellVoltage,
                required double maxTemperature,
                Value<double?> mosfetTemp = const Value.absent(),
                required int warningsMask,
                required bool balancerActive,
                required String cellVoltagesJson,
                Value<String?> deviceId = const Value.absent(),
              }) => SnapshotsCompanion.insert(
                id: id,
                timestamp: timestamp,
                tripId: tripId,
                packVoltage: packVoltage,
                current: current,
                soc: soc,
                soh: soh,
                remainingAh: remainingAh,
                cycleCount: cycleCount,
                deltaVolts: deltaVolts,
                minCellVoltage: minCellVoltage,
                maxCellVoltage: maxCellVoltage,
                maxTemperature: maxTemperature,
                mosfetTemp: mosfetTemp,
                warningsMask: warningsMask,
                balancerActive: balancerActive,
                cellVoltagesJson: cellVoltagesJson,
                deviceId: deviceId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SnapshotsTable,
      Snapshot,
      $$SnapshotsTableFilterComposer,
      $$SnapshotsTableOrderingComposer,
      $$SnapshotsTableAnnotationComposer,
      $$SnapshotsTableCreateCompanionBuilder,
      $$SnapshotsTableUpdateCompanionBuilder,
      (Snapshot, BaseReferences<_$AppDatabase, $SnapshotsTable, Snapshot>),
      Snapshot,
      PrefetchHooks Function()
    >;
typedef $$RawFramesTableCreateCompanionBuilder =
    RawFramesCompanion Function({
      Value<int> id,
      required DateTime timestamp,
      required int recordType,
      required Uint8List bytes,
      Value<String?> deviceId,
    });
typedef $$RawFramesTableUpdateCompanionBuilder =
    RawFramesCompanion Function({
      Value<int> id,
      Value<DateTime> timestamp,
      Value<int> recordType,
      Value<Uint8List> bytes,
      Value<String?> deviceId,
    });

class $$RawFramesTableFilterComposer
    extends Composer<_$AppDatabase, $RawFramesTable> {
  $$RawFramesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RawFramesTableOrderingComposer
    extends Composer<_$AppDatabase, $RawFramesTable> {
  $$RawFramesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RawFramesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RawFramesTable> {
  $$RawFramesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<int> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$RawFramesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RawFramesTable,
          RawFrame,
          $$RawFramesTableFilterComposer,
          $$RawFramesTableOrderingComposer,
          $$RawFramesTableAnnotationComposer,
          $$RawFramesTableCreateCompanionBuilder,
          $$RawFramesTableUpdateCompanionBuilder,
          (RawFrame, BaseReferences<_$AppDatabase, $RawFramesTable, RawFrame>),
          RawFrame,
          PrefetchHooks Function()
        > {
  $$RawFramesTableTableManager(_$AppDatabase db, $RawFramesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RawFramesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RawFramesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RawFramesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<int> recordType = const Value.absent(),
                Value<Uint8List> bytes = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
              }) => RawFramesCompanion(
                id: id,
                timestamp: timestamp,
                recordType: recordType,
                bytes: bytes,
                deviceId: deviceId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime timestamp,
                required int recordType,
                required Uint8List bytes,
                Value<String?> deviceId = const Value.absent(),
              }) => RawFramesCompanion.insert(
                id: id,
                timestamp: timestamp,
                recordType: recordType,
                bytes: bytes,
                deviceId: deviceId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RawFramesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RawFramesTable,
      RawFrame,
      $$RawFramesTableFilterComposer,
      $$RawFramesTableOrderingComposer,
      $$RawFramesTableAnnotationComposer,
      $$RawFramesTableCreateCompanionBuilder,
      $$RawFramesTableUpdateCompanionBuilder,
      (RawFrame, BaseReferences<_$AppDatabase, $RawFramesTable, RawFrame>),
      RawFrame,
      PrefetchHooks Function()
    >;
typedef $$CapacityTestsTableCreateCompanionBuilder =
    CapacityTestsCompanion Function({
      Value<int> id,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      required double startSoc,
      required double endSoc,
      required double startPackVoltage,
      required double endPackVoltage,
      required double measuredAh,
      required double measuredWh,
      Value<double?> catalogueAh,
      Value<bool> completed,
      Value<bool> automatic,
      Value<int> gapSeconds,
      Value<String> note,
      Value<String?> deviceId,
    });
typedef $$CapacityTestsTableUpdateCompanionBuilder =
    CapacityTestsCompanion Function({
      Value<int> id,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<double> startSoc,
      Value<double> endSoc,
      Value<double> startPackVoltage,
      Value<double> endPackVoltage,
      Value<double> measuredAh,
      Value<double> measuredWh,
      Value<double?> catalogueAh,
      Value<bool> completed,
      Value<bool> automatic,
      Value<int> gapSeconds,
      Value<String> note,
      Value<String?> deviceId,
    });

class $$CapacityTestsTableFilterComposer
    extends Composer<_$AppDatabase, $CapacityTestsTable> {
  $$CapacityTestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get startSoc => $composableBuilder(
    column: $table.startSoc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get endSoc => $composableBuilder(
    column: $table.endSoc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get startPackVoltage => $composableBuilder(
    column: $table.startPackVoltage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get endPackVoltage => $composableBuilder(
    column: $table.endPackVoltage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get measuredAh => $composableBuilder(
    column: $table.measuredAh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get measuredWh => $composableBuilder(
    column: $table.measuredWh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get catalogueAh => $composableBuilder(
    column: $table.catalogueAh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get automatic => $composableBuilder(
    column: $table.automatic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gapSeconds => $composableBuilder(
    column: $table.gapSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CapacityTestsTableOrderingComposer
    extends Composer<_$AppDatabase, $CapacityTestsTable> {
  $$CapacityTestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get startSoc => $composableBuilder(
    column: $table.startSoc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get endSoc => $composableBuilder(
    column: $table.endSoc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get startPackVoltage => $composableBuilder(
    column: $table.startPackVoltage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get endPackVoltage => $composableBuilder(
    column: $table.endPackVoltage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get measuredAh => $composableBuilder(
    column: $table.measuredAh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get measuredWh => $composableBuilder(
    column: $table.measuredWh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get catalogueAh => $composableBuilder(
    column: $table.catalogueAh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get automatic => $composableBuilder(
    column: $table.automatic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gapSeconds => $composableBuilder(
    column: $table.gapSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CapacityTestsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CapacityTestsTable> {
  $$CapacityTestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<double> get startSoc =>
      $composableBuilder(column: $table.startSoc, builder: (column) => column);

  GeneratedColumn<double> get endSoc =>
      $composableBuilder(column: $table.endSoc, builder: (column) => column);

  GeneratedColumn<double> get startPackVoltage => $composableBuilder(
    column: $table.startPackVoltage,
    builder: (column) => column,
  );

  GeneratedColumn<double> get endPackVoltage => $composableBuilder(
    column: $table.endPackVoltage,
    builder: (column) => column,
  );

  GeneratedColumn<double> get measuredAh => $composableBuilder(
    column: $table.measuredAh,
    builder: (column) => column,
  );

  GeneratedColumn<double> get measuredWh => $composableBuilder(
    column: $table.measuredWh,
    builder: (column) => column,
  );

  GeneratedColumn<double> get catalogueAh => $composableBuilder(
    column: $table.catalogueAh,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<bool> get automatic =>
      $composableBuilder(column: $table.automatic, builder: (column) => column);

  GeneratedColumn<int> get gapSeconds => $composableBuilder(
    column: $table.gapSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$CapacityTestsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CapacityTestsTable,
          CapacityTest,
          $$CapacityTestsTableFilterComposer,
          $$CapacityTestsTableOrderingComposer,
          $$CapacityTestsTableAnnotationComposer,
          $$CapacityTestsTableCreateCompanionBuilder,
          $$CapacityTestsTableUpdateCompanionBuilder,
          (
            CapacityTest,
            BaseReferences<_$AppDatabase, $CapacityTestsTable, CapacityTest>,
          ),
          CapacityTest,
          PrefetchHooks Function()
        > {
  $$CapacityTestsTableTableManager(_$AppDatabase db, $CapacityTestsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CapacityTestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CapacityTestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CapacityTestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<double> startSoc = const Value.absent(),
                Value<double> endSoc = const Value.absent(),
                Value<double> startPackVoltage = const Value.absent(),
                Value<double> endPackVoltage = const Value.absent(),
                Value<double> measuredAh = const Value.absent(),
                Value<double> measuredWh = const Value.absent(),
                Value<double?> catalogueAh = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<bool> automatic = const Value.absent(),
                Value<int> gapSeconds = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
              }) => CapacityTestsCompanion(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                startSoc: startSoc,
                endSoc: endSoc,
                startPackVoltage: startPackVoltage,
                endPackVoltage: endPackVoltage,
                measuredAh: measuredAh,
                measuredWh: measuredWh,
                catalogueAh: catalogueAh,
                completed: completed,
                automatic: automatic,
                gapSeconds: gapSeconds,
                note: note,
                deviceId: deviceId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                required double startSoc,
                required double endSoc,
                required double startPackVoltage,
                required double endPackVoltage,
                required double measuredAh,
                required double measuredWh,
                Value<double?> catalogueAh = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<bool> automatic = const Value.absent(),
                Value<int> gapSeconds = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
              }) => CapacityTestsCompanion.insert(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                startSoc: startSoc,
                endSoc: endSoc,
                startPackVoltage: startPackVoltage,
                endPackVoltage: endPackVoltage,
                measuredAh: measuredAh,
                measuredWh: measuredWh,
                catalogueAh: catalogueAh,
                completed: completed,
                automatic: automatic,
                gapSeconds: gapSeconds,
                note: note,
                deviceId: deviceId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CapacityTestsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CapacityTestsTable,
      CapacityTest,
      $$CapacityTestsTableFilterComposer,
      $$CapacityTestsTableOrderingComposer,
      $$CapacityTestsTableAnnotationComposer,
      $$CapacityTestsTableCreateCompanionBuilder,
      $$CapacityTestsTableUpdateCompanionBuilder,
      (
        CapacityTest,
        BaseReferences<_$AppDatabase, $CapacityTestsTable, CapacityTest>,
      ),
      CapacityTest,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DevicesTableTableManager get devices =>
      $$DevicesTableTableManager(_db, _db.devices);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db, _db.trips);
  $$TripPointsTableTableManager get tripPoints =>
      $$TripPointsTableTableManager(_db, _db.tripPoints);
  $$SnapshotsTableTableManager get snapshots =>
      $$SnapshotsTableTableManager(_db, _db.snapshots);
  $$RawFramesTableTableManager get rawFrames =>
      $$RawFramesTableTableManager(_db, _db.rawFrames);
  $$CapacityTestsTableTableManager get capacityTests =>
      $$CapacityTestsTableTableManager(_db, _db.capacityTests);
}
