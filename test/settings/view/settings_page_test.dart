import 'package:battle_team/l10n/gen/app_localizations_en.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:battle_team/settings/cubit/settings_cubit.dart';
import 'package:battle_team/settings/data/key_bindings.dart';
import 'package:battle_team/settings/view/settings_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/settings.dart';

void main() {
  group(SettingsPage, () {
    late SettingsCubit cubit;

    setUp(() => cubit = realSettings());

    Future<void> pump(WidgetTester tester, {Locale? locale}) async {
      await tester.binding.setSurfaceSize(const Size(600, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsPage(),
          ),
        ),
      );
    }

    Finder row(String text) => find.widgetWithText(ListTile, text);

    testWidgets('shows both sounds on and the default keys', (tester) async {
      await pump(tester);

      expect(find.text('Settings'), findsOneWidget);
      expect(
        tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .map((tile) => tile.value),
        [true, true],
      );
      expect(
        find.descendant(of: row('Turn left'), matching: find.text('Q')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row('Turn right'), matching: find.text('E')),
        findsOneWidget,
      );
      // Every command is listed.
      for (final command in BattleCommand.values) {
        expect(
          find.descendant(
            of: find.byType(ListTile),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  widget.data ==
                      AppLocalizationsEn().settingsCommand(command.name),
            ),
          ),
          findsOneWidget,
          reason: command.name,
        );
      }
      // Nothing to restore yet.
      final reset = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Restore the default commands'),
      );
      expect(reset.onPressed, isNull);
    });

    testWidgets('switches the sound effects and the ambience', (tester) async {
      await pump(tester);

      await tester.tap(find.widgetWithText(SwitchListTile, 'Sound effects'));
      await tester.pump();
      expect(cubit.state.soundEffects, isFalse);
      expect(cubit.state.ambience, isTrue);

      await tester.tap(find.widgetWithText(SwitchListTile, 'Ambience music'));
      await tester.pump();
      expect(cubit.state.ambience, isFalse);
      expect(
        tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .map((tile) => tile.value),
        [false, false],
      );
    });

    testWidgets('changes a command by choosing it and pressing a key', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(row('Turn left'));
      await tester.pumpAndSettle();
      expect(find.text('Press the key for “Turn left”'), findsOneWidget);

      // A modifier alone is not an answer; a key up is not either.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(
        cubit.state.keys.keyOf(BattleCommand.turnLeft),
        LogicalKeyboardKey.keyA,
      );
      expect(
        find.descendant(of: row('Turn left'), matching: find.text('A')),
        findsOneWidget,
      );
    });

    testWidgets('a key another command has is swapped with it', (tester) async {
      await pump(tester);

      await tester.tap(
        find.descendant(
          of: row('Turn left'),
          matching: find.byType(OutlinedButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: row('Turn left'), matching: find.text('E')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row('Turn right'), matching: find.text('Q')),
        findsOneWidget,
      );
    });

    testWidgets('Cancel leaves the command as it was', (tester) async {
      await pump(tester);

      await tester.tap(row('Turn left'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(cubit.state.keys, KeyBindings.defaults);
    });

    testWidgets('restores the default commands', (tester) async {
      await cubit.rebind(BattleCommand.turnLeft, LogicalKeyboardKey.keyA);
      await pump(tester);

      await tester.tap(find.text('Restore the default commands'));
      await tester.pump();

      expect(cubit.state.keys, KeyBindings.defaults);
      expect(
        find.descendant(of: row('Turn left'), matching: find.text('Q')),
        findsOneWidget,
      );
    });

    test('names the keys by what is printed on them, or by their name', () {
      expect(keyLabel(LogicalKeyboardKey.keyQ), 'Q');
      expect(keyLabel(LogicalKeyboardKey.arrowLeft), 'Arrow Left');
      expect(keyLabel(LogicalKeyboardKey.escape), 'Escape');
      // The space bar prints nothing.
      expect(keyLabel(LogicalKeyboardKey.space), 'Space');
    });

    testWidgets('speaks French', (tester) async {
      await pump(tester, locale: const Locale('fr'));

      expect(find.text('Paramètres'), findsOneWidget);
      expect(find.text('Effets sonores'), findsOneWidget);
      expect(find.text('Musique d’ambiance'), findsOneWidget);
    });

    testWidgets('opens over a page and goes back', (tester) async {
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => SettingsPage.open(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsNothing);
    });
  });
}
