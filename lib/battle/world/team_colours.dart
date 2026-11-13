// POC (branch poc/streamed-world): the colours of the teams, kept apart from
// the GPU code so they are tested.

import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

/// The colours of the teams, in team order, as sRGB (MAP-04: 2 to 5 teams).
/// The Okabe–Ito palette, picked to stay apart for the three kinds of colour
/// blindness: blue, yellow, vermillion, sky blue, black. The closest pair is
/// at 18.9 (OKLab × 100) in the worst case; under 10 is hard to tell apart.
const teamPalette = <int>[
  0xFF0072B2, // blue
  0xFFF0E442, // yellow
  0xFFD55E00, // vermillion
  0xFF56B4E9, // sky blue
  0xFF111111, // black
];

/// The colour of a relic nobody owns (sRGB).
const unownedColor = 0xFFFFFFFF;

/// The colour of a team the palette has no place for (sRGB): a grey.
const otherTeamColor = 0xFF9E9E9E;

/// How much of its team's colour a part of a near model takes, the rest being
/// white: the part's texture is multiplied by the result, so a whole colour
/// would bury it (and a black team would lose the shape of its units). A far
/// model has no texture and takes its team's colour whole.
const nearTintMix = 0.75;

/// The place of [team] among the teams, 0 for the first, from the number its
/// id ends with (`team-3` is the third); null when the id has no such number
/// or the palette has no place for it.
int? teamIndex(String? team) {
  if (team == null) return null;
  final number = int.tryParse(RegExp(r'\d+$').stringMatch(team) ?? '');
  if (number == null || number < 1 || number > teamPalette.length) return null;
  return number - 1;
}

/// The colour of [team]'s units, HQ and relics, as the linear RGB the
/// materials take. A null [team] is a relic nobody owns.
Vector4 teamColor(String? team) {
  if (team == null) return srgbToLinear(unownedColor);
  final index = teamIndex(team);
  return srgbToLinear(index == null ? otherTeamColor : teamPalette[index]);
}

/// The linear RGBA of [argb], an sRGB colour as `0xAARRGGBB`.
Vector4 srgbToLinear(int argb) {
  double channel(int shift) {
    final value = (argb >> shift & 0xFF) / 255;
    return value <= 0.04045
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return Vector4(channel(16), channel(8), channel(0), (argb >>> 24) / 255);
}

/// The relative luminance of a linear colour, 0 for black and 1 for white.
double luminanceOf(Vector4 linear) =>
    0.2126 * linear.x + 0.7152 * linear.y + 0.0722 * linear.z;

/// The colour of the rim around a team's disc: white or black, whichever
/// stands out more from [team] (the greater contrast ratio), so that a unit
/// is outlined by lightness whatever the ground and the hue it is on.
Vector4 rimColor(Vector4 team) {
  // Contrast with white, 1.05 / (l + 0.05), meets contrast with black,
  // (l + 0.05) / 0.05, at l = sqrt(1.05 * 0.05) - 0.05.
  const meeting = 0.1791;
  return luminanceOf(team) > meeting
      ? Vector4(0, 0, 0, 1)
      : Vector4(1, 1, 1, 1);
}

/// [team] mixed with white, [mix] of the way from white (0) to [team] (1).
Vector4 mixedWithWhite(Vector4 team, double mix) => Vector4(
  1 + (team.x - 1) * mix,
  1 + (team.y - 1) * mix,
  1 + (team.z - 1) * mix,
  1,
);
