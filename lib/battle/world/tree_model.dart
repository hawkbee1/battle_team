// coverage:ignore-file
// Imports the glTF model through flutter_scene, which needs a GPU context
// that `flutter test` does not have.

import 'package:flutter/services.dart' show AssetBundle;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

/// Where the tree model is in the app's assets.
const treeModelAsset = 'assets/3d_models/tree_1.glb';

/// {@template tree_part}
/// One primitive of the tree model: its geometry, its material, and the
/// transform from the model's root to it.
/// {@endtemplate}
typedef TreePart = ({Geometry geometry, Material material, Matrix4 transform});

/// {@template tree_model}
/// The tree model, flattened into its [parts]. Its lowest point is [baseY]
/// in the model's frame, so a tree stands on the ground when its [baseY] is
/// placed at the ground's height.
/// {@endtemplate}
final class TreeModel {
  /// {@macro tree_model}
  const new({required this.parts, required this.baseY});

  /// The model's primitives, each with its own material.
  final List<TreePart> parts;

  /// The height of the model's lowest point, in its own frame.
  final double baseY;
}

/// A tree made in code, of about 30 triangles: a trunk and a cone of
/// leaves, 9.5 m tall. POC: it stands in until a low-poly model is chosen
/// (the model of [treeModelAsset] is 20,000 triangles, too many for a
/// forest).
Future<TreeModel> loadPlaceholderTree(AssetBundle bundle) async => TreeModel(
  parts: [
    (
      geometry: CylinderGeometry(
        bottomRadius: 0.45,
        topRadius: 0.3,
        height: 3,
        radialSegments: 5,
      ),
      material: PhysicallyBasedMaterial()
        ..baseColorFactor = Vector4(0.36, 0.26, 0.17, 1)
        ..roughnessFactor = 0.9,
      transform: Matrix4.translation(Vector3(0, 1.5, 0)),
    ),
    (
      geometry: CylinderGeometry(
        bottomRadius: 3.2,
        topRadius: 0,
        height: 7,
        radialSegments: 6,
      ),
      material: PhysicallyBasedMaterial()
        ..baseColorFactor = Vector4(0.16, 0.33, 0.14, 1)
        ..roughnessFactor = 0.9,
      transform: Matrix4.translation(Vector3(0, 6, 0)),
    ),
  ],
  baseY: 0,
);

/// Loads the tree model from the app's assets.
Future<TreeModel> loadTreeModel(AssetBundle bundle) async {
  final root = await Node.fromGlbAsset(treeModelAsset);
  final parts = <TreePart>[];
  _collect(root, Matrix4.identity(), parts);
  var baseY = double.infinity;
  for (final part in parts) {
    final bounds = part.geometry.localBounds;
    if (bounds == null) continue;
    for (final x in [bounds.min.x, bounds.max.x]) {
      for (final y in [bounds.min.y, bounds.max.y]) {
        for (final z in [bounds.min.z, bounds.max.z]) {
          final corner = part.transform.transform3(Vector3(x, y, z));
          if (corner.y < baseY) baseY = corner.y;
        }
      }
    }
  }
  return TreeModel(parts: parts, baseY: baseY.isFinite ? baseY : 0);
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
