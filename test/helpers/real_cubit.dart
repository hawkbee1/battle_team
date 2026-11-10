import 'dart:math';

import 'package:battle_team/battle/battle.dart';
import 'package:mocktail/mocktail.dart';

import 'fake_host.dart';
import 'mocks.dart';
import 'pre_check.dart';

/// A cubit over the real repository, client and codec, with [host] for the
/// battle's host: what the app does, minus the network. The caller starts it
/// and closes it.
BattleCubit realCubit(FakeHost host) {
  final apiClient = MockAppwriteApiClient();
  when(
    () => apiClient.signIn(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenAnswer((_) async {});
  when(apiClient.createJwt).thenAnswer((_) async => 'jwt');
  return BattleCubit(
    repository: BattleRepository(
      settings: const BattleSettings(
        endpoint: 'http://127.0.0.1:9/v1',
        projectId: 'hawkbee',
        email: 'a@battleteam.local',
        password: 'secret',
        battleId: 'b-1',
      ),
      apiClient: apiClient,
      transport: host,
      address: (_) async => Uri.parse('ws://host/v1/socket'),
      random: Random(1),
    ),
    preCheck: testPreCheck(),
  );
}
