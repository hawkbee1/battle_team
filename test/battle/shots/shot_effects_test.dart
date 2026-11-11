import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/shots/shot_effect.dart';
import 'package:battle_team/battle/shots/shot_effects.dart';
import 'package:flutter_test/flutter_test.dart';

const _shooterAt = Position(10000, 10000, 0);
const _targetAt = Position(20000, 10000, 0);
const _otherAt = Position(30000, 10000, 0);
const _hqAt = Position(50000, 50000, 0);

UnitView _unit(String id, Position at, {String section = 's-blue'}) => UnitView(
  unitId: id,
  unitType: 'soldier',
  sectionId: section,
  team: section == 's-blue' ? 'blue' : 'red',
  hp: 100,
  maxHp: 100,
  position: at,
  weapon: 'rifle',
);

const _impact = Impact(
  targetId: 'r-1',
  targetType: 'soldier',
  damage: 12,
  friendly: false,
  result: ImpactResult.damaged,
);

/// The section's whole view: its shooter, two enemies and its team's HQ.
SectionView _whole({List<UnitView>? units}) => SectionView(
  weather: 'clear',
  at: const Duration(hours: 1),
  section: const SectionPrivate(money: 0, xp: 0),
  units:
      units ??
      [
        _unit('b-1', _shooterAt),
        _unit('r-1', _targetAt, section: 's-red'),
        _unit('r-2', _otherAt, section: 's-red'),
      ],
  hqs: const [HqView(team: 'red', position: _hqAt, hp: 1000, maxHp: 1000)],
  relics: const [],
  world: const [],
);

