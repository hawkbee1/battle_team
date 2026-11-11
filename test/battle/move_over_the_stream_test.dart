import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_host.dart';
import '../helpers/move_previewer.dart';
import '../helpers/real_cubit.dart';

void main() {
  group('a move over the host streams', () {
    test('stack decision 8 a recorded stream: a previewed move is confirmed '
        'with the path it planned, through the codec to the host', () async {
      for (final name in ['clear_s-1', 'clear_s-2']) {
        final host = FakeHost.recorded(name);
        final cubit = realCubit(host, previewer: testMovePreviewer());
        addTearDown(cubit.close);
        cubit.start();
        await pumpEventQueue(times: 500);
        final own = cubit.state.sectionUnits.firstWhere(
          (unit) =>
              unit.private?.place == UnitPlace.deployed &&
              unit.position != null,
        );
        cubit.select(own.unitId);
        final from = own.position!;
        final to = Position(from.xCm + 1000, from.yCm, from.zCm);

        await cubit.previewMoveTo(to);
        expect(host.orders, isEmpty, reason: 'a preview sends nothing');
        final plan = cubit.state.pendingMove!.plan as MovePreview;
        await cubit.confirmMove();

        final move = host.orders.single as Move;
        expect(move.unitId, own.unitId, reason: name);
        expect(move.to, to);
        expect(move.path, plan.cells);
        expect(
          move.path!.first,
          Cell((from.x / 10).floor(), (from.y / 10).floor()),
        );
        expect(move.path!.last, Cell((to.x / 10).floor(), (to.y / 10).floor()));
        expect(cubit.state.notice!.refusal, isNull);
      }
    });

    test('stack decision 8 the host refusal of a confirmed move shows as the '
        'host one, and the preview is dropped', () async {
      final host = FakeHost.recorded('clear_s-1')..refusal = 'impassable';
      final cubit = realCubit(host, previewer: testMovePreviewer());
      addTearDown(cubit.close);
      cubit.start();
      await pumpEventQueue(times: 500);
      final own = cubit.state.sectionUnits.firstWhere(
        (unit) =>
            unit.private?.place == UnitPlace.deployed && unit.position != null,
      );
      cubit.select(own.unitId);

      await cubit.previewMoveTo(
        Position(own.position!.xCm + 1000, own.position!.yCm, 0),
      );
      await cubit.confirmMove();

      expect(cubit.state.pendingMove, isNull);
      expect(cubit.state.notice!.refusal, 'impassable');
    });
  });
}
