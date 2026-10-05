import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../report/workshop_branding.dart';
import '../theme.dart';
import 'common.dart';

/// "Datos del taller en los informes": the name, contact line and logo the
/// PDFs carry at the top. Gated by the caller (the workshop tier).
class WorkshopBrandingCard extends StatefulWidget {
  const WorkshopBrandingCard({this.store, this.pickImage, super.key});

  /// Where it is kept. A test hands in one over a temporary directory.
  final WorkshopBrandingStore? store;

  /// Picks an image file and returns its path, or null when the rider backs
  /// out. The system file picker unless a test hands in its own.
  final Future<String?> Function()? pickImage;

  @override
  State<WorkshopBrandingCard> createState() => _WorkshopBrandingCardState();
}

class _WorkshopBrandingCardState extends State<WorkshopBrandingCard> {
  late final WorkshopBrandingStore _store =
      widget.store ?? WorkshopBrandingStore();
  final _name = TextEditingController();
  final _line = TextEditingController();
  ReportBranding _saved = ReportBranding.none;
  bool _loaded = false;
  String? _message;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _line.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final b = await _store.load();
    if (!mounted) return;
    setState(() {
      _saved = b;
      _name.text = b.name;
      _line.text = b.line;
      _loaded = true;
    });
  }

  void _say(String text, {bool failed = false}) => setState(() {
    _message = text;
    _failed = failed;
  });

  Future<void> _saveText(AppL10n t) async {
    try {
      await _store.saveText(name: _name.text, line: _line.text);
      await _load();
      _say(t.workshopSaved);
    } on Object {
      _say(t.workshopSaveFailed, failed: true);
    }
  }

  Future<String?> _defaultPick() async {
    final picked = await FilePicker.pickFile(type: FileType.image);
    return picked?.path;
  }

  Future<void> _pickLogo(AppL10n t) async {
    final path = await (widget.pickImage ?? _defaultPick)();
    if (path == null || !mounted) return;
    try {
      final ok = await _store.saveLogo(await File(path).readAsBytes());
      if (!ok) {
        _say(t.workshopLogoRefused, failed: true);
        return;
      }
      await _load();
      _say(t.workshopSaved);
    } on Object {
      _say(t.workshopSaveFailed, failed: true);
    }
  }

  Future<void> _clearLogo(AppL10n t) async {
    try {
      await _store.clearLogo();
      await _load();
    } on Object {
      _say(t.workshopSaveFailed, failed: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final logo = _saved.logo;
    return Section(
      title: t.workshopTitle,
      intro: t.workshopIntro,
      children: [
        if (!_loaded)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else ...[
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: t.workshopName,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _line,
            decoration: InputDecoration(
              labelText: t.workshopLine,
              hintText: t.workshopLineHint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: () => _saveText(t),
              child: Text(t.profileSave),
            ),
          ),
          const SizedBox(height: 12),
          Caption(t.workshopLogo, color: AppTheme.textFaint),
          const SizedBox(height: 6),
          Row(
            children: [
              if (logo != null) ...[
                Container(
                  height: 48,
                  constraints: const BoxConstraints(maxWidth: 140),
                  padding: const EdgeInsets.all(4),
                  color: Colors.white,
                  child: Image.memory(
                    logo,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Wrap(
                  spacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: () => _pickLogo(t),
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: Text(
                        logo == null
                            ? t.workshopLogoPick
                            : t.workshopLogoChange,
                      ),
                    ),
                    if (logo != null)
                      TextButton.icon(
                        onPressed: () => _clearLogo(t),
                        icon: const Icon(Icons.close, size: 18),
                        label: Text(t.workshopLogoRemove),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (_message case final m?)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                m,
                style: TextStyle(
                  fontSize: 12,
                  color: _failed ? AppTheme.watch : AppTheme.good,
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
