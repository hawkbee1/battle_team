import 'dart:io';
import 'dart:math' as math;

import 'package:battle_rules/battle_rules.dart';
import 'package:battle_team/battle/world/weather_look.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('weatherLookOf', () {
    test('has a look for every weather of terrain.yaml', () {
      final terrain = TerrainData.parse(
        File('plan/data/terrain.yaml').readAsStringSync(),
      );
      final weathers = terrain.weather.keys;

      expect(weatherLooks.keys.toSet(), weathers.toSet());
    });

    test('is clear for none yet and for a weather the app does not know', () {
      expect(weatherLookOf(null), same(weatherLooks['clear']));
      expect(weatherLookOf('hail'), same(weatherLooks['clear']));
      expect(weatherLookOf('fog'), same(weatherLooks['fog']));
    });

    test('the sun shows only when the sky is clear', () {
      for (final MapEntry(key: weather, value: look) in weatherLooks.entries) {
        final (red, green, blue) = look.sun;
        expect(red + green + blue > 0, weather == 'clear', reason: weather);
      }
    });

    test('the far ground fades into the horizon, sooner the thicker the '
        'weather', () {
      for (final look in weatherLooks.values) {
        expect(look.haze, look.horizon);
      }
      final clear = weatherLooks['clear']!.visibilityM;
      expect(weatherLooks['rain']!.visibilityM, lessThan(clear));
      expect(weatherLooks['snow']!.visibilityM, lessThan(clear));
      expect(
        weatherLooks['fog']!.visibilityM,
        lessThan(weatherLooks['snow']!.visibilityM),
      );
    });

    test('the haze leaves 2 % of the contrast at the visibility', () {
      final look = weatherLooks['rain']!;

      expect(
        math.exp(-look.hazeDensity * look.visibilityM),
        closeTo(0.02, 1e-4),
      );
    });

    test('a colour as a vector', () {
      expect(vectorOf((0.1, 0.2, 0.3)), Vector3(0.1, 0.2, 0.3));
    });
  });
}
