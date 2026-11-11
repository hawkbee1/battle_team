import 'package:battle_team/fog/model/fog_model.dart';
import 'package:flutter_test/flutter_test.dart';

FogModel _dark() => FogModel.dark(width: 4, depth: 3, cellSizeM: 10);

void main() {
  group(FogModel, () {
    test('MAP-33 every cell is never seen until a unit sees it', () {
      final fog = _dark();

      for (var y = 0; y < 3; y++) {
        for (var x = 0; x < 4; x++) {
          expect(fog.levelOf(x, y), FogLevel.never);
          expect(fog.isLit(x, y), isFalse);
          expect(fog.wasSeen(x, y), isFalse);
        }
      }
      expect(fog.litCount, 0);
    });

    test('MAP-27 the cells in sight now are lit', () {
      final fog = _dark().lighting([0, 5, 11]);

      expect(fog.isLit(0, 0), isTrue);
      expect(fog.isLit(1, 1), isTrue);
      expect(fog.isLit(3, 2), isTrue);
      expect(fog.isLit(2, 0), isFalse);
      expect(fog.litCount, 3);
    });

    test('MAP-33 a cell seen once and out of sight differs from one never '
        'seen, and stays so', () {
      final once = _dark().lighting([5]);
      final later = once.lighting([0]).lighting([]);

      expect(once.levelOf(1, 1), FogLevel.lit);
      expect(later.levelOf(1, 1), FogLevel.seen);
      expect(later.levelOf(0, 0), FogLevel.seen);
      expect(later.levelOf(2, 2), FogLevel.never);
      expect(later.wasSeen(1, 1), isTrue);
      expect(later.isLit(1, 1), isFalse);
      expect(later.litCount, 0);
    });

    test('MAP-33 a cell seen again is lit again', () {
      final fog = _dark().lighting([5]).lighting([]).lighting([5]);

      expect(fog.levelOf(1, 1), FogLevel.lit);
    });

    test('a model is immutable: lighting makes another', () {
      final fog = _dark();
      final next = fog.lighting([5]);

      expect(fog.litCount, 0);
      expect(next.litCount, 1);
      expect(next, isNot(equals(fog)));
      expect(next, equals(_dark().lighting([5])));
    });

    test(
      'a cell off the map is never seen, and lighting it changes nothing',
      () {
        final fog = _dark().lighting([-1, 99, 5]);

        expect(fog.levelOf(-1, 0), FogLevel.never);
        expect(fog.levelOf(0, -1), FogLevel.never);
        expect(fog.levelOf(4, 0), FogLevel.never);
        expect(fog.levelOf(0, 3), FogLevel.never);
        expect(fog.litCount, 1);
      },
    );

    test('MAP-27 a position in metres is in the cell it falls in', () {
      final fog = _dark().lighting([5]);

      expect(fog.levelAt(15, 15), FogLevel.lit);
      expect(fog.levelAt(9.9, 0), FogLevel.never);
      expect(fog.levelAt(-1, 5), FogLevel.never);
    });

    test('the levels are a view that cannot be changed', () {
      final fog = _dark().lighting([5]);

      expect(fog.levels, hasLength(12));
      expect(fog.levels[5], FogLevel.lit.index);
      expect(() => fog.levels[0] = 2, throwsUnsupportedError);
    });
  });
}
