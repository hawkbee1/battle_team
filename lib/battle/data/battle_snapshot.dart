import 'package:battle_protocol/battle_protocol.dart';
import 'package:equatable/equatable.dart';

/// {@template battle_snapshot}
/// What the section's view holds at one moment: the units it knows, the HQs
/// it sees, the relics, its own state (its spare weapons, its lock, its
/// prisoners), the recalls it runs, and the seat the
/// player signed in as. The host sends only what the section sees (decision
/// 237): a snapshot holds nothing more.
/// {@endtemplate}
class BattleSnapshot extends Equatable {
  /// {@macro battle_snapshot}
  const new({
    required this.units,
    required this.hqs,
    required this.relics,
    this.section,
    this.recalls = const {},
    this.team,
    this.sectionId,
  });

  /// The units the section knows, by ID.
  final Map<String, UnitView> units;

  /// The HQs it sees.
  final List<HqView> hqs;

  /// The relics.
  final List<RelicView> relics;

  /// The section's own state, once the host's whole view came.
  final SectionPrivate? section;

  /// The recalls the section's units run (HQ-32): the battle time each is
  /// stored, by unit ID.
  final Map<String, Duration> recalls;

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
    team,
    sectionId,
  ];
}
