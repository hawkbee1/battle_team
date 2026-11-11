import 'dart:async';

import 'package:appwrite_api_client/appwrite_api_client.dart';
import 'package:battle_team/authentication/authentication.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

const _account = AppwriteAccount(id: 'u-1', email: 'a@x.local', name: 'Ada');

void main() {
  group(AuthenticationGate, () {
    group('by status', () {
      late MockAuthenticationRepository repository;
      late StreamController<AuthenticationStatus> statuses;
      late AuthenticationCubit cubit;

      setUp(() {
        repository = MockAuthenticationRepository();
        statuses = StreamController<AuthenticationStatus>.broadcast(sync: true);
        when(() => repository.status).thenAnswer((_) => statuses.stream);
        when(() => repository.accountId).thenReturn(null);
        when(() => repository.currentStatus)
            .thenReturn(AuthenticationStatus.unknown);
      });

      tearDown(() async {
        await cubit.close();
        await statuses.close();
      });

      Future<void> pumpGate(WidgetTester tester) async {
        cubit = AuthenticationCubit(repository: repository);
        await tester.pumpApp(
          AuthenticationGate(
            signedIn: (context, accountId) => Text('signed in as $accountId'),
          ),
          authenticationRepository: repository,
          authenticationCubit: cubit,
        );
      }

      testWidgets('M7.12 waits while the session is looked for', (
        tester,
      ) async {
        await pumpGate(tester);

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(SignInPage), findsNothing);
        expect(find.textContaining('signed in as'), findsNothing);
      });

      testWidgets('M7.12 shows the sign-in page until an account is signed '
          'in', (tester) async {
        await pumpGate(tester);

        when(() => repository.accountId).thenReturn(null);
        statuses.add(AuthenticationStatus.unauthenticated);
        await tester.pump();

        expect(find.byType(SignInPage), findsOneWidget);
        expect(find.textContaining('signed in as'), findsNothing);
      });

      testWidgets('M7.12 the session of the last run opens the signed-in '
          'screen at once, with the account', (tester) async {
        when(() => repository.currentStatus)
            .thenReturn(AuthenticationStatus.authenticated);
        when(() => repository.accountId).thenReturn('u-1');

        await pumpGate(tester);

        expect(find.text('signed in as u-1'), findsOneWidget);
        expect(find.byType(SignInPage), findsNothing);
      });

      testWidgets('M7.12 goes in, and back to the sign-in page when the '
          'account is out', (tester) async {
        await pumpGate(tester);

        when(() => repository.accountId).thenReturn('u-1');
        statuses.add(AuthenticationStatus.authenticated);
        await tester.pump();
        expect(find.text('signed in as u-1'), findsOneWidget);

        when(() => repository.accountId).thenReturn(null);
        statuses.add(AuthenticationStatus.unauthenticated);
        await tester.pump();
        expect(find.byType(SignInPage), findsOneWidget);
        expect(find.textContaining('signed in as'), findsNothing);
      });

      testWidgets('M7.12 the sign-up page leaves when the account is in', (
        tester,
      ) async {
        await pumpGate(tester);
        statuses.add(AuthenticationStatus.unauthenticated);
        await tester.pump();
        await tester.tap(find.text('No account yet? Create one'));
        await tester.pumpAndSettle();
        expect(find.byType(SignUpPage), findsOneWidget);

        when(() => repository.accountId).thenReturn('u-2');
        statuses.add(AuthenticationStatus.authenticated);
        await tester.pumpAndSettle();

        expect(find.byType(SignUpPage), findsNothing);
        expect(find.text('signed in as u-2'), findsOneWidget);
        expect(
          tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
          isFalse,
        );
      });
    });

    group('with the real repository', () {
      late MockAppwriteApiClient apiClient;
      late AuthenticationCubit cubit;

      setUp(() {
        apiClient = MockAppwriteApiClient();
      });

      // The repository and the cubit are made inside the test, in its zone:
      // `pump` flushes the streams of what the test body made.
      Future<void> pumpGate(WidgetTester tester) {
        final repository = AuthenticationRepository(apiClient: apiClient);
        cubit = AuthenticationCubit(repository: repository);
        addTearDown(() async {
          await cubit.close();
          await repository.close();
        });
        return tester.pumpApp(
          AuthenticationGate(
            signedIn: (context, accountId) => Scaffold(
              body: Column(
                children: [Text('in as $accountId'), const LogOutButton()],
              ),
            ),
          ),
          authenticationRepository: repository,
          authenticationCubit: cubit,
        );
      }

      testWidgets('M7.12 a session kept across restarts opens the signed-in '
          'screen, and a log-out returns to the sign-in page', (tester) async {
        when(apiClient.currentAccount).thenAnswer((_) async => _account);
        when(apiClient.signOut).thenAnswer((_) async {});
        await pumpGate(tester);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        unawaited(cubit.start());
        await tester.pump();
        await tester.pump();

        expect(find.text('in as u-1'), findsOneWidget);
        expect(find.byType(SignInPage), findsNothing);

        await tester.tap(find.text('Log out'));
        await tester.pump();
        await tester.pump();

        verify(apiClient.signOut).called(1);
        expect(find.byType(SignInPage), findsOneWidget);
        expect(find.textContaining('in as'), findsNothing);
      });

      testWidgets('M7.12 no session at start shows the sign-in page, and a '
          'sign-in goes in', (tester) async {
        when(apiClient.currentAccount).thenAnswer((_) async => null);
        when(
          () => apiClient.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async {
          when(apiClient.currentAccount).thenAnswer((_) async => _account);
        });
        await pumpGate(tester);

        unawaited(cubit.start());
        await tester.pump();
        await tester.pump();
        expect(find.byType(SignInPage), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'),
          'a@x.local',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'),
          'secret-123',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(find.text('in as u-1'), findsOneWidget);
      });
    });
  });
}
