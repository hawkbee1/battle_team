import 'dart:async';

import 'package:battle_team/authentication/authentication.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

void main() {
  group(AuthenticationFormCubit, () {
    late MockAuthenticationRepository repository;
    late LogCapture log;

    setUp(() {
      repository = MockAuthenticationRepository();
      log = LogCapture();
    });

    tearDown(() => log.cancel());

    AuthenticationFormCubit build() =>
        AuthenticationFormCubit(repository: repository);

    void stubSignIn(Future<void> Function() answer) => when(
      () => repository.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => answer());

    void stubSignUp(Future<void> Function() answer) => when(
      () => repository.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
        name: any(named: 'name'),
      ),
    ).thenAnswer((_) => answer());

    test('M7.12 starts editing, with no failure', () {
      expect(build().state, const AuthenticationFormState());
    });

    blocTest<AuthenticationFormCubit, AuthenticationFormState>(
      'M7.12 a sign-in is sent, then accepted',
      setUp: () => stubSignIn(() async {}),
      build: build,
      act: (cubit) => cubit.signIn(email: 'a@x.local', password: 'secret-123'),
      expect: () => const [
        AuthenticationFormState(status: AuthenticationFormStatus.submitting),
        AuthenticationFormState(status: AuthenticationFormStatus.succeeded),
      ],
      verify: (_) => verify(
        () => repository.signIn(email: 'a@x.local', password: 'secret-123'),
      ).called(1),
    );

    blocTest<AuthenticationFormCubit, AuthenticationFormState>(
      'M7.12 a sign-in refused says why',
      setUp: () => stubSignIn(
        () async => throw const AuthenticationFailure(
          AuthenticationFailureReason.wrongCredentials,
        ),
      ),
      build: build,
      act: (cubit) => cubit.signIn(email: 'a@x.local', password: 'wrong'),
      expect: () => const [
        AuthenticationFormState(status: AuthenticationFormStatus.submitting),
        AuthenticationFormState(
          status: AuthenticationFormStatus.failed,
          failure: AuthenticationFailureReason.wrongCredentials,
        ),
      ],
    );

    blocTest<AuthenticationFormCubit, AuthenticationFormState>(
      'M7.12 a sign-up is sent, then accepted',
      setUp: () => stubSignUp(() async {}),
      build: build,
      act: (cubit) =>
          cubit.signUp(email: 'a@x.local', password: 'secret-123', name: 'Ada'),
      expect: () => const [
        AuthenticationFormState(status: AuthenticationFormStatus.submitting),
        AuthenticationFormState(status: AuthenticationFormStatus.succeeded),
      ],
      verify: (_) => verify(
        () => repository.signUp(
          email: 'a@x.local',
          password: 'secret-123',
          name: 'Ada',
        ),
      ).called(1),
    );

    blocTest<AuthenticationFormCubit, AuthenticationFormState>(
      'M7.12 an email already used says so',
      setUp: () => stubSignUp(
        () async => throw const AuthenticationFailure(
          AuthenticationFailureReason.accountExists,
        ),
      ),
      build: build,
      act: (cubit) =>
          cubit.signUp(email: 'a@x.local', password: 'secret-123', name: 'Ada'),
      expect: () => const [
        AuthenticationFormState(status: AuthenticationFormStatus.submitting),
        AuthenticationFormState(
          status: AuthenticationFormStatus.failed,
          failure: AuthenticationFailureReason.accountExists,
        ),
      ],
    );

    test('M7.12 a form being sent is not sent twice', () async {
      final answer = Completer<void>();
      stubSignIn(() => answer.future);
      final cubit = build();

      final first = cubit.signIn(email: 'a@x.local', password: 'secret-123');
      await cubit.signIn(email: 'a@x.local', password: 'secret-123');
      answer.complete();
      await first;

      verify(
        () => repository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).called(1);
    });

    test(
      'M7.12 no password, email or name is in the state or the logs',
      () async {
        stubSignUp(
          () async => throw const AuthenticationFailure(
            AuthenticationFailureReason.invalidInput,
          ),
        );
        final cubit = build();

        await cubit.signUp(
          email: 'private@x.local',
          password: 'secret-123',
          name: 'Private Name',
        );

        for (final text in [cubit.state.toString(), ...log.texts]) {
          expect(text, isNot(contains('secret-123')));
          expect(text, isNot(contains('private@x.local')));
          expect(text, isNot(contains('Private Name')));
        }
        expect(log.lines, ['INFO sign-up refused: invalidInput']);
      },
    );
  });
}
