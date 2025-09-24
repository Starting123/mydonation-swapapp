import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import 'chat_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final PostModel post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final PageController _pageController = PageController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  int _currentImageIndex = 0;
  bool _isLoading = false;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          _currentUser = UserModel.fromMap(doc.data()!);
          setState(() {});
        }
      } catch (e) {
        print('Error loading current user: $e');
      }
    }
  }

  Future<void> _handleInterestedTap() async {
    if (_currentUser == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Create or find existing chat between current user and post owner
      final chatId = _generateChatId(_currentUser!.uid, widget.post.userId);
      
      // Check if chat already exists
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      
      if (!chatDoc.exists) {
        // Create new chat
        await _firestore.collection('chats').doc(chatId).set({
          'id': chatId,
          'participants': [_currentUser!.uid, widget.post.userId],
          'participantNames': {
            _currentUser!.uid: _currentUser!.fullName,
            widget.post.userId: widget.post.userName,
          },
          'participantAvatars': {
            _currentUser!.uid: _currentUser!.idImageUrl ?? '',
            widget.post.userId: '', // We don't have this info, will be empty
          },
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount': {
            _currentUser!.uid: 0,
            widget.post.userId: 1, // Owner will have 1 unread message
          },
          'postId': widget.post.id,
          'postTitle': widget.post.title,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        // Send initial message template
        final initialMessage = _generateInitialMessage();
        await _firestore.collection('chats').doc(chatId).collection('messages').add({
          'text': initialMessage,
          'senderId': _currentUser!.uid,
          'senderName': _currentUser!.fullName,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'text',
          'isRead': false,
        });
        
        // Update last message in chat
        await _firestore.collection('chats').doc(chatId).update({
          'lastMessage': initialMessage,
          'lastMessageTime': FieldValue.serverTimestamp(),
        });
      }
      
      // Send notification to post owner (this would trigger a Cloud Function)
      await _sendInterestNotification();
      
      // Navigate to chat screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              otherUserId: widget.post.userId,
              otherUserName: widget.post.userName,
              postTitle: widget.post.title,
            ),
          ),
        );
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _generateChatId(String userId1, String userId2) {
    // Create consistent chat ID regardless of user order
    final users = [userId1, userId2]..sort();
    return '${users[0]}_${users[1]}';
  }

  String _generateInitialMessage() {
    final typeText = widget.post.type == PostType.give ? 'donation' :
                    widget.post.type == PostType.request ? 'request' : 'swap';
    
    return "Hi! I'm interested in your $typeText: \"${widget.post.title}\". "
           "Could you please provide more details?";
  }

  Future<void> _sendInterestNotification() async {
    // This would trigger a Cloud Function to send FCM notification
    // For now, we'll create a notification document that Cloud Function can process
    await _firestore.collection('notifications').add({
      'type': 'interest',
      'toUserId': widget.post.userId,
      'fromUserId': _currentUser!.uid,
      'fromUserName': _currentUser!.fullName,
      'postId': widget.post.id,
      'postTitle': widget.post.title,
      'message': '${_currentUser!.fullName} is interested in your ${widget.post.title}',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  Future<void> _handleReportPost() async {
    final reason = await _showReportDialog();
    if (reason != null && reason.isNotEmpty) {
      try {
        await _firestore.collection('reports').add({
          'postId': widget.post.id,
          'postTitle': widget.post.title,
          'reportedUserId': widget.post.userId,
          'reportedUserName': widget.post.userName,
          'reporterUserId': _currentUser?.uid ?? '',
          'reporterUserName': _currentUser?.fullName ?? 'Anonymous',
          'reason': reason,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report submitted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error submitting report: $e')),
          );
        }
      }
    }
  }

  Future<String?> _showReportDialog() async {
    String selectedReason = '';
    final reasons = [
      'Inappropriate content',
      'Spam or fake listing',
      'Fraudulent activity',
      'Offensive language',
      'Other',
    ];

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Why are you reporting this post?'),
            const SizedBox(height: 16),
            ...reasons.map((reason) => RadioListTile<String>(
              title: Text(reason),
              value: reason,
              groupValue: selectedReason,
              onChanged: (value) {
                selectedReason = value!;
                Navigator.pop(context, selectedReason);
              },
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMarkCompleted() async {
    final confirmed = await _showCompletionDialog();
    if (confirmed == true) {
      try {
        await _firestore.collection('posts').doc(widget.post.id).update({
          'isActive': false,
          'completedAt': FieldValue.serverTimestamp(),
          'completedBy': _currentUser?.uid ?? '',
        });
        
        // Add reputation points for successful donation
        if (widget.post.type == PostType.give) {
          await _firestore.collection('reputation_logs').add({
            'userId': widget.post.userId,
            'action': 'successful_donation',
            'points': 10,
            'postId': widget.post.id,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post marked as completed')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error marking as completed: $e')),
          );
        }
      }
    }
  }

  Future<bool?> _showCompletionDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Completed'),
        content: const Text(
          'Are you sure you want to mark this post as completed? '
          'This action cannot be undone and the post will no longer be visible to others.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark Completed'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = _currentUser?.uid == widget.post.userId;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.post.title),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'report':
                  _handleReportPost();
                  break;
                case 'complete':
                  _handleMarkCompleted();
                  break;
              }
            },
            itemBuilder: (context) => [
              if (!isOwner)
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.report, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Report'),
                    ],
                  ),
                ),
              if (isOwner)
                const PopupMenuItem(
                  value: 'complete',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Mark as Completed'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Carousel
            if (widget.post.imageUrls.isNotEmpty) ...[
              SizedBox(
                height: 300,
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() => _currentImageIndex = index);
                      },
                      itemCount: widget.post.imageUrls.length,
                      itemBuilder: (context, index) {
                        return Image.network(
                          widget.post.imageUrls[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.image_not_supported, size: 64),
                            );
                          },
                        );
                      },
                    ),
                    // Image indicators
                    if (widget.post.imageUrls.length > 1)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: widget.post.imageUrls.asMap().entries.map((entry) {
                            return Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentImageIndex == entry.key
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.5),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    // Image counter
                    if (widget.post.imageUrls.length > 1)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_currentImageIndex + 1}/${widget.post.imageUrls.length}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                height: 200,
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
                ),
              ),
            ],
            
            // Post Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type Badge and Title
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getTypeColor(widget.post.type),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.post.type.toString().split('.').last.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.post.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Brand, Category, Condition
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      if (widget.post.brand.isNotEmpty)
                        _buildInfoChip(Icons.label, 'Brand', widget.post.brand),
                      _buildInfoChip(Icons.category, 'Category', widget.post.category),
                      _buildInfoChip(Icons.star, 'Condition', widget.post.condition),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.post.description,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  
                  // Owner Info
                  const Text(
                    'Posted by',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          widget.post.userName.isNotEmpty 
                              ? widget.post.userName[0].toUpperCase() 
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.post.userName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Posted ${_formatTimeAgo(widget.post.createdAt)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Expiry Info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getExpiryColor(widget.post.expiresAt).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getExpiryColor(widget.post.expiresAt),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: _getExpiryColor(widget.post.expiresAt),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Expires ${_formatExpiry(widget.post.expiresAt)}',
                          style: TextStyle(
                            color: _getExpiryColor(widget.post.expiresAt),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Action Button
      bottomNavigationBar: !isOwner
          ? Container(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleInterestedTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat),
                          SizedBox(width: 8),
                          Text(
                            "I'm interested",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            )
          : null,
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(PostType type) {
    switch (type) {
      case PostType.give:
        return Colors.green;
      case PostType.request:
        return Colors.blue;
      case PostType.swap:
        return Colors.orange;
    }
  }

  Color _getExpiryColor(DateTime expiryDate) {
    final daysLeft = expiryDate.difference(DateTime.now()).inDays;
    if (daysLeft <= 1) return Colors.red;
    if (daysLeft <= 3) return Colors.orange;
    return Colors.green;
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  String _formatExpiry(DateTime expiryDate) {
    final daysLeft = expiryDate.difference(DateTime.now()).inDays;
    if (daysLeft <= 0) return 'today';
    if (daysLeft == 1) return 'tomorrow';
    return 'in $daysLeft days';
  }
}