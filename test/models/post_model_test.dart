import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:donation_swap/models/post_model.dart';

void main() {
  group('PostModel Tests', () {
    test('should create PostModel with valid data', () {
      final now = DateTime.now();
      final expiryDate = now.add(const Duration(days: 7));
      
      final post = PostModel(
        id: 'test_id',
        title: 'Test Item',
        description: 'Test description',
        category: 'Electronics',
        type: PostType.give,
        condition: 'Good',
        brand: 'TestBrand',
        imageUrls: ['https://example.com/image1.jpg'],
        expiryDays: 7,
        userId: 'user_123',
        userName: 'Test User',
        userEmail: 'test@example.com',
        createdAt: now,
        expiresAt: expiryDate,
        isActive: true,
      );

      expect(post.id, equals('test_id'));
      expect(post.title, equals('Test Item'));
      expect(post.type, equals(PostType.give));
      expect(post.isActive, isTrue);
      expect(post.expiresAt, equals(expiryDate));
    });

    test('should convert PostModel to Map correctly', () {
      final now = DateTime.now();
      final expiryDate = now.add(const Duration(days: 7));
      
      final post = PostModel(
        id: 'test_id',
        title: 'Test Item',
        description: 'Test description',
        category: 'Electronics',
        type: PostType.swap,
        condition: 'Excellent',
        brand: 'TestBrand',
        imageUrls: ['https://example.com/image1.jpg'],
        expiryDays: 7,
        userId: 'user_123',
        userName: 'Test User',
        userEmail: 'test@example.com',
        createdAt: now,
        expiresAt: expiryDate,
        isActive: true,
      );

      final map = post.toMap();

      expect(map['id'], equals('test_id'));
      expect(map['title'], equals('Test Item'));
      expect(map['type'], equals('swap'));
      expect(map['isActive'], isTrue);
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['expiresAt'], isA<Timestamp>());
    });

    test('should create PostModel from Map correctly', () {
      final now = DateTime.now();
      final expiryDate = now.add(const Duration(days: 7));
      
      final map = {
        'id': 'test_id',
        'title': 'Test Item',
        'description': 'Test description',
        'category': 'Electronics',
        'type': 'request',
        'condition': 'Fair',
        'brand': 'TestBrand',
        'imageUrls': ['https://example.com/image1.jpg'],
        'expiryDays': 7,
        'userId': 'user_123',
        'userName': 'Test User',
        'userEmail': 'test@example.com',
        'createdAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(expiryDate),
        'isActive': false,
      };

      final post = PostModel.fromMap(map);

      expect(post.id, equals('test_id'));
      expect(post.title, equals('Test Item'));
      expect(post.type, equals(PostType.request));
      expect(post.isActive, isFalse);
      expect(post.createdAt.millisecondsSinceEpoch, 
             closeTo(now.millisecondsSinceEpoch, 1000));
    });

    test('should handle invalid PostType in fromMap', () {
      final now = DateTime.now();
      final map = {
        'id': 'test_id',
        'title': 'Test Item',
        'description': 'Test description',
        'category': 'Electronics',
        'type': 'invalid_type', // Invalid type
        'condition': 'Good',
        'brand': 'TestBrand',
        'imageUrls': <String>[],
        'expiryDays': 7,
        'userId': 'user_123',
        'userName': 'Test User',
        'userEmail': 'test@example.com',
        'createdAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 7))),
        'isActive': true,
      };

      final post = PostModel.fromMap(map);
      expect(post.type, equals(PostType.give)); // Should default to give
    });

    test('should create PostModel with copyWith method', () {
      final now = DateTime.now();
      final originalPost = PostModel(
        id: 'test_id',
        title: 'Original Title',
        description: 'Original description',
        category: 'Electronics',
        type: PostType.give,
        condition: 'Good',
        brand: 'OriginalBrand',
        imageUrls: ['https://example.com/original.jpg'],
        expiryDays: 7,
        userId: 'user_123',
        userName: 'Test User',
        userEmail: 'test@example.com',
        createdAt: now,
        expiresAt: now.add(const Duration(days: 7)),
        isActive: true,
      );

      final updatedPost = originalPost.copyWith(
        title: 'Updated Title',
        isActive: false,
      );

      expect(updatedPost.title, equals('Updated Title'));
      expect(updatedPost.isActive, isFalse);
      expect(updatedPost.description, equals('Original description')); // Unchanged
      expect(updatedPost.id, equals('test_id')); // Unchanged
    });

    group('Post Expiry Logic Tests', () {
      test('should correctly identify expired posts', () {
        final pastDate = DateTime.now().subtract(const Duration(days: 1));
        final futureDate = DateTime.now().add(const Duration(days: 1));
        
        final expiredPost = PostModel(
          id: 'expired_post',
          title: 'Expired Post',
          description: 'This post has expired',
          category: 'Electronics',
          type: PostType.give,
          condition: 'Good',
          brand: 'TestBrand',
          imageUrls: [],
          expiryDays: 7,
          userId: 'user_123',
          userName: 'Test User',
          userEmail: 'test@example.com',
          createdAt: DateTime.now().subtract(const Duration(days: 8)),
          expiresAt: pastDate, // Expired
          isActive: true,
        );

        final activePost = PostModel(
          id: 'active_post',
          title: 'Active Post',
          description: 'This post is still active',
          category: 'Electronics',
          type: PostType.give,
          condition: 'Good',
          brand: 'TestBrand',
          imageUrls: [],
          expiryDays: 7,
          userId: 'user_123',
          userName: 'Test User',
          userEmail: 'test@example.com',
          createdAt: DateTime.now(),
          expiresAt: futureDate, // Not expired
          isActive: true,
        );

        // Check if posts are expired based on current time
        final now = DateTime.now();
        expect(expiredPost.expiresAt.isBefore(now), isTrue);
        expect(activePost.expiresAt.isAfter(now), isTrue);
      });

      test('should handle posts expiring today', () {
        final today = DateTime.now();
        final endOfToday = DateTime(today.year, today.month, today.day, 23, 59, 59);
        
        final post = PostModel(
          id: 'today_expiry',
          title: 'Expires Today',
          description: 'This post expires today',
          category: 'Electronics',
          type: PostType.give,
          condition: 'Good',
          brand: 'TestBrand',
          imageUrls: [],
          expiryDays: 0,
          userId: 'user_123',
          userName: 'Test User',
          userEmail: 'test@example.com',
          createdAt: today,
          expiresAt: endOfToday,
          isActive: true,
        );

        // Post should still be active if it expires later today
        expect(post.expiresAt.isAfter(DateTime.now()), isTrue);
      });
    });

    group('Post Validation Tests', () {
      test('should validate required fields are not empty', () {
        expect(() => PostModel(
          id: '', // Empty ID should be allowed for new posts
          title: 'Valid Title',
          description: 'Valid description',
          category: 'Electronics',
          type: PostType.give,
          condition: 'Good',
          brand: 'TestBrand',
          imageUrls: [],
          expiryDays: 7,
          userId: 'user_123',
          userName: 'Test User',
          userEmail: 'test@example.com',
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 7)),
          isActive: true,
        ), returnsNormally);
      });

      test('should handle empty image URLs list', () {
        final post = PostModel(
          id: 'test_id',
          title: 'No Images',
          description: 'Post without images',
          category: 'Electronics',
          type: PostType.give,
          condition: 'Good',
          brand: 'TestBrand',
          imageUrls: [], // Empty list
          expiryDays: 7,
          userId: 'user_123',
          userName: 'Test User',
          userEmail: 'test@example.com',
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 7)),
          isActive: true,
        );

        expect(post.imageUrls, isEmpty);
      });

      test('should handle multiple image URLs', () {
        final imageUrls = [
          'https://example.com/image1.jpg',
          'https://example.com/image2.jpg',
          'https://example.com/image3.jpg',
        ];

        final post = PostModel(
          id: 'test_id',
          title: 'Multiple Images',
          description: 'Post with multiple images',
          category: 'Electronics',
          type: PostType.give,
          condition: 'Good',
          brand: 'TestBrand',
          imageUrls: imageUrls,
          expiryDays: 7,
          userId: 'user_123',
          userName: 'Test User',
          userEmail: 'test@example.com',
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 7)),
          isActive: true,
        );

        expect(post.imageUrls.length, equals(3));
        expect(post.imageUrls, containsAll(imageUrls));
      });
    });
  });
}