import 'dart:async';

import 'package:appwrite_api_client/appwrite_api_client.dart';
import 'package:battle_team/authentication/data/authentication_failure.dart';
import 'package:logging/logging.dart';

/// Whether the app knows an account is signed in.
enum AuthenticationStatus {
  /// Not found out yet: the session is being looked for.
  unknown,

  /// No account is signed in.
  unauthenticated,

  /// An account is signed in.
  authenticated,
}

/// {@template authentication_repository}
/// The account of the player: it signs up, signs in and logs out through
/// `appwrite_api_client`, and tells the app whether an account is signed in
/// ([status], [currentStatus]). The cubits above it never see the client
/// (Adapter over `appwrite_api_client`).
///
/// The session is the SDK's: it keeps its cookie, so [restore] finds an
/// account signed in again after a restart. The repository never holds a
/// password; it passes the one it is given to Appwrite and forgets it.
///
/// A failure comes out as an [AuthenticationFailure] with a reason the
/// screens can say in words. It logs on `battle_team.AuthenticationRepository`
/// the steps and the reasons of failures, never an email, a password or a
/// name.
/// {@endtemplate}
class AuthenticationRepository {
  /// {@macro authentication_repository}
  ///
  /// [signInAtStart] is for the playtest flavor: the account of its env file
  /// (build-time constants), which [restore] signs in instead of looking for a
  /// session. The normal flavors give none.
  new({required this._apiClient, this.signInAtStart});

  static final _log = Logger('battle_team.AuthenticationRepository');

  final AppwriteApiClient _apiClient;

  /// The account the playtest flavor signs in at start, if any.
  final ({String email, String password})? signInAtStart;

  final _changes = StreamController<AuthenticationStatus>.broadcast();
  AuthenticationStatus _status = AuthenticationStatus.unknown;
  String? _accountId;

  /// Whether an account is signed in now.
  AuthenticationStatus get currentStatus => _status;

  /// The ID of the signed-in account, null when none is.
  String? get accountId => _accountId;

  /// Each change of the status, from the next one on.
  Stream<AuthenticationStatus> get status => _changes.stream;

  /// Finds out whether an account is signed in, at the start of the app: the
  /// session the SDK kept, or [signInAtStart]'s account. Never fails: when
  /// Appwrite cannot say, nobody is signed in and the sign-in page shows.
  Future<void> restore() async {
    _log.info('looking for a session');
    try {
      final account = signInAtStart;
      if (account != null) {
        await _apiClient.signIn(
          email: account.email,
          password: account.password,
        );
      }
      await _enter();
    } on Object catch (error) {
      final reason = _failureOf(error, signingIn: true).reason;
      _log.warning('no session: ${reason.name}');
      _set(AuthenticationStatus.unauthenticated, null);
    }
  }

  /// Signs in as [email] with [password].
  ///
  /// Throws an [AuthenticationFailure] when it cannot.
  Future<void> signIn({required String email, required String password}) =>
      _attempt('sign-in', signingIn: true, () async {
        await _apiClient.signIn(email: email, password: password);
        await _enter();
      });

  /// Creates the account [email] with [password] and [name], and signs in.
  ///
  /// Throws an [AuthenticationFailure] when it cannot.
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) => _attempt('sign-up', () async {
    await _apiClient.signUp(email: email, password: password, name: name);
    await _enter();
  });

  /// Closes the session.
  ///
  /// Throws an [AuthenticationFailure] when it cannot; the account stays
  /// signed in.
  Future<void> signOut() => _attempt('sign-out', () async {
    await _apiClient.signOut();
    _set(AuthenticationStatus.unauthenticated, null);
  });

  /// Reads the account the session belongs to.
  Future<void> _enter() async {
    final account = await _apiClient.currentAccount();
    if (account == null) {
      _set(AuthenticationStatus.unauthenticated, null);
    } else {
      _set(AuthenticationStatus.authenticated, account.id);
    }
  }

  Future<void> _attempt(
    String what,
    Future<void> Function() work, {
    bool signingIn = false,
  }) async {
    _log.info('$what: started');
    try {
      await work();
      _log.info('$what: done');
    } on Object catch (error, stackTrace) {
      // The reason only: the client has logged the error itself.
      final failure = _failureOf(error, signingIn: signingIn);
      _log.warning('$what: failed, ${failure.reason.name}');
      Error.throwWithStackTrace(failure, stackTrace);
    }
  }

  static AuthenticationFailure _failureOf(
    Object error, {
    required bool signingIn,
  }) {
    final kind = switch (error) {
      AppwriteSignInFailure(:final kind) ||
      AppwriteAccountFailure(:final kind) => kind,
      _ => AppwriteFailureKind.other,
    };
    return AuthenticationFailure(switch (kind) {
      AppwriteFailureKind.unauthorized when signingIn =>
        AuthenticationFailureReason.wrongCredentials,
      AppwriteFailureKind.conflict => AuthenticationFailureReason.accountExists,
      AppwriteFailureKind.invalidInput =>
        AuthenticationFailureReason.invalidInput,
      AppwriteFailureKind.tooManyRequests =>
        AuthenticationFailureReason.tooManyRequests,
      AppwriteFailureKind.unreachable =>
        AuthenticationFailureReason.unreachable,
      _ => AuthenticationFailureReason.other,
    });
  }

  void _set(AuthenticationStatus status, String? accountId) {
    _accountId = accountId;
    if (status == _status) return;
    _status = status;
    _changes.add(status);
  }

  /// Stops telling the status.
  Future<void> close() => _changes.close();
}
