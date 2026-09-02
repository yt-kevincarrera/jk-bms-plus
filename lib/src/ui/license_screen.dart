import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../l10n/app_localizations.dart';
import '../license/entitlements.dart';
import '../license/license_controller.dart';
import '../license/license_payload.dart';
import '../license/license_verifier.dart';
import 'license_scope.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Where a phone becomes Pro.
///
/// Three things, top to bottom: what this phone is right now, the code to send
/// with the payment, and the box to paste the key into. Everything else on the
/// page is explanation, and there is deliberately no price on it: the price is
/// agreed in the chat where the payment happens, and a number baked into an
/// APK that gets shared for months would be wrong for most of them.
class LicenseScreen extends StatefulWidget {
  const LicenseScreen({super.key});

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final TextEditingController _key = TextEditingController();
  String _version = '';
  String? _message;
  bool _failed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) setState(() => _version = info.version);
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final controller = LicenseScope.of(context);
    final e = controller.entitlements;
    final now = DateTime.now().toUtc();

    return Scaffold(
      appBar: AppBar(title: Text(t.licenseTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 4, bottom: 28),
          children: [
            _statusSection(t, e, now),
            _deviceSection(t, controller),
            _pasteSection(t, controller),
            if (controller.activeLicenses.isNotEmpty)
              _keysSection(t, controller, now),
            Explainer(title: t.licenseWhyTitle, paragraphs: [t.licenseWhyBody]),
          ],
        ),
      ),
    );
  }

  // --- Status ---

  Widget _statusSection(AppL10n t, Entitlements e, DateTime now) {
    final (label, color) = _statusLabel(t, e.status);
    final body = switch (e.status) {
      LicenseStatus.free => t.licenseFreeBody,
      LicenseStatus.trial => t.licenseTrialLeft('${e.trialDaysLeft(now)}'),
      LicenseStatus.pro => t.licenseProBody,
      LicenseStatus.workshop =>
        e.workshopExpiresAt == null
            ? t.licenseWorkshopNoEnd
            : t.licenseWorkshopBody(_date(e.workshopExpiresAt!)),
      LicenseStatus.workshopExpired => t.licenseWorkshopExpiredBody,
    };
    final extras = <String>[
      if (e.label.isNotEmpty) t.licenseLabel(e.label),
      if (e.inspectionCreditsLeft > 0 || e.isWorkshop)
        t.licenseCreditsLeft(e.isWorkshop ? '∞' : '${e.inspectionCreditsLeft}'),
      if (e.certificateCreditsLeft > 0 || e.isWorkshop)
        t.licenseCertificatesLeft(
          e.isWorkshop ? '∞' : '${e.certificateCreditsLeft}',
        ),
    ];

    return Section(
      title: t.licenseTitle,
      accent: color,
      trailing: Pill(label, color: color),
      children: [
        Text(
          body,
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.45,
            color: AppTheme.textSecondary,
          ),
        ),
        if (extras.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final x in extras)
            Text(
              x,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppTheme.textPrimary,
                fontFeatures: AppTheme.tabular,
              ),
            ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  static (String, Color) _statusLabel(AppL10n t, LicenseStatus s) =>
      switch (s) {
        LicenseStatus.free => (t.licenseStatusFree, AppTheme.textSecondary),
        LicenseStatus.trial => (t.licenseStatusTrial, AppTheme.cool),
        LicenseStatus.pro => (t.licenseStatusPro, AppTheme.good),
        LicenseStatus.workshop => (t.licenseStatusWorkshop, AppTheme.good),
        LicenseStatus.workshopExpired => (
          t.licenseStatusWorkshopExpired,
          AppTheme.watch,
        ),
      };

  // --- Device code ---

  Widget _deviceSection(AppL10n t, LicenseController controller) {
    final code = controller.deviceCode?.display ?? '--';
    return Section(
      title: t.licenseDeviceCode,
      intro: t.licenseDeviceCodeHint,
      children: [
        const SizedBox(height: 4),
        Center(
          child: SelectableText(
            code,
            style: AppTheme.readout(24).copyWith(letterSpacing: 1.5),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _copy(t, code),
                icon: const Icon(Icons.copy, size: 16),
                label: Text(
                  t.licenseCopyCode,
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _copy(
                  t,
                  t.licenseRequestMessage(
                    code,
                    _version.isEmpty ? '--' : _version,
                  ),
                ),
                icon: const Icon(Icons.chat_outlined, size: 16),
                label: Text(
                  t.licenseCopyRequest,
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Future<void> _copy(AppL10n t, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t.licenseCopied)));
  }

  // --- Paste ---

  Widget _pasteSection(AppL10n t, LicenseController controller) {
    final can = controller.canActivate;
    return Section(
      title: t.licensePasteTitle,
      intro: can ? t.licensePasteHint : null,
      children: [
        if (!can)
          Text(
            t.licenseNotConfigured,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppTheme.watch,
            ),
          ),
        if (can) ...[
          TextField(
            controller: _key,
            minLines: 2,
            maxLines: 4,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              hintText: 'JKB1.…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _busy ? null : () => _activate(t, controller),
            icon: const Icon(Icons.key, size: 18),
            label: Text(t.licenseActivate),
          ),
        ],
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _message!,
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: _failed ? AppTheme.bad : AppTheme.good,
              ),
            ),
          ),
        const SizedBox(height: 6),
      ],
    );
  }

  Future<void> _activate(AppL10n t, LicenseController controller) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await controller.activate(_key.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failed = !result.accepted;
      _message = switch (result.rejection) {
        null => result.duplicate ? t.licenseAlreadyActive : t.licenseActivated,
        LicenseRejection.malformed => t.licenseRejectedMalformed,
        LicenseRejection.badSignature => t.licenseRejectedSignature,
        LicenseRejection.wrongDevice => t.licenseRejectedDevice,
        LicenseRejection.expired => t.licenseRejectedExpired,
      };
      if (result.accepted) _key.clear();
    });
  }

  // --- Keys on this phone ---

  Widget _keysSection(AppL10n t, LicenseController controller, DateTime now) {
    final keys = controller.activeLicenses;
    return Section(
      title: t.licenseActiveKeys,
      children: [
        for (final k in keys)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _tierLabel(t, k.payload.tier),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (k.payload.label.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                k.payload.label,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          t.licenseKeyActivated(_date(k.activatedAt)),
                          if (k.payload.expiresAt != null)
                            k.payload.isExpiredAt(now)
                                ? t.licenseKeyExpired(
                                    _date(k.payload.expiresAt!),
                                  )
                                : t.licenseKeyExpires(
                                    _date(k.payload.expiresAt!),
                                  ),
                          if (k.payload.inspectionCredits > 0 ||
                              k.payload.certificateCredits > 0)
                            t.licenseKeyCredits(
                              '${k.payload.inspectionCredits}',
                              '${k.payload.certificateCredits}',
                            ),
                        ].join('  ·  '),
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: k.payload.isExpiredAt(now)
                              ? AppTheme.watch
                              : AppTheme.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _confirmRemove(t, controller, k.id),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textFaint,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    t.licenseRemoveKey,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _confirmRemove(
    AppL10n t,
    LicenseController controller,
    String id,
  ) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceRaised,
        title: Text(t.licenseRemoveConfirmTitle),
        content: Text(
          t.licenseRemoveConfirmBody,
          style: const TextStyle(fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.bad),
            child: Text(t.licenseRemoveKey),
          ),
        ],
      ),
    );
    if (go ?? false) await controller.remove(id);
  }

  static String _tierLabel(AppL10n t, LicenseTier tier) => switch (tier) {
    LicenseTier.pro => t.licenseStatusPro,
    LicenseTier.workshop => t.licenseStatusWorkshop,
    LicenseTier.credits => t.licenseCreditsLeft('').replaceAll(':', '').trim(),
  };

  static String _date(DateTime utc) {
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}

/// The compact card on the settings screen: status in one line, a way in.
class LicenseCard extends StatelessWidget {
  const LicenseCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final e = LicenseScope.entitlements(context);
    final now = DateTime.now().toUtc();
    final (label, color) = _LicenseScreenState._statusLabel(t, e.status);
    final line = switch (e.status) {
      LicenseStatus.trial => t.licenseTrialLeft('${e.trialDaysLeft(now)}'),
      LicenseStatus.free => t.licenseFreeBody,
      LicenseStatus.pro => t.licenseProBody,
      LicenseStatus.workshop =>
        e.workshopExpiresAt == null
            ? t.licenseWorkshopNoEnd
            : t.licenseWorkshopBody(
                _LicenseScreenState._date(e.workshopExpiresAt!),
              ),
      LicenseStatus.workshopExpired => t.licenseWorkshopExpiredBody,
    };

    return Section(
      title: t.licenseTitle,
      accent: color,
      trailing: Pill(label, color: color),
      children: [
        Text(
          line,
          style: const TextStyle(
            fontSize: 12,
            height: 1.45,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const LicenseScreen()),
          ),
          icon: const Icon(Icons.key_outlined, size: 18),
          label: Text(t.licenseOpen),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}
