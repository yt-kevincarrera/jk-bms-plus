import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../inspection/inspection_result.dart';
import '../../inspection/inspection_verdicts.dart';
import '../../report/certificate.dart';
import '../theme.dart';
import '../widgets/advice_list.dart';
import '../widgets/common.dart';
import 'inspection_sections.dart';
import 'inspection_texts.dart';

/// Checks a certificate somebody else produced.
///
/// The buyer's half of the seller certificate. A signed sheet is only worth
/// anything if the person holding it can check it without trusting whoever
/// handed it over, so this screen needs no key, no account and no network: the
/// signature travels with the figures, and either it matches or it does not.
///
/// A pasted certificate is untrusted input from a stranger's phone. Nothing
/// here is displayed until the signature has checked out, and what is
/// displayed afterwards is only what was signed, with the verdict the app
/// draws from it.
///
/// A good signature is not a trusted issuer. The key travels inside the
/// token, so anybody with the app can sign a certificate of their own; what
/// the signature does establish is which installation signed it, and that is
/// only worth something when the buyer compares the issuer code with the one
/// the seller or the workshop publishes. So that is what the screen says.
class CertificateVerifyScreen extends StatefulWidget {
  const CertificateVerifyScreen({this.identity, super.key});

  /// This phone's own signing identity, to say "issued by this phone" when
  /// it was. Injectable for tests.
  final CertificateIdentity? identity;

  @override
  State<CertificateVerifyScreen> createState() =>
      _CertificateVerifyScreenState();
}

class _CertificateVerifyScreenState extends State<CertificateVerifyScreen> {
  final TextEditingController _input = TextEditingController();
  bool _busy = false;
  Certificate? _accepted;
  String? _problem;

