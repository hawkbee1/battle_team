import 'dart:async';
import 'dart:io';

import 'package:battle_client/battle_client.dart';
import 'package:battle_pathfinding/battle_pathfinding.dart' as nav;
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_rules/battle_rules.dart' as rules;
import 'package:battle_team/alerts/cubit/alerts_cubit.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/battle/data/unit_bodies.dart';
import 'package:battle_team/fog/cubit/fog_cubit.dart';
import 'package:battle_team/fog/model/fog_tracker.dart';
import 'package:mocktail/mocktail.dart';

import 'mocks.dart';

/// The plan's own terrain tables, read from the app's folder.
rules.TerrainData testTerrain() =>
    rules.TerrainData.parse(File('plan/data/terrain.yaml').readAsStringSync());

/// The bodies of the plan's own unit types.
UnitBodies testBodies() => UnitBodies.fromUnits(
  rules.UnitsData.parse(File('plan/data/units.yaml').readAsStringSync()),
);

/// A flat map of [width] × [depth] cells of 10 m, all grass, the lines of
/// sight of which nothing blocks, except what `rows` of the fixture format
/// add (`terrain`, `heights`).
String flatMap({int width = 30, int depth = 30, String extra = ''}) {
  String rows(String cell) =>
      List.filled(depth, List.filled(width, cell).join(' ')).join('\n  ');
  return '''
cell 10
legend g grass
terrain
  ${rows('g')}
heights
  ${rows('0')}
$extra
''';
}

/// The ground a unit sees on [map] (a fixture map, [flatMap] by default).
GroundSight testSight({String? map}) => GroundSight(
  map: nav.NavigationFixture.parse(map ?? flatMap()),
  terrain: testTerrain(),
);

/// The fog tracker on [sight], with the plan's own unit bodies.
FogTracker testTracker({GroundSight? sight}) =>
    FogTracker(sight: sight ?? testSight(), bodies: testBodies());

/// A fog cubit over a mocked repository that follows [snapshots]; started; the
/// caller closes it.
FogCubit fogCubit(Stream<BattleSnapshot> snapshots, {FogTracker? tracker}) {
  final repository = MockBattleRepository();
  when(() => repository.snapshots).thenAnswer((_) => snapshots);
  return FogCubit(repository: repository, tracker: tracker ?? testTracker())
    ..start();
}

/// An alerts cubit over a mocked repository that follows [snapshots] and
/// [alerts], at battle time [time]; started; the caller closes it.
AlertsCubit alertsCubit(
  Stream<BattleSnapshot> snapshots, {
  Stream<RelicAlert> alerts = const Stream.empty(),
  Duration? time = const Duration(hours: 1),
}) {
  final repository = MockBattleRepository();
  when(() => repository.snapshots).thenAnswer((_) => snapshots);
  when(() => repository.alerts).thenAnswer((_) => alerts);
  when(() => repository.battleTime).thenReturn(time);
  return AlertsCubit(repository: repository)..start();
}
