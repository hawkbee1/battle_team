import 'dart:async';
import 'dart:math' as math;

import 'package:battle_map/battle_map.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/cubit/battle_cubit.dart';
import 'package:battle_team/battle/data/unit_bodies.dart';
import 'package:battle_team/battle/widgets/move_panel.dart';
import 'package:battle_team/battle/widgets/weapon_panel.dart';
import 'package:battle_team/battle/world/battle_camera.dart';
import 'package:battle_team/battle/world/battle_space.dart';
import 'package:battle_team/battle/world/battle_world.dart';
import 'package:battle_team/battle/world/first_person_camera.dart';
import 'package:battle_team/battle/world/top_down_camera.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:battle_team/shop/widgets/shop_panel.dart';
import 'package:battle_team/storage/cubit/storage_cubit.dart';
import 'package:battle_team/storage/widgets/storage_panel.dart';
import 'package:battle_team/storage/widgets/store_button.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector_math/vector_math.dart' show Vector3, degrees2Radians;

/// Builds the 3D area of [world] seen from [camera]; [onTick] is called on
/// each frame with the seconds since the last one.
typedef BattleSceneBuilder = Widget Function(
  BuildContext context,
  BattleWorld world,
  BattleCamera camera,
  void Function(double seconds) onTick,
);

/// {@template battle_view}
/// The battle seen from above, or through the eyes of one of the section's
/// units (decision 5): the map of [map] in [world], the units the section
/// sees, and the orders of the player. From above, drag to pan, scroll or
/// pinch to zoom, Q/E or two fingers to turn; tap one of your units, then the
/// ground, to move it there, or an enemy to target it. From a unit, drag to
/// look, tap the ground to move there, and fire where the reticle points.
///
/// It draws the shots the cubit announces (Observer): the world shows each
/// for a moment, and nothing of them is kept in the state.
///
/// The cubit's view mode picks the camera (Strategy, `BattleCamera`): the
/// view keeps one of each, so that coming back from a unit finds the overview
/// where it was. The world draws the same units from either.
/// {@endtemplate}
class BattleView extends StatefulWidget {
  /// {@macro battle_view}
  const new({
    required this.map,
    required this.world,
    required this.sceneBuilder,
    required this.bodies,
    super.key,
  });

  /// The battle's map.
  final MapData map;

  /// The 3D world.
  final BattleWorld world;

  /// Builds the 3D area.
  final BattleSceneBuilder sceneBuilder;

  /// The unit types' bodies, which the eyes of a unit are placed by.
  final UnitBodies bodies;

  @override
  State<BattleView> createState() => _BattleViewState();
}

class _BattleViewState extends State<BattleView> {
  static final _log = Logger('battle_team.BattleView');

