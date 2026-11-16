import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';

/// What the player can do from the keyboard in the battle view: the keys of
/// each are the player's to choose (`KeyBindings`).
enum BattleCommand {
  /// Moves the overview left; looks left from a unit's eyes.
  panLeft,

  /// Moves the overview right; looks right from a unit's eyes.
  panRight,

  /// Moves the overview up; looks up from a unit's eyes.
  panUp,

  /// Moves the overview down; looks down from a unit's eyes.
  panDown,

  /// Turns the view to the left.
  turnLeft,

  /// Turns the view to the right.
  turnRight,

  /// Zooms the overview in.
  zoomIn,

  /// Zooms the overview out.
  zoomOut,

  /// Gives up what is under way, and goes back: a previewed move, firing at a
  /// position, the selection, the view through a unit's eyes.
  back,
}

/// {@template key_bindings}
/// The key of each [BattleCommand]. Every command has one key and no key has
/// two commands: giving a command a key another has takes that command's
/// place with the key this one had (a swap), so that the keys stay a
/// bijection and the player never ends with a command out of reach.
///
/// The numeric keypad's plus and minus, and the plus key, zoom as well
/// whatever the bindings, unless the player bound them to something else.
/// {@endtemplate}
class KeyBindings extends Equatable {
  /// {@macro key_bindings}
  const new(this.keys);

  /// The keys the battle view had before they could be changed.
  static const defaults = KeyBindings({
    BattleCommand.panLeft: LogicalKeyboardKey.arrowLeft,
    BattleCommand.panRight: LogicalKeyboardKey.arrowRight,
    BattleCommand.panUp: LogicalKeyboardKey.arrowUp,
    BattleCommand.panDown: LogicalKeyboardKey.arrowDown,
    BattleCommand.turnLeft: LogicalKeyboardKey.keyQ,
    BattleCommand.turnRight: LogicalKeyboardKey.keyE,
    BattleCommand.zoomIn: LogicalKeyboardKey.equal,
    BattleCommand.zoomOut: LogicalKeyboardKey.minus,
    BattleCommand.back: LogicalKeyboardKey.escape,
  });

  /// The command a key that zooms besides the bound ones gives.
  static BattleCommand? _zoomAlias(LogicalKeyboardKey key) => switch (key) {
    LogicalKeyboardKey.add ||
    LogicalKeyboardKey.numpadAdd => BattleCommand.zoomIn,
    LogicalKeyboardKey.numpadSubtract => BattleCommand.zoomOut,
    _ => null,
  };

  /// The key of each command; a command missing keeps its default.
  final Map<BattleCommand, LogicalKeyboardKey> keys;

  /// The key of [command].
  LogicalKeyboardKey keyOf(BattleCommand command) =>
      keys[command] ?? defaults.keys[command]!;

  /// The command [key] gives, or null when it gives none.
  BattleCommand? commandOf(LogicalKeyboardKey key) {
    for (final command in BattleCommand.values) {
      if (keyOf(command) == key) return command;
    }
    return _zoomAlias(key);
  }

  /// These bindings with [command] on [key]. The command that had [key] gets
  /// the key [command] had.
  KeyBindings rebind(BattleCommand command, LogicalKeyboardKey key) {
    final other = commandOf(key);
    final before = keyOf(command);
    return KeyBindings({
      for (final each in BattleCommand.values) each: keyOf(each),
      // An alias that zooms is not a binding to swap with.
      if (other != null && keyOf(other) == key) other: before,
      command: key,
    });
  }

  /// Whether every command has a key of its own: what stored bindings must be
  /// to be trusted.
  bool get isValid =>
      BattleCommand.values.map(keyOf).toSet().length ==
      BattleCommand.values.length;

  @override
  List<Object?> get props => [
    for (final command in BattleCommand.values) keyOf(command),
  ];
}
