import 'dart:async';

import 'package:battle_team/authentication/data/authentication_failure.dart';
import 'package:battle_team/authentication/data/authentication_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'authentication_state.dart';

/// {@template authentication_cubit}
/// Whether an account is signed in, for the whole app: the gate shows the
/// sign-in pages until it is and the battle after, and the log-out buttons ask
/// it to close the session. It follows the repository (Observer).
///
/// It holds no password: the forms keep what is typed, and
/// `AuthenticationFormCubit` hands it to the repository.
/// {@endtemplate}
class AuthenticationCubit extends Cubit<AuthenticationState> {
  /// {@macro authentication_cubit}
  new({required AuthenticationRepository repository})
    : _repository = repository,
      super(
        AuthenticationState(
          status: repository.currentStatus,
          accountId: repository.accountId,
        ),
      ) {
    _changes = repository.status.listen(
      (status) => emit(
        AuthenticationState(status: status, accountId: repository.accountId),
      ),
    );
  }

  final AuthenticationRepository _repository;

  late final StreamSubscription<AuthenticationStatus> _changes;

  /// Looks for the session the last run left, at the start of the app.
  Future<void> start() => _repository.restore();

  /// Logs out; the state then follows the repository to unauthenticated.
  /// [onFailure] is told why when it cannot, and the account stays signed in.
  Future<void> logOut({
    required void Function(AuthenticationFailureReason reason) onFailure,
  }) async {
    try {
      await _repository.signOut();
    } on AuthenticationFailure catch (failure) {
      onFailure(failure.reason);
    }
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    await super.close();
  }
}
