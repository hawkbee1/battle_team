import 'dart:async';

import 'package:battle_team/authentication/authentication.dart';
import 'package:battle_team/backend_status/backend_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

void main() {
  group(SignInPage, () {
    late MockAuthenticationRepository repository;

    setUp(() {
      repository = MockAuthenticationRepository();
      when(
        () => repository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {});
    });

    Future<void> pumpPage(WidgetTester tester, {Locale? locale}) =>
        tester.pumpApp(
          const SignInPage(),
          authenticationRepository: repository,
          locale: locale,
        );

    Finder field(String label) => find.widgetWithText(TextFormField, label);
    Finder submit(String label) => find.widgetWithText(FilledButton, label);

    Future<void> fill(
      WidgetTester tester,
      String email,
      String password,
    ) async {
      await tester.enterText(field('Email'), email);
      await tester.enterText(field('Password'), password);
    }

    testWidgets('M7.12 shows the form and whether the backend answers', (
      tester,
    ) async {
      await pumpPage(tester);
      await tester.pump();

      expect(field('Email'), findsOneWidget);
      expect(field('Password'), findsOneWidget);
      expect(submit('Sign in'), findsOneWidget);
      expect(find.text('No account yet? Create one'), findsOneWidget);
      expect(find.byType(BackendStatusIndicator), findsOneWidget);
      expect(find.text('Connected to Appwrite'), findsOneWidget);
    });

    testWidgets('M7.12 the password is hidden as it is typed', (tester) async {
      await pumpPage(tester);

      final password = tester.widget<EditableText>(
        find.descendant(
          of: field('Password'),
          matching: find.byType(EditableText),
        ),
      );
      expect(password.obscureText, isTrue);
      expect(password.autocorrect, isFalse);
      expect(password.enableSuggestions, isFalse);
    });

    testWidgets('M7.12 sends nothing while the fields are empty', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(submit('Sign in'));
      await tester.pump();

      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      verifyNever(
        () => repository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    });

    testWidgets('M7.12 calls nothing wrong before the first submit, then '
        'says again as each field is edited', (tester) async {
      await pumpPage(tester);
      await tester.enterText(field('Email'), 'a');
      await tester.pump();

      expect(find.text('This is not an email address'), findsNothing);

      await tester.tap(submit('Sign in'));
      await tester.pump();
      expect(find.text('This is not an email address'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);

      await tester.enterText(field('Email'), 'a@x.local');
      await tester.enterText(field('Password'), 'secret-123');
      await tester.pump();

      expect(find.text('This is not an email address'), findsNothing);
      expect(find.text('Enter your password'), findsNothing);
    });

    testWidgets('M7.12 sends nothing for what is not an email', (tester) async {
      await pumpPage(tester);
      await fill(tester, 'not-an-email', 'secret-123');

      await tester.tap(submit('Sign in'));
      await tester.pump();

      expect(find.text('This is not an email address'), findsOneWidget);
      verifyNever(
        () => repository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    });

    testWidgets('M7.12 sends the email without its spaces, and the password '
        'as typed', (tester) async {
      await pumpPage(tester);
      await fill(tester, '  a@x.local ', ' secret-123');

      await tester.tap(submit('Sign in'));
      await tester.pump();

      verify(
        () => repository.signIn(email: 'a@x.local', password: ' secret-123'),
      ).called(1);
    });

    testWidgets('M7.12 sends from the keyboard too', (tester) async {
      await pumpPage(tester);
      await fill(tester, 'a@x.local', 'secret-123');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      verify(
        () => repository.signIn(email: 'a@x.local', password: 'secret-123'),
      ).called(1);
    });

    testWidgets('M7.12 waits for the answer: one send, and a button that '
        'waits', (tester) async {
      final answer = Completer<void>();
      when(
        () => repository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) => answer.future);
      await pumpPage(tester);
      await fill(tester, 'a@x.local', 'secret-123');

      await tester.tap(submit('Sign in'));
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      // The backend status checks with a spinner of its own.
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      answer.complete();
      await tester.pump();
    });

    for (final (reason, text) in [
      (
        AuthenticationFailureReason.wrongCredentials,
        'Wrong email or password.',
      ),
      (
        AuthenticationFailureReason.tooManyRequests,
        'Too many attempts. Wait a moment and try again.',
      ),
      (
        AuthenticationFailureReason.unreachable,
        'Cannot reach the server. Check your connection and try again.',
      ),
      (
        AuthenticationFailureReason.other,
        'Something went wrong. Try again later.',
      ),
    ]) {
      testWidgets('M7.12 says "$text" for $reason, no technical text', (
        tester,
      ) async {
        when(
          () => repository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(AuthenticationFailure(reason));
        await pumpPage(tester);
        await fill(tester, 'a@x.local', 'secret-123');

        await tester.tap(submit('Sign in'));
        await tester.pump();

        expect(find.text(text), findsOneWidget);
        expect(find.textContaining('AuthenticationFailure'), findsNothing);
        expect(find.textContaining('Exception'), findsNothing);
        expect(submit('Sign in'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
      });
    }

    testWidgets('M7.12 opens the sign-up page, and comes back from it', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(find.text('No account yet? Create one'));
      await tester.pumpAndSettle();

      expect(find.byType(SignUpPage), findsOneWidget);

      await tester.tap(find.text('Already have an account? Sign in'));
      await tester.pumpAndSettle();

      expect(find.byType(SignUpPage), findsNothing);
      expect(find.byType(SignInPage), findsOneWidget);
    });

    testWidgets('M7.12 speaks French', (tester) async {
      await pumpPage(tester, locale: const Locale('fr'));
      await tester.pump();

      expect(field('Adresse e-mail'), findsOneWidget);
      expect(field('Mot de passe'), findsOneWidget);
      expect(submit('Se connecter'), findsOneWidget);
      expect(find.text('Pas encore de compte ? Créez-en un'), findsOneWidget);
      expect(find.text('Connecté à Appwrite'), findsOneWidget);

      await tester.tap(submit('Se connecter'));
      await tester.pump();

      expect(find.text('Saisissez votre adresse e-mail'), findsOneWidget);
      expect(find.text('Saisissez votre mot de passe'), findsOneWidget);
    });

    testWidgets('M7.12 says in French what went wrong', (tester) async {
      when(
        () => repository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        const AuthenticationFailure(
          AuthenticationFailureReason.wrongCredentials,
        ),
      );
      await pumpPage(tester, locale: const Locale('fr'));
      await tester.enterText(field('Adresse e-mail'), 'a@x.local');
      await tester.enterText(field('Mot de passe'), 'secret-123');

      await tester.tap(submit('Se connecter'));
      await tester.pump();

      expect(find.text('E-mail ou mot de passe incorrect.'), findsOneWidget);
    });
  });
}
