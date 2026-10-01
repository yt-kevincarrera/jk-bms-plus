import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../../bms_service.dart';
import '../../data/database.dart';
import '../../inspection/inspection_result.dart';
import '../../inspection/inspection_series.dart';
import '../../inspection/inspection_session.dart';
import '../../inspection/inspection_verdicts.dart';
import '../../license/entitlements.dart';
import '../../report/certificate.dart';
import '../../report/pdf_reports.dart';
import '../../report/report_data.dart';
import '../../report/report_sharing.dart';
import '../license_scope.dart';
import '../theme.dart';
import '../widgets/advice_list.dart';
import '../widgets/common.dart';
import 'inspection_sections.dart';
import 'inspection_texts.dart';

/// The traffic light, three sentences, the fidelity, and a save button.
///
/// Opened straight after a test, or from the list of saved inspections. The
/// same screen either way, so what the buyer saw in the yard is exactly what
/// they reread at home. It says "quick test" and "estimate" in so many words:
/// the PRD's one reputational risk is this screen promising more than the
/// two minutes it rests on.
class InspectionVerdictScreen extends StatefulWidget {
  const InspectionVerdictScreen({
    required this.service,
    required this.result,
    required this.samples,
    required this.bmsId,
    required this.bmsName,
    this.savedId,
    this.initialNote = '',
    this.runTotal,
    super.key,
  });

  final BmsService service;
  final InspectionResult result;
  final List<InspectionSample> samples;
  final String bmsId;
  final String bmsName;

  /// Set when this is a saved inspection being reread.
  final int? savedId;
  final String initialNote;

  /// How many runs this pack has in all, when the list that opened a saved
  /// run knows. The series only reads the runs before this one, so on its
  /// own it can only say "run 2 of 2" about the second of five.
  final int? runTotal;

  @override
  State<InspectionVerdictScreen> createState() =>
      _InspectionVerdictScreenState();
}

class _InspectionVerdictScreenState extends State<InspectionVerdictScreen> {
  static const _verdicts = InspectionVerdicts();
  late final TextEditingController _note = TextEditingController(
    text: widget.initialNote,
  );
  bool _saving = false;
  int? _savedId;

  /// Set while a sheet is being built and handed to the share sheet, so two
  /// taps cannot produce two files.
  bool _sharing = false;

  /// Which build printed the sheet. Read once; absent is not worth blocking a
  /// report over, so the line is simply left off.
  String _appVersion = '';

  final CertificateIdentity _identity = CertificateIdentity();

  /// What this pack did the last times it was tested, and how this run sits
  /// against it. Null until the lookup finishes; a first run leaves it with
  /// an empty [InspectionComparison.earlier].
  InspectionComparison? _series;

