part of 'storage_cubit.dart';

/// {@template storage_state}
/// What the storage view shows: the section's own units, its lock and its
/// prisoners, the recalls it runs, the units it sees (for the enemy that
/// blocks a deployment) and the answer to the last order. Everything comes
/// from the section's own view (HQ-29, decision 237): nothing of another
/// section's storage.
/// {@endtemplate}
class StorageState extends Equatable {
  /// {@macro storage_state}
  const new({
    this.units = const {},
    this.sectionId,
    this.portal,
    this.lockedUntil,
    this.prisoners = const [],
    this.recalls = const {},
    this.notice,
    this.revision = 0,
  });

  /// The units the section sees, by ID.
  final Map<String, UnitView> units;

  /// The player's section.
  final String? sectionId;

  /// Where the section stores and deploys: the position of its team's HQ,
  /// once the section sees it.
  final Position? portal;

  /// The end of the section's full storage lock (HQ-35); null without one.
  final Duration? lockedUntil;

  /// The units of other sections the section holds prisoner (HQ-37).
  final List<JoinedUnit> prisoners;

  /// The recalls the section's units run: the battle time each is stored.
  final Map<String, Duration> recalls;

  /// The host's answer to the last store, recall or deploy order.
  final OrderNotice? notice;

  /// Grows with each message of the host.
  final int revision;

  /// The section's units, in ID order.
  List<UnitView> get sectionUnits => [
    for (final unit in units.values)
      if (unit.sectionId == sectionId) unit,
  ]..sort((a, b) => a.unitId.compareTo(b.unitId));

  /// The section's units in storage, in ID order (HQ-29: only its own).
  List<UnitView> get stored => [
    for (final unit in sectionUnits)
      if (unit.private?.place == UnitPlace.stored) unit,
  ];

  /// This state with the values given; [lockedUntil], [portal] and [notice]
  /// are functions so that they can be cleared.
  StorageState copyWith({
    Map<String, UnitView>? units,
    String? sectionId,
    Position? Function()? portal,
    Duration? Function()? lockedUntil,
    List<JoinedUnit>? prisoners,
    Map<String, Duration>? recalls,
    OrderNotice? Function()? notice,
    int? revision,
  }) => StorageState(
    units: units ?? this.units,
    sectionId: sectionId ?? this.sectionId,
    portal: portal == null ? this.portal : portal(),
    lockedUntil: lockedUntil == null ? this.lockedUntil : lockedUntil(),
    prisoners: prisoners ?? this.prisoners,
    recalls: recalls ?? this.recalls,
    notice: notice == null ? this.notice : notice(),
    revision: revision ?? this.revision,
  );

  @override
  List<Object?> get props => [
    units,
    sectionId,
    portal,
    lockedUntil,
    prisoners,
    recalls,
    notice,
    revision,
  ];
}
