import 'dart:async';

import 'package:battle_team/authentication/authentication.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

const BattleAssignment _assignment = (battleId: 'b-1', mapId: 'saint_lo');
const AccountBattle _first = (warId: 'w-1', battle: _assignment);
const AccountBattle _second = (
  warId: 'w-2',
  battle: (battleId: 'b-2', mapId: 'valley'),
);
const AccountBattle _unnamedWar = (warId: null, battle: _assignment);

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

    void stubBattles(List<AccountBattle> battles) =>
        when(() => locator.locate('a-1')).thenAnswer((_) async => battles);

    // The battle screen of these tests: its map, and the Switch battle button
    // the real one has.
    Widget page() => MultiRepositoryProvider(
      providers: [
        RepositoryProvider<BattleLocator>.value(value: locator),
        RepositoryProvider<BattleRepositoryFactory>.value(value: factory),
      ],
      child: BattleEntryPage(
        accountId: 'a-1',
        pageBuilder: (context) => Column(
          children: [
            Text('battle on ${context.read<BattleRepository>().mapId}'),
            TextButton(
              onPressed: () =>
                  unawaited(context.read<BattleEntryCubit>().choose()),
              child: const Text('switch'),
            ),
          ],
        ),
      ),
    );

    Future<void> pumpPage(WidgetTester tester, {Locale? locale}) => tester
        .pumpApp(page(), authenticationCubit: authentication, locale: locale);

    testWidgets('M7.12 looks for the battles of the account', (tester) async {
      final found = Completer<List<AccountBattle>>();
      when(() => locator.locate('a-1')).thenAnswer((_) => found.future);

      await pumpPage(tester);

      expect(find.text('Looking for your battle…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      verify(() => locator.locate('a-1')).called(1);
      verifyNever(() => factory.create(any()));
    });

    testWidgets('M7.12 opens the only battle found with a repository of its '
        'own, and closes it when the battle goes', (tester) async {
      stubBattles(const [_first]);

      await pumpPage(tester);
      await tester.pump();

      expect(find.text('battle on saint_lo'), findsOneWidget);
      verify(() => factory.create(_assignment)).called(1);
      verifyNever(repository.close);

      await tester.pumpWidget(const SizedBox());

      verify(repository.close).called(1);
    });

    testWidgets('M7.12 lists the battles of several wars and enters the one '
        'picked', (tester) async {
      stubBattles(const [_first, _second]);

      await pumpPage(tester);
      await tester.pump();

      expect(find.text('Choose a battle'), findsOneWidget);
      expect(find.text('Battle on saint_lo'), findsOneWidget);
      expect(find.text('War w-1'), findsOneWidget);
      expect(find.text('Battle on valley'), findsOneWidget);
      expect(find.text('War w-2'), findsOneWidget);
      verifyNever(() => factory.create(any()));

      await tester.tap(find.text('Battle on valley'));
      await tester.pump();

      verify(() => factory.create((battleId: 'b-2', mapId: 'valley')))
          .called(1);
      expect(find.text('Choose a battle'), findsNothing);
    });

    testWidgets('M7.12 a battle whose war is not known is listed by its map '
        'alone', (tester) async {
      stubBattles(const [_unnamedWar, _second]);

      await pumpPage(tester);
      await tester.pump();

      expect(find.text('Battle on saint_lo'), findsOneWidget);
      expect(find.textContaining('War w-1'), findsNothing);
      expect(find.text('War w-2'), findsOneWidget);
    });

    testWidgets('M7.12 Switch battle leaves the battle for the list, even '
        'with one battle, and closes its repository', (tester) async {
      stubBattles(const [_first]);
      await pumpPage(tester);
      await tester.pump();
      expect(find.text('battle on saint_lo'), findsOneWidget);

      await tester.tap(find.text('switch'));
      await tester.pump();
      await tester.pump();

      expect(find.text('battle on saint_lo'), findsNothing);
      expect(find.text('Choose a battle'), findsOneWidget);
      expect(find.text('Battle on saint_lo'), findsOneWidget);
      verify(repository.close).called(1);
      verify(() => locator.locate('a-1')).called(2);
    });

    testWidgets('M7.12 Switch battle then another war enters it with a new '
        'repository', (tester) async {
      stubBattles(const [_first, _second]);
      final other = MockBattleRepository();
      when(() => other.mapId).thenReturn('valley');
      when(other.close).thenAnswer((_) async {});
      when(() => factory.create((battleId: 'b-2', mapId: 'valley')))
          .thenReturn(other);
      await pumpPage(tester);
      await tester.pump();
      await tester.tap(find.text('Battle on saint_lo'));
      await tester.pump();
      expect(find.text('battle on saint_lo'), findsOneWidget);

      await tester.tap(find.text('switch'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Battle on valley'));
      await tester.pump();

      expect(find.text('battle on valley'), findsOneWidget);
      verify(repository.close).called(1);
      verifyNever(other.close);
    });

    testWidgets('M7.12 checks the list again when asked', (tester) async {
      stubBattles(const [_first, _second]);
      await pumpPage(tester);
      await tester.pump();

      await tester.tap(find.text('Check again'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Choose a battle'), findsOneWidget);
      verify(() => locator.locate('a-1')).called(2);
    });

    testWidgets('M7.12 says that the account has no battle, and looks again '
        'when asked', (tester) async {
      var calls = 0;
      when(() => locator.locate('a-1'))
          .thenAnswer((_) async => ++calls == 1 ? const [] : const [_first]);

      await pumpPage(tester);
      await tester.pump();

      expect(
        find.text('This account has no section in a running battle yet.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Check again'));
      await tester.pump();
      await tester.pump();

      expect(find.text('battle on saint_lo'), findsOneWidget);
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
          'Cannot reach the server. Check your connection and try again.',
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
      stubBattles(const []);

      await pumpPage(tester, locale: const Locale('fr'));
      await tester.pump();

      expect(
        find.text(
          'Ce compte n’a pas encore de section dans une bataille en cours.',
        ),
        findsOneWidget,
      );
      expect(find.text('Vérifier à nouveau'), findsOneWidget);
      expect(find.text('Se déconnecter'), findsOneWidget);
    });

    testWidgets('M7.12 lists the battles in French', (tester) async {
      stubBattles(const [_first, _second]);

      await pumpPage(tester, locale: const Locale('fr'));
      await tester.pump();

      expect(find.text('Choisissez une bataille'), findsOneWidget);
      expect(find.text('Bataille sur saint_lo'), findsOneWidget);
      expect(find.text('Guerre w-1'), findsOneWidget);
    });

    testWidgets('M7.12 offers to log out while it waits, and when there is '
        'no battle', (tester) async {
      stubBattles(const []);

      await pumpPage(tester);
      await tester.pump();
      await tester.tap(find.text('Log out'));

      verify(() => authentication.logOut(onFailure: any(named: 'onFailure')))
          .called(1);
    });
  });
}
