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
}
