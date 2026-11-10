import 'dart:async';

import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/data/battle_repository.dart';
import 'package:battle_team/battle/data/battle_snapshot.dart';
import 'package:battle_team/battle/data/connection_status.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'battle_state.dart';

/// {@template battle_cubit}
/// Plays one battle as one player through [repository]: signs in, then keeps
/// the section's view and sends the player's orders. The host checks every
/// order (stack decision 8). The 3D view listens to it (Observer).
/// {@endtemplate}
class BattleCubit extends Cubit<BattleState> {
  /// {@macro battle_cubit}
  new({required this.repository}) : super(const BattleState());

  /// Where the battle's data comes from.
  final BattleRepository repository;

  final _subscriptions = <StreamSubscription<Object?>>[];

  /// Signs in, then connects to the battle.
  Future<void> start() async {
    try {
      await repository.signIn();
    } on Object catch (error) {
      emit(state.copyWith(status: BattleStatus.failed, problem: '$error'));
      return;
    }
    _subscriptions
      ..add(repository.connection.listen(_onConnection))
      ..add(repository.snapshots.listen(_onSnapshot));
    repository.start();
  }

  void _onConnection(ConnectionStatus connection) {
    final next = switch (connection) {
      ConnectionStatus.connecting => BattleStatus.connecting,
      ConnectionStatus.connected => BattleStatus.playing,
      ConnectionStatus.lost => BattleStatus.lost,
      ConnectionStatus.stopped => BattleStatus.stopped,
    };
    emit(
      state.copyWith(
        status: next,
        problem: connection == ConnectionStatus.stopped
            ? repository.stopReason
            : null,
      ),
    );
  }

  void _onSnapshot(BattleSnapshot snapshot) => emit(
    state.copyWith(
      units: snapshot.units,
      hqs: snapshot.hqs,
      relics: snapshot.relics,
      team: snapshot.team,
      sectionId: snapshot.sectionId,
      revision: state.revision + 1,
    ),
  );

  /// The battle time now, as the client shows it.
  Duration? get battleTime => repository.battleTime;

  /// The AP of [unit] now, when the section owns it.
  double? apNow(UnitView unit) => switch (unit.private) {
    final private? => repository.apNow(private.ap),
    null => null,
  };

  /// Selects [unitId] when it is one of the section's units; anything else
  /// clears the selection.
  void select(String? unitId) {
    final mine = state.sectionUnits.any((unit) => unit.unitId == unitId);
    emit(state.copyWith(selectedId: () => mine ? unitId : null));
  }

  /// Orders the selected unit to move to [to].
  Future<void> moveSelectedTo(Position to) async {
    final unit = state.selected;
    if (unit == null) return;
    await _order(unit.unitId, 'move', Move(unitId: unit.unitId, to: to));
  }

  /// Brings the stored unit [unitId] of the section out next to its storage
  /// place, the HQ (HQ-33). Nothing happens for another section's unit.
  Future<void> deploy(String unitId) async {
    if (!state.sectionUnits.any((unit) => unit.unitId == unitId)) return;
    await _order(unitId, 'deploy', Deploy(unitId: unitId));
  }

  /// Sends [order] for [unitId] while playing, and shows the host's answer.
  Future<void> _order(String unitId, String name, Order order) async {
    if (state.status != BattleStatus.playing) return;
    String? refusal;
    try {
      refusal = await repository.send(order);
    } on Object catch (error) {
      refusal = '$error';
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        notice: () =>
            OrderNotice(order: name, unitId: unitId, refusal: refusal),
      ),
    );
  }

  /// Closes, then the repository: an order it cuts off shows nothing.
  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await super.close();
    await repository.close();
  }
}
