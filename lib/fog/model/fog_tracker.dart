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

/// {@template fog_tracker}
/// Keeps the [FogModel] of the section's sight (M7 Issue 9, MAP-27, MAP-29):
/// from each of the section's own units (its position, its sight range as the
/// host sent it, the eyes of its type) and the battle's weather,
/// `battle_rules`' vision over the map's heights through [GroundSight], for
/// display only (stack decision 8). It computes again only for a unit that
/// moved or whose range changed, and for all of them when the weather or the
/// delta layer changes (a wall built, a crater dug).
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
      );

  /// The unit types' bodies, which their eyes are placed by.
  final UnitBodies bodies;

  static final _log = Logger('battle_team.FogTracker');

  final GroundSight _base;
  GroundSight _sight;
  FogModel _model;
  int? _worldVersion;
  final _cache = <String, (_Sight, List<int>)>{};
  Set<int> _lit = {};

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
    if (worldVersion != _worldVersion) {
      _worldVersion = worldVersion;
      _sight = _base.withWorld(world);
      _cache.clear();
    }
    final lit = <int>{};
    final present = <String>{};
    for (final unit in units) {
      final sight = _sightOf(unit, weather);
      if (sight == null) continue;
      present.add(unit.unitId);
      final cached = _cache[unit.unitId];
      if (cached == null || cached.$1 != sight) {
        final seen = _sight.seenFrom(
          from: CellRef(sight.x, sight.y, surface: sight.surface),
          flying: sight.flying,
          heightM: sight.eyesM,
          rangeM: sight.rangeM,
          weather: weather,
        );
        _cache[unit.unitId] = (sight, seen);
        lit.addAll(seen);
      } else {
        lit.addAll(cached.$2);
      }
    }
    _cache.removeWhere((id, _) => !present.contains(id));
    if (lit.length == _lit.length && lit.containsAll(_lit)) return null;
    _lit = lit;
    return _model = _model.lighting(lit);
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
