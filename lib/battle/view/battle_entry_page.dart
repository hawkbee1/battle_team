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
/// What a signed-in account sees first: it looks for the account's battle
/// (`BattleLocator`), opens it with a repository of its own (the
/// `BattleRepositoryFactory`'s, closed when the battle goes), or says there is
/// none or why the search failed, with a button to look again and one to log
/// out. The battle's screen is built by [pageBuilder], so that tests run
/// without a GPU.
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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state is BattleEntryLocating) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.battleEntryLooking),
                ] else ...[
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: context.read<BattleEntryCubit>().locate,
                    child: Text(l10n.battleEntryRetry),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
