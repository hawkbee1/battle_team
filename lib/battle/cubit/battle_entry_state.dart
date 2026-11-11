part of 'battle_entry_cubit.dart';

/// {@template battle_entry_state}
/// Where the search for an account's battle stands.
/// {@endtemplate}
sealed class BattleEntryState extends Equatable {
  /// {@macro battle_entry_state}
  const new();

  @override
  List<Object?> get props => [];
}

/// Looking for the running battles.
final class BattleEntryLocating extends BattleEntryState {
  /// Looking.
  const new();
}

/// The account plays [assignment].
final class BattleEntryFound extends BattleEntryState {
  /// The account plays [assignment].
  const new(this.assignment);

  /// The battle and its map.
  final BattleAssignment assignment;

  @override
  List<Object?> get props => [assignment];
}

/// The player picks a battle among [battles], the running ones, each marked
/// with whether the account is in it. [problem] says why the last join of one
/// failed.
final class BattleEntryChoosing extends BattleEntryState {
  /// Choosing among [battles].
  const new(this.battles, {this.problem});

  /// The running battles, one per war.
  final List<AccountBattle> battles;

  /// Why the last war the player tried to join was not joined; null if none
  /// was tried.
  final BattleJoinFailureReason? problem;

  @override
  List<Object?> get props => [battles, problem];
}

/// The account joins the war of [battle]: its section is being created.
final class BattleEntryJoining extends BattleEntryState {
  /// Joining the war of [battle].
  const new(this.battle);

  /// The battle whose war is joined.
  final AccountBattle battle;

  @override
  List<Object?> get props => [battle];
}

/// No battle runs.
final class BattleEntryNone extends BattleEntryState {
  /// Nothing to play.
  const new();
}

/// The search failed.
final class BattleEntryFailed extends BattleEntryState {
  /// Failed; [unreachable] tells whether the server did not answer.
  const new({required this.unreachable});

  /// Whether the server did not answer.
  final bool unreachable;

  @override
  List<Object?> get props => [unreachable];
}
