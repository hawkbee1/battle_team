import 'package:battle_protocol/battle_protocol.dart';
import 'package:equatable/equatable.dart';

/// {@template shot_effect}
/// Something the world draws for a moment when the section sees a shot: a
/// tracer, a muzzle flash, a hit mark. Transient, never part of the battle's
/// state, so that a rebuild does not replay it.
///
/// An effect holds exactly what the section may see (COMBAT-57, COMBAT-58,
/// decisions 234 and 237): a hit it was not told the shooter of has no origin;
/// a shot whose target it does not see has no target.
/// {@endtemplate}
sealed class ShotEffect extends Equatable {
  /// {@macro shot_effect}
  const new();
}

/// {@template tracer}
/// A seen shot, from [from], the seen shooter, to [to], the seen unit it hit.
/// {@endtemplate}
final class Tracer extends ShotEffect {
  /// {@macro tracer}
  const new({required this.from, required this.to, required this.weapon});

  /// Where the shooter stands.
  final Position from;

  /// Where the unit hit stands.
  final Position to;

  /// The weapon type fired.
  final String weapon;

  @override
  List<Object?> get props => [from, to, weapon];
}

/// {@template muzzle_flash}
/// A seen unit at [at] fired, and the section does not see where the shot
/// went or whether it hit (COMBAT-58): nothing but the shooter.
/// {@endtemplate}
final class MuzzleFlash extends ShotEffect {
  /// {@macro muzzle_flash}
  const new({required this.at, required this.weapon});

  /// Where the shooter stands.
  final Position at;

  /// The weapon type fired.
  final String weapon;

  @override
  List<Object?> get props => [at, weapon];
}

/// {@template hit_mark}
/// A seen unit at [at] was hit, with [result]: nothing of who hit it
/// (COMBAT-57).
/// {@endtemplate}
final class HitMark extends ShotEffect {
  /// {@macro hit_mark}
  const new({required this.at, required this.result});

  /// Where the unit hit stands.
  final Position at;

  /// What the hit did.
  final ImpactResult result;

  @override
  List<Object?> get props => [at, result];
}
