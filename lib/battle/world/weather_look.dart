import 'package:vector_math/vector_math.dart';

/// {@template weather_look}
/// How the battle looks under a weather (MAP-31): the sky's colours straight
/// up ([zenith]), at the horizon ([horizon]) and below it ([below]), the
/// [sun] disk (linear HDR, black when
/// clouds hide it), and the haze far ground fades into: its [haze] colour,
/// and how far past [hazeStartM] it all but hides the ground
/// ([visibilityM]). Colours are linear RGB.
///
/// Only the look: what a unit sees is the rules' (`terrain.yaml` `weather`
/// vision factors). The haze starts where trees and buildings stop being
/// drawn, so it never hides a unit or the ground around the camera, and
/// hides where the objects end.
/// {@endtemplate}
class WeatherLook {
  /// {@macro weather_look}
  const new({
    required this.zenith,
    required this.horizon,
    required this.below,
    required this.sun,
    required this.haze,
    required this.visibilityM,
  });

  /// The sky straight up.
  final (double, double, double) zenith;

  /// The sky at the horizon.
  final (double, double, double) horizon;

  /// What shows below the horizon, past the map's edge.
  final (double, double, double) below;

  /// The sun disk, linear HDR; black when hidden.
  final (double, double, double) sun;

  /// What the far ground fades into.
  final (double, double, double) haze;

  /// How far past [hazeStartM] the ground shows before the haze all but
  /// hides it, in metres.
  final double visibilityM;

  /// How far from the eye the haze starts, in metres: the range trees and
  /// buildings are drawn to (`GroundStreamer.objectRangeM`).
  static const hazeStartM = 1500.0;

  /// The density of an exponential haze that leaves 2 % of the ground's
  /// contrast [visibilityM] past its start (Koschmieder's law, as
  /// flutter_scene's `Fog.visibilityDensity`).
  double get hazeDensity => 3.912 / visibilityM;
}

/// The look of each weather of `terrain.yaml` (clear, rain, fog, snow).
const weatherLooks = <String, WeatherLook>{
  'clear': WeatherLook(
    zenith: (0.10, 0.28, 0.68),
    horizon: (0.58, 0.72, 0.90),
    below: (0.30, 0.34, 0.38),
    sun: (3, 2.8, 2.4),
    haze: (0.58, 0.72, 0.90),
    visibilityM: 20000,
  ),
  'rain': WeatherLook(
    zenith: (0.24, 0.27, 0.31),
    horizon: (0.46, 0.49, 0.52),
    below: (0.20, 0.22, 0.24),
    sun: (0, 0, 0),
    haze: (0.46, 0.49, 0.52),
    visibilityM: 4000,
  ),
  'fog': WeatherLook(
    zenith: (0.60, 0.62, 0.64),
    horizon: (0.70, 0.71, 0.72),
    below: (0.62, 0.63, 0.64),
    sun: (0, 0, 0),
    haze: (0.70, 0.71, 0.72),
    visibilityM: 1500,
  ),
  'snow': WeatherLook(
    zenith: (0.58, 0.62, 0.68),
    horizon: (0.82, 0.84, 0.88),
    below: (0.62, 0.64, 0.68),
    sun: (0, 0, 0),
    haze: (0.82, 0.84, 0.88),
    visibilityM: 3000,
  ),
};

/// The look of [weather], a key of `terrain.yaml` `weather`; clear for none
/// yet (the host's view has not come) and for one the app does not know.
WeatherLook weatherLookOf(String? weather) =>
    weatherLooks[weather] ?? weatherLooks['clear']!;

/// [color] as a vector.
Vector3 vectorOf((double, double, double) color) =>
    Vector3(color.$1, color.$2, color.$3);
