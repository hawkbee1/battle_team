import 'dart:async';

import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/data/battle_repository.dart';
import 'package:battle_team/battle/data/battle_snapshot.dart';
import 'package:battle_team/battle/data/connection_status.dart';
import 'package:battle_team/battle/data/order_sender.dart';
import 'package:battle_team/battle/shots/shot_effect.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';

part 'battle_state.dart';

/// {@template battle_cubit}
/// Plays one battle as one player through [repository]: signs in, then keeps
/// the section's view and sends the player's orders. The host checks every
/// order (stack decision 8); [preCheck] tells the buttons what it will refuse,
/// for display only, and an order it expects refused is not sent. The 3D view
/// listens to it (Observer), and to [shots], the shots the section sees.
///
/// A move is previewed before it is sent (M7 Issue 8): [movePreviewer] plans
/// its path and AP cost on the map, for display only, and a refusal it expects
/// is shown and not sent; the player confirms, and the order goes with the
/// path it planned, which the host checks cell by cell. The host's answer
/// wins: a refusal shows as the host's, and an arrival that differs from the
/// preview's is said, never argued. Without a previewer a move goes straight
/// to the host, which searches the path.
///
/// It logs on `battle_team.BattleCubit`: the sign-in, each change of the
/// connection, each order and the answer, with its refusal code. Never a
/// unit, a position or any part of the state (decision 237).
/// {@endtemplate}
class BattleCubit extends Cubit<BattleState> {
  /// {@macro battle_cubit}
  new({required this.repository, required this.preCheck, this.movePreviewer})
    : super(const BattleState());

  /// Where the battle's data comes from.
  final BattleRepository repository;

  /// What the client expects the host to refuse (stack decision 8).
  final OrderPreCheck preCheck;

  /// What the client expects of a move: its path and cost (stack decision 8).
  final MovePreviewer? movePreviewer;

  static final _log = Logger('battle_team.BattleCubit');

