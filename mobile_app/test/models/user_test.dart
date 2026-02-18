import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/user.dart';

void main() {
  group('User model', () {
    group('fromJson', () {
      test('parses basic user fields', () {
        final json = {
          'id': 'user-uuid-1',
          'email': 'agent@nettoyageplus.fr',
          'firstName': 'Jean',
          'lastName': 'Dupont',
          'role': 'AGENT',
          'status': 'ACTIVE',
        };

        final user = User.fromJson(json);

        expect(user.id, equals('user-uuid-1'));
        expect(user.email, equals('agent@nettoyageplus.fr'));
        expect(user.firstName, equals('Jean'));
        expect(user.lastName, equals('Dupont'));
        expect(user.role, equals('AGENT'));
        expect(user.status, equals('ACTIVE'));
      });

      test('displayName returns full name when available', () {
        final json = {
          'id': 'dn-test',
          'email': 'jean.dupont@test.com',
          'firstName': 'Jean',
          'lastName': 'Dupont',
          'role': 'AGENT',
          'status': 'ACTIVE',
        };
        final user = User.fromJson(json);
        expect(user.displayName, equals('Jean Dupont'));
      });

      test('displayName falls back to email when name missing', () {
        final json = {
          'id': 'dn-fallback',
          'email': 'fallback@test.com',
          'role': 'AGENT',
          'status': 'ACTIVE',
        };
        final user = User.fromJson(json);
        expect(user.displayName, equals('fallback@test.com'));
      });

      test('initials returns two uppercase letters', () {
        final json = {
          'id': 'initials-test',
          'email': 'a@b.com',
          'firstName': 'Marie',
          'lastName': 'Martin',
          'role': 'SUPERVISOR',
          'status': 'ACTIVE',
        };
        final user = User.fromJson(json);
        expect(user.initials, equals('MM'));
      });

      test('toJson / fromJson round-trip', () {
        final json = {
          'id': 'round-trip-id',
          'email': 'test@test.com',
          'firstName': 'Marie',
          'lastName': 'Martin',
          'role': 'SUPERVISOR',
          'status': 'ACTIVE',
        };

        final user = User.fromJson(json);
        final restored = User.fromJson(user.toJson());

        expect(restored.id, equals(user.id));
        expect(restored.email, equals(user.email));
        expect(restored.firstName, equals(user.firstName));
        expect(restored.lastName, equals(user.lastName));
        expect(restored.role, equals(user.role));
      });

      test('handles optional phone field', () {
        final jsonWithPhone = {
          'id': 'phone-test',
          'email': 'test@test.com',
          'role': 'AGENT',
          'status': 'ACTIVE',
          'phone': '+33 6 12 34 56 78',
        };

        final jsonWithoutPhone = {
          'id': 'no-phone-test',
          'email': 'test@test.com',
          'role': 'AGENT',
          'status': 'ACTIVE',
        };

        final userWithPhone = User.fromJson(jsonWithPhone);
        final userWithoutPhone = User.fromJson(jsonWithoutPhone);

        expect(userWithPhone.phone, equals('+33 6 12 34 56 78'));
        expect(userWithoutPhone.phone, isNull);
      });
    });
  });
}
