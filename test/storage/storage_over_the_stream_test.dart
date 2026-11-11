import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/storage/cubit/storage_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_host.dart';
import '../helpers/real_cubit.dart';

/// Plays [host] through the real cubit, repository, client and codec, and
/// gives the storage cubit that followed the view.
Future<({BattleCubit battle, StorageCubit storage})> play(FakeHost host) async {
  final battle = realCubit(host);
  final storage = realStorageCubit(battle);
  addTearDown(storage.close);
  addTearDown(battle.close);
  battle.start();
  await pumpEventQueue(times: 500);
  return (battle: battle, storage: storage);
}

void main() {
  group('the storage over the host streams', () {
    test('HQ-29 a recorded stream: the storage lists only the section own '
        'units, and no unit the section does not own', () async {
      var sawOthers = false;
      for (final name in ['clear_s-1', 'clear_s-2', 'fog_s-1', 'fog_s-2']) {
        final host = FakeHost.recorded(name);
        final (:battle, :storage) = await play(host);

        final all = storage.state.units.values.toList();
        final others = all.where((unit) => unit.sectionId != host.sectionId);
        sawOthers = sawOthers || others.isNotEmpty;
        for (final unit in storage.state.stored) {
          expect(unit.sectionId, host.sectionId);
          expect(unit.private, isNotNull);
        }
        expect(storage.state.sectionUnits, isNotEmpty);
        expect(storage.state.portal, isNotNull);
        expect(battle.state.sectionId, host.sectionId);
      }
      // The recordings do show units of other sections to some section.
      expect(sawOthers, isTrue);
    });

    test('HQ-33 Deploy goes through the codec to the host, and its answer '
        'shows', () async {
      final host = FakeHost(
        view: SectionView(
          weather: 'clear',
          at: blueView.at,
          section: blueView.section,
          units: const [blueCommander, storedSoldier, redSoldier],
          hqs: blueView.hqs,
          relics: blueView.relics,
          world: blueView.world,
        ),
      );
      final (battle: _, :storage) = await play(host);

      await storage.deploy('s-1');

      expect(host.orders, [const Deploy(unitId: 's-1')]);
      expect(storage.state.notice!.refusal, isNull);
    });

    test('decision 237 an enemy the section does not see: the host refusal '
        'shows as the host one, nothing was known before', () async {
      final host = FakeHost(
        view: SectionView(
          weather: 'clear',
          at: blueView.at,
          section: blueView.section,
          units: const [blueCommander, storedSoldier],
          hqs: blueView.hqs,
          relics: blueView.relics,
          world: blueView.world,
        ),
      )..refusal = 'blocked_by_enemy';
      final (battle: _, :storage) = await play(host);

      expect(storage.checkDeploy(storedSoldier), const PreCheckPassed());
      await storage.deploy('s-1');

      expect(host.orders, [const Deploy(unitId: 's-1')]);
      expect(storage.state.notice!.refusal, 'blocked_by_enemy');
    });

    test('HQ-32 a recall the host announces counts down, then the unit is '
        'stored', () async {
      final host = FakeHost(
        view: SectionView(
          weather: 'clear',
          at: blueView.at,
          section: blueView.section,
          units: const [blueCommander],
          hqs: blueView.hqs,
          relics: blueView.relics,
          world: blueView.world,
        ),
        updates: [
          TickUpdate(
            at: blueView.at + const Duration(minutes: 1),
            events: const [
              RecallBegan(unitId: 'c-1', storedAt: Duration(hours: 7)),
            ],
          ),
        ],
      );
      final (battle: _, :storage) = await play(host);

      expect(storage.state.recalls, {'c-1': const Duration(hours: 7)});
      expect(storage.recallRemaining('c-1'), isNotNull);
    });
  });
}
