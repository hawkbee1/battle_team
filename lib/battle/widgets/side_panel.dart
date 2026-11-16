import 'dart:math' as math;

import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/cubit/battle_cubit.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:battle_team/shop/widgets/shop_panel.dart';
import 'package:battle_team/storage/cubit/storage_cubit.dart';
import 'package:battle_team/storage/widgets/every_second.dart';
import 'package:battle_team/storage/widgets/storage_panel.dart';
import 'package:battle_team/storage/widgets/store_button.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// The tabs of the side panel, in the order they show.
enum SideTab {
  /// The section's units on the field.
  units,

  /// The section's stored units.
  storage,

  /// What the section can buy.
  shop,
}

/// {@template side_panel}
/// The side panel of the battle view, one panel with a tab bar: **Units**
/// (the section's units on the field with their HP and AP, a button to centre
/// the view on each and one to store it), **Storage** (its stored units, with
/// the button that deploys each while the section has room on the field) and
/// **Shop**. The bodies are the panels of the storage (M7 Issue 6) and of the
/// shop (M7 Issue 7); this holds no rule, and shows only the section's own
/// units (HQ-29, decision 237).
///
/// No taller than its `maxHeight`: the tab bar stays, the body scrolls. It
/// draws no background: the view puts it in its panel.
/// {@endtemplate}
class SidePanel extends StatefulWidget {
  /// {@macro side_panel}
  const new({
    required this.maxHeight,
    required this.onCentreAll,
    required this.onCentreUnit,
    super.key,
  });

  /// The most height the panel takes.
  final double maxHeight;

  /// Looks at the section's units again.
  final VoidCallback onCentreAll;

  /// Looks at the place where a unit on the field stands.
  final void Function(Position at) onCentreUnit;

  @override
  State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<SidePanel>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: SideTab.values.length,
    vsync: this,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: math.max(120, widget.maxHeight)),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              controller: _controller,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: l10n.sideUnits),
                Tab(
                  child: BlocSelector<StorageCubit, StorageState, int>(
                    selector: (state) => state.stored.length,
                    builder: (context, stored) =>
                        Text(l10n.storageOpen('$stored')),
                  ),
                ),
                Tab(text: l10n.shopOpen),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 8),
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) =>
                      switch (SideTab.values[_controller.index]) {
                        SideTab.units => _UnitsTab(
                          onCentreAll: widget.onCentreAll,
                          onCentreUnit: widget.onCentreUnit,
                        ),
                        SideTab.storage => const StoragePanel(),
                        SideTab.shop =>
                          BlocSelector<BattleCubit, BattleState, UnitView?>(
                            selector: (state) => state.selected,
                            builder: (context, selected) =>
                                ShopPanel(selected: selected),
                          ),
                      },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The section's units on the field: a tap on the unit selects it, a button
/// centres the view on it and another stores it (`StoreButton`).
class _UnitsTab extends StatelessWidget {
  const new({required this.onCentreAll, required this.onCentreUnit});

  final VoidCallback onCentreAll;
  final void Function(Position at) onCentreUnit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<BattleCubit>();
    return BlocBuilder<BattleCubit, BattleState>(
      builder: (context, state) => EverySecond(
        builder: (context) {
          final active = [
            for (final unit in state.sectionUnits)
              if (unit.private?.place != UnitPlace.stored) unit,
          ];
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: onCentreAll,
                child: Text(l10n.battleCentre),
              ),
              if (active.isEmpty) Text(l10n.unitsEmpty),
              for (final unit in active)
                _UnitRow(
                  unit: unit,
                  ap: cubit.apNow(unit),
                  selected: unit.unitId == state.selectedId,
                  onSelect: () => cubit.select(unit.unitId),
                  onCentre: switch (unit.position) {
                    final at? => () => onCentreUnit(at),
                    null => null,
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _UnitRow extends StatelessWidget {
  const new({
    required this.unit,
    required this.ap,
    required this.selected,
    required this.onSelect,
    required this.onCentre,
  });

  final UnitView unit;
  final double? ap;
  final bool selected;
  final VoidCallback onSelect;

  /// Null for a unit that is not on the field: nowhere to look at.
  final VoidCallback? onCentre;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          onPressed: onSelect,
          child: Text(
            l10n.storageUnit(
              unit.unitType,
              unit.hp.toStringAsFixed(0),
              unit.maxHp.toStringAsFixed(0),
              ap?.toStringAsFixed(1) ?? '–',
            ),
            style: TextStyle(
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        // A wrap: the store button's label and hint are longer in some
        // languages than the panel is wide.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: l10n.unitsCentreOn(unit.unitType),
              onPressed: onCentre,
              icon: const Icon(Icons.my_location, size: 20),
            ),
            StoreButton(unit: unit),
          ],
        ),
      ],
    );
  }
}
