import 'package:cloud_firestore/cloud_firestore.dart';

enum ReputationAction {
  successfulDonation,
  positiveFeedback,
  reportedAbuse,
  postCompleted,
  helpfulReview,
  responseTime,
}

class ReputationLogModel {
  final String? id;
  final String userId;
  final ReputationAction action;
  final int points;
  final String? postId;
  final String? reviewId;
  final String? fromUserId;
  final String? fromUserName;
  final String description;
  final DateTime timestamp;

  ReputationLogModel({
    this.id,
    required this.userId,
    required this.action,
    required this.points,
    this.postId,
    this.reviewId,
    this.fromUserId,
    this.fromUserName,
    required this.description,
    required this.timestamp,
  });

  factory ReputationLogModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    return ReputationLogModel(
      id: docId,
      userId: map['userId'] ?? '',
      action: _parseReputationAction(map['action'] ?? ''),
      points: map['points'] ?? 0,
      postId: map['postId'],
      reviewId: map['reviewId'],
      fromUserId: map['fromUserId'],
      fromUserName: map['fromUserName'],
      description: map['description'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'action': action.toString().split('.').last,
      'points': points,
      'postId': postId,
      'reviewId': reviewId,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  static ReputationAction _parseReputationAction(String actionString) {
    switch (actionString) {
      case 'successfulDonation':
        return ReputationAction.successfulDonation;
      case 'positiveFeedback':
        return ReputationAction.positiveFeedback;
      case 'reportedAbuse':
        return ReputationAction.reportedAbuse;
      case 'postCompleted':
        return ReputationAction.postCompleted;
      case 'helpfulReview':
        return ReputationAction.helpfulReview;
      case 'responseTime':
        return ReputationAction.responseTime;
      default:
        return ReputationAction.positiveFeedback;
    }
  }
}

class UserReputationModel {
  final String userId;
  final String userName;
  final String? userEmail;
  final int totalPoints;
  final int successfulDonations;
  final int positiveFeedbacks;
  final int reportedAbuses;
  final int completedPosts;
  final double averageResponseTime; // in hours
  final DateTime lastUpdated;
  final String level; // Beginner, Helper, Donor, Champion, Legend

  UserReputationModel({
    required this.userId,
    required this.userName,
    this.userEmail,
    required this.totalPoints,
    required this.successfulDonations,
    required this.positiveFeedbacks,
    required this.reportedAbuses,
    required this.completedPosts,
    required this.averageResponseTime,
    required this.lastUpdated,
    required this.level,
  });

  factory UserReputationModel.fromMap(Map<String, dynamic> map) {
    return UserReputationModel(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userEmail: map['userEmail'],
      totalPoints: map['totalPoints'] ?? 0,
      successfulDonations: map['successfulDonations'] ?? 0,
      positiveFeedbacks: map['positiveFeedbacks'] ?? 0,
      reportedAbuses: map['reportedAbuses'] ?? 0,
      completedPosts: map['completedPosts'] ?? 0,
      averageResponseTime: (map['averageResponseTime'] ?? 0.0).toDouble(),
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
      level: map['level'] ?? 'Beginner',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'totalPoints': totalPoints,
      'successfulDonations': successfulDonations,
      'positiveFeedbacks': positiveFeedbacks,
      'reportedAbuses': reportedAbuses,
      'completedPosts': completedPosts,
      'averageResponseTime': averageResponseTime,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'level': level,
    };
  }

  // Calculate level based on total points
  static String getLevel(int points) {
    if (points >= 1000) return 'Legend';
    if (points >= 500) return 'Champion';
    if (points >= 200) return 'Donor';
    if (points >= 50) return 'Helper';
    return 'Beginner';
  }

  // Get points for different actions
  static int getPointsForAction(ReputationAction action) {
    switch (action) {
      case ReputationAction.successfulDonation:
        return 10;
      case ReputationAction.positiveFeedback:
        return 2;
      case ReputationAction.reportedAbuse:
        return -5;
      case ReputationAction.postCompleted:
        return 5;
      case ReputationAction.helpfulReview:
        return 3;
      case ReputationAction.responseTime:
        return 1; // Bonus for quick response
    }
  }
}

class FeedbackModel {
  final String? id;
  final String postId;
  final String postTitle;
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;
  final int rating; // 1-5 stars
  final String comment;
  final bool isPositive; // true for positive, false for negative
  final DateTime timestamp;

  FeedbackModel({
    this.id,
    required this.postId,
    required this.postTitle,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.rating,
    required this.comment,
    required this.isPositive,
    required this.timestamp,
  });

  factory FeedbackModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    return FeedbackModel(
      id: docId,
      postId: map['postId'] ?? '',
      postTitle: map['postTitle'] ?? '',
      fromUserId: map['fromUserId'] ?? '',
      fromUserName: map['fromUserName'] ?? '',
      toUserId: map['toUserId'] ?? '',
      toUserName: map['toUserName'] ?? '',
      rating: map['rating'] ?? 0,
      comment: map['comment'] ?? '',
      isPositive: map['isPositive'] ?? true,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'postTitle': postTitle,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'toUserId': toUserId,
      'toUserName': toUserName,
      'rating': rating,
      'comment': comment,
      'isPositive': isPositive,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}