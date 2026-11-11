import 'package:battle_team/authentication/authentication.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

void main() {
  group(SignUpPage, () {
    late MockAuthenticationRepository repository;

    setUp(() {
      repository = MockAuthenticationRepository();
      when(
        () => repository.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          name: any(named: 'name'),
        ),
      ).thenAnswer((_) async {});
    });

    Future<void> pumpPage(WidgetTester tester, {Locale? locale}) async {
      // Tall enough for the four fields and the button.
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpApp(
        const SignUpPage(),
        authenticationRepository: repository,
        locale: locale,
      );
    }

    Finder field(String label) => find.widgetWithText(TextFormField, label);
    Finder submit(String label) => find.widgetWithText(FilledButton, label);

    Future<void> fill(
      WidgetTester tester, {
      String name = 'Ada',
      String email = 'a@x.local',
      String password = 'secret-123',
      String? confirmation,
    }) async {
      await tester.enterText(field('Name'), name);
      await tester.enterText(field('Email'), email);
      await tester.enterText(field('Password'), password);
      await tester.enterText(
        field('Repeat the password'),
        confirmation ?? password,
      );
    }

    testWidgets('M7.12 shows a name, an email, a password typed twice', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(field('Name'), findsOneWidget);
      expect(field('Email'), findsOneWidget);
      expect(field('Password'), findsOneWidget);
      expect(field('Repeat the password'), findsOneWidget);
      expect(submit('Create the account'), findsOneWidget);
      expect(find.text('Already have an account? Sign in'), findsOneWidget);
    });

    testWidgets('M7.12 both passwords are hidden as they are typed', (
      tester,
    ) async {
      await pumpPage(tester);

      for (final label in ['Password', 'Repeat the password']) {
        final editable = tester.widget<EditableText>(
          find.descendant(
            of: field(label),
            matching: find.byType(EditableText),
          ),
        );
        expect(editable.obscureText, isTrue, reason: label);
        expect(editable.autocorrect, isFalse, reason: label);
      }
    });

    testWidgets('M7.12 sends nothing while the fields are empty', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(submit('Create the account'));
      await tester.pump();

      expect(find.text('Enter a name'), findsOneWidget);
      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      verifyNever(
        () => repository.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          name: any(named: 'name'),
        ),
      );
    });

    testWidgets('M7.12 says again as each field is edited after a submit', (
      tester,
    ) async {
      await pumpPage(tester);
      await tester.tap(submit('Create the account'));
      await tester.pump();
      expect(find.text('Enter a name'), findsOneWidget);

      await tester.enterText(field('Name'), 'Ada');
      await tester.pump();

      expect(find.text('Enter a name'), findsNothing);
      expect(find.text('Enter your email'), findsOneWidget);
    });

    testWidgets('M7.12 refuses a password that is too short', (tester) async {
      await pumpPage(tester);
      await fill(tester, password: 'short');

      await tester.tap(submit('Create the account'));
      await tester.pump();

      expect(find.text('At least 8 characters'), findsOneWidget);
      verifyNever(
        () => repository.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          name: any(named: 'name'),
        ),
      );
    });

    testWidgets('M7.12 refuses a confirmation that differs', (tester) async {
      await pumpPage(tester);
      await fill(tester, confirmation: 'secret-124');

      await tester.tap(submit('Create the account'));
      await tester.pump();

      expect(find.text('The passwords differ'), findsOneWidget);
      verifyNever(
        () => repository.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          name: any(named: 'name'),
        ),
      );
    });

    testWidgets('M7.12 refuses an email that is not one and a name that is '
        'too long', (tester) async {
      await pumpPage(tester);
      await fill(tester, name: 'a' * 129, email: 'nope');

      await tester.tap(submit('Create the account'));
      await tester.pump();

      expect(find.text('This is not an email address'), findsOneWidget);
      expect(find.text('At most 128 characters'), findsOneWidget);
    });

    testWidgets('M7.12 sends the name and the email without their spaces', (
      tester,
    ) async {
      await pumpPage(tester);
      await fill(tester, name: ' Ada ', email: ' a@x.local ');

      await tester.tap(submit('Create the account'));
      await tester.pump();

      verify(
        () => repository.signUp(
          email: 'a@x.local',
          password: 'secret-123',
          name: 'Ada',
        ),
      ).called(1);
    });

    testWidgets('M7.12 sends from the keyboard too', (tester) async {
      await pumpPage(tester);
      await fill(tester);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      verify(
        () => repository.signUp(
          email: 'a@x.local',
          password: 'secret-123',
          name: 'Ada',
        ),
      ).called(1);
    });

    for (final (reason, text) in [
      (
        AuthenticationFailureReason.accountExists,
        'An account with this email already exists. Sign in instead.',
      ),
      (
        AuthenticationFailureReason.invalidInput,
        'This email or password is not accepted. Check the email and choose '
            'a longer password.',
      ),
      (
        AuthenticationFailureReason.unreachable,
        'Cannot reach the server. Check your connection and try again.',
      ),
    ]) {
      testWidgets('M7.12 says "$text" for $reason', (tester) async {
        when(
          () => repository.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            name: any(named: 'name'),
          ),
        ).thenThrow(AuthenticationFailure(reason));
        await pumpPage(tester);
        await fill(tester);

        await tester.tap(submit('Create the account'));
        await tester.pump();

        expect(find.text(text), findsOneWidget);
        expect(find.textContaining('AuthenticationFailure'), findsNothing);
      });
    }

    testWidgets('M7.12 speaks French', (tester) async {
      when(
        () => repository.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          name: any(named: 'name'),
        ),
      ).thenThrow(
        const AuthenticationFailure(AuthenticationFailureReason.accountExists),
      );
      await pumpPage(tester, locale: const Locale('fr'));

      expect(field('Nom'), findsOneWidget);
      expect(field('Adresse e-mail'), findsOneWidget);
      expect(field('Mot de passe'), findsOneWidget);
      expect(field('Répétez le mot de passe'), findsOneWidget);
      expect(find.text('Déjà un compte ? Connectez-vous'), findsOneWidget);

      await tester.tap(submit('Créer le compte'));
      await tester.pump();
      expect(find.text('Saisissez un nom'), findsOneWidget);
      expect(find.text('Saisissez votre adresse e-mail'), findsOneWidget);

      await tester.enterText(field('Nom'), 'Ada');
      await tester.enterText(field('Adresse e-mail'), 'a@x.local');
      await tester.enterText(field('Mot de passe'), 'court');
      await tester.enterText(field('Répétez le mot de passe'), 'autre');
      await tester.tap(submit('Créer le compte'));
      await tester.pump();
      expect(find.text('Au moins 8 caractères'), findsOneWidget);
      expect(find.text('Les mots de passe diffèrent'), findsOneWidget);

      await tester.enterText(field('Mot de passe'), 'secret-123');
      await tester.enterText(field('Répétez le mot de passe'), 'secret-123');
      await tester.tap(submit('Créer le compte'));
      await tester.pump();
      expect(
        find.text(
          'Un compte existe déjà avec cet e-mail. Connectez-vous plutôt.',
        ),
        findsOneWidget,
      );
    });
  });
}
