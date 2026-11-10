import 'dart:async';

import 'package:logging/logging.dart';

/// Captures the log records of a test: create it in `setUp`, [cancel] it in
/// `tearDown`, or records leak from one test to the next.
final class LogCapture {
  /// Starts capturing every record, whatever its level.
  new() : _level = Logger.root.level {
    Logger.root.level = Level.ALL;
    _subscription = Logger.root.onRecord.listen(records.add);
  }

  final Level _level;
  late final StreamSubscription<LogRecord> _subscription;

  /// The records so far.
  final records = <LogRecord>[];

  /// Each record as `LEVEL message`.
  List<String> get lines => [
    for (final record in records) '${record.level.name} ${record.message}',
  ];

  /// All the text of every record: logger, message, error and stack.
  List<String> get texts => [
    for (final record in records)
      [
        record.loggerName,
        record.message,
        record.error,
        record.stackTrace,
      ].join(' '),
  ];

  /// Stops capturing and restores the root level.
  Future<void> cancel() async {
    await _subscription.cancel();
    Logger.root.level = _level;
  }
}
