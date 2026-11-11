import 'package:appwrite_api_client/appwrite_api_client.dart';
import 'package:backend_status_repository/backend_status_repository.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/authentication/authentication.dart';
import 'package:battle_team/backend_status/backend_status.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBackendStatusRepository extends Mock
    implements BackendStatusRepository;

class MockBackendStatusCubit extends MockCubit<BackendStatusState>
    implements BackendStatusCubit;

class MockBattleRepository extends Mock implements BattleRepository;

class MockAppwriteApiClient extends Mock implements AppwriteApiClient;

class MockAuthenticationRepository extends Mock
    implements AuthenticationRepository;

class MockAuthenticationCubit extends MockCubit<AuthenticationState>
    implements AuthenticationCubit;

class MockBattleLocator extends Mock implements BattleLocator;

class MockBattleRepositoryFactory extends Mock
    implements BattleRepositoryFactory;

/// Registers the fallback values of the sealed types mocktail matches with
/// `any()`; call it once, in `setUpAll`.
void registerBattleFallbackValues() {
  registerFallbackValue(const Move(unitId: 'u', to: Position(0, 0, 0)));
  registerFallbackValue(const Position(0, 0, 0));
  registerFallbackValue(
    const ApView(value: 0, at: Duration.zero, perHour: 1, max: 1),
  );
}
