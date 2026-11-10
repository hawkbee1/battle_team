import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/shots/shot_effect.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_host.dart';
import '../../helpers/real_cubit.dart';

/// Plays [host] to the end through the real cubit, and gives what the cubit
/// announced to draw, update by update.
Future<List<List<ShotEffect>>> play(FakeHost host) async {
  final cubit = realCubit(host);
  addTearDown(cubit.close);
  final announced = <List<ShotEffect>>[];
  final subscription = cubit.shots.listen(announced.add);
  addTearDown(subscription.cancel);
  await cubit.start();
  await pumpEventQueue(times: 500);
  return announced;
}

void main() {
  group('the shots the cubit announces', () {
    test('M7.5 draws the seen shots of a recorded stream', () async {
      final host = FakeHost.recorded('clear_s-1');

      final announced = await play(host);

      final effects = announced.expand((list) => list).toList();
      // Three single shots that hit and two shots of unknown outcome.
      expect(effects.whereType<Tracer>(), isNotEmpty);
      expect(effects.whereType<HitMark>(), isNotEmpty);
      expect(effects.whereType<MuzzleFlash>(), isNotEmpty);
      expect(announced, everyElement(isNotEmpty));
    });

    test(
      'COMBAT-57 / decision 234 an unseen hit shows the hit on the unit seen, '
      'not the shooter',
      () async {
        final recorded = FakeHost.recorded('clear_s-1');
        // A hit by a shooter the section does not see, on one of its units, as
        // the host sends it. No recording holds one, so it is written by hand.
        final own = recorded.view.units.firstWhere((u) => u.private != null);
        final host = FakeHost(
          view: recorded.view,
          updates: [
            TickUpdate(
              at: recorded.view.at + const Duration(minutes: 5),
              unseenHits: [
                UnseenHit(
                  targetId: own.unitId,
                  damage: 7,
                  result: ImpactResult.damaged,
                ),
              ],
            ),
          ],
          accountId: recorded.accountId,
          sectionId: recorded.sectionId,
          team: recorded.team,
        );

        final announced = await play(host);

        // Exactly one effect: the hit mark where the unit stands. It holds no
        // shooter, no direction and no flash.
        expect(announced, [
          [HitMark(at: own.position!, result: ImpactResult.damaged)],
        ]);
      },
    );

    test(
      'COMBAT-58 / decision 237 a shot at an unseen target shows the shooter '
      'firing, outcome unknown',
      () async {
        final recorded = FakeHost.recorded('clear_s-1');
        // A unit the section sees fires, and the section does not see at what.
        final seen = recorded.view.units.firstWhere((u) => u.position != null);
        final host = FakeHost(
          view: recorded.view,
          updates: [
            TickUpdate(
              at: recorded.view.at + const Duration(minutes: 5),
              fired: [
                Fired(
                  attackerId: seen.unitId,
                  sectionId: seen.sectionId,
                  weapon: 'rifle',
                  shots: 3,
                ),
              ],
            ),
          ],
          accountId: recorded.accountId,
          sectionId: recorded.sectionId,
          team: recorded.team,
        );

        final announced = await play(host);

        // The shooter firing, and nothing else: no tracer, no hit, no target.
        expect(announced, [
          [MuzzleFlash(at: seen.position!, weapon: 'rifle')],
        ]);
      },
    );

    test('M7.5 announces nothing for an update with no shot', () async {
      final announced = await play(
        FakeHost(
          updates: const [
            TickUpdate(
              at: Duration(hours: 1, seconds: 5),
              moved: [UnitPosition('r-1', Position(50500, 21000, 3000))],
            ),
          ],
        ),
      );

      expect(announced, isEmpty);
    });
  });
}
