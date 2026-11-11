import 'package:battle_team/alerts/cubit/alerts_cubit.dart';
import 'package:battle_team/battle/widgets/wait_format.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:battle_team/storage/widgets/every_second.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// {@template status_strip}
/// What every section knows, whatever it sees (MAP-49, decision 232), shown
/// all the time: how many relics each team owns and how many are free, and
/// the victory countdown of the team that holds the relics (RELIC-16), counting
/// down between the host's messages by the battle time of the client. Nothing
/// of any unit (decision 237). Empty until the host's view came.
/// {@endtemplate}
class StatusStrip extends StatelessWidget {
  /// {@macro status_strip}
  const new({required this.builder, super.key});

  /// Wraps the strip's content in the screen's panel, which is not shown
  /// while the strip is empty.
  final Widget Function(Widget child) builder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<AlertsCubit, AlertsState>(
      builder: (context, state) {
        if (state.relics.isEmpty && state.hold == null) {
          return const SizedBox.shrink();
        }
        final free = state.owned(null);
        final hold = state.hold;
        return builder(
          Wrap(
            spacing: 12,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (state.relics.isNotEmpty) Text('${l10n.alertsRelics}:'),
              for (final team in state.owners)
                Text(l10n.alertsRelicsOwned(team, '${state.owned(team)}')),
              if (free > 0) Text(l10n.alertsRelicsFree('$free')),
              if (hold != null)
                EverySecond(
                  builder: (context) => Text(
                    l10n.alertsCountdown(
                      hold.team,
                      formatWait(
                        remainingOf(
                          hold.winsAt,
                          context.read<AlertsCubit>().battleTime,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
