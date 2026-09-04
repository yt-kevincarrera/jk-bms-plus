import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../l10n/app_localizations.dart';
import '../inspection/inspection_result.dart';
import '../inspection/inspection_series.dart';
import '../pack/chemistry.dart';
import '../metrics/advice_engine.dart';
import '../metrics/maintenance.dart';
import '../ui/widgets/advice_list.dart';
import 'report_data.dart';

/// The printed sheets: one for the rider's own pack, one for an inspection.
///
/// A PDF is what survives the conversation. The rider takes it to the
/// workshop, attaches it to the advert, or keeps it as the record of what the
/// pack was doing before it was sold. So the sheets are built to be read by
/// somebody who was not there: every figure carries its unit, measurements are
/// separated from what the BMS merely claims, and the honesty note is on the
/// page rather than in a settings screen nobody prints.
///
/// The layout only prints what it is handed. Nothing here recomputes, guesses
/// or fills a gap with a plausible number: a missing figure prints as a dash,
/// because a report that quietly invents is worse than one that admits it does
/// not know.
class PdfReports {
  const PdfReports();

  /// Sober, printer-friendly, and legible in black and white: these sheets get
  /// photocopied and photographed far more often than they get looked at on a
  /// screen.
  static const PdfColor _ink = PdfColor.fromInt(0xFF16181D);
  static const PdfColor _faint = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _rule = PdfColor.fromInt(0xFFD8DCE3);
  static const PdfColor _good = PdfColor.fromInt(0xFF1B7F4B);
  static const PdfColor _watch = PdfColor.fromInt(0xFFB4790C);
  static const PdfColor _bad = PdfColor.fromInt(0xFFB3261E);

  /// The "my battery" sheet.
  Future<Uint8List> packReport(AppL10n t, PackReportData d) async {
    final doc = pw.Document(
      title: t.reportPackTitle,
      author: t.appTitle,
      creator: t.appTitle,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
        theme: pw.ThemeData.withFont().copyWith(
          defaultTextStyle: pw.TextStyle(fontSize: 9.5, color: _ink),
        ),
        footer: (context) => _footer(t, context),
        build: (context) => [
          _header(
            t,
            title: t.reportPackTitle,
            subject: d.packName,
            detail: _identityLine(d.model, d.serialNumber),
            generatedAt: d.generatedAt,
            appVersion: d.appVersion,
          ),
          _section(t.reportSectionNow, [
            _row(t.reportLastReading, _dateTime(d.lastReadingAt)),
            _row(t.soc, _pct(d.soc)),
            _row(t.reportPackVoltage, _volts(d.packVoltage, 2)),
            _row(t.reportCellCount, d.cellCount?.toString() ?? _dash),
            _row(t.reportDelta, _volts(d.deltaVolts, 3)),
            _row(
              t.reportCellRange,
              d.minCellVoltage == null || d.maxCellVoltage == null
                  ? _dash
                  : '${_volts(d.minCellVoltage, 3)} - ${_volts(d.maxCellVoltage, 3)}',
            ),
            _row(t.reportMaxTemperature, _celsius(d.maxTemperature)),
          ]),
          _section(t.reportSectionCapacity, [
            _row(t.offlineBestMeasured, _ah(d.baselineAh), strong: true),
            _row(t.degNowTitle, _ah(d.measuredAh)),
            _row(
              t.degLost,
              d.lostFraction == null
                  ? t.degLostUnknown
                  : '${(d.lostFraction! * 100).toStringAsFixed(1)} %',
            ),
            _row(t.reportConfiguredCapacity, _ah(d.configuredAh)),
            _row(t.reportAdvertisedCapacity, _ah(d.advertisedAh)),
            _row(t.reportCapacityTests, '${d.capacityTests}'),
          ], note: t.reportCapacityNote),
          _section(t.reportSectionRange, [
            _row(
              t.rangeFull,
              d.fullRangeKm == null
                  ? _dash
                  : '${d.fullRangeKm!.toStringAsFixed(0)} km',
              strong: true,
            ),
            _row(
              t.reportConsumption,
              d.whPerKm == null
                  ? _dash
                  : '${d.whPerKm!.toStringAsFixed(0)} Wh/km',
            ),
            _row(
              t.reportRangeBasis,
              d.rangeFromMeasuredCapacity
                  ? t.reportRangeFromMeasured
                  : t.reportRangeFromCatalogue,
            ),
          ]),
          if (d.advice.isNotEmpty) _verdicts(t, d.advice),
          if (d.drift.isNotEmpty) _driftTable(t, d),
          if (d.baseline != null) _dayOne(t, d),
          _section(t.reportSectionHistory, [
            _row(t.offlineHistorySince, _date(d.historySince)),
            _row(t.reportReadings, '${d.readingCount}'),
            _row(t.offlineTrips, '${d.tripCount}'),
            _row(t.offlineTotalKm, '${d.totalKm.toStringAsFixed(1)} km'),
          ]),
          if (d.maintenance.isNotEmpty) _maintenance(t, d),
          _honesty(t.reportHonestyPack),
        ],
      ),
    );

