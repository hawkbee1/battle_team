import 'dart:math' as math;

import 'package:battle_team/battle/world/glide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

Matcher near(Vector3 expected) => predicate<Vector3>(
  (v) => (v - expected).length < 1e-9,
  'within 1e-9 of $expected',
);

void main() {
  group('Glide', () {
    test('stands where it was made until told to go', () {
      final glide = Glide(Vector3(1, 2, 3));

      expect(glide.at(0), near(Vector3(1, 2, 3)));
      expect(glide.at(10), near(Vector3(1, 2, 3)));
      expect(glide.to, near(Vector3(1, 2, 3)));
      expect(glide.yawAt(10), 0);
    });

    test('goes along its route at an even speed, and stops at its end', () {
      // 30 m east, then 10 m north (+Z), in 4 s: 10 m a second.
      final glide = Glide(Vector3.zero())
        ..retarget(
          [Vector3.zero(), Vector3(30, 0, 0), Vector3(30, 6, 10)],
          now: 0,
          seconds: 4,
        );

      expect(glide.at(1), near(Vector3(10, 0, 0)));
      expect(glide.at(3), near(Vector3(30, 0, 0)));
      expect(glide.at(3.5), near(Vector3(30, 3, 5)));
      expect(glide.at(4), near(Vector3(30, 6, 10)));
      expect(glide.at(9), near(Vector3(30, 6, 10)));
      expect(glide.to, near(Vector3(30, 6, 10)));
    });

    test("the route's length is counted on the ground, not up a slope", () {
      final glide = Glide(Vector3.zero())
        ..retarget(
          [Vector3.zero(), Vector3(10, 100, 0), Vector3(20, 0, 0)],
          now: 0,
          seconds: 2,
        );

      expect(glide.at(1), near(Vector3(10, 100, 0)));
    });

    test('faces the way of the stretch it is on, and the last one once '
        'arrived', () {
      final glide = Glide(Vector3.zero())
        ..retarget(
          [Vector3.zero(), Vector3(30, 0, 0), Vector3(30, 0, 10)],
          now: 0,
          seconds: 4,
        );

      expect(glide.yawAt(1), closeTo(math.pi / 2, 1e-9));
      expect(glide.yawAt(3.5), closeTo(0, 1e-9));
      expect(glide.yawAt(5), closeTo(0, 1e-9));
    });

    test('a new route starts from where it is drawn, the first point being '
        'where the host had it', () {
      final glide = Glide(Vector3.zero())
        ..retarget([Vector3.zero(), Vector3(40, 0, 0)], now: 0, seconds: 4)
        ..retarget([Vector3(40, 0, 0), Vector3(20, 0, 0)], now: 2, seconds: 1);

      // It was at 20 m: nothing left to go.
      expect(glide.at(2), near(Vector3(20, 0, 0)));
      expect(glide.at(2.5), near(Vector3(20, 0, 0)));
    });

    test('keeps the way it faced on a stretch too short to tell', () {
      final glide = Glide(Vector3.zero())
        ..retarget([Vector3.zero(), Vector3(0, 0, -10)], now: 0, seconds: 1)
        ..retarget(
          [Vector3(0, 0, -10), Vector3(0, 0, -10.01), Vector3(5, 0, -10.01)],
          now: 1,
          seconds: 1,
        );

      expect(glide.yawAt(1.001), closeTo(math.pi, 1e-9));
      expect(glide.yawAt(1.5), closeTo(math.pi / 2, 1e-9));
    });

    test('a first stretch straight up is past at once', () {
      final glide = Glide(Vector3.zero())
        ..retarget(
          [Vector3.zero(), Vector3(0, 5, 0), Vector3(10, 5, 0)],
          now: 0,
          seconds: 1,
        );

      expect(glide.at(0), near(Vector3(0, 5, 0)));
      expect(glide.at(0.5), near(Vector3(5, 5, 0)));
      expect(glide.yawAt(0), 0);
    });

    test('a route that goes nowhere ends at once', () {
      final glide = Glide(Vector3(5, 0, 5))
        ..retarget([Vector3(5, 0, 5), Vector3(5, 3, 5)], now: 0, seconds: 2);

      expect(glide.at(1), near(Vector3(5, 3, 5)));
      expect(glide.yawAt(1), 0);
    });
  });
}
