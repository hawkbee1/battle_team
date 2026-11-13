// coverage:ignore-file
// Imports the glTF model through flutter_scene, which needs a GPU context
// that `flutter test` does not have.

import 'package:flutter/services.dart' show AssetBundle;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

/// A kind of tree: where its model is in the app's assets, how tall it
/// stands in metres (the models keep the scale of their download), and the
/// colour of its leaves (linear RGB), which its far model takes.
typedef TreeKind = ({
  String asset,
  double heightM,
  (double, double, double) leaves,
});

/// The trees of the game. The leaf colours are the mean of the green of
/// each model: of the pine's texture, and of the flow tree's vertex colours
/// times its material's colour.
const treeKinds = <TreeKind>[
  (
    asset: 'assets/3d_models/tree_pine_near.glb',
    heightM: 13,
    leaves: (0.09, 0.30, 0.04),
  ),
  (
    asset: 'assets/3d_models/tree_flow_near.glb',
    heightM: 9,
    leaves: (0.09, 0.27, 0.10),
  ),
];

/// {@template tree_part}
/// One primitive of the tree model: its geometry, its material, and the
/// transform from the model's root to it.
/// {@endtemplate}
typedef TreePart = ({Geometry geometry, Material material, Matrix4 transform});

/// {@template tree_model}
/// A tree model, flattened into its [parts], and its box in the model's own
/// frame and units: it stands on [baseY], is [height] tall, and its crown is
/// [radius] wide around ([centreX], [centreZ]). A tree is drawn [heightM]
/// metres tall, so its scale is [metresPerUnit].
/// {@endtemplate}
final class TreeModel {
  /// {@macro tree_model}
  const new({
    required this.parts,
    required this.baseY,
    this.height = 1,
    this.centreX = 0,
    this.centreZ = 0,
    this.radius = 0.5,
    this.heightM = 1,
    this.leaves = (0.1, 0.3, 0.1),
  });

  /// The model's primitives, each with its own material.
  final List<TreePart> parts;

  /// The height of the model's lowest point.
  final double baseY;

  /// How tall the model is.
  final double height;

  /// Where the middle of the model's box is, on X.
  final double centreX;

  /// Where the middle of the model's box is, on Z.
  final double centreZ;

  /// Half the width of the model's box, the mean of X and Z.
  final double radius;

  /// How tall the tree is drawn, in metres, before the variation of
  /// `treeLook`.
  final double heightM;

  /// The colour of the leaves (linear RGB), for the far model.
  final (double, double, double) leaves;

  /// The scale that draws the model [heightM] tall.
  double get metresPerUnit => heightM / height;
}

/// Loads the models of [treeKinds] from the app's assets, in their order.
Future<List<TreeModel>> loadTreeModels(AssetBundle bundle) async => [
  for (final kind in treeKinds) await _loadTreeModel(kind),
];

Future<TreeModel> _loadTreeModel(TreeKind kind) async {
  final root = await Node.fromGlbAsset(kind.asset);
  final parts = <TreePart>[];
  _collect(root, Matrix4.identity(), parts);
  final min = Vector3.all(double.infinity);
  final max = Vector3.all(double.negativeInfinity);
  for (final part in parts) {
    // A tree is not metal: the flow tree's material says 0.53, which draws
    // it dark where nothing is reflected.
    if (part.material case final PhysicallyBasedMaterial material) {
      material.metallicFactor = 0;
    }
    final bounds = part.geometry.localBounds;
    if (bounds == null) continue;
    for (final x in [bounds.min.x, bounds.max.x]) {
      for (final y in [bounds.min.y, bounds.max.y]) {
        for (final z in [bounds.min.z, bounds.max.z]) {
          final corner = part.transform.transform3(Vector3(x, y, z));
          Vector3.min(min, corner, min);
          Vector3.max(max, corner, max);
        }
      }
    }
  }
  if (!min.x.isFinite || max.y <= min.y) {
    return TreeModel(
      parts: parts,
      baseY: 0,
      heightM: kind.heightM,
      leaves: kind.leaves,
    );
  }
  return TreeModel(
    parts: parts,
    baseY: min.y,
    height: max.y - min.y,
    centreX: (min.x + max.x) / 2,
    centreZ: (min.z + max.z) / 2,
    radius: (max.x - min.x + max.z - min.z) / 4,
    heightM: kind.heightM,
    leaves: kind.leaves,
  );
}

void _collect(Node node, Matrix4 parent, List<TreePart> out) {
  final world = parent.multiplied(node.localTransform);
  for (final primitive in node.mesh?.primitives ?? const <MeshPrimitive>[]) {
    out.add((
      geometry: primitive.geometry,
      material: primitive.material,
      transform: world,
    ));
  }
  for (final child in node.children) {
    _collect(child, world, out);
  }
}
