import 'package:battle_team/battle/world/team_colours.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

/// The contrast ratio of two linear colours (WCAG).
double _contrast(Vector4 a, Vector4 b) {
  final la = luminanceOf(a) + 0.05;
  final lb = luminanceOf(b) + 0.05;
  return la > lb ? la / lb : lb / la;
}

void main() {
  group('teamIndex', () {
    test('reads the number the id ends with, from 1', () {
      expect(teamIndex('team-1'), 0);
      expect(teamIndex('team-3'), 2);
      expect(teamIndex('team-5'), 4);
    });

    test('has no place for a team past the palette', () {
      expect(teamIndex('team-6'), isNull);
      expect(teamIndex('team-0'), isNull);
      expect(teamIndex('team-12'), isNull);
    });

    test('has none for an id without a number, or for no team', () {
      expect(teamIndex('blue'), isNull);
      expect(teamIndex('team-2-section'), isNull);
      expect(teamIndex(null), isNull);
    });
  });

  group('teamColor', () {
    test('is the palette in linear RGB, in team order', () {
      final blue = teamColor('team-1');
      expect(blue.x, 0);
      expect(blue.y, closeTo(0.168, 0.001));
      expect(blue.z, closeTo(0.445, 0.001));
      expect(blue.w, 1);
      expect(teamColor('team-5').x, closeTo(0.0056, 0.0001));
      for (final (index, argb) in teamPalette.indexed) {
        expect(teamColor('team-${index + 1}'), srgbToLinear(argb));
      }
    });

    test('is white for a relic nobody owns', () {
      expect(teamColor(null), Vector4(1, 1, 1, 1));
    });

    test('is a grey for a team the palette has no place for', () {
      expect(teamColor('blue'), srgbToLinear(otherTeamColor));
      expect(teamColor('team-6'), srgbToLinear(otherTeamColor));
    });

    test('gives five colours that differ from each other and from white', () {
      final colours = [
        for (var team = 1; team <= 5; team++) teamColor('team-$team'),
        teamColor(null),
      ];
      for (final (i, a) in colours.indexed) {
        for (final b in colours.skip(i + 1)) {
          expect((a - b).length, greaterThan(0.1));
        }
      }
    });
  });

  group('srgbToLinear', () {
    test('keeps black and white, and reads the alpha', () {
      expect(srgbToLinear(0xFFFFFFFF), Vector4(1, 1, 1, 1));
      expect(srgbToLinear(0xFF000000), Vector4(0, 0, 0, 1));
      expect(srgbToLinear(0x00FFFFFF).w, 0);
    });

    test('darkens the middle: sRGB 50 % is about 21 % of the light', () {
      expect(srgbToLinear(0xFF808080).x, closeTo(0.216, 0.001));
    });

    test('is linear in the darkest range', () {
      expect(srgbToLinear(0xFF0A0A0A).x, closeTo(10 / 255 / 12.92, 1e-6));
    });
  });

  group('rimColor', () {
    final white = Vector4(1, 1, 1, 1);
    final black = Vector4(0, 0, 0, 1);

    test('is white around the dark colours and black around the light', () {
      expect(rimColor(teamColor('team-1')), white); // blue
      expect(rimColor(teamColor('team-2')), black); // yellow
      expect(rimColor(teamColor('team-3')), black); // vermillion
      expect(rimColor(teamColor('team-4')), black); // sky blue
      expect(rimColor(teamColor('team-5')), white); // black
      expect(rimColor(teamColor(null)), black); // white
    });

    test('always contrasts at least 4.5 to 1 with the colour it outlines', () {
      for (final team in [null, 'team-1', 'team-2', 'team-3', 'team-4']) {
        final colour = teamColor(team);
        expect(_contrast(colour, rimColor(colour)), greaterThan(4.5));
      }
      final other = teamColor('team-5');
      expect(_contrast(other, rimColor(other)), greaterThan(4.5));
      expect(
        _contrast(teamColor('x'), rimColor(teamColor('x'))),
        greaterThan(4.5),
      );
    });
  });

  group('mixedWithWhite', () {
    final team = Vector4(0.2, 0.4, 0.6, 1);

    test('is white for none of the team and the team for all of it', () {
      expect(mixedWithWhite(team, 0), Vector4(1, 1, 1, 1));
      expect(mixedWithWhite(team, 1), team);
    });

    test('goes from white to the team', () {
      final half = mixedWithWhite(team, 0.5);
      expect(half.x, closeTo(0.6, 1e-6));
      expect(half.y, closeTo(0.7, 1e-6));
      expect(half.z, closeTo(0.8, 1e-6));
    });

    test('is opaque whatever the alpha of the team', () {
      expect(mixedWithWhite(Vector4(0, 0, 0, 0.3), 0.75).w, 1);
    });

    test('leaves a black team lighter than black, so its texture shows', () {
      final black = mixedWithWhite(teamColor('team-5'), nearTintMix);
      expect(luminanceOf(black), greaterThan(0.2));
    });
  });
}
