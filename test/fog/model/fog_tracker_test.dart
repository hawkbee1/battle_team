import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/fog/model/fog_model.dart';
import 'package:battle_team/fog/model/fog_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fog.dart';

/// A row of 10 m cells: `terrain` symbols (`g` grass, `t` tree, `b`
/// building) and the ground `heights`.
String _row(String terrain, {String? heights}) =>
    '''
cell 10
legend g grass
legend t grass tree
legend b grass building
terrain
  ${terrain.split('').join(' ')}
heights
  ${heights ?? List.filled(terrain.length, '0').join(' ')}
''';

/// An own unit of the section on cell ([x], [y]) of 10 m cells.
UnitView _own(
  String id, {
  required int x,
  int y = 0,
  double range = 50,
  String type = 'soldier',
  UnitPlace place = UnitPlace.deployed,
  bool flying = false,
}) => UnitView(
  unitId: id,
  unitType: type,
  sectionId: 's-blue',
  team: 'blue',
  hp: 100,
  maxHp: 100,
  position: place == UnitPlace.stored
      ? null
      : Position.metres(x * 10 + 5, y * 10 + 5, 0),
  flying: flying,
  private: UnitPrivate(
    sightRangeM: range,
    place: place,
    ap: const ApView(value: 30, at: Duration.zero, perHour: 1, max: 30),
    morale: 100,
    rounds: 10,
    xpEarned: 0,
    xpUnspent: 0,
  ),
);

/// A unit of another section: no private state, as the host sends it.
UnitView _other(String id, {required int x, int y = 0}) => UnitView(
  unitId: id,
  unitType: 'soldier',
  sectionId: 's-red',
  team: 'red',
  hp: 100,
  maxHp: 100,
  position: Position.metres(x * 10 + 5, y * 10 + 5, 0),
);

FogModel? _update(
  FogTracker tracker,
  List<UnitView> units, {
  String? weather = 'clear',
  List<BattleEvent> world = const [],
  int version = 0,
}) => tracker.update(
  units: units,
  weather: weather,
  world: world,
  worldVersion: version,
);

/// A hill 30 m high on the fourth cell of a row of 30 cells.
final String _hill = [
  for (var x = 0; x < 30; x++)
    if (x == 3) '30' else '0',
].join(' ');

Set<int> _litColumns(FogModel fog, {int y = 0}) => {
  for (var x = 0; x < fog.width; x++)
    if (fog.isLit(x, y)) x,
};

