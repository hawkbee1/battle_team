import 'dart:async';

import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/data/battle_repository.dart';
import 'package:battle_team/battle/data/battle_snapshot.dart';
import 'package:battle_team/battle/widgets/wait_format.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';

part 'alerts_state.dart';

/// {@template alerts_cubit}
/// The alerts of the battle (M7 Issue 9): the relic alert (RELIC-10, decision
/// 233), which the host sends at once to the team that lost the relic and, to
/// those who were not connected, on their next connection; and the victory
/// countdown (RELIC-16), which every section knows, with the relics and their
/// owners (MAP-49, decision 232), for the status strip.
///
/// A cubit of its own, on the same [repository] as the `BattleCubit`. An alert
/// shows once: the host may send the same one again after a crash (M6.4), and
/// the cubit keeps the ones it showed. A banner stays until the player
/// dismisses it. It computes no rule (decision 3).
///
/// It logs on `battle_team.AlertsCubit`: that an alert came or a countdown
/// started, never a unit (decision 237).
/// {@endtemplate}
class AlertsCubit extends Cubit<AlertsState> {
  /// {@macro alerts_cubit}
  new({required this.repository}) : super(const AlertsState());

  /// Where the battle's data comes from, the battle cubit's own.
  final BattleRepository repository;

  static final _log = Logger('battle_team.AlertsCubit');

  final _subscriptions = <StreamSubscription<Object?>>[];
  final _shown = <(Duration, String, String)>{};
  var _next = 0;

  /// Starts to listen. Call it before the battle cubit connects, so that the
  /// alerts the host sends on connecting are not missed.
  void start() {
    _subscriptions
      ..add(repository.alerts.listen(_onAlert))
      ..add(repository.snapshots.listen(_onSnapshot));
  }

  /// The battle time now, as the client shows it.
  Duration? get battleTime => repository.battleTime;

  void _onAlert(RelicAlert alert) {
    if (!_shown.add((alert.at, alert.relicId, alert.team))) {
      _log.fine('a relic alert came again; shown once');
      return;
    }
    _log.info('relic alert');
    emit(
      state.copyWith(
        banners: [
          ...state.banners,
          RelicTaken(
            _next++,
            relicId: alert.relicId,
            team: alert.team,
            at: alert.at,
          ),
        ],
      ),
    );
  }

  void _onSnapshot(BattleSnapshot snapshot) {
    if (snapshot.section == null) return;
    final relics = [
      for (final relic in snapshot.relics)
        (relicId: relic.relicId, owner: relic.owner),
    ];
    final hold = snapshot.hold;
    final before = state.hold;
    // The countdown starts (also when the player connects to one running), or
    // another team takes it over, or it is reset.
    final banner = switch ((before, hold)) {
      (_, final now?) when now != before => CountdownStarted(
        _next,
        team: now.team,
        remaining: remainingOf(now.winsAt, repository.battleTime),
      ),
      (_?, null) => CountdownReset(_next),
      _ => null,
    };
    if (banner != null) {
      _next++;
      _log.info('countdown ${banner is CountdownReset ? 'reset' : 'running'}');
    }
    if (relics.length == state.relics.length &&
        _sameRelics(relics) &&
        hold == before &&
        banner == null) {
      return;
    }
    emit(
      state.copyWith(
        relics: relics,
        hold: () => hold,
        banners: [...state.banners, ?banner],
      ),
    );
  }

  bool _sameRelics(List<RelicOwner> relics) {
    for (var i = 0; i < relics.length; i++) {
      if (relics[i] != state.relics[i]) return false;
    }
    return true;
  }

  /// Dismisses the banner [id].
  void dismiss(int id) => emit(
    state.copyWith(
      banners: [
        for (final banner in state.banners)
          if (banner.id != id) banner,
      ],
    ),
  );

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await super.close();
  }
}
