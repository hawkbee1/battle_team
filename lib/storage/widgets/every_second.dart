import 'dart:async';

import 'package:flutter/widgets.dart';

/// Builds [builder] again every second, so that a remaining time counts
/// down between the host's messages. The time itself is the battle time of
/// the client, not the device's clock.
class EverySecond extends StatefulWidget {
  /// Builds [builder] every second.
  const new({required this.builder, super.key});

  /// Builds the child.
  final WidgetBuilder builder;

  @override
  State<EverySecond> createState() => _EverySecondState();
}

class _EverySecondState extends State<EverySecond> {
  late final Timer _timer = Timer.periodic(
    const Duration(seconds: 1),
    (_) => setState(() {}),
  );

  @override
  void initState() {
    super.initState();
    // Reads the lazy timer, which starts it.
    _timer.isActive;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
