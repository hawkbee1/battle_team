import 'dart:async';

import 'package:battle_team/authentication/cubit/authentication_form_cubit.dart';
import 'package:battle_team/authentication/model/credential_validators.dart';
import 'package:battle_team/authentication/widgets/authentication_submit.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// {@template sign_up_page}
/// Create an account: a name, an email, a password typed twice. The account
/// is signed in as soon as it exists.
/// {@endtemplate}
class SignUpPage extends StatelessWidget {
  /// {@macro sign_up_page}
  const new({super.key});

  /// The route to the page, from the sign-in page.
  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const SignUpPage());

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthenticationFormCubit(repository: context.read()),
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.battleTitle)),
        body: const SafeArea(child: SignUpView()),
      ),
    );
  }
}

/// The sign-up form.
class SignUpView extends StatefulWidget {
  const new({super.key});

  @override
  State<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<SignUpView> {
  final _form = GlobalKey<FormState>();

  /// Off until the first submit, so that nothing is called wrong before the
  /// player tried; after it, each field says again as it is edited.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    if (!_form.currentState!.validate()) return;
    unawaited(
      context.read<AuthenticationFormCubit>().signUp(
        email: _email.text.trim(),
        password: _password.text,
        name: _name.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Form(
            key: _form,
            autovalidateMode: _autovalidate,
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.authenticationSignUpTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _name,
                    decoration: InputDecoration(
                      labelText: l10n.authenticationName,
                    ),
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    validator: (value) =>
                        switch (CredentialValidators.name(value ?? '')) {
                          null => null,
                          NameProblem.empty => l10n.authenticationNameEmpty,
                          NameProblem.tooLong => l10n.authenticationNameTooLong(
                            CredentialValidators.maxNameLength,
                          ),
                        },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    decoration: InputDecoration(
                      labelText: l10n.authenticationEmail,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    validator: (value) => switch (CredentialValidators.email(
                      value ?? '',
                    )) {
                      null => null,
                      EmailProblem.empty => l10n.authenticationEmailEmpty,
                      EmailProblem.invalid => l10n.authenticationEmailInvalid,
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    decoration: InputDecoration(
                      labelText: l10n.authenticationPassword,
                    ),
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (value) =>
                        switch (CredentialValidators.newPassword(value ?? '')) {
                          null => null,
                          PasswordProblem.empty =>
                            l10n.authenticationPasswordEmpty,
                          PasswordProblem.tooShort =>
                            l10n.authenticationPasswordTooShort(
                              CredentialValidators.minPasswordLength,
                            ),
                        },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmation,
                    decoration: InputDecoration(
                      labelText: l10n.authenticationConfirmPassword,
                    ),
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) =>
                        CredentialValidators.confirms(
                          _password.text,
                          value ?? '',
                        )
                        ? null
                        : l10n.authenticationConfirmationMismatch,
                  ),
                  const SizedBox(height: 24),
                  AuthenticationSubmit(
                    label: l10n.authenticationSignUpButton,
                    onSubmit: _submit,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.authenticationGoToSignIn),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
