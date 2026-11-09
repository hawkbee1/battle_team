import 'package:appwrite_api_client/appwrite_api_client.dart';
import 'package:battle_team/playtest/playtest.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_host.dart';
import '../../helpers/fake_world.dart';

class _MockAppwriteApiClient extends Mock implements AppwriteApiClient;

const _settings = PlaytestSettings(
  endpoint: 'http://127.0.0.1:9/v1',
  projectId: 'hawkbee',
  email: 'blue@battleteam.local',
  password: 'secret',
  battleId: 'pt-1',
);

void main() {
  late AppwriteApiClient apiClient;

  setUp(() {
    apiClient = _MockAppwriteApiClient();
    when(
      () => apiClient.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});
    when(() => apiClient.createJwt()).thenAnswer((_) async => 'jwt');
  });

  group(PlaytestPage, () {
    testWidgets('loads the map, signs in and plays', (tester) async {
      final host = FakeHost();
      await tester.pumpWidget(
        PlaytestApp(
          settings: _settings,
          apiClient: apiClient,
          home: PlaytestPage(
            settings: _settings,
            apiClient: apiClient,
            initialize: () async {},
            worldBuilder: FakeWorld.new,
            sceneBuilder: (_, _, _, _) => const SizedBox.expand(),
            clientBuilder: (_, _) => fakeClient(host),
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
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    });

    testWidgets('says why the map did not load', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PlaytestPage(
            settings: _settings,
            apiClient: apiClient,
            loadMap: (_, _) async => throw StateError('no map'),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('no map'), findsOneWidget);
    });
  });

  group('playtestClient', () {
    test('asks Appwrite for the host with a fresh JWT', () async {
      final client = playtestClient(_settings, apiClient);
      expect(client.battleId, 'pt-1');

      client.start();
      // Every HTTP request of a test answers 400: a lasting refusal.
      await client.stopped;

      expect(client.lookupRefused?.status, 400);

      verify(() => apiClient.createJwt()).called(greaterThanOrEqualTo(1));
    });
  });

  group(PlaytestApp, () {
    testWidgets('says how to set the playtest up without settings', (
      tester,
    ) async {
      await tester.pumpWidget(
        PlaytestApp(
          settings: const PlaytestSettings.fromEnvironment(),
          apiClient: apiClient,
        ),
      );
      await tester.pump();

      expect(find.textContaining('tool/playtest.dart'), findsOneWidget);
    });

    testWidgets('opens the battle with its settings', (tester) async {
      await tester.pumpWidget(
        PlaytestApp(settings: _settings, apiClient: apiClient),
      );

      expect(find.byType(PlaytestPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
