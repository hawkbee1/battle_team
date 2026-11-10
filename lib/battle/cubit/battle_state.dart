part of 'battle_cubit.dart';

/// Where the playtest stands.
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
/// What the playtest shows: the section's view, the selected unit and the
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

  /// The host's answer to the last order.
  final OrderNotice? notice;

  /// What stopped it or made it fail, for the player.
  final String? problem;

  /// Grows with each message of the host.
  final int revision;

  /// The selected unit, while the section sees it.
  UnitView? get selected => units[selectedId];

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
    notice,
    problem,
    revision,
  ];
}
