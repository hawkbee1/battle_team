import 'dart:async';

import 'package:battle_team/logging/logging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

void main() {
  group('configureLogging', () {
    late Level previousLevel;
    late List<String> printed;
    StreamSubscription<LogRecord>? subscription;

    setUp(() {
      previousLevel = Logger.root.level;
      printed = [];
    });

    tearDown(() async {
      await subscription?.cancel();
      Logger.root.level = previousLevel;
    });

    test('M7.3 prints every record in debug, formatted', () {
      subscription = configureLogging(release: false, printLine: printed.add);

      Logger('battle_team.Test').fine('a detail');
      Logger('battle_team.Test').severe('broken');

      expect(
        printed,
        equals([
          '[bt] FINE battle_team.Test a detail',
          '[bt] SEVERE battle_team.Test broken',
        ]),
      );
    });

    test('M7.3 prints with debugPrint unless told otherwise', () {
      final output = <String?>[];
      final previous = debugPrint;
      void capture(String? message, {int? wrapWidth}) => output.add(message);
      debugPrint = capture;
      addTearDown(() => debugPrint = previous);
      subscription = configureLogging(release: false);

      Logger('battle_team.Test').info('hello');

      expect(output, equals(['[bt] INFO battle_team.Test hello']));
    });

    test('M7.3 emits nothing in release', () {
      subscription = configureLogging(release: true, printLine: printed.add);

      Logger('battle_team.Test').severe('broken');

      expect(subscription, isNull);
      expect(Logger.root.level, Level.OFF);
      expect(printed, isEmpty);
    });
  });
}
