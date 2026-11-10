part of 'shop_cubit.dart';

/// {@template purchase_notice}
/// The answer to the last purchase: the host's, or the pre-check's when it
/// expected a refusal and the order was not sent.
/// {@endtemplate}
class PurchaseNotice extends Equatable {
  /// {@macro purchase_notice}
  const new({required this.order, required this.item, this.refusal});

  /// The order, as a word: `buy_unit` or `buy_weapon`.
  final String order;

  /// What was bought: a unit type or a weapon type.
  final String item;

  /// Why it was refused; null when the host accepted it.
  final String? refusal;

  @override
  List<Object?> get props => [order, item, refusal];
}

/// {@template shop_state}
/// What the shop shows: the host's roster, the section's money and lock, its
/// own units (for the room it has and the weapons a unit may use) and the
/// answer to the last purchase. Everything is the section's own view
/// (HQ-29, decision 237).
/// {@endtemplate}
class ShopState extends Equatable {
  /// {@macro shop_state}
  const new({
    this.roster,
    this.section,
    this.units = const {},
    this.team,
    this.sectionId,
    this.portal,
    this.notice,
    this.revision = 0,
  });

  /// What the battle lets the section buy; null until the host sent it.
  final Roster? roster;

  /// The section's own state: its money and its lock.
  final SectionPrivate? section;

  /// The units the section sees, by ID.
  final Map<String, UnitView> units;

  /// The player's team.
  final String? team;

  /// The player's section.
  final String? sectionId;

  /// Where bought units arrive: the position of its team's HQ, once the
  /// section sees it.
  final Position? portal;

  /// The answer to the last purchase.
  final PurchaseNotice? notice;

  /// Grows with each message of the host.
  final int revision;

  /// The section's own units, wherever they are, in ID order.
  List<UnitView> get ownUnits => [
    for (final unit in units.values)
      if (unit.sectionId == sectionId && unit.private != null) unit,
  ]..sort((a, b) => a.unitId.compareTo(b.unitId));

  /// This state with the values given; [portal] and [notice] are functions so
  /// that they can be cleared.
  ShopState copyWith({
    Roster? roster,
    SectionPrivate? section,
    Map<String, UnitView>? units,
    String? team,
    String? sectionId,
    Position? Function()? portal,
    PurchaseNotice? Function()? notice,
    int? revision,
  }) => ShopState(
    roster: roster ?? this.roster,
    section: section ?? this.section,
    units: units ?? this.units,
    team: team ?? this.team,
    sectionId: sectionId ?? this.sectionId,
    portal: portal == null ? this.portal : portal(),
    notice: notice == null ? this.notice : notice(),
    revision: revision ?? this.revision,
  );

  @override
  List<Object?> get props => [
    roster,
    section,
    units,
    team,
    sectionId,
    portal,
    notice,
    revision,
  ];
}
