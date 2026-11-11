import 'package:battle_team/battle/battle.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(BattleRepositoryFactory, () {
    test(
      'M7.12 makes a repository of the battle given, with its map',
      () async {
        final factory = BattleRepositoryFactory(
          apiClient: MockAppwriteApiClient(),
          endpoint: 'http://127.0.0.1:9/v1',
          projectId: 'hawkbee',
        );

        final repository = factory.create((battleId: 'b-1', mapId: 'saint_lo'));
        addTearDown(repository.close);

        expect(repository.mapId, 'saint_lo');
      },
    );

    test('M7.12 makes a repository of its own each time: one serves one '
        'session', () async {
      final factory = BattleRepositoryFactory(
        apiClient: MockAppwriteApiClient(),
        endpoint: 'http://127.0.0.1:9/v1',
        projectId: 'hawkbee',
      );

      final first = factory.create((battleId: 'b-1', mapId: 'm'));
      final second = factory.create((battleId: 'b-1', mapId: 'm'));
      addTearDown(first.close);
      addTearDown(second.close);

      expect(identical(first, second), isFalse);
    });
  });
}
