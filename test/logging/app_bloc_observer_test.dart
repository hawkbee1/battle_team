import 'package:battle_team/logging/logging.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

import '../helpers/helpers.dart';

class _CounterCubit extends Cubit<int> {
  new() : super(0);

  void fail() => addError(StateError('broken'), StackTrace.current);
}

void main() {
  group(AppBlocObserver, () {
    late LogCapture log;
    late BlocObserver previous;

    setUp(() {
      log = LogCapture();
      previous = Bloc.observer;
      Bloc.observer = AppBlocObserver();
    });

    tearDown(() async {
      Bloc.observer = previous;
      await log.cancel();
    });

    test('M7.3 logs the error of a bloc as SEVERE with its stack', () async {
      final cubit = _CounterCubit()..fail();
      addTearDown(cubit.close);

      final failed = log.records.single;
      expect(failed.level, Level.SEVERE);
      expect(failed.loggerName, 'battle_team.AppBlocObserver');
      expect(failed.message, '_CounterCubit failed');
      expect(failed.error, isA<StateError>());
      expect(failed.stackTrace, isNotNull);
    });

    test('decision 237 logs no change of state', () async {
      final cubit = _CounterCubit();
      addTearDown(cubit.close);

      cubit.emit(1);

      expect(log.records, isEmpty);
    });
  });

  group('logFlutterError', () {
    late LogCapture log;

    setUp(() => log = LogCapture());

    tearDown(() => log.cancel());

    test('M7.3 logs a framework error as SEVERE', () {
      logFlutterError(
        FlutterErrorDetails(
          exception: StateError('layout'),
          stack: StackTrace.current,
        ),
      );

      final failed = log.records.single;
      expect(failed.level, Level.SEVERE);
      expect(failed.loggerName, 'battle_team.FlutterError');
      expect(failed.error, isA<StateError>());
      expect(failed.stackTrace, isNotNull);
    });
  });
}
