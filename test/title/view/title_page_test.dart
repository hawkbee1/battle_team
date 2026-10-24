import 'package:battle_team/backend_status/backend_status.dart';
import 'package:battle_team/title/title.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockingjay/mockingjay.dart';

import '../../helpers/helpers.dart';

void main() {
  group('TitlePage', () {
    testWidgets('renders TitleView', (tester) async {
      await tester.pumpApp(const TitlePage());
      expect(find.byType(TitleView), findsOneWidget);
    });

    testWidgets('checks the backend connection on start', (tester) async {
      final backendStatusRepository = MockBackendStatusRepository();
      when(backendStatusRepository.checkConnection).thenAnswer((_) async {});

      await tester.pumpApp(
        const TitlePage(),
        backendStatusRepository: backendStatusRepository,
      );
      await tester.pump();

      verify(backendStatusRepository.checkConnection).called(1);
      expect(find.text('Connected to Appwrite'), findsOneWidget);
    });
  });

  group('TitleView', () {
    late BackendStatusCubit backendStatusCubit;

    setUp(() {
      backendStatusCubit = MockBackendStatusCubit();
      when(
        () => backendStatusCubit.state,
      ).thenReturn(const BackendStatusState(status: BackendStatus.reachable));
    });

    Widget buildSubject() =>
        BlocProvider.value(value: backendStatusCubit, child: const TitleView());

    testWidgets('renders start button', (tester) async {
      await tester.pumpApp(buildSubject());

      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('renders the backend status', (tester) async {
      await tester.pumpApp(buildSubject());

      expect(find.byType(BackendStatusIndicator), findsOneWidget);
    });

    testWidgets('starts the game when start button is tapped', (tester) async {
      final navigator = MockNavigator();
      when(navigator.canPop).thenReturn(true);
      when(() => navigator.pushReplacement<void, void>(any()))
          .thenAnswer((_) async {});

      await tester.pumpApp(buildSubject(), navigator: navigator);

      await tester.tap(find.byType(ElevatedButton));

      verify(() => navigator.pushReplacement<void, void>(any())).called(1);
    });
  });
}