  /// This phone's issuer code, when it has ever signed anything.
  String? _localIssuer;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final t = AppL10n.of(context);
    setState(() {
      _busy = true;
      _accepted = null;
      _problem = null;
    });
    final check = await const Certificates().check(_input.text);
    String? local;
    try {
      local = await (widget.identity ?? CertificateIdentity())
          .existingIssuerCode();
    } on Object {
      local = null;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _localIssuer = local;
      _accepted = check.certificate;
      _problem = check.ok
          ? null
          : switch (check.rejection!) {
              CertificateRejection.badSignature => t.certificateBadSignature,
              CertificateRejection.malformed => t.certificateMalformed,
            };
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final cert = _accepted;

    return Scaffold(
      appBar: AppBar(title: Text(t.certificateVerifyTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(
              t.certificateVerifyIntro,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _input,
              minLines: 3,
              maxLines: 6,
              inputFormatters: [LengthLimitingTextInputFormatter(8000)],
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: t.certificateVerifyHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _check,
              child: Text(t.certificateVerifyButton),
            ),
            if (_problem != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.bad.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.bad.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.gpp_bad_outlined, color: AppTheme.bad),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _problem!,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppTheme.bad,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (cert != null) ..._acceptedView(t, cert),
          ],
        ),
      ),
    );
  }

  List<Widget> _acceptedView(AppL10n t, Certificate cert) {
    final r = cert.content.result;
    // Recomputed from the signed figures rather than read from the
    // certificate: the light is a conclusion, and a seller who could sign one
    // separately could sign a red test and label it green.
    const verdicts = InspectionVerdicts();
    final light = verdicts.light(r);
    final tone = switch (light) {
      InspectionLight.problem => AppTheme.bad,
      InspectionLight.watch => AppTheme.watch,
      InspectionLight.good => AppTheme.good,
      // The test never ran. Neither reassuring nor alarming, and it must not
      // be dressed as either on a certificate somebody is being shown.
      InspectionLight.unmeasured => AppTheme.textFaint,
    };
    final fromHere = _localIssuer != null && _localIssuer == cert.issuer;
    const body = TextStyle(
      fontSize: 12.5,
      height: 1.45,
      color: AppTheme.textSecondary,
    );
    final sag = r.medianHeavySagVolts;
    final ir = r.medianResistanceOhms;
    final rec = r.medianRecoverySeconds;
    return [
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.good.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.good.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_outlined, color: AppTheme.good),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.certificateValid(cert.issuer),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppTheme.good,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // The issuer is the one thing a buyer has to check by hand, so it
            // is the biggest thing on the card.
            SelectableText(
              cert.issuer,
              style: AppTheme.readout(22, color: AppTheme.textPrimary),
            ),
            if (fromHere) ...[
              const SizedBox(height: 4),
              Text(
                t.certificateIssuedHere,
                style: const TextStyle(fontSize: 12.5, color: AppTheme.watch),
              ),
            ],
            const SizedBox(height: 8),
            Text(t.certificateDoesNotProve, style: body),
          ],
        ),
      ),
      if (r.simulated == true)
        inspectionSimulatedBanner(t.certificateSimulated)
      else if (r.simulated == null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(t.certificateSimulatedUnknown, style: body),
        ),
      // --- The verdict the signed figures give ---
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                inspectionHeadline(t, light, r, verdicts: verdicts),
                style: TextStyle(
                  fontSize: 19,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: tone,
                ),
              ),
            ),
          ],
        ),
      ),
      if (light == InspectionLight.unmeasured)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            inspectionUnmeasuredText(t, r, verdicts: verdicts),
            style: body,
          ),
        ),
      Section(
        title: t.reportSectionCertificate,
        children: [
          InfoRow(t.reportCertificateCode, cert.code),
          InfoRow(t.reportCertificateIssuer, cert.issuer),
          InfoRow(t.reportCertificateIssuedAt, _date(cert.content.issuedAt)),
          InfoRow(
            t.reportPackLabel,
            cert.content.packName.isEmpty
                ? t.reportUnknownPack
                : cert.content.packName,
            last: true,
          ),
        ],
      ),
      Section(
        title: t.reportSectionTest,
        accent: tone,
        children: [
          InfoRow(t.reportTestedAt, _date(r.at)),
          InfoRow(t.reportCellCount, '${r.cellCount}'),
          InfoRow(
            t.reportPeakCurrent,
            '${r.peakDischargeAmps.toStringAsFixed(1)} A',
          ),
          InfoRow(
            t.reportCurrentStep,
            r.hasHeavyLoad ? '${r.currentStepAmps.toStringAsFixed(1)} A' : '--',
          ),
          InfoRow(
            t.reportRestDelta,
            '${r.restDeltaVolts.toStringAsFixed(3)} V',
          ),
          InfoRow(
            r.heavyWasCharge ? t.reportMedianRise : t.reportMedianSag,
            sag == null ? '--' : '${sag.toStringAsFixed(3)} V',
          ),
          InfoRow(
            t.reportMedianResistance,
            ir == null ? '--' : '${(ir * 1000).toStringAsFixed(1)} mΩ',
          ),
          InfoRow(
            t.reportMedianRecovery,
            rec == null ? '--' : '${rec.toStringAsFixed(1)} s',
          ),
          InfoRow(
            t.reportDuration,
            '${r.durationSeconds} s  ${t.reportReadingsInline('${r.readings}')}',
            last: true,
          ),
        ],
      ),
      AdviceList(
        advice: verdicts.evaluate(r),
        title: t.verdictTitle,
        showHonestyNote: false,
      ),
      inspectionCaveatsSection(t, r),
      inspectionCellsSection(t, r, verdicts: verdicts),
      inspectionReportedSection(t, r),
      if (cert.content.note.isNotEmpty)
        Section(
          title: t.reportSectionNote,
          children: [
            Text(cert.content.note, style: body),
            const SizedBox(height: 6),
          ],
        ),
      // The runs signed alongside this one. A buyer looking at a certificate
      // that names the same cell three times is looking at a fact, not at a
      // seller's good day.
      if (cert.content.history.isNotEmpty)
        Section(
          title: t.reportSectionSeries,
          intro: t.inspectionSeriesIntro,
          children: [
            for (final run in cert.content.history)
              InfoRow(
                t.inspectionSeriesPrevious(_date(run.at)),
                _historyLine(t, run),
                dim: true,
              ),
            const SizedBox(height: 4),
          ],
        ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          t.reportCertificateExplain,
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.45,
            color: AppTheme.textFaint,
          ),
        ),
      ),
    ];
  }

  /// An earlier signed run in one line. A missing sag is a dash, not a
  /// "0.000 V" that reads as a measured nothing.
  static String _historyLine(AppL10n t, CertifiedRun run) {
    if (run.worstCell == null) return t.inspectionCaveatNoHeavyLoad;
    final sag = run.worstSagVolts;
    return '${t.reportCell} ${run.worstCell}  '
        '${sag == null ? '--' : '${sag.toStringAsFixed(3)} V'}';
  }

  static String _date(DateTime utc) {
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }
}
