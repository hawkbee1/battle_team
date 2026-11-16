import 'package:battle_team/l10n/l10n.dart';
import 'package:battle_team/settings/cubit/settings_cubit.dart';
import 'package:battle_team/settings/data/key_bindings.dart';
import 'package:battle_team/settings/data/player_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// The name of [key] on a button: what is printed on it, and the space bar,
/// which prints nothing, by its name.
String keyLabel(LogicalKeyboardKey key) {
  final label = key.keyLabel.trim();
  return label.isEmpty ? 'Space' : label;
}

/// {@template settings_page}
/// The settings screen: the sound effects and the ambience music, each on or
/// off, and the key of each command of the battle view. A command is changed
/// by choosing it and pressing the new key; a key another command uses is
/// swapped with it (`KeyBindings`). Each change shows at once and is kept on
/// the device (`SettingsCubit`, above the navigator).
/// {@endtemplate}
class SettingsPage extends StatelessWidget {
  /// {@macro settings_page}
  const new({super.key});

  /// Opens the settings screen over the current page.
  static Future<void> open(BuildContext context) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SettingsCubit>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: BlocBuilder<SettingsCubit, PlayerSettings>(
        builder: (context, settings) => ListView(
          children: [
            _Heading(l10n.settingsSound),
            SwitchListTile(
              title: Text(l10n.settingsSoundEffects),
              subtitle: Text(l10n.settingsSoundEffectsHint),
              value: settings.soundEffects,
              onChanged: (on) => cubit.setSoundEffects(on: on),
            ),
            SwitchListTile(
              title: Text(l10n.settingsAmbience),
              subtitle: Text(l10n.settingsAmbienceHint),
              value: settings.ambience,
              onChanged: (on) => cubit.setAmbience(on: on),
            ),
            const Divider(),
            _Heading(l10n.settingsCommands),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l10n.settingsCommandsHint),
            ),
            for (final command in BattleCommand.values)
              ListTile(
                title: Text(l10n.settingsCommand(command.name)),
                trailing: OutlinedButton(
                  onPressed: () => _choose(context, command),
                  child: Text(keyLabel(settings.keys.keyOf(command))),
                ),
                onTap: () => _choose(context, command),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: settings.keys == KeyBindings.defaults
                      ? null
                      : cubit.resetKeys,
                  child: Text(l10n.settingsResetKeys),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _choose(BuildContext context, BattleCommand command) async {
    final cubit = context.read<SettingsCubit>();
    final key = await showDialog<LogicalKeyboardKey>(
      context: context,
      builder: (_) => _KeyDialog(command: command),
    );
    if (key != null) await cubit.rebind(command, key);
  }
}

class _Heading extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// Waits for the key the player presses for [command]: the first one that is
/// not a modifier is the answer.
class _KeyDialog extends StatelessWidget {
  const new({required this.command});

  final BattleCommand command;

  static final Set<LogicalKeyboardKey> _modifiers = {
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.capsLock,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent || _modifiers.contains(event.logicalKey)) {
          return KeyEventResult.handled;
        }
        Navigator.of(context).pop(event.logicalKey);
        return KeyEventResult.handled;
      },
      child: AlertDialog(
        content: Text(
          l10n.settingsPressKey(l10n.settingsCommand(command.name)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.settingsCancel),
          ),
        ],
      ),
    );
  }
}
