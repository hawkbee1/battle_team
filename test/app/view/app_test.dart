import 'dart:async';

import 'package:appwrite_api_client/appwrite_api_client.dart';
import 'package:backend_status_repository/backend_status_repository.dart';
import 'package:battle_team/app/app.dart';
import 'package:battle_team/authentication/authentication.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

const _account = AppwriteAccount(id: 'u-1', email: 'a@x.local', name: 'Ada');

void main() {
  setUpAll(() => registerFallbackValue((battleId: '', mapId: '')));

  group(App, () {
    late MockAppwriteApiClient apiClient;
    late BackendStatusRepository backendStatusRepository;
    late MockBattleLocator battleLocator;

    setUp(() {
      apiClient = MockAppwriteApiClient();
      when(apiClient.currentAccount).thenAnswer((_) async => null);
      when(apiClient.signOut).thenAnswer((_) async {});
      backendStatusRepository = MockBackendStatusRepository();
      when(backendStatusRepository.checkConnection).thenAnswer((_) async {});
      battleLocator = MockBattleLocator();
      // No section in a running battle: the entry screen says so, and the
      // test needs no GPU.
      when(() => battleLocator.locate(any())).thenAnswer((_) async => null);
    });

    // The repository is made inside the test, in its zone: `pump` flushes the
    // streams of what the test body made.
    Widget app() {
      final authenticationRepository = AuthenticationRepository(
        apiClient: apiClient,
      );
      addTearDown(authenticationRepository.close);
      return App(
        authenticationRepository: authenticationRepository,
        backendStatusRepository: backendStatusRepository,
        battleLocator: battleLocator,
        battleRepositoryFactory: BattleRepositoryFactory(
          apiClient: apiClient,
          endpoint: 'http://127.0.0.1:9/v1',
          projectId: 'hawkbee',
        ),
      );
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
    }

    testWidgets('M7.12 waits for the session, then shows the sign-in page '
        'when there is none', (tester) async {
      final session = Completer<AppwriteAccount?>();
      when(apiClient.currentAccount).thenAnswer((_) => session.future);

      await tester.pumpWidget(app());
      expect(find.byType(AppView), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(SignInPage), findsNothing);

      session.complete(null);
      await settle(tester);

      expect(find.byType(SignInPage), findsOneWidget);
      expect(find.text('Connected to Appwrite'), findsOneWidget);
      verifyNever(() => battleLocator.locate(any()));
    });

    testWidgets('M7.12 the session of the last run opens the battle of the '
        'account, with no sign-in page', (tester) async {
      when(apiClient.currentAccount).thenAnswer((_) async => _account);

      await tester.pumpWidget(app());
      await settle(tester);

      expect(find.byType(SignInPage), findsNothing);
      verify(() => battleLocator.locate('u-1')).called(1);
      expect(
        find.text('This account has no section in a running battle yet.'),
        findsOneWidget,
      );
    });

    testWidgets('M7.12 a log-out returns to the sign-in page, and a new '
        'sign-in finds the battle again', (tester) async {
      when(apiClient.currentAccount).thenAnswer((_) async => _account);
      await tester.pumpWidget(app());
      await settle(tester);

      await tester.tap(find.text('Log out'));
      when(apiClient.currentAccount).thenAnswer((_) async => null);
      await settle(tester);

      verify(apiClient.signOut).called(1);
      expect(find.byType(SignInPage), findsOneWidget);

      when(
        () => apiClient.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {
        when(apiClient.currentAccount).thenAnswer((_) async => _account);
      });
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'a@x.local',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'secret-123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await settle(tester);

      expect(find.byType(SignInPage), findsNothing);
      verify(() => battleLocator.locate('u-1')).called(2);
    });

    testWidgets('M7.12 speaks French with the Material localizations of '
        'material_ui', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('fr')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(app());
      await settle(tester);

      expect(find.text('Se connecter'), findsWidgets);
      expect(find.text('Connecté à Appwrite'), findsOneWidget);
      // The Material widgets draw with material_ui's own localizations.
      final material = MaterialLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      );
      expect(material.backButtonTooltip, 'Retour');
    });

    testWidgets('M7.12 builds its repositories over the Appwrite client', (
      tester,
    ) async {
      when(apiClient.ping).thenAnswer((_) async {});

      await tester.pumpWidget(App.fromApiClient(apiClient));
      await settle(tester);

      // No session: the sign-in page, which checks the backend.
      expect(find.byType(SignInPage), findsOneWidget);
      verify(apiClient.ping).called(1);
      verify(apiClient.currentAccount).called(1);
    });

    testWidgets('M7.12 the playtest flavor signs in the account of its env '
        'file and plays the battle it names, with no sign-in page', (
      tester,
    ) async {
      when(apiClient.ping).thenAnswer((_) async {});
      when(
        () => apiClient.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {
        when(apiClient.currentAccount).thenAnswer((_) async => _account);
      });

      await tester.pumpWidget(
        App.playtest(
          apiClient,
          const PlaytestSettings(
            email: 'blue@battleteam.local',
            password: 'pw',
            battleId: 'pt-1',
          ),
        ),
      );
      await settle(tester);

      verify(
        () => apiClient.signIn(email: 'blue@battleteam.local', password: 'pw'),
      ).called(1);
      expect(find.byType(SignInPage), findsNothing);
      // Whoever signed in plays the battle the tool set up: the battle page.
      expect(find.byType(BattlePage), findsOneWidget);
    });

    testWidgets('M7.12 the playtest account refused: the sign-in page '
        'shows', (tester) async {
      when(apiClient.ping).thenAnswer((_) async {});
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

      await tester.pumpWidget(
        App.playtest(
          apiClient,
          const PlaytestSettings(
            email: 'blue@battleteam.local',
            password: 'old',
            battleId: 'pt-1',
          ),
        ),
      );
      await settle(tester);

      expect(find.byType(SignInPage), findsOneWidget);
    });
  });
}
