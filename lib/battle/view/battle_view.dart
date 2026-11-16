import 'dart:async';
import 'dart:math' as math;

import 'package:battle_map/battle_map.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/alerts/widgets/alert_banners.dart';
import 'package:battle_team/alerts/widgets/status_strip.dart';
import 'package:battle_team/authentication/widgets/log_out_button.dart';
import 'package:battle_team/battle/cubit/battle_cubit.dart';
import 'package:battle_team/battle/cubit/battle_entry_cubit.dart';
import 'package:battle_team/battle/data/unit_bodies.dart';
import 'package:battle_team/battle/widgets/move_panel.dart';
import 'package:battle_team/battle/widgets/weapon_panel.dart';
import 'package:battle_team/battle/world/battle_camera.dart';
import 'package:battle_team/battle/world/battle_space.dart';
import 'package:battle_team/battle/world/battle_world.dart';
import 'package:battle_team/battle/world/first_person_camera.dart';
import 'package:battle_team/battle/world/top_down_camera.dart';
import 'package:battle_team/fog/cubit/fog_cubit.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:battle_team/settings/cubit/settings_cubit.dart';
import 'package:battle_team/settings/data/key_bindings.dart';
import 'package:battle_team/settings/view/settings_page.dart';
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
/// pinch to zoom, the turn keys (Q/E at first) or two fingers to turn; tap one of your units, then the
/// ground, to move it there, or an enemy to target it. From a unit, drag to
/// look, tap the ground to move there, and fire where the reticle points.
///
/// It draws the shots the cubit announces (Observer): the world shows each
/// for a moment, and nothing of them is kept in the state.
///
/// The cubit's view mode picks the camera (Strategy, `BattleCamera`): the
/// view keeps one of each, so that coming back from a unit finds the overview
/// where it was. The world draws the same units from either.
///
/// On a wide screen the panels float where there is room, with the toolbar
/// along the right. On a phone they stack: the status, the units, the alerts
/// and the relics at the top, one sheet at the bottom, over the toolbar, for
/// the selected unit, the storage or the shop, and the help behind a button.
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
  static const _compactWidth = 600.0;
  static const _toolbarExtent = 56.0;
  static final _log = Logger('battle_team.BattleView');

  late final TopDownCamera _topDown;
  FirstPersonCamera? _firstPerson;
  late final StreamSubscription<Object?> _shots;
  final _frame = ValueNotifier<int>(0);
  final _focus = FocusNode();
  bool _storageOpen = false;
  bool _shopOpen = false;
  final _hidden = <_Overlay>{};
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
    widget.world.showFog(context.read<FogCubit>().state.model);
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

  /// Opens the settings screen; the keys go back to the view after it.
  Future<void> _openSettings() async {
    await SettingsPage.open(context);
    if (mounted) _focus.requestFocus();
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
    final command = context.read<SettingsCubit>().state.keys.commandOf(
      event.logicalKey,
    );
    final done = switch (_firstPerson) {
      final inside? => _keyFirstPerson(inside, command),
      null => _keyTopDown(command),
    };
    return done ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  bool _keyTopDown(BattleCommand? command) {
    const step = 60.0;
    return switch (command) {
      BattleCommand.panLeft => _do(
        () => _topDown.pan(const Offset(step, 0), _size),
      ),
      BattleCommand.panRight => _do(
        () => _topDown.pan(const Offset(-step, 0), _size),
      ),
      BattleCommand.panUp => _do(
        () => _topDown.pan(const Offset(0, step), _size),
      ),
      BattleCommand.panDown => _do(
        () => _topDown.pan(const Offset(0, -step), _size),
      ),
      BattleCommand.turnLeft => _do(() => _topDown.turn(-15 * degrees2Radians)),
      BattleCommand.turnRight => _do(() => _topDown.turn(15 * degrees2Radians)),
      BattleCommand.zoomIn => _do(() => _topDown.zoom(1.25)),
      BattleCommand.zoomOut => _do(() => _topDown.zoom(0.8)),
      BattleCommand.back => _do(_escape),
      null => false,
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

  /// From a unit's eyes: the pan keys look around a little, the turn keys
  /// turn, back goes back above and keeps the unit selected.
  bool _keyFirstPerson(FirstPersonCamera inside, BattleCommand? command) {
    const step = 30.0;
    return switch (command) {
      BattleCommand.panLeft => _do(() => inside.look(const Offset(-step, 0))),
      BattleCommand.panRight => _do(() => inside.look(const Offset(step, 0))),
      BattleCommand.panUp => _do(() => inside.look(const Offset(0, -step))),
      BattleCommand.panDown => _do(() => inside.look(const Offset(0, step))),
      BattleCommand.turnLeft => _do(() => inside.turn(-15 * degrees2Radians)),
      BattleCommand.turnRight => _do(() => inside.turn(15 * degrees2Radians)),
      BattleCommand.back => _do(context.read<BattleCubit>().leaveFirstPerson),
      BattleCommand.zoomIn || BattleCommand.zoomOut || null => false,
    };
  }

  bool _do(void Function() action) {
    action();
    _frame.value++;
    return true;
  }

  bool _shows(_Overlay overlay) => !_hidden.contains(overlay);

  Widget _panel(Widget child) => _Panel(child: child);

  /// The storage or the shop, no taller than [maxHeight], scrolling inside.
  Widget _sheet(Widget child, {required double maxHeight}) => ConstrainedBox(
    constraints: BoxConstraints(maxHeight: math.max(80, maxHeight)),
    child: _Panel(child: SingleChildScrollView(child: child)),
  );

  Widget _storage(double maxHeight) => _sheet(
    StoragePanel(onClose: () => setState(() => _storageOpen = false)),
    maxHeight: maxHeight,
  );

  Widget _shop(double maxHeight) =>
      BlocSelector<BattleCubit, BattleState, UnitView?>(
        selector: (state) => state.selected,
        builder: (context, selected) => _sheet(
          ShopPanel(
            selected: selected,
            onClose: () => setState(() => _shopOpen = false),
          ),
          maxHeight: maxHeight,
        ),
      );

  Widget _unitsPanel({required bool compact}) => _UnitsPanel(
    compact: compact,
    onCentre: _centreNow,
    onStorage: () => setState(() {
      _storageOpen = !_storageOpen;
      _shopOpen = false;
    }),
    onShop: () => setState(() {
      _shopOpen = !_shopOpen;
      _storageOpen = false;
    }),
  );

  Widget _selectedUnit({required bool compact}) => ValueListenableBuilder(
    valueListenable: _frame,
    builder: (context, _, _) => _SelectedUnit(
      compact: compact,
      aim: switch (_firstPerson) {
        final inside? => () => directionOf(inside.forward),
        null => null,
      },
    ),
  );

  /// A desktop's or a browser's overlays: each floats where there is room.
  Widget _wideOverlays(BuildContext context, String help) {
    // The storage and the shop stop short of the selected unit panel.
    final height = MediaQuery.sizeOf(context).height;
    return Stack(
      children: [
        if (_shows(_Overlay.status))
          Positioned(
            left: 12,
            top: 12,
            right: 12,
            child: _Header(help: help, compact: false),
          ),
        if (_shows(_Overlay.units))
          Positioned(right: 12, top: 96, child: _unitsPanel(compact: false)),
        if (_storageOpen && _shows(_Overlay.units))
          Positioned(
            left: 12,
            top: 96,
            width: 300,
            child: BlocSelector<BattleCubit, BattleState, bool>(
              selector: (state) => state.selectedId != null,
              builder: (context, selected) =>
                  _storage(height - 96 - (selected ? 200 : 12)),
            ),
          ),
        if (_shopOpen && _shows(_Overlay.units))
          Positioned(
            left: 12,
            top: 96,
            width: 300,
            child: BlocSelector<BattleCubit, BattleState, bool>(
              selector: (state) => state.selectedId != null,
              builder: (context, selected) =>
                  _shop(height - 96 - (selected ? 200 : 12)),
            ),
          ),
        if (_shows(_Overlay.alerts))
          Positioned(
            top: 96,
            left: 0,
            right: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AlertBanners(builder: _panel),
              ),
            ),
          ),
        if (_shows(_Overlay.alerts))
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: IgnorePointer(child: StatusStrip(builder: _panel)),
              ),
            ),
          ),
        if (_shows(_Overlay.unit))
          Positioned(
            left: 12,
            bottom: 12,
            child: _selectedUnit(compact: false),
          ),
      ],
    );
  }

  /// A phone's overlays: the status, the units, the alerts and the relics
  /// stack at the top, and one sheet at the bottom holds the storage, else
  /// the shop, else the selected unit, each the full width and no taller
  /// than half the screen.
  Widget _compactOverlays(BuildContext context, String help) {
    final maxSheet = MediaQuery.sizeOf(context).height * 0.45;
    final sheet = _storageOpen && _shows(_Overlay.units)
        ? _storage(maxSheet)
        : _shopOpen && _shows(_Overlay.units)
        ? _shop(maxSheet)
        : _shows(_Overlay.unit)
        ? ConstrainedBox(
            constraints: BoxConstraints(maxHeight: math.max(80, maxSheet)),
            child: _selectedUnit(compact: true),
          )
        : null;
    return Stack(
      children: [
        Positioned(
          left: 12,
          top: 12,
          right: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_shows(_Overlay.status)) _Header(help: help, compact: true),
              if (_shows(_Overlay.units))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _unitsPanel(compact: true),
                ),
              if (_shows(_Overlay.alerts)) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: AlertBanners(builder: _panel),
                ),
                IgnorePointer(child: StatusStrip(builder: _panel)),
              ],
            ],
          ),
        ),
        if (sheet != null)
          Positioned(left: 12, right: 12, bottom: 12, child: sheet),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // A phone's toolbar runs along the bottom, a desktop's or a browser's
    // along the right.
    final media = MediaQuery.of(context);
    final compact = media.size.width < _compactWidth;
    final keys = context.select<SettingsCubit, KeyBindings>(
      (settings) => settings.state.keys,
    );
    String keyName(BattleCommand command) => keyLabel(keys.keyOf(command));
    final help = _firstPerson == null
        ? context.l10n.battleHelp(
            keyName(BattleCommand.turnLeft),
            keyName(BattleCommand.turnRight),
          )
        : context.l10n.battleHelpFirstPerson(
            keyName(BattleCommand.turnLeft),
            keyName(BattleCommand.turnRight),
            keyName(BattleCommand.back),
          );
    return MultiBlocListener(
      listeners: [
        BlocListener<BattleCubit, BattleState>(
          listener: (context, state) {
            _show(state, centreOnUnits: true);
            _syncCamera(state);
          },
        ),
        // The ground is shaded when what the section sees changes, not every
        // frame (M7 Issue 9).
        BlocListener<FogCubit, FogState>(
          listener: (context, state) => widget.world.showFog(state.model),
        ),
      ],
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
            if (_firstPerson != null) const AimReticle(),
            // The overlays live in what the toolbar and the screen's edges
            // (the clock, the gesture bar) leave free, so that none can cover
            // one of its buttons or sit under the status bar.
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: compact ? _toolbarExtent + media.padding.bottom : 0,
                  right: compact ? 0 : _toolbarExtent,
                ),
                child: SafeArea(
                  bottom: false,
                  child: compact
                      ? _compactOverlays(context, help)
                      : _wideOverlays(context, help),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              left: compact ? 0 : null,
              top: compact ? null : 0,
              child: _Toolbar(
                compact: compact,
                hidden: _hidden,
                onToggleOverlay: (overlay) => setState(
                  () => _hidden.contains(overlay)
                      ? _hidden.remove(overlay)
                      : _hidden.add(overlay),
                ),
                credits: widget.map.spec.attribution,
                onSettings: _openSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the player stands and the help: beside each other on a wide screen;
/// on a phone the help is behind a button, in a dialog, since a paragraph
/// squeezed next to the status reads one word a line.
class _Header extends StatelessWidget {
  const new({required this.help, required this.compact});

  final String help;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<BattleCubit>().state;
    final team = state.team;
    final section = state.sectionId;
    final status = Text(
      [
        l10n.battleStatus(state.status.name),
        if (team != null && section != null)
          l10n.battlePlayingAs(team, section),
        ?state.problem,
      ].join('\n'),
    );
    if (compact) {
      return _Panel(
        child: Row(
          children: [
            Expanded(child: status),
            IconButton(
              tooltip: l10n.battleHelpShow,
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.battleHelpShow),
                  content: Text(help),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.battleHelpClose),
                    ),
                  ],
                ),
              ),
              icon: const Icon(Icons.help_outline, color: Colors.white),
            ),
          ],
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Panel(child: status),
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

