import 'package:audioplayers/audioplayers.dart';
import 'package:backend_status_repository/backend_status_repository.dart';
import 'package:battle_team/backend_status/backend_status.dart';
import 'package:battle_team/loading/loading.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPreloadCubit extends MockCubit<PreloadState> implements PreloadCubit;

class MockAudioCache extends Mock implements AudioCache;

class MockBackendStatusRepository extends Mock
    implements BackendStatusRepository;

class MockBackendStatusCubit extends MockCubit<BackendStatusState>
    implements BackendStatusCubit;
