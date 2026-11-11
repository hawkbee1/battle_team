import 'dart:async';

import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/fog/cubit/fog_cubit.dart';
import 'package:battle_team/fog/model/fog_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fog.dart';
import '../../helpers/log_capture.dart';

UnitView _own(String id, {required int x, int y = 5, double range = 30}) =>
    UnitView(
      unitId: id,
      unitType: 'soldier',
      sectionId: 's-blue',
      team: 'blue',
      hp: 100,
      maxHp: 100,
      position: Position.metres(x * 10 + 5, y * 10 + 5, 0),
      private: UnitPrivate(
        sightRangeM: range,
        place: UnitPlace.deployed,
        ap: const ApView(value: 30, at: Duration.zero, perHour: 1, max: 30),
        morale: 100,
        rounds: 10,
        xpEarned: 0,
        xpUnspent: 0,
      ),
    );

BattleSnapshot _snapshot(
  List<UnitView> units, {
  String? weather = 'clear',
  List<BattleEvent> world = const [],
  int version = 0,
}) => BattleSnapshot(
  units: {for (final unit in units) unit.unitId: unit},
  hqs: const [],
  relics: const [],
  weather: weather,
  world: world,
  worldVersion: version,
);

void main() {
  group(FogCubit, () {
    late StreamController<BattleSnapshot> snapshots;
    late FogCubit cubit;
    late LogCapture logs;

    setUp(() {
      logs = LogCapture();
      snapshots = StreamController<BattleSnapshot>.broadcast(sync: true);
      cubit = fogCubit(snapshots.stream);
    });

    tearDown(() async {
      await logs.cancel();
      await cubit.close();
      await snapshots.close();
    });

    test('M7.9 starts in the dark', () {
      expect(cubit.state.model.litCount, 0);
      expect(cubit.state.revision, 0);
    });

    test('MAP-27 lights what the units of the section see, once the view '
        'of the host came', () {
      snapshots.add(_snapshot([_own('u-1', x: 10)], weather: null));
      expect(cubit.state.revision, 0);

      snapshots.add(_snapshot([_own('u-1', x: 10)]));

      expect(cubit.state.model.isLit(10, 5), isTrue);
      expect(cubit.state.model.isLit(13, 5), isTrue);
      expect(cubit.state.model.isLit(14, 5), isFalse);
      expect(cubit.state.revision, 1);
    });

    test('M7.9 says nothing while the ground in sight stays the same (frame '
        'budget, stack decision 4)', () async {
      final states = <FogState>[];
      final subscription = cubit.stream.listen(states.add);
      addTearDown(subscription.cancel);

      snapshots
        ..add(_snapshot([_own('u-1', x: 10)]))
        ..add(_snapshot([_own('u-1', x: 10)]))
        ..add(_snapshot([_own('u-1', x: 10)]));
      await pumpEventQueue();

      expect(states, hasLength(1));
    });

    test('MAP-33 the ground a unit left is seen once', () {
      snapshots
        ..add(_snapshot([_own('u-1', x: 5)]))
        ..add(_snapshot([_own('u-1', x: 20)]));

      expect(cubit.state.model.levelOf(5, 5), FogLevel.seen);
      expect(cubit.state.model.levelOf(20, 5), FogLevel.lit);
      expect(cubit.state.model.levelOf(12, 5), FogLevel.never);
      expect(cubit.state.revision, 2);
    });

    test('MAP-31 a change of weather lights less', () {
      snapshots
        ..add(_snapshot([_own('u-1', x: 10)]))
        ..add(_snapshot([_own('u-1', x: 10)], weather: 'fog'));

      expect(cubit.state.model.isLit(10, 5), isTrue);
      expect(cubit.state.model.isLit(11, 5), isTrue);
      expect(cubit.state.model.isLit(12, 5), isFalse);
      expect(cubit.state.model.levelOf(12, 5), FogLevel.seen);
    });

    test('logs that it follows the view, and never a unit, a cell or the '
        'grid (decision 237)', () {
      snapshots.add(_snapshot([_own('u-1', x: 10)]));

      final text = logs.records.map((record) => record.message).join('\n');
      expect(text, contains('following'));
      expect(text, isNot(contains('u-1')));
      expect(text, isNot(contains('lit')));
    });

    test('stops following the view when it is closed', () async {
      await cubit.close();

      snapshots.add(_snapshot([_own('u-1', x: 10)]));

      expect(cubit.state.revision, 0);
    });
  });
}
