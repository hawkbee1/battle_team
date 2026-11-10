import 'dart:async';

import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/data/battle_repository.dart';
import 'package:battle_team/battle/data/battle_snapshot.dart';
import 'package:battle_team/battle/data/order_sender.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';

part 'shop_state.dart';

/// {@template shop_cubit}
/// The shop (M7 Issue 7): what the battle lets the section buy, with prices,
/// the section's money, and the orders `BuyUnit` and `BuyWeapon`.
///
/// What is on sale comes from the host (its `Roster`), never from data in the
/// app. A cubit of its own on the same [repository] as the other feature
/// cubits, fed by `repository.snapshots`. It computes no rule (decision 3):
/// [preCheck] tells the buttons what the host will refuse (room, lock, enemy
/// at the portal, money), for display only, and an order it expects refused
/// is not sent; a refusal it missed shows as the host's. A bought unit
/// arrives through the normal stream, next to the portal (HQ-46).
///
/// It logs on `battle_team.ShopCubit`: each order and its answer. Never a
/// unit or a position (decision 237).
/// {@endtemplate}
class ShopCubit extends Cubit<ShopState> {
  /// {@macro shop_cubit}
  new({required this.repository, required this.preCheck})
    : super(const ShopState());

  /// Where the battle's data comes from, the battle cubit's own.
  final BattleRepository repository;

  /// What the client expects the host to refuse (stack decision 8).
  final OrderPreCheck preCheck;

  static final _log = Logger('battle_team.ShopCubit');

  StreamSubscription<BattleSnapshot>? _subscription;

  /// Starts to follow the section's view. Call it before the battle cubit
  /// connects, so that no snapshot is missed.
  void start() {
    _subscription = repository.snapshots.listen(_onSnapshot);
  }

  void _onSnapshot(BattleSnapshot snapshot) {
    final team = snapshot.team;
    emit(
      state.copyWith(
        roster: snapshot.roster,
        section: snapshot.section,
        units: snapshot.units,
        team: team,
        sectionId: snapshot.sectionId,
        portal: () => snapshot.hqs
            .where((hq) => hq.team == team)
            .map((hq) => hq.position)
            .firstOrNull,
        revision: state.revision + 1,
      ),
    );
  }

  /// What the client expects of buying [unit] (ECO-04, HQ-46): the enemies it
  /// knows are the ones the section sees; an unseen one blocks all the same
  /// and only the host says so (decision 237).
  PreChecked checkUnit(RosterUnit unit) {
    final section = state.section;
    final time = repository.battleTime;
    final team = state.team;
    if (section == null || time == null || team == null) {
      return const PreCheckPassed();
    }
    return preCheck.buyUnit(
      unit: unit,
      section: section,
      owned: state.ownUnits,
      team: team,
      portal: state.portal,
      seen: state.units.values,
      time: time,
    );
  }

  /// What the client expects of buying [weapon] (COMBAT-27). Before the
  /// host's first view it expects nothing: the host decides.
  PreChecked checkWeapon(RosterWeapon weapon) {
    final section = state.section;
    if (section == null) {
      return const PreCheckPassed();
    }
    return preCheck.buyWeapon(weapon: weapon, section: section);
  }

  /// How long the lock has to run at the battle time now; null when the
  /// section is not locked (HQ-35).
  Duration? get lockRemaining {
    final until = state.section?.lockedUntil;
    final time = repository.battleTime;
    return until != null && time != null && until > time ? until - time : null;
  }

  /// Buys a unit of [unitType] from the roster (ECO-04, ECO-05).
  Future<void> buyUnit(String unitType) async {
    final unit = state.roster?.units
        .where((unit) => unit.unitType == unitType)
        .firstOrNull;
    if (unit == null) return;
    if (checkUnit(unit) case PreCheckRefused(:final reason)) {
      _refuse('buy_unit', unitType, reason);
      return;
    }
    await _order('buy_unit', unitType, BuyUnit(unitType: unitType));
  }

  /// Buys [weapon] from the roster, for the section's storage (COMBAT-27).
  Future<void> buyWeapon(String weapon) async {
    final item = state.roster?.weapons
        .where((item) => item.weapon == weapon)
        .firstOrNull;
    if (item == null) return;
    if (checkWeapon(item) case PreCheckRefused(:final reason)) {
      _refuse('buy_weapon', weapon, reason);
      return;
    }
    await _order('buy_weapon', weapon, BuyWeapon(weapon: weapon));
  }

  void _refuse(String name, String item, PreCheckRefusal reason) {
    _log.warning('order $name not sent: ${reason.code}');
    emit(
      state.copyWith(
        notice: () =>
            PurchaseNotice(order: name, item: item, refusal: reason.code),
      ),
    );
  }

  Future<void> _order(String name, String item, Order order) async {
    final refusal = await sendOrder(_log, repository, name, order);
    if (isClosed) return;
    emit(
      state.copyWith(
        notice: () => PurchaseNotice(order: name, item: item, refusal: refusal),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
