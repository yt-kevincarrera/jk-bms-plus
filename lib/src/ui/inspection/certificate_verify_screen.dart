import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../inspection/inspection_result.dart';
import '../../inspection/inspection_verdicts.dart';
import '../../report/certificate.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Checks a certificate somebody else produced.
///
/// The buyer's half of the seller certificate. A signed sheet is only worth
/// anything if the person holding it can check it without trusting whoever
/// handed it over, so this screen needs no key, no account and no network: the
/// signature travels with the figures, and either it matches or it does not.
///
/// A pasted certificate is untrusted input from a stranger's phone. Nothing
/// here is displayed until the signature has checked out, and what is
/// displayed afterwards is only what was signed.
class CertificateVerifyScreen extends StatefulWidget {
  const CertificateVerifyScreen({super.key});

  @override
  State<CertificateVerifyScreen> createState() =>
      _CertificateVerifyScreenState();
}

class _CertificateVerifyScreenState extends State<CertificateVerifyScreen> {
  final TextEditingController _input = TextEditingController();
  bool _busy = false;
  Certificate? _accepted;
  String? _problem;

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
    if (!mounted) return;
    setState(() {
      _busy = false;
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
    final light = const InspectionVerdicts().light(r);
    final tone = switch (light) {
      InspectionLight.problem => AppTheme.bad,
      InspectionLight.watch => AppTheme.watch,
      InspectionLight.good => AppTheme.good,
    };
    return [
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.good.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.good.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_outlined, color: AppTheme.good),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t.certificateValid,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppTheme.good,
                ),
              ),
            ),
          ],
        ),
      ),
      Section(
        title: t.reportSectionCertificate,
        children: [
          InfoRow(t.reportCertificateCode, cert.code),
          InfoRow(t.reportCertificateIssuer, cert.issuer),
          InfoRow(t.reportCertificateIssuedAt, _date(cert.content.issuedAt)),
          InfoRow(
            t.reportSectionTest,
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
            t.reportRestDelta,
            '${r.restDeltaVolts.toStringAsFixed(3)} V',
          ),
          InfoRow(
            t.reportMedianSag,
            r.medianHeavySagVolts == null
                ? '--'
                : '${r.medianHeavySagVolts!.toStringAsFixed(3)} V',
            last: true,
          ),
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

  static String _date(DateTime utc) {
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }
}
