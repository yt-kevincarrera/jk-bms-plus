import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/inspection/inspection_result.dart';
import 'package:jk_bms/src/inspection/inspection_series.dart';
import 'package:jk_bms/src/inspection/inspection_verdicts.dart';
import 'package:jk_bms/src/metrics/advice_engine.dart';
import 'package:jk_bms/src/metrics/cell_drift.dart';
import 'package:jk_bms/src/metrics/maintenance.dart';
import 'package:jk_bms/src/report/certificate.dart';
import 'package:jk_bms/src/report/pdf_reports.dart';
import 'package:jk_bms/src/report/report_data.dart';
import 'package:jk_bms/src/report/report_sharing.dart';

/// The Spanish wording, which is the template the app ships against. Pure
/// Dart: no widget tree is needed to lay out a PDF.
final AppL10n t = lookupAppL10n(const Locale('es'));

InspectionResult _result({
  double sagOnCell7 = 0.30,
  List<String> faults = const [],
  List<InspectionCaveat> caveats = const [],
}) {
  final cells = [
    for (var i = 1; i <= 16; i++)
      CellInspection(
        index: i,
        restVolts: 3.900 - i * 0.001,
        lightSagVolts: 0.010,
        heavySagVolts: i == 7 ? sagOnCell7 : 0.080,
        resistanceOhms: i == 7 ? 0.0080 : 0.0021,
        recoverySeconds: i == 7 ? 22.0 : 4.0,
        recovered: true,
      ),
  ];
  return InspectionResult(
    at: DateTime.utc(2026, 5, 4, 11, 30),
    cells: cells,
    restDeltaVolts: 0.015,
    restCurrentAmps: 0.2,
    lightLoadAmps: 1.8,
    peakDischargeAmps: 38,
    currentStepAmps: 37.4,
    medianHeavySagVolts: 0.080,
    medianResistanceOhms: 0.0021,
    medianRecoverySeconds: 4.0,
    maxTemperature: 31.5,
    faultsSeen: faults,
    caveats: caveats,
    reported: const ReportedFigures(
      model: 'JK-BD6A20S10P',
      serialNumber: 'SN-90210',
      softwareVersion: '11.26',
      cycleCount: 12,
      configuredCapacityAh: 40,
      soc: 78,
      soh: 100,
    ),
    durationSeconds: 96,
    readings: 180,
  );
}

Device _device() => Device(
  id: 'AA:BB:CC:DD:EE:FF',
  name: 'Pack de la moto',
  serialNumber: 'SN-1',
  model: 'JK-BD6A20S10P',
  firstSeenAt: DateTime.utc(2025, 9, 1),
  lastSeenAt: DateTime.utc(2026, 5, 1),
  catalogueCapacityAh: 40,
  catalogueFromBms: false,
  demo: false,
);

