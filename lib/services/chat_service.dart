import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user's chats
  Stream<List<ChatModel>> getUserChats() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatModel.fromMap(doc.data()))
          .toList();
    });
  }

  // Get messages for a specific chat
  Stream<List<MessageModel>> getChatMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromMap(doc.data(), docId: doc.id))
          .toList();
    });
  }

  // Send a message
  Future<void> sendMessage(String chatId, String text, String recipientId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    final message = MessageModel(
      text: text,
      senderId: currentUser.uid,
      senderName: currentUser.displayName ?? 'User',
      type: 'text',
      isRead: false,
    );

    // Add message to subcollection
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(message.toMap());

    // Update chat with last message info
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount.$recipientId': FieldValue.increment(1),
    });
  }

  // Create a new chat
  Future<String> createChat({
    required String otherUserId,
    required String otherUserName,
    required String postId,
    required String postTitle,
    String? initialMessage,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    final chatId = _generateChatId(currentUser.uid, otherUserId);
    
    // Check if chat already exists
    final existingChat = await _firestore.collection('chats').doc(chatId).get();
    if (existingChat.exists) {
      return chatId;
    }

    final chat = ChatModel(
      id: chatId,
      participants: [currentUser.uid, otherUserId],
      participantNames: {
        currentUser.uid: currentUser.displayName ?? 'User',
        otherUserId: otherUserName,
      },
      participantAvatars: {
        currentUser.uid: '',
        otherUserId: '',
      },
      lastMessage: initialMessage ?? '',
      lastMessageTime: DateTime.now(),
      unreadCount: {
        currentUser.uid: 0,
        otherUserId: initialMessage != null ? 1 : 0,
      },
      postId: postId,
      postTitle: postTitle,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('chats').doc(chatId).set(chat.toMap());

    // Send initial message if provided
    if (initialMessage != null) {
      await sendMessage(chatId, initialMessage, otherUserId);
    }

    return chatId;
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String senderId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    // Get unread messages from the sender
    final unreadMessages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isEqualTo: senderId)
        .where('isRead', isEqualTo: false)
        .get();

    if (unreadMessages.docs.isEmpty) return;

    // Batch update to mark as read
    final batch = _firestore.batch();
    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    // Update unread count in chat document
    batch.update(
      _firestore.collection('chats').doc(chatId),
      {'unreadCount.$currentUserId': 0},
    );

    await batch.commit();
  }

  // Update typing indicator
  Future<void> updateTypingIndicator(String chatId, bool isTyping) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('typing')
        .doc(currentUserId)
        .set({
      'isTyping': isTyping,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Listen to typing indicator
  Stream<bool> getTypingIndicator(String chatId, String userId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('typing')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return false;
      final data = snapshot.data();
      return data?['isTyping'] ?? false;
    });
  }

  String _generateChatId(String userId1, String userId2) {
    final users = [userId1, userId2]..sort();
    return '${users[0]}_${users[1]}';
  }

  // Delete a chat (optional)
  Future<void> deleteChat(String chatId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    // Delete all messages in the chat
    final messages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();

    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }

    // Delete typing indicators
    final typingDocs = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('typing')
        .get();

    for (final doc in typingDocs.docs) {
      batch.delete(doc.reference);
    }

    // Delete the chat document
    batch.delete(_firestore.collection('chats').doc(chatId));

    await batch.commit();
  }
}