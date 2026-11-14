// POC (branch poc/streamed-world): the ground's terrain and fog as textures,
// read by the ground's material (`assets/materials/ground.fmat`).
//
// A page is the cells of one root tile of the ground's quadtree
// (`GroundGrid.roots`): every tile under that root draws with the page's two
// textures, one texel a cell. A texture as large as the map would pass what
// a phone or a browser takes for sure (4,096 texels a side; `saint_lo` is
// 5,000 cells long), and a fog change would upload all of it.

import 'dart:typed_data';

import 'package:battle_map/battle_map.dart';
import 'package:battle_team/battle/world/battle_space.dart';
import 'package:battle_team/battle/world/ground_tiles.dart';
import 'package:battle_team/fog/model/fog_model.dart';
import 'package:battle_team/fog/model/fog_shading.dart';

/// The texels along a page of [cells], from west to east: one a cell.
int pageWidth(CellRect cells) => cells.x1 - cells.x0 + 1;

/// The texels along a page of [cells], from north to south: one a cell.
int pageHeight(CellRect cells) => cells.y1 - cells.y0 + 1;

/// The terrain of the page of [cells] as the pixels of its texture: red,
/// green, blue and alpha, a byte each, the north-west cell first. A cell has
/// the colour of its terrain (`terrainColors`, grey for any other), as it
/// is: the material multiplies it by the slope's shade of the tile's
/// vertices.
Uint8List terrainPagePixels(MapData map, CellRect cells) {
  final names = map.spec.terrainIndex;
  final palette = Uint8List(names.length * 3);
  for (final (i, name) in names.indexed) {
    final (red, green, blue) = terrainColors[name] ?? (0.5, 0.5, 0.5);
    palette
      ..[i * 3] = (red * 255).round()
      ..[i * 3 + 1] = (green * 255).round()
      ..[i * 3 + 2] = (blue * 255).round();
  }
  final width = pageWidth(cells);
  final pixels = Uint8List(width * pageHeight(cells) * 4);
  var at = 0;
  for (var y = cells.y0; y <= cells.y1; y++) {
    final row = y * map.width;
    for (var x = cells.x0; x <= cells.x1; x++) {
      final terrain = map.terrain[row + x] * 3;
      pixels
        ..[at++] = palette[terrain]
        ..[at++] = palette[terrain + 1]
        ..[at++] = palette[terrain + 2]
        ..[at++] = 255;
    }
  }
  return pixels;
}

/// What a cell of [level] keeps of its colour under the fog (MAP-33), as the
/// byte of the fog's texture: 255 keeps it all, and the material fades the
/// rest to `FogShade.tint`.
int fogKeepsByte(FogLevel level) => switch (level) {
  FogLevel.lit => 255,
  FogLevel.seen => (FogShade.seenKeeps * 255).round(),
  FogLevel.never => (FogShade.neverKeeps * 255).round(),
};

/// The fog over the page of [cells] as the pixels of its texture, written
/// into [into] (four bytes a cell, the north-west cell first): the red byte
/// of a cell is its [fogKeepsByte], the only one the material reads. Gives
/// back the part of [into] that was written, which is the whole texture.
Uint8List fogPagePixels(FogModel fog, CellRect cells, Uint8List into) {
  final keeps = [for (final level in FogLevel.values) fogKeepsByte(level)];
  final levels = fog.levels;
  var at = 0;
  for (var y = cells.y0; y <= cells.y1; y++) {
    final row = y * fog.width;
    for (var x = cells.x0; x <= cells.x1; x++) {
      into[at] = keeps[levels[row + x]];
      at += 4;
    }
  }
  return Uint8List.sublistView(into, 0, at);
}

/// Whether the fog over the page of [cells] differs between [before] and
/// [after]: a page it does not change keeps its texture.
bool fogPageChanged(FogModel before, FogModel after, CellRect cells) {
  if (identical(before, after)) return false;
  final was = before.levels;
  final now = after.levels;
  for (var y = cells.y0; y <= cells.y1; y++) {
    final row = y * after.width;
    for (var i = row + cells.x0; i <= row + cells.x1; i++) {
      if (was[i] != now[i]) return true;
    }
  }
  return false;
}
