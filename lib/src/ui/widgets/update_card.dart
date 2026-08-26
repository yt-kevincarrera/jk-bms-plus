import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app_settings.dart';
import '../../update/release_info.dart';
import '../../update/update_downloader.dart';
import '../../update/update_service.dart';
import '../theme.dart';
import 'common.dart';

/// Checking for, fetching and installing a new build.
///
/// Every step is a button. Nothing here happens on its own — an app that can
/// install packages is the last place to put helpful automatic behaviour.
class UpdateCard extends StatefulWidget {
  const UpdateCard({required this.service, required this.settings, super.key});

  final UpdateService service;
  final AppSettings settings;

  @override
  State<UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<UpdateCard> {
  late final TextEditingController _token =
      TextEditingController(text: widget.settings.updateToken);
  bool _tokenSaved = false;
  bool _needsPermission = false;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onChanged);
    _token.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _check() async {
    widget.service.token = widget.settings.updateToken;
    await widget.service.check();
  }

  Future<void> _download() async {
    // Asked before the download, not after: 20 MB fetched and then blocked by
    // a permission dialog is 20 MB wasted.
    if (!await widget.service.canInstall()) {
      if (mounted) setState(() => _needsPermission = true);
      return;
    }
    if (mounted) setState(() => _needsPermission = false);
    await widget.service.download();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final s = widget.service;
    final check = s.lastCheck;

    return Section(
      title: t.updateTitle,
      intro: t.updateIntro,
      accent: check?.hasUpdate ?? false ? AppTheme.cool : AppTheme.textFaint,
      trailing: check?.hasUpdate ?? false
          ? Pill(check!.release!.tag, color: AppTheme.cool)
          : null,
      children: [
        InfoRow(
          t.updateInstalled,
          s.currentVersion.toString(),
          last: check?.release == null,
        ),
        // Once a check has run, the published version is worth keeping on
        // screen next to the installed one: two numbers side by side answer
        // "am I behind" without reading a sentence.
        if (check?.release != null)
          InfoRow(
            t.updatePublished,
            check!.release!.version.toString(),
            valueColor: check.hasUpdate ? AppTheme.cool : null,
            hint: check.release!.publishedAt == null
                ? null
                : t.updateReleasedOn(_date(check.release!.publishedAt!)),
          ),
        const SizedBox(height: 4),
        ..._body(t, s, check),
        const SizedBox(height: 8),
      ],
    );
  }

  List<Widget> _body(AppL10n t, UpdateService s, UpdateCheck? check) {
    switch (s.phase) {
      case UpdatePhase.checking:
        return [_note(t.updateChecking, AppTheme.textFaint)];

      case UpdatePhase.downloading:
        final p = s.progress;
        final fraction = p?.fraction;
        return [
          LinearProgressIndicator(
            value: fraction,
            backgroundColor: AppTheme.textFaint.withValues(alpha: 0.2),
            color: AppTheme.cool,
          ),
          const SizedBox(height: 8),
          _note(
            t.updateDownloading(
              fraction == null ? '--' : (fraction * 100).toStringAsFixed(0),
            ),
            AppTheme.textFaint,
          ),
        ];

      case UpdatePhase.readyToInstall:
        return [
          _note(t.updateReady, AppTheme.cool),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () async {
              await s.install();
              // The package is only cleaned up once the system has been handed
              // it; deleting sooner would pull the file out from under the
              // installer.
              await UpdateDownloader.clearCache();
            },
            icon: const Icon(Icons.system_update_alt, size: 19),
            label: Text(t.updateInstall),
          ),
        ];

      case UpdatePhase.failed:
        return [
          _note(t.updateFailed(s.error ?? '?'), AppTheme.bad),
          const SizedBox(height: 10),
          _checkButton(t, s),
        ];

      case UpdatePhase.idle:
        return _idle(t, s, check);
    }
  }

  List<Widget> _idle(AppL10n t, UpdateService s, UpdateCheck? check) {
    if (check == null) return [_checkButton(t, s)];

    return switch (check.status) {
      UpdateStatus.upToDate => [
          _note(t.updateUpToDate, AppTheme.textFaint),
          const SizedBox(height: 10),
          _checkButton(t, s),
        ],
      UpdateStatus.available => [
          _note(
            t.updateAvailable(
              check.release!.version.toString(),
              check.asset!.sizeMb.toStringAsFixed(1),
            ),
            AppTheme.cool,
          ),
          const SizedBox(height: 2),
          Text(
            check.asset!.name,
            style: const TextStyle(
              fontSize: 11,
              height: 1.4,
              color: AppTheme.textFaint,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          if (check.release!.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Caption(t.updateNotes, color: AppTheme.textFaint),
            const SizedBox(height: 2),
            Text(
              check.release!.notes.trim(),
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppTheme.textFaint,
              ),
            ),
          ],
          if (_needsPermission) ...[
            const SizedBox(height: 8),
            _note(t.updateNeedsPermission, AppTheme.watch),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: s.openInstallSettings,
              icon: const Icon(Icons.settings, size: 18),
              label: Text(t.updateOpenPermission),
            ),
          ],
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _download,
            icon: const Icon(Icons.download, size: 19),
            label: Text(t.updateDownload),
          ),
        ],
      UpdateStatus.noAssetForDevice => [
          _note(
            t.updateNoAsset(check.release!.version.toString()),
            AppTheme.watch,
          ),
          const SizedBox(height: 10),
          _checkButton(t, s),
        ],
      UpdateStatus.needsToken => [
          _note(t.updateNeedsToken, AppTheme.watch),
          const SizedBox(height: 10),
          ..._tokenField(t),
          const SizedBox(height: 10),
          _checkButton(t, s),
        ],
      UpdateStatus.failed => [
          _note(t.updateFailed(check.error ?? '?'), AppTheme.bad),
          const SizedBox(height: 10),
          _checkButton(t, s),
        ],
    };
  }

  List<Widget> _tokenField(AppL10n t) => [
        TextField(
          controller: _token,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            labelText: t.updateTokenLabel,
            labelStyle: const TextStyle(fontSize: 13),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t.updateTokenHint,
          style: const TextStyle(
            fontSize: 11,
            height: 1.4,
            color: AppTheme.textFaint,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton(
              onPressed: () async {
                await widget.settings.setUpdateToken(_token.text);
                widget.service.token = widget.settings.updateToken;
                if (mounted) setState(() => _tokenSaved = true);
              },
              child: Text(t.updateTokenSave),
            ),
            if (_tokenSaved) ...[
              const SizedBox(width: 10),
              Text(
                t.updateTokenSaved,
                style: const TextStyle(fontSize: 11.5, color: AppTheme.cool),
              ),
            ],
          ],
        ),
      ];

  Widget _checkButton(AppL10n t, UpdateService s) => FilledButton.icon(
        onPressed: s.busy ? null : _check,
        icon: const Icon(Icons.refresh, size: 19),
        label: Text(t.updateCheck),
      );

  Widget _note(String text, Color colour) => Text(
        text,
        style: TextStyle(fontSize: 12, height: 1.45, color: colour),
      );

  static String _date(DateTime utc) {
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}
