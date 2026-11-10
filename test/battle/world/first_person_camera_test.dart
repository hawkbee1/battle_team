import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:battle_rules/battle_rules.dart';
import 'package:battle_team/battle/data/unit_bodies.dart';
import 'package:battle_team/battle/world/battle_camera.dart';
import 'package:battle_team/battle/world/first_person_camera.dart';
import 'package:battle_team/battle/world/top_down_camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  const size = Size(800, 600);

  group(FirstPersonCamera, () {
    late UnitsData units;

    setUpAll(() {
      // The plan's own file, the one the app bundles.
      units = UnitsData.parse(File(unitsAsset).readAsStringSync());
    });

    FirstPersonCamera camera({double yaw = 0, double pitch = 0}) =>
        FirstPersonCamera(
          unitId: 'u-1',
          eyeHeightM: 1.8,
          feet: Vector3(120, 4, -300),
          yaw: yaw,
          pitch: pitch,
        );

    test('decision 235 the eye sits at the top of the unit hit box, for '
        'every unit type of the real data', () {
      final bodies = UnitBodies.fromUnits(units);
      expect(units.unitTypes, isNotEmpty);

      for (final MapEntry(key: id, value: type) in units.unitTypes.entries) {
        final eyes = FirstPersonCamera(
          unitId: 'u-1',
          eyeHeightM: bodies.eyeHeightOf(id)!,
          feet: Vector3(120, 4, -300),
        );

        expect(type.hitBox.height, greaterThan(0), reason: id);
        expect(
          eyes.position.y,
          closeTo(4 + type.hitBox.height, 1e-5),
          reason: id,
        );
        expect(eyes.position.x, 120, reason: id);
        expect(eyes.position.z, -300, reason: id);
      }
    });

    test('decision 5 looks north, level, with its first angles', () {
      final eyes = camera();

      expect(eyes.forward.x, closeTo(0, 1e-9));
      expect(eyes.forward.y, closeTo(0, 1e-9));
      expect(eyes.forward.z, closeTo(1, 1e-9));
      expect(eyes.insideUnit, 'u-1');
      expect(eyes.fovY, FirstPersonLook.fovY);
      expect(eyes.near, FirstPersonLook.near);
    });

    test('decision 5 a quarter turn looks east, a raised pitch looks up', () {
      final east = camera(yaw: math.pi / 2);
      expect(east.forward.x, closeTo(1, 1e-9));
      expect(east.forward.z, closeTo(0, 1e-9));

      final up = camera(pitch: math.pi / 4);
      expect(up.forward.y, closeTo(math.sqrt1_2, 1e-6));
      expect(up.forward.z, closeTo(math.sqrt1_2, 1e-6));
    });

    test('decision 5 a drag looks around: right turns east, up looks up', () {
      final eyes = camera()..look(const Offset(100, -40));

      expect(eyes.yaw, closeTo(100 * FirstPersonLook.radiansPerPixel, 1e-12));
      expect(eyes.pitch, closeTo(40 * FirstPersonLook.radiansPerPixel, 1e-12));
      expect(eyes.forward.x, greaterThan(0));
      expect(eyes.forward.y, greaterThan(0));

      eyes.look(const Offset(-100, 80));
      expect(eyes.yaw, closeTo(0, 1e-9));
      expect(eyes.pitch, closeTo(-40 * FirstPersonLook.radiansPerPixel, 1e-12));
    });

    test('decision 5 never looks straight up or down', () {
      final eyes = camera()
        ..look(const Offset(0, -100000))
        ..turn(0);
      expect(eyes.pitch, FirstPersonLook.maxPitch);
      expect(eyes.forward.y, lessThan(1));

      eyes.look(const Offset(0, 100000));
      expect(eyes.pitch, -FirstPersonLook.maxPitch);

      expect(camera(pitch: 4).pitch, FirstPersonLook.maxPitch);
      expect(camera(pitch: -4).pitch, -FirstPersonLook.maxPitch);
    });

    test('decision 5 turning back and forth does not drift', () {
      final eyes = camera(yaw: 0.3, pitch: 0.2);
      for (var i = 0; i < 10000; i++) {
        eyes
          ..look(const Offset(7, 3))
          ..look(const Offset(-7, -3));
      }

      expect(eyes.yaw, closeTo(0.3, 1e-9));
      expect(eyes.pitch, closeTo(0.2, 1e-9));
      expect(eyes.forward.length, closeTo(1, 1e-6));
    });

    test('decision 5 keeps its yaw within one turn', () {
      final eyes = camera()..turn(5 * math.pi);

      expect(eyes.yaw, closeTo(math.pi, 1e-9));
      eyes.turn(-2 * math.pi);
      expect(eyes.yaw, closeTo(math.pi, 1e-9));
      expect(eyes.yaw, inInclusiveRange(0, 2 * math.pi));
      expect(camera(yaw: -math.pi / 2).yaw, closeTo(3 * math.pi / 2, 1e-9));
    });

    test('decision 5 follows the unit and keeps its own copy of the spot', () {
      final feet = Vector3(10, 2, -30);
      final eyes = FirstPersonCamera(
        unitId: 'u-1',
        eyeHeightM: 1.8,
        feet: feet,
      );

      feet.x = 99;
      expect(eyes.position.x, 10);

      final drawn = Vector3(40, 3, -60);
      eyes.standAt(drawn);
      drawn.x = 99;

      expect(eyes.position.x, 40);
      expect(eyes.position.y, closeTo(4.8, 1e-5));
      expect(eyes.position.z, -60);
    });

    test('decision 5 projects what is ahead to the middle of the screen', () {
      final eyes = camera();
      final view = eyes.view(size);

      final ahead = view.project(eyes.position + Vector3(0, 0, 50))!;
      expect(ahead.dx, closeTo(400, 1e-6));
      expect(ahead.dy, closeTo(300, 1e-6));
      // East is on the right, the ground below the horizon.
      expect(
        view.project(eyes.position + Vector3(10, 0, 50))!.dx,
        greaterThan(400),
      );
      expect(
        view.project(Vector3(eyes.position.x, 4, eyes.position.z + 50))!.dy,
        greaterThan(300),
      );
      // Behind the eyes is nowhere.
      expect(view.project(eyes.position + Vector3(0, 0, -50)), isNull);
    });
  });

  group(BattleCamera, () {
    test('M7.4 the top-down camera is outside every unit', () {
      final camera = TopDownCamera(target: Vector3(500, 0, -500));

      expect(camera.insideUnit, isNull);
      expect(camera.near, 1);
      expect(camera.forward.length, closeTo(1, 1e-6));
      final middle = camera.view(size).project(camera.target)!;
      expect(middle.dx, closeTo(400, 1e-3));
      expect(middle.dy, closeTo(300, 1e-3));
    });
  });
}
