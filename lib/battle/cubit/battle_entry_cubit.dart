import 'package:battle_team/battle/data/battle_locator.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';

part 'battle_entry_state.dart';

/// {@template battle_entry_cubit}
/// Finds the battles of an account, once it is signed in, through the
/// locator: the screen then opens the only battle the account is in, lets the
/// player choose among the running battles (the ones he is in and the ones he
/// can join), or says there is none or why the search failed. [choose] looks
/// again and always lists them (the battle screen's Switch battle). A battle
/// the account is not in is joined first (SOC-30): its war gives the account a
/// new section, then the battle is entered and the host admits the section.
/// A battle on a map the app does not have (`mapAvailable`) cannot be shown:
/// it is not entered at once and not entered when picked, so that the player
/// never joins a war he cannot play. The cubit enters nothing itself: the host
/// logs the player in on the socket (decision 220).
/// {@endtemplate}
class BattleEntryCubit extends Cubit<BattleEntryState> {
  /// {@macro battle_entry_cubit}
  new({
    required this._locator,
    required this._accountId,
    this._mapAvailable = _anyMap,
  }) : super(const BattleEntryLocating());

  final BattleLocator _locator;
  final String _accountId;
  final bool Function(String mapId) _mapAvailable;

  static bool _anyMap(String mapId) => true;

  static final _log = Logger('battle_team.BattleEntryCubit');

  /// The battles of the last look, which a failed join goes back to.
  List<AccountBattle> _listed = const [];

  /// Looks for the battles; again after a failure or a "none". The only
  /// battle the account is in is entered at once.
  Future<void> locate() => _look(enterTheOnlyOne: true);

  /// Looks again and lists the running battles, even when the account is in
  /// one: the player wants another war, or another battle.
  Future<void> choose() => _look(enterTheOnlyOne: false);

  /// Enters [battle], one of the [BattleEntryChoosing] list: at once when the
  /// account is in it, after joining its war when it is not.
  Future<void> enter(AccountBattle battle) async {
    if (!_mapAvailable(battle.battle.mapId)) return;
    if (battle.joined) {
      emit(BattleEntryFound(battle.battle));
      return;
    }
    emit(BattleEntryJoining(battle));
    try {
      await _locator.join(battle.warId!);
      emit(BattleEntryFound(battle.battle));
    } on BattleJoinFailure catch (failure) {
      _log.warning('war not joined: ${failure.reason.name}');
      emit(BattleEntryChoosing(_listed, problem: failure.reason));
    }
  }

  Future<void> _look({required bool enterTheOnlyOne}) async {
    emit(const BattleEntryLocating());
    try {
      final battles = _listed = await _locator.locate(_accountId);
      final mine = battles.where((battle) => battle.joined).toList();
      emit(switch (battles) {
        [] => const BattleEntryNone(),
        _
            when enterTheOnlyOne &&
                mine.length == 1 &&
                _mapAvailable(mine.single.battle.mapId) =>
          BattleEntryFound(mine.single.battle),
        _ => BattleEntryChoosing(battles),
      });
    } on BattleLookupFailure catch (failure) {
      _log.warning('no battles: lookup failed');
      emit(BattleEntryFailed(unreachable: failure.unreachable));
    }
  }
}