  /// A confirmed move whose arrival the host has not told yet: the unit, the
  /// arrival the preview showed and the end of its move before the order.
  ({String unitId, Duration expected, Duration? before})? _awaiting;

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
      storedWeapons: snapshot.section?.storedWeapons,
      team: snapshot.team,
      sectionId: snapshot.sectionId,
      revision: state.revision + 1,
    );
    // The unit whose eyes the player looks through died, was stored or left
    // the section's sight: back to the overview.
    final lost =
        next.viewMode is FirstPersonMode && !next.canSeeFrom(next.seenFrom);
    if (lost) _log.info('first person ended: the unit is gone');
    // A target the section stops seeing is no target any more.
    final targetGone = next.targetId != null && next.target == null;
    // A preview of a unit that moved, left or is no longer selected is stale.
    final pending = next.pendingMove;
    final stale =
        pending != null &&
        (next.selectedId != pending.unitId ||
            next.units[pending.unitId]?.position != pending.from);
    final note = _arrivalNote(next);
    emit(
      next.copyWith(
        viewMode: lost ? const TopDownMode() : null,
        targetId: targetGone ? () => null : null,
        pendingMove: stale ? () => null : null,
        arrivalNote: note == null ? null : () => note,
      ),
    );
  }

  /// The arrival the host gave a confirmed move, when it differs from the
  /// preview's by more than a second (stack decision 8).
  ArrivalNote? _arrivalNote(BattleState next) {
    final awaiting = _awaiting;
    if (awaiting == null) return null;
    final unit = next.units[awaiting.unitId];
    if (unit == null) {
      _awaiting = null;
      return null;
    }
    final host = unit.private?.movingUntil;
    // Not told yet: the view still holds the end of the previous move.
    if (host == null || host == awaiting.before) return null;
    _awaiting = null;
    if ((host - awaiting.expected).abs() <= const Duration(seconds: 1)) {
      return null;
    }
    _log.warning('move arrival differs from the preview');
    return ArrivalNote(
      unitId: awaiting.unitId,
      expected: awaiting.expected,
      host: host,
    );
  }

  /// The shots the section sees, to draw for a moment: transient, so not part
  /// of the state (decisions 234 and 237).
  Stream<List<ShotEffect>> get shots => repository.shots;

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
        targetId: () => null,
        groundFire: false,
        pendingMove: () => null,
        arrivalNote: () => null,
        viewMode: leaves ? const TopDownMode() : null,
      ),
    );
  }

  /// Aims the selected unit at [unitId], a unit of another section that the
  /// section sees (COMBAT-11); the same unit again, or anything else, clears
  /// the target.
  void target(String? unitId) {
    final other = state.units[unitId];
    final valid =
        other != null &&
        other.position != null &&
        other.sectionId != state.sectionId &&
        state.selected != null;
    emit(
      state.copyWith(
        targetId: () => valid && unitId != state.targetId ? unitId : null,
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

  /// Plans the move of the selected unit to [to] and shows it, sending
  /// nothing: the path and its AP cost, or why the client expects the host to
  /// refuse it (COMBAT-03, COMBAT-06, MAP-47, MAP-50). [confirmMove] sends
  /// it. A move the client cannot plan goes straight to the host.
  Future<void> previewMoveTo(Position to) async {
    final unit = state.selected;
    final time = battleTime;
    if (state.status != BattleStatus.playing || unit == null || time == null) {
      return;
    }
    final plan = _plan(unit, to, time);
    if (plan is MoveUnplanned) {
      await _sendMove(unit, to);
      return;
    }
    _log.info(
      plan is MoveRefused
          ? 'move not previewable: ${plan.reason.code}'
          : 'move previewed',
    );
    emit(
      state.copyWith(
        pendingMove: () => PendingMove(
          unitId: unit.unitId,
          from: unit.position ?? const Position(0, 0, 0),
          plan: plan,
        ),
        arrivalNote: () => null,
      ),
    );
  }

  /// Sends the previewed move, with the path it planned (stack decision 8).
  Future<void> confirmMove() async {
    final pending = state.pendingMove;
    final unit = state.units[pending?.unitId];
    final plan = pending?.plan;
    emit(state.copyWith(pendingMove: () => null));
    if (unit == null || plan is! MovePreview) return;
    await _sendMove(unit, plan.destination, plan: plan);
  }

  /// Drops the previewed move.
  void cancelMove() {
    if (state.pendingMove == null) return;
    emit(state.copyWith(pendingMove: () => null));
  }

  /// Orders the selected unit to move to [to] at once, without a preview:
  /// from first person, where a move is a step of a stream (stack decision
  /// 3). An order the client expects refused is not sent.
  Future<void> moveSelectedTo(Position to) async {
    final unit = state.selected;
    final time = battleTime;
    if (unit == null) return;
    final plan = time == null ? const MoveUnplanned() : _plan(unit, to, time);
    if (plan is MoveRefused) {
      _log.warning('order move not sent: ${plan.reason.code}');
      emit(
        state.copyWith(
          notice: () => OrderNotice(
            order: 'move',
            unitId: unit.unitId,
            refusal: plan.reason.code,
          ),
        ),
      );
      return;
    }
    await _sendMove(unit, to, plan: plan is MovePreview ? plan : null);
  }

  MovePlan _plan(UnitView unit, Position to, Duration time) =>
      movePreviewer?.preview(
        unit: unit,
        destination: to,
        seen: state.units.values,
        time: time,
      ) ??
      const MoveUnplanned();

  /// Sends the move of [unit] to [to], along the path of [plan] when there is
  /// one, and waits for the host to say when it arrives.
  Future<void> _sendMove(
    UnitView unit,
    Position to, {
    MovePreview? plan,
  }) async {
    if (state.status != BattleStatus.playing) return;
    final before = unit.private?.movingUntil;
    final refusal = await _order(
      unit.unitId,
      'move',
      Move(unitId: unit.unitId, to: to, path: plan?.cells),
    );
    if (refusal == null && plan != null && !isClosed) {
      _awaiting = (
        unitId: unit.unitId,
        expected: plan.arrivesAt,
        before: before,
      );
    }
  }

  // The weapon: what the buttons show (stack decision 8, display only) ...

  /// What the client expects of the selected unit firing at its target
  /// (COMBAT-11).
  PreChecked checkFire() => _checked(
    (unit, time) =>
        preCheck.fire(shooter: unit, target: state.target, time: time),
  );

  /// What the client expects of the selected unit firing at a position
  /// (COMBAT-12), before the position is chosen: whether it can at all.
  PreChecked checkFireAtPosition() => _checked(
    (unit, time) => preCheck.fireAtPosition(
      shooter: unit,
      // Only the weapon is asked about, not the range: the position comes with
      // the tap. A unit off the field is refused before this is used.
      target: unit.position ?? const Position(0, 0, 0),
      time: time,
    ),
  );

  /// What the client expects of the selected unit firing from first person
  /// (COMBAT-14).
  PreChecked checkFireAimed() =>
      _checked((unit, time) => preCheck.fireAimed(shooter: unit, time: time));

  /// What the client expects of the selected unit reloading.
  PreChecked checkReload() => _checked((unit, _) => preCheck.reload(unit));

  /// What the client expects of the selected unit swapping for [weapon].
  PreChecked checkSwap(String weapon) => _checked(
    (unit, _) => preCheck.swap(
      unit: unit,
      weapon: weapon,
      stored: state.storedWeapons,
      storage: _storage,
    ),
  );

  /// The spare weapons the selected unit's type may use (COMBAT-26).
  List<String> get swappableWeapons => switch (state.selected) {
    final unit? => preCheck.swappable(unit, state.storedWeapons),
    null => const [],
  };

  /// The rounds a magazine of [unit]'s weapon holds; null without a weapon.
  int? magazineOf(UnitView unit) =>
      preCheck.weaponType(unit.weapon)?.magazineCapacity;

  /// The position of the section's storage place, its team's HQ.
  Position? get _storage => state.hqs
      .where((hq) => hq.team == state.team)
      .map((hq) => hq.position)
      .firstOrNull;

  PreChecked _checked(PreChecked Function(UnitView unit, Duration time) check) {
    final unit = state.selected;
    final time = battleTime;
    if (unit == null || time == null) {
      return const PreCheckRefused(PreCheckRefusal.notOnField);
    }
    return check(unit, time);
  }

  // ... and the orders (COMBAT-11 to COMBAT-14, COMBAT-26 to COMBAT-33).

  /// Orders the selected unit to fire at its target.
  Future<void> fireSelected() {
    final target = state.targetId;
    return _weapon(
      'fire',
      (unit, time) =>
          preCheck.fire(shooter: unit, target: state.target, time: time),
      // The check passes only with a target the section sees.
      (unit) => Fire(unitId: unit.unitId, targetId: target!),
    );
  }

  /// Arms the next tap on the ground to fire there, or disarms it (COMBAT-12).
  void toggleGroundFire() {
    final armed = !state.groundFire;
    if (armed && checkFireAtPosition() is PreCheckRefused) return;
    emit(state.copyWith(groundFire: armed));
  }

  /// Orders the selected unit to fire at the ground position [at] (COMBAT-12).
  Future<void> fireSelectedAt(Position at) {
    emit(state.copyWith(groundFire: false));
    return _weapon(
      'fireAtPosition',
      (unit, time) =>
          preCheck.fireAtPosition(shooter: unit, target: at, time: time),
      (unit) => FireAtPosition(unitId: unit.unitId, target: at),
    );
  }

  /// Orders the selected unit to fire toward [aim], from first person
  /// (COMBAT-14, decision 183).
  Future<void> fireAimed(Direction aim) {
    final time = battleTime;
    if (state.viewMode is! FirstPersonMode || time == null) {
      return Future.value();
    }
    return _weapon(
      'fireAimed',
      (unit, now) => preCheck.fireAimed(shooter: unit, time: now),
      (unit) => FireAimed(unitId: unit.unitId, aim: aim, fireTime: time),
    );
  }

  /// Orders the selected unit to reload (COMBAT-33).
  Future<void> reload() => _weapon(
    'reload',
    (unit, _) => preCheck.reload(unit),
    (unit) => Reload(unitId: unit.unitId),
  );

  /// Orders the selected unit to take [weapon] from the section's storage
  /// (COMBAT-28).
  Future<void> swap(String weapon) => _weapon(
    'swap',
    (unit, _) => preCheck.swap(
      unit: unit,
      weapon: weapon,
      stored: state.storedWeapons,
      storage: _storage,
    ),
    (unit) => SwapWeapon(unitId: unit.unitId, weapon: weapon),
  );

  /// Sends the weapon order [build] makes for the selected unit when [check]
  /// sees nothing against it; else shows what the client expects the host to
  /// say, and sends nothing.
  Future<void> _weapon(
    String name,
    PreChecked Function(UnitView unit, Duration time) check,
    Order Function(UnitView unit) build,
  ) async {
    final unit = state.selected;
    final time = battleTime;
    if (state.status != BattleStatus.playing || unit == null || time == null) {
      return;
    }
    if (check(unit, time) case PreCheckRefused(:final reason)) {
      _log.warning('order $name not sent: ${reason.code}');
      emit(
        state.copyWith(
          notice: () => OrderNotice(
            order: name,
            unitId: unit.unitId,
            refusal: reason.code,
          ),
        ),
      );
      return;
    }
    await _order(unit.unitId, name, build(unit));
  }

  /// Sends [order] for [unitId] while playing, and shows the host's answer;
  /// completes with the host's refusal code, or null when it accepted it (and
  /// when nothing was sent).
  Future<String?> _order(String unitId, String name, Order order) async {
    if (state.status != BattleStatus.playing) return null;
    final refusal = await sendOrder(_log, repository, name, order);
    if (isClosed) return refusal;
    emit(
      state.copyWith(
        notice: () =>
            OrderNotice(order: name, unitId: unitId, refusal: refusal),
      ),
    );
    return refusal;
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