  late final TopDownCamera _topDown;
  FirstPersonCamera? _firstPerson;
  late final StreamSubscription<Object?> _shots;
  final _frame = ValueNotifier<int>(0);
  final _focus = FocusNode();
  bool _storageOpen = false;
  bool _shopOpen = false;
  double _lastScale = 1;
  double _lastRotation = 0;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    final surface = widget.world.surface;
    final centre = Vector3(surface.widthM / 2, 0, -surface.depthM / 2);
    centre.y = surface.heightAt(centre.x, -centre.z);
    _topDown = TopDownCamera(target: centre, distance: 700);
    widget.world.useCamera(_topDown);
    final cubit = context.read<BattleCubit>();
    _shots = cubit.shots.listen(widget.world.showShots);
    _show(cubit.state, centreOnUnits: true);
  }

  /// The camera of the view mode now.
  BattleCamera get _camera => _firstPerson ?? _topDown;

  @override
  void dispose() {
    unawaited(_shots.cancel());
    _frame.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _show(BattleState state, {bool centreOnUnits = false}) {
    widget.world.show(
      units: state.units.values,
      hqs: state.hqs,
      relics: state.relics,
      selected: state.selectedId,
      target: state.target?.unitId,
      battleTime: context.read<BattleCubit>().battleTime,
    );
    widget.world.showPath(state.pendingMove?.points);
    if (centreOnUnits) _centreOnSection(state);
  }

  /// Looks at the section's units the first time it sees them, or at its
  /// HQ while none is out; `force` looks again (the Centre button).
  bool _centred = false;
  void _centreOnSection(BattleState state, {bool force = false}) {
    if (_centred && !force) return;
    final mine = [
      for (final unit in state.sectionUnits)
        if (unit.position != null) worldOf(unit.position!),
    ];
    final home = [
      for (final hq in state.hqs)
        if (hq.team == state.team) worldOf(hq.position),
    ];
    final points = mine.isNotEmpty ? mine : home;
    if (points.isEmpty) return;
    if (mine.isNotEmpty) _centred = true;
    final sum =
        points.fold(Vector3.zero(), (a, b) => a + b) / points.length.toDouble();
    sum.y = widget.world.surface.heightAt(sum.x, -sum.z);
    _topDown
      ..target = sum
      ..distance = 120;
    _frame.value++;
  }

  /// Follows the cubit's view mode: sees through the eyes of its unit, or
  /// goes back to the overview.
  void _syncCamera(BattleState state) {
    final mode = state.viewMode;
    if (mode is FirstPersonMode && _firstPerson?.unitId != mode.unitId) {
      _enterFirstPerson(state, mode.unitId);
    } else if (mode is TopDownMode && _firstPerson != null) {
      setState(() => _firstPerson = null);
      widget.world.useCamera(_topDown);
    }
  }

  void _enterFirstPerson(BattleState state, String unitId) {
    final unit = state.units[unitId]!;
    final eye = widget.bodies.eyeHeightOf(unit.unitType);
    if (eye == null) {
      // Data the app does not know (an older client): stay above.
      _log.warning('first person unavailable: no body for the unit type');
      context.read<BattleCubit>().leaveFirstPerson();
      return;
    }
    final camera = FirstPersonCamera(
      unitId: unitId,
      eyeHeightM: eye,
      feet: widget.world.drawn[unitId]!,
      yaw: _topDown.heading,
    );
    setState(() => _firstPerson = camera);
    widget.world.useCamera(camera);
  }

  void _centreNow() =>
      _centreOnSection(context.read<BattleCubit>().state, force: true);

  void _tick(double seconds) {
    widget.world.tick(seconds);
    // The eyes go where the unit is drawn: gliding to its destination
    // (decision 236).
    final inside = _firstPerson;
    if (inside != null) {
      final feet = widget.world.drawn[inside.unitId];
      if (feet != null) inside.standAt(feet);
    }
    _frame.value++;
  }

  void _tap(Offset at) {
    final cubit = context.read<BattleCubit>();
    final state = cubit.state;
    final view = _camera.view(_size);
    String? nearest;
    var best = 28.0;
    for (final MapEntry(key: id, value: drawn) in widget.world.drawn.entries) {
      if (id == _camera.insideUnit) continue;
      final onScreen = view.project(drawn + Vector3(0, 3, 0));
      if (onScreen == null) continue;
      final distance = (onScreen - at).distance;
      if (distance < best) {
        best = distance;
        nearest = id;
      }
    }
    final unit = state.units[nearest];
    if (unit != null && unit.sectionId == state.sectionId) {
      cubit.select(unit.unitId == state.selectedId ? null : unit.unitId);
      return;
    }
    // A unit of another section is a target (COMBAT-11), not a place to go.
    if (unit != null) {
      cubit.target(unit.unitId);
      return;
    }
    final ground = widget.world.surface.hit(
      view.position,
      view.directionAt(at),
    );
    if (ground != null && state.selected != null) {
      final there = positionOf(ground);
      // From above a move is previewed and confirmed (M7 Issue 8); from a
      // unit's eyes it is a step of a stream and goes at once.
      unawaited(
        state.groundFire
            ? cubit.fireSelectedAt(there)
            : _firstPerson != null
            ? cubit.moveSelectedTo(there)
            : cubit.previewMoveTo(there),
      );
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final done = switch (_firstPerson) {
      final inside? => _keyFirstPerson(inside, key),
      null => _keyTopDown(key),
    };
    return done ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  bool _keyTopDown(LogicalKeyboardKey key) {
    const step = 60.0;
    return switch (key) {
      LogicalKeyboardKey.arrowLeft => _do(
        () => _topDown.pan(const Offset(step, 0), _size),
      ),
      LogicalKeyboardKey.arrowRight => _do(
        () => _topDown.pan(const Offset(-step, 0), _size),
      ),
      LogicalKeyboardKey.arrowUp => _do(
        () => _topDown.pan(const Offset(0, step), _size),
      ),
      LogicalKeyboardKey.arrowDown => _do(
        () => _topDown.pan(const Offset(0, -step), _size),
      ),
      LogicalKeyboardKey.keyQ => _do(
        () => _topDown.turn(-15 * degrees2Radians),
      ),
      LogicalKeyboardKey.keyE => _do(() => _topDown.turn(15 * degrees2Radians)),
      LogicalKeyboardKey.equal ||
      LogicalKeyboardKey.add ||
      LogicalKeyboardKey.numpadAdd => _do(() => _topDown.zoom(1.25)),
      LogicalKeyboardKey.minus ||
      LogicalKeyboardKey.numpadSubtract => _do(() => _topDown.zoom(0.8)),
      LogicalKeyboardKey.escape => _do(_escape),
      _ => false,
    };
  }

  /// Gives up a previewed move, else firing at a position, else clears the
  /// selection.
  void _escape() {
    final cubit = context.read<BattleCubit>();
    if (cubit.state.pendingMove != null) {
      cubit.cancelMove();
    } else if (cubit.state.groundFire) {
      cubit.toggleGroundFire();
    } else {
      cubit.select(null);
    }
  }

  /// From a unit's eyes: the arrows look around a little, Q/E turn, Escape
  /// goes back above and keeps the unit selected.
  bool _keyFirstPerson(FirstPersonCamera inside, LogicalKeyboardKey key) {
    const step = 30.0;
    return switch (key) {
      LogicalKeyboardKey.arrowLeft => _do(
        () => inside.look(const Offset(-step, 0)),
      ),
      LogicalKeyboardKey.arrowRight => _do(
        () => inside.look(const Offset(step, 0)),
      ),
      LogicalKeyboardKey.arrowUp => _do(
        () => inside.look(const Offset(0, -step)),
      ),
      LogicalKeyboardKey.arrowDown => _do(
        () => inside.look(const Offset(0, step)),
      ),
      LogicalKeyboardKey.keyQ => _do(() => inside.turn(-15 * degrees2Radians)),
      LogicalKeyboardKey.keyE => _do(() => inside.turn(15 * degrees2Radians)),
      LogicalKeyboardKey.escape => _do(
        context.read<BattleCubit>().leaveFirstPerson,
      ),
      _ => false,
    };
  }

  bool _do(void Function() action) {
    action();
    _frame.value++;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BattleCubit, BattleState>(
      listener: (context, state) {
        _show(state, centreOnUnits: true);
        _syncCamera(state);
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _key,
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _size = constraints.biggest;
                  return Listener(
                    onPointerSignal: (signal) {
                      if (signal is PointerScrollEvent &&
                          _firstPerson == null) {
                        _do(
                          () => _topDown.zoom(
                            math.pow(1.0015, -signal.scrollDelta.dy).toDouble(),
                          ),
                        );
                      }
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) => _tap(details.localPosition),
                      onScaleStart: (_) {
                        _lastScale = 1;
                        _lastRotation = 0;
                      },
                      onScaleUpdate: (details) => _do(() {
                        // From a unit's eyes a drag, with one finger or
                        // two, looks around.
                        if (_firstPerson case final inside?) {
                          inside.look(details.focalPointDelta);
                          return;
                        }
                        _topDown
                          ..pan(details.focalPointDelta, _size)
                          ..zoom(details.scale / _lastScale)
                          ..turn(_lastRotation - details.rotation);
                        _lastScale = details.scale;
                        _lastRotation = details.rotation;
                      }),
                      child: widget.sceneBuilder(
                        context,
                        widget.world,
                        _camera,
                        _tick,
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: ValueListenableBuilder(
                  valueListenable: _frame,
                  builder: (context, _, _) => _UnitLabels(
                    world: widget.world,
                    view: _camera.view(_size),
                    all: _firstPerson != null || _topDown.distance < 200,
                    hide: _camera.insideUnit,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              right: 12,
              child: _Header(
                help: _firstPerson == null
                    ? context.l10n.battleHelp
                    : context.l10n.battleHelpFirstPerson,
              ),
            ),
            Positioned(
              right: 12,
              top: 96,
              child: _UnitsPanel(
                onCentre: _centreNow,
                onStorage: () => setState(() {
                  _storageOpen = !_storageOpen;
                  _shopOpen = false;
                }),
                onShop: () => setState(() {
                  _shopOpen = !_shopOpen;
                  _storageOpen = false;
                }),
              ),
            ),
            if (_storageOpen)
              Positioned(
                left: 12,
                top: 96,
                width: 300,
                // Short enough to leave the selected unit's panel below.
                child: BlocSelector<BattleCubit, BattleState, bool>(
                  selector: (state) => state.selectedId != null,
                  builder: (context, selected) => ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: math.max(
                        80,
                        MediaQuery.sizeOf(context).height -
                            96 -
                            (selected ? 200 : 12),
                      ),
                    ),
                    child: _Panel(
                      child: SingleChildScrollView(
                        child: StoragePanel(
                          onClose: () => setState(() => _storageOpen = false),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_shopOpen)
              Positioned(
                left: 12,
                top: 96,
                width: 300,
                // Short enough to leave the selected unit's panel below.
                child: BlocSelector<BattleCubit, BattleState, UnitView?>(
                  selector: (state) => state.selected,
                  builder: (context, selected) => ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: math.max(
                        80,
                        MediaQuery.sizeOf(context).height -
                            96 -
                            (selected != null ? 200 : 12),
                      ),
                    ),
                    child: _Panel(
                      child: SingleChildScrollView(
                        child: ShopPanel(
                          selected: selected,
                          onClose: () => setState(() => _shopOpen = false),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_firstPerson != null) const AimReticle(),
            Positioned(
              left: 12,
              bottom: 12,
              child: ValueListenableBuilder(
                valueListenable: _frame,
                builder: (context, _, _) => _SelectedUnit(
                  aim: switch (_firstPerson) {
                    final inside? => () => directionOf(inside.forward),
                    null => null,
                  },
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: _Credits(lines: widget.map.spec.attribution),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const new({required this.help});

  final String help;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<BattleCubit>().state;
    final team = state.team;
    final section = state.sectionId;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Panel(
          child: Text(
            [
              l10n.battleStatus(state.status.name),
              if (team != null && section != null)
                l10n.battlePlayingAs(team, section),
              ?state.problem,
            ].join('\n'),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: _Panel(
            child: Text(help, style: const TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }
}

/// The section's units, deployed or stored: a tap selects one, Storage opens
/// the storage view (M7 Issue 6), Shop the shop (M7 Issue 7), Centre looks at
/// the section again.
class _UnitsPanel extends StatelessWidget {
  const new({
    required this.onCentre,
    required this.onStorage,
    required this.onShop,
  });

  final VoidCallback onCentre;
  final VoidCallback onStorage;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.watch<BattleCubit>();
    final units = cubit.state.sectionUnits;
    return _Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.battleUnits),
              TextButton(onPressed: onCentre, child: Text(l10n.battleCentre)),
              TextButton(
                onPressed: onStorage,
                child: BlocSelector<StorageCubit, StorageState, int>(
                  selector: (state) => state.stored.length,
                  builder: (context, stored) =>
                      Text(l10n.storageOpen('$stored')),
                ),
              ),
              TextButton(onPressed: onShop, child: Text(l10n.shopOpen)),
            ],
          ),
          for (final unit in units) _UnitRow(unit: unit),
        ],
      ),
    );
  }
}

class _UnitRow extends StatelessWidget {
  const new({required this.unit});

  final UnitView unit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<BattleCubit>();
    final stored = unit.private?.place == UnitPlace.stored;
    return TextButton(
      onPressed: () => cubit.select(unit.unitId),
      child: Text(
        '${unit.unitType} · '
        '${stored ? l10n.battleStored : l10n.battleInField}',
      ),
    );
  }
}

/// The selected unit, its weapon and the answer to the last order, with the
/// button that sees the battle through the unit's eyes, or goes back above.
class _SelectedUnit extends StatelessWidget {
  const new({required this.aim});

  /// The direction the eyes look along, from first person.
  final Direction Function()? aim;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.watch<BattleCubit>();
    final state = cubit.state;
    final unit = state.selected;
    final notice = state.notice;
    final lines = [
      if (unit != null)
        l10n.battleUnit(
          unit.unitType,
          unit.hp.toStringAsFixed(0),
          cubit.apNow(unit)?.toStringAsFixed(1) ?? '–',
        ),
      // The answer to an order of the selected unit, not to another unit's.
      if (notice != null && (unit == null || notice.unitId == unit.unitId))
        switch (notice.refusal) {
          null => l10n.battleOrderAccepted(l10n.battleOrderName(notice.order)),
          final reason => l10n.battleOrderRefused(
            l10n.battleOrderName(notice.order),
            l10n.battleRefusal(reason),
          ),
        },
    ];
    final fromAbove = state.viewMode is TopDownMode;
    final seeable = fromAbove && state.canSeeFrom(unit);
    if (lines.isEmpty) return const SizedBox.shrink();
    return _Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lines.join('\n')),
          if (unit != null) WeaponPanel(unit: unit, aim: aim),
          if (unit != null)
            MovePanel(
              pending: switch (state.pendingMove) {
                final pending? when pending.unitId == unit.unitId => pending,
                _ => null,
              },
              note: switch (state.arrivalNote) {
                final note? when note.unitId == unit.unitId => note,
                _ => null,
              },
              ap: cubit.apNow(unit),
              time: cubit.battleTime,
              onConfirm: () => unawaited(cubit.confirmMove()),
              onCancel: cubit.cancelMove,
            ),
          if (unit != null && unit.private?.place == UnitPlace.deployed)
            StoreButton(unit: unit),
          if (seeable)
            TextButton(
              onPressed: cubit.enterFirstPerson,
              child: Text(l10n.battleFirstPerson),
            ),
          if (!fromAbove)
            TextButton(
              onPressed: cubit.leaveFirstPerson,
              child: Text(l10n.battleTopDown),
            ),
        ],
      ),
    );
  }
}

class _UnitLabels extends StatelessWidget {
  const new({
    required this.world,
    required this.view,
    required this.all,
    required this.hide,
  });

  final BattleWorld world;
  final ViewProjection view;

  /// Whether every unit is named, or only the selected one.
  final bool all;

  /// The unit whose eyes the view is, which has no name over its head.
  final String? hide;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BattleCubit>().state;
    return Stack(
      children: [
        for (final MapEntry(key: id, value: at) in world.drawn.entries)
          if ((state.units[id], view.project(at + Vector3(0, 7.5, 0)))
              case (final unit?, final onScreen?)
              when id != hide &&
                  (all || id == state.selectedId || id == state.targetId))
            Positioned(
              left: onScreen.dx - 40,
              top: onScreen.dy - 16,
              width: 80,
              child: Text(
                unit.unitType,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: id == state.selectedId || id == state.targetId
                      ? FontWeight.bold
                      : FontWeight.normal,
                  // The target is named in orange, to tell it from the rest.
                  color: id == state.targetId
                      ? Colors.deepOrangeAccent
                      : Colors.white,
                  shadows: const [Shadow(blurRadius: 3)],
                ),
              ),
            ),
      ],
    );
  }
}

/// The map's credits: its data is under licences that ask for an
/// attribution (Q-MAP-22), which a tap on the entry shows.
class _Credits extends StatelessWidget {
  const new({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Panel(
      child: TextButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.battleCredits),
            content: SingleChildScrollView(child: Text(lines.join('\n\n'))),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.battleCreditsClose),
              ),
            ],
          ),
        ),
        child: Text(l10n.battleCredits),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xCC1E2228),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white, fontSize: 13),
        child: child,
      ),
    ),
  );
}