void main() {
  group('a certificate', () {
    late SimpleKeyPair pair;

    setUp(() async {
      pair = await CertificateIdentity(
        seed: List<int>.generate(32, (i) => i + 1),
      ).keyPair();
    });

    test('verifies against the figures it was made from', () async {
      final content = CertificateContent(
        issuedAt: DateTime.utc(2026, 5, 4, 12),
        packName: 'Pack del vendedor',
        result: _result(),
        note: 'Pedía 400 euros',
      );
      final cert = await const Certificates().issue(content, pair);

      expect(cert.token, startsWith('JKC1.'));
      final check = await const Certificates().check(cert.token);
      expect(check.ok, isTrue);
      final back = check.certificate!.content;
      expect(back.packName, 'Pack del vendedor');
      expect(back.note, 'Pedía 400 euros');
      expect(back.result.cellCount, 16);
      expect(back.result.cells[6].heavySagVolts, closeTo(0.30, 1e-9));
      expect(back.issuedAt, content.issuedAt);
    });

    test('is rejected when a figure was edited afterwards', () async {
      final cert = await const Certificates().issue(
        CertificateContent(
          issuedAt: DateTime.utc(2026, 5, 4, 12),
          packName: 'Pack del vendedor',
          result: _result(),
        ),
        pair,
      );

      // The payload of a different, healthier test, carrying the original
      // signature. This is the fraud the signature exists to catch.
      final other = CertificateContent(
        issuedAt: DateTime.utc(2026, 5, 4, 12),
        packName: 'Pack del vendedor',
        result: _result(sagOnCell7: 0.08),
      ).encode();
      final parts = cert.token.split('.');
      final forged = [
        parts[0],
        base64Url.encode(other).replaceAll('=', ''),
        parts[2],
        parts[3],
      ].join('.');

      final check = await const Certificates().check(forged);
      expect(check.ok, isFalse);
      expect(check.rejection, CertificateRejection.badSignature);
    });

    test('rejects text that is not a certificate at all', () async {
      for (final text in ['', 'hola', 'JKB1.aaa.bbb', 'JKC1.aa.bb']) {
        final check = await const Certificates().check(text);
        expect(check.ok, isFalse, reason: text);
        expect(check.rejection, CertificateRejection.malformed, reason: text);
      }
    });

    test('survives the whitespace a paste picks up', () async {
      final cert = await const Certificates().issue(
        CertificateContent(
          issuedAt: DateTime.utc(2026, 5, 4, 12),
          packName: 'Pack',
          result: _result(),
        ),
        pair,
      );
      final wrapped = cert.token.replaceAllMapped(
        RegExp('.{40}'),
        (m) => '${m[0]}\n',
      );
      expect((await const Certificates().check(wrapped)).ok, isTrue);
    });

    test('the same phone always signs as the same issuer', () async {
      final one = CertificateIdentity(seed: List<int>.filled(32, 7));
      final two = CertificateIdentity(seed: List<int>.filled(32, 7));
      expect(await one.issuerCode(), await two.issuerCode());

      final other = CertificateIdentity(seed: List<int>.filled(32, 9));
      expect(await one.issuerCode(), isNot(await other.issuerCode()));
    });

    test('the short codes are readable and stable', () {
      final code = Certificate.shortCode(List<int>.generate(64, (i) => i));
      expect(code, matches(RegExp(r'^[2-9A-Z]{4}-[2-9A-Z]{4}-[2-9A-Z]{4}$')));
      expect(code, Certificate.shortCode(List<int>.generate(64, (i) => i)));
    });
  });

  group('a certificate that carries earlier runs', () {
    test('signs them along with this one and reads them back', () async {
      final pair = await CertificateIdentity(
        seed: List<int>.filled(32, 11),
      ).keyPair();
      final earlier = [
        PastInspection(at: DateTime.utc(2026, 3, 1), result: _result()),
        PastInspection(at: DateTime.utc(2026, 4, 1), result: _result()),
      ];
      final cert = await const Certificates().issue(
        CertificateContent(
          issuedAt: DateTime.utc(2026, 5, 4, 12),
          packName: 'Pack del vendedor',
          result: _result(),
          history: [for (final p in earlier) CertifiedRun.from(p)],
        ),
        pair,
      );

      final check = await const Certificates().check(cert.token);
      expect(check.ok, isTrue);
      final history = check.certificate!.content.history;
      expect(history, hasLength(2));
      expect(history.first.at, DateTime.utc(2026, 3, 1));
      // The cell that failed, on every run, is the point of carrying them.
      expect(history.every((r) => r.worstCell == 7), isTrue);
      expect(history.first.worstSagVolts, closeTo(0.30, 1e-9));
    });

    test('editing an earlier run breaks the signature too', () async {
      final pair = await CertificateIdentity(
        seed: List<int>.filled(32, 11),
      ).keyPair();
      final cert = await const Certificates().issue(
        CertificateContent(
          issuedAt: DateTime.utc(2026, 5, 4, 12),
          packName: 'Pack del vendedor',
          result: _result(),
          history: [
            CertifiedRun.from(
              PastInspection(at: DateTime.utc(2026, 3, 1), result: _result()),
            ),
          ],
        ),
        pair,
      );

      // The same certificate with the bad run quietly dropped from history.
      final tampered = CertificateContent(
        issuedAt: DateTime.utc(2026, 5, 4, 12),
        packName: 'Pack del vendedor',
        result: _result(),
      ).encode();
      final parts = cert.token.split('.');
      final forged = [
        parts[0],
        base64Url.encode(tampered).replaceAll('=', ''),
        parts[2],
        parts[3],
      ].join('.');

      final check = await const Certificates().check(forged);
      expect(check.ok, isFalse);
      expect(check.rejection, CertificateRejection.badSignature);
    });

    test(
      'a certificate for a 24-cell pack with three runs still fits a QR',
      () async {
        final cells = [
          for (var i = 1; i <= 24; i++)
            CellInspection(
              index: i,
              restVolts: 3.9 - i * 0.001,
              lightSagVolts: 0.01,
              heavySagVolts: 0.08,
              resistanceOhms: 0.0021,
              recoverySeconds: 4,
              recovered: true,
            ),
        ];
        final big = InspectionResult(
          at: DateTime.utc(2026, 5, 4),
          cells: cells,
          restDeltaVolts: 0.015,
          restCurrentAmps: 0.2,
          peakDischargeAmps: 38,
          currentStepAmps: 37.4,
          medianHeavySagVolts: 0.08,
          medianResistanceOhms: 0.0021,
          faultsSeen: const ['over temperature'],
          caveats: const [],
          reported: const ReportedFigures(
            model: 'JK-BD6A20S10P',
            serialNumber: 'SN-90210',
            softwareVersion: '11.26',
          ),
          durationSeconds: 96,
          readings: 180,
        );
        final pair = await CertificateIdentity(
          seed: List<int>.filled(32, 13),
        ).keyPair();
        final cert = await const Certificates().issue(
          CertificateContent(
            issuedAt: DateTime.utc(2026, 5, 4),
            packName: 'Pack del vendedor  JK-BD6A20S10P',
            result: big,
            note: 'Pedia 400 euros, bateria de 2023',
            history: [
              for (var i = 1; i <= 3; i++)
                CertifiedRun.from(
                  PastInspection(at: DateTime.utc(2026, i + 1, 1), result: big),
                ),
            ],
          ),
          pair,
        );

        // A QR at the size the sheet prints it stops being scannable well
        // before this; the short code is the fallback, not the plan.
        expect(cert.token.length, lessThan(1200));
      },
    );
  });

  group('the inspection sheet', () {
    test('renders a PDF with the verdicts on it', () async {
      final r = _result();
      final bytes = await const PdfReports().inspectionReport(
        t,
        InspectionReportData(
          generatedAt: DateTime.utc(2026, 5, 4, 12),
          result: r,
          light: const InspectionVerdicts().light(r),
          advice: const InspectionVerdicts().evaluate(r),
          packName: 'Pack del vendedor',
          note: 'Pedía 400 euros',
          appVersion: '2.15.0',
        ),
      );

      expect(bytes.length, greaterThan(1000));
      expect(_isPdf(bytes), isTrue);
    });

    test('renders when the test measured almost nothing', () async {
      final bare = InspectionResult(
        at: DateTime.utc(2026, 5, 4),
        cells: const [],
        restDeltaVolts: 0,
        restCurrentAmps: 0,
        peakDischargeAmps: 0,
        currentStepAmps: 0,
        faultsSeen: const [],
        caveats: const [
          InspectionCaveat.noHeavyLoad,
          InspectionCaveat.noLightLoad,
          InspectionCaveat.fewReadings,
        ],
        reported: const ReportedFigures(
          model: '',
          serialNumber: '',
          softwareVersion: '',
        ),
        durationSeconds: 10,
        readings: 3,
      );
      final bytes = await const PdfReports().inspectionReport(
        t,
        InspectionReportData(
          generatedAt: DateTime.utc(2026, 5, 4, 12),
          result: bare,
          light: const InspectionVerdicts().light(bare),
          advice: const InspectionVerdicts().evaluate(bare),
        ),
      );
      expect(_isPdf(bytes), isTrue);
    });

    test(
      'a signed sheet carries the QR and stays bigger than a plain one',
      () async {
        final r = _result();
        final data = InspectionReportData(
          generatedAt: DateTime.utc(2026, 5, 4, 12),
          result: r,
          light: const InspectionVerdicts().light(r),
          advice: const InspectionVerdicts().evaluate(r),
          packName: 'Pack del vendedor',
        );
        final plain = await const PdfReports().inspectionReport(t, data);

        final pair = await CertificateIdentity(
          seed: List<int>.filled(32, 3),
        ).keyPair();
        final cert = await const Certificates().issue(
          CertificateContent(
            issuedAt: DateTime.utc(2026, 5, 4, 12),
            packName: 'Pack del vendedor',
            result: r,
          ),
          pair,
        );
        final signed = await const PdfReports().inspectionReport(
          t,
          InspectionReportData(
            generatedAt: data.generatedAt,
            result: r,
            light: data.light,
            advice: data.advice,
            packName: data.packName,
            certificate: cert,
          ),
        );

        expect(_isPdf(signed), isTrue);
        expect(signed.length, greaterThan(plain.length));
        // The code is on the page, so a buyer can read it out to somebody
        // without a scanner, and it is only there when the sheet is signed.
        expect(_textOf(signed), contains(cert.code));
        expect(_textOf(signed), contains(cert.issuer));
        expect(_textOf(plain).contains(cert.code), isFalse);
      },
    );
  });

  group('the inspection sheet with earlier runs', () {
    test('prints the earlier runs and what repeating them showed', () async {
      final r = _result();
      final earlier = [
        PastInspection(
          at: DateTime.utc(2026, 3, 2),
          result: _result(sagOnCell7: 0.28),
        ),
        PastInspection(
          at: DateTime.utc(2026, 4, 6),
          result: _result(sagOnCell7: 0.29),
        ),
      ];
      final comparison = const InspectionSeries().compare(r, earlier);
      final bytes = await const PdfReports().inspectionReport(
        t,
        InspectionReportData(
          generatedAt: DateTime.utc(2026, 5, 4, 12),
          result: r,
          light: const InspectionVerdicts().light(r),
          advice: const InspectionVerdicts().evaluate(r),
          packName: 'Pack del vendedor',
          comparison: comparison,
          seriesAdvice: const InspectionSeries().evaluate(comparison),
        ),
      );

      final text = _textOf(bytes);
      // Every run is on the page, with its date, so a reader can count them.
      expect(text, contains('02/03/2026'));
      expect(text, contains('06/04/2026'));
      // And the sentence a repeat earns.
      expect(text, contains(t.verdictInspRepeatSameCellBody.split(':').first));
    });

    test('a first run prints no comparison at all', () async {
      final r = _result();
      final comparison = const InspectionSeries().compare(r, const []);
      final bytes = await const PdfReports().inspectionReport(
        t,
        InspectionReportData(
          generatedAt: DateTime.utc(2026, 5, 4, 12),
          result: r,
          light: const InspectionVerdicts().light(r),
          advice: const InspectionVerdicts().evaluate(r),
          comparison: comparison,
        ),
      );
      expect(_textOf(bytes).contains(t.reportSectionSeries), isFalse);
    });
  });

  group('the battery sheet', () {
    test('renders from a pack with history', () async {
      final data = PackReportData(
        generatedAt: DateTime.utc(2026, 5, 4, 12),
        packName: 'Pack de la moto',
        model: 'JK-BD6A20S10P',
        serialNumber: 'SN-1',
        appVersion: '2.15.0',
        lastReadingAt: DateTime.utc(2026, 5, 3, 19),
        soc: 78,
        packVoltage: 62.4,
        cellCount: 16,
        deltaVolts: 0.021,
        minCellVoltage: 3.881,
        maxCellVoltage: 3.902,
        maxTemperature: 28.4,
        measuredAh: 36.2,
        baselineAh: 39.4,
        baselineAt: DateTime.utc(2025, 10, 2),
        baselineIsMeasured: true,
        configuredAh: 40,
        advertisedAh: 40,
        lostFraction: 0.081,
        capacityTests: 3,
        fullRangeKm: 84,
        rangeFromMeasuredCapacity: true,
        whPerKm: 26.5,
        drift: [
          CellDrift(
            index: 6,
            currentDeviationVolts: 0.031,
            earlyDeviationVolts: 0.006,
            changeVoltsPerMonth: 0.012,
            samples: 9000,
            spanDays: 62,
          ),
        ],
        advice: [
          Advice(
            code: AdviceCode.healthMeasured,
            level: AdviceLevel.watch,
            // What the engine puts here: how much of the original capacity
            // is left, as a percentage, not the fraction that is gone.
            value: 91.9,
            evidence: [
              Evidence(
                EvidenceKind.baselineCapacity,
                value: 39.4,
                at: DateTime.utc(2025, 10, 2),
              ),
              Evidence(
                EvidenceKind.currentCapacity,
                value: 36.2,
                at: DateTime.utc(2026, 4, 20),
              ),
            ],
          ),
        ],
        readingCount: 412000,
        historySince: DateTime.utc(2025, 9, 1),
        tripCount: 88,
        totalKm: 1204.6,
      );

      final bytes = await const PdfReports().packReport(t, data);
      expect(_isPdf(bytes), isTrue);
      final text = _textOf(bytes);
      // The measurement, the distance behind it, and the BMS setting that
      // must not be mistaken for a measurement.
      expect(text, contains('39.4 Ah'));
      expect(text, contains('1204.6 km'));
      expect(text, contains('40.0 Ah'));
      expect(text, contains('no una medida'));
    });

    test('prints maintenance in words rather than enum names', () async {
      final bytes = await const PdfReports().packReport(
        t,
        PackReportData(
          generatedAt: DateTime.utc(2026, 5, 4, 12),
          packName: 'Pack de la moto',
          maintenance: [
            MaintenanceEvent(
              id: 1,
              deviceId: 'AA',
              at: DateTime.utc(2026, 2, 1),
              kind: MaintenanceKind.cellReplaced.name,
              note: 'Celda 7',
            ),
          ],
        ),
      );

      final text = _textOf(bytes);
      expect(text, contains(t.maintKindCellReplaced.split(' ').first));
      expect(text.contains('cellReplaced'), isFalse);
    });

    test('renders for a pack nothing is known about yet', () async {
      final bytes = await const PdfReports().packReport(
        t,
        PackReportData(
          generatedAt: DateTime.utc(2026, 5, 4, 12),
          packName: 'AA:BB:CC:DD:EE:FF',
        ),
      );
      expect(_isPdf(bytes), isTrue);
    });

    test('gathers what the saved-pack screen holds', () {
      final data = PackReportData.build(
        generatedAt: DateTime.utc(2026, 5, 4, 12),
        device: _device(),
        last: null,
        degradation: null,
        outlook: null,
        drift: const [],
        advice: const [],
        trips: const [],
        maintenance: const [],
        readingCount: 0,
      );

      expect(data.packName, 'Pack de la moto');
      expect(data.model, 'JK-BD6A20S10P');
      // The advert is a fact about the purchase and belongs on the sheet even
      // when nothing has been measured yet.
      expect(data.advertisedAh, 40);
      expect(data.measuredAh, isNull);
      expect(data.totalKm, 0);
    });
  });

  group('the file name', () {
    test('says what, which pack and when', () {
      final name = ReportSharing.fileName(
        'inspeccion',
        'Pack del vendedor',
        DateTime.utc(2026, 5, 4, 11, 30).toLocal(),
      );
      expect(name, startsWith('inspeccion-Pack-del-vendedor-'));
      expect(name, endsWith('.pdf'));
    });

    test('drops what a file system would choke on', () {
      final name = ReportSharing.fileName(
        'bateria',
        'AA:BB/CC..DD',
        DateTime.utc(2026, 5, 4),
      );
      expect(name.contains('/'), isFalse);
      expect(name.contains(':'), isFalse);
      expect(name, endsWith('.pdf'));
    });
  });
}

