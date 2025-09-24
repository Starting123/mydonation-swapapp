import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'logging_service.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  FlutterLocalNotificationsPlugin? _localNotifications;
  String? _currentToken;

  // Initialize FCM service
  Future<void> initialize() async {
    try {
      await _requestPermission();
      await _initializeLocalNotifications();
      await _setupTokenRefreshListener();
      await _updateFCMToken();
      _setupMessageHandlers();
    } catch (e) {
      LoggingService.error('Error initializing FCM service: $e', error: e);
    }
  }

  // Request notification permissions
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      LoggingService.info('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      LoggingService.info('User granted provisional permission');
    } else {
      LoggingService.warning('User declined or has not accepted permission');
    }
  }

  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    _localNotifications = FlutterLocalNotificationsPlugin();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications?.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    if (!kIsWeb) {
      await _createNotificationChannels();
    }
  }

  // Create notification channels for different types
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _localNotifications?.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Messages channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'messages',
          'Messages',
          description: 'Notifications for new messages',
          importance: Importance.high,
        ),
      );

      // Interests channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'interests',
          'Interest Notifications',
          description: 'Notifications when someone is interested in your posts',
          importance: Importance.high,
        ),
      );

      // Alerts channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'alerts',
          'Post Alerts',
          description: 'Notifications for posts matching your saved alerts',
          importance: Importance.defaultImportance,
        ),
      );
    }
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      LoggingService.info('Notification tapped with payload: $payload');
      // TODO: Navigate to appropriate screen based on payload
      // This would typically use a navigation service or global navigator
    }
  }

  // Setup token refresh listener
  Future<void> _setupTokenRefreshListener() async {
    _messaging.onTokenRefresh.listen((token) {
      _currentToken = token;
      _updateFCMTokenInFirestore(token);
    });
  }

  // Update FCM token in Firestore
  Future<void> _updateFCMToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        _currentToken = token;
        await _updateFCMTokenInFirestore(token);
      }
    } catch (e) {
      LoggingService.error('Error getting FCM token: $e', error: e);
    }
  }

  // Update FCM token in Firestore
  Future<void> _updateFCMTokenInFirestore(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      LoggingService.info('FCM token updated successfully');
    } catch (e) {
      LoggingService.error('Error updating FCM token in Firestore: $e', error: e);
    }
  }

  // Setup message handlers
  void _setupMessageHandlers() {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle messages when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Handle messages when app is opened from terminated state
    _handleInitialMessage();
  }

  // Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    LoggingService.info('Received foreground message: ${message.messageId}');
    
    final notification = message.notification;
    final data = message.data;

    if (notification != null && _localNotifications != null) {
      // Show local notification
      await _showLocalNotification(
        title: notification.title ?? 'New Notification',
        body: notification.body ?? '',
        payload: data.toString(),
        channelId: _getChannelId(data['type']),
      );
    }
  }

  // Handle message when app is opened from background
  void _handleMessageOpenedApp(RemoteMessage message) {
    LoggingService.info('App opened from message: ${message.messageId}');
    _navigateBasedOnMessage(message.data);
  }

  // Handle initial message when app is opened from terminated state
  Future<void> _handleInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      LoggingService.info('App opened from terminated state with message: ${initialMessage.messageId}');
      _navigateBasedOnMessage(initialMessage.data);
    }
  }

  // Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String payload = '',
    String channelId = 'default',
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'default',
      'Default',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications?.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Get appropriate channel ID based on notification type
  String _getChannelId(String? type) {
    switch (type) {
      case 'message':
        return 'messages';
      case 'interest':
        return 'interests';
      case 'post_alert':
        return 'alerts';
      default:
        return 'default';
    }
  }

  // Navigate based on message data
  void _navigateBasedOnMessage(Map<String, dynamic> data) {
    final type = data['type'];
    
    switch (type) {
      case 'message':
        // Navigate to chat screen
        final chatId = data['chatId'];
        if (chatId != null) {
          LoggingService.info('Navigate to chat: $chatId');
          // TODO: Use navigation service to navigate to chat
        }
        break;
      case 'interest':
        // Navigate to post detail
        final postId = data['postId'];
        if (postId != null) {
          LoggingService.info('Navigate to post: $postId');
          // TODO: Use navigation service to navigate to post
        }
        break;
      case 'post_alert':
        // Navigate to post detail
        final postId = data['postId'];
        if (postId != null) {
          LoggingService.info('Navigate to alert post: $postId');
          // TODO: Use navigation service to navigate to post
        }
        break;
    }
  }

  // Create user alert for posts matching criteria
  Future<void> createPostAlert({
    required List<String> categories,
    required List<String> types,
    required List<String> keywords,
    required String alertName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      await _firestore.collection('user_alerts').add({
        'userId': user.uid,
        'alertName': alertName,
        'categories': categories,
        'types': types,
        'keywords': keywords,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to create alert: $e');
    }
  }

  // Get user's alerts
  Stream<QuerySnapshot> getUserAlerts() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('user_alerts')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Update alert status
  Future<void> updateAlertStatus(String alertId, bool isActive) async {
    try {
      await _firestore.collection('user_alerts').doc(alertId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update alert: $e');
    }
  }

  // Delete alert
  Future<void> deleteAlert(String alertId) async {
    try {
      await _firestore.collection('user_alerts').doc(alertId).delete();
    } catch (e) {
      throw Exception('Failed to delete alert: $e');
    }
  }

  // Send test notification (for development)
  Future<void> sendTestNotification({
    String title = 'Test Notification',
    String body = 'This is a test notification!',
  }) async {
    try {
      // Show local notification for testing
      await _showLocalNotification(
        title: title,
        body: body,
        payload: 'test',
      );
    } catch (e) {
      LoggingService.error('Error sending test notification: $e', error: e);
    }
  }

  // Get current FCM token
  String? get currentToken => _currentToken;

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  // Clear all notifications
  Future<void> clearAllNotifications() async {
    await _localNotifications?.cancelAll();
  }
}