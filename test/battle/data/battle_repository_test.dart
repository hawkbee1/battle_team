import 'dart:math';

import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_host.dart';
import '../../helpers/mocks.dart';

const _settings = BattleSettings(
  endpoint: 'http://127.0.0.1:9/v1',
  projectId: 'hawkbee',
  email: 'blue@battleteam.local',
  password: 'secret',
  battleId: 'b-1',
);

void main() {
  setUpAll(registerBattleFallbackValues);

  group(BattleRepository, () {
    late MockAppwriteApiClient apiClient;
    late FakeHost host;
    late List<Credential> credentials;
    late BattleRepository repository;

    BattleRepository repositoryOf({
      Future<Uri> Function(Credential credential)? address,
    }) => BattleRepository(
      settings: _settings,
      apiClient: apiClient,
      transport: host,
      address:
          address ??
          (credential) async {
            credentials.add(credential);
            return Uri.parse('ws://host/v1/socket');
          },
      random: Random(1),
    );

    /// Starts, and waits for the host's first view.
    Future<BattleSnapshot> play() {
      final first = repository.snapshots.firstWhere(
        (snapshot) => snapshot.units.isNotEmpty,
      );
      repository.start();
      return first.timeout(const Duration(seconds: 5));
    }

    setUp(() {
      apiClient = MockAppwriteApiClient();
      when(
        () => apiClient.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {});
      when(apiClient.createJwt).thenAnswer((_) async => 'jwt');
      host = FakeHost();
      credentials = [];
      repository = repositoryOf();
    });

    tearDown(() => repository.close());

    test('M7.1 knows its map and whether it can play', () {
      expect(repository.mapId, 'saint_lo_1km');
      expect(repository.isConfigured, isTrue);
      expect(
        BattleRepository(
          settings: const BattleSettings.fromEnvironment(),
          apiClient: apiClient,
        ).isConfigured,
        isFalse,
      );
    });

    test('M7.1 signs the player in to Appwrite with the settings', () async {
      await repository.signIn();

      verify(
        () => apiClient.signIn(
          email: 'blue@battleteam.local',
          password: 'secret',
        ),
      ).called(1);
    });

    test('M7.1 signs in to the host with a fresh JWT from Appwrite', () async {
      await play();

      expect(credentials.single.kind, CredentialKind.jwt);
      expect(credentials.single.secret, 'jwt');
      verify(apiClient.createJwt).called(1);
      expect(host.sockets, hasLength(1));
    });

    test('M7.1 shows the connection as it goes', () async {
      final statuses = <ConnectionStatus>[];
      final subscription = repository.connection.listen(statuses.add);
      addTearDown(subscription.cancel);

      await play();
      await repository.close();
      await pumpEventQueue();

      expect(statuses, [
        ConnectionStatus.connecting,
        ConnectionStatus.connected,
        ConnectionStatus.stopped,
      ]);
    });

    test('M7.1 shows the lost host as lost', () async {
      final statuses = <ConnectionStatus>[];
      final subscription = repository.connection.listen(statuses.add);
      addTearDown(subscription.cancel);
      await play();

      host.sockets.single.deliver(const Goodbye(GoodbyeReason.idle));
      await pumpEventQueue();

      expect(statuses, contains(ConnectionStatus.lost));
    });

    test('M7.1 gives the section view and its seat', () async {
      final snapshot = await play();

      expect(snapshot.units.keys, unorderedEquals(['c-1', 'r-1']));
      expect(snapshot.hqs.single.team, 'blue');
      expect(snapshot.relics.single.relicId, 'relic-1');
      expect(snapshot.team, 'blue');
      expect(snapshot.sectionId, 's-blue');
      expect(
        snapshot,
        BattleSnapshot(
          units: const {'c-1': blueCommander, 'r-1': redSoldier},
          hqs: blueView.hqs,
          relics: blueView.relics,
          section: blueView.section,
          team: 'blue',
          sectionId: 's-blue',
        ),
      );
    });

    test('HQ-32 gives the recalls the host announced', () async {
      final first = await play();
      expect(first.recalls, isEmpty);

      final next = repository.snapshots.first;
      host.sockets.single.deliver(
        TickUpdate(
          at: blueView.at + const Duration(minutes: 1),
          events: const [
            RecallBegan(unitId: 'c-1', storedAt: Duration(hours: 8)),
          ],
        ),
      );

      expect((await next).recalls, {'c-1': const Duration(hours: 8)});
    });

    test('M7.1 shows the battle time and the AP between updates', () async {
      expect(repository.battleTime, isNull);
      expect(repository.apNow(blueCommander.private!.ap), isNull);

      await play();

      expect(repository.battleTime, greaterThanOrEqualTo(blueView.at));
      expect(repository.apNow(blueCommander.private!.ap), closeTo(30, 1e-6));
    });

    test('M7.1 sends an order and gives the host answer', () async {
      await play();
      const order = Move(unitId: 'c-1', to: Position(52000, 9000, 3100));

      expect(await repository.send(order), isNull);
      host.refusal = 'not_enough_ap';
      expect(await repository.send(order), 'not_enough_ap');

      expect(host.orders, [order, order]);
    });

    test('M7.1 refuses to send before it signed in to the host', () {
      expect(repository.send(const Deploy(unitId: 'c-1')), throwsStateError);
    });

    test('M7.1 gives the last word of a host that stopped it', () async {
      await play();
      expect(repository.stopReason, isNull);

      host.sockets.single.deliver(const Goodbye(GoodbyeReason.battleEnded));
      await repository.connection.firstWhere(
        (status) => status == ConnectionStatus.stopped,
      );

      expect(repository.stopReason, contains('battleEnded'));
    });

    test('M7.1 gives the code of a refused host address', () async {
      repository = repositoryOf(
        address: (_) async =>
            throw const HostLookupException('not_your_battle', status: 403),
      )..start();
      await repository.connection.firstWhere(
        (status) => status == ConnectionStatus.stopped,
      );

      expect(repository.stopReason, 'not_your_battle');
    });

    test('M7.1 gives no reason for a repository it closed', () async {
      await play();

      await repository.close();

      expect(repository.stopReason, isNull);
    });
  });

  group('$BattleRepository over the real adapters', () {
    test('M7.1 asks Appwrite for the host with a fresh JWT', () async {
      // The test binding answers every HTTP request with 400: a lasting
      // refusal.
      TestWidgetsFlutterBinding.ensureInitialized();
      final apiClient = MockAppwriteApiClient();
      when(apiClient.createJwt).thenAnswer((_) async => 'jwt');
      final repository = BattleRepository(
        settings: _settings,
        apiClient: apiClient,
      );
      addTearDown(repository.close);
      final stopped = repository.connection.firstWhere(
        (status) => status == ConnectionStatus.stopped,
      );

      repository.start();
      await stopped;

      expect(repository.stopReason, 'appwrite_error');
      verify(apiClient.createJwt).called(greaterThanOrEqualTo(1));
    });
  });
}
