import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/battle/widgets/move_panel.dart';
import 'package:flutter/widgets.dart' show Locale, Text;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

const _from = Position(500, 500, 0);

PendingMove _pending({
  double cost = 12.5,
  Duration arrives = const Duration(hours: 1, minutes: 6),
  Duration wait = Duration.zero,
}) => PendingMove(
  unitId: 'u-1',
  from: _from,
  plan: MovePreview(
    destination: const Position(1500, 500, 0),
    cells: const [Cell(0, 0), Cell(1, 0)],
    points: const [Position(500, 500, 0), Position(1500, 500, 0)],
    costAp: cost,
    lengthM: 10,
    arrivesAt: arrives,
    apWait: wait,
  ),
);

void main() {
  var confirmed = 0;
  var cancelled = 0;

  Future<void> pump(
    WidgetTester tester, {
    PendingMove? pending,
    ArrivalNote? note,
    double? ap = 30,
    Duration? time = const Duration(hours: 1),
    Locale? locale,
  }) async {
    await tester.pumpApp(
      MovePanel(
        pending: pending,
        note: note,
        ap: ap,
        time: time,
        onConfirm: () => confirmed++,
        onCancel: () => cancelled++,
      ),
      locale: locale,
    );
  }

  setUp(() {
    confirmed = 0;
    cancelled = 0;
  });

  group(MovePanel, () {
    testWidgets('COMBAT-03 shows the AP cost against the unit AP and when it '
        'arrives, and confirms or cancels', (tester) async {
      await pump(tester, pending: _pending());

      expect(
        find.text('Move: 12.5 AP of 30 · arrives in 6 min'),
        findsOneWidget,
      );
      expect(find.textContaining('Short of AP'), findsNothing);

      await tester.tap(find.text('Confirm move'));
      await tester.tap(find.text('Cancel'));

      expect((confirmed, cancelled), (1, 1));
    });

    testWidgets('COMBAT-06 a cost above the AP shows how long the unit '
        'waits for them', (tester) async {
      await pump(
        tester,
        pending: _pending(cost: 40, wait: const Duration(hours: 10)),
        ap: 5.25,
      );

      expect(find.textContaining('Move: 40 AP of 5.3'), findsOneWidget);
      expect(find.text('Short of AP: waits 10.0 h for them'), findsOneWidget);
    });

    testWidgets('the unit AP or the battle time not known yet show dashes '
        'and no time', (tester) async {
      await pump(tester, pending: _pending(), ap: null, time: null);

      expect(find.textContaining('AP of –'), findsOneWidget);
    });

    testWidgets('MAP-50 a refused preview says why and has nothing to '
        'confirm', (tester) async {
      await pump(
        tester,
        pending: const PendingMove(
          unitId: 'u-1',
          from: _from,
          plan: MoveRefused(PreCheckRefusal.occupied),
        ),
      );

      expect(
        find.text('Cannot move there: The place is taken'),
        findsOneWidget,
      );
      expect(find.text('Confirm move'), findsNothing);

      await tester.tap(find.text('Cancel'));
      expect(cancelled, 1);
    });

    testWidgets('stack decision 8 the host arrival, when it differs, is '
        'shown: later or sooner', (tester) async {
      await pump(
        tester,
        note: const ArrivalNote(
          unitId: 'u-1',
          expected: Duration(hours: 1),
          host: Duration(hours: 1, minutes: 5),
        ),
      );
      expect(
        find.text('The host has the unit arrive 5 min later than previewed'),
        findsOneWidget,
      );

      await pump(
        tester,
        note: const ArrivalNote(
          unitId: 'u-1',
          expected: Duration(hours: 1, minutes: 5),
          host: Duration(hours: 1),
        ),
      );
      expect(
        find.text('The host has the unit arrive 5 min sooner than previewed'),
        findsOneWidget,
      );
    });

    testWidgets('shows nothing without a preview or a note, or for a note '
        'of no difference', (tester) async {
      await pump(tester);
      expect(find.byType(Text), findsNothing);

      await pump(
        tester,
        note: const ArrivalNote(
          unitId: 'u-1',
          expected: Duration(hours: 1),
          host: Duration(hours: 1),
        ),
      );
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('is in French', (tester) async {
      await pump(
        tester,
        pending: _pending(wait: const Duration(minutes: 3)),
        locale: const Locale('fr'),
      );

      expect(
        find.text('Déplacement : 12.5 PA sur 30 · arrivée dans 6 min'),
        findsOneWidget,
      );
      expect(
        find.text('Manque de PA : attend 3 min qu’ils reviennent'),
        findsOneWidget,
      );
      expect(find.text('Confirmer le déplacement'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
    });

    testWidgets('is read by a screen reader: labelled buttons', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, pending: _pending());

      expect(find.bySemanticsLabel('Confirm move'), findsOneWidget);
      expect(find.bySemanticsLabel('Cancel'), findsOneWidget);
      handle.dispose();
    });
  });
}
