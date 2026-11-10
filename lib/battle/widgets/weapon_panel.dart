import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/cubit/battle_cubit.dart';
import 'package:battle_team/battle/widgets/wait_format.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// {@template weapon_panel}
/// The weapon of the selected own unit [unit]: its name, its rounds, whether
/// it is busy reloading or swapping, and the buttons that fire it (M7 Issue
/// 5). Fire shoots at the unit's target from above, and along [aim] from first
/// person (COMBAT-14); Fire at position arms the next tap on the ground
/// (COMBAT-12); Reload (COMBAT-33); one Swap button for each spare weapon the
/// unit may take (COMBAT-26, COMBAT-28).
///
/// A button is off when the client's pre-check expects the host to refuse the
/// order (`BattleCubit.checkFire` and its siblings: display only, the host
/// decides), and says why in the section's language; a shot that only waits
/// for AP stays on (COMBAT-06) and says how long. Holds no rule: the cubit
/// and `battle_client` answer.
/// {@endtemplate}
class WeaponPanel extends StatelessWidget {
  /// {@macro weapon_panel}
  const new({required this.unit, this.aim, super.key});

  /// The selected unit, one of the section's.
  final UnitView unit;

  /// The direction the eyes look along, from first person; null from above.
  final Direction Function()? aim;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.watch<BattleCubit>();
    final aim = this.aim;
    final weapon = unit.weapon;
    final private = unit.private!;
    final time = cubit.battleTime;
    final busyUntil = private.busyUntil;
    final busy = time != null && busyUntil != null && busyUntil > time
        ? busyUntil - time
        : null;
    final firing = aim == null ? cubit.checkFire() : cubit.checkFireAimed();
    final atPosition = cubit.checkFireAtPosition();
    final reloading = cubit.checkReload();
    final swaps = cubit.swappableWeapons;
    final swapHint = swaps.isEmpty
        ? null
        : _refusal(l10n, cubit.checkSwap(swaps.first));
    final hint = _hint(l10n, firing);
    final target = cubit.state.target;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          [
            if (weapon == null) ...[
              l10n.battleNoWeapon,
            ] else ...[
              l10n.battleWeapon(weapon),
              l10n.battleRounds(
                '${private.rounds}',
                '${cubit.magazineOf(unit) ?? '?'}',
              ),
            ],
            if (busy != null) l10n.battleWeaponBusy(busy.inSeconds.toString()),
          ].join(' · '),
        ),
        if (aim == null && target != null)
          Text(l10n.battleTarget(target.unitType)),
        if (cubit.state.groundFire) Text(l10n.battleHelpFireAtPosition),
        if (hint != null) Text(hint),
        Wrap(
          children: [
            TextButton(
              onPressed: firing is PreCheckPassed
                  ? () => aim == null
                        ? cubit.fireSelected()
                        : cubit.fireAimed(aim())
                  : null,
              child: Text(l10n.battleFire),
            ),
            TextButton(
              onPressed: atPosition is PreCheckPassed
                  ? cubit.toggleGroundFire
                  : null,
              child: Text(l10n.battleFireAtPosition),
            ),
            TextButton(
              onPressed: reloading is PreCheckPassed ? cubit.reload : null,
              child: Text(l10n.battleReload),
            ),
            for (final spare in swaps)
              TextButton(
                onPressed: cubit.checkSwap(spare) is PreCheckPassed
                    ? () => cubit.swap(spare)
                    : null,
                child: Text(l10n.battleSwapTo(l10n.battleWeapon(spare))),
              ),
          ],
        ),
        if (swapHint != null) Text(swapHint),
      ],
    );
  }

  /// What the Fire button says about [firing]: why it is off, or how long the
  /// shot waits for AP.
  static String? _hint(AppLocalizations l10n, PreChecked firing) =>
      switch (firing) {
        PreCheckRefused() => _refusal(l10n, firing),
        PreCheckPassed(:final apWait) when apWait > Duration.zero =>
          l10n.battleApWait(formatWait(apWait)),
        PreCheckPassed() => null,
      };

  static String? _refusal(AppLocalizations l10n, PreChecked checked) =>
      switch (checked) {
        PreCheckRefused(:final reason) => l10n.battleRefusal(reason.code),
        PreCheckPassed() => null,
      };
}

/// {@template aim_reticle}
/// The cross in the middle of the screen from first person: where
/// `FireAimed` goes (COMBAT-14). The shot's spread is the host's (decision
/// 183), so the reticle shows the aim and promises no hit.
/// {@endtemplate}
class AimReticle extends StatelessWidget {
  /// {@macro aim_reticle}
  const new({super.key});

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: Center(
      child: SizedBox.square(
        dimension: 28,
        child: Stack(
          children: [
            Center(child: _Bar(width: 28, height: 2)),
            Center(child: _Bar(width: 2, height: 28)),
          ],
        ),
      ),
    ),
  );
}

class _Bar extends StatelessWidget {
  const new({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: const DecoratedBox(
      decoration: BoxDecoration(color: Color(0xCCFFFFFF)),
    ),
  );
}
