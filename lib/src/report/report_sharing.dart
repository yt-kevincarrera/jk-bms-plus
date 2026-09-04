import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Puts a finished PDF where the rider can do something with it.
///
/// Shared rather than saved: the sheet exists to be sent to a workshop, a
/// buyer or a group chat, and every phone already has a better idea than this
/// app about where a file should go. The copy in the cache is a handover, not
/// storage, and the system clears it when it needs the space.
class ReportSharing {
  const ReportSharing();

  Future<File> write(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> share(
    Uint8List bytes, {
    required String fileName,
    String? text,
  }) async {
    final file = await write(bytes, fileName);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        fileNameOverrides: [fileName],
        text: text,
      ),
    );
  }

  /// A file name somebody can find again in a downloads folder six months
  /// later: what it is, which pack, and when.
  static String fileName(String prefix, String pack, DateTime at) {
    final safe = pack
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    String two(int n) => n.toString().padLeft(2, '0');
    final d = at.toLocal();
    final stamp =
        '${d.year}${two(d.month)}${two(d.day)}-${two(d.hour)}${two(d.minute)}';
    final name = [prefix, if (safe.isNotEmpty) safe, stamp].join('-');
    return '$name.pdf';
  }
}
