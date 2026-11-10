import 'dart:math' as math;
import 'dart:ui';

import 'package:battle_team/battle/world/top_down_camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  const size = Size(800, 600);

  group(TopDownCamera, () {
    late TopDownCamera camera;

    setUp(() => camera = TopDownCamera(target: Vector3(500, 0, -500)));

    test('looks north from the south, from above', () {
      final eye = camera.position;

      expect(eye.y, greaterThan(0));
      expect(eye.z, lessThan(-500));
      expect(eye.x, closeTo(500, 1e-3));
      expect((eye - camera.target).length, closeTo(400, 1e-3));
    });

    test('pans with the finger: a drag left shows more of the east', () {
      camera.pan(const Offset(-100, 0), size);

      expect(camera.target.x, greaterThan(500));
      expect(camera.target.z, closeTo(-500, 1e-3));

      camera.pan(const Offset(0, 100), size);
      expect(camera.target.z, greaterThan(-500));
    });

    test('zooms within its bounds', () {
      camera.zoom(2);
      expect(camera.distance, 200);
      camera.zoom(1000);
      expect(camera.distance, camera.minDistance);
      camera.zoom(0.0001);
      expect(camera.distance, camera.maxDistance);
    });

    test('turns, and the ground directions follow', () {
      camera.turn(math.pi / 2);

      expect(camera.ahead.x, closeTo(1, 1e-6));
      expect(camera.right.z, closeTo(-1, 1e-6));
    });
  });

  group(ViewProjection, () {
    test('puts the target in the middle of the screen, east on the right', () {
      final camera = TopDownCamera(target: Vector3(500, 0, -500));
      final view = camera.view(size);

      final middle = view.project(camera.target)!;
      expect(middle.dx, closeTo(400, 1e-3));
      expect(middle.dy, closeTo(300, 1e-3));
      expect(view.project(Vector3(600, 0, -500))!.dx, greaterThan(400));
      expect(view.project(camera.position - camera.forward), isNull);
    });

    test('sends a ray through the screen point that projects back there', () {
      final camera = TopDownCamera(target: Vector3(500, 0, -500), heading: 1);
      final view = camera.view(size);
      const tap = Offset(120, 450);

      final point = view.position + view.directionAt(tap) * 300;

      final back = view.project(point)!;
      expect(back.dx, closeTo(tap.dx, 1e-3));
      expect(back.dy, closeTo(tap.dy, 1e-3));
    });

    test('looks straight ahead in an empty view', () {
      final camera = TopDownCamera(target: Vector3.zero());
      final view = camera.view(Size.zero);

      expect(view.directionAt(Offset.zero), view.forward);
      expect(view.project(camera.target), isNotNull);
    });
  });
}
