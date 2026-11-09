import 'dart:async';
import 'dart:math' as math;

import 'package:battle_map/battle_map.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:battle_team/playtest/cubit/playtest_cubit.dart';
import 'package:battle_team/playtest/world/battle_space.dart';
import 'package:battle_team/playtest/world/playtest_world.dart';
import 'package:battle_team/playtest/world/top_down_camera.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector_math/vector_math.dart' show Vector3, degrees2Radians;

/// Builds the 3D area of [world] seen from [camera]; [onTick] is called on
/// each frame with the seconds since the last one.
typedef PlaytestSceneBuilder = Widget Function(
  BuildContext context,
  PlaytestWorld world,
  TopDownCamera camera,
  void Function(double seconds) onTick,
);

/// {@template playtest_view}
/// The battle seen from above: the map of [map] in [world], the units the
/// section sees, and the orders of the player. Drag to pan, scroll or pinch
/// to zoom, Q/E or two fingers to turn; tap one of your units, then the
/// ground, to move it there.
/// {@endtemplate}
class PlaytestView extends StatefulWidget {
  /// {@macro playtest_view}
  const new({
    required this.map,
    required this.world,
    required this.sceneBuilder,
    super.key,
  });

  /// The battle's map.
  final MapData map;

  /// The 3D world.
  final PlaytestWorld world;

  /// Builds the 3D area.
  final PlaytestSceneBuilder sceneBuilder;

  @override
  State<PlaytestView> createState() => _PlaytestViewState();
}

