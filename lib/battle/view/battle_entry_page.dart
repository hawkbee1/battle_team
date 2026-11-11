import 'dart:async';

import 'package:battle_team/authentication/widgets/log_out_button.dart';
import 'package:battle_team/battle/cubit/battle_entry_cubit.dart';
import 'package:battle_team/battle/data/battle_locator.dart';
import 'package:battle_team/battle/data/battle_repository_factory.dart';
import 'package:battle_team/battle/view/battle_page.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

Widget _battlePage(BuildContext context) => const BattlePage();

/// {@template battle_entry_page}
/// What a signed-in account sees first: it looks for the running battles
/// (`BattleLocator`) and opens the only one the account is in with a
/// repository of its own (the `BattleRepositoryFactory`'s, closed when the
/// battle goes). Otherwise it lists the running battles, each marked "You are
/// in" or "Join", and the player picks one (so does the battle screen's
/// Switch battle, which comes back here): a battle he is in is entered, one he
/// is not is joined after he confirms (SOC-30: a new section in its war) and
/// then entered. Or it says there is none or why the search failed, with a
/// button to look again and one to log out. The battle's screen is built by
/// [pageBuilder], so that tests run without a GPU.
///
/// Needs a `BattleLocator`, a `BattleRepositoryFactory` and an
/// `AuthenticationCubit` above it.
/// {@endtemplate}
class BattleEntryPage extends StatelessWidget {
  /// {@macro battle_entry_page}
  const new({
    required this.accountId,
    this.pageBuilder = _battlePage,
    super.key,
  });

  /// The signed-in account.
  final String accountId;

  /// Builds the battle's screen, with its repository in the tree.
  final WidgetBuilder pageBuilder;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = BattleEntryCubit(
          locator: context.read<BattleLocator>(),
          accountId: accountId,
        );
        unawaited(cubit.locate());
        return cubit;
      },
      child: BlocBuilder<BattleEntryCubit, BattleEntryState>(
        builder: (context, state) => switch (state) {
          BattleEntryFound(:final assignment) => RepositoryProvider(
            key: ValueKey(assignment),
            create: (context) =>
                context.read<BattleRepositoryFactory>().create(assignment),
            dispose: (repository) => unawaited(repository.close()),
            child: Builder(builder: pageBuilder),
          ),
          _ => _Waiting(state: state),
        },
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const new({required this.state});

  final BattleEntryState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<BattleEntryCubit>();
    final message = switch (state) {
      BattleEntryFailed(:final unreachable) => l10n.battleEntryProblem(
        unreachable ? 'unreachable' : 'other',
      ),
      _ => l10n.battleEntryNone,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.battleTitle),
        actions: const [LogOutButton()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  switch (state) {
                    BattleEntryLocating() => _Progress(
                      label: l10n.battleEntryLooking,
                    ),
                    BattleEntryJoining() => _Progress(
                      label: l10n.battleEntryJoining,
                    ),
                    BattleEntryChoosing(:final battles, :final problem) =>
                      _Battles(battles: battles, problem: problem),
                    _ => Text(message, textAlign: TextAlign.center),
                  },
                  if (state is! BattleEntryLocating &&
                      state is! BattleEntryJoining) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: FilledButton(
                        onPressed: state is BattleEntryChoosing
                            ? cubit.choose
                            : cubit.locate,
                        child: Text(l10n.battleEntryRetry),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const new({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const CircularProgressIndicator(),
      const SizedBox(height: 16),
      Text(label),
    ],
  );
}

/// The running battles: the ones the account is in enter, the others ask
/// before they join their war.
class _Battles extends StatelessWidget {
  const new({required this.battles, required this.problem});

  final List<AccountBattle> battles;
  final BattleJoinFailureReason? problem;

  Future<void> _pick(BuildContext context, AccountBattle battle) async {
    final cubit = context.read<BattleEntryCubit>();
    if (!battle.joined) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _JoinDialog(war: battle.warId ?? ''),
      );
      if (confirmed != true) return;
    }
    await cubit.enter(battle);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.battleEntryChoose,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (problem case final reason?) ...[
          const SizedBox(height: 8),
          Text(
            l10n.battleEntryJoinProblem(reason.name),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        for (final battle in battles)
          Card(
            child: ListTile(
              title: Text(l10n.battleEntryBattleOn(battle.battle.mapId)),
              subtitle: switch (battle.warId) {
                final war? => Text(l10n.battleEntryWar(war)),
                null => null,
              },
              trailing: battle.joined
                  ? Text(l10n.battleEntryYouAreIn)
                  : FilledButton.tonal(
                      onPressed: () => unawaited(_pick(context, battle)),
                      child: Text(l10n.battleEntryJoin),
                    ),
              onTap: () => unawaited(_pick(context, battle)),
            ),
          ),
      ],
    );
  }
}

/// Asks before the account joins a war: its section stays in the team for
/// the whole battle (SOC-09).
class _JoinDialog extends StatelessWidget {
  const new({required this.war});

  final String war;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.battleEntryJoinTitle),
      content: Text(l10n.battleEntryJoinBody(war)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.battleEntryCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.battleEntryJoin),
        ),
      ],
    );
  }
}
