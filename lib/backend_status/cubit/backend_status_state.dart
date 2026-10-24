part of 'backend_status_cubit.dart';

enum BackendStatus { initial, checking, reachable, unreachable }

final class BackendStatusState extends Equatable {
  const new({this.status = BackendStatus.initial, this.errorMessage = ''});

  final BackendStatus status;

  /// Why the backend is unreachable. Empty unless [status] is
  /// [BackendStatus.unreachable].
  final String errorMessage;

  @override
  List<Object> get props => [status, errorMessage];
}
