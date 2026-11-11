import 'dart:typed_data';

import 'package:battle_team/fog/model/fog_model.dart';

/// How much of the ground's colour a cell keeps, and how much it takes of the
/// fog's own: display constants, not game numbers (the fog colour is a
/// tint, not a rule).
abstract final class FogShade {
  /// What a cell seen once keeps of its colour: dimmed, since nothing of it
  /// is known now.
  static const double seenKeeps = 0.55;

  /// What a cell never seen keeps of its colour: nearly the fog's.
  static const double neverKeeps = 0.18;

  /// The colour of the fog a cell fades to, as red, green and blue.
  static const (double, double, double) tint = (0.10, 0.12, 0.18);
}

/// The vertex colours of the ground with the fog on it (MAP-33, M7 Issue 9):
/// [base] is the ground's colour at each cell's vertex (red, green, blue and
/// alpha, `y × width + x`), a cell in sight [FogLevel.lit] keeps it, one seen
/// once [FogShade.seenKeeps] of it and one never seen [FogShade.neverKeeps].
/// The ground mesh is made again from them when the fog changes, never per
/// frame (stack decision 4). Pure: the GPU class only draws the result.
///
/// Throws an [ArgumentError] when [base] does not hold four values for each
/// cell of [fog].
Float32List fogShadedColors(Float32List base, FogModel fog) {
  final cells = fog.width * fog.depth;
  if (base.length != cells * 4) {
    throw ArgumentError.value(
      base.length,
      'base',
      'must hold 4 values for each of the $cells cells',
    );
  }
  final shaded = Float32List.fromList(base);
  final (red, green, blue) = FogShade.tint;
  for (var i = 0; i < cells; i++) {
    final keeps = switch (FogLevel.values[fog.levels[i]]) {
      FogLevel.lit => 1.0,
      FogLevel.seen => FogShade.seenKeeps,
      FogLevel.never => FogShade.neverKeeps,
    };
    if (keeps == 1) continue;
    shaded
      ..[i * 4] = base[i * 4] * keeps + red * (1 - keeps)
      ..[i * 4 + 1] = base[i * 4 + 1] * keeps + green * (1 - keeps)
      ..[i * 4 + 2] = base[i * 4 + 2] * keeps + blue * (1 - keeps);
  }
  return shaded;
}
