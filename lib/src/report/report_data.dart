import '../data/database.dart';
import '../inspection/inspection_result.dart';
import '../inspection/inspection_series.dart';
import '../metrics/advice_engine.dart';
import '../metrics/cell_drift.dart';
import '../metrics/degradation.dart';
import '../metrics/range_outlook.dart';
import '../pack/chemistry.dart';
import '../pack/pack_baseline.dart';
import 'certificate.dart';

/// Everything the "my battery" sheet prints, gathered in one place.
///
/// Deliberately made of numbers and strings rather than of live objects: a
/// report is a snapshot of what was known at one moment, and a page that goes
/// on reading from the service while it renders would print figures that
/// disagree with each other. Building it is also what makes the layout
/// testable without a screen.
class PackReportData {
  const PackReportData({
    required this.generatedAt,
    required this.packName,
    this.model = '',
    this.serialNumber = '',
    this.appVersion = '',
    this.lastReadingAt,
    this.soc,
    this.packVoltage,
    this.cellCount,
    this.deltaVolts,
    this.minCellVoltage,
    this.maxCellVoltage,
    this.maxTemperature,
    this.measuredAh,
    this.baselineAh,
    this.baselineAt,
    this.baselineIsMeasured = false,
    this.configuredAh,
    this.advertisedAh,
    this.lostFraction,
    this.capacityTests = 0,
    this.fullRangeKm,
    this.rangeFromMeasuredCapacity = false,
    this.whPerKm,
    this.drift = const [],
    this.advice = const [],
    this.readingCount = 0,
    this.historySince,
    this.tripCount = 0,
    this.totalKm = 0,
    this.maintenance = const [],
    this.chemistry = CellChemistry.unknown,
    this.acquiredAt,
    this.baseline,
    this.sinceDayOne,
  });

  final DateTime generatedAt;
  final String packName;
  final String model;
  final String serialNumber;

  /// Which build produced the sheet. A figure that changed meaning between
  /// versions can then be traced to the version that printed it.
  final String appVersion;

  final DateTime? lastReadingAt;
  final double? soc;
  final double? packVoltage;
  final int? cellCount;
  final double? deltaVolts;
  final double? minCellVoltage;
  final double? maxCellVoltage;
  final double? maxTemperature;

  /// The best full discharge the app ever counted. The only measurement here.
  final double? measuredAh;
  final double? baselineAh;
  final DateTime? baselineAt;
  final bool baselineIsMeasured;

  /// What the BMS is set to hold. A setting, and the sheet says so.
  final double? configuredAh;

  /// What the pack was sold as, when the rider said.
  final double? advertisedAh;
  final double? lostFraction;
  final int capacityTests;

  final double? fullRangeKm;
  final bool rangeFromMeasuredCapacity;
  final double? whPerKm;

  /// Worst first, as the Health tab ranks them.
  final List<CellDrift> drift;

  /// The same sentences the app says on screen, with their evidence.
  final List<Advice> advice;

  final int readingCount;
  final DateTime? historySince;
  final int tripCount;
  final double totalKm;

  final List<MaintenanceEvent> maintenance;

  /// What the rider said the pack is, and since when. Neither can be read
  /// off the wire, and both change what the sheet is allowed to claim.
  final CellChemistry chemistry;
  final DateTime? acquiredAt;

  /// The day-one copy, when one was kept.
  final PackBaseline? baseline;

  /// Today against that day. Absent when there is no baseline, or when the
  /// two readings cannot be lined up.
  final BaselineComparison? sinceDayOne;

  /// Assembles the sheet from what a screen already holds.
  ///
  /// Takes the analyses rather than the raw rows, so the numbers on paper are
  /// by construction the numbers on the screen the rider pressed the button
  /// from. A report that recomputed them from scratch would eventually
  /// disagree with the app, and the person holding both would be right to
  /// trust neither.
  static PackReportData build({
    required DateTime generatedAt,
    required Device device,
    required Snapshot? last,
    required Degradation? degradation,
    required RangeOutlook? outlook,
    required List<CellDrift> drift,
    required List<Advice> advice,
    required List<Trip> trips,
    required List<MaintenanceEvent> maintenance,
    required int readingCount,
    DateTime? historySince,
    double? whPerKm,
    int capacityTests = 0,
    String appVersion = '',
    PackBaseline? baseline,
    BaselineComparison? sinceDayOne,
  }) {
    final cells = last == null
        ? const <double>[]
        : decodeCellVoltages(last.cellVoltagesJson);
    return PackReportData(
      generatedAt: generatedAt,
      packName: device.name.isEmpty ? device.id : device.name,
      model: device.model,
      serialNumber: device.serialNumber,
      appVersion: appVersion,
      lastReadingAt: last?.timestamp,
      soc: last?.soc,
      packVoltage: last?.packVoltage,
      cellCount: cells.isEmpty ? null : cells.length,
      deltaVolts: last?.deltaVolts,
      minCellVoltage: last?.minCellVoltage,
      maxCellVoltage: last?.maxCellVoltage,
      maxTemperature: last?.maxTemperature,
      measuredAh: degradation?.current?.ah,
      baselineAh: degradation?.baseline?.ah,
      baselineAt: degradation?.baseline?.at,
      baselineIsMeasured: degradation?.baselineIsMeasured ?? false,
      configuredAh: degradation?.configuredAh,
      advertisedAh: degradation?.advertisedAh ?? device.catalogueCapacityAh,
      lostFraction: degradation?.lostFraction,
      capacityTests: capacityTests,
      fullRangeKm: outlook?.fullKm,
      rangeFromMeasuredCapacity: outlook?.fullFromMeasuredCapacity ?? false,
      whPerKm: whPerKm,
      drift: drift,
      advice: advice,
      readingCount: readingCount,
      historySince: historySince,
      tripCount: trips.length,
      totalKm: trips.fold<double>(0, (a, t) => a + t.distanceKm),
      maintenance: maintenance,
      chemistry: CellChemistry.byName(device.chemistry),
      acquiredAt: device.acquiredAt,
      baseline: baseline,
      sinceDayOne: sinceDayOne,
    );
  }
}

/// Everything the inspection sheet prints.
///
/// The same document whether or not it is signed: a certificate is this sheet
/// with a QR and a code added, not a different set of figures. Printing two
/// versions of the truth is how a document format starts lying.
class InspectionReportData {
  const InspectionReportData({
    required this.generatedAt,
    required this.result,
    required this.light,
    required this.advice,
    this.packName = '',
    this.note = '',
    this.appVersion = '',
    this.certificate,
    this.comparison,
    this.seriesAdvice = const [],
  });

  final DateTime generatedAt;
  final InspectionResult result;
  final InspectionLight light;
  final List<Advice> advice;
  final String packName;
  final String note;
  final String appVersion;

  /// Present when the sheet is a signed certificate.
  final Certificate? certificate;

  /// This run set against the earlier runs on the same pack, when there are
  /// any. A repeated test is the strongest thing a quick test can produce, so
  /// it belongs on the paper rather than only on the screen.
  final InspectionComparison? comparison;

  /// What the repeat adds, in the same evidence-backed sentences.
  final List<Advice> seriesAdvice;

  bool get isCertificate => certificate != null;

  bool get hasSeries => (comparison?.earlier.isNotEmpty ?? false);
}
