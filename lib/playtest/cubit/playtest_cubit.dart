import 'dart:async';

import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'playtest_state.dart';

/// {@template playtest_cubit}
/// Plays one battle as one player through [client]: signs in to Appwrite
/// ([signIn]), then keeps the section's view and sends the player's moves.
/// The host checks every order (stack decision 8).
/// {@endtemplate}
class PlaytestCubit extends Cubit<PlaytestState> {
  /// {@macro playtest_cubit}
  new({required this.client, required this.signIn})
    : super(const PlaytestState());

  /// The connection to the battle's host.
  final BattleClient client;

  /// Signs the player in to Appwrite, so that the client gets JWTs.
  final Future<void> Function() signIn;

  final _subscriptions = <StreamSubscription<Object?>>[];

  /// Signs in, then connects to the battle.
  Future<void> start() async {
    try {
      await signIn();
    } on Object catch (error) {
      emit(state.copyWith(status: PlaytestStatus.failed, problem: '$error'));
      return;
    }
    _subscriptions
      ..add(client.statuses.listen(_onStatus))
      ..add(client.messages.listen((_) => _refresh()));
    client.start();
  }

  void _onStatus(ClientStatus status) {
    final next = switch (status) {
      ClientStatus.idle || ClientStatus.connecting => PlaytestStatus.connecting,
      ClientStatus.signedIn => PlaytestStatus.playing,
      ClientStatus.waiting => PlaytestStatus.lost,
      ClientStatus.stopped => PlaytestStatus.stopped,
    };
    final problem = switch (status) {
      ClientStatus.stopped => switch ((
        client.stoppedBy,
        client.lookupRefused,
      )) {
        (final HostMessage message?, _) => '$message',
        (_, final HostLookupException refused?) => refused.code,
        _ => null,
      },
      _ => null,
    };
    emit(state.copyWith(status: next, problem: problem));
  }

  void _refresh() {
    final view = client.view;
    final seat = client.seat;
    emit(
      state.copyWith(
        units: Map.of(view.units),
        hqs: view.hqs.values.toList(),
        relics: view.relics.values.toList(),
        team: seat?.team,
        sectionId: seat?.sectionId,
        revision: state.revision + 1,
      ),
    );
  }

  /// The battle time now, as the client shows it.
  Duration? get battleTime => client.battleTime;

  /// The AP of [unit] now, when the section owns it.
  double? apNow(UnitView unit) => switch (unit.private) {
    final private? => client.apNow(private.ap),
    null => null,
  };

  /// Selects [unitId] when it is one of the section's units; anything else
  /// clears the selection.
  void select(String? unitId) {
    final unit = state.units[unitId];
    final mine = unit != null && unit.sectionId == state.sectionId;
    emit(state.copyWith(selectedId: () => mine ? unitId : null));
  }

  /// Orders the selected unit to move to [to].
  Future<void> moveSelectedTo(Position to) async {
    final unit = state.selected;
    if (unit == null || state.status != PlaytestStatus.playing) return;
    String? refusal;
    try {
      final answer = await client.send(Move(unitId: unit.unitId, to: to));
      refusal = answer.refusal;
    } on Object catch (error) {
      refusal = '$error';
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        notice: () =>
            OrderNotice(order: 'move', unitId: unit.unitId, refusal: refusal),
      ),
    );
  }

  /// Closes, then the client: an order it cuts off shows nothing.
  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await super.close();
    await client.close();
  }
}
