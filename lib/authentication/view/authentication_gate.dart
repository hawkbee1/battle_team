import 'package:battle_team/authentication/cubit/authentication_cubit.dart';
import 'package:battle_team/authentication/data/authentication_repository.dart';
import 'package:battle_team/authentication/view/sign_in_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// Builds what an account sees once it is signed in.
typedef SignedInBuilder = Widget Function(
  BuildContext context,
  String accountId,
);

/// {@template authentication_gate}
/// Shows the sign-in page until an account is signed in, and what
/// [signedIn] builds after: the first screen is decided by the session the
/// last run left, not by a tap. A log-out brings the sign-in page back and
/// drops what [signedIn] built with it. Needs an [AuthenticationCubit] above
/// it.
/// {@endtemplate}
class AuthenticationGate extends StatelessWidget {
  /// {@macro authentication_gate}
  const new({required this.signedIn, super.key});

  /// Builds the screen of a signed-in account.
  final SignedInBuilder signedIn;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthenticationCubit, AuthenticationState>(
      // The sign-up page sits on the sign-in page: once the account is in,
      // both leave.
      listenWhen: (previous, current) =>
          current.status == AuthenticationStatus.authenticated &&
          previous.status != AuthenticationStatus.authenticated,
      listener: (context, _) =>
          Navigator.of(context).popUntil((route) => route.isFirst),
      builder: (context, state) => switch (state) {
        AuthenticationState(status: AuthenticationStatus.unknown) =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
        AuthenticationState(
          status: AuthenticationStatus.authenticated,
          :final accountId?,
        ) =>
          signedIn(context, accountId),
        _ => const SignInPage(),
      },
    );
  }
}
