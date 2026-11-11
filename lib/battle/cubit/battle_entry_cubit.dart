import 'package:battle_team/battle/data/battle_locator.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';

part 'battle_entry_state.dart';

/// {@template battle_entry_cubit}
/// Finds the battles an account plays, once it is signed in, through the
/// locator: the screen then opens the only one, lets the player choose among
/// several, or says there is none or why the search failed. [choose] looks
/// again and always lets the player choose (the battle screen's Switch
/// battle). It enters nothing: the host logs the player in on the socket
/// (decision 220).
/// {@endtemplate}
class BattleEntryCubit extends Cubit<BattleEntryState> {
  /// {@macro battle_entry_cubit}
  new({required this._locator, required this._accountId})
    : super(const BattleEntryLocating());

  final BattleLocator _locator;
  final String _accountId;

  static final _log = Logger('battle_team.BattleEntryCubit');

  /// Looks for the account's battles; again after a failure or a "none". The
  /// only battle found is entered at once.
  Future<void> locate() => _look(enterTheOnlyOne: true);

  /// Looks again and lists the account's battles, even when there is one: the
  /// player wants another war, or another battle.
  Future<void> choose() => _look(enterTheOnlyOne: false);

  /// Enters [battle], one of the [BattleEntryChoosing] list.
  void enter(AccountBattle battle) => emit(BattleEntryFound(battle.battle));

  Future<void> _look({required bool enterTheOnlyOne}) async {
    emit(const BattleEntryLocating());
    try {
      final battles = await _locator.locate(_accountId);
      emit(switch (battles) {
        [] => const BattleEntryNone(),
        [final only] when enterTheOnlyOne => BattleEntryFound(only.battle),
        _ => BattleEntryChoosing(battles),
      });
    } on BattleLookupFailure catch (failure) {
      _log.warning('no battle: lookup failed');
      emit(BattleEntryFailed(unreachable: failure.unreachable));
    }
  }
}
