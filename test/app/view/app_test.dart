import 'package:backend_status_repository/backend_status_repository.dart';
import 'package:battle_team/app/app.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

void main() {
  group(App, () {
    late BackendStatusRepository backendStatusRepository;
    late MockBattleRepository battleRepository;

    setUp(() {
      backendStatusRepository = MockBackendStatusRepository();
      when(backendStatusRepository.checkConnection).thenAnswer((_) async {});
      battleRepository = MockBattleRepository();
      // Without settings the battle screen stops at how to set it up, so
      // that the test needs no GPU.
      when(() => battleRepository.isConfigured).thenReturn(false);
    });

    Widget app() => App(
      backendStatusRepository: backendStatusRepository,
      battleRepository: battleRepository,
    );

    testWidgets('M7.1 opens on the title', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.byType(AppView), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Connected to Appwrite'), findsOneWidget);
    });

    testWidgets('M7.1 routes the title to the battle', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(find.byType(BattlePage), findsOneWidget);
      expect(find.text('Start'), findsNothing);
    });

    testWidgets('M7.1 speaks French with the Material localizations of '
        'material_ui', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('fr')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text('Démarrer'), findsOneWidget);
      expect(find.text('Connecté à Appwrite'), findsOneWidget);
      // The Material widgets draw with material_ui's own localizations.
      final material = MaterialLocalizations.of(
        tester.element(find.byType(Scaffold)),
      );
      expect(material.backButtonTooltip, 'Retour');
    });

    testWidgets('M7.1 builds its repositories from the build settings', (
      tester,
    ) async {
      final apiClient = MockAppwriteApiClient();
      when(apiClient.ping).thenAnswer((_) async {});

      await tester.pumpWidget(App.fromApiClient(apiClient));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      // No settings were given at build time: the battle says how to.
      expect(find.textContaining('tool/playtest.dart'), findsOneWidget);
      verify(apiClient.ping).called(1);
    });
  });
}
