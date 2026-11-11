import 'dart:async';

import 'package:battle_team/authentication/authentication.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

void main() {
  group(AuthenticationCubit, () {
    late MockAuthenticationRepository repository;
    late StreamController<AuthenticationStatus> statuses;

    setUp(() {
      repository = MockAuthenticationRepository();
      statuses = StreamController<AuthenticationStatus>.broadcast(sync: true);
      when(() => repository.currentStatus)
          .thenReturn(AuthenticationStatus.unknown);
      when(() => repository.accountId).thenReturn(null);
      when(() => repository.status).thenAnswer((_) => statuses.stream);
    });

    tearDown(() => statuses.close());

    AuthenticationCubit build() => AuthenticationCubit(repository: repository);

    test('M7.12 starts at the status the repository has', () {
      when(() => repository.currentStatus)
          .thenReturn(AuthenticationStatus.authenticated);
      when(() => repository.accountId).thenReturn('u-1');

      expect(
        build().state,
        const AuthenticationState(
          status: AuthenticationStatus.authenticated,
          accountId: 'u-1',
        ),
      );
    });

    blocTest<AuthenticationCubit, AuthenticationState>(
      'M7.12 follows the status: in, then out',
      build: build,
      act: (_) {
        when(() => repository.accountId).thenReturn('u-1');
        statuses.add(AuthenticationStatus.authenticated);
        when(() => repository.accountId).thenReturn(null);
        statuses.add(AuthenticationStatus.unauthenticated);
      },
      expect: () => const [
        AuthenticationState(
          status: AuthenticationStatus.authenticated,
          accountId: 'u-1',
        ),
        AuthenticationState(status: AuthenticationStatus.unauthenticated),
      ],
    );

    test('M7.12 looks for the session the last run left', () async {
      when(repository.restore).thenAnswer((_) async {});

      await build().start();

      verify(repository.restore).called(1);
    });

    group('logOut', () {
      test('M7.12 closes the session and reports nothing', () async {
        when(repository.signOut).thenAnswer((_) async {});
        final failures = <AuthenticationFailureReason>[];

        await build().logOut(onFailure: failures.add);

        verify(repository.signOut).called(1);
        expect(failures, isEmpty);
      });

      test('M7.12 says why it could not', () async {
        when(repository.signOut).thenThrow(
          const AuthenticationFailure(AuthenticationFailureReason.unreachable),
        );
        final failures = <AuthenticationFailureReason>[];

        await build().logOut(onFailure: failures.add);

        expect(failures, [AuthenticationFailureReason.unreachable]);
      });
    });

    test('M7.12 stops listening when closed', () async {
      final cubit = build();

      await cubit.close();
      statuses.add(AuthenticationStatus.authenticated);

      expect(statuses.hasListener, isFalse);
      expect(cubit.state.status, AuthenticationStatus.unknown);
    });

    test('M7.12 states with the same status and account are equal', () {
      expect(
        const AuthenticationState(
          status: AuthenticationStatus.authenticated,
          accountId: 'u-1',
        ),
        isNot(
          const AuthenticationState(status: AuthenticationStatus.authenticated),
        ),
      );
    });
  });
}
