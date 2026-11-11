import 'package:backend_status_repository/backend_status_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'backend_status_state.dart';

class BackendStatusCubit extends Cubit<BackendStatusState> {
  new({required this._backendStatusRepository})
    : super(const BackendStatusState());

  final BackendStatusRepository _backendStatusRepository;

  Future<void> checkConnection() async {
    emit(const BackendStatusState(status: BackendStatus.checking));
    try {
      await _backendStatusRepository.checkConnection();
      emit(const BackendStatusState(status: BackendStatus.reachable));
    } on BackendUnreachableException catch (exception, stackTrace) {
      // Logged by the bloc observer; the player is told in words, never with
      // the reason.
      addError(exception, stackTrace);
      emit(const BackendStatusState(status: BackendStatus.unreachable));
    }
  }
}
