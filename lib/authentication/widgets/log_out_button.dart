import 'dart:async';

import 'package:battle_team/authentication/cubit/authentication_cubit.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// The button that logs the player out. The gate then shows the sign-in page
/// by itself; when the session cannot be closed the account stays signed in
/// and a message says why. Needs an [AuthenticationCubit] above it when it is
/// pressed.
class LogOutButton extends StatelessWidget {
  const new({super.key, this.icon = false});

  /// Whether it is an icon with a tooltip, for a toolbar, rather than text.
  final bool icon;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    void logOut() {
      final messenger = ScaffoldMessenger.of(context);
      unawaited(
        context.read<AuthenticationCubit>().logOut(
          onFailure: (reason) => messenger.showSnackBar(
            SnackBar(
              content: Text(
                l10n.authenticationLogOutFailed(
                  l10n.authenticationFailure(reason.name),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return icon
        ? IconButton(
            tooltip: l10n.authenticationLogOut,
            onPressed: logOut,
            icon: const Icon(Icons.logout),
          )
        : TextButton(onPressed: logOut, child: Text(l10n.authenticationLogOut));
  }
}
