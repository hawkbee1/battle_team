import 'dart:async';

import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/storage/cubit/storage_cubit.dart';
import 'package:mocktail/mocktail.dart';

import 'mocks.dart';
import 'pre_check.dart';

/// A storage cubit over a mocked repository, at battle time [time], that
/// follows [snapshots]; its orders are accepted; the caller closes it.
StorageCubit storageCubit(
  Stream<BattleSnapshot> snapshots, {
  MockBattleRepository? repository,
  Duration? time = const Duration(hours: 1),
}) {
  registerBattleFallbackValues();
  final repo = repository ?? MockBattleRepository();
  when(() => repo.snapshots).thenAnswer((_) => snapshots);
  when(() => repo.battleTime).thenReturn(time);
  when(() => repo.apNow(any()))
      .thenAnswer((call) => (call.positionalArguments.first as ApView).value);
  when(() => repo.send(any())).thenAnswer((_) async => null);
  return StorageCubit(repository: repo, preCheck: testPreCheck())..start();
}
