import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/app.dart';
import 'src/ble/connect_recovery.dart';

void main() {
  // First, so the connect log's process uptime measures the process.
  markProcessStart();
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(
      'assets/fonts/OFL-BarlowCondensed.txt',
    );
    yield LicenseEntryWithLineBreaks(['Barlow Condensed'], text);
  });
  runApp(const JkBmsApp());
}
