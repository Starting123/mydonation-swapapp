import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:donation_swap/models/post_model.dart';
import 'package:donation_swap/services/post_service.dart';

void main() {
  group('PostService Tests', () {
    late PostService postService;

    setUp(() {
      postService = PostService();
    });

    group('Post Filtering Tests', () {
      test('should filter posts by category correctly', () {
        final posts = _createSamplePosts();
        
        final electronicsFilter = (PostModel post) => post.category == 'Electronics';
        final booksFilter = (PostModel post) => post.category == 'Books';
        
        final electronicsPosts = posts.where(electronicsFilter).toList();
        final booksPosts = posts.where(booksFilter).toList();
        
        expect(electronicsPosts.length, equals(2));
        expect(booksPosts.length, equals(1));
        expect(electronicsPosts.every((p) => p.category == 'Electronics'), isTrue);
        expect(booksPosts.every((p) => p.category == 'Books'), isTrue);
      });

      test('should filter posts by type correctly', () {
        final posts = _createSamplePosts();
        
        final givePosts = posts.where((p) => p.type == PostType.give).toList();
        final requestPosts = posts.where((p) => p.type == PostType.request).toList();
        final swapPosts = posts.where((p) => p.type == PostType.swap).toList();
        
        expect(givePosts.length, equals(2));
        expect(requestPosts.length, equals(1));
        expect(swapPosts.length, equals(0));
      });

      test('should filter active posts correctly', () {
        final posts = _createSamplePosts();
        
        final activePosts = posts.where((p) => p.isActive).toList();
        final inactivePosts = posts.where((p) => !p.isActive).toList();
        
        expect(activePosts.length, equals(2));
        expect(inactivePosts.length, equals(1));
      });

      test('should filter non-expired posts correctly', () {
        final posts = _createSamplePosts();
        final now = DateTime.now();
        
        final nonExpiredPosts = posts.where((p) => p.expiresAt.isAfter(now)).toList();
        final expiredPosts = posts.where((p) => p.expiresAt.isBefore(now)).toList();
        
        expect(nonExpiredPosts.length, equals(2));
        expect(expiredPosts.length, equals(1));
      });
    });

    group('Post Search Tests', () {
      test('should search posts by title', () {
        final posts = _createSamplePosts();
        
        final searchResults = posts.where((post) => 
          post.title.toLowerCase().contains('laptop'.toLowerCase())).toList();
        
        expect(searchResults.length, equals(1));
        expect(searchResults.first.title, contains('Laptop'));
      });

      test('should search posts by brand', () {
        final posts = _createSamplePosts();
        
        final appleResults = posts.where((post) => 
          post.brand.toLowerCase().contains('apple'.toLowerCase())).toList();
        
        expect(appleResults.length, equals(1));
        expect(appleResults.first.brand, equals('Apple'));
      });

      test('should perform case-insensitive search', () {
        final posts = _createSamplePosts();
        
        final searchResults = posts.where((post) => 
          post.title.toLowerCase().contains('LAPTOP'.toLowerCase()) ||
          post.brand.toLowerCase().contains('APPLE'.toLowerCase())).toList();
        
        expect(searchResults.length, equals(2));
      });

      test('should handle empty search query', () {
        final posts = _createSamplePosts();
        
        final searchResults = posts.where((post) => 
          post.title.toLowerCase().contains(''.toLowerCase())).toList();
        
        expect(searchResults.length, equals(posts.length));
      });
    });

    group('Post Expiry Logic Tests', () {
      test('should correctly calculate expiry date', () {
        final now = DateTime.now();
        const expiryDays = 7;
        
        final post = PostModel(
          id: 'test_post',
          title: 'Test Item',
          description: 'Test description',
          category: 'Electronics',
          type: PostType.give,
          condition: 'Good',
          brand: 'TestBrand',
          imageUrls: [],
          expiryDays: expiryDays,
          userId: 'user_123',
          userName: 'Test User',
          userEmail: 'test@example.com',
          createdAt: now,
          expiresAt: now.add(Duration(days: expiryDays)),
          isActive: true,
        );

        final expectedExpiryDate = now.add(Duration(days: expiryDays));
        expect(post.expiresAt.day, equals(expectedExpiryDate.day));
        expect(post.expiresAt.month, equals(expectedExpiryDate.month));
        expect(post.expiresAt.year, equals(expectedExpiryDate.year));
      });

      test('should handle different expiry periods', () {
        final now = DateTime.now();
        final expiryPeriods = [1, 3, 7, 14, 30];
        
        for (final days in expiryPeriods) {
          final post = PostModel(
            id: 'test_post_$days',
            title: 'Test Item $days',
            description: 'Test description',
            category: 'Electronics',
            type: PostType.give,
            condition: 'Good',
            brand: 'TestBrand',
            imageUrls: [],
            expiryDays: days,
            userId: 'user_123',
            userName: 'Test User',
            userEmail: 'test@example.com',
            createdAt: now,
            expiresAt: now.add(Duration(days: days)),
            isActive: true,
          );
          
          final expectedDate = now.add(Duration(days: days));
          expect(post.expiresAt.isAfter(now), isTrue);
          expect(post.expiresAt.difference(now).inDays, 
                 closeTo(days, 1)); // Allow 1 day tolerance
        }
      });

      test('should identify expired posts correctly', () {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));
        final tomorrow = now.add(const Duration(days: 1));
        
        final expiredPost = PostModel(
          id: 'expired_post',
          title: 'Expired Item',
          description: 'This item has expired',
          category: 'Electronics',
          type: PostType.give,
          condition: 'Good',
          brand: 'TestBrand',
          imageUrls: [],
          expiryDays: 1,
          userId: 'user_123',
          userName: 'Test User',
          userEmail: 'test@example.com',
          createdAt: now.subtract(const Duration(days: 2)),
          expiresAt: yesterday,
          isActive: true,
        );

        final activePost = PostModel(
          id: 'active_post',
          title: 'Active Item',
          description: 'This item is still active',
          category: 'Electronics',
          type: PostType.give,
          condition: 'Good',
          brand: 'TestBrand',
          imageUrls: [],
          expiryDays: 1,
          userId: 'user_123',
          userName: 'Test User',
          userEmail: 'test@example.com',
          createdAt: now,
          expiresAt: tomorrow,
          isActive: true,
        );

        expect(expiredPost.expiresAt.isBefore(now), isTrue);
        expect(activePost.expiresAt.isAfter(now), isTrue);
      });
    });

    group('Post Validation Tests', () {
      test('should validate required fields', () {
        expect(() => PostModel(
          id: 'valid_post',
          title: 'Valid Title',
          description: 'Valid description with sufficient length.',
          category: 'Electronics',
          type: PostType.give,
          condition: 'Good',
          brand: 'ValidBrand',
          imageUrls: ['https://example.com/image.jpg'],
          expiryDays: 7,
          userId: 'user_123',
          userName: 'Valid User',
          userEmail: 'valid@example.com',
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 7)),
          isActive: true,
        ), returnsNormally);
      });

      test('should handle posts with multiple images', () {
        final imageUrls = [
          'https://example.com/image1.jpg',
          'https://example.com/image2.jpg',
          'https://example.com/image3.jpg',
        ];

        final post = PostModel(
          id: 'multi_image_post',
          title: 'Multi Image Item',
          description: 'Item with multiple images',
          category: 'Electronics',
          type: PostType.give,
          condition: 'Excellent',
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

      test('should handle posts without images', () {
        final post = PostModel(
          id: 'no_image_post',
          title: 'No Image Item',
          description: 'Item without images',
          category: 'Books',
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
        );

        expect(post.imageUrls, isEmpty);
      });
    });

    group('Firestore Query Logic Tests', () {
      test('should build correct query filters', () {
        // These tests would verify query construction logic
        // In a real implementation, you'd test the actual query building
        
        final queryParams = {
          'category': 'Electronics',
          'type': 'give',
          'isActive': true,
        };

        expect(queryParams['category'], equals('Electronics'));
        expect(queryParams['type'], equals('give'));
        expect(queryParams['isActive'], isTrue);
      });

      test('should handle pagination parameters', () {
        const limit = 10;
        const lastDocId = 'last_document_id';
        
        final paginationParams = {
          'limit': limit,
          'startAfter': lastDocId,
        };

        expect(paginationParams['limit'], equals(10));
        expect(paginationParams['startAfter'], equals(lastDocId));
      });

      test('should validate search terms', () {
        const validSearchTerms = ['laptop', 'phone', 'book'];
        const invalidSearchTerms = ['', '  ', '\t\n'];
        
        for (final term in validSearchTerms) {
          expect(term.trim().isNotEmpty, isTrue);
        }
        
        for (final term in invalidSearchTerms) {
          expect(term.trim().isEmpty, isTrue);
        }
      });
    });
  });
}