void main() {
  group(FogTracker, () {
    test('MAP-27 an own unit lights the cells within its sight range', () {
      final tracker = testTracker(sight: testSight(map: _row('gggggggggg')));

      final fog = _update(tracker, [_own('u-1', x: 0)])!;

      expect(_litColumns(fog), {0, 1, 2, 3, 4, 5});
      expect(tracker.model, same(fog));
    });

    test('MAP-26 decision 235 a hill between an own unit and a cell leaves '
        'it dark', () {
      final tracker = testTracker(
        sight: testSight(map: _row('gggggggg', heights: '0 0 0 30 0 0 0 0')),
      );

      final fog = _update(tracker, [_own('u-1', x: 0, range: 100)])!;

      expect(_litColumns(fog), {0, 1, 2, 3});
      expect(fog.levelOf(5, 0), FogLevel.never);
    });

    test('MAP-27 forest the line crosses reduces how far a unit sees', () {
      final open = testTracker(sight: testSight(map: _row('gggggggggg')));
      final wood = testTracker(sight: testSight(map: _row('gtttgggggg')));

      final clear = _update(open, [_own('u-1', x: 0, range: 100)])!;
      final covered = _update(wood, [_own('u-1', x: 0, range: 100)])!;

      expect(_litColumns(clear), hasLength(10));
      expect(_litColumns(covered), {0, 1, 2});
    });

    test('MAP-31 weather shortens the range, and a change of weather is '
        'taken into account', () {
      final tracker = testTracker(sight: testSight(map: _row('gggggggggg')));
      final units = [_own('u-1', x: 0, range: 100)];

      final clear = _update(tracker, units)!;
      final fog = _update(tracker, units, weather: 'fog')!;

      expect(_litColumns(clear), hasLength(10));
      expect(_litColumns(fog), {0, 1, 2, 3, 4});
      expect(fog.levelOf(8, 0), FogLevel.seen);
    });

    test(
      'MAP-27 UNIT-34 a unit whose range grew, observing, lights farther',
      () {
        final tracker = testTracker(sight: testSight(map: _row('gggggggggg')));

        final near = _update(tracker, [_own('u-1', x: 0, range: 30)])!;
        final far = _update(tracker, [_own('u-1', x: 0, range: 60)])!;

        expect(_litColumns(near), {0, 1, 2, 3});
        expect(_litColumns(far), {0, 1, 2, 3, 4, 5, 6});
      },
    );

    test('MAP-33 a cell a unit left behind is seen once, not never seen', () {
      final tracker = testTracker(sight: testSight(map: _row('gggggggggg')));

      _update(tracker, [_own('u-1', x: 0, range: 20)]);
      final moved = _update(tracker, [_own('u-1', x: 7, range: 20)])!;

      expect(moved.levelOf(0, 0), FogLevel.seen);
      expect(moved.levelOf(7, 0), FogLevel.lit);
      expect(moved.levelOf(4, 0), FogLevel.never);
    });

    test('MAP-29 the sights of the units add up, and a unit that '
        'is gone lights nothing any more', () {
      final tracker = testTracker(sight: testSight(map: _row('gggggggggg')));
      final a = _own('u-1', x: 0, range: 10);
      final b = _own('u-2', x: 9, range: 10);

      final both = _update(tracker, [a, b])!;
      final one = _update(tracker, [b])!;

      expect(_litColumns(both), {0, 1, 8, 9});
      expect(_litColumns(one), {8, 9});
      expect(one.levelOf(0, 0), FogLevel.seen);
    });

    test('nothing changes, and nothing is computed again, while no own unit '
        'moves and the range, the weather and the world stay', () {
      final tracker = testTracker(sight: testSight(map: _row('gggggggggg')));
      final units = [_own('u-1', x: 0), _other('r-1', x: 5)];

      expect(_update(tracker, units), isNotNull);
      expect(_update(tracker, units), isNull);
      // An enemy that moves changes nothing of the ground in sight.
      expect(_update(tracker, [units.first, _other('r-1', x: 6)]), isNull);
    });

    test('decision 237 a unit of another section lights nothing, and a unit '
        'in storage lights nothing', () {
      final tracker = testTracker(sight: testSight(map: _row('gggggggggg')));

      final none = _update(tracker, [
        _other('r-1', x: 5),
        _own('u-2', x: 3, place: UnitPlace.stored),
        _own('u-3', x: 3, place: UnitPlace.prisoner),
      ]);

      expect(none, isNull);
      expect(tracker.model.litCount, 0);
    });

    test('decision 237 an enemy that leaves sight leaves no mark', () {
      final tracker = testTracker(sight: testSight(map: _row('gggggggggg')));
      final mine = _own('u-1', x: 0, range: 20);

      final seen = _update(tracker, [mine, _other('r-1', x: 2)])!;
      final gone = _update(tracker, [mine]);

      expect(gone, isNull);
      expect(tracker.model, seen);
      expect(tracker.model.levelOf(9, 0), FogLevel.never);
    });

    test('MAP-33 a carried unit sees from where its transport is', () {
      final tracker = testTracker(sight: testSight(map: _row('gggggggggg')));

      final fog = _update(tracker, [
        _own('u-1', x: 4, range: 10, place: UnitPlace.carried),
      ])!;

      expect(_litColumns(fog), {3, 4, 5});
    });

    test('MAP-06 MAP-28 a wall built stops the sight behind it, and destroyed '
        'it stops blocking', () {
      final tracker = testTracker(sight: testSight(map: _row('gggggggg')));
      final units = [_own('u-1', x: 0, range: 100)];
      const wall = StructureBuilt(
        siteId: 'w-1',
        structure: 'wall',
        cells: [Cell(2, 0)],
      );

      final open = _update(tracker, units)!;
      final built = _update(tracker, units, world: [wall], version: 1)!;
      final destroyed = _update(
        tracker,
        units,
        world: [
          wall,
          const ObjectDestroyed(object: 'wall', cells: [Cell(2, 0)]),
        ],
        version: 2,
      )!;

      expect(_litColumns(open), hasLength(8));
      expect(_litColumns(built), {0, 1, 2});
      expect(_litColumns(destroyed), hasLength(8));
    });

    test('MAP-07 a crater dug within reach is applied on top of the layer: '
        'the hill dug away stops blocking, while a unit that moved sees from '
        'where it is; a crater out of reach changes nothing', () {
      final tracker = testTracker(
        sight: testSight(map: _row('g' * 30, heights: _hill)),
      );
      final hill = CraterDug(
        at: Position.metres(35, 5, 0),
        radiusM: 6,
        depthM: 30,
      );
      // Range 100 m, and up to 150 m more from height: 25 cells.
      final far = CraterDug(
        at: Position.metres(295, 5, 0),
        radiusM: 4,
        depthM: 3,
      );
      final scout = _own('u-1', x: 0, range: 100);

      final blocked = _update(tracker, [scout, _own('u-2', x: 20, range: 10)])!;
      final dug = _update(
        tracker,
        [scout, _own('u-2', x: 22, range: 10)],
        world: [hill],
        version: 1,
      )!;
      final again = _update(
        tracker,
        [scout, _own('u-2', x: 22, range: 10)],
        world: [hill, far],
        version: 2,
      );

      expect(_litColumns(blocked), {0, 1, 2, 3, 19, 20, 21});
      expect(_litColumns(dug), {for (var x = 0; x <= 10; x++) x, 21, 22, 23});
      expect(dug.levelOf(20, 0), FogLevel.seen);
      expect(again, isNull);
      expect(tracker.model, same(dug));
    });

    test('MAP-08 a layer the host sends whole again, after a resync, is '
        'applied anew on the map as built', () {
      final tracker = testTracker(sight: testSight(map: _row('g' * 10)));
      final units = [_own('u-1', x: 0, range: 100)];
      StructureBuilt wall(int x) => StructureBuilt(
        siteId: 'w-$x',
        structure: 'wall',
        cells: [Cell(x, 0)],
      );

      final walled = _update(tracker, units, world: [wall(2)], version: 1)!;
      // The same layer, as a resync sends it: the same events, new.
      final same = _update(tracker, units, world: [wall(2)], version: 2);
      final other = _update(tracker, units, world: [wall(5)], version: 3)!;

      expect(_litColumns(walled), {0, 1, 2});
      expect(same, isNull);
      expect(_litColumns(other), {0, 1, 2, 3, 4, 5});
    });

    test('MAP-29 a cell stays lit while one of the units sees it', () {
      final tracker = testTracker(sight: testSight(map: _row('g' * 20)));
      final a = _own('u-1', x: 0, range: 30);
      final b = _own('u-2', x: 2, range: 30);

      final both = _update(tracker, [a, b])!;
      final left = _update(tracker, [b]);
      final moved = _update(tracker, [_own('u-2', x: 12, range: 30)])!;

      expect(_litColumns(both), {0, 1, 2, 3, 4, 5});
      expect(left, isNull);
      expect(_litColumns(moved), {9, 10, 11, 12, 13, 14, 15});
      expect(moved.levelOf(0, 0), FogLevel.seen);
    });

    test('damage, and a bridge built, change the layer but nothing a sight '
        'line reads: nothing is computed again', () {
      final tracker = testTracker(sight: testSight(map: _row('g' * 10)));
      final units = [_own('u-1', x: 0)];

      _update(tracker, units);

      expect(
        _update(
          tracker,
          units,
          world: [
            const ObjectDamaged(object: 'wall', cells: [Cell(2, 0)], hp: 10),
            const StructureBuilt(
              siteId: 'b-1',
              structure: 'bridge',
              cells: [Cell(3, 0)],
            ),
          ],
          version: 1,
        ),
        isNull,
      );
    });

    test('a unit of a type the data does not know, or off the map, lights '
        'nothing', () {
      final tracker = testTracker(sight: testSight(map: _row('gggggggggg')));

      final none = _update(tracker, [
        _own('u-1', x: 0, type: 'dragon'),
        _own('u-2', x: 50),
      ]);

      expect(none, isNull);
    });

    test('nothing is computed before the whole view of the host brings the '
        'weather', () {
      final tracker = testTracker(sight: testSight(map: _row('gggggggggg')));

      expect(_update(tracker, [_own('u-1', x: 0)], weather: null), isNull);
      expect(tracker.model.litCount, 0);
    });
  });
}
