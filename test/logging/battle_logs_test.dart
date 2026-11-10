import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fake_host.dart';
import '../helpers/helpers.dart';

void main() {
  group('a battle played over a recorded stream', () {
    late LogCapture log;

    setUp(() => log = LogCapture());

    tearDown(() => log.cancel());

    test('decision 237 logs nothing the section does not see', () async {
      // Section 2 in clear weather, and in fog: fog hides some of what the
      // host showed it.
      final clear = FakeHost.recorded('clear_s-2_host').view;
      final fog = FakeHost.recorded('fog_s-2_host').view;
      final seen = {for (final unit in fog.units) unit.unitId};
      final hidden = {
        for (final unit in clear.units)
          if (!seen.contains(unit.unitId)) unit.unitId,
      };
      expect(hidden, isNotEmpty, reason: 'the recordings must differ');

      // No recording holds an unseen hit: a unit the section sees takes one
      // from a shooter it does not see (COMBAT-57).
      final recorded = FakeHost.recorded('fog_s-2');
      final host = FakeHost(
        view: recorded.view,
        updates: [
          ...recorded.updates,
          TickUpdate(
            at: recorded.view.at + const Duration(seconds: 1),
            unseenHits: [
              UnseenHit(
                targetId: recorded.view.units.first.unitId,
                damage: 12,
                result: ImpactResult.damaged,
              ),
            ],
          ),
        ],
        accountId: recorded.accountId,
        sectionId: recorded.sectionId,
        team: recorded.team,
      );
      final apiClient = MockAppwriteApiClient();
      when(
        () => apiClient.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {});
      when(apiClient.createJwt).thenAnswer((_) async => 'jwt-secret-value');
      final cubit = BattleCubit(
        repository: BattleRepository(
          settings: const BattleSettings(
            endpoint: 'http://127.0.0.1:9/v1',
            projectId: 'hawkbee',
            email: 'a@battleteam.local',
            password: 'password-value',
            battleId: 'b-1',
          ),
          apiClient: apiClient,
          transport: host,
          address: (_) async => Uri.parse('ws://host/v1/socket'),
        ),
      );
      addTearDown(cubit.close);

      await cubit.start();
      await pumpEventQueue(times: 500);
      cubit.select(cubit.state.sectionUnits.first.unitId);
      await cubit.moveSelectedTo(const Position(52000, 9000, 3100));

      // The lifecycle of the client and of the order, in the log.
      expect(
        log.lines,
        containsAll([
          'INFO sign-in accepted',
          'INFO order move sent',
          'INFO order move accepted',
        ]),
      );
      expect(
        log.records.map((record) => record.loggerName).toSet(),
        containsAll(['battle_client.BattleClient', 'battle_team.BattleCubit']),
      );
      // The hit came through, yet no record names the unit it hit, a unit
      // the section does not see, a position, or a secret.
      expect(cubit.state.units, isNotEmpty);
      for (final text in log.texts) {
        for (final id in {...hidden, ...seen}) {
          expect(text, isNot(contains(id)));
        }
        expect(text, isNot(contains('52000')));
        expect(text, isNot(contains('jwt-secret-value')));
        expect(text, isNot(contains('password-value')));
      }
      expect(
        log.records.where((record) => record.level >= Level.SEVERE),
        isEmpty,
      );
    });
  });
}