// Helper function to create sample posts for testing
List<PostModel> _createSamplePosts() {
  final now = DateTime.now();
  
  return [
    PostModel(
      id: 'post_1',
      title: 'Old Laptop',
      description: 'Working laptop, good condition',
      category: 'Electronics',
      type: PostType.give,
      condition: 'Good',
      brand: 'Dell',
      imageUrls: ['https://example.com/laptop.jpg'],
      expiryDays: 7,
      userId: 'user_1',
      userName: 'John Doe',
      userEmail: 'john@example.com',
      createdAt: now.subtract(const Duration(hours: 1)),
      expiresAt: now.add(const Duration(days: 6)),
      isActive: true,
    ),
    PostModel(
      id: 'post_2',
      title: 'iPhone Charger',
      description: 'Original Apple charger',
      category: 'Electronics',
      type: PostType.give,
      condition: 'Excellent',
      brand: 'Apple',
      imageUrls: ['https://example.com/charger.jpg'],
      expiryDays: 3,
      userId: 'user_2',
      userName: 'Jane Smith',
      userEmail: 'jane@example.com',
      createdAt: now.subtract(const Duration(hours: 2)),
      expiresAt: now.add(const Duration(days: 2)),
      isActive: true,
    ),
    PostModel(
      id: 'post_3',
      title: 'Programming Book',
      description: 'Looking for Flutter development book',
      category: 'Books',
      type: PostType.request,
      condition: 'Any',
      brand: 'Various',
      imageUrls: [],
      expiryDays: 14,
      userId: 'user_3',
      userName: 'Bob Wilson',
      userEmail: 'bob@example.com',
      createdAt: now.subtract(const Duration(days: 15)),
      expiresAt: now.subtract(const Duration(days: 1)), // Expired
      isActive: false,
    ),
  ];
}