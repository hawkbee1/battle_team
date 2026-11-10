import 'package:logging/logging.dart';

/// The one line format of the app's logs, which the `watch-debug-session`
/// skill and `adb logcat | grep '\[bt\]'` read:
/// `[bt] <level> <logger> <message>`.
///
/// An error, then its stack, follow on lines with the same prefix, so a
/// grep on `[bt]` keeps them together. A message that spans lines is split
/// the same way: every line of the result starts with the prefix, and a
/// blank line (the stack of an error that has none) is dropped.
String formatLogRecord(LogRecord record) {
  final prefix = '[bt] ${record.level.name} ${record.loggerName}';
  final text = [
    record.message,
    if (record.error != null) 'error: ${record.error}',
    if (record.stackTrace != null) '${record.stackTrace}',
  ];
  return [
    for (final part in text)
      for (final line in part.trimRight().split('\n'))
        if (line.isNotEmpty) '$prefix $line',
  ].join('\n');
}
