import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/widgets/wait_format.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:battle_team/storage/cubit/storage_cubit.dart';
import 'package:battle_team/storage/widgets/every_second.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// {@template storage_panel}
/// The section's storage (M7 Issue 6): the portal and what a deployment
/// costs, the 24-hour lock with the time it has left (HQ-35), the recalls on
/// their way (HQ-32), the stored units with their type, HP and AP and a
/// Deploy button each (HQ-33), the prisoners the section holds (HQ-37) and
/// the answer to the last deployment.
///
/// It lists the section's own units only (HQ-29) and draws nothing of what
/// the section does not see (decision 237): an enemy near the portal blocks a
/// deployment in the list only when the section sees it; one it does not see
/// is the host's refusal, shown like the pre-check's. A button is off when
/// the client's pre-check expects the host to refuse the order, and says why;
/// a deployment that only waits for AP stays on and says how long (COMBAT-06).
/// Holds no rule: `StorageCubit` and `battle_client` answer.
/// {@endtemplate}
class StoragePanel extends StatelessWidget {
  /// {@macro storage_panel}
  const new({required this.onClose, super.key});

  /// Closes the panel.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<StorageCubit>();
    return BlocBuilder<StorageCubit, StorageState>(
      builder: (context, state) => EverySecond(
        builder: (context) {
          final stored = state.stored;
          final lock = cubit.lockRemaining;
          final checks = {
            for (final unit in stored) unit.unitId: cubit.checkDeploy(unit),
          };
          final blocked = checks.values.any(
            (check) =>
                check is PreCheckRefused &&
                check.reason == PreCheckRefusal.blockedByEnemy,
          );
          final recalls = [
            for (final unit in state.sectionUnits)
              if (cubit.recallRemaining(unit.unitId) case final left?)
                l10n.storageRecall(unit.unitType, formatWait(left)),
          ];
          final notice = state.notice;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.storageTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: onClose,
                    child: Text(l10n.storageClose),
                  ),
                ],
              ),
              Text(
                state.portal == null
                    ? l10n.storageNotInSight
                    : l10n.storagePortal,
              ),
              Text(l10n.storageDeployCost(formatAp(cubit.deployAp))),
              if (lock != null) Text(l10n.storageLocked(formatWait(lock))),
              if (blocked)
                Text(l10n.storageBlocked(formatAp(cubit.blockRadiusM))),
              if (recalls.isNotEmpty) ...[
                Semantics(header: true, child: Text(l10n.storageRecalls)),
                for (final line in recalls) Text(line),
              ],
              if (stored.isEmpty) Text(l10n.storageEmpty),
              for (final unit in stored)
                _StoredRow(
                  unit: unit,
                  ap: cubit.apNow(unit),
                  check: checks[unit.unitId]!,
                  onDeploy: () => cubit.deploy(unit.unitId),
                ),
              if (state.prisoners.isNotEmpty) ...[
                Semantics(
                  header: true,
                  child: Text(
                    l10n.storagePrisoners('${state.prisoners.length}'),
                  ),
                ),
                for (final prisoner in state.prisoners) Text(prisoner.unitType),
              ],
              if (notice != null && notice.order == 'deploy')
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

class _StoredRow extends StatelessWidget {
  const new({
    required this.unit,
    required this.ap,
    required this.check,
    required this.onDeploy,
  });

  final UnitView unit;
  final double? ap;
  final PreChecked check;
  final VoidCallback onDeploy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hint = switch (check) {
      PreCheckRefused(:final reason) => l10n.battleRefusal(reason.code),
      PreCheckPassed(:final apWait) when apWait > Duration.zero =>
        l10n.battleApWait(formatWait(apWait)),
      PreCheckPassed() => null,
    };
    final enabled = check is PreCheckPassed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                l10n.storageUnit(
                  unit.unitType,
                  unit.hp.toStringAsFixed(0),
                  unit.maxHp.toStringAsFixed(0),
                  ap?.toStringAsFixed(1) ?? '–',
                ),
              ),
            ),
            Semantics(
              label: l10n.storageDeployUnit(unit.unitType),
              button: true,
              enabled: enabled,
              excludeSemantics: true,
              onTap: enabled ? onDeploy : null,
              child: TextButton(
                onPressed: enabled ? onDeploy : null,
                child: Text(l10n.storageDeploy),
              ),
            ),
          ],
        ),
        ?switch (hint) {
          final text? => Text(text, style: const TextStyle(fontSize: 12)),
          null => null,
        },
      ],
    );
  }
}
