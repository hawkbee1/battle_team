import 'package:battle_team/battle/data/map_assets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('loadBundledMapIds', () {
    test(
      'M7.12 lists the maps in the assets of the app, and no other',
      () async {
        final ids = await loadBundledMapIds(rootBundle);

        expect(ids, contains('saint_lo_1km'));
        expect(ids, isNot(contains('valley')));
        // Only a folder with its map.yaml is a map: not its tiles.
        expect(ids, isNot(contains('tiles')));
      },
    );
  });
}
