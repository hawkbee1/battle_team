import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/widgets/wait_format.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:battle_team/shop/cubit/shop_cubit.dart';
import 'package:battle_team/storage/widgets/every_second.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// {@template shop_panel}
/// The shop (M7 Issue 7): the section's money, the unit types the host lets
/// it buy with their prices (ECO-04, ECO-05), and, for the selected own unit,
/// the weapons it can use with theirs (COMBAT-26, COMBAT-27). The list is the
/// host's `Roster`: the app holds no copy of the plan's prices, and the test
/// unit is there only where the battle allows it (UNIT-44).
///
/// A button is off when the client's pre-check expects the host to refuse the
/// order (no room, the lock, an enemy at the portal, money) and says why in
/// the host's own words; the host's answer to the last purchase is shown
/// under the list. A bought unit appears through the normal stream, next to
/// the portal (HQ-46). The guild camp and the skill tree are not sold here.
/// Holds no rule: `ShopCubit` and `battle_client` answer. It shows the
/// section's own money only (HQ-29).
/// {@endtemplate}
class ShopPanel extends StatelessWidget {
  /// {@macro shop_panel}
  const new({required this.onClose, this.selected, super.key});

  /// Closes the panel.
  final VoidCallback onClose;

  /// The selected unit, when it is one of the section's own: the weapons
  /// shown are the ones it may equip.
  final UnitView? selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ShopCubit>();
    return BlocBuilder<ShopCubit, ShopState>(
      builder: (context, state) => EverySecond(
        builder: (context) {
          final roster = state.roster;
          final section = state.section;
          final lock = cubit.lockRemaining;
          final own = switch (selected) {
            final unit? when unit.private != null => unit,
            _ => null,
          };
          final usable = own == null
              ? const <String>[]
              : [
                  for (final unit in roster?.units ?? const <RosterUnit>[])
                    if (unit.unitType == own.unitType) ...unit.weapons,
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
                      l10n.shopTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(onPressed: onClose, child: Text(l10n.shopClose)),
                ],
              ),
              if (roster == null || section == null)
                Text(l10n.shopWaiting)
              else ...[
                Text(l10n.shopMoney(section.money)),
                if (lock != null) Text(l10n.shopLocked(formatWait(lock))),
                Semantics(header: true, child: Text(l10n.shopUnits)),
                for (final unit in roster.units)
                  _ShopRow(
                    name: l10n.unitTypeName(unit.unitType),
                    price: unit.price,
                    check: cubit.checkUnit(unit),
                    onBuy: () => cubit.buyUnit(unit.unitType),
                  ),
                Semantics(
                  header: true,
                  child: Text(
                    own == null
                        ? l10n.shopWeapons
                        : l10n.shopWeaponsFor(l10n.unitTypeName(own.unitType)),
                  ),
                ),
                if (own == null)
                  Text(l10n.shopPickUnit)
                else if (usable.isEmpty)
                  Text(l10n.shopNoWeapons)
                else ...[
                  Text(l10n.shopWeaponsNote),
                  for (final weapon in roster.weapons)
                    if (usable.contains(weapon.weapon))
                      _ShopRow(
                        name: l10n.battleWeapon(weapon.weapon),
                        price: weapon.price,
                        check: cubit.checkWeapon(weapon),
                        onBuy: () => cubit.buyWeapon(weapon.weapon),
                      ),
                ],
                if (notice != null)
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
            ],
          );
        },
      ),
    );
  }
}

class _ShopRow extends StatelessWidget {
  const new({
    required this.name,
    required this.price,
    required this.check,
    required this.onBuy,
  });

  final String name;
  final int price;
  final PreChecked check;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cost = l10n.shopPrice(price);
    final hint = switch (check) {
      PreCheckRefused(:final reason) => l10n.battleRefusal(reason.code),
      PreCheckPassed() => null,
    };
    final enabled = check is PreCheckPassed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text('$name · $cost')),
            Semantics(
              label: l10n.shopBuyItem(name, cost),
              button: true,
              enabled: enabled,
              excludeSemantics: true,
              onTap: enabled ? onBuy : null,
              child: TextButton(
                onPressed: enabled ? onBuy : null,
                child: Text(l10n.shopBuy),
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
