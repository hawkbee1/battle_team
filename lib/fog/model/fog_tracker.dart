import 'dart:typed_data';

import 'package:battle_client/battle_client.dart';
import 'package:battle_pathfinding/battle_pathfinding.dart' show CellRef;
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/data/unit_bodies.dart';
import 'package:battle_team/fog/model/fog_model.dart';
import 'package:logging/logging.dart';

/// What a unit's sight depends on: where it stands, how high its eyes are, how
/// far it sees and the weather. The ground it lights is recomputed only when
/// one of them changes.
typedef _Sight = ({
  int x,
  int y,
  String surface,
  bool flying,
  double eyesM,
  double rangeM,
  String weather,
});

/// How the delta layer changed since the last update, for a sight line.
enum _Layer {
  /// In nothing a sight line reads.
  same,

  /// It has new events, applied on top of the others.
  grew,

  /// Events it had are gone: the host sent it whole again (a resync), and
  /// it is applied anew on the map as built.
  replayed,
}

/// {@template fog_tracker}
/// Keeps the [FogModel] of the section's sight (M7 Issue 9, MAP-27, MAP-29):
/// from each of the section's own units (its position, its sight range as the
/// host sent it, the eyes of its type) and the battle's weather,
/// `battle_rules`' vision over the map's heights through [GroundSight], for
/// display only (stack decision 8). It computes again only for a unit that
/// moved or whose range changed, and for all of them when the weather
/// changes. A change of the delta layer (a wall built, a crater dug) is
/// applied on top of the layer it had, and walks again only the lines it can
/// cross, of the units within reach of it; a message of the host that
/// changes none of them costs next to nothing.
///
/// Nothing of any other unit feeds it (decision 237): a unit without private
/// state, a hit the section did not see, an enemy that left sight are not its
/// inputs, so they leave no mark. The grid is view state; it logs nothing.
/// {@endtemplate}
final class FogTracker {
  /// {@macro fog_tracker}
  new({required GroundSight sight, required this.bodies})
    : _base = sight,
      _sight = sight,
      _model = FogModel.dark(
        width: sight.width,
        depth: sight.depth,
        cellSizeM: sight.cellSizeM,
      ),
      _sightsOn = Uint16List(sight.width * sight.depth);

  /// The unit types' bodies, which their eyes are placed by.
  final UnitBodies bodies;

  static final _log = Logger('battle_team.FogTracker');

  final GroundSight _base;
  GroundSight _sight;
  FogModel _model;
  int? _worldVersion;

  // The events of the delta layer [_sight] has, by identity: the host adds
  // events to the layer, and sends it whole again, as new events, after a
  // resync.
  var _applied = Set<BattleEvent>.identity();

  final _cache = <String, (_Sight, List<int>)>{};

  // How many of the sights in the cache light each cell: a cell is lit
  // while one does.
  final Uint16List _sightsOn;

  /// What the section knows of the ground now.
  FogModel get model => _model;

  /// Brings the model to the section's [units] in [weather] with the delta
  /// layer [world] (at [worldVersion]); gives the new model when the ground
  /// in sight changed, null otherwise. Before the host's whole view there is
  /// no weather and nothing to compute.
  FogModel? update({
    required Iterable<UnitView> units,
    required String? weather,
    required List<BattleEvent> world,
    required int worldVersion,
  }) {
    if (weather == null) return null;
    final layer = worldVersion == _worldVersion ? _Layer.same : _follow(world);
    _worldVersion = worldVersion;
    // The cells whose count of sights started or stopped at 0.
    final touched = <int>[];
    final present = <String>{};
    for (final unit in units) {
      final sight = _sightOf(unit, weather);
      if (sight == null) continue;
      present.add(unit.unitId);
      final cached = _cache[unit.unitId];
      final List<int> seen;
      if (cached == null || cached.$1 != sight || layer == _Layer.replayed) {
        seen = _seen(sight);
      } else if (layer == _Layer.grew) {
        seen = _seen(sight, before: cached.$2);
        if (identical(seen, cached.$2)) continue;
      } else {
        continue;
      }
      if (cached != null) _count(cached.$2, -1, touched);
      _count(seen, 1, touched);
      _cache[unit.unitId] = (sight, seen);
    }
    _cache.removeWhere((id, cached) {
      if (present.contains(id)) return false;
      _count(cached.$2, -1, touched);
      return true;
    });
    final levels = _model.levels;
    final lit = <int>[];
    final dimmed = <int>[];
    for (final cell in touched) {
      final wasLit = levels[cell] == FogLevel.lit.index;
      if (_sightsOn[cell] > 0) {
        if (!wasLit) lit.add(cell);
      } else if (wasLit) {
        dimmed.add(cell);
      }
    }
    if (lit.isEmpty && dimmed.isEmpty) return null;
    return _model = _model.lighting(lit: lit, dimmed: dimmed);
  }

  /// Brings the sight to the delta layer [world]: its new events on top of
  /// the others, or the whole layer on the map as built when events the
  /// sight has are gone from it.
  _Layer _follow(List<BattleEvent> world) {
    final read = [
      for (final event in world)
        if (_base.reads(event)) event,
    ];
    final fresh = [
      for (final event in read)
        if (!_applied.contains(event)) event,
    ];
    if (read.length - fresh.length < _applied.length) {
      _sight = _base.withWorld(read);
      _applied = Set.identity()..addAll(read);
      return _Layer.replayed;
    }
    if (fresh.isEmpty) return _Layer.same;
    _sight = _sight.withWorld(fresh);
    _applied.addAll(fresh);
    return _Layer.grew;
  }

  /// The ground [sight] lights, or, from [before], what it lit before the
  /// delta layer grew.
  List<int> _seen(_Sight sight, {List<int>? before}) {
    final from = CellRef(sight.x, sight.y, surface: sight.surface);
    return before == null
        ? _sight.seenFrom(
            from: from,
            flying: sight.flying,
            heightM: sight.eyesM,
            rangeM: sight.rangeM,
            weather: sight.weather,
          )
        : _sight.seenAgainFrom(
            before: before,
            from: from,
            flying: sight.flying,
            heightM: sight.eyesM,
            rangeM: sight.rangeM,
            weather: sight.weather,
          );
  }

  /// Adds [by] to the count of sights on each of [cells]; a cell whose count
  /// starts or stops at 0 goes to [touched].
  void _count(List<int> cells, int by, List<int> touched) {
    for (final cell in cells) {
      final was = _sightsOn[cell];
      _sightsOn[cell] = was + by;
      if (was == 0 || was + by == 0) touched.add(cell);
    }
  }

  /// The sight of [unit] if it is one of the section's own on the field: only
  /// those have private state, which holds the range (decision 237).
  _Sight? _sightOf(UnitView unit, String weather) {
    final private = unit.private;
    final position = unit.position;
    if (private == null ||
        position == null ||
        private.place == UnitPlace.stored ||
        private.place == UnitPlace.prisoner) {
      return null;
    }
    final eyes = bodies.eyeHeightOf(unit.unitType);
    final cell = _sight.cellAt(position);
    if (eyes == null || cell == null) {
      _log.fine('a unit has no sight: no body for its type, or off the map');
      return null;
    }
    return (
      x: cell.x,
      y: cell.y,
      surface: cell.surface,
      flying: unit.flying,
      eyesM: eyes,
      rangeM: private.sightRangeM,
      weather: weather,
    );
  }
}
