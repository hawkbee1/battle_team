part of 'authentication_cubit.dart';

/// {@template authentication_state}
/// Whether an account is signed in, and which one.
/// {@endtemplate}
final class AuthenticationState extends Equatable {
  /// {@macro authentication_state}
  const new({required this.status, this.accountId});

  /// Whether an account is signed in.
  final AuthenticationStatus status;

  /// The signed-in account's ID; null unless [status] is authenticated.
  final String? accountId;

  @override
  List<Object?> get props => [status, accountId];
}
