import 'dart:async';

import 'package:battle_team/authentication/authentication.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

const BattleAssignment _assignment = (battleId: 'b-1', mapId: 'saint_lo');
const BattleAssignment _valley = (battleId: 'b-2', mapId: 'valley');

/// A battle the account is in, one it can join and one more it is in.
const AccountBattle _mine = (warId: 'w-1', battle: _assignment, joined: true);
const AccountBattle _other = (warId: 'w-2', battle: _valley, joined: false);
const AccountBattle _third = (
  warId: 'w-3',
  battle: (battleId: 'b-3', mapId: 'ridge'),
  joined: true,
);
const AccountBattle _unnamedWar = (
  warId: null,
  battle: _assignment,
  joined: true,
);

void main() {
  setUpAll(() => registerFallbackValue(_assignment));

  group(BattleEntryPage, () {
    late MockBattleLocator locator;
    late MockBattleRepositoryFactory factory;
    late MockBattleRepository repository;
    late MockAuthenticationCubit authentication;
    // The maps the app has, as its assets list them.
    late Future<Set<String>> Function(AssetBundle bundle) loadMapIds;

    setUp(() {
      loadMapIds = (_) async => {'saint_lo', 'valley', 'ridge'};
      locator = MockBattleLocator();
      factory = MockBattleRepositoryFactory();
      repository = MockBattleRepository();
      authentication = MockAuthenticationCubit();
      when(() => repository.mapId).thenReturn('saint_lo');
      when(repository.close).thenAnswer((_) async {});
      when(() => factory.create(any())).thenReturn(repository);
      when(() => locator.join(any())).thenAnswer((_) async {});
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
        loadMapIds: loadMapIds,
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

    // One frame for the list of maps, then the page looks for the battles.
    Future<void> pumpPage(WidgetTester tester, {Locale? locale}) async {
      await tester.pumpApp(
        page(),
        authenticationCubit: authentication,
        locale: locale,
      );
      await tester.pump();
    }

    Finder inDialog(String text) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text(text),
    );

    testWidgets('M7.12 looks for the running battles', (tester) async {
      final found = Completer<List<AccountBattle>>();
      when(() => locator.locate('a-1')).thenAnswer((_) => found.future);

      await pumpPage(tester);

      expect(find.text('Looking for your battle…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      verify(() => locator.locate('a-1')).called(1);
      verifyNever(() => factory.create(any()));
    });

    testWidgets('M7.12 waits for the list of the maps of the app before it '
        'looks for the battles', (tester) async {
      final maps = Completer<Set<String>>();
      loadMapIds = (_) => maps.future;
      stubBattles(const [_mine]);

      await tester.pumpApp(page(), authenticationCubit: authentication);
      await tester.pump();

      expect(find.text('Looking for your battle…'), findsOneWidget);
      verifyNever(() => locator.locate(any()));

      maps.complete({'saint_lo'});
      await tester.pump();
      await tester.pump();

      expect(find.text('battle on saint_lo'), findsOneWidget);
    });

    testWidgets('M7.12 a battle on a map the app does not have is listed, '
        'but cannot be entered or joined', (tester) async {
      loadMapIds = (_) async => {'saint_lo'};
      stubBattles(const [_mine, _third, _other]);
      await pumpPage(tester);
      await tester.pump();

      // The battle of a map it has stays as before; the two others say why
      // they cannot be entered, and offer no Join.
      expect(find.text('You are in'), findsOneWidget);
      expect(find.text('Map not available in this app'), findsNWidgets(2));
      expect(find.widgetWithText(FilledButton, 'Join'), findsNothing);

      await tester.tap(find.text('Battle on valley'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Battle on ridge'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => locator.join(any()));
      verifyNever(() => factory.create(any()));
    });

    testWidgets('M7.12 the only battle the account is in is not entered at '
        'once when the app lacks its map: the list shows it', (tester) async {
      loadMapIds = (_) async => {'valley'};
      stubBattles(const [_mine]);

      await pumpPage(tester);
      await tester.pump();

      expect(find.text('Choose a battle'), findsOneWidget);
      expect(find.text('Map not available in this app'), findsOneWidget);
      verifyNever(() => factory.create(any()));
    });

    testWidgets('M7.12 without the list of maps no battle is refused: the page '
        'of the battle says if a map is missing', (tester) async {
      loadMapIds = (_) async => throw StateError('no manifest');
      stubBattles(const [_other]);

      await pumpPage(tester);
      await tester.pump();

      expect(find.widgetWithText(FilledButton, 'Join'), findsOneWidget);
      expect(find.text('Map not available in this app'), findsNothing);
    });

    testWidgets('M7.12 a battle on a map the app does not have says so in '
        'French', (tester) async {
      loadMapIds = (_) async => {'saint_lo'};
      stubBattles(const [_mine, _third, _other]);

      await pumpPage(tester, locale: const Locale('fr'));
      await tester.pump();

      expect(find.text('Carte absente de cette application'), findsNWidgets(2));
    });

    testWidgets('M7.12 opens the only battle the account is in with a '
        'repository of its own, and closes it when the battle goes', (
      tester,
    ) async {
      stubBattles(const [_mine]);

      await pumpPage(tester);
      await tester.pump();

      expect(find.text('battle on saint_lo'), findsOneWidget);
      verify(() => factory.create(_assignment)).called(1);
      verifyNever(repository.close);

      await tester.pumpWidget(const SizedBox());

      verify(repository.close).called(1);
    });

    testWidgets('SOC-30 lists every running battle, marks the ones the '
        'account is in and offers to join the others', (tester) async {
      stubBattles(const [_mine, _third, _other]);

      await pumpPage(tester);
      await tester.pump();

      expect(find.text('Choose a battle'), findsOneWidget);
      expect(find.text('Battle on saint_lo'), findsOneWidget);
      expect(find.text('War w-1'), findsOneWidget);
      expect(find.text('Battle on ridge'), findsOneWidget);
      expect(find.text('Battle on valley'), findsOneWidget);
      expect(find.text('War w-2'), findsOneWidget);
      expect(find.text('You are in'), findsNWidgets(2));
      expect(find.widgetWithText(FilledButton, 'Join'), findsOneWidget);
      verifyNever(() => factory.create(any()));
    });

    testWidgets('M7.12 a battle the account is in is entered at once, with '
        'nothing joined', (tester) async {
      stubBattles(const [_mine, _third]);
      await pumpPage(tester);
      await tester.pump();

      await tester.tap(find.text('Battle on ridge'));
      await tester.pump();

      verify(() => factory.create((battleId: 'b-3', mapId: 'ridge'))).called(1);
      verifyNever(() => locator.join(any()));
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('SOC-30 a battle the account is not in is joined after the '
        'player confirms: its war gets the account a section, then the '
        'battle is entered', (tester) async {
      stubBattles(const [_mine, _third, _other]);
      final joined = Completer<void>();
      when(() => locator.join('w-2')).thenAnswer((_) => joined.future);
      await pumpPage(tester);
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Join'));
      await tester.pumpAndSettle();

      // Asked first, since a player stays in his team for the whole battle.
      expect(find.text('Join this war?'), findsOneWidget);
      expect(
        find.text(
          'A new section is created for you in the war w-2, and you enter '
          'its battle. You stay in its team for the whole battle.',
        ),
        findsOneWidget,
      );
      verifyNever(() => locator.join(any()));

      await tester.tap(inDialog('Join'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Joining the war…'), findsOneWidget);
      verify(() => locator.join('w-2')).called(1);
      verifyNever(() => factory.create(any()));

      joined.complete();
      await tester.pump();
      await tester.pump();

      verify(() => factory.create(_valley)).called(1);
      expect(find.text('battle on saint_lo'), findsOneWidget);
    });

    testWidgets('SOC-30 the whole row of a battle to join asks too', (
      tester,
    ) async {
      stubBattles(const [_other]);
      await pumpPage(tester);
      await tester.pump();

      await tester.tap(find.text('Battle on valley'));
      await tester.pumpAndSettle();

      expect(find.text('Join this war?'), findsOneWidget);
    });

    testWidgets('SOC-30 a player who cancels joins nothing', (tester) async {
      stubBattles(const [_other]);
      await pumpPage(tester);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Join'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Choose a battle'), findsOneWidget);
      verifyNever(() => locator.join(any()));
    });

    for (final (reason, text) in [
      (BattleJoinFailureReason.warOver, 'This war is over.'),
      (
        BattleJoinFailureReason.unreachable,
        'Cannot reach the server. Check your connection and try again.',
      ),
      (
        BattleJoinFailureReason.other,
        'Could not join this war. Try again later.',
      ),
    ]) {
      testWidgets('SOC-30 a war that cannot be joined ($reason) goes back to '
          'the list and says why in words', (tester) async {
        stubBattles(const [_other]);
        when(() => locator.join('w-2')).thenThrow(BattleJoinFailure(reason));
        await pumpPage(tester);
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Join'));
        await tester.pumpAndSettle();

        await tester.tap(inDialog('Join'));
        await tester.pumpAndSettle();

        expect(find.text('Choose a battle'), findsOneWidget);
        expect(find.text(text), findsOneWidget);
        expect(find.textContaining('BattleJoinFailure'), findsNothing);
        verifyNever(() => factory.create(any()));
      });
    }

    testWidgets('M7.12 a battle whose war is not known is listed by its '
        'map alone', (tester) async {
      stubBattles(const [_unnamedWar, _third, _other]);

      await pumpPage(tester);
      await tester.pump();

      expect(find.text('Battle on saint_lo'), findsOneWidget);
      expect(find.textContaining('War w-1'), findsNothing);
      expect(find.text('War w-2'), findsOneWidget);
    });

    testWidgets('M7.12 Switch battle leaves the battle for the list, even '
        'with one battle, and closes its repository', (tester) async {
      stubBattles(const [_mine]);
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

    testWidgets('SOC-30 Switch battle then a war the account is not in joins '
        'it and enters it with a new repository', (tester) async {
      stubBattles(const [_mine, _other]);
      final next = MockBattleRepository();
      when(() => next.mapId).thenReturn('valley');
      when(next.close).thenAnswer((_) async {});
      when(() => factory.create(_valley)).thenReturn(next);
      await pumpPage(tester);
      await tester.pump();
      // The account is in one battle: entered at once.
      expect(find.text('battle on saint_lo'), findsOneWidget);

      await tester.tap(find.text('switch'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Join'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Join'));
      await tester.pumpAndSettle();

      verify(() => locator.join('w-2')).called(1);
      expect(find.text('battle on valley'), findsOneWidget);
      verify(repository.close).called(1);
      verifyNever(next.close);
    });

    testWidgets('M7.12 checks the list again when asked', (tester) async {
      stubBattles(const [_mine, _third]);
      await pumpPage(tester);
      await tester.pump();

      await tester.tap(find.text('Check again'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Choose a battle'), findsOneWidget);
      verify(() => locator.locate('a-1')).called(2);
    });

    testWidgets('M7.12 says that no battle runs, and looks again when '
        'asked', (tester) async {
      var calls = 0;
      when(() => locator.locate('a-1'))
          .thenAnswer((_) async => ++calls == 1 ? const [] : const [_mine]);

      await pumpPage(tester);
      await tester.pump();

      expect(find.text('No battle is running right now.'), findsOneWidget);

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
        find.text('Aucune bataille n’est en cours pour le moment.'),
        findsOneWidget,
      );
      expect(find.text('Vérifier à nouveau'), findsOneWidget);
      expect(find.text('Se déconnecter'), findsOneWidget);
    });

    testWidgets('SOC-30 lists and joins in French', (tester) async {
      stubBattles(const [_mine, _third, _other]);
      await pumpPage(tester, locale: const Locale('fr'));
      await tester.pump();

      expect(find.text('Choisissez une bataille'), findsOneWidget);
      expect(find.text('Bataille sur saint_lo'), findsOneWidget);
      expect(find.text('Guerre w-1'), findsOneWidget);
      expect(find.text('Vous y êtes'), findsNWidgets(2));

      await tester.tap(find.widgetWithText(FilledButton, 'Rejoindre'));
      await tester.pumpAndSettle();

      expect(find.text('Rejoindre cette guerre ?'), findsOneWidget);
      expect(
        find.text(
          'Une nouvelle section est créée pour vous dans la guerre w-2, et '
          'vous entrez dans sa bataille. Vous restez dans son équipe pendant '
          'toute la bataille.',
        ),
        findsOneWidget,
      );
      expect(find.text('Annuler'), findsOneWidget);
    });

    testWidgets('M7.12 a join that failed says so in French', (tester) async {
      stubBattles(const [_other]);
      when(() => locator.join('w-2'))
          .thenThrow(const BattleJoinFailure(BattleJoinFailureReason.warOver));
      await pumpPage(tester, locale: const Locale('fr'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Rejoindre'));
      await tester.pumpAndSettle();

      await tester.tap(inDialog('Rejoindre'));
      await tester.pumpAndSettle();

      expect(find.text('Cette guerre est terminée.'), findsOneWidget);
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
