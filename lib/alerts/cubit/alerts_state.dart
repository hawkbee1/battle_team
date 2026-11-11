part of 'alerts_cubit.dart';

/// {@template alert_banner}
/// An alert the player can dismiss (M7 Issue 9). It holds only what the host
/// told the section: a relic's ID and the team that took it, a team's
/// countdown (decisions 232 and 233).
/// {@endtemplate}
sealed class AlertBanner extends Equatable {
  /// {@macro alert_banner}
  const new(this.id);

  /// Tells banners apart, in the order they came.
  final int id;
}

/// The section's team lost [relicId] to [team] (RELIC-10, decision 233).
final class RelicTaken extends AlertBanner {
  /// [team] took [relicId] at the battle time [at].
  const new(
    super.id, {
    required this.relicId,
    required this.team,
    required this.at,
  });

  /// The relic.
  final String relicId;

  /// Its new owner.
  final String team;

  /// When it changed owner.
  final Duration at;

  @override
  List<Object?> get props => [id, relicId, team, at];
}

/// [team] holds the relics and wins in [remaining] unless one is taken back
/// (RELIC-16): every section is told, whatever it sees (MAP-49). [remaining]
/// is the time left when the alert came; the status strip counts down.
final class CountdownStarted extends AlertBanner {
  /// The countdown of [team].
  const new(super.id, {required this.team, required this.remaining});

  /// The team that holds.
  final String team;

  /// The time left when the countdown was announced.
  final Duration remaining;

  @override
  List<Object?> get props => [id, team, remaining];
}

/// The running countdown was reset (RELIC-16).
final class CountdownReset extends AlertBanner {
  /// A countdown reset.
  const new(super.id);

  @override
  List<Object?> get props => [id];
}

/// A relic and the team that owns it, as every section knows it (MAP-49).
typedef RelicOwner = ({String relicId, String? owner});

/// {@template alerts_state}
/// What the status strip and the banners show: the relics and their owners,
/// the victory countdown (MAP-49, RELIC-16) and the alerts not yet
/// dismissed. All of it is what every section knows, or what the host told
/// this one (decision 237).
/// {@endtemplate}
class AlertsState extends Equatable {
  /// {@macro alerts_state}
  const new({
    this.relics = const [],
    this.hold,
    this.banners = const [],
    this.revision = 0,
  });

  /// Every relic and its owner, in the host's order.
  final List<RelicOwner> relics;

  /// The running victory countdown, when a team holds.
  final HoldView? hold;

  /// The alerts not dismissed yet, oldest first.
  final List<AlertBanner> banners;

  /// Grows with each change.
  final int revision;

  /// How many relics [team] owns; null counts the free ones.
  int owned(String? team) =>
      relics.where((relic) => relic.owner == team).length;

  /// The teams that own a relic, in the order the relics list them.
  List<String> get owners =>
      {for (final relic in relics) ?relic.owner}.toList();

  /// This state with the values given.
  AlertsState copyWith({
    List<RelicOwner>? relics,
    HoldView? Function()? hold,
    List<AlertBanner>? banners,
  }) => AlertsState(
    relics: relics ?? this.relics,
    hold: hold == null ? this.hold : hold(),
    banners: banners ?? this.banners,
    revision: revision + 1,
  );

  @override
  List<Object?> get props => [relics, hold, banners, revision];
}
