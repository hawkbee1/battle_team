import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/widgets/wait_format.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:battle_team/storage/cubit/storage_cubit.dart';
import 'package:battle_team/storage/widgets/every_second.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// {@template store_button}
/// The button that stores the selected own unit [unit], on the field (HQ-31,
/// HQ-32): "Store now" next to its portal, else "Recall" with the time the
/// recall takes, so that the player sees which before sending. While a recall
/// runs it says when the unit is stored; a unit that cannot be stored says
/// why. Holds no rule: `StorageCubit` and `battle_client` answer.
/// {@endtemplate}
class StoreButton extends StatelessWidget {
  /// {@macro store_button}
  const new({required this.unit, super.key});

  /// The selected unit, one of the section's, on the field.
  final UnitView unit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<StorageCubit>();
    return BlocBuilder<StorageCubit, StorageState>(
      builder: (context, state) => EverySecond(
        builder: (context) {
          final notice = state.notice;
          final ours = notice != null && notice.unitId == unit.unitId;
          final plan = cubit.planStore(unit);
          final recalling = cubit.recallRemaining(unit.unitId);
          final (label, hint) = switch (plan) {
            StoredNow() => (l10n.storageStoreNow, null),
            RecalledAfter(:final takes) => (
              l10n.storageRecallIn(formatWait(takes)),
              null,
            ),
            StoreNotPossible(:final reason) => (
              l10n.storageStoreNow,
              recalling == null
                  ? l10n.battleRefusal(reason.code)
                  : l10n.storageRecalling(formatWait(recalling)),
            ),
          };
          final onTap = plan is StoreNotPossible
              ? null
              : () => cubit.storeOrRecall(unit.unitId);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: l10n.storageStoreUnit(unit.unitType),
                button: true,
                enabled: onTap != null,
                excludeSemantics: true,
                onTap: onTap,
                child: TextButton(onPressed: onTap, child: Text(label)),
              ),
              ?switch (hint) {
                final text? => Text(text),
                null => null,
              },
              if (ours && notice.order != 'deploy')
                Text(switch (notice.refusal) {
                  null => l10n.battleOrderAccepted(
                    l10n.battleOrderName(notice.order),
                  ),
                  final reason => l10n.battleOrderRefused(
                    l10n.battleOrderName(notice.order),
                    l10n.battleRefusal(reason),
                  ),
                }),
            ],
          );
        },
      ),
    );
  }
}
