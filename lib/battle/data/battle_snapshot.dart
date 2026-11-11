import 'package:battle_protocol/battle_protocol.dart';
import 'package:equatable/equatable.dart';

/// {@template battle_snapshot}
/// What the section's view holds at one moment: the units it knows, the HQs
/// it sees, the relics, its own state (its spare weapons, its lock, its
/// prisoners), the recalls it runs, what the battle lets it buy (the host's
/// `Roster`), the weather and the delta layer (which every section knows,
/// MAP-49), the victory countdown, and the seat the player signed in as. The
/// host sends only what the section sees (decision 237): a snapshot holds
/// nothing more.
/// {@endtemplate}
class BattleSnapshot extends Equatable {
  /// {@macro battle_snapshot}
  const new({
    required this.units,
    required this.hqs,
    required this.relics,
    this.section,
    this.recalls = const {},
    this.roster,
    this.team,
    this.sectionId,
    this.weather,
    this.world = const [],
    this.worldVersion = 0,
    this.hold,
  });

  /// The units the section knows, by ID.
  final Map<String, UnitView> units;

  /// The HQs it sees.
  final List<HqView> hqs;

  /// The relics.
  final List<RelicView> relics;

  /// The battle's weather, once the host's whole view came (MAP-31).
  final String? weather;

  /// The delta layer as world events (MAP-08), which sight lines read.
  final List<BattleEvent> world;

  /// Changes with [world], so that a view looks at it again only then.
  final int worldVersion;

  /// The running victory countdown (RELIC-16, MAP-49).
  final HoldView? hold;

  /// The section's own state, once the host's whole view came.
  final SectionPrivate? section;

  /// The recalls the section's units run (HQ-32): the battle time each is
  /// stored, by unit ID.
  final Map<String, Duration> recalls;

  /// What the battle lets the section buy, once the host sent it (ECO-04,
  /// COMBAT-27).
  final Roster? roster;

  /// The player's team, once signed in.
  final String? team;

  /// The player's section, once signed in.
  final String? sectionId;

  @override
  List<Object?> get props => [
    units,
    hqs,
    relics,
    section,
    recalls,
    roster,
    team,
    sectionId,
    weather,
    world,
    worldVersion,
    hold,
  ];
}
