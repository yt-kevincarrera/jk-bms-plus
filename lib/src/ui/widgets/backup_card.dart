import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../../bms_service.dart';
import '../../data/backup.dart';
import '../theme.dart';
import 'common.dart';

/// Getting the whole history off the phone, and back onto one.
///
/// The exports elsewhere in the app are for reading data somewhere else. This
/// is the one that answers "the phone is gone". Everything the app is built on
/// is accumulated over months and lives in a single file with no copy.
class BackupCard extends StatefulWidget {
  const BackupCard({required this.service, super.key});

  final BmsService service;

  @override
  State<BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends State<BackupCard> {
  bool _busy = false;
  String? _message;
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);

    return Section(
      title: t.backupTitle,
      intro: t.backupIntro,
      children: [
        if (_busy)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  t.backupWorking,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textFaint,
                  ),
                ),
              ],
            ),
          ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: Text(
              _message!,
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: _failed ? AppTheme.bad : AppTheme.good,
              ),
            ),
          ),
        TextButton.icon(
          onPressed: _busy ? null : () => _export(t, withFrames: true),
          icon: const Icon(Icons.save_alt, size: 18),
          label: Text(t.backupExport),
        ),
        TextButton.icon(
          onPressed: _busy ? null : () => _export(t, withFrames: false),
          icon: const Icon(Icons.save_alt, size: 18),
          label: Text(t.backupExportLight),
        ),
        TextButton.icon(
          onPressed: _busy ? null : () => _import(t),
          icon: const Icon(Icons.restore, size: 18),
          label: Text(t.backupImport),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Future<void> _export(AppL10n t, {required bool withFrames}) async {
    final db = widget.service.repository?.db;
    if (db == null) return;

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final file =
          await BackupCodec(db).export(includeRawFrames: withFrames);
      // Straight to the share sheet: the file lands in the app's private
      // directory, which nothing else on the phone can reach, so writing it
      // without handing it over would be a backup you cannot retrieve.
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          fileNameOverrides: [p.basename(file.path)],
        ),
      );
      if (mounted) setState(() => _message = null);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = t.backupFailed('$e');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import(AppL10n t) async {
    final db = widget.service.repository?.db;
    if (db == null) return;

    final picked = await FilePicker.pickFile(type: FileType.any);
    final path = picked?.path;
    if (path == null || !mounted) return;

    final replace = await _askReplace(t);
    if (replace == null || !mounted) return;

    setState(() {
      _busy = true;
      _message = null;
      _failed = false;
    });
    try {
      final result =
          await BackupCodec(db).import(File(path), replace: replace);
      // Everything derived from history has to be rebuilt: the range estimate
      // is held in memory and would otherwise ignore every restored ride.
      await widget.service.relearnRangeFromTrips();
      if (mounted) {
        setState(() {
          _failed = false;
          _message = t.backupDone(
            '${result.trips}',
            '${result.snapshots}',
            '${result.devices}',
          );
        });
      }
    } on BackupFormatException catch (e) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = t.backupFailed(e.reason);
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = t.backupFailed('$e');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Merge or replace. Asked every time, because the wrong answer to this
  /// silently destroys whatever the phone has been recording since the backup
  /// was taken.
  Future<bool?> _askReplace(AppL10n t) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.backupImportChoose),
          content: Text(
            t.backupReplaceWarning,
            style: const TextStyle(fontSize: 13, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.packsCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t.backupImportMerge),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.bad),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(t.backupImportReplace),
            ),
          ],
        ),
      );
}
