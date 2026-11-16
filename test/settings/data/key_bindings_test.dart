import 'package:battle_team/settings/data/key_bindings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(KeyBindings, () {
    test('has the keys the battle view always had, each on one command', () {
      const keys = KeyBindings.defaults;

      expect(keys.keyOf(BattleCommand.turnLeft), LogicalKeyboardKey.keyQ);
      expect(keys.keyOf(BattleCommand.turnRight), LogicalKeyboardKey.keyE);
      expect(keys.keyOf(BattleCommand.back), LogicalKeyboardKey.escape);
      expect(keys.isValid, isTrue);
      expect(keys.commandOf(LogicalKeyboardKey.keyQ), BattleCommand.turnLeft);
      expect(keys.commandOf(LogicalKeyboardKey.keyZ), isNull);
    });

    test('the plus key and the keypad still zoom', () {
      const keys = KeyBindings.defaults;

      expect(keys.commandOf(LogicalKeyboardKey.add), BattleCommand.zoomIn);
      expect(
        keys.commandOf(LogicalKeyboardKey.numpadAdd),
        BattleCommand.zoomIn,
      );
      expect(
        keys.commandOf(LogicalKeyboardKey.numpadSubtract),
        BattleCommand.zoomOut,
      );
    });

    test('a command missing from the keys has its default', () {
      const keys = KeyBindings({
        BattleCommand.turnLeft: LogicalKeyboardKey.keyA,
      });

      expect(keys.keyOf(BattleCommand.turnLeft), LogicalKeyboardKey.keyA);
      expect(keys.keyOf(BattleCommand.turnRight), LogicalKeyboardKey.keyE);
    });

    test('puts a command on a free key', () {
      final keys = KeyBindings.defaults.rebind(
        BattleCommand.turnLeft,
        LogicalKeyboardKey.keyA,
      );

      expect(keys.keyOf(BattleCommand.turnLeft), LogicalKeyboardKey.keyA);
      expect(keys.commandOf(LogicalKeyboardKey.keyA), BattleCommand.turnLeft);
      // Q gives nothing now.
      expect(keys.commandOf(LogicalKeyboardKey.keyQ), isNull);
      expect(keys.isValid, isTrue);
    });

    test('swaps with the command that had the key', () {
      final keys = KeyBindings.defaults.rebind(
        BattleCommand.turnLeft,
        LogicalKeyboardKey.keyE,
      );

      expect(keys.keyOf(BattleCommand.turnLeft), LogicalKeyboardKey.keyE);
      expect(keys.keyOf(BattleCommand.turnRight), LogicalKeyboardKey.keyQ);
      expect(keys.isValid, isTrue);
    });

    test('keeps a command on its own key when it is bound to it again', () {
      final keys = KeyBindings.defaults.rebind(
        BattleCommand.turnLeft,
        LogicalKeyboardKey.keyQ,
      );

      expect(keys, KeyBindings.defaults);
    });

    test('a key that zooms by alias is not swapped, it is rebound', () {
      final keys = KeyBindings.defaults.rebind(
        BattleCommand.turnLeft,
        LogicalKeyboardKey.numpadAdd,
      );

      expect(keys.keyOf(BattleCommand.turnLeft), LogicalKeyboardKey.numpadAdd);
      expect(keys.keyOf(BattleCommand.zoomIn), LogicalKeyboardKey.equal);
      // The key is bound, so it turns and no longer zooms.
      expect(
        keys.commandOf(LogicalKeyboardKey.numpadAdd),
        BattleCommand.turnLeft,
      );
    });

    test('two commands on one key are not valid', () {
      const keys = KeyBindings({
        BattleCommand.turnLeft: LogicalKeyboardKey.keyE,
      });

      expect(keys.isValid, isFalse);
    });

    test('bindings with the same keys are equal', () {
      expect(
        KeyBindings.defaults.rebind(
          BattleCommand.turnLeft,
          LogicalKeyboardKey.keyQ,
        ),
        const KeyBindings({}),
      );
    });
  });
}
