import 'dart:async';

import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/cubit/battle_cubit.dart';
import 'package:battle_team/battle/data/battle_repository.dart';
import 'package:battle_team/battle/data/battle_snapshot.dart';
import 'package:battle_team/battle/data/order_sender.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';

part 'storage_state.dart';

/// {@template storage_cubit}
/// The section's storage (M7 Issue 6): its stored units, the lock, the
/// recalls, the prisoners, and the orders `Store`, `Recall` and `Deploy`.
///
/// A cubit of its own, on the same [repository] as the `BattleCubit`, so that
/// the battle cubit stays about the field: the two read the same snapshots
/// and share nothing else. It reads the section's own view only (HQ-29) and
/// computes no rule (decision 3): [preCheck] tells the buttons what the host
/// will refuse, for display only, and an order it expects refused is not
/// sent; a refusal it missed shows as the host's.
///
/// It logs on `battle_team.StorageCubit`: each order and its answer. Never a
/// unit or a position (decision 237).
/// {@endtemplate}
class StorageCubit extends Cubit<StorageState> {
  /// {@macro storage_cubit}
  new({required this.repository, required this.preCheck})
    : super(const StorageState());

  /// Where the battle's data comes from, the battle cubit's own.
  final BattleRepository repository;

  /// What the client expects the host to refuse (stack decision 8).
  final OrderPreCheck preCheck;

  static final _log = Logger('battle_team.StorageCubit');

  StreamSubscription<BattleSnapshot>? _subscription;

  /// Starts to follow the section's view. Call it before the battle cubit
  /// connects, so that no snapshot is missed.
  void start() {
    _subscription = repository.snapshots.listen(_onSnapshot);
  }

  void _onSnapshot(BattleSnapshot snapshot) {
    final team = snapshot.team;
    final section = snapshot.section;
    emit(
      state.copyWith(
        units: snapshot.units,
        sectionId: snapshot.sectionId,
        portal: () => snapshot.hqs
            .where((hq) => hq.team == team)
            .map((hq) => hq.position)
            .firstOrNull,
        lockedUntil: () => section?.lockedUntil,
        prisoners: section?.prisoners ?? const [],
        recalls: snapshot.recalls,
        revision: state.revision + 1,
      ),
    );
  }

  /// The battle time now, as the client shows it.
  Duration? get battleTime => repository.battleTime;

  /// The AP of [unit] now, when the section owns it.
  double? apNow(UnitView unit) => switch (unit.private) {
    final private? => repository.apNow(private.ap),
    null => null,
  };

  /// AP a deployment costs (`storage.deploy_ap`, HQ-33).
  double get deployAp => preCheck.storage.deployAp;

  /// How close an enemy blocks a deployment, in metres
  /// (`storage.deploy_block_radius_m`, HQ-36).
  double get blockRadiusM => preCheck.storage.deployBlockRadiusM;

  /// How long the lock has to run at the battle time now; null when the
  /// section is not locked (HQ-35).
  Duration? get lockRemaining {
    final until = state.lockedUntil;
    final time = battleTime;
    return until != null && time != null && until > time ? until - time : null;
  }

  /// How long the recall of [unitId] has to run; null when none does.
  Duration? recallRemaining(String unitId) {
    final until = state.recalls[unitId];
    final time = battleTime;
    return until != null && time != null && until > time ? until - time : null;
  }

  /// What a store order for the field unit [unit] does: stored at once next
  /// to the portal, or a recall from afar (HQ-31, HQ-32).
  StorePlan planStore(UnitView unit) {
    final time = battleTime;
    if (time == null) return const StoreNotPossible(PreCheckRefusal.notOnField);
    return preCheck.store(
      unit: unit,
      portal: state.portal,
      units: state.sectionUnits,
      time: time,
      recalledUntil: state.recalls[unit.unitId],
    );
  }

  /// What the client expects of deploying the stored unit [unit] (HQ-33 to
  /// HQ-36). The enemies it knows are the ones the section sees: an unseen
  /// one blocks all the same, and only the host says so (decision 237).
  PreChecked checkDeploy(UnitView unit) {
    final time = battleTime;
    if (time == null) return const PreCheckRefused(PreCheckRefusal.notStored);
    return preCheck.deploy(
      unit: unit,
      portal: state.portal,
      seen: state.units.values,
      time: time,
      lockedUntil: state.lockedUntil,
    );
  }

  /// Stores [unitId] at once, next to the portal (HQ-31), or recalls it from
  /// afar (HQ-32), as [planStore] says.
  Future<void> storeOrRecall(String unitId) async {
    final unit = _own(unitId);
    if (unit == null) return;
    switch (planStore(unit)) {
      case StoredNow():
        await _order(unitId, 'store', Store(unitId: unitId));
      case RecalledAfter():
        await _order(unitId, 'recall', Recall(unitId: unitId));
      case StoreNotPossible(:final reason):
        _refuse(unitId, 'store', reason);
    }
  }

  /// Brings the stored unit [unitId] out next to the portal (HQ-33).
  Future<void> deploy(String unitId) async {
    final unit = _own(unitId);
    if (unit == null) return;
    if (checkDeploy(unit) case PreCheckRefused(:final reason)) {
      _refuse(unitId, 'deploy', reason);
      return;
    }
    await _order(unitId, 'deploy', Deploy(unitId: unitId));
  }

  UnitView? _own(String unitId) {
    final unit = state.units[unitId];
    return unit != null && unit.sectionId == state.sectionId ? unit : null;
  }

  void _refuse(String unitId, String name, PreCheckRefusal reason) {
    _log.warning('order $name not sent: ${reason.code}');
    emit(
      state.copyWith(
        notice: () =>
            OrderNotice(order: name, unitId: unitId, refusal: reason.code),
      ),
    );
  }

  Future<void> _order(String unitId, String name, Order order) async {
    final refusal = await sendOrder(_log, repository, name, order);
    if (isClosed) return;
    emit(
      state.copyWith(
        notice: () =>
            OrderNotice(order: name, unitId: unitId, refusal: refusal),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
