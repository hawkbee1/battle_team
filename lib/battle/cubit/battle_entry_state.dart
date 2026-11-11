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

/// Looking for the account's battle.
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

/// The account has several battles to choose from, or asked to choose: it
/// picks one of [battles].
final class BattleEntryChoosing extends BattleEntryState {
  /// Choosing among [battles].
  const new(this.battles);

  /// The running battles of the account, one per war.
  final List<AccountBattle> battles;

  @override
  List<Object?> get props => [battles];
}

/// The account has no section in a running battle.
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
