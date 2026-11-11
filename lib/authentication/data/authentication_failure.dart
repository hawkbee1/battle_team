/// Why an account call failed, in the words of the app. The screens turn each
/// into a localized message; none carries technical text.
enum AuthenticationFailureReason {
  /// The email or the password does not match an account.
  wrongCredentials,

  /// The email already has an account.
  accountExists,

  /// Appwrite refused the email or the password (too short, not an email).
  invalidInput,

  /// Too many attempts; try again in a moment.
  tooManyRequests,

  /// The server did not answer.
  unreachable,

  /// Anything else.
  other,
}

/// {@template authentication_failure}
/// Thrown by the `AuthenticationRepository` when an account call fails.
/// {@endtemplate}
class AuthenticationFailure implements Exception {
  /// {@macro authentication_failure}
  const new(this.reason);

  /// Why it failed.
  final AuthenticationFailureReason reason;

  @override
  String toString() => 'AuthenticationFailure: ${reason.name}';
}