  @override
  void initState() {
    super.initState();
    _savedId = widget.savedId;
    _loadSeries();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) setState(() => _appVersion = info.version);
        })
        .catchError((Object _) {});
  }

  /// Reads the earlier runs on this pack and works out what repeating the
  /// test has added.
  ///
  /// When a saved run is being reread, only the runs before it count: a sheet
  /// printed in May should say what was known in May, not borrow a conclusion
  /// from a test done in July.
  Future<void> _loadSeries() async {
    final repo = widget.service.repository;
    final r = widget.result;
    if (repo == null) {
      if (mounted) {
        setState(() => _series = const InspectionSeries().compare(r, const []));
      }
      return;
    }
    final earlier = await repo.pastInspections(
      bmsId: widget.bmsId,
      serialNumber: r.reported.serialNumber,
      bmsName: widget.bmsName,
      before: widget.savedId == null ? null : r.at,
      excludeId: widget.savedId,
    );
    if (!mounted) return;
    setState(() => _series = const InspectionSeries().compare(r, earlier));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _isSaved => _savedId != null;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final r = widget.result;
    final light = _verdicts.light(r);
    final advice = _verdicts.evaluate(r);
    final headline = inspectionHeadline(t, light, r, verdicts: _verdicts);
    final tone = switch (light) {
      InspectionLight.good => AppTheme.good,
      InspectionLight.watch => AppTheme.watch,
      InspectionLight.problem => AppTheme.bad,
      InspectionLight.unmeasured => AppTheme.textFaint,
    };

    return Scaffold(
      appBar: AppBar(title: Text(t.inspectionTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 4, bottom: 28),
          children: [
            // A rehearsal against the app's own simulator looks exactly like
            // a real result. Said first and loudly, on every screen it is
            // shown on, so nobody reads a demo pack's figures as a battery.
            if (r.simulated == true)
              inspectionSimulatedBanner(t.inspectionSimulatedBanner),
            // --- The light ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.inspectionQuickTestLabel,
                    style: AppTheme.caption(
                      context,
                    ).copyWith(color: AppTheme.textFaint),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(top: 7),
                        decoration: BoxDecoration(
                          color: tone,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          headline,
                          style: TextStyle(
                            fontSize: 24,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: tone,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _headerLine(t, r),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textFaint,
                      fontFeatures: AppTheme.tabular,
                    ),
                  ),
                ],
              ),
            ),
            // Straight under the headline, before any findings, because it
            // is the thing that decides how to read everything below: the
            // test never got its load, so nothing below is about this pack.
            if (light == InspectionLight.unmeasured)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceRaised,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.watch),
                  ),
                  child: Text(
                    inspectionUnmeasuredText(t, r, verdicts: _verdicts),
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            AdviceList(
              advice: advice,
              title: t.verdictTitle,
              showHonestyNote: false,
            ),
            inspectionCaveatsSection(t, r),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
              child: Text(
                inspectionFidelityText(t, light, r, verdicts: _verdicts),
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppTheme.textFaint,
                ),
              ),
            ),
            _seriesSection(t),
            inspectionCellsSection(t, r, verdicts: _verdicts),
            inspectionReportedSection(t, r),
            _sheetSection(t),
            Section(
              title: t.inspectionSaveTitle,
              children: [
                TextField(
                  controller: _note,
                  minLines: 1,
                  maxLines: 3,
                  readOnly: _isSaved,
                  decoration: InputDecoration(
                    hintText: t.inspectionNoteHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13.5),
                ),
                const SizedBox(height: 12),
                if (!_isSaved) ...[
                  _creditsLine(t),
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _save(t),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: Text(t.inspectionSave),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t.inspectionDiscard),
                  ),
                ] else
                  Text(
                    t.inspectionSaved,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.good,
                    ),
                  ),
                if (widget.savedId == null) ...[
                  const SizedBox(height: 14),
                  // Repeating is what saving is for: the next run is compared
                  // against this one, and the one after that against both.
                  // Popping with true tells the connect screen to stay in
                  // inspection mode and start looking again.
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.replay, size: 18),
                    label: Text(t.inspectionRepeatButton),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.inspectionRepeatHint,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      color: AppTheme.textFaint,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _headerLine(AppL10n t, InspectionResult r) {
    final name = widget.bmsName.isEmpty ? widget.bmsId : widget.bmsName;
    final model = r.reported.model;
    final who = model.isEmpty ? name : '$name · $model';
    return '$who\n${_date(r.at)}  ·  '
        '${t.inspectionSummaryLine('${r.cellCount}', r.peakDischargeAmps.toStringAsFixed(0), '${r.durationSeconds}', '${r.readings}')}';
  }

  /// The two ways this test leaves the phone.
  ///
  /// The plain sheet is free: the inspection was already paid for by running
  /// it, and a buyer who cannot show anybody what they found has bought
  /// nothing. The signed certificate is the seller's product, so it is the one
  /// that costs a credit.
  /// What the earlier runs on this pack add.
  ///
  /// A single quick test can be wrong in ways nobody notices: a clip that was
  /// not on properly, a throttle nobody held down, a pack straight off the
  /// charger. Running it again is what turns a reading into evidence, so when
  /// there is a run to compare against, the comparison gets its own block
  /// rather than being mixed into this run's own findings.
  Widget _seriesSection(AppL10n t) {
    final series = _series;
    if (series == null) return const SizedBox.shrink();

    if (series.isFirstRun) {
      return Section(
        title: t.inspectionSeriesTitle,
        children: [
          Text(
            t.inspectionSeriesFirstRun,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
        ],
      );
    }

    final advice = const InspectionSeries().evaluate(series);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Section(
          title: t.reportSectionSeries,
          intro: t.inspectionSeriesIntro,
          children: [
            InfoRow(
              t.inspectionSeriesRun(
                '${series.runNumber}',
                '${widget.runTotal ?? series.runNumber}',
              ),
              _date(series.result.at),
            ),
            for (final p in series.earlier.reversed)
              InfoRow(
                t.inspectionSeriesPrevious(_date(p.at)),
                _pastSummary(t, p),
                dim: true,
              ),
            const SizedBox(height: 4),
          ],
        ),
        if (advice.isNotEmpty)
          AdviceList(
            advice: advice,
            title: t.inspectionSeriesTitle,
            showHonestyNote: false,
          ),
      ],
    );
  }

  /// One line about an earlier run: which cell gave up and how far it fell.
  String _pastSummary(AppL10n t, PastInspection p) {
    final worst = p.result.worstSag;
    if (worst == null) return t.inspectionCaveatNoHeavyLoad;
    return '${t.reportCell} ${worst.index}  ${worst.heavySagVolts!.toStringAsFixed(3)} V';
  }

  Widget _sheetSection(AppL10n t) {
    final e = LicenseScope.entitlements(context);
    // A rehearsal with the simulated pack is never signed. A certificate is
    // a statement that these figures came off a battery, and these did not.
    final simulated = widget.result.simulated == true;
    final canSign = e.allows(Feature.sellerCertificate) && !simulated;
    return Section(
      title: t.reportSectionCertificate,
      children: [
        OutlinedButton.icon(
          onPressed: _sharing ? null : () => _sharePdf(t, sign: false),
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: Text(t.reportInspectionPdfButton),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _sharing || !canSign
              ? null
              : () => _sharePdf(t, sign: true),
          icon: const Icon(Icons.verified_outlined, size: 18),
          label: Text(t.reportCertificateButton),
        ),
        const SizedBox(height: 8),
        Text(
          simulated ? t.certificateNoSimulated : _certificateCreditsLine(t, e),
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.45,
            color: AppTheme.textFaint,
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  String _certificateCreditsLine(AppL10n t, Entitlements e) {
    if (!LicenseScope.of(context).enabled || e.isWorkshop) {
      return t.reportCertificateExplain;
    }
    return e.allows(Feature.sellerCertificate)
        ? t.certificateCreditsLeft('${e.certificateCreditsLeft}')
        : t.certificateCreditsGone;
  }

  /// Builds the sheet and hands it to the phone's share sheet.
  ///
  /// The credit for a certificate is spent only once the signature exists: a
  /// share the rider cancels has still produced the document, but a failure
  /// while building one must not cost anything.
  Future<void> _sharePdf(AppL10n t, {required bool sign}) async {
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    final license = LicenseScope.of(context);
    try {
      final r = widget.result;
      Certificate? certificate;
      if (sign && r.simulated == true) return;
      if (sign) {
        if (!await license.consumeCertificate()) {
          messenger.showSnackBar(
            SnackBar(content: Text(t.certificateCreditsGone)),
          );
          return;
        }
        certificate = await const Certificates().issue(
          CertificateContent(
            issuedAt: DateTime.now().toUtc(),
            packName: _packLabel(),
            result: r,
            note: _note.text.trim(),
            // The earlier runs are signed with this one. A single test
            // showing a bad cell is a claim a seller can argue with; three
            // runs a month apart all naming the same cell is not.
            history: [
              for (final past in _series?.earlier ?? const <PastInspection>[])
                CertifiedRun.from(past),
            ],
          ),
          await _identity.keyPair(),
        );
      }

      final series = _series;
      final bytes = await const PdfReports().inspectionReport(
        t,
        InspectionReportData(
          generatedAt: DateTime.now().toUtc(),
          result: r,
          light: _verdicts.light(r),
          advice: _verdicts.evaluate(r),
          packName: _packLabel(),
          note: _note.text.trim(),
          appVersion: _appVersion,
          certificate: certificate,
          comparison: series,
          seriesAdvice: series == null
              ? const []
              : const InspectionSeries().evaluate(series),
        ),
      );
      await const ReportSharing().share(
        bytes,
        fileName: ReportSharing.fileName(
          sign ? 'certificado' : 'inspeccion',
          _packLabel(),
          r.at,
        ),
        text: t.reportShareText,
      );
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(t.reportFailed)));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  String _packLabel() {
    final name = widget.bmsName.isEmpty ? widget.bmsId : widget.bmsName;
    final model = widget.result.reported.model;
    return model.isEmpty ? name : '$name  $model';
  }

  Widget _creditsLine(AppL10n t) {
    final e = LicenseScope.entitlements(context);
    if (e.isWorkshop) return const SizedBox.shrink();
    if (!e.allows(Feature.inspection)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          t.inspectionCreditsGone,
          style: const TextStyle(fontSize: 12, color: AppTheme.watch),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        t.inspectionCreditsLeft('${e.inspectionCreditsLeft}'),
        style: const TextStyle(fontSize: 12, color: AppTheme.textFaint),
      ),
    );
  }

  Future<void> _save(AppL10n t) async {
    final repo = widget.service.repository;
    if (repo == null) return;
    setState(() => _saving = true);

    // The credit is spent on saving, not on looking: a test that was aborted
    // or came out with nothing measured costs nothing. The workshop tier and
    // a build with licensing off never spend.
    final license = LicenseScope.of(context);
    final ok = await license.consumeInspection();
    if (!ok) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.inspectionCreditsGone)));
      }
      return;
    }

    final r = widget.result;
    final id = await repo.saveInspection(
      InspectionsCompanion.insert(
        at: r.at,
        bmsId: widget.bmsId,
        bmsName: Value(widget.bmsName),
        model: Value(r.reported.model),
        serialNumber: Value(r.reported.serialNumber),
        light: _verdicts.light(r).name,
        resultJson: jsonEncode(r.toJson()),
        samplesJson: jsonEncode([for (final s in widget.samples) s.toJson()]),
        note: Value(_note.text.trim()),
      ),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _savedId = id;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t.inspectionSaved)));
  }

  static String _date(DateTime utc) {
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }
}
