import 'package:appwrite_api_client/appwrite_api_client.dart';
import 'package:battle_team/authentication/authentication.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

const _account = AppwriteAccount(id: 'u-1', email: 'a@x.local', name: 'Ada');

void main() {
  group(AuthenticationRepository, () {
    late MockAppwriteApiClient apiClient;
    late AuthenticationRepository repository;
    late LogCapture log;

    setUp(() {
      apiClient = MockAppwriteApiClient();
      repository = AuthenticationRepository(apiClient: apiClient);
      log = LogCapture();
    });

    tearDown(() async {
      await log.cancel();
      await repository.close();
    });

    void stubSignIn() => when(
      () => apiClient.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});

    void stubSignUp() => when(
      () => apiClient.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
        name: any(named: 'name'),
      ),
    ).thenAnswer((_) async {});

    test('M7.12 starts unknown, with no account', () {
      expect(repository.currentStatus, AuthenticationStatus.unknown);
      expect(repository.accountId, isNull);
    });

    group('restore', () {
      test('M7.12 finds the session the last run left', () async {
        when(apiClient.currentAccount).thenAnswer((_) async => _account);
        final statuses = expectLater(
          repository.status,
          emits(AuthenticationStatus.authenticated),
        );

        await repository.restore();

        await statuses;
        expect(repository.currentStatus, AuthenticationStatus.authenticated);
        expect(repository.accountId, 'u-1');
        verifyNever(
          () => apiClient.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );
      });

      test('M7.12 finds no session: unauthenticated', () async {
        when(apiClient.currentAccount).thenAnswer((_) async => null);
        final statuses = expectLater(
          repository.status,
          emits(AuthenticationStatus.unauthenticated),
        );

        await repository.restore();

        await statuses;
        expect(repository.currentStatus, AuthenticationStatus.unauthenticated);
        expect(repository.accountId, isNull);
      });

      test('M7.12 Appwrite unreachable at start: unauthenticated, '
          'and a warning with the reason', () async {
        when(apiClient.currentAccount).thenThrow(
          const AppwriteAccountFailure(
            'no route',
            kind: AppwriteFailureKind.unreachable,
          ),
        );

        await repository.restore();

        expect(repository.currentStatus, AuthenticationStatus.unauthenticated);
        expect(log.lines, contains('WARNING no session: unreachable'));
      });

      test('M7.12 the playtest signs in its account instead of looking for '
          'a session', () async {
        final playtest = AuthenticationRepository(
          apiClient: apiClient,
          signInAtStart: (email: 'blue@battleteam.local', password: 'pw'),
        );
        addTearDown(playtest.close);
        stubSignIn();
        when(apiClient.currentAccount).thenAnswer((_) async => _account);

        await playtest.restore();

        verify(
          () =>
              apiClient.signIn(email: 'blue@battleteam.local', password: 'pw'),
        ).called(1);
        expect(playtest.currentStatus, AuthenticationStatus.authenticated);
      });

      test(
        'M7.12 the playtest account refused: the sign-in page shows',
        () async {
          final playtest = AuthenticationRepository(
            apiClient: apiClient,
            signInAtStart: (email: 'blue@battleteam.local', password: 'pw'),
          );
          addTearDown(playtest.close);
          when(
            () => apiClient.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ),
          ).thenThrow(
            const AppwriteSignInFailure(
              'wrong',
              kind: AppwriteFailureKind.unauthorized,
            ),
          );

          await playtest.restore();

          expect(playtest.currentStatus, AuthenticationStatus.unauthenticated);
          expect(log.lines, contains('WARNING no session: wrongCredentials'));
        },
      );
    });

    group('signIn', () {
      test('M7.12 signs in and reads the account', () async {
        stubSignIn();
        when(apiClient.currentAccount).thenAnswer((_) async => _account);

        await repository.signIn(email: 'a@x.local', password: 'secret-123');

        verify(
          () => apiClient.signIn(email: 'a@x.local', password: 'secret-123'),
        ).called(1);
        expect(repository.currentStatus, AuthenticationStatus.authenticated);
        expect(repository.accountId, 'u-1');
      });

      test(
        'M7.12 a session that is not there after all: unauthenticated',
        () async {
          stubSignIn();
          when(apiClient.currentAccount).thenAnswer((_) async => null);

          await repository.signIn(email: 'a@x.local', password: 'secret-123');

          expect(
            repository.currentStatus,
            AuthenticationStatus.unauthenticated,
          );
        },
      );

      test('M7.12 tells a change of status once, not each time', () async {
        stubSignIn();
        when(apiClient.currentAccount).thenAnswer((_) async => _account);
        final statuses = <AuthenticationStatus>[];
        final subscription = repository.status.listen(statuses.add);
        addTearDown(subscription.cancel);

        await repository.signIn(email: 'a@x.local', password: 'secret-123');
        await repository.signIn(email: 'a@x.local', password: 'secret-123');
        await pumpEventQueue();

        expect(statuses, [AuthenticationStatus.authenticated]);
      });

      for (final (kind, reason) in [
        (
          AppwriteFailureKind.unauthorized,
          AuthenticationFailureReason.wrongCredentials,
        ),
        (
          AppwriteFailureKind.tooManyRequests,
          AuthenticationFailureReason.tooManyRequests,
        ),
        (
          AppwriteFailureKind.unreachable,
          AuthenticationFailureReason.unreachable,
        ),
        (AppwriteFailureKind.serverError, AuthenticationFailureReason.other),
        (AppwriteFailureKind.other, AuthenticationFailureReason.other),
      ]) {
        test('M7.12 a ${kind.name} failure of the sign-in is $reason, and '
            'nobody is signed in', () async {
          when(
            () => apiClient.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ),
          ).thenThrow(AppwriteSignInFailure('failed', kind: kind));

          await expectLater(
            repository.signIn(email: 'a@x.local', password: 'wrong'),
            throwsA(
              isA<AuthenticationFailure>().having(
                (failure) => failure.reason,
                'reason',
                reason,
              ),
            ),
          );
          expect(repository.currentStatus, AuthenticationStatus.unknown);
        });
      }
    });

    group('signUp', () {
      test('M7.12 creates the account and reads it', () async {
        stubSignUp();
        when(apiClient.currentAccount).thenAnswer((_) async => _account);

        await repository.signUp(
          email: 'a@x.local',
          password: 'secret-123',
          name: 'Ada',
        );

        verify(
          () => apiClient.signUp(
            email: 'a@x.local',
            password: 'secret-123',
            name: 'Ada',
          ),
        ).called(1);
        expect(repository.currentStatus, AuthenticationStatus.authenticated);
        expect(repository.accountId, 'u-1');
      });

      for (final (kind, reason) in [
        (
          AppwriteFailureKind.conflict,
          AuthenticationFailureReason.accountExists,
        ),
        (
          AppwriteFailureKind.invalidInput,
          AuthenticationFailureReason.invalidInput,
        ),
        // A 401 is not "wrong password" when creating an account.
        (AppwriteFailureKind.unauthorized, AuthenticationFailureReason.other),
        (
          AppwriteFailureKind.unreachable,
          AuthenticationFailureReason.unreachable,
        ),
      ]) {
        test(
          'M7.12 a ${kind.name} failure of the sign-up is $reason',
          () async {
            when(
              () => apiClient.signUp(
                email: any(named: 'email'),
                password: any(named: 'password'),
                name: any(named: 'name'),
              ),
            ).thenThrow(AppwriteAccountFailure('failed', kind: kind));

            await expectLater(
              repository.signUp(
                email: 'a@x.local',
                password: 'secret-123',
                name: 'Ada',
              ),
              throwsA(
                isA<AuthenticationFailure>().having(
                  (failure) => failure.reason,
                  'reason',
                  reason,
                ),
              ),
            );
          },
        );
      }

      test("M7.12 an error that is not Appwrite's is other", () async {
        when(
          () => apiClient.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            name: any(named: 'name'),
          ),
        ).thenThrow(StateError('boom'));

        await expectLater(
          repository.signUp(
            email: 'a@x.local',
            password: 'secret-123',
            name: 'Ada',
          ),
          throwsA(
            isA<AuthenticationFailure>().having(
              (failure) => failure.reason,
              'reason',
              AuthenticationFailureReason.other,
            ),
          ),
        );
      });
    });

    group('signOut', () {
      setUp(() async {
        when(apiClient.currentAccount).thenAnswer((_) async => _account);
        await repository.restore();
      });

      test('M7.12 closes the session: unauthenticated', () async {
        when(apiClient.signOut).thenAnswer((_) async {});
        final statuses = expectLater(
          repository.status,
          emits(AuthenticationStatus.unauthenticated),
        );

        await repository.signOut();

        await statuses;
        expect(repository.currentStatus, AuthenticationStatus.unauthenticated);
        expect(repository.accountId, isNull);
      });

      test('M7.12 when it cannot, the account stays signed in', () async {
        when(apiClient.signOut).thenThrow(
          const AppwriteAccountFailure(
            'no route',
            kind: AppwriteFailureKind.unreachable,
          ),
        );

        await expectLater(
          repository.signOut,
          throwsA(
            isA<AuthenticationFailure>().having(
              (failure) => failure.reason,
              'reason',
              AuthenticationFailureReason.unreachable,
            ),
          ),
        );
        expect(repository.currentStatus, AuthenticationStatus.authenticated);
        expect(repository.accountId, 'u-1');
      });
    });

    test('M7.12 logs the steps and no email, password or name', () async {
      stubSignUp();
      when(apiClient.currentAccount).thenAnswer((_) async => _account);
      await repository.signUp(
        email: 'private@x.local',
        password: 'secret-123',
        name: 'Private Name',
      );
      when(
        () => apiClient.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const AppwriteSignInFailure('failed'));
      await expectLater(
        repository.signIn(email: 'private@x.local', password: 'secret-123'),
        throwsA(isA<AuthenticationFailure>()),
      );

      expect(
        log.lines,
        containsAll([
          'INFO sign-up: started',
          'INFO sign-up: done',
          'WARNING sign-in: failed, other',
        ]),
      );
      expect(log.records.map((record) => record.loggerName).toSet(), {
        'battle_team.AuthenticationRepository',
      });
      for (final text in log.texts) {
        expect(text, isNot(contains('private@x.local')));
        expect(text, isNot(contains('secret-123')));
        expect(text, isNot(contains('Private Name')));
      }
    });

    test('M7.12 stops telling the status when closed', () async {
      final done = expectLater(repository.status, emitsDone);

      await repository.close();

      await done;
    });
  });

  group(AuthenticationFailure, () {
    test('M7.12 describes its reason, not an error text', () {
      expect(
        const AuthenticationFailure(
          AuthenticationFailureReason.wrongCredentials,
        ).toString(),
        'AuthenticationFailure: wrongCredentials',
      );
    });
  });
}
