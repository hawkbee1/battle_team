import 'dart:async';

import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_host.dart';
import '../../helpers/helpers.dart';
import '../../helpers/move_previewer.dart';

const _hq = HqView(
  team: 'blue',
  position: Position(50500, 5500, 3000),
  hp: 1000,
  maxHp: 1000,
);

/// A blue soldier at (5, 5) m of the 10 m grid, with [ap] AP, whose move ends
/// at [movingUntil] when it is under way.
UnitView _soldier({
  double ap = 30,
  Duration? movingUntil,
  Position at = const Position(500, 500, 0),
}) => UnitView(
  unitId: 'u-1',
  unitType: 'soldier',
  sectionId: 's-blue',
  team: 'blue',
  hp: 100,
  maxHp: 100,
  position: at,
  weapon: 'rifle',
  private: UnitPrivate(
    sightRangeM: 60,
    place: UnitPlace.deployed,
    ap: ApView(value: ap, at: const Duration(hours: 1), perHour: 1, max: 30),
    morale: 100,
    rounds: 10,
    xpEarned: 0,
    xpUnspent: 0,
    movingUntil: movingUntil,
  ),
);

BattleSnapshot _snapshot(List<UnitView> units) => BattleSnapshot(
  units: {for (final unit in units) unit.unitId: unit},
  hqs: const [_hq],
  relics: const [],
  team: 'blue',
  sectionId: 's-blue',
);

