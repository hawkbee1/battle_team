import 'dart:async';

import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/data/battle_repository.dart';
import 'package:battle_team/battle/data/battle_snapshot.dart';
import 'package:battle_team/battle/data/connection_status.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';

part 'battle_state.dart';

/// {@template battle_cubit}
/// Plays one battle as one player through [repository]: signs in, then keeps
/// the section's view and sends the player's orders. The host checks every
/// order (stack decision 8). The 3D view listens to it (Observer).
///
/// It logs on `battle_team.BattleCubit`: the sign-in, each change of the
/// connection, each order and the host's answer, with its refusal code. Never
/// a unit, a position or any part of the state (decision 237).
/// {@endtemplate}
class BattleCubit extends Cubit<BattleState> {
  /// {@macro battle_cubit}
  new({required this.repository}) : super(const BattleState());

  /// Where the battle's data comes from.
  final BattleRepository repository;

  static final _log = Logger('battle_team.BattleCubit');

  final _subscriptions = <StreamSubscription<Object?>>[];

  /// Signs in, then connects to the battle.
  Future<void> start() async {
    _log.info('signing in');
    try {
      await repository.signIn();
      _log.info('signed in');
    } on Object catch (error, stackTrace) {
      _log.severe('sign-in failed', error, stackTrace);
      emit(state.copyWith(status: BattleStatus.failed, problem: '$error'));
      return;
    }
    _subscriptions
      ..add(repository.connection.listen(_onConnection))
      ..add(repository.snapshots.listen(_onSnapshot));
    repository.start();
  }

  void _onConnection(ConnectionStatus connection) {
    _log.info('connection ${connection.name}');
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

  void _onSnapshot(BattleSnapshot snapshot) {
    final next = state.copyWith(
      units: snapshot.units,
      hqs: snapshot.hqs,
      relics: snapshot.relics,
      team: snapshot.team,
      sectionId: snapshot.sectionId,
      revision: state.revision + 1,
    );
    // The unit whose eyes the player looks through died, was stored or left
    // the section's sight: back to the overview.
    final lost =
        next.viewMode is FirstPersonMode && !next.canSeeFrom(next.seenFrom);
    if (lost) _log.info('first person ended: the unit is gone');
    emit(lost ? next.copyWith(viewMode: const TopDownMode()) : next);
  }

  /// The battle time now, as the client shows it.
  Duration? get battleTime => repository.battleTime;

  /// The AP of [unit] now, when the section owns it.
  double? apNow(UnitView unit) => switch (unit.private) {
    final private? => repository.apNow(private.ap),
    null => null,
  };

  /// Selects [unitId] when it is one of the section's units; anything else
  /// clears the selection. Selecting another unit than the one the battle is
  /// seen from goes back to the overview.
  void select(String? unitId) {
    final mine = state.sectionUnits.any((unit) => unit.unitId == unitId);
    final selected = mine ? unitId : null;
    final mode = state.viewMode;
    final leaves = mode is FirstPersonMode && mode.unitId != selected;
    if (leaves) _log.info('first person ended: the selection changed');
    emit(
      state.copyWith(
        selectedId: () => selected,
        viewMode: leaves ? const TopDownMode() : null,
      ),
    );
  }

  /// Sees the battle through the eyes of the selected unit (decision 5),
  /// when it is one of the section's, alive and on the field.
  void enterFirstPerson() {
    final unit = state.selected;
    if (unit == null || !state.canSeeFrom(unit)) return;
    _log.info('first person entered');
    emit(state.copyWith(viewMode: FirstPersonMode(unit.unitId)));
  }

  /// Back to the overview from a unit's eyes.
  void leaveFirstPerson() {
    if (state.viewMode is! FirstPersonMode) return;
    _log.info('first person left');
    emit(state.copyWith(viewMode: const TopDownMode()));
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
    _log.info('order $name sent');
    try {
      refusal = await repository.send(order);
      if (refusal == null) {
        _log.info('order $name accepted');
      } else {
        _log.warning('order $name refused $refusal');
      }
    } on Object catch (error, stackTrace) {
      _log.severe('order $name failed', error, stackTrace);
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
