import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Who is handing the sheet over: a workshop's name, a line of contact, and
/// its logo, printed at the top of the PDFs.
///
/// This is the "workshop's own logo on the PDFs" the workshop tier promised
/// and nothing implemented. A sheet a workshop gives a customer, or attaches
/// to a used pack it is selling, carries the workshop's name rather than
/// only the app's.
class ReportBranding {
  const ReportBranding({this.name = '', this.line = '', this.logo});

  final String name;

  /// A phone number, an address, a web: whatever the workshop wants under
  /// its name. One line.
  final String line;

  /// The image as picked, PNG or JPEG. Null for none.
  final Uint8List? logo;

  static const ReportBranding none = ReportBranding();

  bool get isEmpty =>
      name.trim().isEmpty && line.trim().isEmpty && logo == null;
}

/// Keeps the [ReportBranding] on the phone: the words in preferences, the
/// logo as a file in the app's own directory.
///
/// Not in the backup. A backup is a battery's history and the rider's
/// settings; a workshop's logo is neither, and would make every backup
/// carry an image.
class WorkshopBrandingStore {
  WorkshopBrandingStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directory;

  static const _nameKey = 'workshop_report_name';
  static const _lineKey = 'workshop_report_line';
  static const _logoFile = 'workshop_logo';

  /// Bigger than this and it is a photograph, not a logo: the sheet would
  /// weigh megabytes and the picture would be printed an inch tall anyway.
  static const int maxLogoBytes = 1024 * 1024;

  Future<File> _logo() async =>
      File(p.join((await _directory()).path, _logoFile));

  /// What is stored, or [ReportBranding.none]. Never throws: a sheet
  /// without a logo is better than no sheet.
  Future<ReportBranding> load() async {
    var name = '';
    var line = '';
    Uint8List? logo;
    try {
      final prefs = await SharedPreferences.getInstance();
      name = prefs.getString(_nameKey) ?? '';
      line = prefs.getString(_lineKey) ?? '';
    } on Object {
      // Defaults.
    }
    try {
      final f = await _logo();
      if (f.existsSync()) logo = await f.readAsBytes();
    } on Object {
      logo = null;
    }
    return ReportBranding(name: name, line: line, logo: logo);
  }

  Future<void> saveText({required String name, required String line}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name.trim());
    await prefs.setString(_lineKey, line.trim());
  }

  /// Keeps [bytes] as the logo. False, and nothing kept, when the file is
  /// not a PNG or a JPEG, or is too big to be one.
  Future<bool> saveLogo(Uint8List bytes) async {
    if (bytes.length > maxLogoBytes || !looksLikeImage(bytes)) return false;
    await (await _logo()).writeAsBytes(bytes, flush: true);
    return true;
  }

  Future<void> clearLogo() async {
    final f = await _logo();
    if (f.existsSync()) await f.delete();
  }

  /// PNG or JPEG by their first bytes, which is what the PDF library can
  /// embed. Anything else picked from the gallery (a HEIC, a WebP) is
  /// refused here rather than failing the sheet later.
  static bool looksLikeImage(Uint8List b) {
    const png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (b.length >= png.length) {
      var match = true;
      for (var i = 0; i < png.length; i++) {
        if (b[i] != png[i]) match = false;
      }
      if (match) return true;
    }
    return b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;
  }
}