/// The buttons of a phone's panels: tighter, so that a row of them fits.
final ButtonStyle _denseButton = TextButton.styleFrom(
  visualDensity: VisualDensity.compact,
  padding: const EdgeInsets.symmetric(horizontal: 8),
);

/// The section's units, deployed or stored: a tap selects one, Storage opens
/// the storage view (M7 Issue 6), Shop the shop (M7 Issue 7), Centre looks at
/// the section again. A list on a wide screen; on a phone the units wrap
/// across the width, so that the panel stays short.
class _UnitsPanel extends StatelessWidget {
  const new({
    required this.compact,
    required this.onCentre,
    required this.onStorage,
    required this.onShop,
  });

  final bool compact;
  final VoidCallback onCentre;
  final VoidCallback onStorage;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.watch<BattleCubit>();
    final units = cubit.state.sectionUnits;
    final style = compact ? _denseButton : null;
    final actions = [
      Text(l10n.battleUnits),
      TextButton(
        onPressed: onCentre,
        style: style,
        child: Text(l10n.battleCentre),
      ),
      TextButton(
        onPressed: onStorage,
        style: style,
        child: BlocSelector<StorageCubit, StorageState, int>(
          selector: (state) => state.stored.length,
          builder: (context, stored) => Text(l10n.storageOpen('$stored')),
        ),
      ),
      TextButton(onPressed: onShop, style: style, child: Text(l10n.shopOpen)),
    ];
    final rows = [for (final unit in units) _UnitRow(unit: unit, style: style)];
    return _Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            )
          else
            Row(mainAxisSize: MainAxisSize.min, children: actions),
          if (compact) Wrap(children: rows) else ...rows,
        ],
      ),
    );
  }
}

