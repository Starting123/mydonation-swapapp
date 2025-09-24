import 'package:cloud_firestore/cloud_firestore.dart';

enum PostType { give, request, swap }

class PostModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final PostType type;
  final String condition;
  final String brand;
  final List<String> imageUrls;
  final int expiryDays;
  final String userId;
  final String userName;
  final String userEmail;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isActive;

  PostModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.type,
    required this.condition,
    required this.brand,
    required this.imageUrls,
    required this.expiryDays,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.createdAt,
    required this.expiresAt,
    required this.isActive,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'type': type.toString().split('.').last,
      'condition': condition,
      'brand': brand,
      'imageUrls': imageUrls,
      'expiryDays': expiryDays,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isActive': isActive,
    };
  }

  // Create from Firestore document
  factory PostModel.fromMap(Map<String, dynamic> map) {
    return PostModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      type: _parsePostType(map['type'] ?? 'give'),
      condition: map['condition'] ?? '',
      brand: map['brand'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      expiryDays: map['expiryDays'] ?? 7,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userEmail: map['userEmail'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      expiresAt: (map['expiresAt'] as Timestamp).toDate(),
      isActive: map['isActive'] ?? true,
    );
  }

  static PostType _parsePostType(String typeString) {
    switch (typeString) {
      case 'give':
        return PostType.give;
      case 'request':
        return PostType.request;
      case 'swap':
        return PostType.swap;
      default:
        return PostType.give;
    }
  }

  // Copy with method for updates
  PostModel copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    PostType? type,
    String? condition,
    String? brand,
    List<String>? imageUrls,
    int? expiryDays,
    String? userId,
    String? userName,
    String? userEmail,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isActive,
  }) {
    return PostModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      type: type ?? this.type,
      condition: condition ?? this.condition,
      brand: brand ?? this.brand,
      imageUrls: imageUrls ?? this.imageUrls,
      expiryDays: expiryDays ?? this.expiryDays,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
    );
  }
}