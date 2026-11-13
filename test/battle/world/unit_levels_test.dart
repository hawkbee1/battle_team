import 'dart:math' as math;

import 'package:battle_team/battle/world/unit_levels.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('unitLevelAt', () {
    test('is near within the limit and far beyond', () {
      expect(unitLevelAt(100, now: null, nearM: 100), UnitLevel.near);
      expect(unitLevelAt(101, now: null, nearM: 100), UnitLevel.far);
      expect(unitLevelAt(101, now: .far, nearM: 100), UnitLevel.far);
    });

    test('a near unit stays near until past the margin', () {
      expect(unitLevelAt(120, now: .near, nearM: 100), UnitLevel.near);
      expect(unitLevelAt(126, now: .near, nearM: 100), UnitLevel.far);
    });
  });

  group('InstanceSlots', () {
    test('gives each key the next index', () {
      final slots = InstanceSlots<String>();
      expect(slots.add('a'), 0);
      expect(slots.add('b'), 1);
      expect(slots.length, 2);
      expect(slots.indexOf('b'), 1);
      expect(slots.indexOf('c'), isNull);
      expect(slots.keyAt(0), 'a');
    });

    test('the last takes the index of the one removed', () {
      final slots = InstanceSlots<String>()
        ..add('a')
        ..add('b')
        ..add('c');
      expect(slots.remove('a'), (index: 0, last: 2));
      expect(slots.length, 2);
      expect(slots.indexOf('a'), isNull);
      expect(slots.indexOf('c'), 0);
      expect(slots.keyAt(0), 'c');
      expect(slots.indexOf('b'), 1);
    });

    test('removing the last moves nothing', () {
      final slots = InstanceSlots<String>()
        ..add('a')
        ..add('b');
      expect(slots.remove('b'), (index: 1, last: 1));
      expect(slots.indexOf('a'), 0);
      expect(slots.remove('a'), (index: 0, last: 0));
      expect(slots.length, 0);
    });

    test('removing a key without an instance gives null', () {
      expect((InstanceSlots<String>()..add('a')).remove('b'), isNull);
    });

    test('a key removed can be added again', () {
      final slots = InstanceSlots<String>()
        ..add('a')
        ..add('b')
        ..remove('a');
      expect(slots.add('a'), 1);
      expect(slots.indexOf('b'), 0);
    });
  });

  group('headingYaw', () {
    // As `UnitInstances` places a unit: vector_math's matrix of a
    // quaternion, which turns the other way from `Quaternion.rotated`.
    Vector3 turned(double yaw) => Matrix4.compose(
      Vector3.zero(),
      Quaternion.axisAngle(Vector3(0, 1, 0), yaw),
      Vector3.all(1),
    ).transformed3(Vector3(0, 0, 1));

    test('turns +Z towards where the unit goes', () {
      for (final to in [
        Vector3(0, 0, 5),
        Vector3(5, 0, 0),
        Vector3(-3, 0, -4),
        Vector3(2, 7, -2),
      ]) {
        final yaw = headingYaw(Vector3.zero(), to, otherwise: 9);
        final flat = Vector3(to.x, 0, to.z).normalized();
        expect(turned(yaw).distanceTo(flat), closeTo(0, 1e-6));
      }
    });

    test('keeps the way it faced when it does not move', () {
      expect(
        headingYaw(Vector3(1, 0, 1), Vector3(1, 4, 1.01), otherwise: 0.7),
        0.7,
      );
    });
  });

  group('lookedAt', () {
    test('is where the look meets the ground', () {
      final at = lookedAt(
        Vector3(10, 110, 20),
        Vector3(0, -1, 1).normalized(),
        groundY: 10,
      );
      expect(at.distanceTo(Vector3(10, 10, 120)), closeTo(0, 1e-9));
    });

    test('straight down is under the eye', () {
      final at = lookedAt(Vector3(10, 700, 20), Vector3(0, -1, 0), groundY: 0);
      expect(at, Vector3(10, 0, 20));
    });

    test('is no further than the limit, also for a level look', () {
      final shallow = lookedAt(
        Vector3(0, 2, 0),
        Vector3(1, -0.001, 0).normalized(),
        groundY: 0,
      );
      expect(shallow.distanceTo(Vector3(150, 0, 0)), closeTo(0, 1e-6));
      final up = lookedAt(
        Vector3(0, 2, 0),
        Vector3(0, 0.5, -1).normalized(),
        groundY: 0,
        maxM: 40,
      );
      expect(up.distanceTo(Vector3(0, 0, -40)), closeTo(0, 1e-6));
    });
  });

  group('crowdUnitAt', () {
    final crowd = [for (var i = 0; i < 1000; i++) crowdUnitAt(i)];

    test('is a tank one time in five', () {
      expect(crowd.where((unit) => unit.tank), hasLength(200));
      expect(crowd.first.tank, isFalse);
      expect(crowd[4].tank, isTrue);
    });

    test('has soldiers and tanks of each of the five teams', () {
      for (final tank in [false, true]) {
        final teams = {
          for (final unit in crowd.where((unit) => unit.tank == tank))
            unit.team,
        };
        expect(teams, {0, 1, 2, 3, 4});
      }
    });

    test('never gives a unit the team of its neighbours on the grid', () {
      // crowdAt lays a thousand units out 32 wide.
      for (var i = 0; i < 999; i++) {
        expect(crowd[i].team, isNot(crowd[i + 1].team), reason: 'next to $i');
        if (i + 32 < 1000) {
          expect(crowd[i].team, isNot(crowd[i + 32].team), reason: 'below $i');
        }
      }
    });

    test('keeps within the teams asked for', () {
      for (var i = 0; i < 100; i++) {
        expect(crowdUnitAt(i, teams: 2).team, lessThan(2));
      }
    });
  });

  group('crowdAt', () {
    test('standing, the crowd is a grid around its middle', () {
      final spots = [
        for (var i = 0; i < 1000; i++) crowdAt(i, 1000, 0, speed: 0),
      ];
      expect({for (final spot in spots) (spot.east, spot.north)}.length, 1000);
      final easts = spots.map((spot) => spot.east);
      final norths = spots.map((spot) => spot.north);
      // 32 units a side, 8 m apart.
      expect(easts.reduce(math.min), -124);
      expect(easts.reduce(math.max), 124);
      expect(norths.reduce(math.min), -124);
      expect(norths.reduce(math.max), lessThanOrEqualTo(124));
    });

    test('a unit walks its circle, facing where it goes', () {
      final place = crowdAt(7, 100, 0, speed: 0);
      const step = 0.01;
      for (final seconds in [0.0, 1.3, 20.0]) {
        final now = crowdAt(7, 100, seconds);
        final next = crowdAt(7, 100, seconds + step);
        expect(
          math.sqrt(
            math.pow(now.east - place.east, 2) +
                math.pow(now.north - place.north, 2),
          ),
          closeTo(3, 1e-9),
        );
        final walked = headingYaw(
          Vector3(now.east, 0, now.north),
          Vector3(next.east, 0, next.north),
          otherwise: 9,
          still: 0,
        );
        final turn = (walked - now.yaw + math.pi) % (2 * math.pi) - math.pi;
        expect(turn.abs(), lessThan(0.01));
        // 1.5 m/s.
        expect(
          math.sqrt(
            math.pow(next.east - now.east, 2) +
                math.pow(next.north - now.north, 2),
          ),
          closeTo(1.5 * step, 1e-4),
        );
      }
    });
  });
}