class _UnitRow extends StatelessWidget {
  const new({required this.unit, required this.style});

  final UnitView unit;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<BattleCubit>();
    final stored = unit.private?.place == UnitPlace.stored;
    return TextButton(
      onPressed: () => cubit.select(unit.unitId),
      style: style,
      child: Text(
        '${unit.unitType} · '
        '${stored ? l10n.battleStored : l10n.battleInField}',
      ),
    );
  }
}

/// The selected unit, its weapon and the answer to the last order, with the
/// button that sees the battle through the unit's eyes, or goes back above,
/// on the unit's own line, where it is found first. On a phone the panel
/// scrolls inside the height it is given.
class _SelectedUnit extends StatelessWidget {
  const new({required this.aim, required this.compact});

  /// The direction the eyes look along, from first person.
  final Direction Function()? aim;

  final bool compact;

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
    final style = compact ? _denseButton : null;
    final text = Text(lines.join('\n'));
    final views = [
      if (seeable)
        TextButton(
          onPressed: cubit.enterFirstPerson,
          style: style,
          child: Text(l10n.battleFirstPerson),
        ),
      if (!fromAbove)
        TextButton(
          onPressed: cubit.leaveFirstPerson,
          style: style,
          child: Text(l10n.battleTopDown),
        ),
    ];
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // On a phone the view button is on the unit's line, found first and
        // never below the fold of the sheet.
        if (compact)
          Row(
            children: [
              Expanded(child: text),
              ...views,
            ],
          )
        else
          text,
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
        if (!compact) ...views,
      ],
    );
    return _Panel(
      child: compact ? SingleChildScrollView(child: content) : content,
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

/// The overlays the toolbar masks, one button each.
enum _Overlay {
  status(Icons.info),
  units(Icons.groups),
  unit(Icons.person),
  alerts(Icons.notifications);

  new(this.icon);

  final IconData icon;

  String label(AppLocalizations l10n) => switch (this) {
    status => l10n.battleOverlayStatus,
    units => l10n.battleOverlayUnits,
    unit => l10n.battleOverlayUnit,
    alerts => l10n.battleOverlayAlerts,
  };
}

/// The toolbar: masks or shows each overlay, the map's credits (its data is
/// under licences that ask for an attribution, Q-MAP-22), the switch to
/// another battle and the log-out (M7 Issue 12). Along the bottom of a phone,
/// along the right of a desktop or a browser.
class _Toolbar extends StatelessWidget {
  const new({
    required this.compact,
    required this.hidden,
    required this.onToggleOverlay,
    required this.credits,
    required this.onSettings,
  });

  final bool compact;

  /// The overlays masked now.
  final Set<_Overlay> hidden;
  final void Function(_Overlay overlay) onToggleOverlay;
  final List<String> credits;

  /// Opens the settings screen.
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final buttons = [
      for (final overlay in _Overlay.values)
        IconButton(
          tooltip: hidden.contains(overlay)
              ? l10n.battleOverlayShow(overlay.label(l10n))
              : l10n.battleOverlayHide(overlay.label(l10n)),
          onPressed: () => onToggleOverlay(overlay),
          isSelected: !hidden.contains(overlay),
          icon: Icon(overlay.icon),
          selectedIcon: Icon(overlay.icon),
          style: IconButton.styleFrom(
            foregroundColor: hidden.contains(overlay)
                ? Colors.white38
                : Colors.white,
          ),
        ),
      IconButton(
        tooltip: l10n.battleCredits,
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.battleCredits),
            content: SingleChildScrollView(child: Text(credits.join('\n\n'))),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.battleCreditsClose),
              ),
            ],
          ),
        ),
        icon: const Icon(Icons.info_outline),
      ),
      IconButton(
        tooltip: l10n.settingsOpen,
        onPressed: onSettings,
        icon: const Icon(Icons.settings),
      ),
      IconButton(
        tooltip: l10n.battleEntrySwitch,
        onPressed: () => unawaited(context.read<BattleEntryCubit>().choose()),
        icon: const Icon(Icons.swap_horiz),
      ),
      const LogOutButton(icon: true),
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xCC1E2228)),
      child: SafeArea(
        child: IconTheme.merge(
          data: const IconThemeData(color: Colors.white),
          child: SingleChildScrollView(
            scrollDirection: compact ? Axis.horizontal : Axis.vertical,
            child: compact
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: buttons,
                  )
                : Column(mainAxisSize: MainAxisSize.min, children: buttons),
          ),
        ),
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
