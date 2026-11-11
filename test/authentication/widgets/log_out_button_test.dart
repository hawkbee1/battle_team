import 'package:battle_team/authentication/authentication.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

void main() {
  group(LogOutButton, () {
    late MockAuthenticationCubit cubit;

    setUp(() {
      cubit = MockAuthenticationCubit();
      when(() => cubit.state).thenReturn(
        const AuthenticationState(
          status: AuthenticationStatus.authenticated,
          accountId: 'u-1',
        ),
      );
    });

    Future<void> pumpButton(WidgetTester tester, {Locale? locale}) =>
        tester.pumpApp(
          const Scaffold(body: LogOutButton()),
          authenticationCubit: cubit,
          locale: locale,
        );

    testWidgets('M7.12 logs out when pressed', (tester) async {
      when(() => cubit.logOut(onFailure: any(named: 'onFailure')))
          .thenAnswer((_) async {});
      await pumpButton(tester);

      await tester.tap(find.text('Log out'));
      await tester.pump();

      verify(() => cubit.logOut(onFailure: any(named: 'onFailure'))).called(1);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('M7.12 says why it could not, and the account stays', (
      tester,
    ) async {
      when(() => cubit.logOut(onFailure: any(named: 'onFailure')))
          .thenAnswer((invocation) async {
            (invocation.namedArguments[#onFailure]
                as void Function(AuthenticationFailureReason))(
              AuthenticationFailureReason.unreachable,
            );
          });
      await pumpButton(tester);

      await tester.tap(find.text('Log out'));
      await tester.pump();

      expect(
        find.text(
          'Could not log out. Cannot reach the server. Check your connection '
          'and try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('M7.12 speaks French', (tester) async {
      when(() => cubit.logOut(onFailure: any(named: 'onFailure')))
          .thenAnswer((invocation) async {
            (invocation.namedArguments[#onFailure]
                as void Function(AuthenticationFailureReason))(
              AuthenticationFailureReason.other,
            );
          });
      await pumpButton(tester, locale: const Locale('fr'));

      await tester.tap(find.text('Se déconnecter'));
      await tester.pump();

      expect(
        find.text(
          'Déconnexion impossible. Un problème est survenu. Réessayez plus '
          'tard.',
        ),
        findsOneWidget,
      );
    });
  });
}
