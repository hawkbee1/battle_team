import 'package:battle_team/authentication/authentication.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(CredentialValidators, () {
    group('email', () {
      test('M7.12 accepts an address, ignoring the spaces around it', () {
        expect(CredentialValidators.email(' a@x.local '), isNull);
      });

      test('M7.12 refuses nothing typed', () {
        expect(CredentialValidators.email(''), EmailProblem.empty);
        expect(CredentialValidators.email('   '), EmailProblem.empty);
      });

      test('M7.12 refuses what is not an address', () {
        for (final text in ['a', 'a@', '@x.local', 'a@x', 'a b@x.local']) {
          expect(
            CredentialValidators.email(text),
            EmailProblem.invalid,
            reason: text,
          );
        }
      });
    });

    group('passwords', () {
      test('M7.12 a sign-in only needs a password typed', () {
        expect(CredentialValidators.signInPassword(''), PasswordProblem.empty);
        expect(CredentialValidators.signInPassword('x'), isNull);
      });

      test('M7.12 a new password has at least the minimum length', () {
        expect(CredentialValidators.newPassword(''), PasswordProblem.empty);
        expect(
          CredentialValidators.newPassword('1234567'),
          PasswordProblem.tooShort,
        );
        expect(CredentialValidators.newPassword('12345678'), isNull);
      });

      test('M7.12 the confirmation repeats the password', () {
        expect(
          CredentialValidators.confirms('secret-123', 'secret-123'),
          isTrue,
        );
        expect(
          CredentialValidators.confirms('secret-123', 'secret-124'),
          isFalse,
        );
      });
    });

    group('name', () {
      test('M7.12 needs a name, ignoring the spaces around it', () {
        expect(CredentialValidators.name(''), NameProblem.empty);
        expect(CredentialValidators.name('  '), NameProblem.empty);
        expect(CredentialValidators.name(' Ada '), isNull);
      });

      test('M7.12 refuses a name longer than Appwrite keeps', () {
        expect(
          CredentialValidators.name('a' * CredentialValidators.maxNameLength),
          isNull,
        );
        expect(
          CredentialValidators.name(
            'a' * (CredentialValidators.maxNameLength + 1),
          ),
          NameProblem.tooLong,
        );
      });
    });
  });
}
