import 'package:backend_status_repository/backend_status_repository.dart';
import 'package:battle_team/backend_status/backend_status.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

void main() {
  group(BackendStatusCubit, () {
    late BackendStatusRepository backendStatusRepository;

    setUp(() {
      backendStatusRepository = MockBackendStatusRepository();
    });

    BackendStatusCubit buildCubit() =>
        BackendStatusCubit(backendStatusRepository: backendStatusRepository);

    test('initial state is $BackendStatus.initial', () {
      expect(buildCubit().state, const BackendStatusState());
    });

    group('checkConnection', () {
      blocTest<BackendStatusCubit, BackendStatusState>(
        'emits [checking, reachable] when the backend answers',
        setUp: () =>
            when(() => backendStatusRepository.checkConnection())
                .thenAnswer((_) async {}),
        build: buildCubit,
        act: (cubit) => cubit.checkConnection(),
        expect: () => const [
          BackendStatusState(status: BackendStatus.checking),
          BackendStatusState(status: BackendStatus.reachable),
        ],
      );

      blocTest<BackendStatusCubit, BackendStatusState>(
        'emits [checking, unreachable] with the reason when it does not',
        setUp: () => when(() => backendStatusRepository.checkConnection())
            .thenThrow(const BackendUnreachableException('Project not found')),
        build: buildCubit,
        act: (cubit) => cubit.checkConnection(),
        expect: () => const [
          BackendStatusState(status: BackendStatus.checking),
          BackendStatusState(
            status: BackendStatus.unreachable,
            errorMessage: 'Project not found',
          ),
        ],
        errors: () => [isA<BackendUnreachableException>()],
      );
    });
  });
}
