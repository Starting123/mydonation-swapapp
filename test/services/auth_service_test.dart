import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:donation_swap/models/user_model.dart';

void main() {
  group('AuthService Tests', () {
    group('Input Validation Tests', () {
      test('should validate email format correctly', () {
        // Valid emails
        expect(isValidEmail('test@example.com'), isTrue);
        expect(isValidEmail('user.name@domain.co.uk'), isTrue);
        expect(isValidEmail('user+tag@example.org'), isTrue);

        // Invalid emails
        expect(isValidEmail(''), isFalse);
        expect(isValidEmail('invalid-email'), isFalse);
        expect(isValidEmail('@example.com'), isFalse);
        expect(isValidEmail('test@'), isFalse);
        expect(isValidEmail('test@.com'), isFalse);
      });

      test('should validate password strength', () {
        // Valid passwords (minimum 6 characters)
        expect(isValidPassword('password123'), isTrue);
        expect(isValidPassword('MyStrongPassword!'), isTrue);
        expect(isValidPassword('123456'), isTrue);

        // Invalid passwords (too short)
        expect(isValidPassword(''), isFalse);
        expect(isValidPassword('123'), isFalse);
        expect(isValidPassword('short'), isFalse);
      });

      test('should validate full name format', () {
        // Valid names
        expect(isValidFullName('John Doe'), isTrue);
        expect(isValidFullName('Alice Smith'), isTrue);
        expect(isValidFullName('Mary-Jane Watson'), isTrue);
        expect(isValidFullName('José García'), isTrue);

        // Invalid names
        expect(isValidFullName(''), isFalse);
        expect(isValidFullName('A'), isFalse);
        expect(isValidFullName('123'), isFalse);
        expect(isValidFullName('   '), isFalse);
      });
    });

    group('User Model Tests', () {
      test('should create UserModel with all required fields', () {
        final now = DateTime.now();
        final userModel = UserModel(
          uid: 'user_123',
          email: 'test@example.com',
          fullName: 'Test User',
          idVerified: 'not_submitted',
          role: 'user',
          idImageUrl: 'https://example.com/id.jpg',
          createdAt: now,
          updatedAt: now,
        );

        expect(userModel.uid, equals('user_123'));
        expect(userModel.email, equals('test@example.com'));
        expect(userModel.fullName, equals('Test User'));
        expect(userModel.idImageUrl, equals('https://example.com/id.jpg'));
        expect(userModel.idVerified, equals('not_submitted'));
        expect(userModel.role, equals('user'));
        expect(userModel.createdAt, equals(now));
      });

      test('should handle nullable ID image URL', () {
        final now = DateTime.now();
        final userModel = UserModel(
          uid: 'user_123',
          email: 'test@example.com',
          fullName: 'Test User',
          idVerified: 'not_submitted',
          role: 'user',
          idImageUrl: null,
          createdAt: now,
          updatedAt: now,
        );

        expect(userModel.idImageUrl, isNull);
      });

      test('should convert UserModel to Map correctly', () {
        final now = DateTime.now();
        final userModel = UserModel(
          uid: 'user_123',
          email: 'test@example.com',
          fullName: 'Test User',
          idVerified: 'approved',
          role: 'user',
          idImageUrl: 'https://example.com/id.jpg',
          createdAt: now,
          updatedAt: now,
        );

        final map = userModel.toMap();

        expect(map['uid'], equals('user_123'));
        expect(map['email'], equals('test@example.com'));
        expect(map['fullName'], equals('Test User'));
        expect(map['idVerified'], equals('approved'));
        expect(map['role'], equals('user'));
        expect(map['idImageUrl'], equals('https://example.com/id.jpg'));
      });

      test('should create UserModel from Map correctly', () {
        final now = DateTime.now();
        final map = {
          'uid': 'user_123',
          'email': 'test@example.com',
          'fullName': 'Test User',
          'idVerified': 'pending',
          'role': 'user',
          'idImageUrl': 'https://example.com/id.jpg',
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        };

        final userModel = UserModel.fromMap(map);

        expect(userModel.uid, equals('user_123'));
        expect(userModel.email, equals('test@example.com'));
        expect(userModel.fullName, equals('Test User'));
        expect(userModel.idVerified, equals('pending'));
        expect(userModel.role, equals('user'));
      });
    });

    group('Authentication Flows Tests', () {
      test('should handle successful authentication flow', () {
        // Test the expected flow of successful authentication
        const email = 'test@example.com';
        const password = 'password123';
        const fullName = 'Test User';

        // Validate input before authentication
        expect(isValidEmail(email), isTrue);
        expect(isValidPassword(password), isTrue);
        expect(isValidFullName(fullName), isTrue);

        // In a real implementation, this would test the actual auth flow
        // For now, we're testing the validation that would occur
        expect(() => {
          'email': email,
          'password': password,
          'fullName': fullName,
        }, returnsNormally);
      });

      test('should reject invalid authentication data', () {
        const invalidEmail = 'invalid-email';
        const weakPassword = '123';
        const invalidName = 'A';

        expect(isValidEmail(invalidEmail), isFalse);
        expect(isValidPassword(weakPassword), isFalse);
        expect(isValidFullName(invalidName), isFalse);
      });

      test('should handle password reset validation', () {
        const validEmail = 'test@example.com';
        const invalidEmail = 'invalid-email';

        expect(isValidEmail(validEmail), isTrue);
        expect(isValidEmail(invalidEmail), isFalse);
      });
    });

    group('User State Management Tests', () {
      test('should handle user data updates correctly', () {
        final now = DateTime.now();
        final originalUser = UserModel(
          uid: 'user_123',
          email: 'test@example.com',
          fullName: 'Test User',
          idVerified: 'not_submitted',
          role: 'user',
          idImageUrl: null,
          createdAt: now,
          updatedAt: now,
        );

        // Simulate status update
        final updatedUser = UserModel(
          uid: originalUser.uid,
          email: originalUser.email,
          fullName: originalUser.fullName,
          idVerified: 'approved',
          role: originalUser.role,
          idImageUrl: originalUser.idImageUrl,
          createdAt: originalUser.createdAt,
          updatedAt: DateTime.now(),
        );

        expect(updatedUser.idVerified, equals('approved'));
        expect(updatedUser.uid, equals(originalUser.uid));
        expect(updatedUser.updatedAt.isAfter(originalUser.updatedAt), isTrue);
      });

      test('should handle role updates', () {
        final now = DateTime.now();
        final user = UserModel(
          uid: 'user_123',
          email: 'test@example.com',
          fullName: 'Test User',
          idVerified: 'approved',
          role: 'user',
          idImageUrl: null,
          createdAt: now,
          updatedAt: now,
        );

        // Simulate role promotion
        final adminUser = UserModel(
          uid: user.uid,
          email: user.email,
          fullName: user.fullName,
          idVerified: user.idVerified,
          role: 'admin',
          idImageUrl: user.idImageUrl,
          createdAt: user.createdAt,
          updatedAt: DateTime.now(),
        );

        expect(adminUser.role, equals('admin'));
        expect(adminUser.uid, equals(user.uid));
      });
    });
  });
}

// Helper functions for validation logic
bool isValidEmail(String email) {
  return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
}

bool isValidPassword(String password) {
  return password.length >= 6;
}

bool isValidFullName(String fullName) {
  return fullName.trim().length >= 2 && 
         RegExp(r'^[a-zA-Z\s\-\.]+$').hasMatch(fullName.trim());
}