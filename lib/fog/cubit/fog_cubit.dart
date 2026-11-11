import 'dart:async';

import 'package:battle_team/battle/data/battle_repository.dart';
import 'package:battle_team/battle/data/battle_snapshot.dart';
import 'package:battle_team/fog/model/fog_model.dart';
import 'package:battle_team/fog/model/fog_tracker.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';

part 'fog_state.dart';

/// {@template fog_cubit}
/// The fog of the battle screen (M7 Issue 9, MAP-27, MAP-29, MAP-33): it
/// follows the section's view and keeps the ground the section sees, in sight
/// now, seen once, or never seen, through [tracker].
///
/// A cubit of its own, on the same [repository] as the `BattleCubit`: the two
/// read the same snapshots and share nothing else. It reads the section's own
/// units, the weather and the delta layer, which every section knows
/// (MAP-49), and computes no rule (decision 3): the host decides what a unit
/// sees, this only shows it.
///
/// It logs on `battle_team.FogCubit` when it starts. The grid is view state:
/// never a unit, a position or a cell (decision 237).
/// {@endtemplate}
class FogCubit extends Cubit<FogState> {
  /// {@macro fog_cubit}
  new({required this.repository, required this.tracker})
    : super(FogState(model: tracker.model));

  /// Where the battle's data comes from, the battle cubit's own.
  final BattleRepository repository;

  /// What the section's sight lights.
  final FogTracker tracker;

  static final _log = Logger('battle_team.FogCubit');

  StreamSubscription<BattleSnapshot>? _subscription;

  /// Starts to follow the section's view. Call it before the battle cubit
  /// connects, so that no snapshot is missed.
  void start() {
    _log.info('following the section view');
    _subscription = repository.snapshots.listen(_onSnapshot);
  }

  void _onSnapshot(BattleSnapshot snapshot) {
    final model = tracker.update(
      units: snapshot.units.values,
      weather: snapshot.weather,
      world: snapshot.world,
      worldVersion: snapshot.worldVersion,
    );
    if (model != null) {
      emit(FogState(model: model, revision: state.revision + 1));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
