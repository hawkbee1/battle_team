// coverage:ignore-file
// Makes textures and materials through flutter_scene, which needs a GPU
// context that `flutter test` does not have.
//
// POC (branch poc/streamed-world).

import 'dart:typed_data';

import 'package:battle_map/battle_map.dart';
import 'package:battle_team/battle/world/ground_pages.dart';
import 'package:battle_team/battle/world/ground_tiles.dart';
import 'package:battle_team/fog/model/fog_model.dart';
import 'package:battle_team/fog/model/fog_shading.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

/// Where the ground's material is in the app: `hook/build.dart` compiles it.
const groundMaterialSource = 'assets/materials/ground.fmat';

/// {@template ground_page}
/// A page of the ground on the GPU: the [material] every tile under one root
/// of the quadtree is drawn with, which reads the terrain of the page's
/// [cells] from a texture made once and their fog from a texture uploaded
/// again when the fog changes there.
/// {@endtemplate}
class GroundPage {
  /// {@macro ground_page}
  new({required this.cells, required this.material});

  /// The cells of the page: those of its root tile.
  final CellRect cells;

  /// The material of the page's tiles.
  final PreprocessedMaterial material;

  Texture2D? _fogTexture;
  FogModel? _shown;

  // One buffer for the fog of every page, as large as the largest asked
  // for: an upload copies it, so the next page can write over it.
  static Uint8List _scratch = Uint8List(0);

  /// Whether the page shows [fog].
  bool shows(FogModel fog) => identical(_shown, fog);

  /// Shows [fog] on the page. Gives whether its texture was uploaded: a
  /// page whose cells [fog] leaves as they were keeps it.
  bool showFog(FogModel fog) {
    final shown = _shown;
    _shown = fog;
    if (shown != null && !fogPageChanged(shown, fog, cells)) return false;
    final width = pageWidth(cells);
    final height = pageHeight(cells);
    if (_scratch.length < width * height * 4) {
      _scratch = Uint8List(width * height * 4);
    }
    final pixels = fogPagePixels(fog, cells, _scratch);
    if (_fogTexture case final texture?) {
      texture.gpuTexture.overwrite(ByteData.sublistView(pixels));
      return true;
    }
    // Not minified enough to need a mip chain: the fog is wide patches.
    final texture = _fogTexture = Texture2D.fromPixels(
      pixels,
      width,
      height,
      content: TextureContent.data,
      sampling: const TextureSampling(
        mipmaps: false,
        addressMode: .clampToEdge,
      ),
    );
    material.parameters.setTexture(
      'fog_texture',
      texture.gpuTexture,
      sampler: texture.sampledSampler,
    );
    return true;
  }
}

/// {@template ground_materials}
/// The pages of a map's ground, by the root tile of each.
/// {@endtemplate}
class GroundMaterials {
  /// {@macro ground_materials}
  const new(this.pages);

  /// The page of each root tile.
  final Map<GroundTile, GroundPage> pages;
}

/// Makes the pages of [map]'s ground: for each root tile, the ground's
/// material ([groundMaterialSource]) with the terrain of the root's cells as
/// its texture, mipmapped so that far ground does not shimmer.
/// [terrainMipmaps] is the knob: off, a page is made faster and far roads
/// flicker.
Future<GroundMaterials> loadGroundMaterials(
  MapData map, {
  bool terrainMipmaps = true,
}) async {
  final grid = GroundGrid.of(map);
  final (red, green, blue) = FogShade.tint;
  final pages = <GroundTile, GroundPage>{};
  for (final root in grid.roots) {
    final cells = grid.cellsOf(root);
    final terrain = Texture2D.fromPixels(
      terrainPagePixels(map, cells),
      pageWidth(cells),
      pageHeight(cells),
      // Linear colours, averaged as they are down the mip chain.
      content: TextureContent.data,
      sampling: TextureSampling(
        mipmaps: terrainMipmaps,
        addressMode: .clampToEdge,
      ),
    );
    final material = await loadFmatMaterial(groundMaterialSource);
    material.parameters
      ..setVec3('fog_tint', Vector3(red, green, blue))
      ..setTexture(
        'terrain_texture',
        terrain.gpuTexture,
        sampler: terrain.sampledSampler,
      );
    pages[root] = GroundPage(cells: cells, material: material);
  }
  return GroundMaterials(pages);
}
