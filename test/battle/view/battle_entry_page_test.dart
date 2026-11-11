import 'dart:async';

import 'package:battle_team/authentication/authentication.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

const BattleAssignment _assignment = (battleId: 'b-1', mapId: 'saint_lo');

void main() {
  setUpAll(() => registerFallbackValue(_assignment));

  group(BattleEntryPage, () {
    late MockBattleLocator locator;
    late MockBattleRepositoryFactory factory;
    late MockBattleRepository repository;
    late MockAuthenticationCubit authentication;

    setUp(() {
      locator = MockBattleLocator();
      factory = MockBattleRepositoryFactory();
      repository = MockBattleRepository();
      authentication = MockAuthenticationCubit();
      when(() => repository.mapId).thenReturn('saint_lo');
      when(repository.close).thenAnswer((_) async {});
      when(() => factory.create(any())).thenReturn(repository);
      when(() => authentication.state).thenReturn(
        const AuthenticationState(
          status: AuthenticationStatus.authenticated,
          accountId: 'a-1',
        ),
      );
      when(() => authentication.logOut(onFailure: any(named: 'onFailure')))
          .thenAnswer((_) async {});
    });

    Widget page() => MultiRepositoryProvider(
      providers: [
        RepositoryProvider<BattleLocator>.value(value: locator),
        RepositoryProvider<BattleRepositoryFactory>.value(value: factory),
      ],
      child: BattleEntryPage(
        accountId: 'a-1',
        pageBuilder: (context) =>
            Text('battle of ${context.read<BattleRepository>().mapId}'),
      ),
    );

    Future<void> pumpPage(WidgetTester tester, {Locale? locale}) => tester
        .pumpApp(page(), authenticationCubit: authentication, locale: locale);

    testWidgets('M7.12 looks for the battle of the account', (tester) async {
      final found = Completer<BattleAssignment?>();
      when(() => locator.locate('a-1')).thenAnswer((_) => found.future);

      await pumpPage(tester);

      expect(find.text('Looking for your battle…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      verify(() => locator.locate('a-1')).called(1);
      verifyNever(() => factory.create(any()));
    });

    testWidgets('M7.12 opens the battle found with a repository of its '
        'own, and closes it when the battle goes', (tester) async {
      when(() => locator.locate('a-1')).thenAnswer((_) async => _assignment);

      await pumpPage(tester);
      await tester.pump();

      expect(find.text('battle of saint_lo'), findsOneWidget);
      verify(() => factory.create(_assignment)).called(1);
      verifyNever(repository.close);

      await tester.pumpWidget(const SizedBox());

      verify(repository.close).called(1);
    });

    testWidgets('M7.12 says that the account has no battle, and looks again '
        'when asked', (tester) async {
      var calls = 0;
      when(() => locator.locate('a-1'))
          .thenAnswer((_) async => ++calls == 1 ? null : _assignment);

      await pumpPage(tester);
      await tester.pump();

      expect(
        find.text('This account has no section in a running battle yet.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Check again'));
      await tester.pump();
      await tester.pump();

      expect(find.text('battle of saint_lo'), findsOneWidget);
    });

    testWidgets('M7.12 says in words that the server did not answer', (
      tester,
    ) async {
      when(() => locator.locate('a-1'))
          .thenThrow(const BattleLookupFailure(unreachable: true));

      await pumpPage(tester);
      await tester.pump();

      expect(
        find.text(
          'Cannot reach the server. Check your connection and try '
          'again.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('BattleLookupFailure'), findsNothing);
    });

    testWidgets('M7.12 says in words that the search failed', (tester) async {
      when(() => locator.locate('a-1'))
          .thenThrow(const BattleLookupFailure(unreachable: false));

      await pumpPage(tester);
      await tester.pump();

      expect(
        find.text('Could not find your battle. Try again later.'),
        findsOneWidget,
      );
    });

    testWidgets('M7.12 speaks French', (tester) async {
      when(() => locator.locate('a-1')).thenAnswer((_) async => null);

      await pumpPage(tester, locale: const Locale('fr'));
      await tester.pump();

      expect(
        find.text(
          'Ce compte n’a pas encore de section dans une bataille en '
          'cours.',
        ),
        findsOneWidget,
      );
      expect(find.text('Vérifier à nouveau'), findsOneWidget);
      expect(find.text('Se déconnecter'), findsOneWidget);
    });

    testWidgets('M7.12 offers to log out while it waits, and when there is '
        'no battle', (tester) async {
      when(() => locator.locate('a-1')).thenAnswer((_) async => null);

      await pumpPage(tester);
      await tester.pump();
      await tester.tap(find.text('Log out'));

      verify(() => authentication.logOut(onFailure: any(named: 'onFailure')))
          .called(1);
    });
  });
}
