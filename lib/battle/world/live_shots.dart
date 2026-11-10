import 'dart:math' as math;

import 'package:battle_team/battle/shots/shot_effect.dart';
import 'package:flutter/animation.dart';

/// {@template shot_look}
/// How long each shot effect lives, in seconds. Display constants, not game
/// numbers.
/// {@endtemplate}
abstract final class ShotLook {
  /// A tracer, from the shooter to the unit hit.
  static const tracerS = 0.25;

  /// A muzzle flash.
  static const flashS = 0.15;

  /// A hit mark.
  static const hitS = 0.6;

  /// The most one frame ages an effect, in seconds: a frame that hitches
  /// does not take a shot off the screen before it was drawn once.
  static const maxStepS = 0.05;

  /// The seconds [effect] lives.
  static double lifeOf(ShotEffect effect) => switch (effect) {
    Tracer() => tracerS,
    MuzzleFlash() => flashS,
    HitMark() => hitS,
  };
}

/// {@template live_shot}
/// A [ShotEffect] on screen. The scene keeps one node per live shot and
/// finds it again by the shot itself, so a shot ages in place.
/// {@endtemplate}
class LiveShot {
  /// {@macro live_shot}
  new(this.effect) : lifeS = ShotLook.lifeOf(effect);

  /// The effect.
  final ShotEffect effect;

  /// Seconds it lives.
  final double lifeS;

  /// Seconds since it appeared.
  double ageS = 0;

  /// How far through its life it is, from 0 to 1, in a straight line.
  double get _t => (ageS / lifeS).clamp(0, 1).toDouble();

  /// How far through its life it is, eased out the way Flutter's animations
  /// ease a short effect: a hit mark swells fast, then slowly.
  double get progress => Curves.easeOut.transform(_t);

  /// How visible it is: full for most of its life, then fading out quickly
  /// (eased in), gone at its end.
  double get opacity => 1 - Curves.easeIn.transform(_t);

  /// Whether its life is over.
  bool get expired => ageS >= lifeS;
}

/// {@template live_shots}
/// The shot effects on screen: the world adds what the section sees, moves
/// them on with its clock and draws what is left. Pure Dart, so that what
/// lives and for how long is tested without a GPU; the scene only draws it
/// (Flutter's animation curves give the fade).
/// {@endtemplate}
class LiveShots {
  /// {@macro live_shots}
  new();

  final _live = <LiveShot>[];

  /// The effects on screen, oldest first.
  List<LiveShot> get live => List.unmodifiable(_live);

  /// Puts [effects] on screen, and returns them as live shots.
  List<LiveShot> add(Iterable<ShotEffect> effects) {
    final added = effects.map(LiveShot.new).toList();
    _live.addAll(added);
    return added;
  }

  /// Moves on by [seconds], at most [ShotLook.maxStepS]. Effects whose life
  /// is over leave the screen and are returned, so that the scene takes them
  /// down.
  List<LiveShot> advance(double seconds) {
    final step = math.min(seconds, ShotLook.maxStepS);
    for (final shot in _live) {
      shot.ageS += step;
    }
    final gone = _live.where((shot) => shot.expired).toList();
    _live.removeWhere((shot) => shot.expired);
    return gone;
  }
}
