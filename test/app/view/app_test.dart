import 'package:backend_status_repository/backend_status_repository.dart';
import 'package:battle_team/app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

void main() {
  group('App', () {
    late BackendStatusRepository backendStatusRepository;

    setUp(() {
      backendStatusRepository = MockBackendStatusRepository();
      when(() => backendStatusRepository.checkConnection())
          .thenAnswer((_) async {});
    });

    testWidgets('renders AppView', (tester) async {
      await tester.pumpWidget(
        App(backendStatusRepository: backendStatusRepository),
      );

      await tester.pumpAndSettle(const Duration(seconds: 400));
      expect(find.byType(AppView), findsOneWidget);
    });
  });
}
