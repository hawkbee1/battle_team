import 'package:battle_team/backend_status/backend_status.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// One-line status of the Appwrite connection, with a retry button when it
/// failed. Needs a [BackendStatusCubit] above it.
class BackendStatusIndicator extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<BackendStatusCubit>().state;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            switch (state.status) {
              BackendStatus.initial ||
              BackendStatus.checking => const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              BackendStatus.reachable => Icon(
                Icons.cloud_done,
                size: 16,
                color: colorScheme.primary,
              ),
              BackendStatus.unreachable => Icon(
                Icons.cloud_off,
                size: 16,
                color: colorScheme.error,
              ),
            },
            const SizedBox(width: 8),
            Flexible(
              child: Text(switch (state.status) {
                BackendStatus.initial ||
                BackendStatus.checking => l10n.backendStatusChecking,
                BackendStatus.reachable => l10n.backendStatusReachable,
                BackendStatus.unreachable => l10n.backendStatusUnreachable,
              }),
            ),
            if (state.status == BackendStatus.unreachable)
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: l10n.backendStatusRetryButton,
                onPressed: context.read<BackendStatusCubit>().checkConnection,
              ),
          ],
        ),
        if (state.errorMessage.isNotEmpty)
          SelectableText(
            state.errorMessage,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}
