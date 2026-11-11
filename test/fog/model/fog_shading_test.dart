import 'dart:typed_data';

import 'package:battle_team/fog/model/fog_model.dart';
import 'package:battle_team/fog/model/fog_shading.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 3 × 1 ground of one colour.
Float32List _ground() => Float32List.fromList([
  0.5, 0.6, 0.4, 1, //
  0.5, 0.6, 0.4, 1,
  0.5, 0.6, 0.4, 1,
]);

void main() {
  group('fogShadedColors', () {
    test('MAP-33 a cell in sight keeps its colour, one seen once is dimmed '
        'and one never seen is darker still', () {
      // Cell 0 lit now, cell 1 seen once, cell 2 never seen.
      final fog = FogModel.dark(
        width: 3,
        depth: 1,
        cellSizeM: 10,
      ).lighting([1]).lighting([0]);

      final shaded = fogShadedColors(_ground(), fog);

      expect(shaded.sublist(0, 4), _ground().sublist(0, 4));
      for (var channel = 0; channel < 3; channel++) {
        final lit = shaded[channel];
        final seen = shaded[4 + channel];
        final never = shaded[8 + channel];
        expect(seen, lessThan(lit), reason: 'channel $channel');
        expect(never, lessThan(seen), reason: 'channel $channel');
      }
      expect(shaded[7], 1);
      expect(shaded[11], 1);
    });

    test('MAP-33 the fog fades towards its tint, and the ground it is made '
        'from is not changed', () {
      final fog = FogModel.dark(width: 3, depth: 1, cellSizeM: 10);
      final ground = _ground();

      final shaded = fogShadedColors(ground, fog);

      expect(
        shaded[0],
        closeTo(
          0.5 * FogShade.neverKeeps +
              FogShade.tint.$1 * (1 - FogShade.neverKeeps),
          1e-6,
        ),
      );
      expect(ground, _ground());
    });

    test('a ground that does not fit the fog is refused', () {
      final fog = FogModel.dark(width: 2, depth: 1, cellSizeM: 10);

      expect(() => fogShadedColors(_ground(), fog), throwsArgumentError);
    });
  });
}
