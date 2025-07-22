// lib/services/notification_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:lupus_care/views/chat_screen/chat_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:lupus_care/helper/storage_service.dart';

class NotificationService extends GetxService {
  static NotificationService get to => Get.find();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Observable for FCM token
  RxString fcmToken = ''.obs;

  // Track notification permissions
  RxBool notificationsEnabled = false.obs;

  @override
  Future<void> onInit() async {
    super.onInit();
    await initializeNotifications();
  }

  /// Initialize all notification services
  Future<void> initializeNotifications() async {
    try {
      print('🔔 Initializing notification services...');

      // Request permissions first
      await _requestPermissions();

      // Initialize Firebase Messaging
      await _initializeFirebaseMessaging();

      // Get and store FCM token
      await _getFCMToken();

      print('✅ Notification services initialized successfully');
    } catch (e) {
      print('❌ Error initializing notifications: $e');
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      print('🔐 Requesting notification permissions...');

      // Request Firebase Messaging permissions
      final NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      print('📱 Firebase Messaging permission: ${settings.authorizationStatus}');

      // Request system notification permissions
      final PermissionStatus status = await Permission.notification.request();
      print('📱 System notification permission: $status');

      notificationsEnabled.value = settings.authorizationStatus == AuthorizationStatus.authorized &&
          status == PermissionStatus.granted;

      print('✅ Notification permissions: ${notificationsEnabled.value}');
    } catch (e) {
      print('❌ Error requesting permissions: $e');
    }
  }

  /// Initialize Firebase Messaging
  Future<void> _initializeFirebaseMessaging() async {
    try {
      print('🔥 Initializing Firebase Messaging...');

      // Handle foreground messages - we'll just handle the data directly
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📨 Received foreground message: ${message.notification?.title}');
        _handleMessage(message);
      });

