/// What is wrong with an email.
enum EmailProblem {
  /// Nothing was typed.
  empty,

  /// It is not an email address.
  invalid,
}

/// What is wrong with a password.
enum PasswordProblem {
  /// Nothing was typed.
  empty,

  /// Shorter than [CredentialValidators.minPasswordLength].
  tooShort,
}

/// What is wrong with a name.
enum NameProblem {
  /// Nothing was typed.
  empty,

  /// Longer than [CredentialValidators.maxNameLength].
  tooLong,
}

/// {@template credential_validators}
/// What the sign-in and sign-up forms check before anything goes to Appwrite
/// (pure functions, no Flutter). Appwrite checks again: this only spares a
/// round trip and says what is wrong in the player's words. A problem is null
/// when the text is fine.
/// {@endtemplate}
abstract final class CredentialValidators {
  /// The shortest password a new account may have (Appwrite's own minimum).
  static const minPasswordLength = 8;

  /// The longest name Appwrite keeps.
  static const maxNameLength = 128;

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// What is wrong with [email], ignoring spaces around it.
  static EmailProblem? email(String email) {
    final text = email.trim();
    if (text.isEmpty) return EmailProblem.empty;
    if (!_email.hasMatch(text)) return EmailProblem.invalid;
    return null;
  }

  /// What is wrong with the password of a sign-in: only that it is empty. An
  /// account made under other rules still signs in.
  static PasswordProblem? signInPassword(String password) =>
      password.isEmpty ? PasswordProblem.empty : null;

  /// What is wrong with the password of a new account.
  static PasswordProblem? newPassword(String password) {
    if (password.isEmpty) return PasswordProblem.empty;
    if (password.length < minPasswordLength) return PasswordProblem.tooShort;
    return null;
  }

  /// What is wrong with [name], ignoring spaces around it.
  static NameProblem? name(String name) {
    final text = name.trim();
    if (text.isEmpty) return NameProblem.empty;
    if (text.length > maxNameLength) return NameProblem.tooLong;
    return null;
  }

  /// Whether [confirmation] repeats [password].
  static bool confirms(String password, String confirmation) =>
      password == confirmation;
}
