import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/shots/shot_effects.dart';
import 'package:battle_team/battle/sounds/sound_cue.dart';
import 'package:battle_team/battle/sounds/sound_cues.dart';
import 'package:flutter_test/flutter_test.dart';

const _shooterAt = Position(10000, 10000, 0);
const _targetAt = Position(20000, 10000, 0);
const _otherAt = Position(30000, 10000, 0);

UnitView _unit(
  String id,
  Position at, {
  String section = 's-blue',
  String type = 'soldier',
}) => UnitView(
  unitId: id,
  unitType: type,
  sectionId: section,
  team: section == 's-blue' ? 'blue' : 'red',
  hp: 100,
  maxHp: 100,
  position: at,
  weapon: 'rifle',
);

Impact _impact(String target, ImpactResult result) => Impact(
  targetId: target,
  targetType: 'soldier',
  damage: 12,
  friendly: false,
  result: result,
);

Attacked _attack(
  List<Impact> impacts, {
  String weapon = 'rifle',
  String attacker = 'b-1',
}) => Attacked(
  attackerId: attacker,
  sectionId: 's-blue',
  weapon: weapon,
  hit: true,
  impacts: impacts,
);

void main() {
  group(SoundCues, () {
    late HeldView view;
    late ShotEffects effects;

    /// The view takes [message], then the sounds of it for a player of [team].
    List<SoundCue> hear(HostMessage message, {String? team = 'blue'}) {
      view.apply(message);
      return const SoundCues().of(
        message,
        view,
        effects.of(message, view),
        team: team,
      );
    }

    TickUpdate tick({
      List<BattleEvent> events = const [],
      List<Burst> bursts = const [],
      List<Fired> fired = const [],
      List<UnseenHit> unseenHits = const [],
    }) => TickUpdate(
      at: const Duration(hours: 1, seconds: 1),
      events: events,
      bursts: bursts,
      fired: fired,
      unseenHits: unseenHits,
    );

    setUp(() {
      view = HeldView();
      effects = ShotEffects();
      hear(
        SectionView(
          weather: 'clear',
          at: const Duration(hours: 1),
          section: const SectionPrivate(money: 0, xp: 0),
          units: [
            _unit('b-1', _shooterAt),
            _unit('b-2', _otherAt, type: 'tank'),
            _unit('r-1', _targetAt, section: 's-red'),
          ],
          hqs: const [],
          relics: const [],
          world: const [],
        ),
      );
    });

    test('makes no sound for a message that is not an update', () {
      expect(
        hear(
          const RelicAlert(
            at: Duration(hours: 2),
            relicId: 'relic-1',
            team: 'red',
          ),
        ),
        isEmpty,
      );
    });

    test('makes no sound for an update with nothing to hear', () {
      expect(hear(tick()), isEmpty);
    });

    test('a seen shot is a shot of its weapon, where the shooter stands', () {
      final cues = hear(
        tick(
          events: [
            _attack([_impact('r-1', ImpactResult.damaged)]),
          ],
        ),
      );

      expect(cues, const [
        SoundCue(Sound.shot, at: _shooterAt, subject: 'rifle'),
        SoundCue(Sound.injury, at: _targetAt),
      ]);
    });

    test('a hit that kills is a death, not an injury', () {
      final cues = hear(
        tick(
          events: [
            _attack([_impact('r-1', ImpactResult.killed)]),
          ],
        ),
      );

      expect(cues, const [
        SoundCue(Sound.shot, at: _shooterAt, subject: 'rifle'),
        SoundCue(Sound.death, at: _targetAt),
      ]);
    });

    test('a prisoner or a defector is hurt, not dead', () {
      final cues = hear(
        tick(
          events: [
            _attack([
              _impact('r-1', ImpactResult.prisoner),
              _impact('b-2', ImpactResult.defected),
            ]),
          ],
        ),
      );

      expect(cues.map((cue) => cue.sound), [
        Sound.shot,
        Sound.injury,
        Sound.injury,
      ]);
    });

    test('a volley that hits several units sounds once', () {
      final cues = hear(
        tick(
          bursts: [
            Burst(
              attackerId: 'b-1',
              sectionId: 's-blue',
              weapon: 'machine_gun',
              shots: 5,
              hits: 2,
              impacts: [
                _impact('r-1', ImpactResult.damaged),
                _impact('b-2', ImpactResult.damaged),
              ],
            ),
          ],
        ),
      );

      expect(cues.where((cue) => cue.sound == Sound.shot), const [
        SoundCue(Sound.shot, at: _shooterAt, subject: 'machine_gun'),
      ]);
      expect(cues.where((cue) => cue.sound == Sound.injury), hasLength(2));
    });

    test('two shooters make two shots, and one weapon twice makes two', () {
      final cues = hear(
        tick(
          events: [
            _attack([_impact('r-1', ImpactResult.damaged)]),
            _attack([_impact('r-1', ImpactResult.damaged)], attacker: 'b-2'),
            _attack([_impact('r-1', ImpactResult.damaged)], weapon: 'cannon'),
          ],
        ),
      );

      expect(cues.where((cue) => cue.sound == Sound.shot), const [
        SoundCue(Sound.shot, at: _shooterAt, subject: 'rifle'),
        SoundCue(Sound.shot, at: _otherAt, subject: 'rifle'),
        SoundCue(Sound.shot, at: _shooterAt, subject: 'cannon'),
      ]);
    });

    test(
      'COMBAT-58 a shot at an unseen target is the shooter firing, and no more',
      () {
        final cues = hear(
          tick(
            fired: const [
              Fired(
                attackerId: 'b-1',
                sectionId: 's-blue',
                weapon: 'rifle',
                shots: 3,
              ),
            ],
          ),
        );

        expect(cues, const [
          SoundCue(Sound.shot, at: _shooterAt, subject: 'rifle'),
        ]);
      },
    );

    test(
      'COMBAT-57 a hit by an unseen shooter is the injury, with no shot',
      () {
        final cues = hear(
          tick(
            unseenHits: const [
              UnseenHit(
                targetId: 'b-1',
                damage: 7,
                result: ImpactResult.damaged,
              ),
            ],
          ),
        );

        expect(cues, const [SoundCue(Sound.injury, at: _shooterAt)]);
      },
    );

    test('a seen unit that sets off is a move, with its type', () {
      final cues = hear(
        tick(
          events: const [
            MoveStarted(moverId: 'b-2', arrivesAt: Duration(hours: 2)),
            MoveStarted(moverId: 'b-1', arrivesAt: Duration(hours: 2)),
          ],
        ),
      );

      expect(cues, const [
        SoundCue(Sound.move, at: _otherAt, subject: 'tank'),
        SoundCue(Sound.move, at: _shooterAt, subject: 'soldier'),
      ]);
    });

    test('an HQ or a relic that moves, or a unit gone, makes no sound', () {
      final cues = hear(
        tick(
          events: const [
            MoveStarted(moverId: 'hq-red', arrivesAt: Duration(hours: 2)),
            MoveStarted(moverId: 'relic-1', arrivesAt: Duration(hours: 2)),
            MoveStarted(moverId: 'nobody', arrivesAt: Duration(hours: 2)),
          ],
        ),
      );

      expect(cues, isEmpty);
    });

    group('the end of the battle', () {
      const ended = BattleEnded(
        winner: 'blue',
        kind: WinKind.relics,
        eliminated: ['red'],
      );

      test('is a victory for the winner, flat', () {
        expect(hear(tick(events: const [ended])), const [
          SoundCue(Sound.victory),
        ]);
      });

      test('is a defeat for a team that lost it while still in it', () {
        expect(hear(tick(events: const [ended]), team: 'green'), const [
          SoundCue(Sound.defeat),
        ]);
      });

      test('is not heard again by a team eliminated before', () {
        expect(
          hear(
            tick(
              events: const [
                BattleEnded(
                  winner: 'blue',
                  kind: WinKind.relics,
                  eliminated: ['red', 'green'],
                ),
              ],
            ),
            team: 'green',
          ),
          isEmpty,
        );
      });

      test("HQ-18 the elimination of the player's team is a defeat", () {
        expect(
          hear(
            tick(
              events: const [
                Eliminated(team: 'blue', loss: HqLoss.destroyed),
                Eliminated(team: 'red', loss: HqLoss.destroyed),
              ],
            ),
          ),
          const [SoundCue(Sound.defeat)],
        );
      });

      test('is silent before the sign-in has told the team', () {
        expect(hear(tick(events: const [ended]), team: null), isEmpty);
      });
    });
  });
}
