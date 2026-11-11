part of 'backend_status_cubit.dart';

enum BackendStatus { initial, checking, reachable, unreachable }

final class BackendStatusState extends Equatable {
  const new({this.status = BackendStatus.initial});

  final BackendStatus status;

  @override
  List<Object> get props => [status];
}
