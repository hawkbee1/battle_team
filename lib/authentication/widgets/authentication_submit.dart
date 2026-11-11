import 'package:battle_team/authentication/cubit/authentication_form_cubit.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// The end of a sign-in or a sign-up form: why the last attempt failed, in
/// words, and the button that submits [label]. While the form is being sent
/// the button waits. Needs an [AuthenticationFormCubit] above it.
class AuthenticationSubmit extends StatelessWidget {
  const new({required this.label, required this.onSubmit, super.key});

  /// The button's text.
  final String label;

  /// Called when the button is pressed and the form is not being sent.
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<AuthenticationFormCubit>().state;
    final failure = state.failure;
    final sending = state.status == AuthenticationFormStatus.submitting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l10n.authenticationFailure(failure.name),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        FilledButton(
          onPressed: sending ? null : onSubmit,
          child: sending
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(label),
        ),
      ],
    );
  }
}
