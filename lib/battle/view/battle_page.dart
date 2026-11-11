import 'package:battle_client/battle_client.dart';
import 'package:battle_map/battle_map.dart';
import 'package:battle_team/alerts/cubit/alerts_cubit.dart';
import 'package:battle_team/battle/cubit/battle_cubit.dart';
import 'package:battle_team/battle/data/battle_repository.dart';
import 'package:battle_team/battle/data/map_assets.dart';
import 'package:battle_team/battle/data/order_checks.dart';
import 'package:battle_team/battle/data/unit_bodies.dart';
import 'package:battle_team/battle/view/battle_view.dart';
import 'package:battle_team/battle/world/battle_camera.dart';
import 'package:battle_team/battle/world/battle_world.dart';
import 'package:battle_team/battle/world/scene_battle_world.dart';
import 'package:battle_team/fog/cubit/fog_cubit.dart';
import 'package:battle_team/fog/data/ground_sight_loader.dart';
import 'package:battle_team/fog/model/fog_tracker.dart';
import 'package:battle_team/shop/cubit/shop_cubit.dart';
import 'package:battle_team/storage/cubit/storage_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_scene/scene.dart';
import 'package:material_ui/material_ui.dart';

/// {@template battle_page}
/// Opens the battle of the [BattleRepository] in the tree as its player:
/// loads the map, the unit types' bodies and what the order pre-check reads,
/// finds the battle's host and plays. Its map, its 3D world and its scene are
/// built by the functions it is given, so that tests run without a GPU.
/// {@endtemplate}
class BattlePage extends StatefulWidget {
  /// {@macro battle_page}
  const new({
    super.key,
    this.loadMap = loadMapAsset,
    this.loadBodies = loadUnitBodies,
    this.loadPreCheck = loadOrderPreCheck,
    this.loadMovePreviewer = loadMovePreview,
    this.loadSight = loadGroundSight,
    this.initialize = Scene.initializeStaticResources,
    this.worldBuilder = SceneBattleWorld.new,
    this.sceneBuilder = buildBattleScene,
  });

  /// Loads a map from the assets.
  final Future<MapData> Function(AssetBundle bundle, String mapId) loadMap;

  /// Loads the unit types' bodies from the assets.
  final Future<UnitBodies> Function(AssetBundle bundle) loadBodies;

  /// Loads what the order pre-check reads from the assets.
  final Future<OrderPreCheck> Function(AssetBundle bundle) loadPreCheck;

  /// Loads the move preview, which plans a path on the map.
  final Future<MovePreviewer> Function(AssetBundle bundle, String mapId)
  loadMovePreviewer;

  /// Loads the ground a unit sees, which the fog is made of.
  final Future<GroundSight> Function(AssetBundle bundle, String mapId)
  loadSight;

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
  late final Future<
    ({
      MapData map,
      UnitBodies bodies,
      OrderPreCheck preCheck,
      MovePreviewer previewer,
      GroundSight sight,
    })
  >
  _ready = () async {
    final bundle = DefaultAssetBundle.of(context);
    final mapId = context.read<BattleRepository>().mapId;
    final map = await widget.loadMap(bundle, mapId);
    final bodies = await widget.loadBodies(bundle);
    final preCheck = await widget.loadPreCheck(bundle);
    final previewer = await widget.loadMovePreviewer(bundle, mapId);
    final sight = await widget.loadSight(bundle, mapId);
    await widget.initialize();
    return (
      map: map,
      bodies: bodies,
      preCheck: preCheck,
      previewer: previewer,
      sight: sight,
    );
  }();

  @override
  Widget build(BuildContext context) {
    final repository = context.read<BattleRepository>();
    return Scaffold(
      body: FutureBuilder(
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
                lazy: false,
                create: (_) => AlertsCubit(repository: repository)..start(),
              ),
              BlocProvider(
                lazy: false,
                create: (_) => FogCubit(
                  repository: repository,
                  tracker: FogTracker(sight: data.sight, bodies: data.bodies),
                )..start(),
              ),
              BlocProvider(
                lazy: false,
                create: (_) =>
                    ShopCubit(repository: repository, preCheck: data.preCheck)
                      ..start(),
              ),
              BlocProvider(
                create: (_) => BattleCubit(
                  repository: repository,
                  preCheck: data.preCheck,
                  movePreviewer: data.previewer,
                )..start(),
              ),
            ],
            child: BattleView(
              map: data.map,
              world: widget.worldBuilder(data.map),
              sceneBuilder: widget.sceneBuilder,
              bodies: data.bodies,
            ),
          ),
          AsyncSnapshot(:final Object error) => Center(child: Text('$error')),
          _ => const Center(child: CircularProgressIndicator()),
        },
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
