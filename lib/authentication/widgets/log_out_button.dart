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
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextButton(
      onPressed: () {
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
      },
      child: Text(l10n.authenticationLogOut),
    );
  }
}
