import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new post
  Future<void> createPost(PostModel post) async {
    try {
      await _firestore.collection('posts').doc(post.id).set(post.toMap());
    } catch (e) {
      throw Exception('Failed to create post: $e');
    }
  }

  // Get posts by user
  Future<List<PostModel>> getUserPosts(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PostModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get user posts: $e');
    }
  }

  // Get posts by category
  Future<List<PostModel>> getPostsByCategory(String category) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('posts')
          .where('category', isEqualTo: category)
          .where('isActive', isEqualTo: true)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .orderBy('expiresAt')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PostModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get posts by category: $e');
    }
  }

  // Get posts by type
  Future<List<PostModel>> getPostsByType(PostType type) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('posts')
          .where('type', isEqualTo: type.toString().split('.').last)
          .where('isActive', isEqualTo: true)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .orderBy('expiresAt')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PostModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get posts by type: $e');
    }
  }

  // Get all active posts
  Future<List<PostModel>> getAllActivePosts() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('posts')
          .where('isActive', isEqualTo: true)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .orderBy('expiresAt')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => PostModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get active posts: $e');
    }
  }

  // Update post
  Future<void> updatePost(PostModel post) async {
    try {
      await _firestore.collection('posts').doc(post.id).update(post.toMap());
    } catch (e) {
      throw Exception('Failed to update post: $e');
    }
  }

  // Delete post (mark as inactive)
  Future<void> deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to delete post: $e');
    }
  }

  // Search posts
  Future<List<PostModel>> searchPosts(String query) async {
    try {
      // Note: This is a basic search. For more advanced search,
      // consider using Algolia or similar search service
      QuerySnapshot snapshot = await _firestore
          .collection('posts')
          .where('isActive', isEqualTo: true)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .orderBy('expiresAt')
          .orderBy('createdAt', descending: true)
          .get();

      List<PostModel> allPosts = snapshot.docs
          .map((doc) => PostModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      // Filter posts that contain the query in title or description
      String lowercaseQuery = query.toLowerCase();
      return allPosts.where((post) {
        return post.title.toLowerCase().contains(lowercaseQuery) ||
               post.description.toLowerCase().contains(lowercaseQuery) ||
               post.category.toLowerCase().contains(lowercaseQuery) ||
               post.brand.toLowerCase().contains(lowercaseQuery);
      }).toList();
    } catch (e) {
      throw Exception('Failed to search posts: $e');
    }
  }

  // Get post by ID
  Future<PostModel?> getPostById(String postId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('posts').doc(postId).get();
      
      if (doc.exists) {
        return PostModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get post: $e');
    }
  }

  // Stream of posts for real-time updates
  Stream<List<PostModel>> getPostsStream() {
    return _firestore
        .collection('posts')
        .where('isActive', isEqualTo: true)
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PostModel.fromMap(doc.data()))
            .toList());
  }
}