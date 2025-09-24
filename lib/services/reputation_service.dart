import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/reputation_model.dart';

class ReputationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Add reputation points for a user
  Future<void> addReputationPoints({
    required String userId,
    required ReputationAction action,
    String? postId,
    String? reviewId,
    String? fromUserId,
    String? fromUserName,
    String? customDescription,
  }) async {
    try {
      final points = UserReputationModel.getPointsForAction(action);
      final description = customDescription ?? _getDefaultDescription(action, points);

      // Create reputation log entry
      final logEntry = ReputationLogModel(
        userId: userId,
        action: action,
        points: points,
        postId: postId,
        reviewId: reviewId,
        fromUserId: fromUserId,
        fromUserName: fromUserName,
        description: description,
        timestamp: DateTime.now(),
      );

      // Add to reputation logs
      await _firestore.collection('reputation_logs').add(logEntry.toMap());

      // Update user's reputation summary
      await _updateUserReputationSummary(userId, action, points);

    } catch (e) {
      throw Exception('Failed to add reputation points: $e');
    }
  }

  // Update user's reputation summary
  Future<void> _updateUserReputationSummary(
    String userId, 
    ReputationAction action, 
    int points
  ) async {
    final userReputationRef = _firestore.collection('user_reputation').doc(userId);
    
    await _firestore.runTransaction((transaction) async {
      final userReputationDoc = await transaction.get(userReputationRef);
      
      if (!userReputationDoc.exists) {
        // Create new reputation record
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data();
        
        final newReputation = UserReputationModel(
          userId: userId,
          userName: userData?['fullName'] ?? 'Unknown User',
          userEmail: userData?['email'],
          totalPoints: points,
          successfulDonations: action == ReputationAction.successfulDonation ? 1 : 0,
          positiveFeedbacks: action == ReputationAction.positiveFeedback ? 1 : 0,
          reportedAbuses: action == ReputationAction.reportedAbuse ? 1 : 0,
          completedPosts: action == ReputationAction.postCompleted ? 1 : 0,
          averageResponseTime: 0.0,
          lastUpdated: DateTime.now(),
          level: UserReputationModel.getLevel(points),
        );
        
        transaction.set(userReputationRef, newReputation.toMap());
      } else {
        // Update existing reputation record
        final currentData = userReputationDoc.data()!;
        final currentPoints = currentData['totalPoints'] ?? 0;
        final newTotalPoints = currentPoints + points;
        
        final updates = <String, dynamic>{
          'totalPoints': newTotalPoints,
          'lastUpdated': Timestamp.fromDate(DateTime.now()),
          'level': UserReputationModel.getLevel(newTotalPoints),
        };

        // Update specific counters based on action
        switch (action) {
          case ReputationAction.successfulDonation:
            updates['successfulDonations'] = FieldValue.increment(1);
            break;
          case ReputationAction.positiveFeedback:
            updates['positiveFeedbacks'] = FieldValue.increment(1);
            break;
          case ReputationAction.reportedAbuse:
            updates['reportedAbuses'] = FieldValue.increment(1);
            break;
          case ReputationAction.postCompleted:
            updates['completedPosts'] = FieldValue.increment(1);
            break;
          default:
            break;
        }
        
        transaction.update(userReputationRef, updates);
      }
    });
  }

  // Get user's reputation summary
  Future<UserReputationModel?> getUserReputation(String userId) async {
    try {
      final doc = await _firestore.collection('user_reputation').doc(userId).get();
      if (doc.exists) {
        return UserReputationModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user reputation: $e');
    }
  }

  // Get user's reputation logs
  Future<List<ReputationLogModel>> getUserReputationLogs(String userId, {int limit = 50}) async {
    try {
      final query = await _firestore
          .collection('reputation_logs')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => ReputationLogModel.fromMap(doc.data(), docId: doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get reputation logs: $e');
    }
  }

  // Get leaderboard (top users by reputation)
  Future<List<UserReputationModel>> getLeaderboard({int limit = 50}) async {
    try {
      final query = await _firestore
          .collection('user_reputation')
          .orderBy('totalPoints', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => UserReputationModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get leaderboard: $e');
    }
  }

  // Submit feedback for a user
  Future<void> submitFeedback({
    required String postId,
    required String postTitle,
    required String toUserId,
    required String toUserName,
    required int rating,
    required String comment,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    try {
      final isPositive = rating >= 4; // 4-5 stars considered positive
      
      final feedback = FeedbackModel(
        postId: postId,
        postTitle: postTitle,
        fromUserId: currentUser.uid,
        fromUserName: currentUser.displayName ?? 'Anonymous',
        toUserId: toUserId,
        toUserName: toUserName,
        rating: rating,
        comment: comment,
        isPositive: isPositive,
        timestamp: DateTime.now(),
      );

      // Add feedback to collection
      await _firestore.collection('feedbacks').add(feedback.toMap());

      // Add reputation points based on feedback
      if (isPositive) {
        await addReputationPoints(
          userId: toUserId,
          action: ReputationAction.positiveFeedback,
          postId: postId,
          fromUserId: currentUser.uid,
          fromUserName: currentUser.displayName ?? 'Anonymous',
        );
      }

    } catch (e) {
      throw Exception('Failed to submit feedback: $e');
    }
  }

  // Get feedback for a user
  Future<List<FeedbackModel>> getUserFeedback(String userId, {int limit = 20}) async {
    try {
      final query = await _firestore
          .collection('feedbacks')
          .where('toUserId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => FeedbackModel.fromMap(doc.data(), docId: doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get user feedback: $e');
    }
  }

  // Report abuse (reduces reputation)
  Future<void> reportAbuse({
    required String userId,
    required String reason,
    String? postId,
    String? evidenceUrl,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    try {
      // Create abuse report
      await _firestore.collection('abuse_reports').add({
        'reportedUserId': userId,
        'reporterUserId': currentUser.uid,
        'reporterUserName': currentUser.displayName ?? 'Anonymous',
        'reason': reason,
        'postId': postId,
        'evidenceUrl': evidenceUrl,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Deduct reputation points
      await addReputationPoints(
        userId: userId,
        action: ReputationAction.reportedAbuse,
        postId: postId,
        fromUserId: currentUser.uid,
        fromUserName: currentUser.displayName ?? 'Anonymous',
        customDescription: 'Reported for: $reason',
      );

    } catch (e) {
      throw Exception('Failed to report abuse: $e');
    }
  }

  // Mark post as completed (adds reputation)
  Future<void> markPostCompleted(String postId, String userId) async {
    try {
      await addReputationPoints(
        userId: userId,
        action: ReputationAction.postCompleted,
        postId: postId,
      );
    } catch (e) {
      throw Exception('Failed to mark post as completed: $e');
    }
  }

  // Get user's level color
  static Color getLevelColor(String level) {
    switch (level) {
      case 'Legend':
        return const Color(0xFFFFD700); // Gold
      case 'Champion':
        return const Color(0xFFC0C0C0); // Silver
      case 'Donor':
        return const Color(0xFFCD7F32); // Bronze
      case 'Helper':
        return const Color(0xFF4CAF50); // Green
      case 'Beginner':
      default:
        return const Color(0xFF9E9E9E); // Grey
    }
  }

  // Get user's level icon
  static IconData getLevelIcon(String level) {
    switch (level) {
      case 'Legend':
        return Icons.emoji_events;
      case 'Champion':
        return Icons.military_tech;
      case 'Donor':
        return Icons.volunteer_activism;
      case 'Helper':
        return Icons.favorite;
      case 'Beginner':
      default:
        return Icons.person;
    }
  }

  String _getDefaultDescription(ReputationAction action, int points) {
    switch (action) {
      case ReputationAction.successfulDonation:
        return '+$points points for successful donation';
      case ReputationAction.positiveFeedback:
        return '+$points points for positive feedback';
      case ReputationAction.reportedAbuse:
        return '$points points for reported abuse';
      case ReputationAction.postCompleted:
        return '+$points points for completing post';
      case ReputationAction.helpfulReview:
        return '+$points points for helpful review';
      case ReputationAction.responseTime:
        return '+$points points for quick response';
    }
  }
}