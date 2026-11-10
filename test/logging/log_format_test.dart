import 'package:battle_team/logging/logging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

void main() {
  group('formatLogRecord', () {
    test('M7.3 puts level, logger and message on one line', () {
      final line = formatLogRecord(
        LogRecord(Level.INFO, 'socket open', 'battle_client.BattleClient'),
      );

      expect(line, '[bt] INFO battle_client.BattleClient socket open');
    });

    test('M7.3 follows an error and its stack on prefixed lines', () {
      final line = formatLogRecord(
        LogRecord(
          Level.SEVERE,
          'connecting failed',
          'battle_client.BattleClient',
          StateError('refused'),
          StackTrace.fromString('#0 main (a.dart:1:1)\n#1 run (b.dart:2:2)\n'),
        ),
      );

      expect(
        line.split('\n'),
        equals([
          '[bt] SEVERE battle_client.BattleClient connecting failed',
          '[bt] SEVERE battle_client.BattleClient error: Bad state: refused',
          '[bt] SEVERE battle_client.BattleClient #0 main (a.dart:1:1)',
          '[bt] SEVERE battle_client.BattleClient #1 run (b.dart:2:2)',
        ]),
      );
    });

    test('M7.3 leaves out the stack an error does not have', () {
      final line = formatLogRecord(
        LogRecord(
          Level.SEVERE,
          'socket failed',
          'x',
          StateError('reset'),
          StackTrace.empty,
        ),
      );

      expect(
        line.split('\n'),
        equals([
          '[bt] SEVERE x socket failed',
          '[bt] SEVERE x error: Bad state: reset',
        ]),
      );
    });

    test('M7.3 prefixes every line of a message that spans lines', () {
      final line = formatLogRecord(LogRecord(Level.WARNING, 'a\nb', 'x'));

      expect(
        line.split('\n'),
        equals(['[bt] WARNING x a', '[bt] WARNING x b']),
      );
    });
  });
}
