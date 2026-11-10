import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/shots/shot_effect.dart';
import 'package:battle_team/battle/world/live_shots.dart';
import 'package:flutter_test/flutter_test.dart';

const _tracer = Tracer(
  from: Position(0, 0, 0),
  to: Position(100, 0, 0),
  weapon: 'rifle',
);
const _flash = MuzzleFlash(at: Position(0, 0, 0), weapon: 'rifle');
const _hit = HitMark(at: Position(100, 0, 0), result: ImpactResult.damaged);

void main() {
  group(LiveShots, () {
    late LiveShots shots;

    setUp(() => shots = LiveShots());

    test('M7.5 a shot effect lives for a moment: a tracer, a flash, a hit', () {
      expect(ShotLook.lifeOf(_tracer), ShotLook.tracerS);
      expect(ShotLook.lifeOf(_flash), ShotLook.flashS);
      expect(ShotLook.lifeOf(_hit), ShotLook.hitS);
      expect([
        ShotLook.tracerS,
        ShotLook.flashS,
        ShotLook.hitS,
      ], everyElement(inInclusiveRange(0.05, 1)));
    });

    test('M7.5 puts effects on screen, new and fully visible', () {
      final added = shots.add([_tracer, _hit]);

      expect(added.map((shot) => shot.effect), [_tracer, _hit]);
      expect(shots.live, added);
      expect(added.first.ageS, 0);
      expect(added.first.progress, 0);
      expect(added.first.opacity, 1);
      expect(added.first.expired, isFalse);
    });

    test('M7.5 ages the effects in place and fades them out', () {
      final [tracer, hit] = shots.add([_tracer, _hit]);

      final gone = shots.advance(ShotLook.maxStepS);

      expect(gone, isEmpty);
      expect(shots.live, [tracer, hit]);
      expect(tracer.ageS, ShotLook.maxStepS);
      // Eased out, it swells faster at first than in a straight line ...
      const straight = ShotLook.maxStepS / ShotLook.tracerS;
      expect(tracer.progress, inExclusiveRange(straight, 1));
      // ... and eased in, it stays visible for most of its life.
      expect(tracer.opacity, inExclusiveRange(0.9, 1));
      expect(hit.progress, lessThan(tracer.progress));
    });

    test('M7.5 an effect is gone to the eye at the end of its life', () {
      final [tracer] = shots.add([_tracer]);

      while (!tracer.expired) {
        shots.advance(ShotLook.maxStepS);
      }

      expect(tracer.opacity, 0);
      expect(tracer.progress, 1);
    });

    test('M7.5 takes an effect down when its life is over, and says which', () {
      final [tracer, hit] = shots.add([_tracer, _hit]);

      final gone = <LiveShot>[];
      while (shots.live.contains(tracer)) {
        gone.addAll(shots.advance(ShotLook.maxStepS));
      }

      expect(gone, [tracer]);
      expect(shots.live, [hit]);
      expect(tracer.expired, isTrue);
      expect(tracer.progress, 1);
      expect(tracer.opacity, 0);
    });

    test('M7.5 ends with nothing on screen', () {
      shots.add([_tracer, _flash, _hit]);

      // Frame after frame, as the scene moves on.
      var gone = <LiveShot>[];
      for (var frame = 0; frame < 40; frame++) {
        gone = [...gone, ...shots.advance(1 / 60)];
      }

      expect(gone, hasLength(3));
      expect(shots.live, isEmpty);
    });

    test('M7.5 a frame that hitches does not skip a shot', () {
      final [tracer] = shots.add([_tracer]);

      // A frame of two seconds, on a slow device: it ages the shot by no more
      // than a frame can, so that the shot is drawn at least once.
      final gone = shots.advance(2);

      expect(gone, isEmpty);
      expect(tracer.ageS, ShotLook.maxStepS);
      expect(shots.live, [tracer]);
    });
  });
}
