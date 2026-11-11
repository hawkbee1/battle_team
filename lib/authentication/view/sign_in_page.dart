import 'dart:async';

import 'package:battle_team/authentication/cubit/authentication_form_cubit.dart';
import 'package:battle_team/authentication/model/credential_validators.dart';
import 'package:battle_team/authentication/view/sign_up_page.dart';
import 'package:battle_team/authentication/widgets/authentication_submit.dart';
import 'package:battle_team/backend_status/backend_status.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// {@template sign_in_page}
/// Sign in with an email and a password. It also checks that the backend
/// answers, so that an unreachable server shows before anything is typed.
/// {@endtemplate}
class SignInPage extends StatelessWidget {
  /// {@macro sign_in_page}
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              AuthenticationFormCubit(repository: context.read()),
        ),
        BlocProvider(
          create: (context) {
            final cubit = BackendStatusCubit(
              backendStatusRepository: context.read(),
            );
            unawaited(cubit.checkConnection());
            return cubit;
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.battleTitle)),
        body: const SafeArea(child: SignInView()),
      ),
    );
  }
}

/// The sign-in form.
class SignInView extends StatefulWidget {
  const new({super.key});

  @override
  State<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<SignInView> {
  final _form = GlobalKey<FormState>();

  /// Off until the first submit, so that nothing is called wrong before the
  /// player tried; after it, each field says again as it is edited.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    if (!_form.currentState!.validate()) return;
    unawaited(
      context.read<AuthenticationFormCubit>().signIn(
        email: _email.text.trim(),
        password: _password.text,
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
                    l10n.authenticationSignInTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
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
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) =>
                        switch (CredentialValidators.signInPassword(
                          value ?? '',
                        )) {
                          null => null,
                          _ => l10n.authenticationPasswordEmpty,
                        },
                  ),
                  const SizedBox(height: 24),
                  AuthenticationSubmit(
                    label: l10n.authenticationSignInButton,
                    onSubmit: _submit,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).push(SignUpPage.route()),
                    child: Text(l10n.authenticationGoToSignUp),
                  ),
                  const SizedBox(height: 16),
                  const Center(child: BackendStatusIndicator()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
