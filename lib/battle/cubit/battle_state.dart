part of 'battle_cubit.dart';

/// Where the battle screen stands.
enum BattleStatus {
  /// Signing in to Appwrite.
  signingIn,

  /// Finding the battle's host and signing in to it.
  connecting,

  /// Signed in: the view is kept up to date and orders go out.
  playing,

  /// Lost the host; coming back.
  lost,

  /// Stopped for good: the host or Appwrite refused, or the battle ended.
  stopped,

  /// The sign-in to Appwrite failed.
  failed,
}

/// {@template view_mode}
/// How the battle is seen (decision 5): from above, or through the eyes of
/// one of the section's units. The view picks the camera of the mode (the
/// camera Strategy); the state holds no camera.
/// {@endtemplate}
sealed class ViewMode extends Equatable {
  /// {@macro view_mode}
  const new();
}

/// The battle seen from above.
final class TopDownMode extends ViewMode {
  /// Seen from above.
  const new();

  @override
  List<Object?> get props => [];
}

/// The battle seen through the eyes of the section's unit [unitId].
final class FirstPersonMode extends ViewMode {
  /// Through the eyes of [unitId].
  const new(this.unitId);

  /// The unit whose eyes these are.
  final String unitId;

  @override
  List<Object?> get props => [unitId];
}

/// {@template order_notice}
/// The host's answer to the player's last order.
/// {@endtemplate}
class OrderNotice extends Equatable {
  /// {@macro order_notice}
  const new({required this.order, required this.unitId, this.refusal});

  /// The order, as a word: `move`.
  final String order;

  /// The unit it was for.
  final String unitId;

  /// Why the host refused it; null when accepted.
  final String? refusal;

  /// Whether the host accepted it.
  bool get accepted => refusal == null;

  @override
  List<Object?> get props => [order, unitId, refusal];
}

/// {@template battle_state}
/// What the battle screen shows: the section's view, the selected unit and the
/// last answer.
/// {@endtemplate}
class BattleState extends Equatable {
  /// {@macro battle_state}
  const new({
    this.status = BattleStatus.signingIn,
    this.units = const {},
    this.hqs = const [],
    this.relics = const [],
    this.team,
    this.sectionId,
    this.selectedId,
    this.viewMode = const TopDownMode(),
    this.notice,
    this.problem,
    this.revision = 0,
  });

  /// Where it stands.
  final BattleStatus status;

  /// The units the section sees, by ID.
  final Map<String, UnitView> units;

  /// The HQs it sees.
  final List<HqView> hqs;

  /// The relics.
  final List<RelicView> relics;

  /// The player's team.
  final String? team;

  /// The player's section.
  final String? sectionId;

  /// The selected unit, one of the section's.
  final String? selectedId;

  /// How the battle is seen.
  final ViewMode viewMode;

  /// The host's answer to the last order.
  final OrderNotice? notice;

  /// What stopped it or made it fail, for the player.
  final String? problem;

  /// Grows with each message of the host.
  final int revision;

  /// The selected unit, while the section sees it.
  UnitView? get selected => units[selectedId];

  /// The unit whose eyes the battle is seen through, while the section has
  /// it; null from above.
  UnitView? get seenFrom => switch (viewMode) {
    FirstPersonMode(:final unitId) => units[unitId],
    TopDownMode() => null,
  };

  /// Whether [unit] can be seen from: one of the section's, alive and on the
  /// field. A stored or carried unit has no view of its own, and a unit the
  /// section no longer sees is gone.
  bool canSeeFrom(UnitView? unit) =>
      unit != null &&
      unit.sectionId == sectionId &&
      unit.hp > 0 &&
      unit.position != null &&
      unit.private?.place == UnitPlace.deployed;

  /// The player's section's units, deployed or stored, in ID order.
  List<UnitView> get sectionUnits {
    final mine = [
      for (final unit in units.values)
        if (unit.sectionId == sectionId) unit,
    ];
    return mine..sort((a, b) => a.unitId.compareTo(b.unitId));
  }

  /// This state with the values given; [selectedId] and [notice] are
  /// functions so that they can be cleared.
  BattleState copyWith({
    BattleStatus? status,
    Map<String, UnitView>? units,
    List<HqView>? hqs,
    List<RelicView>? relics,
    String? team,
    String? sectionId,
    String? Function()? selectedId,
    ViewMode? viewMode,
    OrderNotice? Function()? notice,
    String? problem,
    int? revision,
  }) => BattleState(
    status: status ?? this.status,
    units: units ?? this.units,
    hqs: hqs ?? this.hqs,
    relics: relics ?? this.relics,
    team: team ?? this.team,
    sectionId: sectionId ?? this.sectionId,
    selectedId: selectedId == null ? this.selectedId : selectedId(),
    viewMode: viewMode ?? this.viewMode,
    notice: notice == null ? this.notice : notice(),
    problem: problem ?? this.problem,
    revision: revision ?? this.revision,
  );

  @override
  List<Object?> get props => [
    status,
    units,
    hqs,
    relics,
    team,
    sectionId,
    selectedId,
    viewMode,
    notice,
    problem,
    revision,
  ];
}