void main() {
  setUpAll(registerBattleFallbackValues);

  group('the move preview of $BattleCubit', () {
    late MockBattleRepository repository;
    late StreamController<ConnectionStatus> connection;
    late StreamController<BattleSnapshot> snapshots;
    late BattleCubit cubit;
    late LogCapture log;

    /// The soldier moves to the cell 10 m east of its own: (15, 5) m.
    const to = Position(1500, 500, 0);

    BattleCubit build({MovePreviewer? previewer}) => BattleCubit(
      repository: repository,
      preCheck: testPreCheck(),
      movePreviewer: previewer,
    );

    setUp(() {
      repository = MockBattleRepository();
      connection = StreamController<ConnectionStatus>.broadcast(sync: true);
      snapshots = StreamController<BattleSnapshot>.broadcast(sync: true);
      when(repository.signIn).thenAnswer((_) async {});
      when(() => repository.connection).thenAnswer((_) => connection.stream);
      when(() => repository.snapshots).thenAnswer((_) => snapshots.stream);
      when(() => repository.stopReason).thenReturn(null);
      when(repository.start).thenReturn(null);
      when(() => repository.send(any())).thenAnswer((_) async => null);
      when(repository.close).thenAnswer((_) async {});
      when(() => repository.battleTime).thenReturn(const Duration(hours: 1));
      cubit = build(previewer: testMovePreviewer());
      log = LogCapture();
    });

    tearDown(() async {
      await log.cancel();
      await cubit.close();
      await connection.close();
      await snapshots.close();
    });

    /// Plays with [units] and the soldier selected.
    Future<void> play([List<UnitView>? units]) async {
      await cubit.start();
      connection.add(ConnectionStatus.connected);
      snapshots.add(_snapshot(units ?? [_soldier(), blueCommander]));
      cubit.select('u-1');
    }

    group('previewMoveTo', () {
      test('COMBAT-03 shows the path, its cost and its arrival and sends '
          'nothing', () async {
        await play();

        await cubit.previewMoveTo(to);

        final pending = cubit.state.pendingMove!;
        expect(pending.unitId, 'u-1');
        expect(pending.from, _soldier().position);
        final plan = pending.plan as MovePreview;
        // 10 m of grass at 1 AP a metre, walked at 5 m/s.
        expect(plan.costAp, 10);
        expect(plan.arrivesAt, const Duration(hours: 1, seconds: 2));
        expect(plan.cells, const [Cell(0, 0), Cell(1, 0)]);
        expect(pending.points, plan.points);
        verifyNever(() => repository.send(any()));
        expect(log.lines.last, 'INFO move previewed');
      });

      test('COMBAT-06 a cost above the AP shows the wait', () async {
        await play([_soldier(ap: 4), blueCommander]);

        await cubit.previewMoveTo(to);

        final plan = cubit.state.pendingMove!.plan as MovePreview;
        expect(plan.apWait, greaterThan(const Duration(hours: 5)));
      });

      test('MAP-50 a destination a seen unit fills is refused before '
          'sending, with nothing to draw', () async {
        // Four tanks of 3.5 m fill the 10 m cell.
        final tanks = [
          for (var i = 0; i < 4; i++)
            UnitView(
              unitId: 'r-$i',
              unitType: 'tank',
              sectionId: 's-red',
              team: 'red',
              hp: 100,
              maxHp: 100,
              position: const Position(1500, 500, 0),
            ),
        ];
        await play([_soldier(), blueCommander, ...tanks]);

        await cubit.previewMoveTo(to);

        final pending = cubit.state.pendingMove!;
        expect(pending.plan, const MoveRefused(PreCheckRefusal.occupied));
        expect(pending.points, isNull);
        verifyNever(() => repository.send(any()));
        expect(log.lines.last, 'INFO move not previewable: occupied');
        await cubit.confirmMove();
        verifyNever(() => repository.send(any()));
        expect(cubit.state.pendingMove, isNull);
      });

      test('MAP-37 a destination no path leads to is refused', () async {
        cubit = build(
          previewer: testMovePreviewer(
            planner: StraightPlanner(blocked: {(1, 0)}),
          ),
        );
        await play();

        await cubit.previewMoveTo(to);

        expect(
          cubit.state.pendingMove!.plan,
          const MoveRefused(PreCheckRefusal.noPath),
        );
      });

      test(
        'a unit the client cannot plan for goes straight to the host',
        () async {
          await play([
            UnitView(
              unitId: 'u-1',
              unitType: 'dragon',
              sectionId: 's-blue',
              team: 'blue',
              hp: 1,
              maxHp: 1,
              position: const Position(500, 500, 0),
              private: _soldier().private,
            ),
          ]);

          await cubit.previewMoveTo(to);

          verify(() => repository.send(const Move(unitId: 'u-1', to: to)))
              .called(1);
          expect(cubit.state.pendingMove, isNull);
        },
      );

      test('without a previewer a move goes straight to the host', () async {
        cubit = build();
        await play();

        await cubit.previewMoveTo(to);

        verify(() => repository.send(const Move(unitId: 'u-1', to: to)))
            .called(1);
        expect(cubit.state.pendingMove, isNull);
      });

      test('nothing is previewed without a selected unit, a battle time or '
          'while the battle is not playing', () async {
        await cubit.previewMoveTo(to);
        await cubit.start();
        snapshots.add(_snapshot([_soldier()]));
        cubit.select('u-1');
        await cubit.previewMoveTo(to);
        connection.add(ConnectionStatus.connected);
        when(() => repository.battleTime).thenReturn(null);
        await cubit.previewMoveTo(to);
        when(() => repository.battleTime).thenReturn(const Duration(hours: 1));
        cubit.select(null);
        await cubit.previewMoveTo(to);

        expect(cubit.state.pendingMove, isNull);
        verifyNever(() => repository.send(any()));
      });
    });

    group('confirmMove', () {
      test('stack decision 8 sends the move with the path it planned and '
          'drops the preview', () async {
        await play();
        await cubit.previewMoveTo(to);

        await cubit.confirmMove();

        verify(
          () => repository.send(
            const Move(unitId: 'u-1', to: to, path: [Cell(0, 0), Cell(1, 0)]),
          ),
        ).called(1);
        expect(cubit.state.pendingMove, isNull);
        expect(
          cubit.state.notice,
          const OrderNotice(order: 'move', unitId: 'u-1'),
        );
      });

      test(
        'the host refusal shows as the host one; the preview is gone',
        () async {
          await play();
          await cubit.previewMoveTo(to);
          when(() => repository.send(any()))
              .thenAnswer((_) async => 'impassable');

          await cubit.confirmMove();

          expect(cubit.state.pendingMove, isNull);
          expect(cubit.state.notice!.refusal, 'impassable');
          expect(cubit.state.arrivalNote, isNull);
        },
      );

      test('with nothing previewed it sends nothing', () async {
        await play();

        await cubit.confirmMove();

        verifyNever(() => repository.send(any()));
      });

      test('a unit that left the section view is not moved', () async {
        await play();
        await cubit.previewMoveTo(to);
        snapshots.add(_snapshot([blueCommander]));
        expect(cubit.state.pendingMove, isNull);

        await cubit.confirmMove();

        verifyNever(() => repository.send(any()));
      });
    });

    group('the preview goes stale', () {
      test('cancelMove drops it', () async {
        await play();
        await cubit.previewMoveTo(to);

        cubit.cancelMove();
        expect(cubit.state.pendingMove, isNull);
        final before = cubit.state;
        cubit.cancelMove();

        expect(cubit.state, same(before));
      });

      test('selecting another unit, or none, drops it', () async {
        await play();
        await cubit.previewMoveTo(to);

        cubit.select('c-1');

        expect(cubit.state.pendingMove, isNull);
      });

      test('the unit moving, or leaving, drops it; a message that changes '
          'nothing for it keeps it', () async {
        await play();
        await cubit.previewMoveTo(to);

        snapshots.add(_snapshot([_soldier(ap: 20), blueCommander]));
        expect(cubit.state.pendingMove, isNotNull);

        snapshots.add(
          _snapshot([_soldier(at: const Position(900, 500, 0)), blueCommander]),
        );
        expect(cubit.state.pendingMove, isNull);
      });
    });

    group('moveSelectedTo from first person', () {
      test('a move goes at once, with the path the preview planned', () async {
        await play();

        await cubit.moveSelectedTo(to);

        verify(
          () => repository.send(
            const Move(unitId: 'u-1', to: to, path: [Cell(0, 0), Cell(1, 0)]),
          ),
        ).called(1);
        expect(cubit.state.pendingMove, isNull);
      });

      test('MAP-50 a move the client expects refused is not sent, and says '
          'why', () async {
        await play();
        final crowd = [
          for (var i = 0; i < 4; i++)
            UnitView(
              unitId: 'r-$i',
              unitType: 'tank',
              sectionId: 's-red',
              team: 'red',
              hp: 100,
              maxHp: 100,
              position: const Position(1500, 500, 0),
            ),
        ];
        snapshots.add(_snapshot([_soldier(), blueCommander, ...crowd]));

        await cubit.moveSelectedTo(to);

        verifyNever(() => repository.send(any()));
        expect(
          cubit.state.notice,
          const OrderNotice(order: 'move', unitId: 'u-1', refusal: 'occupied'),
        );
        expect(log.lines.last, 'WARNING order move not sent: occupied');
      });

      test('without a battle time the host decides', () async {
        await play();
        when(() => repository.battleTime).thenReturn(null);

        await cubit.moveSelectedTo(to);

        verify(() => repository.send(const Move(unitId: 'u-1', to: to)))
            .called(1);
      });

      test('nothing is sent without a selected unit', () async {
        await cubit.start();
        connection.add(ConnectionStatus.connected);

        await cubit.moveSelectedTo(to);

        verifyNever(() => repository.send(any()));
      });
    });

    group('the host arrival', () {
      Future<void> confirmed() async {
        await play();
        await cubit.previewMoveTo(to);
        await cubit.confirmMove();
      }

      test('decision 236 an arrival that is the preview one says nothing: '
          'the unit moves to it', () async {
        await confirmed();

        snapshots.add(
          _snapshot([
            _soldier(movingUntil: const Duration(hours: 1, seconds: 2), at: to),
            blueCommander,
          ]),
        );

        expect(cubit.state.arrivalNote, isNull);
        expect(
          cubit.state.units['u-1']!.private!.movingUntil,
          const Duration(hours: 1, seconds: 2),
        );
      });

      test('stack decision 8 an arrival that differs is shown, with by how '
          'much, and not argued', () async {
        await confirmed();

        snapshots.add(
          _snapshot([
            _soldier(movingUntil: const Duration(hours: 1, seconds: 12)),
            blueCommander,
          ]),
        );

        final note = cubit.state.arrivalNote!;
        expect(note.unitId, 'u-1');
        expect(note.expected, const Duration(hours: 1, seconds: 2));
        expect(note.host, const Duration(hours: 1, seconds: 12));
        expect(note.difference, const Duration(seconds: 10));
        expect(log.lines.last, 'WARNING move arrival differs from the preview');
        // Told once; a new preview clears it.
        final before = cubit.state;
        snapshots.add(
          _snapshot([
            _soldier(movingUntil: const Duration(hours: 1, seconds: 12)),
            blueCommander,
          ]),
        );
        expect(cubit.state.arrivalNote, before.arrivalNote);
        await cubit.previewMoveTo(to);
        expect(cubit.state.arrivalNote, isNull);
      });

      test(
        'the end of the previous move is not the answer to the new one',
        () async {
          await play([
            _soldier(movingUntil: const Duration(hours: 1, minutes: 5)),
            blueCommander,
          ]);
          await cubit.previewMoveTo(to);
          await cubit.confirmMove();

          // The view still holds the old end of move.
          snapshots.add(
            _snapshot([
              _soldier(movingUntil: const Duration(hours: 1, minutes: 5)),
              blueCommander,
            ]),
          );
          expect(cubit.state.arrivalNote, isNull);

          snapshots.add(
            _snapshot([
              _soldier(movingUntil: const Duration(hours: 1, seconds: 30)),
              blueCommander,
            ]),
          );
          expect(cubit.state.arrivalNote, isNotNull);
        },
      );

      test('a unit that left the view is not waited for', () async {
        await confirmed();

        snapshots
          ..add(_snapshot([blueCommander]))
          ..add(
            _snapshot([
              _soldier(movingUntil: const Duration(hours: 5)),
              blueCommander,
            ]),
          );

        expect(cubit.state.arrivalNote, isNull);
      });

      test('a move the host refused is not waited for', () async {
        await play();
        await cubit.previewMoveTo(to);
        when(() => repository.send(any())).thenAnswer((_) async => 'no_path');
        await cubit.confirmMove();

        snapshots.add(
          _snapshot([
            _soldier(movingUntil: const Duration(hours: 5)),
            blueCommander,
          ]),
        );

        expect(cubit.state.arrivalNote, isNull);
      });

      test('a move sent after the cubit closed is not waited for', () async {
        await play();
        await cubit.previewMoveTo(to);
        final answer = Completer<String?>();
        when(() => repository.send(any())).thenAnswer((_) => answer.future);

        final confirming = cubit.confirmMove();
        await cubit.close();
        answer.complete(null);
        await confirming;

        expect(cubit.state.arrivalNote, isNull);
      });
    });

    group('the state', () {
      test('compares by value', () {
        const plan = MoveRefused(PreCheckRefusal.noPath);
        const from = Position(1, 2, 3);
        PendingMove pending() =>
            PendingMove(unitId: ['u'].first, from: from, plan: plan);
        ArrivalNote note() => ArrivalNote(
          unitId: ['u'].first,
          expected: Duration.zero,
          host: const Duration(seconds: 1),
        );

        expect(pending(), pending());
        expect(note(), note());
        expect(pending().points, isNull);
        expect(note().difference, const Duration(seconds: 1));
      });
    });

    test('decision 237 the logs name no unit and no position', () async {
      await play();
      await cubit.previewMoveTo(to);
      await cubit.confirmMove();

      for (final text in log.texts) {
        expect(text, isNot(contains('u-1')));
        expect(text, isNot(contains('1500')));
      }
      expect(log.records.every((r) => r.level < Level.SEVERE), isTrue);
    });
  });
}