class _PlaytestViewState extends State<PlaytestView> {
  late final TopDownCamera _camera;
  final _frame = ValueNotifier<int>(0);
  final _focus = FocusNode();
  double _lastScale = 1;
  double _lastRotation = 0;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    final surface = widget.world.surface;
    final centre = Vector3(surface.widthM / 2, 0, -surface.depthM / 2);
    centre.y = surface.heightAt(centre.x, -centre.z);
    _camera = TopDownCamera(target: centre, distance: 700);
    _show(context.read<PlaytestCubit>().state, centreOnUnits: true);
  }

  @override
  void dispose() {
    _frame.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _show(PlaytestState state, {bool centreOnUnits = false}) {
    widget.world.show(
      units: state.units.values,
      hqs: state.hqs,
      relics: state.relics,
      selected: state.selectedId,
      battleTime: context.read<PlaytestCubit>().battleTime,
    );
    if (centreOnUnits) _centreOnSection(state);
  }

  /// Looks at the section's units the first time it sees them, or at its
  /// HQ while none is out; `force` looks again (the Centre button).
  bool _centred = false;
  void _centreOnSection(PlaytestState state, {bool force = false}) {
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
    _camera
      ..target = sum
      ..distance = 120;
    _frame.value++;
  }

  void _centreNow() =>
      _centreOnSection(context.read<PlaytestCubit>().state, force: true);

  void _tick(double seconds) {
    widget.world.tick(seconds);
    _frame.value++;
  }

  void _tap(Offset at) {
    final cubit = context.read<PlaytestCubit>();
    final state = cubit.state;
    final view = _camera.view(_size);
    String? nearest;
    var best = 28.0;
    for (final MapEntry(key: id, value: drawn) in widget.world.drawn.entries) {
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
    final ground = widget.world.surface.hit(
      view.position,
      view.directionAt(at),
    );
    if (ground != null && state.selected != null) {
      unawaited(cubit.moveSelectedTo(positionOf(ground)));
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    const step = 60.0;
    final key = event.logicalKey;
    final done = switch (key) {
      LogicalKeyboardKey.arrowLeft => _do(
        () => _camera.pan(const Offset(step, 0), _size),
      ),
      LogicalKeyboardKey.arrowRight => _do(
        () => _camera.pan(const Offset(-step, 0), _size),
      ),
      LogicalKeyboardKey.arrowUp => _do(
        () => _camera.pan(const Offset(0, step), _size),
      ),
      LogicalKeyboardKey.arrowDown => _do(
        () => _camera.pan(const Offset(0, -step), _size),
      ),
      LogicalKeyboardKey.keyQ => _do(() => _camera.turn(-15 * degrees2Radians)),
      LogicalKeyboardKey.keyE => _do(() => _camera.turn(15 * degrees2Radians)),
      LogicalKeyboardKey.equal ||
      LogicalKeyboardKey.add ||
      LogicalKeyboardKey.numpadAdd => _do(() => _camera.zoom(1.25)),
      LogicalKeyboardKey.minus ||
      LogicalKeyboardKey.numpadSubtract => _do(() => _camera.zoom(0.8)),
      LogicalKeyboardKey.escape => _do(
        () => context.read<PlaytestCubit>().select(null),
      ),
      _ => false,
    };
    return done ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  bool _do(void Function() action) {
    action();
    _frame.value++;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PlaytestCubit, PlaytestState>(
      listener: (context, state) => _show(state, centreOnUnits: true),
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
                      if (signal is PointerScrollEvent) {
                        _do(
                          () => _camera.zoom(
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
                        _camera
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
                    all: _camera.distance < 200,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              right: 12,
              child: _Header(help: context.l10n.playtestHelp),
            ),
            Positioned(
              right: 12,
              top: 96,
              child: _UnitsPanel(onCentre: _centreNow),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: ValueListenableBuilder(
                valueListenable: _frame,
                builder: (context, _, _) => const _SelectedUnit(),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: _Attribution(lines: widget.map.spec.attribution),
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
    final state = context.watch<PlaytestCubit>().state;
    final team = state.team;
    final section = state.sectionId;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Panel(
          child: Text(
            [
              l10n.playtestStatus(state.status.name),
              if (team != null && section != null)
                l10n.playtestPlayingAs(team, section),
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

/// The section's units, deployed or stored: a tap selects one, Deploy
/// brings a stored one out to the HQ, Centre looks at the section again.
class _UnitsPanel extends StatelessWidget {
  const new({required this.onCentre});

  final VoidCallback onCentre;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.watch<PlaytestCubit>();
    final units = cubit.state.sectionUnits;
    return _Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.playtestUnits),
              TextButton(onPressed: onCentre, child: Text(l10n.playtestCentre)),
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
    final cubit = context.read<PlaytestCubit>();
    final stored = unit.private?.place == UnitPlace.stored;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () => cubit.select(unit.unitId),
          child: Text(
            '${unit.unitType} · '
            '${stored ? l10n.playtestStored : l10n.playtestInField}',
          ),
        ),
        if (stored)
          TextButton(
            onPressed: () => cubit.deploy(unit.unitId),
            child: Text(l10n.playtestDeploy),
          ),
      ],
    );
  }
}

class _SelectedUnit extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.watch<PlaytestCubit>();
    final state = cubit.state;
    final unit = state.selected;
    final notice = state.notice;
    final lines = [
      if (unit != null)
        l10n.playtestUnit(
          unit.unitType,
          unit.hp.toStringAsFixed(0),
          cubit.apNow(unit)?.toStringAsFixed(1) ?? '–',
        ),
      if (notice != null)
        switch (notice.refusal) {
          null => l10n.playtestOrderAccepted(notice.order),
          final reason => l10n.playtestOrderRefused(notice.order, reason),
        },
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    return _Panel(child: Text(lines.join('\n')));
  }
}

class _UnitLabels extends StatelessWidget {
  const new({required this.world, required this.view, required this.all});

  final PlaytestWorld world;
  final ViewProjection view;

  /// Whether every unit is named, or only the selected one.
  final bool all;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlaytestCubit>().state;
    return Stack(
      children: [
        for (final MapEntry(key: id, value: at) in world.drawn.entries)
          if ((state.units[id], view.project(at + Vector3(0, 7.5, 0)))
              case (final unit?, final onScreen?)
              when all || id == state.selectedId)
            Positioned(
              left: onScreen.dx - 40,
              top: onScreen.dy - 16,
              width: 80,
              child: Text(
                unit.unitType,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: id == state.selectedId
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: Colors.white,
                  shadows: const [Shadow(blurRadius: 3)],
                ),
              ),
            ),
      ],
    );
  }
}

class _Attribution extends StatelessWidget {
  const new({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 420),
    child: _Panel(
      child: Text(lines.join('\n'), style: const TextStyle(fontSize: 9)),
    ),
  );
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
