import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_host.dart';
import '../../helpers/fake_world.dart';
import '../../helpers/mocks.dart';

const _settings = BattleSettings(
  endpoint: 'http://127.0.0.1:9/v1',
  projectId: 'hawkbee',
  email: 'blue@battleteam.local',
  password: 'secret',
  battleId: 'pt-1',
);

void main() {
  late MockAppwriteApiClient apiClient;

  setUp(() {
    apiClient = MockAppwriteApiClient();
    when(
      () => apiClient.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});
    when(apiClient.createJwt).thenAnswer((_) async => 'jwt');
  });

  Widget appOf(BattleRepository repository, Widget home) =>
      RepositoryProvider.value(
        value: repository,
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      );

  group(BattlePage, () {
    testWidgets('M7.1 loads the map, signs in and plays', (tester) async {
      final host = FakeHost();
      final repository = BattleRepository(
        settings: _settings,
        apiClient: apiClient,
        transport: host,
        address: (_) async => Uri.parse('ws://host/v1/socket'),
      );
      await tester.pumpWidget(
        appOf(
          repository,
          BattlePage(
            initialize: () async {},
            worldBuilder: FakeWorld.new,
            sceneBuilder: (_, _, _, _) => const SizedBox.expand(),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();

      expect(find.textContaining('In battle'), findsOneWidget);
      verify(
        () => apiClient.signIn(
          email: 'blue@battleteam.local',
          password: 'secret',
        ),
      ).called(1);
      expect(host.sockets, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    });

    testWidgets('M7.1 says why the map did not load', (tester) async {
      final repository = BattleRepository(
        settings: _settings,
        apiClient: apiClient,
      );
      await tester.pumpWidget(
        appOf(
          repository,
          BattlePage(loadMap: (_, _) async => throw StateError('no map')),
        ),
      );
      await tester.pump();

      expect(find.textContaining('no map'), findsOneWidget);
    });

    testWidgets('M7.1 says how to set the battle up without settings', (
      tester,
    ) async {
      final repository = BattleRepository(
        settings: const BattleSettings.fromEnvironment(),
        apiClient: apiClient,
      );
      await tester.pumpWidget(appOf(repository, const BattlePage()));
      await tester.pump();

      expect(find.textContaining('tool/playtest.dart'), findsOneWidget);
    });

    testWidgets('M7.1 has a route to the battle', (tester) async {
      final repository = BattleRepository(
        settings: const BattleSettings.fromEnvironment(),
        apiClient: apiClient,
      );
      await tester.pumpWidget(
        appOf(
          repository,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(BattlePage.route()),
              child: const Text('go'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byType(BattlePage), findsOneWidget);
    });
  });
}