      // Handle notification opened app from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('📱 App opened from notification: ${message.notification?.title}');
        _handleMessage(message, wasOpened: true);
      });

      // Handle notification that opened app from terminated state
      final RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        print('📱 App opened from terminated state: ${initialMessage.notification?.title}');
        _handleMessage(initialMessage, wasOpened: true);
      }

      print('✅ Firebase Messaging initialized');
    } catch (e) {
      print('❌ Error initializing Firebase Messaging: $e');
    }
  }

  /// Get FCM token and store it
  Future<void> _getFCMToken() async {
    try {
      print('🔑 Getting FCM token...');

      final String? token = await _firebaseMessaging.getToken();

      if (token != null) {
        fcmToken.value = token;
        print('✅ FCM Token received: ${token.substring(0, 50)}...');

        // Store token in Firestore for current user
        await _storeFCMToken(token);

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          print('🔄 FCM Token refreshed');
          fcmToken.value = newToken;
          _storeFCMToken(newToken);
        });
      } else {
        print('❌ Failed to get FCM token');
      }
    } catch (e) {
      print('❌ Error getting FCM token: $e');
    }
  }

  /// Store FCM token in Firestore
  Future<void> _storeFCMToken(String token) async {
    try {
      final currentUserId = getCurrentUserId();

      if (currentUserId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          'platform': Platform.isAndroid ? 'android' : 'ios',
        });

        print('✅ FCM token stored in Firestore for user: $currentUserId');
      } else {
        print('❌ No current user ID to store FCM token');
      }
    } catch (e) {
      print('❌ Error storing FCM token: $e');
    }
  }

  /// Handle all incoming messages
  void _handleMessage(RemoteMessage message, {bool wasOpened = false}) {
    try {
      print('📨 Handling message (opened: $wasOpened)...');

      final data = message.data;
      final chatId = data['chatId'];
      final senderId = data['senderId'];

      if (chatId != null && wasOpened) {
        _navigateToChat(chatId, senderId);
      }
    } catch (e) {
      print('❌ Error handling message: $e');
    }
  }

  /// Navigate to chat screen
  void _navigateToChat(String chatId, String? senderId) {
    try {
      print('🚀 Navigating to chat: $chatId');

      // Check if ChatController is available
      if (Get.isRegistered<ChatController>()) {
        final chatController = Get.find<ChatController>();

        // Handle the notification opened in ChatController
        chatController.handleNotificationOpened({
          'chatId': chatId,
          'senderId': senderId,
        });
      } else {
        print('❌ ChatController not registered');
      }
    } catch (e) {
      print('❌ Error navigating to chat: $e');
    }
  }

  /// Send notification to specific user
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    required String chatId,
    required String senderId,
    String? senderName,
  }) async {
    try {
      print('📤 Sending notification to user: $userId');

      // Get user's FCM token from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final fcmToken = userData['fcmToken'] as String?;

        if (fcmToken != null && fcmToken.isNotEmpty) {
          print('📤 Found FCM token for user: $userId');

          await _sendFCMNotification(
            token: fcmToken,
            title: title,
            body: body,
            data: {
              'chatId': chatId,
              'senderId': senderId,
              'senderName': senderName ?? 'Unknown',
              'type': 'chat_message',
            },
          );
        } else {
          print('⚠️ No FCM token found for user: $userId');
        }
      } else {
        print('⚠️ User document not found: $userId');
      }
    } catch (e) {
      print('❌ Error sending notification to user: $e');
    }
  }

  /// Send notification to multiple users
  Future<void> sendNotificationToUsers({
    required List<String> userIds,
    required String title,
    required String body,
    required String chatId,
    required String senderId,
    String? senderName,
  }) async {
    try {
      print('📤 Sending notification to ${userIds.length} users');

      for (final userId in userIds) {
        await sendNotificationToUser(
          userId: userId,
          title: title,
          body: body,
          chatId: chatId,
          senderId: senderId,
          senderName: senderName,
        );
      }
    } catch (e) {
      print('❌ Error sending notification to users: $e');
    }
  }

  /// Send FCM notification to single token
  Future<void> _sendFCMNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      print('📤 Sending FCM notification to token: ${token.substring(0, 20)}...');

      // Method 1: Using your backend API (RECOMMENDED)
      await _sendNotificationViaBackend(
        token: token,
        title: title,
        body: body,
        data: data,
      );

      print('✅ FCM notification sent successfully');
    } catch (e) {
      print('❌ Error sending FCM notification: $e');
    }
  }

  /// Send notification via your backend API (RECOMMENDED APPROACH)
  Future<void> _sendNotificationViaBackend({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      print('📤 Sending notification via backend API...');

      // Get current user data for authentication
      final userData = StorageService.to.getUser();
      if (userData == null) {
        throw Exception('No user data for authentication');
      }

      // Your backend API endpoint for sending notifications
      const String apiUrl = 'https://your-backend-api.com/send-notification';

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${userData['token']}', // Use your auth token
        },
        body: jsonEncode({
          'fcm_token': token,
          'title': title,
          'body': body,
          'data': data,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Notification sent via backend successfully');
      } else {
        print('❌ Backend notification failed: ${response.statusCode}');
        print('❌ Response: ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending notification via backend: $e');
    }
  }

  /// Get current user ID
  String? getCurrentUserId() {
    try {
      final userData = StorageService.to.getUser();
      if (userData != null) {
        final userId = userData['id']?.toString() ?? '';
        final userEmail = userData['email']?.toString() ?? '';

        // Generate consistent user ID (same as ChatController)
        if (userId.isNotEmpty) {
          return 'app_user_$userId';
        } else if (userEmail.isNotEmpty) {
          return 'app_user_${userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
        }
      }

      return null;
    } catch (e) {
      print('❌ Error getting current user ID: $e');
      return null;
    }
  }

  /// Check if notifications are enabled
  bool get areNotificationsEnabled => notificationsEnabled.value;

  /// Get FCM token
  String get currentFCMToken => fcmToken.value;

  /// Clear FCM token (for logout)
  Future<void> clearFCMToken() async {
    try {
      final currentUserId = getCurrentUserId();

      if (currentUserId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .update({
          'fcmToken': FieldValue.delete(),
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
      }

      fcmToken.value = '';
      print('✅ FCM token cleared');
    } catch (e) {
      print('❌ Error clearing FCM token: $e');
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📨 Background message received: ${message.notification?.title}');
  // You can add any specific background handling here if needed
}