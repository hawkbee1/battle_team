import 'package:battle_client/battle_client.dart';
import 'package:battle_team/battle/cubit/battle_cubit.dart';
import 'package:battle_team/battle/widgets/wait_format.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// {@template move_panel}
/// The move the player previewed (M7 Issue 8): its AP cost against the unit's
/// AP and when it arrives, the wait for AP it needs when it lacks them
/// (COMBAT-06), with Confirm and Cancel; or why the client expects the host to
/// refuse it, with nothing to confirm. After a confirmed move, the host's
/// arrival when it differs from the preview's: the host's answer counts and
/// is shown, not argued (stack decision 8).
///
/// Holds no rule: `MovePreviewer` of `battle_client` planned it, from the
/// section's own view (decision 237).
/// {@endtemplate}
class MovePanel extends StatelessWidget {
  /// {@macro move_panel}
  const new({
    required this.pending,
    required this.note,
    required this.ap,
    required this.time,
    required this.onConfirm,
    required this.onCancel,
    super.key,
  });

  /// The previewed move, if any.
  final PendingMove? pending;

  /// The host's arrival, when it differs from the preview's.
  final ArrivalNote? note;

  /// The unit's AP now, when known.
  final double? ap;

  /// The battle time now, as the client shows it.
  final Duration? time;

  /// Sends the previewed move.
  final VoidCallback onConfirm;

  /// Drops the previewed move.
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final plan = pending?.plan;
    final difference = note?.difference;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        switch (plan) {
          MovePreview(:final costAp, :final arrivesAt, :final apWait) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.moveCost(
                  formatAp(double.parse(costAp.toStringAsFixed(1))),
                  ap == null
                      ? '–'
                      : formatAp(double.parse(ap!.toStringAsFixed(1))),
                  formatWait(time == null ? Duration.zero : arrivesAt - time!),
                ),
              ),
              if (apWait > Duration.zero)
                Text(l10n.moveWait(formatWait(apWait))),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: onConfirm,
                    child: Text(l10n.moveConfirm),
                  ),
                  TextButton(onPressed: onCancel, child: Text(l10n.moveCancel)),
                ],
              ),
            ],
          ),
          MoveRefused(:final reason) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.moveRefused(l10n.battleRefusal(reason.code))),
              TextButton(onPressed: onCancel, child: Text(l10n.moveCancel)),
            ],
          ),
          _ => const SizedBox.shrink(),
        },
        if (difference != null && difference != Duration.zero)
          Text(
            difference.isNegative
                ? l10n.moveSooner(formatWait(-difference))
                : l10n.moveLater(formatWait(difference)),
          ),
      ],
    );
  }
}
