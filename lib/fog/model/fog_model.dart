import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// What a section knows of a cell of the ground (MAP-33): in sight now, in
/// sight once and kept for the session, or never in sight.
enum FogLevel {
  /// Never in sight of the section's units.
  never,

  /// Seen once: the section saw it, and no unit of its sees it now.
  seen,

  /// In sight of one of the section's units now.
  lit,
}

/// {@template fog_model}
/// The ground the section sees, on the coarse grid of the map's cells
/// (stack decision 5): each cell is [FogLevel.lit] now, [FogLevel.seen] once
/// or [FogLevel.never] seen (MAP-27, MAP-29, MAP-33). It is view state, not
/// game state: made from the section's own units alone (decision 237), kept
/// for the session, never sent and never logged.
///
/// A cell is `y × width + x`; the model is immutable, [lighting] gives the
/// next one.
/// {@endtemplate}
final class FogModel extends Equatable {
  /// {@macro fog_model}
  ///
  /// Every cell is [FogLevel.never] until lit.
  new dark({required this.width, required this.depth, required this.cellSizeM})
    : _levels = Uint8List(width * depth);

  const new _(this.width, this.depth, this.cellSizeM, this._levels);

  /// The columns of the map.
  final int width;

  /// The rows of the map.
  final int depth;

  /// The side of a cell, in metres.
  final double cellSizeM;

  final Uint8List _levels;

  /// What the section knows of the cell at column [x], row [y]; a cell off
  /// the map is never seen.
  FogLevel levelOf(int x, int y) => x < 0 || y < 0 || x >= width || y >= depth
      ? FogLevel.never
      : FogLevel.values[_levels[y * width + x]];

  /// Whether a unit of the section sees the cell at column [x], row [y] now.
  bool isLit(int x, int y) => levelOf(x, y) == FogLevel.lit;

  /// Whether the section has seen the cell at column [x], row [y], now or
  /// before.
  bool wasSeen(int x, int y) => levelOf(x, y) != FogLevel.never;

  /// What the section knows of the ground at [eastM], [southM] metres from
  /// the map's north-west corner.
  FogLevel levelAt(double eastM, double southM) =>
      levelOf((eastM / cellSizeM).floor(), (southM / cellSizeM).floor());

  /// The level of every cell, `y × width + x`, as a view.
  Uint8List get levels => _levels.asUnmodifiableView();

  /// How many cells are lit now.
  int get litCount =>
      _levels.where((level) => level == FogLevel.lit.index).length;

  /// This model once the cells [lit] (`y × width + x`) are the ones in
  /// sight: the others that were lit become seen once, and nothing seen is
  /// ever forgotten. Cells off the map are ignored.
  FogModel lighting(Iterable<int> lit) {
    final next = Uint8List.fromList(_levels);
    for (var i = 0; i < next.length; i++) {
      if (next[i] == FogLevel.lit.index) next[i] = FogLevel.seen.index;
    }
    for (final cell in lit) {
      if (cell >= 0 && cell < next.length) next[cell] = FogLevel.lit.index;
    }
    return FogModel._(width, depth, cellSizeM, next);
  }

  @override
  List<Object?> get props => [width, depth, cellSizeM, _levels];
}
