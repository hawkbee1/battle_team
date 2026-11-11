import 'package:battle_team/alerts/cubit/alerts_cubit.dart';
import 'package:battle_team/battle/widgets/wait_format.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// {@template alert_banners}
/// The alerts the player has not dismissed (M7 Issue 9): a relic of the
/// section's team taken (RELIC-10, decision 233, also those it missed while
/// away) and a victory countdown that started or was reset (RELIC-16). Each
/// banner stays until its Dismiss button is pressed, and says what the host
/// told the section and nothing more (decision 237). [builder] puts each one
/// in the app's panel.
/// {@endtemplate}
class AlertBanners extends StatelessWidget {
  /// {@macro alert_banners}
  const new({required this.builder, super.key});

  /// Wraps a banner's content in the screen's panel.
  final Widget Function(Widget child) builder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<AlertsCubit, AlertsState>(
      buildWhen: (before, after) => before.banners != after.banners,
      builder: (context, state) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final banner in state.banners)
            Padding(
              key: ValueKey(banner.id),
              padding: const EdgeInsets.only(bottom: 6),
              child: builder(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(switch (banner) {
                          RelicTaken(:final team, :final relicId) =>
                            l10n.alertsRelicTaken(team, relicId),
                          CountdownStarted(:final team, :final remaining) =>
                            l10n.alertsCountdownStarted(
                              team,
                              formatWait(remaining),
                            ),
                          CountdownReset() => l10n.alertsCountdownReset,
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () =>
                          context.read<AlertsCubit>().dismiss(banner.id),
                      child: Text(l10n.alertsDismiss),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
