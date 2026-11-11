import 'package:battle_team/battle/data/battle_locator.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';

part 'battle_entry_state.dart';

/// {@template battle_entry_cubit}
/// Finds the battle an account plays, once it is signed in, through the
/// locator: the screen then opens it, or says there is none or why the search
/// failed. It enters nothing: the host logs the player in on the socket
/// (decision 220).
/// {@endtemplate}
class BattleEntryCubit extends Cubit<BattleEntryState> {
  /// {@macro battle_entry_cubit}
  new({required this._locator, required this._accountId})
    : super(const BattleEntryLocating());

  final BattleLocator _locator;
  final String _accountId;

  static final _log = Logger('battle_team.BattleEntryCubit');

  /// Looks for the account's battle; again after a failure or a "none".
  Future<void> locate() async {
    emit(const BattleEntryLocating());
    try {
      final assignment = await _locator.locate(_accountId);
      emit(
        assignment == null
            ? const BattleEntryNone()
            : BattleEntryFound(assignment),
      );
    } on BattleLookupFailure catch (failure) {
      _log.warning('no battle: lookup failed');
      emit(BattleEntryFailed(unreachable: failure.unreachable));
    }
  }
}
