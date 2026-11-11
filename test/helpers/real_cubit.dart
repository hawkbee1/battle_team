import 'dart:math';

import 'package:battle_client/battle_client.dart';
import 'package:battle_team/alerts/cubit/alerts_cubit.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/fog/cubit/fog_cubit.dart';
import 'package:battle_team/fog/model/fog_tracker.dart';
import 'package:battle_team/storage/cubit/storage_cubit.dart';
import 'package:mocktail/mocktail.dart';

import 'fake_host.dart';
import 'fog.dart';
import 'mocks.dart';
import 'pre_check.dart';

/// A cubit over the real repository, client and codec, with [host] for the
/// battle's host: what the app does, minus the network. The caller starts it
/// and closes it.
BattleCubit realCubit(FakeHost host, {MovePreviewer? previewer}) {
  final apiClient = MockAppwriteApiClient();
  when(apiClient.createJwt).thenAnswer((_) async => 'jwt');
  return BattleCubit(
    repository: BattleRepository(
      settings: const BattleSettings(
        endpoint: 'http://127.0.0.1:9/v1',
        projectId: 'hawkbee',
        battleId: 'b-1',
      ),
      apiClient: apiClient,
      transport: host,
      address: (_) async => Uri.parse('ws://host/v1/socket'),
      random: Random(1),
    ),
    preCheck: testPreCheck(),
    movePreviewer: previewer,
  );
}

/// The storage cubit over the same repository as [battle]; started, so that it
/// follows the view from the first message. Call it before `battle.start()`.
StorageCubit realStorageCubit(BattleCubit battle) =>
    StorageCubit(repository: battle.repository, preCheck: battle.preCheck)
      ..start();

/// The fog cubit over the same repository as [battle], on [tracker] (a flat
/// map by default); started. Call it before `battle.start()`.
FogCubit realFogCubit(BattleCubit battle, {FogTracker? tracker}) =>
    FogCubit(repository: battle.repository, tracker: tracker ?? testTracker())
      ..start();

/// The alerts cubit over the same repository as [battle]; started. Call it
/// before `battle.start()`, so that the alerts sent on connecting are heard.
AlertsCubit realAlertsCubit(BattleCubit battle) =>
    AlertsCubit(repository: battle.repository)..start();
