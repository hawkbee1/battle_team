import 'dart:async';

import 'package:battle_client/battle_client.dart';
import 'package:battle_map/battle_map.dart';
import 'package:battle_team/battle/cubit/battle_cubit.dart';
import 'package:battle_team/battle/data/battle_repository.dart';
import 'package:battle_team/battle/data/map_assets.dart';
import 'package:battle_team/battle/data/order_checks.dart';
import 'package:battle_team/battle/data/unit_bodies.dart';
import 'package:battle_team/battle/view/battle_view.dart';
import 'package:battle_team/battle/world/battle_camera.dart';
import 'package:battle_team/battle/world/battle_world.dart';
import 'package:battle_team/battle/world/scene_battle_world.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:battle_team/storage/cubit/storage_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_scene/scene.dart';
import 'package:material_ui/material_ui.dart';

/// {@template battle_page}
/// Opens the battle of the [BattleRepository] in the tree as its player:
/// loads the map, the unit types' bodies and what the order pre-check reads,
/// signs in, finds the battle's
/// host and plays. Its map, its 3D world and its scene are built by the
/// functions it is given, so that tests run without a GPU.
/// {@endtemplate}
class BattlePage extends StatefulWidget {
  /// {@macro battle_page}
  const new({
    super.key,
    this.loadMap = loadMapAsset,
    this.loadBodies = loadUnitBodies,
    this.loadPreCheck = loadOrderPreCheck,
    this.initialize = Scene.initializeStaticResources,
    this.worldBuilder = SceneBattleWorld.new,
    this.sceneBuilder = buildBattleScene,
  });

  /// The route to the battle, for the title's Start button.
  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const BattlePage());

  /// Loads a map from the assets.
  final Future<MapData> Function(AssetBundle bundle, String mapId) loadMap;

  /// Loads the unit types' bodies from the assets.
  final Future<UnitBodies> Function(AssetBundle bundle) loadBodies;

  /// Loads what the order pre-check reads from the assets.
  final Future<OrderPreCheck> Function(AssetBundle bundle) loadPreCheck;

  /// Loads flutter_scene's shaders and shared resources.
  final Future<void> Function() initialize;

  /// The 3D world of a map.
  final BattleWorld Function(MapData map) worldBuilder;

  /// Builds the 3D area.
  final BattleSceneBuilder sceneBuilder;

  @override
  State<BattlePage> createState() => _BattlePageState();
}

class _BattlePageState extends State<BattlePage> {
  late final Future<({MapData map, UnitBodies bodies, OrderPreCheck preCheck})>
  _ready = () async {
    final bundle = DefaultAssetBundle.of(context);
    final map = await widget.loadMap(
      bundle,
      context.read<BattleRepository>().mapId,
    );
    final bodies = await widget.loadBodies(bundle);
    final preCheck = await widget.loadPreCheck(bundle);
    await widget.initialize();
    return (map: map, bodies: bodies, preCheck: preCheck);
  }();

  @override
  Widget build(BuildContext context) {
    final repository = context.read<BattleRepository>();
    return Scaffold(
      body: repository.isConfigured
          ? FutureBuilder(
              future: _ready,
              builder: (context, snapshot) => switch (snapshot) {
                AsyncSnapshot(:final data?) => MultiBlocProvider(
                  providers: [
                    // First, and not lazy: it follows the view from the
                    // first message the battle cubit makes the repository
                    // fetch.
                    BlocProvider(
                      lazy: false,
                      create: (_) => StorageCubit(
                        repository: repository,
                        preCheck: data.preCheck,
                      )..start(),
                    ),
                    BlocProvider(
                      create: (_) {
                        final cubit = BattleCubit(
                          repository: repository,
                          preCheck: data.preCheck,
                        );
                        unawaited(cubit.start());
                        return cubit;
                      },
                    ),
                  ],
                  child: BattleView(
                    map: data.map,
                    world: widget.worldBuilder(data.map),
                    sceneBuilder: widget.sceneBuilder,
                    bodies: data.bodies,
                  ),
                ),
                AsyncSnapshot(:final Object error) => Center(
                  child: Text('$error'),
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(context.l10n.battleMissingSettings),
              ),
            ),
    );
  }
}

// coverage:ignore-start
// Draws through flutter_scene, which needs a GPU context.

/// The 3D area: [world]'s scene seen from [camera].
Widget buildBattleScene(
  BuildContext context,
  BattleWorld world,
  BattleCamera camera,
  void Function(double seconds) onTick,
) => SceneView(
  (world as SceneBattleWorld).scene,
  cameraBuilder: (_) => PerspectiveCamera(
    position: camera.position,
    target: camera.position + camera.forward,
    fovRadiansY: camera.fovY,
    fovNear: camera.near,
    fovFar: 8000,
  ),
  onTick: (_, seconds) => onTick(seconds),
);
// coverage:ignore-end
