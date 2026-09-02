import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../ble/link_trouble.dart';
import '../theme.dart';

/// Puts Bluetooth trouble into words, with the raw text one tap away.
///
/// The rule this enforces: the rider reads a sentence about their motorcycle,
/// never a stack trace. Everything the exception said is still reachable,
/// because when something genuinely unexpected happens that text is the only
/// thing worth having, but it is behind a disclosure rather than in front of
/// somebody trying to work out why their bike will not connect.
String linkTroubleWording(AppL10n t, LinkTrouble trouble) =>
    switch (trouble.kind) {
      LinkTroubleKind.busy => t.troubleBusy,
      LinkTroubleKind.outOfRange => t.troubleOutOfRange,
      LinkTroubleKind.bluetoothOff => t.troubleBluetoothOff,
      LinkTroubleKind.permission => t.troublePermission,
      LinkTroubleKind.locationOff => t.troubleLocationOff,
      LinkTroubleKind.slowFrames => t.troubleSlowFrames,
      LinkTroubleKind.unknown => t.troubleGeneric,
    };

/// A message with an expandable "details" line carrying the original text.
class LinkTroubleText extends StatefulWidget {
  const LinkTroubleText({
    required this.message,
    this.detail = '',
    this.color,
    super.key,
  });

  /// The sentence to lead with. Already in the rider's language.
  final String message;

  /// The raw exception text, if there is one worth keeping.
  final String detail;

  final Color? color;

  @override
  State<LinkTroubleText> createState() => _LinkTroubleTextState();
}

class _LinkTroubleTextState extends State<LinkTroubleText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final colour = widget.color ?? AppTheme.bad;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.message,
          style: TextStyle(fontSize: 12.5, height: 1.4, color: colour),
        ),
        if (widget.detail.isNotEmpty) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => _open = !_open),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.linkDetails,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textFaint,
                  ),
                ),
                Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  size: 15,
                  color: AppTheme.textFaint,
                ),
              ],
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: SelectableText(
                widget.detail,
                style: const TextStyle(
                  fontSize: 10.5,
                  height: 1.35,
                  fontFamily: 'monospace',
                  color: AppTheme.textFaint,
                ),
              ),
            ),
        ],
      ],
    );
  }
}
