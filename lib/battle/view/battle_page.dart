import 'dart:async';
import 'dart:math';

import 'package:appwrite_api_client/appwrite_api_client.dart';
import 'package:battle_client/battle_client.dart';
import 'package:battle_map/battle_map.dart';
import 'package:battle_team/battle/battle_settings.dart';
import 'package:battle_team/battle/cubit/battle_cubit.dart';
import 'package:battle_team/battle/map_assets.dart';
import 'package:battle_team/battle/view/battle_view.dart';
import 'package:battle_team/battle/world/battle_world.dart';
import 'package:battle_team/battle/world/scene_battle_world.dart';
import 'package:battle_team/battle/world/top_down_camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_scene/scene.dart';
import 'package:material_ui/material_ui.dart';

/// {@template battle_page}
/// Opens the battle of [settings] as its player: loads the map, signs in
/// with [apiClient], finds the battle's host and plays.
/// {@endtemplate}
class BattlePage extends StatefulWidget {
  /// {@macro battle_page}
  const new({
    required this.settings,
    required this.apiClient,
    super.key,
    this.loadMap = loadMapAsset,
    this.initialize = Scene.initializeStaticResources,
    this.worldBuilder = SceneBattleWorld.new,
    this.sceneBuilder = buildBattleScene,
    this.clientBuilder = playtestClient,
  });

  /// What to play.
  final BattleSettings settings;

  /// The Appwrite project.
  final AppwriteApiClient apiClient;

  /// Loads a map from the assets.
  final Future<MapData> Function(AssetBundle bundle, String mapId) loadMap;

  /// Loads flutter_scene's shaders and shared resources.
  final Future<void> Function() initialize;

  /// The 3D world of a map.
  final BattleWorld Function(MapData map) worldBuilder;

  /// Builds the 3D area.
  final BattleSceneBuilder sceneBuilder;

  /// The connection to the battle's host.
  final BattleClient Function(
    BattleSettings settings,
    AppwriteApiClient apiClient,
  )
  clientBuilder;

  @override
  State<BattlePage> createState() => _BattlePageState();
}

class _BattlePageState extends State<BattlePage> {
  late final Future<MapData> _ready = () async {
    final map = await widget.loadMap(
      DefaultAssetBundle.of(context),
      widget.settings.mapId,
    );
    await widget.initialize();
    return map;
  }();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF1E2228),
    body: FutureBuilder(
      future: _ready,
      builder: (context, snapshot) => switch (snapshot) {
        AsyncSnapshot(:final MapData data) => BlocProvider(
          create: (_) {
            final settings = widget.settings;
            final cubit = BattleCubit(
              client: widget.clientBuilder(settings, widget.apiClient),
              signIn: () => widget.apiClient.signIn(
                email: settings.email,
                password: settings.password,
              ),
            );
            unawaited(cubit.start());
            return cubit;
          },
          child: BattleView(
            map: data,
            world: widget.worldBuilder(data),
            sceneBuilder: widget.sceneBuilder,
          ),
        ),
        AsyncSnapshot(:final Object error) => Center(
          child: Text('$error', style: const TextStyle(color: Colors.white)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    ),
  );
}

/// The connection of the player of [settings]: it finds the battle's host
/// through Appwrite and signs in with a fresh JWT each time.
BattleClient playtestClient(
  BattleSettings settings,
  AppwriteApiClient apiClient,
) {
  final finder = AppwriteHostFinder(
    endpoint: Uri.parse(settings.endpoint),
    project: settings.projectId,
  );
  return BattleClient(
    battleId: settings.battleId,
    transport: const WebSocketTransport(),
    address: (credential) => finder.socketOf(settings.battleId, credential),
    credential: () async => Credential.jwt(await apiClient.createJwt()),
    clock: const SystemClock(),
    random: Random.secure(),
  );
}

// coverage:ignore-start
// Draws through flutter_scene, which needs a GPU context.

/// The 3D area: [world]'s scene seen from [camera].
Widget buildBattleScene(
  BuildContext context,
  BattleWorld world,
  TopDownCamera camera,
  void Function(double seconds) onTick,
) => SceneView(
  (world as SceneBattleWorld).scene,
  cameraBuilder: (_) => PerspectiveCamera(
    position: camera.position,
    target: camera.target,
    fovRadiansY: camera.fovY,
    fovNear: 1,
    fovFar: 8000,
  ),
  onTick: (_, seconds) => onTick(seconds),
);
// coverage:ignore-end