    return doc.save();
  }

  /// What the pack is, and what it looked like on day one.
  ///
  /// The chemistry and the date come from the rider; everything else was
  /// captured once and left alone. Nothing here is a capacity figure: a
  /// snapshot cannot measure what a battery holds, and a sheet that implied
  /// otherwise would be the most convincing wrong number in the document.
  pw.Widget _dayOne(AppL10n t, PackReportData d) {
    final baseline = d.baseline!;
    final since = d.sinceDayOne;
    return _section(t.reportSectionDayOne, [
      _row(t.profileChemistry, _chemistryName(t, d.chemistry)),
      if (d.acquiredAt != null) _row(t.profileAcquired, _date(d.acquiredAt)),
      _row(t.profileBaseline, _date(baseline.capturedAt)),
      _row(
        t.profileDeltaThenNow,
        since == null
            ? '${baseline.deltaVolts.toStringAsFixed(3)} V'
            : '${since.thenDeltaVolts.toStringAsFixed(3)} V  ->  '
                  '${since.nowDeltaVolts.toStringAsFixed(3)} V',
      ),
      if (since?.worstDrift != null)
        _row(
          t.profileWorstDrift,
          t.profileWorstDriftValue(
            '${since!.worstDrift!.index}',
            (since.worstDrift!.driftVolts * 1000).toStringAsFixed(0),
          ),
        ),
      if (since?.cyclesSince != null)
        _row(t.profileCyclesSince, '${since!.cyclesSince}'),
      if (since != null)
        _row(
          t.profileConfigChanged,
          since.configChanged.isEmpty
              ? t.profileConfigUnchanged
              : t.profileConfigChangedCount('${since.configChanged.length}'),
        ),
    ], note: t.reportDayOneNote);
  }

  static String _chemistryName(AppL10n t, CellChemistry c) => switch (c) {
    CellChemistry.lfp => t.chemistryLfp,
    CellChemistry.nmc => t.chemistryNmc,
    CellChemistry.unknown => t.chemistryUnknown,
  };

  /// The inspection sheet, signed or not.
  Future<Uint8List> inspectionReport(AppL10n t, InspectionReportData d) async {
    final r = d.result;
    final title = d.isCertificate
        ? t.reportCertificateTitle
        : t.reportInspectionTitle;
    final doc = pw.Document(
      title: title,
      author: t.appTitle,
      creator: t.appTitle,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
        theme: pw.ThemeData.withFont().copyWith(
          defaultTextStyle: pw.TextStyle(fontSize: 9.5, color: _ink),
        ),
        footer: (context) => _footer(t, context),
        build: (context) => [
          _header(
            t,
            title: title,
            subject: d.packName.isEmpty ? t.reportUnknownPack : d.packName,
            detail: _identityLine(r.reported.model, r.reported.serialNumber),
            generatedAt: d.generatedAt,
            appVersion: d.appVersion,
          ),
          _lightBanner(t, d.light),
          _section(t.reportSectionTest, [
            _row(t.reportTestedAt, _dateTime(r.at)),
            _row(t.reportCellCount, '${r.cellCount}'),
            _row(
              t.reportPeakCurrent,
              '${r.peakDischargeAmps.toStringAsFixed(1)} A',
            ),
            _row(t.reportRestDelta, _volts(r.restDeltaVolts, 3)),
            _row(t.reportMedianSag, _volts(r.medianHeavySagVolts, 3)),
            _row(
              t.reportMedianResistance,
              r.medianResistanceOhms == null
                  ? _dash
                  : '${(r.medianResistanceOhms! * 1000).toStringAsFixed(1)} mOhm',
            ),
            _row(
              t.reportMedianRecovery,
              r.medianRecoverySeconds == null
                  ? _dash
                  : '${r.medianRecoverySeconds!.toStringAsFixed(1)} s',
            ),
            _row(t.reportMaxTemperature, _celsius(r.maxTemperature)),
            _row(
              t.reportDuration,
              '${r.durationSeconds} s  ${t.reportReadingsInline('${r.readings}')}',
            ),
          ]),
          if (d.advice.isNotEmpty) _verdicts(t, d.advice),
          if (d.hasSeries) _series(t, d),
          if (r.caveats.isNotEmpty) _caveats(t, r),
          _cellTable(t, r),
          _reported(t, r),
          if (d.note.isNotEmpty)
            _section(t.reportSectionNote, [
              _t(d.note, style: const pw.TextStyle(fontSize: 9.5)),
            ]),
          if (d.certificate != null) _certificateBlock(t, d),
          _honesty(t.reportHonestyInspection(_date(r.at))),
        ],
      ),
    );

    return doc.save();
  }

  // --- pieces ---

  /// Every string that reaches the page goes through here.
  ///
  /// The sheets are laid out in the PDF standard fonts, which have no
  /// glyph for anything outside Windows-1252: an ohm sign lands on the page as
  /// a silent blank and takes the units off a resistance figure with it. The
  /// app's own screens keep the proper symbols; paper gets the spelled-out
  /// version, which is worse typography and better information.
  static String _safe(String s) {
    const swaps = {
      '\u2126': 'Ohm', // ohm sign
      '\u03a9': 'Ohm', // greek capital omega, which is what most fonts use
      '\u2248': '~',
      '\u2192': '->',
      '\u2264': '<=',
      '\u2265': '>=',
      '\u00b1': '+/-',
    };
    var out = s;
    swaps.forEach((from, to) => out = out.replaceAll(from, to));
    // What is left is either Latin-1, one of the handful of Windows-1252
    // extras the fonts do carry, or something nobody can print.
    const printableExtras = {
      0x20AC,
      0x201A,
      0x0192,
      0x201E,
      0x2026,
      0x2020,
      0x2021,
      0x02C6,
      0x2030,
      0x0160,
      0x2039,
      0x0152,
      0x017D,
      0x2018,
      0x2019,
      0x201C,
      0x201D,
      0x2022,
      0x2013,
      0x2014,
      0x02DC,
      0x2122,
      0x0161,
      0x203A,
      0x0153,
      0x017E,
      0x0178,
    };
    return String.fromCharCodes([
      for (final c in out.runes)
        if (c <= 0xFF || printableExtras.contains(c)) c else 0x3F,
    ]);
  }

  /// Text, sanitised. Everything on the page is built through this rather
  /// than through the layout library's own widget, so nothing can reach the
  /// page unchecked.
  static pw.Widget _t(
    String text, {
    pw.TextStyle? style,
    pw.TextAlign? textAlign,
  }) => pw.Text(_safe(text), style: style, textAlign: textAlign);

  static const String _dash = '--';

  pw.Widget _header(
    AppL10n t, {
    required String title,
    required String subject,
    required String detail,
    required DateTime generatedAt,
    required String appVersion,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _t(
                title,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 3),
              _t(subject, style: const pw.TextStyle(fontSize: 12)),
              if (detail.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                _t(
                  detail,
                  style: const pw.TextStyle(fontSize: 8.5, color: _faint),
                ),
              ],
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _t(
                t.appTitle,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              _t(
                t.reportGeneratedAt(_dateTime(generatedAt)),
                style: const pw.TextStyle(fontSize: 8, color: _faint),
              ),
              if (appVersion.isNotEmpty)
                _t(
                  t.reportAppVersion(appVersion),
                  style: const pw.TextStyle(fontSize: 8, color: _faint),
                ),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Divider(color: _rule, height: 1, thickness: 1),
    ],
  );

  pw.Widget _footer(AppL10n t, pw.Context context) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 8),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _t(t.appTitle, style: const pw.TextStyle(fontSize: 7.5, color: _faint)),
        _t(
          t.reportPageOf('${context.pageNumber}', '${context.pagesCount}'),
          style: const pw.TextStyle(fontSize: 7.5, color: _faint),
        ),
      ],
    ),
  );

  pw.Widget _section(String title, List<pw.Widget> children, {String? note}) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 14),
          _t(
            title.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _faint,
              letterSpacing: 0.6,
            ),
          ),
          pw.SizedBox(height: 6),
          ...children,
          if (note != null) ...[
            pw.SizedBox(height: 5),
            _t(note, style: const pw.TextStyle(fontSize: 8, color: _faint)),
          ],
        ],
      );

  pw.Widget _row(String label, String value, {bool strong = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 3,
              child: _t(label, style: const pw.TextStyle(fontSize: 9.5)),
            ),
            pw.Expanded(
              flex: 2,
              child: _t(
                value,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: strong
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );

  /// The app's own sentences, each with the facts underneath it.
  ///
  /// Printing the conclusion without its evidence would make the sheet an
  /// assertion. The whole point of the verdict layer is that every sentence
  /// can be checked, and paper is where that matters most: the person reading
  /// it cannot tap anything.
  pw.Widget _verdicts(AppL10n t, List<Advice> advice, {String? title}) =>
      _section(title ?? t.verdictTitle, [
        for (final a in advice)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 6,
                      height: 6,
                      margin: const pw.EdgeInsets.only(top: 3, right: 6),
                      decoration: pw.BoxDecoration(
                        color: _levelColour(a.level),
                        shape: pw.BoxShape.circle,
                      ),
                    ),
                    pw.Expanded(
                      child: _t(
                        adviceTitle(t, a),
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 12, top: 2),
                  child: _t(
                    adviceBody(t, a),
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                if (a.evidence.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 12, top: 3),
                    child: _t(
                      [
                        for (final e in a.evidence)
                          _evidenceText(describeEvidence(t, e)),
                      ].join('   .   '),
                      style: const pw.TextStyle(fontSize: 8, color: _faint),
                    ),
                  ),
              ],
            ),
          ),
      ]);

  static String _evidenceText((String, String) pair) =>
      '${pair.$1}: ${pair.$2}';

  pw.Widget _driftTable(
    AppL10n t,
    PackReportData d,
  ) => _section(t.reportSectionCells, [
    _table(
      headers: [t.reportCell, t.reportDeviation, t.reportTrend, t.reportSpan],
      rows: [
        for (final c in d.drift.take(8))
          [
            '${c.index + 1}',
            _volts(c.currentDeviationVolts, 3),
            '${c.changeVoltsPerMonth >= 0 ? '+' : ''}'
                '${c.changeVoltsPerMonth.toStringAsFixed(3)} V/${t.evidencePerMonth}',
            t.reportDays('${c.spanDays}'),
          ],
      ],
    ),
  ], note: t.reportCellsNote);

  /// The earlier runs on this pack, and what repeating the test showed.
  ///
  /// The most useful thing on a second-hand battery report: one run naming a
  /// bad cell is a claim, and three runs a month apart naming the same cell
  /// is a fact about the pack.
  pw.Widget _series(AppL10n t, InspectionReportData d) {
    final c = d.comparison!;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _section(t.reportSectionSeries, [
          _table(
            headers: [
              t.reportDate,
              t.reportSeriesWorstCell,
              t.reportSag,
              t.reportRestDelta,
              t.reportPeakCurrent,
            ],
            rows: [
              for (final p in [...c.earlier, _asPast(c)])
                [
                  _date(p.at),
                  p.result.worstSag == null
                      ? _dash
                      : '${p.result.worstSag!.index}',
                  p.result.worstSag?.heavySagVolts == null
                      ? _dash
                      : p.result.worstSag!.heavySagVolts!.toStringAsFixed(3),
                  p.result.restDeltaVolts.toStringAsFixed(3),
                  '${p.result.currentStepAmps.toStringAsFixed(1)} A',
                ],
            ],
          ),
        ], note: t.reportSeriesNote),
        if (d.seriesAdvice.isNotEmpty)
          _verdicts(t, d.seriesAdvice, title: t.inspectionSeriesTitle),
      ],
    );
  }

  /// This run, in the shape the table rows are built from, so the newest line
  /// sits in the same columns as the ones before it.
  static PastInspection _asPast(InspectionComparison c) =>
      PastInspection(at: c.result.at, result: c.result);

  pw.Widget _cellTable(AppL10n t, InspectionResult r) =>
      _section(t.reportSectionCells, [
        _table(
          headers: [
            t.reportCell,
            t.reportRestVolts,
            t.reportSag,
            t.reportResistance,
            t.reportRecovery,
          ],
          rows: [
            for (final c in r.cells)
              [
                '${c.index}',
                c.restVolts.toStringAsFixed(3),
                c.heavySagVolts == null
                    ? _dash
                    : c.heavySagVolts!.toStringAsFixed(3),
                c.resistanceOhms == null
                    ? _dash
                    : (c.resistanceOhms! * 1000).toStringAsFixed(1),
                c.recoverySeconds == null
                    ? (c.recovered ? _dash : t.reportNotRecovered)
                    : c.recoverySeconds!.toStringAsFixed(1),
              ],
          ],
        ),
      ], note: t.reportCellTableNote);

  pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
  }) => pw.Table(
    border: pw.TableBorder(
      horizontalInside: const pw.BorderSide(color: _rule, width: 0.5),
      bottom: const pw.BorderSide(color: _rule, width: 0.5),
      top: const pw.BorderSide(color: _rule, width: 0.5),
    ),
    children: [
      pw.TableRow(
        children: [
          for (final h in headers)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 3,
              ),
              child: _t(
                h,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: _faint,
                ),
              ),
            ),
        ],
      ),
      for (final row in rows)
        pw.TableRow(
          children: [
            for (final cell in row)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 3,
                  horizontal: 3,
                ),
                child: _t(cell, style: const pw.TextStyle(fontSize: 9)),
              ),
          ],
        ),
    ],
  );

  /// What the BMS says about itself, kept apart from everything measured.
  ///
  /// A seller can set the cycle counter to zero and the state of health to
  /// 100% in the official app in under a minute. Printing these next to the
  /// measurements without saying so would launder a claim into evidence.
  pw.Widget _reported(AppL10n t, InspectionResult r) =>
      _section(t.reportSectionReported, [
        _row(t.reportModel, _orDash(r.reported.model)),
        _row(t.reportSerial, _orDash(r.reported.serialNumber)),
        _row(t.reportSoftware, _orDash(r.reported.softwareVersion)),
        _row(t.reportCycles, r.reported.cycleCount?.toString() ?? _dash),
        _row(t.reportConfiguredCapacity, _ah(r.reported.configuredCapacityAh)),
        _row(t.soc, _pct(r.reported.soc)),
        _row(t.reportReportedSoh, _pct(r.reported.soh)),
      ], note: t.reportReportedNote);

  pw.Widget _caveats(AppL10n t, InspectionResult r) =>
      _section(t.reportSectionCaveats, [
        for (final c in r.caveats)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: _t(
              '.  ${_caveatText(t, c)}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
      ]);

  pw.Widget _maintenance(AppL10n t, PackReportData d) =>
      _section(t.reportSectionMaintenance, [
        _table(
          headers: [t.reportDate, t.reportEvent, t.reportNote],
          rows: [
            for (final e in d.maintenance.take(10))
              [_date(e.at), _maintenanceKind(t, e.kind), e.note],
          ],
        ),
      ]);

  pw.Widget _lightBanner(AppL10n t, InspectionLight light) {
    final colour = switch (light) {
      InspectionLight.good => _good,
      InspectionLight.watch => _watch,
      InspectionLight.problem => _bad,
    };
    final text = switch (light) {
      InspectionLight.good => t.inspectionLightGood,
      InspectionLight.watch => t.inspectionLightWatch,
      InspectionLight.problem => t.inspectionLightProblem,
    };
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14),
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: colour, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 10,
            height: 10,
            margin: const pw.EdgeInsets.only(right: 8),
            decoration: pw.BoxDecoration(
              color: colour,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.Expanded(
            child: _t(
              text,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: colour,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The QR and the code, with the sentence that says what they are worth.
  pw.Widget _certificateBlock(AppL10n t, InspectionReportData d) {
    final cert = d.certificate!;
    return _section(t.reportSectionCertificate, [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Big enough to scan. A certificate for a 24-cell pack runs to
          // around 800 characters, which needs a dense QR, and a dense QR
          // printed small is a QR nobody's phone can read. At this size the
          // modules land near half a millimetre on A4, and the printed code
          // beside it is the fallback when the paper has been folded through
          // the picture.
          pw.Container(
            width: 150,
            height: 150,
            margin: const pw.EdgeInsets.only(right: 16),
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(
                errorCorrectLevel: pw.BarcodeQRCorrectionLevel.low,
              ),
              data: cert.token,
              drawText: false,
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _row(t.reportCertificateCode, cert.code, strong: true),
                _row(t.reportCertificateIssuer, cert.issuer),
                _row(
                  t.reportCertificateIssuedAt,
                  _dateTime(cert.content.issuedAt),
                ),
                pw.SizedBox(height: 6),
                _t(
                  t.reportCertificateExplain,
                  style: const pw.TextStyle(fontSize: 8.5, color: _faint),
                ),
              ],
            ),
          ),
        ],
      ),
    ]);
  }

  pw.Widget _honesty(String text) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 18),
    padding: const pw.EdgeInsets.all(9),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _rule, width: 0.5),
      borderRadius: pw.BorderRadius.circular(3),
    ),
    child: _t(text, style: const pw.TextStyle(fontSize: 8, color: _faint)),
  );

  static PdfColor _levelColour(AdviceLevel level) => switch (level) {
    AdviceLevel.problem => _bad,
    AdviceLevel.watch => _watch,
    AdviceLevel.good => _good,
    AdviceLevel.info => _faint,
  };

  static String _caveatText(AppL10n t, InspectionCaveat c) => switch (c) {
    InspectionCaveat.noHeavyLoad => t.inspectionCaveatNoHeavyLoad,
    InspectionCaveat.noLightLoad => t.inspectionCaveatNoLightLoad,
    InspectionCaveat.restNoisy => t.inspectionCaveatRestNoisy,
    InspectionCaveat.noRecovery => t.inspectionCaveatNoRecovery,
    InspectionCaveat.currentStepTooSmall => t.inspectionCaveatStepTooSmall,
    InspectionCaveat.fewReadings => t.inspectionCaveatFewReadings,
  };

  /// The stored kind is an enum name, which is fine in a database and no use
  /// on a printed page.
  static String _maintenanceKind(AppL10n t, String stored) =>
      switch (MaintenanceKind.parse(stored)) {
        MaintenanceKind.cellReplaced => t.maintKindCellReplaced,
        MaintenanceKind.manualBalance => t.maintKindManualBalance,
        MaintenanceKind.connectionsServiced => t.maintKindConnections,
        MaintenanceKind.chargerChanged => t.maintKindCharger,
        MaintenanceKind.bmsSettingsChanged => t.maintKindBmsSettings,
        MaintenanceKind.other => t.maintKindOther,
      };

  static String _identityLine(String model, String serial) => [
    if (model.isNotEmpty) model,
    if (serial.isNotEmpty) serial,
  ].join('  .  ');

  static String _orDash(String s) => s.isEmpty ? _dash : s;

  static String _ah(double? v) =>
      v == null ? _dash : '${v.toStringAsFixed(1)} Ah';

  static String _pct(double? v) =>
      v == null ? _dash : '${v.toStringAsFixed(0)} %';

  static String _volts(double? v, int places) =>
      v == null ? _dash : '${v.toStringAsFixed(places)} V';

  static String _celsius(double? v) =>
      v == null ? _dash : '${v.toStringAsFixed(1)} \u00b0C';

  static String _date(DateTime? utc) {
    if (utc == null) return _dash;
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  static String _dateTime(DateTime? utc) {
    if (utc == null) return _dash;
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}
