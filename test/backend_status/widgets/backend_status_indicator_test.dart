import 'package:battle_team/backend_status/backend_status.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

void main() {
  group(BackendStatusIndicator, () {
    late BackendStatusCubit cubit;

    setUp(() {
      cubit = MockBackendStatusCubit();
      when(() => cubit.checkConnection()).thenAnswer((_) async {});
    });

    Future<void> pumpIndicator(WidgetTester tester, BackendStatusState state) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpApp(
        BlocProvider.value(value: cubit, child: const BackendStatusIndicator()),
      );
    }

    testWidgets('shows a progress indicator while checking', (tester) async {
      await pumpIndicator(
        tester,
        const BackendStatusState(status: BackendStatus.checking),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Contacting Appwrite…'), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('shows that the backend is reachable', (tester) async {
      await pumpIndicator(
        tester,
        const BackendStatusState(status: BackendStatus.reachable),
      );

      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
      expect(find.text('Connected to Appwrite'), findsOneWidget);
    });

    testWidgets('shows the reason when the backend is unreachable', (
      tester,
    ) async {
      await pumpIndicator(
        tester,
        const BackendStatusState(
          status: BackendStatus.unreachable,
          errorMessage: 'Project not found',
        ),
      );

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text('Cannot reach Appwrite'), findsOneWidget);
      expect(find.text('Project not found'), findsOneWidget);
    });

    testWidgets('checks again when the retry button is tapped', (tester) async {
      await pumpIndicator(
        tester,
        const BackendStatusState(status: BackendStatus.unreachable),
      );

      await tester.tap(find.byTooltip('Check again'));

      verify(() => cubit.checkConnection()).called(1);
    });
  });
}
