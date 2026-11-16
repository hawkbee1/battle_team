import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/sounds/sound_cue.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_host.dart';
import '../../helpers/real_cubit.dart';

/// Plays [host] to the end through the real cubit, and gives what the cubit
/// announced to play, update by update.
Future<List<List<SoundCue>>> play(FakeHost host) async {
  final cubit = realCubit(host);
  addTearDown(cubit.close);
  final announced = <List<SoundCue>>[];
  final subscription = cubit.sounds.listen(announced.add);
  addTearDown(subscription.cancel);
  cubit.start();
  await pumpEventQueue(times: 500);
  return announced;
}

void main() {
  group('the sounds the cubit announces', () {
    test('M7.14 plays the seen shots of a recorded stream', () async {
      final announced = await play(FakeHost.recorded('clear_s-1'));

      final cues = announced.expand((list) => list).toList();
      expect(cues.map((cue) => cue.sound), contains(Sound.shot));
      expect(cues.map((cue) => cue.sound), contains(Sound.injury));
      expect(announced, everyElement(isNotEmpty));
    });

    test(
      'M7.14 announces nothing for an update with nothing to hear',
      () async {
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
      },
    );

    test('M7.14 a unit that sets off is heard, and the end of the battle is '
        "a victory for the player's team", () async {
      final recorded = FakeHost.recorded('clear_s-1');
      final own = recorded.view.units.firstWhere((u) => u.private != null);
      final host = FakeHost(
        view: recorded.view,
        updates: [
          TickUpdate(
            at: recorded.view.at + const Duration(minutes: 5),
            events: [
              MoveStarted(
                moverId: own.unitId,
                arrivesAt: recorded.view.at + const Duration(minutes: 9),
              ),
            ],
          ),
          TickUpdate(
            at: recorded.view.at + const Duration(minutes: 6),
            events: [
              BattleEnded(
                winner: recorded.team,
                kind: WinKind.relics,
                eliminated: const [],
              ),
            ],
          ),
        ],
        accountId: recorded.accountId,
        sectionId: recorded.sectionId,
        team: recorded.team,
      );

      final announced = await play(host);

      expect(announced, [
        [SoundCue(Sound.move, at: own.position, subject: own.unitType)],
        [const SoundCue(Sound.victory)],
      ]);
    });
  });
}