void main() {
  group(ShotEffects, () {
    late HeldView view;
    late ShotEffects effects;

    /// The view takes [message], then the effects of it.
    List<ShotEffect> hear(HostMessage message) {
      view.apply(message);
      return effects.of(message, view);
    }

    setUp(() {
      view = HeldView();
      effects = ShotEffects();
      hear(_whole());
    });

    test('COMBAT-11 a single seen shot that hit a seen unit is a tracer', () {
      final drawn = hear(
        const TickUpdate(
          at: Duration(hours: 1, seconds: 1),
          events: [
            Attacked(
              attackerId: 'b-1',
              sectionId: 's-blue',
              weapon: 'rifle',
              hit: true,
              impacts: [_impact],
            ),
          ],
        ),
      );

      expect(drawn, const [
        Tracer(from: _shooterAt, to: _targetAt, weapon: 'rifle'),
        HitMark(at: _targetAt, result: ImpactResult.damaged),
      ]);
    });

    test('COMBAT-11 a burst is a tracer and a hit mark for each unit hit', () {
      final drawn = hear(
        const TickUpdate(
          at: Duration(hours: 1, seconds: 1),
          bursts: [
            Burst(
              attackerId: 'b-1',
              sectionId: 's-blue',
              weapon: 'rifle',
              shots: 3,
              hits: 3,
              impacts: [
                _impact,
                Impact(
                  targetId: 'r-2',
                  targetType: 'soldier',
                  damage: 12,
                  friendly: false,
                  result: ImpactResult.killed,
                ),
              ],
            ),
          ],
        ),
      );

      expect(drawn, const [
        Tracer(from: _shooterAt, to: _targetAt, weapon: 'rifle'),
        HitMark(at: _targetAt, result: ImpactResult.damaged),
        Tracer(from: _shooterAt, to: _otherAt, weapon: 'rifle'),
        HitMark(at: _otherAt, result: ImpactResult.killed),
      ]);
    });

    test(
      'COMBAT-57 / decision 234 an unseen hit shows the hit, not the shooter',
      () {
        final drawn = hear(
          const TickUpdate(
            at: Duration(hours: 1, seconds: 1),
            unseenHits: [
              UnseenHit(
                targetId: 'b-1',
                damage: 12,
                result: ImpactResult.damaged,
              ),
            ],
          ),
        );

        // Only the unit hit: no origin, no direction, no tracer, no flash.
        expect(drawn, const [
          HitMark(at: _shooterAt, result: ImpactResult.damaged),
        ]);
        expect(drawn.whereType<Tracer>(), isEmpty);
        expect(drawn.whereType<MuzzleFlash>(), isEmpty);
      },
    );

    test(
      'COMBAT-58 / decision 237 a shot at an unseen target shows the shooter '
      'firing, outcome unknown',
      () {
        final drawn = hear(
          const TickUpdate(
            at: Duration(hours: 1, seconds: 1),
            fired: [
              Fired(
                attackerId: 'b-1',
                sectionId: 's-blue',
                weapon: 'rifle',
                shots: 2,
              ),
            ],
          ),
        );

        // The shooter, and nothing of where the shot went.
        expect(drawn, const [MuzzleFlash(at: _shooterAt, weapon: 'rifle')]);
        expect(drawn.whereType<Tracer>(), isEmpty);
        expect(drawn.whereType<HitMark>(), isEmpty);
      },
    );

    test(
      'COMBAT-58 a shot whose outcome is unknown shows only the hits it sees',
      () {
        final drawn = hear(
          const TickUpdate(
            at: Duration(hours: 1, seconds: 1),
            fired: [
              Fired(
                attackerId: 'b-1',
                sectionId: 's-blue',
                weapon: 'rifle',
                shots: 2,
                impacts: [_impact],
              ),
            ],
          ),
        );

        expect(drawn, const [
          MuzzleFlash(at: _shooterAt, weapon: 'rifle'),
          HitMark(at: _targetAt, result: ImpactResult.damaged),
        ]);
        expect(drawn.whereType<Tracer>(), isEmpty);
      },
    );

    test('decision 237 a shooter the view has no place for draws nothing', () {
      expect(
        hear(
          const TickUpdate(
            at: Duration(hours: 1, seconds: 1),
            events: [
              Attacked(
                attackerId: 'ghost',
                sectionId: 's-red',
                weapon: 'rifle',
                hit: true,
                impacts: [_impact],
              ),
            ],
            fired: [
              Fired(
                attackerId: 'ghost',
                sectionId: 's-red',
                weapon: 'rifle',
                shots: 1,
              ),
            ],
            unseenHits: [
              UnseenHit(
                targetId: 'ghost',
                damage: 1,
                result: ImpactResult.damaged,
              ),
            ],
          ),
        ),
        isEmpty,
      );
    });

    test('a seen shooter whose hit units cannot be placed is a flash', () {
      final drawn = hear(
        const TickUpdate(
          at: Duration(hours: 1, seconds: 1),
          events: [
            Attacked(
              attackerId: 'b-1',
              sectionId: 's-blue',
              weapon: 'rifle',
              hit: true,
              impacts: [
                Impact(
                  targetId: 'ghost',
                  targetType: 'soldier',
                  damage: 12,
                  friendly: false,
                  result: ImpactResult.damaged,
                ),
              ],
            ),
          ],
        ),
      );

      expect(drawn, const [MuzzleFlash(at: _shooterAt, weapon: 'rifle')]);
    });

    test('a unit killed by the shot is marked where it was last seen', () {
      // The target leaves the view in the very update that tells it died.
      final drawn = hear(
        const TickUpdate(
          at: Duration(hours: 1, seconds: 1),
          gone: ['r-1'],
          events: [
            Attacked(
              attackerId: 'b-1',
              sectionId: 's-blue',
              weapon: 'rifle',
              hit: true,
              impacts: [
                Impact(
                  targetId: 'r-1',
                  targetType: 'soldier',
                  damage: 100,
                  friendly: false,
                  result: ImpactResult.killed,
                ),
              ],
            ),
          ],
        ),
      );

      expect(view.units, isNot(contains('r-1')));
      expect(drawn, const [
        Tracer(from: _shooterAt, to: _targetAt, weapon: 'rifle'),
        HitMark(at: _targetAt, result: ImpactResult.killed),
      ]);
    });

    test('a hit on an HQ is marked at the HQ', () {
      final drawn = hear(
        const TickUpdate(
          at: Duration(hours: 1, seconds: 1),
          events: [
            Attacked(
              attackerId: 'b-1',
              sectionId: 's-blue',
              weapon: 'rifle',
              hit: true,
              impacts: [
                Impact(
                  targetId: 'hq-red',
                  targetType: 'hq',
                  damage: 5,
                  friendly: false,
                  result: ImpactResult.damaged,
                ),
              ],
            ),
          ],
        ),
      );

      expect(drawn, const [
        Tracer(from: _shooterAt, to: _hqAt, weapon: 'rifle'),
        HitMark(at: _hqAt, result: ImpactResult.damaged),
      ]);
    });

    test('a message that is not an update draws nothing', () {
      expect(hear(_whole(units: [_unit('b-1', _shooterAt)])), isEmpty);
    });

    test('events other than a shot draw nothing', () {
      expect(
        hear(
          const TickUpdate(
            at: Duration(hours: 1, seconds: 1),
            events: [UnitHealed(unitId: 'b-1', targetId: 'b-1', hp: 100)],
          ),
        ),
        isEmpty,
      );
    });
  });
}