/// The words actually drawn on the page, in order.
///
/// Reads the deflated content streams the way a viewer does, so a test can
/// assert on what somebody holding the sheet would read rather than on byte
/// counts.
String _textOf(Uint8List bytes) {
  final out = StringBuffer();
  var i = 0;
  while (true) {
    final start = _indexOf(bytes, 'stream', i);
    if (start < 0) break;
    var from = start + 'stream'.length;
    if (from < bytes.length && bytes[from] == 0x0D) from++;
    if (from < bytes.length && bytes[from] == 0x0A) from++;
    final end = _indexOf(bytes, 'endstream', from);
    if (end < 0) break;
    try {
      final inflated = ZLibCodec().decode(bytes.sublist(from, end));
      final text = latin1.decode(inflated, allowInvalid: true);
      for (final m in RegExp(r'\[\((.*?)\)\]TJ').allMatches(text)) {
        out
          ..write(m.group(1)!.replaceAll(r'\(', '(').replaceAll(r'\)', ')'))
          ..write(' ');
      }
    } on Object {
      // Not a deflated content stream: an embedded font, say.
    }
    // Past the whole marker: 'endstream' contains 'stream', and stepping
    // one byte would find that instead of the next real stream.
    i = end + 'endstream'.length;
  }
  return out.toString();
}

int _indexOf(Uint8List haystack, String needle, int from) {
  final n = needle.codeUnits;
  for (var i = from; i + n.length <= haystack.length; i++) {
    var hit = true;
    for (var j = 0; j < n.length; j++) {
      if (haystack[i + j] != n[j]) {
        hit = false;
        break;
      }
    }
    if (hit) return i;
  }
  return -1;
}

/// Every PDF starts with the same five bytes, whatever produced it.
bool _isPdf(Uint8List bytes) =>
    bytes.length > 5 && String.fromCharCodes(bytes.sublist(0, 5)) == '%PDF-';
