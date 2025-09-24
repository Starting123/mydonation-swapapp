import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final Map<String, String> participantAvatars;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final Map<String, int> unreadCount;
  final String postId;
  final String postTitle;
  final DateTime createdAt;

  ChatModel({
    required this.id,
    required this.participants,
    required this.participantNames,
    required this.participantAvatars,
    required this.lastMessage,
    this.lastMessageTime,
    required this.unreadCount,
    required this.postId,
    required this.postTitle,
    required this.createdAt,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map) {
    return ChatModel(
      id: map['id'] ?? '',
      participants: List<String>.from(map['participants'] ?? []),
      participantNames: Map<String, String>.from(map['participantNames'] ?? {}),
      participantAvatars: Map<String, String>.from(map['participantAvatars'] ?? {}),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: map['lastMessageTime'] != null 
          ? (map['lastMessageTime'] as Timestamp).toDate()
          : null,
      unreadCount: Map<String, int>.from(map['unreadCount'] ?? {}),
      postId: map['postId'] ?? '',
      postTitle: map['postTitle'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participants': participants,
      'participantNames': participantNames,
      'participantAvatars': participantAvatars,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null 
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'unreadCount': unreadCount,
      'postId': postId,
      'postTitle': postTitle,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class MessageModel {
  final String? id;
  final String text;
  final String senderId;
  final String senderName;
  final DateTime? timestamp;
  final String type; // 'text', 'image', 'system'
  final bool isRead;
  final String? imageUrl;

  MessageModel({
    this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    this.timestamp,
    required this.type,
    required this.isRead,
    this.imageUrl,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    return MessageModel(
      id: docId,
      text: map['text'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      timestamp: map['timestamp'] != null 
          ? (map['timestamp'] as Timestamp).toDate()
          : null,
      type: map['type'] ?? 'text',
      isRead: map['isRead'] ?? false,
      imageUrl: map['imageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'senderId': senderId,
      'senderName': senderName,
      'timestamp': timestamp != null 
          ? Timestamp.fromDate(timestamp!)
          : FieldValue.serverTimestamp(),
      'type': type,
      'isRead': isRead,
      'imageUrl': imageUrl,
    };
  }
}