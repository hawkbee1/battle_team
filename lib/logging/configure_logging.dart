import 'dart:async';

import 'package:battle_team/logging/log_format.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Sets up the app's logs, once (Observer on `package:logging`'s root
/// logger): every package logs on its own `Logger`; this is the only place
/// that sets the level and prints.
///
/// In debug and profile everything is printed to the console, in
/// `formatLogRecord`'s format, with [printLine] (`debugPrint`, so it
/// reaches logcat under the `flutter` tag and the browser console). In
/// [release] nothing is: the level is off and nothing listens.
///
/// Returns the listener, to cancel it in tests; null in [release].
StreamSubscription<LogRecord>? configureLogging({
  required bool release,
  void Function(String line)? printLine,
}) {
  if (release) {
    Logger.root.level = Level.OFF;
    return null;
  }
  Logger.root.level = Level.ALL;
  final print = printLine ?? debugPrint;
  return Logger.root.onRecord.listen(
    (record) => print(formatLogRecord(record)),
  );
}
