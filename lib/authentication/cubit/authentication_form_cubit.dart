import 'package:battle_team/authentication/data/authentication_failure.dart';
import 'package:battle_team/authentication/data/authentication_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';

part 'authentication_form_state.dart';

/// {@template authentication_form_cubit}
/// Submits a sign-in or a sign-up form to the repository, and says how it
/// went. The page validates what was typed first
/// (`CredentialValidators`); the state holds none of it, so no password is in
/// a state, a log line or a state dump.
///
/// When the repository accepts, its status turns authenticated and the gate
/// moves on: the cubit only reports [AuthenticationFormStatus.succeeded].
/// {@endtemplate}
class AuthenticationFormCubit extends Cubit<AuthenticationFormState> {
  /// {@macro authentication_form_cubit}
  new({required this._repository}) : super(const AuthenticationFormState());

  final AuthenticationRepository _repository;

  static final _log = Logger('battle_team.AuthenticationFormCubit');

  /// Signs in as [email] with [password].
  Future<void> signIn({required String email, required String password}) =>
      _submit(
        'sign-in',
        () => _repository.signIn(email: email, password: password),
      );

  /// Creates the account [email] with [password] and [name], and signs in.
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) => _submit(
    'sign-up',
    () => _repository.signUp(email: email, password: password, name: name),
  );

  Future<void> _submit(String what, Future<void> Function() submission) async {
    if (state.status == AuthenticationFormStatus.submitting) return;
    emit(
      const AuthenticationFormState(
        status: AuthenticationFormStatus.submitting,
      ),
    );
    try {
      await submission();
      emit(
        const AuthenticationFormState(
          status: AuthenticationFormStatus.succeeded,
        ),
      );
    } on AuthenticationFailure catch (failure) {
      _log.info('$what refused: ${failure.reason.name}');
      emit(
        AuthenticationFormState(
          status: AuthenticationFormStatus.failed,
          failure: failure.reason,
        ),
      );
    }
  }
}
