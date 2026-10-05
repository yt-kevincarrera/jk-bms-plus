import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/ble/connect_recovery.dart';

void main() {
  // First, so the connect log's process uptime measures the process.
  markProcessStart();
  runApp(const JkBmsApp());
}
