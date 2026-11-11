part of 'authentication_form_cubit.dart';

/// Where a sign-in or a sign-up form stands.
enum AuthenticationFormStatus {
  /// Waiting for the player to submit.
  editing,

  /// Sent to Appwrite, no answer yet.
  submitting,

  /// Accepted: the app moves on by itself.
  succeeded,

  /// Refused or failed; [AuthenticationFormState.failure] says why.
  failed,
}

/// {@template authentication_form_state}
/// A form's status and, once it failed, why. It holds nothing that was typed:
/// no email, no password, no name.
/// {@endtemplate}
final class AuthenticationFormState extends Equatable {
  /// {@macro authentication_form_state}
  const new({this.status = AuthenticationFormStatus.editing, this.failure});

  /// Where the form stands.
  final AuthenticationFormStatus status;

  /// Why the last submission failed; null unless [status] is failed.
  final AuthenticationFailureReason? failure;

  @override
  List<Object?> get props => [status, failure];
}
