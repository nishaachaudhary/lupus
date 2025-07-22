// lib/controllers/chat_controller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:lupus_care/constant/images.dart';
import 'package:lupus_care/data/api/auth_service.dart';
import 'package:lupus_care/helper/storage_service.dart';
import 'package:lupus_care/views/chat_screen/firebase/firebase_chat_service.dart';
import 'package:lupus_care/views/chat_screen/firebase/firebase_model.dart';
import 'package:lupus_care/views/chat_screen/notification_api_service.dart';
import 'package:lupus_care/views/chat_screen/notification_service.dart';
import 'package:lupus_care/views/group_chat/group_chat_controller.dart';

import 'package:path_provider/path_provider.dart';

class ChatController extends GetxController {
  // Firebase service
  FirebaseChatService? _firebaseService;
  final Map<String, bool> _userOnlineStatus = {};
  final Map<String, DateTime> _userLastSeen = {};

  // Tab management
  RxInt selectedTabIndex = 0.obs;
  Timer? _onlineStatusTimer;


// Stream subscription for online status updates
  StreamSubscription? _onlineStatusSubscription;
  // Chat data
  RxList<Chat> personalChats = <Chat>[].obs;
  RxList<Chat> groupChats = <Chat>[].obs;
  RxList<Chat> filteredPersonalChats = <Chat>[].obs;
  RxList<Chat> filteredGroupChats = <Chat>[].obs;

  // Current messages
  RxList<ChatMessage> currentMessages = <ChatMessage>[].obs;

  // Search functionality
  RxString searchQuery = ''.obs;

  // Message input
  RxString messageText = ''.obs;

  // Group creation
  RxString groupName = ''.obs;
  RxString groupDescription = ''.obs;
  RxList<AppUser> allUsers = <AppUser>[].obs;
  RxList<AppUser> filteredUsers = <AppUser>[].obs;
  RxList<AppUser> selectedMembers = <AppUser>[].obs;

  // Loading states
  RxBool isLoading = false.obs;
  RxBool isSendingMessage = false.obs;
  RxBool isLoadingMessages = false.obs;
  RxBool isSearchingUsers = false.obs;

  // Current active chat
  String? currentChatId;
  Rx<Chat?> currentChat = Rx<Chat?>(null);

  // Stream subscriptions
  StreamSubscription? _chatsSubscription;
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _authStateSubscription;

  // Connection status
  RxBool isConnected = true.obs;
  RxString connectionStatus = 'Connected'.obs;

  // Image picker
  final ImagePicker _picker = ImagePicker();

  // Initialization control
  bool _isInitialized = false;
  Timer? _initTimer;

  // Silent mode - prevents popups
  bool _silentMode = true;

  RxBool isCreatingChat = false.obs;

  // Track if we're in the initial setup phase
  RxBool isInitialSetup = true.obs;

  // Store the actual user data
  Map<String, dynamic>? _currentUserData;
  String? _consistentUserId;


  @override
  @override
  void onInit() {
    super.onInit();
    print('🎮 ChatController.onInit() called');

    isInitialSetup.value = true;
    startOnlineStatusUpdates();

    _initTimer = Timer(Duration(milliseconds: 500), () {
      // ENSURE NotificationService is initialized FIRST
      _ensureNotificationServiceRegistration().then((_) {
        _initializeNotificationService().then((_) {
          initializeWithEnhancedRealTime().then((_) {
            Future.delayed(Duration(milliseconds: 1000), () {
              markInitialSetupComplete();
            });
          });
        });
      });
    });
  }

// NEW: Ensure NotificationService is registered
  Future<void> _ensureNotificationServiceRegistration() async {
    try {
      if (!Get.isRegistered<NotificationService>()) {
        print('⚠️ NotificationService not registered, creating now...');
        final notificationService = NotificationService();
        await notificationService.onInit();
        Get.put(notificationService, permanent: true);
        print('✅ NotificationService registered successfully');
      } else {
        print('✅ NotificationService already registered');
      }
    } catch (e) {
      print('❌ Error ensuring NotificationService registration: $e');
    }
  }



  Future<void> initializeWithFullChatSupport() async {
    try {
      print('🚀 Initializing with full chat support...');

      // Step 1: Basic initialization
      await _safeInitializeFirebase();

      // Step 2: Enhanced Firebase services
      await _initializeFirebaseServicesEnhanced();

      // Step 3: Load chats with API user support
      await _loadChatsWithApiUserSupport();

      // Step 4: Setup notification listener for real-time sync
      _setupChatNotificationListener();

      // Step 5: Mark initialization as complete
      markInitialSetupComplete();

      print('✅ Full chat support initialization completed');

    } catch (e) {
      print('❌ Error initializing with full chat support: $e');
      _handleOfflineMode();
    }
  }

  void _setupEnhancedOnlineStatusUpdates() {
    try {
      print('🟢 Setting up enhanced online status updates...');

      _updateOwnOnlineStatus(true);

      _onlineStatusTimer?.cancel();
      _onlineStatusTimer = Timer.periodic(Duration(seconds: 30), (timer) {
        _updateOwnOnlineStatus(true);
        _syncWithApiUserStatuses(); // NEW: Sync with API user statuses
      });

      print('✅ Enhanced online status updates started');
    } catch (e) {
      print('❌ Error starting enhanced online status updates: $e');
    }
  }

// NEW: Sync online status with API users
  Future<void> _syncWithApiUserStatuses() async {
    try {
      // Get all chats with API users
      final allChats = [...personalChats, ...groupChats];
      final apiUserIds = <String>{};

      for (var chat in allChats) {
        for (var participant in chat.participants) {
          if (participant.startsWith('app_user_') && participant != _consistentUserId) {
            apiUserIds.add(participant);
          }
        }
      }

      if (apiUserIds.isEmpty) return;

      print('🔄 Syncing online status for ${apiUserIds.length} API users');

      // Update online status in Firebase for API users
      final batch = FirebaseFirestore.instance.batch();

      for (String consistentId in apiUserIds) {
        // Extract API ID from consistent ID
        final apiId = consistentId.replaceFirst('app_user_', '');


        final userRef = FirebaseFirestore.instance.collection('users').doc(consistentId);
        batch.update(userRef, {
          'lastSeen': FieldValue.serverTimestamp(),
          'syncedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

    } catch (e) {
      print('❌ Error syncing API user statuses: $e');
    }
  }

  bool _validateEnhancedChatData(Map<String, dynamic> data, String docId) {
    try {
      // Check required fields
      if (data['participants'] == null || !(data['participants'] is List)) {
        print('❌ Chat $docId: Invalid participants field');
        return false;
      }

      final participants = List<String>.from(data['participants']);
      if (participants.isEmpty) {
        print('❌ Chat $docId: Empty participants list');
        return false;
      }

      // CRITICAL: Check if current user is in participants (in any format)
      bool currentUserFound = false;

      for (String participantId in participants) {
        if (participantId == _consistentUserId) {
          currentUserFound = true;
          break;
        }
        // Also check if this might be our user in a different format
        if (participantId.contains(_currentUserData?['id']?.toString() ?? '')) {
          currentUserFound = true;
          break;
        }
      }

      if (!currentUserFound) {
        print('⚠️ Chat $docId: Current user not in participants: $participants');
        print('   Current user ID: $_consistentUserId');
        return false;
      }

      // Additional validation for personal chats
      if (data['isGroup'] != true && participants.length != 2) {
        print('❌ Chat $docId: Personal chat should have exactly 2 participants, has: ${participants.length}');
      }

      return true;

    } catch (e) {
      print('❌ Error validating chat data for $docId: $e');
      return false;
    }
  }

// CRITICAL FIXES for Real-time Personal Chat Updates

// 1. REPLACE your setupEnhancedRealTimeListener method with this enhanced version:
  Future<void> setupEnhancedRealTimeListener() async {
    try {
      print('👂 Setting up ENHANCED real-time listener...');
      print('   Current user ID: $_consistentUserId');

      if (_consistentUserId == null) {
        print('❌ No user ID for real-time listener');
        return;
      }

      _chatsSubscription?.cancel();

      // CRITICAL: Create multiple listeners for different user ID formats
      await _setupMultiFormatRealTimeListener();

      print('✅ Enhanced real-time listener established');

    } catch (e) {
      print('❌ Error setting up enhanced real-time listener: $e');
    }
  }

// 2. NEW: Multi-format real-time listener to catch all possible user ID formats
  Future<void> _setupMultiFormatRealTimeListener() async {
    try {
      final userEmail = _currentUserData?['email']?.toString() ?? '';
      final userId = _currentUserData?['id']?.toString() ?? '';

      // Create all possible user ID formats this user might be referenced as
      final possibleUserIds = <String>{
        _consistentUserId!,
        if (userEmail.isNotEmpty) userEmail,
        if (userId.isNotEmpty) userId,
        if (userId.isNotEmpty) 'app_user_$userId',
      }.toList();

      print('🔍 Setting up listeners for user IDs: $possibleUserIds');

      // Set up the primary listener for the consistent user ID
      _chatsSubscription = FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: _consistentUserId!)
          .snapshots()
          .listen(
            (snapshot) => _handleRealTimeUpdate(snapshot, 'primary'),
        onError: (error) => _handleListenerError(error, 'primary'),
      );

      // CRITICAL: Set up additional listeners for other user ID formats
      for (int i = 0; i < possibleUserIds.length; i++) {
        final userId = possibleUserIds[i];
        if (userId != _consistentUserId) {
          print('🔍 Setting up secondary listener for: $userId');

          FirebaseFirestore.instance
              .collection('chats')
              .where('participants', arrayContains: userId)
              .snapshots()
              .listen(
                (snapshot) => _handleRealTimeUpdate(snapshot, 'secondary-$i'),
            onError: (error) => _handleListenerError(error, 'secondary-$i'),
          );
        }
      }

      print('✅ Multi-format real-time listeners established');

    } catch (e) {
      print('❌ Error setting up multi-format listeners: $e');
    }
  }

  void _handleRealTimeUpdate(QuerySnapshot snapshot, String listenerType) async {
    try {
      print('📨 Real-time update from $listenerType: ${snapshot.docs.length} chats');

      final chats = <Chat>[];
      final processedChatIds = <String>{};

      for (var doc in snapshot.docs) {
        try {
          final chatId = doc.id;

          // Skip if already processed (deduplication)
          if (processedChatIds.contains(chatId)) {
            continue;
          }
          processedChatIds.add(chatId);

          final data = doc.data() as Map<String, dynamic>;

          if (_validateEnhancedChatData(data, chatId)) {
            // CRITICAL: Only process chats that have messages or are groups
            final isGroup = data['isGroup'] == true;

            if (isGroup) {
              // Groups are always processed
              final migratedData = await _migrateChatDataIfNeeded(chatId, data);
              final chat = _createChatFromFirestoreDataEnhanced(chatId, migratedData);
              chats.add(chat);
            } else {
              // For personal chats, check if they have messages
              final hasMessages = await _chatHasMessages(chatId);

              if (hasMessages) {
                final migratedData = await _migrateChatDataIfNeeded(chatId, data);
                final chat = _createChatFromFirestoreDataEnhanced(chatId, migratedData);
                chats.add(chat);
                print('✅ Added personal chat with messages: $chatId');
              } else {
                print('⚠️ Skipping personal chat without messages: $chatId');
              }
            }
          }
        } catch (e) {
          print('❌ Error parsing real-time chat ${doc.id}: $e');
        }
      }

      // Force update the chat lists
      _forceUpdateChatListsWithDeduplication(chats);

    } catch (e) {
      print('❌ Error handling real-time update: $e');
    }
  }

  Future<String?> findExistingPersonalChatWithMessages(String apiUserId) async {
    try {
      print('🔍 Looking for existing personal chat with messages for API user: $apiUserId');

      if (_consistentUserId == null) return null;

      final otherUserConsistentId = 'app_user_$apiUserId';

      // Search in Firebase for existing chat
      final existingChatQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: _consistentUserId!)
          .where('isGroup', isEqualTo: false)
          .get();

      for (var doc in existingChatQuery.docs) {
        final docParticipants = List<String>.from(doc.data()['participants'] ?? []);

        // Check if this chat contains both users
        if (docParticipants.contains(_consistentUserId!) &&
            (docParticipants.contains(otherUserConsistentId) ||
                docParticipants.contains(apiUserId))) {

          // CRITICAL: Check if chat has any messages
          final messagesSnapshot = await FirebaseFirestore.instance
              .collection('chats')
              .doc(doc.id)
              .collection('messages')
              .limit(1)
              .get();

          if (messagesSnapshot.docs.isNotEmpty) {
            print('✅ Found existing chat with messages: ${doc.id}');
            return doc.id;
          } else {
            print('⚠️ Found chat without messages, ignoring: ${doc.id}');
          }
        }
      }

      print('❌ No existing chat with messages found');
      return null;
    } catch (e) {
      print('❌ Error finding existing personal chat with messages: $e');
      return null;
    }
  }

  Future<bool> _chatHasMessages(String chatId) async {
    try {
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .limit(1)
          .get();

      return messagesSnapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking if chat has messages: $e');
      return false; // Default to false for safety
    }
  }


  Future<void> sendMessageWithApiNotifications() async {
    if (messageText.value.trim().isEmpty || currentChatId == null) return;

    final message = messageText.value.trim();
    messageText.value = ''; // Clear input immediately

    try {
      print('📤 Sending message with API notifications...');
      isSendingMessage.value = true;

      // Check if current chat is temporary (needs Firebase creation)
      // final isTemporaryChat = currentChat.value?.isTemporary == true || currentChatId!.startsWith('temp_');

      String actualChatId = currentChatId!;


      // Create message object
      final chatMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        chatId: actualChatId,
        senderId: currentUserId ?? 'unknown',
        senderName: currentUserName ?? 'Unknown User',
        text: message,
        timestamp: DateTime.now(),
        type: MessageType.text,
        readBy: [currentUserId ?? ''],
      );

      print('📤 Sending message with API notifications...123');
      // STEP 1: Add to local messages immediately for instant display
      currentMessages.add(chatMessage);
      currentMessages.refresh();

      // STEP 2: Update local chat list immediately (optimistic update)
      await _updateLocalChatImmediately(actualChatId, message);

      // STEP 3: Send to Firestore
      await _sendMessageToFirestore(chatMessage);

      // STEP 4: Send API notifications
      await _sendApiNotificationsForMessage(chatMessage);

      // STEP 5: If this was a temporary chat, add to personal chats list


      print('✅ Message sent with API notifications successfully');

    } catch (e) {
      print('❌ Error sending message with API notifications: $e');

      // Remove message from local list if Firestore failed
      currentMessages.removeWhere((msg) => msg.text == message &&
          msg.timestamp.difference(DateTime.now()).inSeconds.abs() < 5);
      currentMessages.refresh();

      Get.snackbar('Error', 'Failed to send message: ${e.toString()}',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isSendingMessage.value = false;
    }
  }

  /// Send API notifications for a message
  Future<void> _sendApiNotificationsForMessage(ChatMessage message) async {
    try {
      if (currentChat.value == null || _consistentUserId == null) {
        print('⚠️ No current chat or user ID for API notifications');
        return;
      }

      print('📡 Sending API notifications for message...');

      final chat = currentChat.value!;
      final isGroupChat = chat.isGroup;

      if (isGroupChat) {
        // Send group chat notification
        await _sendGroupChatApiNotification(message, chat);
      } else {
        // Send personal chat notification
        await _sendPersonalChatApiNotification(message, chat);
      }

    } catch (e) {
      print('❌ Error sending API notifications: $e');
      // Don't throw error here as the message was already sent successfully
    }
  }

  /// Send group chat API notification
  Future<void> _sendGroupChatApiNotification(ChatMessage message, Chat chat) async {
    try {
      print('👥 Sending group chat API notification...');

      // Extract API group ID
      String? apiGroupId;

      // Try to get API group ID from various sources
      if (chat.apiGroupId != null && chat.apiGroupId!.isNotEmpty) {
        apiGroupId = chat.apiGroupId;
      } else {
        // Try to extract from chat ID or other sources
        apiGroupId = chat.id;
      }

      if (apiGroupId == null || apiGroupId.isEmpty) {
        print('❌ Could not determine API group ID for notification');
        return;
      }

      // Extract API sender ID (remove 'app_user_' prefix if present)
      final apiSenderId = NotificationApiService.extractApiUserId(_consistentUserId!);

      print('   API Sender ID: $apiSenderId');
      print('   API Group ID: $apiGroupId');
      print('   Message: ${message.text}');

      // Send group notification via API
      final result = await NotificationApiService.sendGroupChatNotification(
        senderId: apiSenderId,
        groupId: apiGroupId,
        message: message.text,
      );

      if (result['success'] == true) {
        print('✅ Group chat API notification sent successfully');
      } else {
        print('❌ Group chat API notification failed: ${result['message']}');
      }

    } catch (e) {
      print('❌ Error sending group chat API notification: $e');
    }
  }


  /// Send personal chat API notification
  Future<void> _sendPersonalChatApiNotification(ChatMessage message, Chat chat) async {
    try {
      print('💬 Sending personal chat API notification...');

      // Find the other participant (receiver)
      String? otherParticipantId;
      for (String participantId in chat.participants) {
        if (participantId != _consistentUserId) {
          otherParticipantId = participantId;
          break;
        }
      }

      if (otherParticipantId == null) {
        print('❌ Could not find other participant for notification');
        return;
      }

      // Extract API user IDs
      final apiSenderId = NotificationApiService.extractApiUserId(_consistentUserId!);
      final apiReceiverId = NotificationApiService.extractApiUserId(otherParticipantId);

      print('   API Sender ID: $apiSenderId');
      print('   API Receiver ID: $apiReceiverId');
      print('   Message: ${message.text}');

      // Send personal notification via API
      final result = await NotificationApiService.sendChatNotification(
        senderId: apiSenderId,
        receiverId: apiReceiverId,
        message: message.text,
      );

      if (result['success'] == true) {
        print('✅ Personal chat API notification sent successfully');
      } else {
        print('❌ Personal chat API notification failed: ${result['message']}');
      }

    } catch (e) {
      print('❌ Error sending personal chat API notification: $e');
    }
  }

  /// Enhanced image sending with API notifications
  Future<void> sendImageWithApiNotifications() async {
    try {
      print('📷 Sending image with API notifications...');

      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image != null) {
        isSendingMessage.value = true;

        // Process and send image as base64
        await _processAndSendImageWithApiNotifications(File(image.path));
      }
    } catch (e) {
      print('❌ Error sending image with API notifications: $e');
      Get.snackbar('Error', 'Failed to send image: ${e.toString()}',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  /// Process and send image with API notifications
  Future<void> _processAndSendImageWithApiNotifications(File imageFile) async {
    try {
      if (currentChatId == null || currentChatId!.isEmpty) {
        throw Exception('No active chat selected');
      }

      if (!await imageFile.exists()) {
        throw Exception('Image file not found');
      }

      final Uint8List imageBytes = await imageFile.readAsBytes();
      if (imageBytes.length > 800000) {
        throw Exception('Image too large (${(imageBytes.length / 1024).toInt()}KB). Please choose a smaller image.');
      }

      final String base64Image = base64Encode(imageBytes);
      final String imageDataUri = 'data:image/jpeg;base64,$base64Image';

      // Create message with image
      final message = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        chatId: currentChatId!,
        senderId: currentUserId ?? 'unknown',
        senderName: currentUserName ?? 'Unknown User',
        text: '📷 Image',
        timestamp: DateTime.now(),
        type: MessageType.image,
        imageUrl: imageDataUri,
        readBy: [currentUserId ?? ''],
        fileSize: imageBytes.length,
        mimeType: 'image/jpeg',
      );

      // Add to local messages
      currentMessages.add(message);
      currentMessages.refresh();

      // Send to Firestore
      await _sendMessageToFirestore(message);

      // Update local chat
      await _updateLocalChatAfterMessage(currentChatId!, '📷 Image');

      // Send API notifications for image
      await _sendApiNotificationsForMessage(message);

      print('✅ Image sent with API notifications successfully');

      Get.snackbar(
        'Success',
        'Image sent successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 2),
      );

    } catch (e) {
      print('❌ Error processing image with API notifications: $e');

      String userMessage = 'Failed to send image';
      if (e.toString().contains('too large')) {
        userMessage = e.toString();
      } else if (e.toString().contains('No active chat')) {
        userMessage = 'Please select a chat first';
      } else if (e.toString().contains('not found')) {
        userMessage = 'Image file not found. Please try again.';
      }

      Get.snackbar('Error', userMessage,
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isSendingMessage.value = false;
    }
  }

  /// Test API notifications
  Future<void> testApiNotifications() async {
    try {
      print('🧪 Testing API notifications...');

      if (currentChat.value == null || _consistentUserId == null) {
        print('❌ No current chat or user ID for testing');
        return;
      }

      final chat = currentChat.value!;
      final testMessage = "Test notification at ${DateTime.now().toLocal()}";

      // Test based on chat type
      if (chat.isGroup) {
        print('🧪 Testing group notification...');

        final apiSenderId = NotificationApiService.extractApiUserId(_consistentUserId!);
        final apiGroupId = chat.apiGroupId ?? chat.id;

        final result = await NotificationApiService.sendGroupChatNotification(
          senderId: apiSenderId,
          groupId: apiGroupId,
          message: testMessage,
        );

        if (result['success'] == true) {
          Get.snackbar('Test Success', 'Group notification API test passed!',
              backgroundColor: Colors.green, colorText: Colors.white);
        } else {
          Get.snackbar('Test Failed', 'Group notification API test failed: ${result['message']}',
              backgroundColor: Colors.red, colorText: Colors.white);
        }
      } else {
        print('🧪 Testing personal notification...');

        // Find other participant
        String? otherParticipantId;
        for (String participantId in chat.participants) {
          if (participantId != _consistentUserId) {
            otherParticipantId = participantId;
            break;
          }
        }

        if (otherParticipantId == null) {
          Get.snackbar('Test Failed', 'Could not find other participant',
              backgroundColor: Colors.red, colorText: Colors.white);
          return;
        }

        final apiSenderId = NotificationApiService.extractApiUserId(_consistentUserId!);
        final apiReceiverId = NotificationApiService.extractApiUserId(otherParticipantId);

        final result = await NotificationApiService.sendChatNotification(
          senderId: apiSenderId,
          receiverId: apiReceiverId,
          message: testMessage,
        );

        if (result['success'] == true) {
          Get.snackbar('Test Success', 'Personal notification API test passed!',
              backgroundColor: Colors.green, colorText: Colors.white);
        } else {
          Get.snackbar('Test Failed', 'Personal notification API test failed: ${result['message']}',
              backgroundColor: Colors.red, colorText: Colors.white);
        }
      }

    } catch (e) {
      print('❌ Error testing API notifications: $e');
      Get.snackbar('Test Error', 'API notification test error: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }



  /// REPLACE your existing sendImage method with this enhanced version
  Future<void> sendImage() async {
    await sendImageWithApiNotifications();
  }



  Future<Map<String, dynamic>> _migrateChatDataIfNeeded(String chatId, Map<String, dynamic> data) async {
    try {
      final participants = List<String>.from(data['participants'] ?? []);
      final userEmail = _currentUserData?['email']?.toString() ?? '';
      final userId = _currentUserData?['id']?.toString() ?? '';

      bool needsMigration = false;
      final updatedParticipants = <String>[];

      // Check if migration is needed
      for (String participantId in participants) {
        if (participantId == userEmail || participantId == userId) {
          // Replace with consistent user ID
          updatedParticipants.add(_consistentUserId!);
          needsMigration = true;
          print('🔄 Migrating participant: $participantId -> $_consistentUserId');
        } else {
          updatedParticipants.add(participantId);
        }
      }

      if (needsMigration) {
        // Update participant details and unread counts
        final participantDetails = Map<String, dynamic>.from(data['participantDetails'] ?? {});
        final unreadCounts = Map<String, dynamic>.from(data['unreadCounts'] ?? {});

        // Migrate participant details
        if (participantDetails.containsKey(userEmail)) {
          participantDetails[_consistentUserId!] = participantDetails[userEmail];
          participantDetails.remove(userEmail);
        }
        if (participantDetails.containsKey(userId)) {
          participantDetails[_consistentUserId!] = participantDetails[userId];
          participantDetails.remove(userId);
        }

        // Migrate unread counts
        if (unreadCounts.containsKey(userEmail)) {
          unreadCounts[_consistentUserId!] = unreadCounts[userEmail];
          unreadCounts.remove(userEmail);
        }
        if (unreadCounts.containsKey(userId)) {
          unreadCounts[_consistentUserId!] = unreadCounts[userId];
          unreadCounts.remove(userId);
        }

        // Update Firestore document
        await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
          'participants': updatedParticipants,
          'participantDetails': participantDetails,
          'unreadCounts': unreadCounts,
          'migratedAt': FieldValue.serverTimestamp(),
        });

        // Return updated data
        return {
          ...data,
          'participants': updatedParticipants,
          'participantDetails': participantDetails,
          'unreadCounts': unreadCounts,
        };
      }

      return data;
    } catch (e) {
      print('❌ Error migrating chat data: $e');
      return data;
    }
  }

// 5. ENHANCED: Force update with deduplication
  void _forceUpdateChatListsWithDeduplication(List<Chat> newChats) {
    try {
      print('🔄 Force updating chat lists with deduplication...');

      // Get existing chat IDs to prevent duplicates
      final existingPersonalIds = personalChats.map((c) => c.id).toSet();
      final existingGroupIds = groupChats.map((c) => c.id).toSet();

      // Combine new chats with existing, removing duplicates
      final allPersonalChats = <Chat>[];
      final allGroupChats = <Chat>[];

      // Add existing chats first
      allPersonalChats.addAll(personalChats.where((c) => !c.isGroup));
      allGroupChats.addAll(groupChats.where((c) => c.isGroup));

      // Add new chats, avoiding duplicates
      for (final chat in newChats) {
        if (chat.isGroup) {
          if (!existingGroupIds.contains(chat.id)) {
            allGroupChats.add(chat);
            print('➕ Added new group chat: ${chat.name}');
          } else {
            // Update existing group chat
            final index = allGroupChats.indexWhere((c) => c.id == chat.id);
            if (index >= 0) {
              allGroupChats[index] = chat;
              print('🔄 Updated group chat: ${chat.name}');
            }
          }
        } else {
          if (!existingPersonalIds.contains(chat.id)) {
            allPersonalChats.add(chat);
            print('➕ Added new personal chat: ${chat.getDisplayName(_consistentUserId)}');
          } else {
            // Update existing personal chat
            final index = allPersonalChats.indexWhere((c) => c.id == chat.id);
            if (index >= 0) {
              allPersonalChats[index] = chat;
              print('🔄 Updated personal chat: ${chat.getDisplayName(_consistentUserId)}');
            }
          }
        }
      }

      // Sort by last message timestamp (newest first)
      allPersonalChats.sort((a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp));
      allGroupChats.sort((a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp));

      print('📊 Final counts: Personal: ${allPersonalChats.length}, Groups: ${allGroupChats.length}');

      // CRITICAL: Update observable lists immediately
      personalChats.value = allPersonalChats;
      groupChats.value = allGroupChats;

      // Force immediate refresh
      personalChats.refresh();
      groupChats.refresh();

      // Update filtered lists
      _applySearchFilter();

      print('✅ Chat lists updated with deduplication');

    } catch (e) {
      print('❌ Error in force update with deduplication: $e');
    }
  }

// 6. NEW: Handle newly detected chats
  void _handleNewChatsDetected(List<String> newChatIds) {
    try {
      print('🔔 Handling ${newChatIds.length} newly detected chats');






    } catch (e) {
      print('❌ Error handling new chats: $e');
    }
  }

// 7. NEW: Enhanced error handling for listeners
  void _handleListenerError(dynamic error, String listenerType) {
    print('❌ Error in $listenerType listener: $error');

    connectionStatus.value = 'Connected (Local)';

    // Retry connection after a delay
    Timer(Duration(seconds: 5), () {
      print('🔄 Retrying $listenerType listener setup...');
      if (listenerType == 'primary') {
        setupEnhancedRealTimeListener();
      }
    });
  }

// 8. ENHANCED: Create personal chat with proper notification system
  Future<String?> createPersonalChatEnhanced(String apiUserId, String userName) async {
    if (_consistentUserId == null) {
      _showError('User not authenticated');
      return null;
    }

    try {
      print('💬 Creating ENHANCED personal chat with: $userName (API ID: $apiUserId)');

      // Set loading states
      isLoading.value = true;
      isCreatingChat.value = true;
      isSendingMessage.value = true;

      // CRITICAL: Convert API user ID to consistent format
      final otherUserConsistentId = 'app_user_$apiUserId';
      print('👤 Other user consistent ID: $otherUserConsistentId');

      // Check if chat already exists with comprehensive search
      String? existingChatId = await _findExistingChatComprehensive(otherUserConsistentId, apiUserId);

      if (existingChatId != null) {
        print('✅ Found existing chat: $existingChatId');
        await _ensureExistingChatInLocalList(existingChatId, {});
        return existingChatId;
      }

      print('🆕 Creating new chat with $userName');

      // CRITICAL: Ensure both users have proper Firebase user documents
      await _ensureApiUserDocumentExists(apiUserId, otherUserConsistentId, userName);
      await _ensureUserDocumentExists();

      // Create new chat with CONSISTENT participant IDs
      final chatData = {
        'participants': [_consistentUserId!, otherUserConsistentId],
        'isGroup': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': 'Chat created',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSender': 'system',
        'participantDetails': {
          _consistentUserId!: {
            'id': _consistentUserId!,
            'name': _currentUserData!['full_name']?.toString() ?? 'User',
            'avatar': _currentUserData!['profile_image'] ?? CustomImage.avator,
            'isOnline': true,
            'originalApiId': _currentUserData!['id']?.toString() ?? '',
          },
          otherUserConsistentId: {
            'id': otherUserConsistentId,
            'name': userName,
            'avatar': CustomImage.avator,
            'isOnline': false,
            'originalApiId': apiUserId,
          },
        },
        'unreadCounts': {
          _consistentUserId!: 0,
          otherUserConsistentId: 0,
        },
        'chatType': 'personal',
        'realTimeSync': true,
        'apiUserMapping': {
          otherUserConsistentId: apiUserId,
        }
      };

      print('📝 Creating chat document with participants: ${chatData['participants']}');

      final docRef = await FirebaseFirestore.instance
          .collection('chats')
          .add(chatData);

      print('✅ Personal chat created successfully: ${docRef.id}');

      // CRITICAL: Send notification to other user about new chat
      await _notifyUserAboutNewPersonalChat(docRef.id, otherUserConsistentId, userName);

      // CRITICAL: Add to local list immediately
      await _addNewChatToLocalListImmediate(docRef.id, chatData);

      // Force refresh after a delay to ensure real-time sync
      Future.delayed(Duration(milliseconds: 2000), () {
        forceRefreshChats();
      });

      if (!_silentMode) {
        _showSuccess('Chat created with $userName');
      }

      return docRef.id;

    } catch (e) {
      print('❌ Error creating enhanced personal chat: $e');
      if (!_silentMode) {
        _showError('Failed to create chat: ${e.toString()}');
      }
      return null;
    } finally {
      isLoading.value = false;
      isCreatingChat.value = false;
      isSendingMessage.value = false;
    }
  }

// 9. NEW: Comprehensive existing chat search
  Future<String?> _findExistingChatComprehensive(String consistentId, String apiId) async {
    try {
      print('🔍 Comprehensive search for existing chat...');

      // Search with consistent ID
      var existingChats = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: _consistentUserId!)
          .where('isGroup', isEqualTo: false)
          .get();

      for (var doc in existingChats.docs) {
        final participants = List<String>.from(doc.data()['participants'] ?? []);

        if (participants.contains(_consistentUserId!) &&
            (participants.contains(consistentId) || participants.contains(apiId))) {
          print('✅ Found existing chat: ${doc.id}');
          return doc.id;
        }
      }

      print('❌ No existing chat found');
      return null;
    } catch (e) {
      print('❌ Error searching for existing chat: $e');
      return null;
    }
  }

// 10. NEW: Notify user about new personal chat
  Future<void> _notifyUserAboutNewPersonalChat(String chatId, String otherUserId, String otherUserName) async {
    try {
      print('🔔 Notifying user about new personal chat: $chatId');

      // Create notification document
      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
        'type': 'new_personal_chat',
        'chatId': chatId,
        'userId': otherUserId,
        'fromUserId': _consistentUserId!,
        'fromUserName': _currentUserData!['full_name']?.toString() ?? 'User',
        'message': 'You have a new message',
        'timestamp': FieldValue.serverTimestamp(),
        'processed': false,
        'forceSync': true,
      });

      print('✅ Notification sent to user: $otherUserId');

    } catch (e) {
      print('❌ Error sending new chat notification: $e');
    }
  }

// 11. ENHANCED: Notification listener for real-time chat updates
  void _setupEnhancedNotificationListener() {
    try {
      if (_consistentUserId == null) {
        print('❌ No user ID for notification listener');
        return;
      }

      print('👂 Setting up enhanced notification listener for: $_consistentUserId');

      // Listen for notifications directed to this user
      FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: _consistentUserId!)
          .where('processed', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {

        print('🔔 Received ${snapshot.docs.length} unprocessed notifications');

        for (var doc in snapshot.docs) {
          try {
            final data = doc.data();
            final type = data['type']?.toString() ?? '';

            print('🔔 Processing notification: $type');

            switch (type) {
              case 'new_personal_chat':
                _handleNewPersonalChatNotification(doc.id, data);
                break;
              case 'new_group':
                _handleNewGroupNotification(doc.id, data);
                break;
              case 'chat_message':
                _handleNewMessageNotification(doc.id, data);
                break;
            }

            // Mark notification as processed
            doc.reference.update({'processed': true, 'processedAt': FieldValue.serverTimestamp()});

          } catch (e) {
            print('❌ Error processing notification ${doc.id}: $e');
          }
        }
      }, onError: (error) {
        print('❌ Error in notification listener: $error');
      });

      print('✅ Enhanced notification listener established');

    } catch (e) {
      print('❌ Error setting up notification listener: $e');
    }
  }

// 12. NEW: Handle new personal chat notification
  Future<void> _handleNewPersonalChatNotification(String notificationId, Map<String, dynamic> data) async {
    try {
      print('📨 Handling new personal chat notification');

      final chatId = data['chatId']?.toString();
      final fromUserName = data['fromUserName']?.toString() ?? 'Someone';

      if (chatId != null) {
        // Force refresh to ensure the new chat appears
        await forceRefreshChats();


      }

      print('✅ New personal chat notification handled');
    } catch (e) {
      print('❌ Error handling new personal chat notification: $e');
    }
  }

// 13. NEW: Handle new group notification
  Future<void> _handleNewGroupNotification(String notificationId, Map<String, dynamic> data) async {
    try {
      print('📨 Handling new group notification');

      final groupId = data['groupId']?.toString();
      final groupName = data['groupName']?.toString() ?? 'Group';

      if (groupId != null) {
        await forceRefreshChats();


      }

      print('✅ New group notification handled');
    } catch (e) {
      print('❌ Error handling new group notification: $e');
    }
  }

// 14. NEW: Handle new message notification
  Future<void> _handleNewMessageNotification(String notificationId, Map<String, dynamic> data) async {
    try {
      print('📨 Handling new message notification');

      // Force refresh to ensure latest messages are shown
      await forceRefreshChats();

      print('✅ New message notification handled');
    } catch (e) {
      print('❌ Error handling new message notification: $e');
    }
  }

// 15. REPLACE your existing initializeWithEnhancedRealTime method:
  Future<void> initializeWithEnhancedRealTime() async {
    try {
      print('🚀 Initializing ChatController with ENHANCED real-time support...');

      // Step 1: Basic initialization
      await _safeInitializeFirebase();

      // Step 2: Enhanced Firebase services
      await _initializeFirebaseServicesEnhanced();

      // Step 3: Setup enhanced real-time listener with multi-format support
      await setupEnhancedRealTimeListener();

      // Step 4: Setup enhanced notification listener
      _setupEnhancedNotificationListener();

      // Step 5: Load chats with API user support
      await _loadChatsWithApiUserSupport();

      // Step 6: Initialize FCM token
      await _initializeUserFCMToken();

      // Step 7: Mark initialization as complete
      markInitialSetupComplete();

      print('✅ ENHANCED real-time ChatController initialization completed');

    } catch (e) {
      print('❌ Error initializing ChatController with enhanced real-time: $e');
      _handleOfflineMode();
    }
  }


  Future<void> sendMessageEnhanced(String messageText) async {
    if (messageText.trim().isEmpty || currentChatId == null) return;

    try {
      print('📝 Sending enhanced message...');
      isSendingMessage.value = true;

      final message = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        chatId: currentChatId!,
        senderId: currentUserId ?? 'unknown',
        senderName: currentUserName ?? 'Unknown User',
        text: messageText.trim(),
        timestamp: DateTime.now(),
        type: MessageType.text,
        readBy: [currentUserId ?? ''],
      );

      // STEP 1: Add to local messages immediately for instant display
      currentMessages.add(message);
      currentMessages.refresh();

      // STEP 2: Update local chat list immediately (optimistic update)
      await _updateLocalChatImmediately(currentChatId!, messageText.trim());

      // STEP 3: Send to Firestore (this will trigger real-time listener)
      await _sendMessageToFirestore(message);

      print('✅ Enhanced message sent successfully');

    } catch (e) {
      print('❌ Error sending enhanced message: $e');

      // Remove message from local list if Firestore failed
      currentMessages.removeWhere((msg) => msg.text == messageText.trim() &&
          msg.timestamp.difference(DateTime.now()).inSeconds.abs() < 5);
      currentMessages.refresh();

      Get.snackbar('Error', 'Failed to send message',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isSendingMessage.value = false;
    }
  }

// CRITICAL: Update local chat immediately for instant UI response
  Future<void> _updateLocalChatImmediately(String chatId, String lastMessage) async {
    try {
      print('⚡ Updating local chat immediately for instant UI response');

      final now = DateTime.now();
      final currentUser = currentUserId ?? 'unknown';

      // Find and update in personal chats
      for (int i = 0; i < personalChats.length; i++) {
        if (personalChats[i].id == chatId) {
          final originalChat = personalChats[i];
          final updatedChat = Chat(
            id: originalChat.id,
            name: originalChat.name,
            participants: originalChat.participants,
            isGroup: originalChat.isGroup,
            description: originalChat.description,
            createdBy: originalChat.createdBy,
            createdAt: originalChat.createdAt,
            lastMessage: lastMessage,
            lastMessageTimestamp: now, // Use current time for immediate update
            lastMessageSender: currentUser,
            participantDetails: originalChat.participantDetails,
            unreadCounts: originalChat.unreadCounts,
            groupImage: originalChat.groupImage,
            apiGroupId: originalChat.apiGroupId,
          );

          personalChats[i] = updatedChat;
          personalChats.refresh();

          print('✅ Updated personal chat immediately');
          break;
        }
      }

      // Find and update in group chats
      for (int i = 0; i < groupChats.length; i++) {
        if (groupChats[i].id == chatId) {
          final originalChat = groupChats[i];
          final updatedChat = Chat(
            id: originalChat.id,
            name: originalChat.name,
            participants: originalChat.participants,
            isGroup: originalChat.isGroup,
            description: originalChat.description,
            createdBy: originalChat.createdBy,
            createdAt: originalChat.createdAt,
            lastMessage: lastMessage,
            lastMessageTimestamp: now,
            lastMessageSender: currentUser,
            participantDetails: originalChat.participantDetails,
            unreadCounts: originalChat.unreadCounts,
            groupImage: originalChat.groupImage,
            apiGroupId: originalChat.apiGroupId,
          );

          groupChats[i] = updatedChat;
          groupChats.refresh();

          print('✅ Updated group chat immediately');
          break;
        }
      }

      // Update current chat if it matches
      if (currentChat.value?.id == chatId) {
        final originalChat = currentChat.value!;
        currentChat.value = Chat(
          id: originalChat.id,
          name: originalChat.name,
          participants: originalChat.participants,
          isGroup: originalChat.isGroup,
          description: originalChat.description,
          createdBy: originalChat.createdBy,
          createdAt: originalChat.createdAt,
          lastMessage: lastMessage,
          lastMessageTimestamp: now,
          lastMessageSender: currentUser,
          participantDetails: originalChat.participantDetails,
          unreadCounts: originalChat.unreadCounts,
          groupImage: originalChat.groupImage,
          apiGroupId: originalChat.apiGroupId,
        );
      }

      // Apply search filter and refresh UI
      _applySearchFilter();
      refreshChatListUI();

      print('⚡ Local chat updated immediately for instant response');

    } catch (e) {
      print('❌ Error updating local chat immediately: $e');
    }
  }

  Future<String?> findExistingPersonalChat(String apiUserId) async {
    try {
      print('🔍 Looking for existing personal chat with API user: $apiUserId');

      if (_consistentUserId == null) return null;

      final otherUserConsistentId = 'app_user_$apiUserId';

      // Search in Firebase for existing chat
      final existingChatQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: _consistentUserId!)
          .where('isGroup', isEqualTo: false)
          .get();

      for (var doc in existingChatQuery.docs) {
        final docParticipants = List<String>.from(doc.data()['participants'] ?? []);

        // Check if this chat contains both users
        if (docParticipants.contains(_consistentUserId!) &&
            (docParticipants.contains(otherUserConsistentId) ||
                docParticipants.contains(apiUserId))) {
          print('✅ Found existing chat: ${doc.id}');
          return doc.id;
        }
      }

      print('❌ No existing chat found');
      return null;
    } catch (e) {
      print('❌ Error finding existing personal chat: $e');
      return null;
    }
  }

// 3. ADD this method to create chat from existing Firebase document
  Future<Chat> createChatFromExistingFirebase(String chatId) async {
    try {
      print('🔧 Creating chat object from existing Firebase document: $chatId');

      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      if (!chatDoc.exists) {
        throw Exception('Chat document not found: $chatId');
      }

      final data = chatDoc.data()!;
      return _createChatFromFirestoreDataEnhanced(chatId, data);

    } catch (e) {
      print('❌ Error creating chat from existing Firebase: $e');
      throw e;
    }
  }

// 4. REPLACE the sendMessage method in ChatController
  Future<void> sendMessage() async {
    if (messageText.value.trim().isEmpty) return;

    final message = messageText.value.trim();
    messageText.value = '';

    await sendMessageEnhancedWithChatCreation(message);
  }

  Future<void> sendMessageEnhancedWithChatCreation(String messageText) async {
    if (messageText.trim().isEmpty || currentChatId == null) return;

    try {
      print('📝 Sending message with enhanced chat creation logic...');
      isSendingMessage.value = true;


      String actualChatId = currentChatId!;



      final message = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        chatId: actualChatId,
        senderId: currentUserId ?? 'unknown',
        senderName: currentUserName ?? 'Unknown User',
        text: messageText.trim(),
        timestamp: DateTime.now(),
        type: MessageType.text,
        readBy: [currentUserId ?? ''],
      );

      // STEP 1: Add to local messages immediately for instant display
      currentMessages.add(message);
      currentMessages.refresh();


      await _updateLocalChatImmediately(actualChatId, messageText.trim());


      await _sendMessageToFirestore(message);



      print('✅ Message sent and chat created (if needed)');

    } catch (e) {
      print('❌ Error sending message with chat creation: $e');

      // Remove message from local list if Firestore failed
      currentMessages.removeWhere((msg) => msg.text == messageText.trim() &&
          msg.timestamp.difference(DateTime.now()).inSeconds.abs() < 5);
      currentMessages.refresh();

      Get.snackbar('Error', 'Failed to send message',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isSendingMessage.value = false;
    }
  }

  Future<void> _addNewChatToPersonalChatsListAfterFirstMessage(String chatId) async {
    try {
      print('➕ Adding chat to personal list after first message: $chatId');

      // Fetch the chat document from Firebase
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      if (chatDoc.exists) {
        final data = chatDoc.data()!;
        final chat = _createChatFromFirestoreDataEnhanced(chatId, data);

        // Add to personal chats list at the beginning (newest first)
        personalChats.insert(0, chat);
        personalChats.refresh();

        // Update filtered lists
        _applySearchFilter();

        // Force UI refresh
        refreshChatListUI();

        print('✅ Chat added to personal chats list after first message');
      }

    } catch (e) {
      print('❌ Error adding chat after first message: $e');
    }
  }

// 6. ADD method to create Firebase chat for first message
  Future<String> _createFirebaseChatForFirstMessage() async {
    try {
      print('🔥 Creating Firebase chat document for first message');

      if (currentChat.value == null || _consistentUserId == null) {
        throw Exception('No current chat or user ID');
      }

      // Find the other participant
      String? otherParticipantId;
      for (String participantId in currentChat.value!.participants) {
        if (participantId != _consistentUserId) {
          otherParticipantId = participantId;
          break;
        }
      }

      if (otherParticipantId == null) {
        throw Exception('Could not find other participant');
      }

      // Get participant details
      final otherParticipant = currentChat.value!.participantDetails[otherParticipantId];
      if (otherParticipant == null) {
        throw Exception('Could not find other participant details');
      }

      // Create chat data
      final chatData = {
        'participants': [_consistentUserId!, otherParticipantId],
        'isGroup': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': 'Chat started',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSender': _consistentUserId!,
        'participantDetails': {
          _consistentUserId!: {
            'id': _consistentUserId!,
            'name': _currentUserData!['full_name']?.toString() ?? 'User',
            'avatar': _currentUserData!['profile_image'] ?? CustomImage.avator,
            'isOnline': true,
            'originalApiId': _currentUserData!['id']?.toString() ?? '',
          },
          otherParticipantId: {
            'id': otherParticipantId,
            'name': otherParticipant.name,
            'avatar': otherParticipant.avatar,
            'isOnline': otherParticipant.isOnline,
            'originalApiId': otherParticipantId.replaceFirst('app_user_', ''),
          },
        },
        'unreadCounts': {
          _consistentUserId!: 0,
          otherParticipantId: 0,
        },
        'chatType': 'personal',
        'createdOnFirstMessage': true, // Flag to indicate this was created on first message
      };

      print('📝 Creating Firebase chat document...');

      final docRef = await FirebaseFirestore.instance
          .collection('chats')
          .add(chatData);

      print('✅ Firebase chat created: ${docRef.id}');

      // Create user document for API user if needed
      final apiUserId = otherParticipantId.replaceFirst('app_user_', '');
      await _ensureApiUserDocumentExists(apiUserId, otherParticipantId, otherParticipant.name);

      return docRef.id;

    } catch (e) {
      print('❌ Error creating Firebase chat for first message: $e');
      throw e;
    }
  }

// 7. ADD method to add new chat to personal chats list
  Future<void> _addNewChatToPersonalChatsList(String chatId) async {
    try {
      print('➕ Adding new chat to personal chats list: $chatId');

      // Fetch the chat document from Firebase
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      if (chatDoc.exists) {
        final data = chatDoc.data()!;
        final chat = _createChatFromFirestoreDataEnhanced(chatId, data);

        // Add to personal chats list at the beginning (newest first)
        personalChats.insert(0, chat);
        personalChats.refresh();

        // Update filtered lists
        _applySearchFilter();

        // Force UI refresh
        refreshChatListUI();

        print('✅ New chat added to personal chats list');
      }

    } catch (e) {
      print('❌ Error adding new chat to personal chats list: $e');
    }
  }

  Future<void> _loadChatsWithApiUserSupport() async {
    print('📱 Loading chats with enhanced real-time support...');

    if (_consistentUserId == null || _currentUserData == null) {
      print('❌ No user data available for loading chats');
      _processChatData([]);
      return;
    }

    isLoading.value = true;
    connectionStatus.value = 'Loading chats...';

    try {
      // Setup the enhanced real-time listener immediately
      await setupEnhancedRealTimeListener();

      // Setup enhanced online status updates
      _setupEnhancedOnlineStatusUpdates();

      print('✅ Enhanced real-time chat loading completed');

    } catch (e) {
      print('❌ Error in enhanced real-time chat loading: $e');
      _processChatData([]);
    } finally {
      isLoading.value = false;
      connectionStatus.value = 'Connected';
    }
  }

  void _setupChatNotificationListener() {
    try {
      if (_consistentUserId == null) {
        print('❌ No user ID for notification listener');
        return;
      }

      print('👂 Setting up chat notification listener for: $_consistentUserId');

      // Listen for notifications directed to this user
      FirebaseFirestore.instance
          .collection('notifications')
          .where('toUserId', isEqualTo: _consistentUserId!)
          .where('processed', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {

        print('🔔 Received ${snapshot.docs.length} unprocessed notifications');

        for (var doc in snapshot.docs) {
          try {
            final data = doc.data();
            final type = data['type']?.toString() ?? '';

            print('🔔 Processing notification: $type');

            switch (type) {
              case 'new_personal_chat':
                // _handleNewPersonalChatNotification(doc.id, data);
                break;
              case 'new_group':
                // _handleNewGroupNotification(doc.id, data);
                break;
              case 'chat_message':
                // _handleNewMessageNotification(doc.id, data);
                break;
            }

          } catch (e) {
            print('❌ Error processing notification ${doc.id}: $e');
          }
        }
      }, onError: (error) {
        print('❌ Error in notification listener: $error');
      });

      print('✅ Chat notification listener established');

    } catch (e) {
      print('❌ Error setting up notification listener: $e');
    }
  }

  Future<void> _initializeNotificationService() async {
    try {
      if (Get.isRegistered<NotificationService>()) {
        print('✅ NotificationService already registered');
      } else {
        await Get.putAsync(() => NotificationService().onInit().then((_) => NotificationService()));
        print('✅ NotificationService initialized');
      }
    } catch (e) {
      print('❌ Error initializing NotificationService: $e');
    }
  }

  void startOnlineStatusUpdates() {
    try {
      print('🟢 Starting online status updates...');

      // Update own online status immediately
      _updateOwnOnlineStatus(true);

      // Set up periodic updates every 30 seconds
      _onlineStatusTimer = Timer.periodic(Duration(seconds: 30), (timer) {
        _updateOwnOnlineStatus(true);

      });


      print('✅ Online status updates started');
    } catch (e) {
      print('❌ Error starting online status updates: $e');
    }
  }


  Future<void> _updateOwnOnlineStatus(bool isOnline) async {
    try {
      if (_consistentUserId == null) return;

      final now = DateTime.now();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_consistentUserId!)
          .update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
      });

      // Update local cache
      _userOnlineStatus[_consistentUserId!] = isOnline;
      _userLastSeen[_consistentUserId!] = now;

      print('🟢 Updated own online status: $isOnline');
    } catch (e) {
      print('❌ Error updating own online status: $e');
    }
  }

  Future<void> onGroupImageUpdatedFromGroupController(String chatId, String newImageData) async {
    try {
      print('🔄 ChatController: Group image update notification from GroupController');
      print('   Chat ID: $chatId');
      print('   New image data type: ${newImageData.startsWith('data:image') ? 'Base64' : 'URL'}');
      print('   Image data length: ${newImageData.length}');

      // Update local chat data immediately using comprehensive method
      await _updateLocalChatGroupImageComprehensive(chatId, newImageData);

      // Force refresh chat lists UI
      refreshChatListUI();

      print('✅ ChatController: Group image sync from GroupController completed');

    } catch (e) {
      print('❌ ChatController: Error syncing group image from GroupController: $e');
    }
  }


  Future<void> updateGroupImageFromController(String groupId, String newImageData) async {
    try {
      print('📞 ChatController: Received group image update from GroupController');
      print('   Group ID: $groupId');
      print('   Image type: ${_getImageType(newImageData)}');

      // Use the comprehensive update method
      await _updateLocalChatGroupImageComprehensive(groupId, newImageData);

      // Verify the update was successful
      await _verifyGroupImageUpdate(groupId, newImageData);

      print('✅ ChatController: Group image update from GroupController completed');

    } catch (e) {
      print('❌ ChatController: Error updating group image from GroupController: $e');
    }
  }

// Helper method to verify group image update
  Future<void> _verifyGroupImageUpdate(String groupId, String expectedImageData) async {
    try {
      print('🔍 Verifying group image update...');

      // Check if the update was successful
      final allChats = [...personalChats, ...groupChats];
      bool found = false;

      for (var chat in allChats) {
        if (chat.id == groupId || chat.apiGroupId == groupId ||
            (chat.isGroup && chat.name.isNotEmpty)) {

          final currentImage = chat.groupImage ?? '';
          if (currentImage == expectedImageData) {
            found = true;
            print('✅ Group image update verification successful');
            break;
          } else {
            print('⚠️ Group image mismatch detected');

          }
        }
      }

      if (!found) {
        print('❌ Group image update verification failed - forcing refresh');
        await forceRefreshChatsWithGroupImages();
      }

    } catch (e) {
      print('❌ Error verifying group image update: $e');
    }
  }

// Method to debug group image issues
  void debugGroupImages() {
    print('🔍 =================== GROUP IMAGE DEBUG ===================');

    final allChats = [...personalChats, ...groupChats];
    final groupChatsOnly = allChats.where((chat) => chat.isGroup).toList();

    print('📊 Total chats: ${allChats.length}');
    print('📊 Group chats: ${groupChatsOnly.length}');

    for (var chat in groupChatsOnly) {
      print('👥 Group: ${chat.name} (${chat.id})');
      print('   - Has group image: ${chat.groupImage != null && chat.groupImage!.isNotEmpty}');
      if (chat.groupImage != null && chat.groupImage!.isNotEmpty) {
        print('   - Image type: ${_getImageType(chat.groupImage)}');
        print('   - Image length: ${chat.groupImage!.length}');

      }
      print('   - API Group ID: ${chat.apiGroupId}');
      print('   - Participants: ${chat.participants.length}');
    }

    print('🔍 =================== END GROUP IMAGE DEBUG ===================');
  }

  Future<void> _safeInitializeFirebase() async {
    if (_isInitialized) {
      print('✅ ChatController already initialized');
      return;
    }

    try {
      print('🔍 ChatController: Checking Firebase availability...');

      // Get current user data from storage
      _currentUserData = StorageService.to.getUser();
      if (_currentUserData == null) {
        print('❌ No user data in storage');
        _handleOfflineMode();
        return;
      }

      // Generate consistent user ID
      _consistentUserId = _generateConsistentUserId(_currentUserData!);
      print('👤 Current user: ${_currentUserData!['email']} (ID: $_consistentUserId)');

      // Verify Firebase is initialized
      try {
        final app = Firebase.app();
        print('✅ Firebase app available: ${app.name}');
      } catch (e) {
        print('⚠️ Firebase not initialized, using offline mode: $e');
        _handleOfflineMode();
        return;
      }

      await _initializeFirebaseServices();
      _isInitialized = true;
      print('✅ ChatController initialization completed');

    } catch (e) {
      print('❌ ChatController initialization failed: $e');
      _handleOfflineMode();
    }
  }

  // Generate consistent user ID across sessions
  String _generateConsistentUserId(Map<String, dynamic> userData) {
    final userId = userData['id']?.toString() ?? '';
    final email = userData['email']?.toString() ?? '';

    if (userId.isNotEmpty) {
      return 'app_user_$userId';
    } else if (email.isNotEmpty) {
      // Fallback to email-based ID if no user ID
      return 'app_user_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
    } else {
      // Last resort - generate from current timestamp but store it
      final fallbackId = 'app_user_${DateTime.now().millisecondsSinceEpoch}';
      print('⚠️ Generated fallback user ID: $fallbackId');
      return fallbackId;
    }
  }

  void _handleOfflineMode() {
    print('📱 Running in offline mode');
    isConnected.value = true;
    connectionStatus.value = 'Connected (Local)';
    _isInitialized = true;

    // Load any locally stored chats
    _loadLocalChats();
  }

  // Load locally stored chats (for offline mode)
  void _loadLocalChats() {
    try {
      // You can implement local storage of chats here if needed
      personalChats.clear();
      groupChats.clear();
      _applySearchFilter();
      print('📱 Local chats loaded (empty for now)');
    } catch (e) {
      print('❌ Error loading local chats: $e');
    }
  }

  Future<void> _initializeFirebaseServices() async {
    try {
      print('🔥 ChatController: Initializing Firebase services...');
      connectionStatus.value = 'Connecting to Firebase...';
      isLoading.value = true;

      await _setupFirebaseChatService();
      await _authenticateWithFirebase();
      await _migrateExistingChats(); // NEW: Migrate old chats
      _setupAuthenticationListener();

      print('✅ ChatController: Firebase services initialized');

    } catch (e) {
      print('❌ ChatController: Firebase services initialization failed: $e');
      _handleOfflineMode();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _setupFirebaseChatService() async {
    try {
      print('🔧 Setting up Firebase Chat Service...');

      if (Get.isRegistered<FirebaseChatService>()) {
        _firebaseService = Get.find<FirebaseChatService>();
        print('✅ Found existing FirebaseChatService');
      } else {
        _firebaseService = FirebaseChatService.instance;
        Get.put<FirebaseChatService>(_firebaseService!, permanent: true);
        print('✅ Created new FirebaseChatService');
      }

      if (_firebaseService == null) {
        throw Exception('Failed to initialize FirebaseChatService');
      }

    } catch (e) {
      print('❌ Error setting up Firebase Chat Service: $e');
      rethrow;
    }
  }

  // Enhanced Firebase authentication with proper user management
  Future<void> _authenticateWithFirebase() async {
    try {
      print('🔐 Authenticating with Firebase...');

      if (_currentUserData == null || _consistentUserId == null) {
        throw Exception('No user data available');
      }

      final userName = _currentUserData!['full_name']?.toString() ?? 'User';
      final userEmail = _currentUserData!['email']?.toString() ?? '';

      connectionStatus.value = 'Authenticating...';

      // Check if user is already signed in
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        print('✅ Firebase user already authenticated: ${currentUser.uid}');
        await _ensureUserDocumentExists();
        await _loadChats();
        return;
      }

      // Sign in anonymously (we'll manage the user identity through Firestore)
      UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();

      if (userCredential.user != null) {
        print('✅ Firebase authentication successful: ${userCredential.user!.uid}');

        // Create/update user document with consistent ID
        await _ensureUserDocumentExists();

        isConnected.value = true;
        connectionStatus.value = 'Connected';
        await _loadChats();
      } else {
        throw Exception('Failed to authenticate with Firebase');
      }

    } catch (e) {
      print('❌ Firebase authentication failed: $e');
      _handleOfflineMode();
    }
  }

  // NEW: Migrate existing chats to new user ID format
  Future<void> _migrateExistingChats() async {
    try {
      print('🔄 Checking for existing chats to migrate...');

      if (_currentUserData == null || _consistentUserId == null) {
        return;
      }

      final userEmail = _currentUserData!['email']?.toString() ?? '';
      if (userEmail.isEmpty) return;

      // Look for chats with old email-based participants or anonymous IDs
      final chatsQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: userEmail)
          .get();

      if (chatsQuery.docs.isNotEmpty) {
        print('🔄 Found ${chatsQuery.docs.length} chats to potentially migrate');

        for (var doc in chatsQuery.docs) {
          await _migrateChatDocument(doc);
        }
      }

      print('✅ Chat migration check completed');
    } catch (e) {
      print('❌ Error during chat migration: $e');
      // Don't block the process, continue anyway
    }
  }



  /// Check if group image is base64
  bool isGroupImageBase64(Chat chat) {
    if (!chat.isGroup) return false;

    final groupImage = chat.groupImage;
    return groupImage != null && groupImage.startsWith('data:image');
  }



  Future<void> _updateLocalChatGroupImageEnhanced(String chatId, String newImageData) async {
    try {
      print('🔄 Enhanced local chat group image update...');
      print('   Target chat ID: $chatId');
      print('   Current personalChats count: ${personalChats.length}');
      print('   Current groupChats count: ${groupChats.length}');

      bool foundAndUpdated = false;

      // Search and update in personal chats
      for (int i = 0; i < personalChats.length; i++) {
        final chat = personalChats[i];

        // Check multiple possible ID matches
        if (chat.id == chatId ||
            chat.apiGroupId == chatId ||
            (chat.isGroup && chat.name.isNotEmpty && _matchesGroupName(chat, newImageData))) {

          print('🎯 Found matching chat in personalChats at index $i');
          print('   Chat ID: ${chat.id}');
          print('   API Group ID: ${chat.apiGroupId}');
          print('   Is Group: ${chat.isGroup}');
          print('   Chat Name: ${chat.name}');

          // Create updated chat with new image
          final updatedChat = _createChatWithUpdatedImage(chat, newImageData);
          personalChats[i] = updatedChat;
          foundAndUpdated = true;

          print('✅ Updated chat in personalChats');
          break;
        }
      }

      // Search and update in group chats
      for (int i = 0; i < groupChats.length; i++) {
        final chat = groupChats[i];

        // Check multiple possible ID matches
        if (chat.id == chatId ||
            chat.apiGroupId == chatId ||
            (chat.isGroup && chat.name.isNotEmpty && _matchesGroupName(chat, newImageData))) {

          print('🎯 Found matching chat in groupChats at index $i');
          print('   Chat ID: ${chat.id}');
          print('   API Group ID: ${chat.apiGroupId}');
          print('   Is Group: ${chat.isGroup}');
          print('   Chat Name: ${chat.name}');

          // Create updated chat with new image
          final updatedChat = _createChatWithUpdatedImage(chat, newImageData);
          groupChats[i] = updatedChat;
          foundAndUpdated = true;

          print('✅ Updated chat in groupChats');
          break;
        }
      }

      // Update current chat if it's the same group
      if (currentChat.value != null) {
        final currentChatValue = currentChat.value!;
        if (currentChatValue.id == chatId ||
            currentChatValue.apiGroupId == chatId ||
            (currentChatValue.isGroup && _matchesGroupName(currentChatValue, newImageData))) {

          final updatedCurrentChat = _createChatWithUpdatedImage(currentChatValue, newImageData);
          currentChat.value = updatedCurrentChat;
          foundAndUpdated = true;

          print('✅ Updated current chat');
        }
      }

      if (foundAndUpdated) {
        // Force refresh all reactive lists
        personalChats.refresh();
        groupChats.refresh();

        // Apply search filters to update filtered lists
        _applySearchFilter();

        // Force UI update
        update();

        print('✅ Local chat data updated and UI refreshed');
      } else {
        print('⚠️ No matching chat found for ID: $chatId');
        print('⚠️ This might indicate a ChatID mismatch or the chat hasn\'t been loaded yet');

        // Force a complete refresh as fallback
        print('🔄 Forcing complete chat refresh as fallback...');
        await forceRefreshChats();
      }

    } catch (e) {
      print('❌ Error in enhanced local chat update: $e');
    }
  }

  // Helper method to check if chat matches by name (fallback identification)
  bool _matchesGroupName(Chat chat, String newImageData) {
    // This is a fallback method in case IDs don't match
    // You can implement additional logic here based on your group naming patterns
    return false; // Implement if needed
  }

  // ENHANCED: Create chat with updated image
  Chat _createChatWithUpdatedImage(Chat originalChat, String newImageData) {
    try {
      print('🔧 Creating updated chat with new image...');
      print('   Original image: ${originalChat.groupImage?.substring(0, 50) ?? 'None'}...');
      print('   New image: ${newImageData.substring(0, 50)}...');

      return Chat(
        id: originalChat.id,
        name: originalChat.name,
        participants: originalChat.participants,
        isGroup: originalChat.isGroup,
        description: originalChat.description,
        createdBy: originalChat.createdBy,
        createdAt: originalChat.createdAt,
        lastMessage: originalChat.lastMessage,
        lastMessageTimestamp: originalChat.lastMessageTimestamp,
        lastMessageSender: originalChat.lastMessageSender,
        participantDetails: originalChat.participantDetails,
        unreadCounts: originalChat.unreadCounts,
        groupImage: newImageData, // Update the group image
        apiGroupId: originalChat.apiGroupId, // Preserve API group ID if exists
      );
    } catch (e) {
      print('❌ Error creating updated chat with image: $e');
      // Return original chat if update fails
      return originalChat;
    }
  }

  // NEW: Verify Firestore has the updated image
  Future<void> _verifyFirestoreImageUpdate(String chatId, String expectedImageData) async {
    try {
      print('🔍 Verifying Firestore has updated image...');

      // Wait a moment for Firestore to propagate
      await Future.delayed(Duration(milliseconds: 500));

      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      if (chatDoc.exists && chatDoc.data() != null) {
        final data = chatDoc.data()!;
        final firestoreImage = data['groupImage']?.toString() ?? '';

        if (firestoreImage == expectedImageData) {
          print('✅ Firestore image matches expected data');
        } else {
          print('⚠️ Firestore image mismatch!');
          print('   Expected: ${expectedImageData.substring(0, 50)}...');
          print('   Got: ${firestoreImage.substring(0, 50)}...');

          // If mismatch, we might need to wait longer or there's an issue
          await Future.delayed(Duration(milliseconds: 1000));

          // Try one more time
          final retryDoc = await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .get();

          if (retryDoc.exists && retryDoc.data() != null) {
            final retryData = retryDoc.data()!;
            final retryImage = retryData['groupImage']?.toString() ?? '';

            if (retryImage == expectedImageData) {
              print('✅ Firestore image matched on retry');
            } else {
              print('❌ Firestore image still doesn\'t match after retry');
            }
          }
        }
      } else {
        print('❌ Chat document not found in Firestore');
      }

    } catch (e) {
      print('❌ Error verifying Firestore image update: $e');
    }
  }

  // ENHANCED: Update group image in chat list (direct method)
  Future<void> updateGroupImageInChatList(String groupId, String newImageUrl) async {
    try {
      print('🔄 Direct update: Group image in chat list...');
      print('   Group ID: $groupId');
      print('   New Image type: ${_getImageType(newImageUrl)}');

      // Force update using our enhanced method
      await _updateLocalChatGroupImageEnhanced(groupId, newImageUrl);

      // Double-check by refreshing from Firestore
      try {
        await refreshGroupImageFromFirestore(groupId);
      } catch (e) {
        print('⚠️ Could not refresh from Firestore: $e');
      }

      print('✅ Direct chat list update completed');

    } catch (e) {
      print('❌ Error in direct chat list update: $e');
    }
  }

  String _getImageType(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return 'None';

    if (imageUrl.startsWith('data:image')) {
      return 'Base64';
    } else if (imageUrl.startsWith('https://firebasestorage.googleapis.com')) {
      return 'Firebase Storage';
    } else if (imageUrl.startsWith('http')) {
      return 'HTTP URL';
    } else if (imageUrl.startsWith('local:')) {
      return 'Local file';
    }
    return 'Unknown';
  }

  Future<void> onGroupImageUpdated(String chatId, String newImageData) async {
    try {
      print('🔄 ChatController: Group image updated notification received');
      print('   Chat ID: $chatId');
      print('   New image data type: ${newImageData.startsWith('data:image') ? 'Base64' : 'URL'}');
      print('   Image data length: ${newImageData.length}');

      // Update local chat data immediately
      await _updateLocalChatGroupImage(chatId, newImageData);

      // Force refresh chat lists UI
      refreshChatListUI();

      print('✅ ChatController: Group image sync completed');

    } catch (e) {
      print('❌ ChatController: Error syncing group image: $e');
    }
  }

  Future<void> _updateLocalChatGroupImage(String chatId, String newImageData) async {
    try {
      print('🔄 Updating group image in ChatController local lists...');
      bool foundAndUpdated = false;

      // Update in group chats
      for (int i = 0; i < groupChats.length; i++) {
        if (groupChats[i].id == chatId) {
          print('🎯 Found group in groupChats list at index $i');

          // Create updated chat with new image
          final originalChat = groupChats[i];
          final updatedChat = _createUpdatedChatWithImage(originalChat, newImageData);

          groupChats[i] = updatedChat;
          groupChats.refresh();
          foundAndUpdated = true;

          print('✅ Updated group image in groupChats list');
          break;
        }
      }

      // Update in personal chats (in case group appears there too)
      for (int i = 0; i < personalChats.length; i++) {
        if (personalChats[i].id == chatId) {
          print('🎯 Found group in personalChats list at index $i');

          final originalChat = personalChats[i];
          final updatedChat = _createUpdatedChatWithImage(originalChat, newImageData);

          personalChats[i] = updatedChat;
          personalChats.refresh();
          foundAndUpdated = true;

          print('✅ Updated group image in personalChats list');
          break;
        }
      }

      // Update current chat if viewing this group
      if (currentChat.value?.id == chatId) {
        final currentChatValue = currentChat.value!;
        final updatedCurrentChat = _createUpdatedChatWithImage(currentChatValue, newImageData);
        currentChat.value = updatedCurrentChat;
        print('✅ Updated current chat group image');
      }

      if (foundAndUpdated) {
        // Apply search filters to update filtered lists
        _applySearchFilter();
        print('✅ Applied search filters after group image update');
      } else {
        print('⚠️ Group not found in local lists, will be updated on next refresh');
      }

    } catch (e) {
      print('❌ Error updating local chat group image: $e');
    }
  }


  Chat _createUpdatedChatWithImage(Chat originalChat, String newImageData) {
    try {
      return Chat(
        id: originalChat.id,
        name: originalChat.name,
        participants: originalChat.participants,
        isGroup: originalChat.isGroup,
        description: originalChat.description,
        createdBy: originalChat.createdBy,
        createdAt: originalChat.createdAt,
        lastMessage: originalChat.lastMessage,
        lastMessageTimestamp: originalChat.lastMessageTimestamp,
        lastMessageSender: originalChat.lastMessageSender,
        participantDetails: originalChat.participantDetails,
        unreadCounts: originalChat.unreadCounts,
        groupImage: newImageData, // Update the group image
        apiGroupId: originalChat.apiGroupId, // Preserve API group ID if exists
      );
    } catch (e) {
      print('❌ Error creating updated chat with image: $e');
      // Return original chat if update fails
      return originalChat;
    }
  }

  String getChatDisplayImage(Chat chat) {
    try {
      print('🖼️ Getting display image for chat: ${chat.id}');
      print('   Is Group: ${chat.isGroup}');
      print('   Chat Name: ${chat.name}');

      if (chat.isGroup) {
        return getGroupDisplayImage(chat);
      } else {
        return getPersonalChatDisplayImage(chat);
      }
    } catch (e) {
      print('❌ Error getting chat display image: $e');
      return CustomImage.avator;
    }
  }


  final Map<String, String> _persistentGroupImageCache = {};
  final Map<String, DateTime> _groupImageCacheTimestamp = {};

  // FIXED: Method to get group display image with persistent caching
  String getGroupDisplayImage(Chat chat) {
  try {
  print('🖼️ Getting group display image for: ${chat.id}');
  print('   Is Group: ${chat.isGroup}');
  print('   Chat Name: ${chat.name}');

  if (!chat.isGroup) {
  return chat.getDisplayAvatar(currentUserId) ?? CustomImage.avator;
  }

  final chatId = chat.id;

  // Step 1: Check persistent cache first (prevents loss during rebuilds)
  if (_persistentGroupImageCache.containsKey(chatId)) {
  final cachedImage = _persistentGroupImageCache[chatId]!;
  final cacheTime = _groupImageCacheTimestamp[chatId]!;

  // Use cache if less than 10 minutes old and not empty
  if (DateTime.now().difference(cacheTime).inMinutes < 10 &&
  cachedImage.isNotEmpty &&
  cachedImage != CustomImage.userGroup) {
  print('📦 Using persistent cached group image');
  return cachedImage;
  }
  }

  // Step 2: Get from chat object and validate
  final groupImage = chat.groupImage ?? '';
  print('   Raw group image: ${groupImage.length} chars');
  print('   Image type: ${_getImageType(groupImage)}');

  if (_isValidGroupImage(groupImage)) {
  print('✅ Valid group image found, caching it');
  // Cache the valid image
  _persistentGroupImageCache[chatId] = groupImage;
  _groupImageCacheTimestamp[chatId] = DateTime.now();
  return groupImage;
  }

  // Step 3: Try to get from GroupController if available
  try {
  if (Get.isRegistered<GroupController>()) {
  final groupController = Get.find<GroupController>();
  if (groupController.groupId == chatId) {
  final groupControllerImage = groupController.getDisplayImage();
  if (_isValidGroupImage(groupControllerImage) &&
  groupControllerImage != CustomImage.userGroup) {
  print('📦 Using image from GroupController');
  // Cache it for future use
  _persistentGroupImageCache[chatId] = groupControllerImage;
  _groupImageCacheTimestamp[chatId] = DateTime.now();

  // Also update the chat object to prevent future misses
  _updateChatGroupImageSilently(chatId, groupControllerImage);

  return groupControllerImage;
  }
  }
  }
  } catch (e) {
  print('⚠️ Could not get image from GroupController: $e');
  }

  // Step 4: Try to fetch from Firestore in background
  _fetchGroupImageFromFirestoreBackground(chatId);

  // Step 5: Return default
  print('📁 Using default group image');
  return CustomImage.userGroup;

  } catch (e) {
  print('❌ Error getting group display image: $e');
  return CustomImage.userGroup;
  }
  }

  // Helper method to validate group image
  bool _isValidGroupImage(String? imageData) {
  if (imageData == null ||
  imageData.isEmpty ||
  imageData == 'null' ||
  imageData == 'undefined' ||
  imageData == CustomImage.userGroup) {
  return false;
  }

  // Valid formats
  return imageData.startsWith('data:image') ||
  imageData.startsWith('http') ||
  imageData.startsWith('assets/') ||
  (imageData.length > 100); // Assume long strings are base64
  }

  // FIXED: Silent update method that doesn't trigger UI rebuilds
  void _updateChatGroupImageSilently(String chatId, String newImageData) {
  try {
  // Update in personal chats without triggering rebuilds
  for (int i = 0; i < personalChats.length; i++) {
  if (personalChats[i].id == chatId && personalChats[i].groupImage != newImageData) {
  final updatedChat = Chat(
  id: personalChats[i].id,
  name: personalChats[i].name,
  participants: personalChats[i].participants,
  isGroup: personalChats[i].isGroup,
  description: personalChats[i].description,
  createdBy: personalChats[i].createdBy,
  createdAt: personalChats[i].createdAt,
  lastMessage: personalChats[i].lastMessage,
  lastMessageTimestamp: personalChats[i].lastMessageTimestamp,
  lastMessageSender: personalChats[i].lastMessageSender,
  participantDetails: personalChats[i].participantDetails,
  unreadCounts: personalChats[i].unreadCounts,
  groupImage: newImageData, // Update the group image
  apiGroupId: personalChats[i].apiGroupId,
  );
  personalChats[i] = updatedChat;
  break;
  }
  }

  // Update in group chats without triggering rebuilds
  for (int i = 0; i < groupChats.length; i++) {
  if (groupChats[i].id == chatId && groupChats[i].groupImage != newImageData) {
  final updatedChat = Chat(
  id: groupChats[i].id,
  name: groupChats[i].name,
  participants: groupChats[i].participants,
  isGroup: groupChats[i].isGroup,
  description: groupChats[i].description,
  createdBy: groupChats[i].createdBy,
  createdAt: groupChats[i].createdAt,
  lastMessage: groupChats[i].lastMessage,
  lastMessageTimestamp: groupChats[i].lastMessageTimestamp,
  lastMessageSender: groupChats[i].lastMessageSender,
  participantDetails: groupChats[i].participantDetails,
  unreadCounts: groupChats[i].unreadCounts,
  groupImage: newImageData, // Update the group image
  apiGroupId: groupChats[i].apiGroupId,
  );
  groupChats[i] = updatedChat;
  break;
  }
  }

  print('✅ Chat group image updated silently');
  } catch (e) {
  print('❌ Error in silent update: $e');
  }
  }

  // Background fetch method that doesn't block UI
  void _fetchGroupImageFromFirestoreBackground(String chatId) {
  // Use Future.delayed to avoid blocking the UI
  Future.delayed(Duration(milliseconds: 100), () async {
  try {
  print('🔍 Background fetch of group image for: $chatId');

  final doc = await FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .get();

  if (doc.exists && doc.data() != null) {
  final data = doc.data()!;
  final firestoreImage = data['groupImage']?.toString() ?? '';

  if (_isValidGroupImage(firestoreImage)) {
  print('✅ Found valid group image in Firestore');

  // Cache it
  _persistentGroupImageCache[chatId] = firestoreImage;
  _groupImageCacheTimestamp[chatId] = DateTime.now();

  // Update chat objects silently
  _updateChatGroupImageSilently(chatId, firestoreImage);

  // Gentle UI refresh after a short delay
  Future.delayed(Duration(milliseconds: 200), () {
  _refreshChatListsGently();
  });
  }
  }
  } catch (e) {
  print('❌ Error in background fetch: $e');
  }
  });
  }

  // FIXED: Gentle refresh that doesn't cause flickering
  void _refreshChatListsGently() {
  try {
  // Only refresh the lists, don't force complete rebuilds
  personalChats.refresh();
  groupChats.refresh();

  // Update filtered lists
  _applySearchFilter();

  print('✅ Gentle refresh completed');
  } catch (e) {
  print('❌ Error in gentle refresh: $e');
  }
  }



  // Method to manually refresh a specific group's image
  Future<void> refreshSpecificGroupImage(String chatId) async {
  try {
  print('🔄 Manually refreshing group image for: $chatId');

  // Clear cache for this group
  _persistentGroupImageCache.remove(chatId);
  _groupImageCacheTimestamp.remove(chatId);

  // Fetch fresh from Firestore
  final doc = await FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .get();

  if (doc.exists && doc.data() != null) {
  final data = doc.data()!;
  final freshImage = data['groupImage']?.toString() ?? '';

  if (_isValidGroupImage(freshImage)) {
  // Update cache and chat objects
  _persistentGroupImageCache[chatId] = freshImage;
  _groupImageCacheTimestamp[chatId] = DateTime.now();
  _updateChatGroupImageSilently(chatId, freshImage);

  // Refresh UI
  _refreshChatListsGently();

  print('✅ Group image refreshed successfully');
  }
  }
  } catch (e) {
  print('❌ Error refreshing group image: $e');
  }
  }

  // Method to clear all group image cache
  void clearAllGroupImageCache() {
  print('🧹 Clearing all group image cache');
  _persistentGroupImageCache.clear();
  _groupImageCacheTimestamp.clear();
  }

  // Debug method to check cache status
  void debugGroupImageCache() {
  print('🔍 Group Image Cache Status:');
  print('   Cached groups: ${_persistentGroupImageCache.length}');

  _persistentGroupImageCache.forEach((chatId, imageData) {
  final timestamp = _groupImageCacheTimestamp[chatId];
  final age = timestamp != null ? DateTime.now().difference(timestamp).inMinutes : 0;
  print('   - $chatId: ${_getImageType(imageData)} (${age}min old)');
  });
  }



  String getPersonalChatDisplayImage(Chat chat) {
    try {
      // Find the other participant (not current user)
      for (String participantId in chat.participants) {
        if (participantId != _consistentUserId) {
          final participant = chat.participantDetails[participantId];
          if (participant?.avatar != null && participant!.avatar.isNotEmpty) {
            return participant.avatar;
          }
        }
      }

      // Return default if no avatar found
      return CustomImage.avator;

    } catch (e) {
      print('❌ Error getting personal chat display image: $e');
      return CustomImage.avator;
    }
  }


  Chat _createChatFromFirestoreDataEnhanced(String docId, Map<String, dynamic> data) {
    try {
      print('🔧 Creating chat from Firestore data for: $docId');
      print('📄 Raw data keys: ${data.keys.toList()}');

      // Extract participants safely
      final participants = List<String>.from(data['participants'] ?? []);
      print('👥 Participants: $participants');

      // ENHANCED: Extract group image with multiple possible field names and validation
      String groupImage = '';
      final possibleImageFields = ['groupImage', 'group_image', 'image', 'group_img', 'img'];

      for (String field in possibleImageFields) {
        if (data.containsKey(field)) {
          final imageValue = data[field]?.toString() ?? '';
          if (imageValue.isNotEmpty && imageValue != 'null' && imageValue != 'undefined') {
            groupImage = imageValue;
            print('📸 Found group image in field "$field": ${imageValue.length > 50 ? "${imageValue.substring(0, 50)}..." : imageValue}');
            break;
          }
        }
      }

      print('📸 Final group image: ${groupImage.length > 50 ? "${groupImage.substring(0, 50)}..." : groupImage}');
      print('📸 Image type: ${_getImageType(groupImage)}');

      // Extract participant details safely
      final participantDetailsRaw = data['participantDetails'] as Map<String, dynamic>? ?? {};
      print('📝 Raw participant details: ${participantDetailsRaw.keys.toList()}');

      // Build participant details map with null safety
      Map<String, ParticipantInfo> participantDetails = {};

      for (String participantId in participants) {
        try {
          final detailsRaw = participantDetailsRaw[participantId] as Map<String, dynamic>?;

          if (detailsRaw != null) {
            participantDetails[participantId] = ParticipantInfo(
              id: detailsRaw['id']?.toString() ?? participantId,
              name: detailsRaw['name']?.toString() ?? 'Unknown User',
              avatar: detailsRaw['avatar']?.toString() ?? '',
              isOnline: detailsRaw['isOnline'] as bool? ?? false,
            );
          } else {
            // Create default participant info if details are missing
            participantDetails[participantId] = ParticipantInfo(
              id: participantId,
              name: _getDefaultUserName(participantId),
              avatar: _getDefaultUserAvatar(participantId),
              isOnline: false,
            );
          }

          print('✅ Created participant info for: ${participantDetails[participantId]?.name}');
        } catch (e) {
          print('❌ Error creating participant info for $participantId: $e');
          // Create minimal participant info
          participantDetails[participantId] = ParticipantInfo(
            id: participantId,
            name: 'Unknown User',
            avatar: '',
            isOnline: false,
          );
        }
      }

      // Extract unread counts safely
      final unreadCountsRaw = data['unreadCounts'] as Map<String, dynamic>? ?? {};
      Map<String, int> unreadCounts = {};

      for (String participantId in participants) {
        unreadCounts[participantId] = (unreadCountsRaw[participantId] as num?)?.toInt() ?? 0;
      }

      // Extract timestamps safely
      DateTime createdAt = DateTime.now();
      DateTime lastMessageTimestamp = DateTime.now();

      try {
        if (data['createdAt'] != null) {
          createdAt = (data['createdAt'] as Timestamp).toDate();
        }
      } catch (e) {
        print('⚠️ Error parsing createdAt: $e');
      }

      try {
        if (data['lastMessageTimestamp'] != null) {
          lastMessageTimestamp = (data['lastMessageTimestamp'] as Timestamp).toDate();
        }
      } catch (e) {
        print('⚠️ Error parsing lastMessageTimestamp: $e');
      }

      // Extract other fields safely
      final isGroup = data['isGroup'] as bool? ?? false;
      final name = data['name']?.toString() ?? '';
      final description = data['description']?.toString() ?? '';
      final createdBy = data['createdBy']?.toString() ?? '';
      final lastMessage = data['lastMessage']?.toString() ?? '';
      final lastMessageSender = data['lastMessageSender']?.toString() ?? '';
      final apiGroupId = data['apiGroupId']?.toString();

      print('📊 Chat creation summary:');
      print('   - ID: $docId');
      print('   - Name: $name');
      print('   - Is Group: $isGroup');
      print('   - Group Image: ${groupImage.isNotEmpty ? "Set (${_getImageType(groupImage)}, ${groupImage.length} chars)" : "None"}');
      print('   - Participants: ${participants.length}');
      print('   - Last Message: "$lastMessage"');

      final chat = Chat(
        id: docId,
        name: name,
        participants: participants,
        isGroup: isGroup,
        description: description,
        createdBy: createdBy,
        createdAt: createdAt,
        lastMessage: lastMessage,
        lastMessageTimestamp: lastMessageTimestamp,
        lastMessageSender: lastMessageSender,
        participantDetails: participantDetails,
        unreadCounts: unreadCounts,
        groupImage: groupImage, // CRITICAL: Include the extracted group image
        apiGroupId: apiGroupId, // Include API group ID if exists
      );

      print('✅ Successfully created chat object with group image: $docId');
      return chat;

    } catch (e) {
      print('❌ Error in _createChatFromFirestoreDataEnhanced for $docId: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  void _setupGroupImageUpdateListener() {
    try {
      if (_consistentUserId == null) {
        print('⚠️ No user ID for group image listener');
        return;
      }

      print('👂 Setting up enhanced group image update listener...');

      // Listen for real-time updates to group images
      FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: _consistentUserId!)
          .where('isGroup', isEqualTo: true)
          .snapshots()
          .listen((snapshot) {

        print('📨 Group image listener: Received update for ${snapshot.docs.length} groups');

        for (var change in snapshot.docChanges) {
          try {
            final chatId = change.doc.id;
            final data = change.doc.data() as Map<String, dynamic>? ?? {};

            print('🔍 Processing change for group: $chatId, type: ${change.type}');

            if (change.type == DocumentChangeType.modified) {
              final newGroupImage = data['groupImage']?.toString() ?? '';
              final imageUpdatedAt = data['imageUpdatedAt'];

              print('📸 Group $chatId image data: ${newGroupImage.isNotEmpty ? "Present (${newGroupImage.length} chars)" : "Empty"}');

              // Check if group image was actually updated
              final existingChat = [...personalChats, ...groupChats]
                  .firstWhereOrNull((chat) => chat.id == chatId);

              if (existingChat != null) {
                final currentImage = existingChat.groupImage ?? '';

                if (currentImage != newGroupImage && newGroupImage.isNotEmpty) {
                  print('🔄 Detected group image change for $chatId');
                  print('   Old: ${currentImage.isEmpty ? "Empty" : "${currentImage.substring(0, 30)}..."}');
                  print('   New: ${newGroupImage.substring(0, 30)}...');

                  // Update local chat data immediately
                  _updateLocalChatGroupImageEnhanced(chatId, newGroupImage);

                  print('✅ Group image updated via real-time listener');
                } else {
                  print('📸 Group $chatId image unchanged or empty');
                }
              } else {
                print('⚠️ Group $chatId not found in local chat lists');

                // If group not in local lists, create it from Firestore data
                _createMissingGroupFromFirestore(chatId, data);
              }
            }

          } catch (changeError) {
            print('❌ Error processing group change ${change.doc.id}: $changeError');
          }
        }

      }, onError: (error) {
        print('❌ Error in group image update listener: $error');
      });

      print('✅ Enhanced group image update listener established');

    } catch (e) {
      print('❌ Error setting up group image update listener: $e');
    }
  }

  Future<void> _createMissingGroupFromFirestore(String chatId, Map<String, dynamic> data) async {
    try {
      print('🔄 Creating missing group from Firestore: $chatId');

      final chat = _createChatFromFirestoreDataEnhanced(chatId, data);

      if (chat.isGroup) {
        groupChats.add(chat);
        groupChats.refresh();
        print('✅ Added missing group to groupChats');
      } else {
        personalChats.add(chat);
        personalChats.refresh();
        print('✅ Added missing chat to personalChats');
      }

      _applySearchFilter();
      refreshChatListUI();

    } catch (e) {
      print('❌ Error creating missing group: $e');
    }
  }

  Future<void> forceRefreshChatsWithGroupImages() async {
    try {
      print('🔄 Force refreshing chats with group image awareness...');
      connectionStatus.value = 'Refreshing with images...';

      if (_consistentUserId == null) {
        print('❌ No user ID for force refresh');
        return;
      }

      // Get fresh data from Firestore with enhanced processing
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: _consistentUserId!)
          .get();

      print('🔄 Force refresh found ${snapshot.docs.length} chats');

      final chats = <Chat>[];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();

          // Log group image data for debugging
          if (data['isGroup'] == true) {
            final groupImage = data['groupImage']?.toString() ?? '';
            print('📸 Group ${doc.id} has image: ${groupImage.isNotEmpty ? "Yes (${groupImage.length} chars)" : "No"}');
          }

          // Use enhanced method that handles group images properly
          final chat = _createChatFromFirestoreDataEnhanced(doc.id, data);
          chats.add(chat);

          print('✅ Successfully processed chat with image: ${doc.id}');

        } catch (e) {
          print('❌ Error processing chat ${doc.id}: $e');
        }
      }

      print('✅ Force refresh processed ${chats.length} chats');
      _processChatData(chats);

      connectionStatus.value = 'Connected';

    } catch (e) {
      print('❌ Error in force refresh with group images: $e');
      connectionStatus.value = 'Connected (Local)';
    }
  }






// 11. ADD chat matching helper to ChatController
  bool _chatMatches(Chat chat, String targetId) {
    return chat.id == targetId ||
        chat.apiGroupId == targetId ||
        (chat.isGroup && chat.name.isNotEmpty && chat.id.contains(targetId));
  }



  // Enhanced ChatController methods for proper group image sync

// 1. REPLACE your existing refreshGroupImageFromFirestore method with this enhanced version:
  Future<void> refreshGroupImageFromFirestore(String chatId) async {
    try {
      print('🔄 Refreshing group image from Firestore for chat: $chatId');

      // Get updated chat data from Firestore
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      if (chatDoc.exists && chatDoc.data() != null) {
        final data = chatDoc.data()!;
        final newGroupImage = data['groupImage']?.toString() ?? '';

        print('🔄 Firestore group image for $chatId:');
        print('   - Image type: ${_getImageType(newGroupImage)}');
        print('   - Image length: ${newGroupImage.length}');

        if (newGroupImage.isNotEmpty) {
          // Update local chat data immediately with comprehensive approach
          await _updateLocalChatGroupImageComprehensive(chatId, newGroupImage);
          print('✅ Refreshed group image from Firestore');
        }
      }

    } catch (e) {
      print('❌ Error refreshing group image: $e');
    }
  }

// 2. ADD this new comprehensive local update method:
  Future<void> _updateLocalChatGroupImageComprehensive(String chatId, String newImageData) async {
    try {
      print('🔄 Comprehensive local update for chat: $chatId');
      print('   Image data length: ${newImageData.length}');
      print('   Image type: ${_getImageType(newImageData)}');

      bool updated = false;

      // Update in personalChats
      for (int i = 0; i < personalChats.length; i++) {
        if (_chatMatches(personalChats[i], chatId)) {
          print('🎯 Found chat in personalChats at index $i');
          personalChats[i] = _createUpdatedChatWithImage(personalChats[i], newImageData);
          updated = true;
          print('✅ Updated in personalChats at index $i');
          break;
        }
      }

      // Update in groupChats
      for (int i = 0; i < groupChats.length; i++) {
        if (_chatMatches(groupChats[i], chatId)) {
          print('🎯 Found chat in groupChats at index $i');
          personalChats[i] = _createUpdatedChatWithImage(groupChats[i], newImageData);
          updated = true;
          print('✅ Updated in groupChats at index $i');
          break;
        }
      }

      // Update current chat if it matches
      if (currentChat.value != null && _chatMatches(currentChat.value!, chatId)) {
        currentChat.value = _createUpdatedChatWithImage(currentChat.value!, newImageData);
        updated = true;
        print('✅ Updated current chat');
      }

      if (updated) {
        // Force refresh all lists
        personalChats.refresh();
        groupChats.refresh();
        currentChat.refresh();

        // Update filtered lists
        _applySearchFilter();

        // Force UI update
        update();

        print('✅ Comprehensive local update completed');
      } else {
        print('⚠️ No matching chat found for update');
      }

    } catch (e) {
      print('❌ Error in comprehensive local update: $e');
    }
  }


  Future<void> updateGroupImageWithFullSync(String chatId, String newImageData) async {
    try {
      print('🔄 ChatController: Full sync group image update');
      print('   Chat ID: $chatId');
      print('   Image type: ${_getImageType(newImageData)}');
      print('   Image length: ${newImageData.length}');

      // Step 1: Update local data immediately
      await _updateLocalChatGroupImageComprehensive(chatId, newImageData);

      // Step 2: Verify Firestore has the latest data
      await _verifyAndSyncFromFirestore(chatId);

      // Step 3: Force complete UI refresh
      await _forceCompleteUIRefresh();

      // Step 4: Trigger reactive updates
      _triggerReactiveUpdates();

      print('✅ ChatController: Full sync completed successfully');

    } catch (e) {
      print('❌ ChatController: Error in full sync: $e');
    }
  }

// 5. ADD Firestore verification method:
  Future<void> _verifyAndSyncFromFirestore(String chatId) async {
    try {
      print('🔍 Verifying Firestore data for chat: $chatId');

      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      if (chatDoc.exists && chatDoc.data() != null) {
        final data = chatDoc.data()!;
        final firestoreImage = data['groupImage']?.toString() ?? '';

        if (firestoreImage.isNotEmpty) {
          print('✅ Firestore verification: Image found');

          // Double-check local data matches
          await _updateLocalChatGroupImageComprehensive(chatId, firestoreImage);
        } else {
          print('⚠️ Firestore verification: No image in document');
        }
      } else {
        print('❌ Firestore verification: Document not found');
      }

    } catch (e) {
      print('❌ Error in Firestore verification: $e');
    }
  }

// 6. ADD complete UI refresh method:
  Future<void> _forceCompleteUIRefresh() async {
    try {
      print('🔄 Force complete UI refresh');

      // Refresh all reactive lists
      personalChats.refresh();
      groupChats.refresh();
      filteredPersonalChats.refresh();
      filteredGroupChats.refresh();

      if (currentChat.value != null) {
        currentChat.refresh();
      }

      // Update the controller itself
      update();

      // Force global app update
      Get.forceAppUpdate();

      // Small delay for UI processing
      await Future.delayed(Duration(milliseconds: 100));

      print('✅ Complete UI refresh finished');

    } catch (e) {
      print('❌ Error in complete UI refresh: $e');
    }
  }

// 7. ADD reactive updates trigger:
  void _triggerReactiveUpdates() {
    try {
      print('🔄 Triggering reactive updates');

      // Update all observable lists
      personalChats.value = List.from(personalChats);
      groupChats.value = List.from(groupChats);

      // Refresh filtered lists
      _applySearchFilter();

      // Force controller update
      update();

      print('✅ Reactive updates triggered');

    } catch (e) {
      print('❌ Error triggering reactive updates: $e');
    }
  }

// 8. REPLACE your existing updateGroupImage method:
  Future<void> updateGroupImage(String chatId, String newImageData) async {
    try {
      print('🔄 ChatController: Enhanced group image update');
      await updateGroupImageWithFullSync(chatId, newImageData);
    } catch (e) {
      print('❌ ChatController: Error updating group image: $e');
    }
  }




  Future<void> _initializeFirebaseServicesEnhanced() async {
    try {
      print('🔥 ChatController: Initializing Firebase services...');
      connectionStatus.value = 'Connecting to Firebase...';
      isLoading.value = true;

      await _setupFirebaseChatService();
      await _authenticateWithFirebase();
      await _migrateExistingChats();
      _setupAuthenticationListener();

      // NEW: Setup group image update listener
      _setupGroupImageUpdateListener();

      print('✅ ChatController: Firebase services initialized with group image sync');

    } catch (e) {
      print('❌ ChatController: Firebase services initialization failed: $e');
      _handleOfflineMode();
    } finally {
      isLoading.value = false;
    }
  }



  /// Enhanced method to force refresh chats with group image awareness
  Future<void> forceRefreshChatsWithImages() async {
    try {
      print('🔄 Force refreshing chats with image awareness...');
      connectionStatus.value = 'Refreshing...';

      if (_consistentUserId == null) {
        print('❌ No user ID for force refresh');
        return;
      }

      // Get fresh data from Firestore with enhanced processing
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: _consistentUserId!)
          .get();

      print('🔄 Force refresh found ${snapshot.docs.length} chats');

      final chats = <Chat>[];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();

          // Use enhanced method that handles group images properly
          final chat = _createChatFromFirestoreDataWithGroupImage(doc.id, data);
          chats.add(chat);

          print('✅ Successfully processed chat with image: ${doc.id}');

        } catch (e) {
          print('❌ Error processing chat ${doc.id}: $e');
        }
      }

      print('✅ Force refresh processed ${chats.length} chats with images');
      _processChatData(chats);

      connectionStatus.value = 'Connected';

    } catch (e) {
      print('❌ Error in force refresh with images: $e');
      connectionStatus.value = 'Connected (Local)';
    }
  }


  Chat _createChatFromFirestoreDataWithGroupImage(String docId, Map<String, dynamic> data) {
    try {
      print('🔧 Creating chat from Firestore data for: $docId');
      print('📄 Raw data keys: ${data.keys.toList()}');

      // Extract participants safely
      final participants = List<String>.from(data['participants'] ?? []);
      print('👥 Participants: $participants');

      // Extract group image with multiple possible field names
      String groupImage = '';
      if (data.containsKey('groupImage')) {
        groupImage = data['groupImage']?.toString() ?? '';
      } else if (data.containsKey('group_image')) {
        groupImage = data['group_image']?.toString() ?? '';
      } else if (data.containsKey('image')) {
        groupImage = data['image']?.toString() ?? '';
      }

      print('📸 Group image extracted: ${groupImage.length > 50 ? "${groupImage.substring(0, 50)}..." : groupImage}');
      print('📸 Image type: ${_getImageType(groupImage)}');

      // Extract participant details safely
      final participantDetailsRaw = data['participantDetails'] as Map<String, dynamic>? ?? {};
      print('📝 Raw participant details: ${participantDetailsRaw.keys.toList()}');

      // Build participant details map with null safety
      Map<String, ParticipantInfo> participantDetails = {};

      for (String participantId in participants) {
        try {
          final detailsRaw = participantDetailsRaw[participantId] as Map<String, dynamic>?;

          if (detailsRaw != null) {
            participantDetails[participantId] = ParticipantInfo(
              id: detailsRaw['id']?.toString() ?? participantId,
              name: detailsRaw['name']?.toString() ?? 'Unknown User',
              avatar: detailsRaw['avatar']?.toString() ?? '',
              isOnline: detailsRaw['isOnline'] as bool? ?? false,
            );
          } else {
            // Create default participant info if details are missing
            participantDetails[participantId] = ParticipantInfo(
              id: participantId,
              name: _getDefaultUserName(participantId),
              avatar: _getDefaultUserAvatar(participantId),
              isOnline: false,
            );
          }

          print('✅ Created participant info for: ${participantDetails[participantId]?.name}');
        } catch (e) {
          print('❌ Error creating participant info for $participantId: $e');
          // Create minimal participant info
          participantDetails[participantId] = ParticipantInfo(
            id: participantId,
            name: 'Unknown User',
            avatar: '',
            isOnline: false,
          );
        }
      }

      // Extract unread counts safely
      final unreadCountsRaw = data['unreadCounts'] as Map<String, dynamic>? ?? {};
      Map<String, int> unreadCounts = {};

      for (String participantId in participants) {
        unreadCounts[participantId] = (unreadCountsRaw[participantId] as num?)?.toInt() ?? 0;
      }

      // Extract timestamps safely
      DateTime createdAt = DateTime.now();
      DateTime lastMessageTimestamp = DateTime.now();

      try {
        if (data['createdAt'] != null) {
          createdAt = (data['createdAt'] as Timestamp).toDate();
        }
      } catch (e) {
        print('⚠️ Error parsing createdAt: $e');
      }

      try {
        if (data['lastMessageTimestamp'] != null) {
          lastMessageTimestamp = (data['lastMessageTimestamp'] as Timestamp).toDate();
        }
      } catch (e) {
        print('⚠️ Error parsing lastMessageTimestamp: $e');
      }

      // Extract other fields safely
      final isGroup = data['isGroup'] as bool? ?? false;
      final name = data['name']?.toString() ?? '';
      final description = data['description']?.toString() ?? '';
      final createdBy = data['createdBy']?.toString() ?? '';
      final lastMessage = data['lastMessage']?.toString() ?? '';
      final lastMessageSender = data['lastMessageSender']?.toString() ?? '';
      final apiGroupId = data['apiGroupId']?.toString();

      print('📊 Chat details:');
      print('   - ID: $docId');
      print('   - Name: $name');
      print('   - Is Group: $isGroup');
      print('   - Group Image: ${groupImage.isNotEmpty ? "Set (${_getImageType(groupImage)})" : "None"}');
      print('   - Participants: ${participants.length}');
      print('   - Last Message: "$lastMessage"');

      final chat = Chat(
        id: docId,
        name: name,
        participants: participants,
        isGroup: isGroup,
        description: description,
        createdBy: createdBy,
        createdAt: createdAt,
        lastMessage: lastMessage,
        lastMessageTimestamp: lastMessageTimestamp,
        lastMessageSender: lastMessageSender,
        participantDetails: participantDetails,
        unreadCounts: unreadCounts,
        groupImage: groupImage, // Include group image
        apiGroupId: apiGroupId, // Include API group ID if exists
      );

      print('✅ Successfully created chat object with group image: $docId');
      return chat;

    } catch (e) {
      print('❌ Error in _createChatFromFirestoreDataWithGroupImage for $docId: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }




  Map<String, dynamic> getChatDisplayInfoEnhanced(Chat chat) {
    return {
      'displayName': chat.getDisplayName(_consistentUserId),
      'displayAvatar': getChatDisplayImage(chat), // Use enhanced method
      'unreadCount': chat.unreadCounts[_consistentUserId] ?? 0,
      'lastMessagePreview': chat.lastMessage.isNotEmpty
          ? chat.lastMessage.length > 50
          ? '${chat.lastMessage.substring(0, 50)}...'
          : chat.lastMessage
          : 'No messages yet',
      'lastMessageTime': _formatLastMessageTime(chat.lastMessageTimestamp),
      'isOnline': _isParticipantOnline(chat),
      'hasCustomImage': chatHasCustomImage(chat),
      'isGroup': chat.isGroup,
      'groupImage': chat.isGroup ? getGroupDisplayImage(chat) : null,
      'imageType': chat.isGroup ? _getImageType(chat.groupImage) : null,
    };
  }

  /// Check if chat has custom image
  bool chatHasCustomImage(Chat chat) {
    if (!chat.isGroup) return false;

    final groupImage = chat.groupImage;
    return groupImage != null &&
        groupImage.isNotEmpty &&
        (groupImage.startsWith('data:image') ||
            groupImage.startsWith('http') ||
            groupImage.startsWith('local:'));
  }


  Future<void> initializeWithGroupImageSupport() async {
    try {
      print('🚀 Initializing ChatController with enhanced group image support...');

      // Step 1: Basic initialization
      await _safeInitializeFirebase();

      // Step 2: Enhanced Firebase services with group image support
      await _initializeFirebaseServicesEnhanced();

      // Step 3: Load chats with enhanced group image handling
      await _loadChatsEnhanced();

      // Step 4: Setup comprehensive group image listeners
      // _setupEnhancedGroupImageUpdateListener();

      // Step 5: Mark initialization as complete
      markInitialSetupComplete();

      print('✅ ChatController initialization with group image support completed');

    } catch (e) {
      print('❌ Error initializing ChatController with group image support: $e');
      _handleOfflineMode();
    }
  }
  /// Update your _loadChats method to use the enhanced chat creation
  Future<void> _loadChatsWithGroupImageSupport() async {
    print('📱 Loading chats with group image support...');

    if (_consistentUserId == null || _currentUserData == null) {
      print('❌ No user data available for loading chats');
      _processChatData([]);
      return;
    }

    isLoading.value = true;
    connectionStatus.value = 'Loading chats...';

    try {
      _chatsSubscription?.cancel();

      // Set up real-time listener with enhanced chat creation
      _chatsSubscription = FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: _consistentUserId!)
          .snapshots()
          .listen(
            (snapshot) {
          print('📨 Real-time update: ${snapshot.docs.length} chats');

          final chats = <Chat>[];
          for (var doc in snapshot.docs) {
            try {
              final data = doc.data();
              // Use enhanced method that handles group images properly
              final chat = _createChatFromFirestoreDataWithGroupImage(doc.id, data);
              chats.add(chat);
            } catch (e) {
              print('❌ Error parsing real-time chat ${doc.id}: $e');
            }
          }

          _processChatData(chats);
        },
        onError: (error) {
          print('❌ Error in real-time chat listener: $error');
          connectionStatus.value = 'Connected (Local)';
        },
      );

    } catch (e) {
      print('❌ Error in _loadChatsWithGroupImageSupport: $e');
      _processChatData([]);
    } finally {
      isLoading.value = false;
      connectionStatus.value = 'Connected';
    }
  }


  Future<void> _loadChatsEnhanced() async {
    print('📱 Loading chats with enhanced participant management...');

    if (_consistentUserId == null || _currentUserData == null) {
      print('❌ No user data available for loading chats');
      _processChatData([]);
      return;
    }

    isLoading.value = true;
    connectionStatus.value = 'Loading chats...';

    try {
      _chatsSubscription?.cancel();

      // Setup real-time listener with enhanced error handling
      _chatsSubscription = FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: _consistentUserId!)
          .snapshots()
          .listen(
            (snapshot) {
          print('📨 Real-time update: ${snapshot.docs.length} chats');

          final chats = <Chat>[];
          for (var doc in snapshot.docs) {
            try {
              final data = doc.data();

              // CRITICAL: Validate chat data before processing
              if (_validateChatData(data)) {
                final chat = _createChatFromFirestoreDataEnhanced(doc.id, data);
                chats.add(chat);
              } else {
                print('⚠️ Invalid chat data for ${doc.id}');
              }

            } catch (e) {
              print('❌ Error parsing real-time chat ${doc.id}: $e');
            }
          }

          _processChatData(chats);
        },
        onError: (error) {
          print('❌ Error in real-time chat listener: $error');
          connectionStatus.value = 'Connected (Local)';

          _loadChatsEnhanced();

        },
      );

    } catch (e) {
      print('❌ Error in _loadChatsEnhanced: $e');
      _processChatData([]);
    } finally {
      isLoading.value = false;
      connectionStatus.value = 'Connected';
    }
  }

  // CRITICAL: Validate chat data before processing
  bool _validateChatData(Map<String, dynamic> data) {
    try {
      // Check required fields
      if (data['participants'] == null || !(data['participants'] is List)) {
        return false;
      }

      final participants = List<String>.from(data['participants']);
      if (participants.isEmpty) {
        return false;
      }

      // Ensure current user is in participants
      if (!participants.contains(_consistentUserId!)) {
        print('⚠️ Current user not in participants: ${data['participants']}');
        return false;
      }

      return true;

    } catch (e) {
      print('❌ Error validating chat data: $e');
      return false;
    }
  }

  // FIXED: Enhanced group image sync
  Future<void> syncGroupImageFromGroupController(String chatId, String imageData) async {
    try {
      print('🔄 Syncing group image from GroupController...');
      print('   Chat ID: $chatId');
      print('   Image data length: ${imageData.length}');

      if (!_isValidGroupImage(imageData)) {
        print('❌ Invalid image data from GroupController');
        return;
      }

      // Update persistent cache immediately
      _persistentGroupImageCache[chatId] = imageData;
      _groupImageCacheTimestamp[chatId] = DateTime.now();

      // Update chat objects silently
      _updateChatGroupImageSilently(chatId, imageData);

      // Gentle refresh after a short delay
      Future.delayed(Duration(milliseconds: 300), () {
        _refreshChatListsGently();
      });

      print('✅ Group image synced from GroupController');

    } catch (e) {
      print('❌ Error syncing group image from GroupController: $e');
    }
  }



  Future<void> refreshGroupImageFromController(String chatId) async {
    try {
      print('🔄 Refreshing group image from GroupController for chat: $chatId');

      // Get updated chat data from Firestore
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      if (chatDoc.exists) {
        final data = chatDoc.data()!;
        final newGroupImage = data['groupImage']?.toString() ?? '';

        if (newGroupImage.isNotEmpty) {
          await _updateLocalChatGroupImage(chatId, newGroupImage);
          print('✅ Refreshed group image from Firestore');
        }
      }

    } catch (e) {
      print('❌ Error refreshing group image: $e');
    }
  }



  /// Create group with image support (base64 or file path)
  Future<String?> createGroupWithImage({
    required String groupName,
    required String groupDescription,
    required List<String> memberIds,
    String? groupImagePath,
    String? groupImageBase64,
  }) async {
    if (_consistentUserId == null) {
      _showError('User not authenticated');
      return null;
    }

    try {
      isLoading.value = true;
      isCreatingChat.value = true;
      isSendingMessage.value = true;

      print('👥 Creating group with image: $groupName');

      final allParticipants = [_consistentUserId!, ...memberIds];

      // Prepare group image data
      String groupImageData = '';

      if (groupImageBase64 != null && groupImageBase64.isNotEmpty) {
        // Use provided base64 image
        groupImageData = groupImageBase64;
        print('📸 Using provided base64 image');
      } else if (groupImagePath != null && groupImagePath.isNotEmpty) {
        // Convert file to base64
        try {
          final File imageFile = File(groupImagePath);
          if (await imageFile.exists()) {
            final bytes = await imageFile.readAsBytes();
            groupImageData = 'data:image/jpeg;base64,${base64Encode(bytes)}';
            print('📸 Converted file to base64');
          }
        } catch (e) {
          print('⚠️ Error converting image to base64: $e');
          // Continue without image
        }
      }

      final groupData = {
        'name': groupName.trim(),
        'description': groupDescription.trim(),
        'groupImage': groupImageData, // Store the base64 or URL
        'participants': allParticipants,
        'isGroup': true,
        'createdBy': _consistentUserId!,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': 'Group created',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSender': _consistentUserId!,
        'participantDetails': {
          _consistentUserId!: {
            'id': _consistentUserId!,
            'name': _currentUserData!['full_name']?.toString() ?? 'User',
            'avatar': _currentUserData!['profile_image'] ?? CustomImage.avator,
            'isOnline': true,
          },
          // Add other participants details here based on memberIds
        },
        'unreadCounts': {
          for (var userId in allParticipants) userId: 0,
        },
      };

      print('📝 Creating group document with image data: ${groupImageData.isNotEmpty ? "Yes" : "No"}');

      final docRef = await FirebaseFirestore.instance
          .collection('chats')
          .add(groupData);

      print('✅ Group created successfully: ${docRef.id}');

      // Add to local list immediately
      await _addNewChatToLocalListImmediate(docRef.id, groupData);

      if (!_silentMode) {
        _showSuccess('Group "$groupName" created successfully!');
      }

      return docRef.id;

    } catch (e) {
      print('❌ Error creating group with image: $e');
      if (!_silentMode) {
        _showError('Failed to create group: ${e.toString()}');
      }
      return null;
    } finally {
      isLoading.value = false;
      isCreatingChat.value = false;
      isSendingMessage.value = false;
    }
  }

// Alternative methods to handle images without Firebase Storage

// Method 1: Base64 Encoding (Store directly in Firestore)
  Future<void> sendImageAsBase64() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60, // Reduce quality to minimize size
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image != null) {
        isSendingMessage.value = true;

        // Read image as bytes
        final File imageFile = File(image.path);
        final Uint8List imageBytes = await imageFile.readAsBytes();

        // Check file size (Firestore has 1MB document limit)
        if (imageBytes.length > 800000) { // ~800KB limit
          throw Exception('Image too large. Please choose a smaller image.');
        }

        // Convert to base64
        final String base64Image = base64Encode(imageBytes);
        final String imageDataUri = 'data:image/jpeg;base64,$base64Image';

        // Create message with base64 image
        final message = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          chatId: currentChatId!,
          senderId: currentUserId ?? 'unknown',
          senderName: currentUserName ?? 'Unknown User',
          text: '📷 Image',
          timestamp: DateTime.now(),
          type: MessageType.image,
          imageUrl: imageDataUri, // Store base64 directly
          readBy: [currentUserId ?? ''],
        );

        // Add to local messages
        currentMessages.add(message);
        currentMessages.refresh();

        // Send to Firestore
        await _sendMessageToFirestore(message);

        print('✅ Base64 image sent successfully');
      }
    } catch (e) {
      print('❌ Error sending base64 image: $e');
      Get.snackbar('Error', e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,);
    } finally {
      isSendingMessage.value = false;
    }
  }

// Method 2: Using ImgBB API (Free image hosting)
  Future<void> sendImageViaImgBB() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        isSendingMessage.value = true;

        // Upload to ImgBB
        final String imageUrl = await _uploadToImgBB(File(image.path));

        if (imageUrl.isNotEmpty) {
          final message = ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            chatId: currentChatId!,
            senderId: currentUserId ?? 'unknown',
            senderName: currentUserName ?? 'Unknown User',
            text: '📷 Image',
            timestamp: DateTime.now(),
            type: MessageType.image,
            imageUrl: imageUrl,
            readBy: [currentUserId ?? ''],
          );

          currentMessages.add(message);
          await _sendMessageToFirestore(message);

          print('✅ ImgBB image sent successfully');
        }
      }
    } catch (e) {
      print('❌ Error sending ImgBB image: $e');
      Get.snackbar('Error', 'Failed to upload image: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isSendingMessage.value = false;
    }
  }

// ImgBB upload helper
  Future<String> _uploadToImgBB(File imageFile) async {
    try {
      const String apiKey = 'YOUR_IMGBB_API_KEY'; // Get free API key from imgbb.com
      const String uploadUrl = 'https://api.imgbb.com/1/upload';

      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse(uploadUrl),
        body: {
          'key': apiKey,
          'image': base64Image,
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          return jsonResponse['data']['url'];
        }
      }

      throw Exception('Failed to upload to ImgBB');
    } catch (e) {
      print('❌ ImgBB upload error: $e');
      throw Exception('Upload failed: $e');
    }
  }

// Method 3: Using Cloudinary (Free tier available)
  Future<void> sendImageViaCloudinary() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        isSendingMessage.value = true;

        final String imageUrl = await _uploadToCloudinary(File(image.path));

        if (imageUrl.isNotEmpty) {
          final message = ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            chatId: currentChatId!,
            senderId: currentUserId ?? 'unknown',
            senderName: currentUserName ?? 'Unknown User',
            text: '📷 Image',
            timestamp: DateTime.now(),
            type: MessageType.image,
            imageUrl: imageUrl,
            readBy: [currentUserId ?? ''],
          );

          currentMessages.add(message);
          await _sendMessageToFirestore(message);
        }
      }
    } catch (e) {
      print('❌ Error sending Cloudinary image: $e');
      Get.snackbar('Error', 'Failed to upload image',
        backgroundColor: Colors.red,
        colorText: Colors.white,);
    } finally {
      isSendingMessage.value = false;
    }
  }

// Cloudinary upload helper
  Future<String> _uploadToCloudinary(File imageFile) async {
    try {
      const String cloudName = 'YOUR_CLOUD_NAME';
      const String uploadPreset = 'YOUR_UPLOAD_PRESET';
      const String uploadUrl = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonResponse = json.decode(responseData);
        return jsonResponse['secure_url'];
      }

      throw Exception('Cloudinary upload failed');
    } catch (e) {
      print('❌ Cloudinary upload error: $e');
      throw Exception('Upload failed: $e');
    }
  }

// Method 4: Local Storage with Sharing (No internet upload)
  Future<void> sendImageLocally() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image != null) {
        isSendingMessage.value = true;

        // Save to app's documents directory
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String localPath = '${appDir.path}/chat_images/$fileName';

        // Create directory if it doesn't exist
        await Directory('${appDir.path}/chat_images').create(recursive: true);

        // Copy image to local storage
        final File localFile = await File(image.path).copy(localPath);

        // Create message with local path
        // Note: This only works if all users have access to the same local storage
        // Better to use this with a sync mechanism or for demo purposes
        final message = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          chatId: currentChatId!,
          senderId: currentUserId ?? 'unknown',
          senderName: currentUserName ?? 'Unknown User',
          text: '📷 Local Image',
          timestamp: DateTime.now(),
          type: MessageType.image,
          imageUrl: 'local:$localPath',
          readBy: [currentUserId ?? ''],
        );

        currentMessages.add(message);
        // Note: Don't send to Firestore as other users can't access local files

        print('✅ Local image saved');
      }
    } catch (e) {
      print('❌ Error with local image: $e');
    } finally {
      isSendingMessage.value = false;
    }
  }

// Method 5: Using your existing backend API
  Future<void> sendImageViaAPI() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        isSendingMessage.value = true;

        // Upload to your backend API
        final String imageUrl = await _uploadToYourAPI(File(image.path));

        if (imageUrl.isNotEmpty) {
          final message = ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            chatId: currentChatId!,
            senderId: currentUserId ?? 'unknown',
            senderName: currentUserName ?? 'Unknown User',
            text: '📷 Image',
            timestamp: DateTime.now(),
            type: MessageType.image,
            imageUrl: imageUrl,
            readBy: [currentUserId ?? ''],
          );

          currentMessages.add(message);
          await _sendMessageToFirestore(message);
        }
      }
    } catch (e) {
      print('❌ Error sending API image: $e');
    } finally {
      isSendingMessage.value = false;
    }
  }

// Upload to your backend API
  Future<String> _uploadToYourAPI(File imageFile) async {
    try {
      const String apiUrl = 'https://your-api-endpoint.com/upload-image';

      final request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // Add user authentication
      final userData = StorageService.to.getUser();
      if (userData != null) {
        request.headers['Authorization'] = 'Bearer ${userData['token']}';
      }

      // Add the image file
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonResponse = json.decode(responseData);
        return jsonResponse['image_url']; // Adjust based on your API response
      }

      throw Exception('API upload failed');
    } catch (e) {
      print('❌ API upload error: $e');
      throw Exception('Upload failed: $e');
    }
  }




  // Migrate individual chat document
  Future<void> _migrateChatDocument(QueryDocumentSnapshot doc) async {
    try {
      final chatData = doc.data() as Map<String, dynamic>;
      final participants = List<String>.from(chatData['participants'] ?? []);
      final userEmail = _currentUserData!['email']?.toString() ?? '';

      bool needsUpdate = false;

      // Replace email with consistent user ID
      for (int i = 0; i < participants.length; i++) {
        if (participants[i] == userEmail) {
          participants[i] = _consistentUserId!;
          needsUpdate = true;
          break;
        }
      }

      // Update participant details if needed
      Map<String, dynamic>? participantDetails = chatData['participantDetails'];
      if (participantDetails != null && participantDetails.containsKey(userEmail)) {
        final userDetails = participantDetails[userEmail];
        participantDetails.remove(userEmail);
        participantDetails[_consistentUserId!] = userDetails;
        needsUpdate = true;
      }

      // Update unread counts if needed
      Map<String, dynamic>? unreadCounts = chatData['unreadCounts'];
      if (unreadCounts != null && unreadCounts.containsKey(userEmail)) {
        final count = unreadCounts[userEmail];
        unreadCounts.remove(userEmail);
        unreadCounts[_consistentUserId!] = count;
        needsUpdate = true;
      }

      if (needsUpdate) {
        await doc.reference.update({
          'participants': participants,
          if (participantDetails != null) 'participantDetails': participantDetails,
          if (unreadCounts != null) 'unreadCounts': unreadCounts,
          'migratedAt': FieldValue.serverTimestamp(),
        });

        print('✅ Migrated chat: ${doc.id}');
      }

    } catch (e) {
      print('❌ Error migrating chat ${doc.id}: $e');
    }
  }

  // ========== PUBLIC GETTERS FOR USER DATA ==========

  /// Get current user's profile image
  String get currentUserAvatar {
    if (_currentUserData != null) {
      return _currentUserData!['profile_image']?.toString() ?? '';
    }
    return '';
  }

  /// Get current user's email
  String get currentUserEmail {
    if (_currentUserData != null) {
      return _currentUserData!['email']?.toString() ?? '';
    }
    return '';
  }

  /// Get current user's full data (if needed)
  Map<String, dynamic>? get currentUserData {
    return _currentUserData != null ? Map<String, dynamic>.from(_currentUserData!) : null;
  }

  /// Get current user's ID (ensure this exists)
  String? get currentUserId => _consistentUserId;

  /// Get current user's name (ensure this exists)
  String? get currentUserName {
    if (_currentUserData != null) {
      return _currentUserData!['full_name']?.toString() ?? 'User';
    }
    return 'Guest User';
  }

  Future<void> _ensureUserDocumentExists() async {
    try {
      if (_currentUserData == null || _consistentUserId == null) return;

      print('📝 Ensuring user document exists for: $_consistentUserId');

      final userName = _currentUserData!['full_name']?.toString() ?? 'User';
      final userEmail = _currentUserData!['email']?.toString() ?? '';
      final userAvatar = _currentUserData!['profile_image']?.toString() ?? CustomImage.avator;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_consistentUserId!)
          .set({
        'id': _consistentUserId!,
        'name': userName,
        'email': userEmail,
        'avatar': userAvatar,
        'isOnline': true,
        'isAppUser': true,
        'appUserId': _currentUserData!['id']?.toString() ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        'joinedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ User document created/updated successfully');
    } catch (e) {
      print('❌ Error ensuring user document: $e');
    }
  }

  void _setupAuthenticationListener() {
    try {
      print('👂 Setting up authentication listener...');

      _authStateSubscription?.cancel();
      _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen(
            (User? user) {
          print('🔍 Auth state changed: ${user?.uid ?? 'No user'}');
          _handleAuthStateChange(user);
        },
        onError: (error) {
          print('❌ Auth state listener error: $error');
          if (!_silentMode) {
            connectionStatus.value = 'Authentication error';
            isConnected.value = false;
          }
        },
      );

    } catch (e) {
      print('❌ Error setting up authentication listener: $e');
    }
  }

  void _handleAuthStateChange(User? user) {
    if (user != null) {
      print('✅ User authenticated with Firebase: ${user.uid}');
      isConnected.value = true;
      connectionStatus.value = 'Connected';
      // Don't reload chats here to avoid infinite loops
    } else {
      print('❌ User not authenticated - attempting re-authentication');
      if (_currentUserData != null) {
        Future.delayed(Duration(seconds: 1), () {
          _authenticateWithFirebase();
        });
      }
    }
  }

  void refreshChatListUI() {
    personalChats.refresh();
    groupChats.refresh();
    filteredPersonalChats.refresh();
    filteredGroupChats.refresh();

    // Also refresh current chat if viewing one
    if (currentChat.value != null) {
      currentChat.refresh();
    }

    print('✅ Chat list UI refreshed');
  }

  // Enhanced method to check if any chats exist
  bool get hasAnyChats => personalChats.isNotEmpty || groupChats.isNotEmpty;

  // Method to get the count of unread chats
  int get totalUnreadChats {
    int count = 0;
    for (var chat in [...personalChats, ...groupChats]) {
      final unreadCount = chat.unreadCounts[currentUserId] ?? 0;
      if (unreadCount > 0) count++;
    }
    return count;
  }

  // Method to get total unread messages
  int get totalUnreadMessages {
    int count = 0;
    for (var chat in [...personalChats, ...groupChats]) {
      count += chat.unreadCounts[currentUserId] ?? 0;
    }
    return count;
  }

  // Add these methods to your ChatController class

// Enhanced method to load chats with multiple user ID formats
  Future<void> _loadChats() async {
    print('📱 Loading chats for user: $_consistentUserId');

    if (_consistentUserId == null || _currentUserData == null) {
      print('❌ No user data available for loading chats');
      _processChatData([]);
      return;
    }

    isLoading.value = true;
    connectionStatus.value = 'Loading chats...';

    try {
      _chatsSubscription?.cancel();

      // Get user email for fallback searches
      final userEmail = _currentUserData!['email']?.toString() ?? '';
      final userId = _currentUserData!['id']?.toString() ?? '';

      // Create multiple possible user ID formats to search for
      List<String> possibleUserIds = [
        _consistentUserId!,
      ];

      // Add email-based fallbacks
      if (userEmail.isNotEmpty) {
        possibleUserIds.addAll([
          userEmail,
          'app_user_${userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}',
        ]);
      }

      // Add numeric ID fallbacks
      if (userId.isNotEmpty) {
        possibleUserIds.addAll([
          'app_user_$userId',
          userId,
        ]);
      }

      // Remove duplicates
      possibleUserIds = possibleUserIds.toSet().toList();

      print('🔍 Searching for chats with possible user IDs: $possibleUserIds');

      // Create a composite query to find chats with any of these user IDs
      Set<String> foundChatIds = {};
      List<Chat> allChats = [];

      for (String possibleUserId in possibleUserIds) {
        try {
          print('🔍 Searching with user ID: $possibleUserId');

          final snapshot = await FirebaseFirestore.instance
              .collection('chats')
              .where('participants', arrayContains: possibleUserId)
              .get();

          print('📨 Found ${snapshot.docs.length} chats for user ID: $possibleUserId');

          for (var doc in snapshot.docs) {
            // Avoid duplicates
            if (foundChatIds.contains(doc.id)) {
              continue;
            }
            foundChatIds.add(doc.id);

            try {
              final data = doc.data();
              print('📄 Processing chat: ${doc.id} - ${data['name'] ?? 'Personal Chat'}');

              // Migrate the chat if needed
              bool migrated = await _migrateChatIfNeeded(doc.id, data, possibleUserId);

              // Get fresh data if migrated
              final chatData = migrated ?
              (await FirebaseFirestore.instance.collection('chats').doc(doc.id).get()).data()! :
              data;

              final chat = _createChatFromFirestoreData(doc.id, chatData);
              allChats.add(chat);
              print('✅ Successfully processed chat: ${doc.id}');

            } catch (e) {
              print('❌ Error parsing chat ${doc.id}: $e');
            }
          }
        } catch (e) {
          print('❌ Error searching with user ID $possibleUserId: $e');
        }
      }

      print('📊 Total unique chats found: ${allChats.length}');

      // Process the found chats
      _processChatData(allChats);

      // Set up real-time listener for the primary user ID
      await _setupRealTimeListener();

    } catch (e) {
      print('❌ Error in _loadChats: $e');
      _processChatData([]);
    } finally {
      isLoading.value = false;
      connectionStatus.value = 'Connected';
    }
  }

// Enhanced migration method
  Future<bool> _migrateChatIfNeeded(String chatId, Map<String, dynamic> chatData, String foundUserId) async {
    try {
      // Check if this chat needs migration
      final participants = List<String>.from(chatData['participants'] ?? []);

      // If the chat was found with a different user ID than our current consistent ID,
      // we need to migrate it
      if (foundUserId != _consistentUserId && participants.contains(foundUserId)) {
        print('🔄 Migrating chat $chatId from $foundUserId to $_consistentUserId');

        bool needsUpdate = false;

        // Replace the old user ID with the new consistent one
        for (int i = 0; i < participants.length; i++) {
          if (participants[i] == foundUserId) {
            participants[i] = _consistentUserId!;
            needsUpdate = true;
            break;
          }
        }

        // Update participant details
        Map<String, dynamic>? participantDetails = chatData['participantDetails'];
        if (participantDetails != null && participantDetails.containsKey(foundUserId)) {
          final userDetails = participantDetails[foundUserId];
          participantDetails.remove(foundUserId);
          participantDetails[_consistentUserId!] = userDetails;
          needsUpdate = true;
        }

        // Update unread counts
        Map<String, dynamic>? unreadCounts = chatData['unreadCounts'];
        if (unreadCounts != null && unreadCounts.containsKey(foundUserId)) {
          final count = unreadCounts[foundUserId];
          unreadCounts.remove(foundUserId);
          unreadCounts[_consistentUserId!] = count;
          needsUpdate = true;
        }

        if (needsUpdate) {
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .update({
            'participants': participants,
            if (participantDetails != null) 'participantDetails': participantDetails,
            if (unreadCounts != null) 'unreadCounts': unreadCounts,
            'migratedAt': FieldValue.serverTimestamp(),
            'migratedFrom': foundUserId,
            'migratedTo': _consistentUserId!,
          });

          print('✅ Successfully migrated chat: $chatId');
          return true;
        }
      }

      return false;
    } catch (e) {
      print('❌ Error migrating chat $chatId: $e');
      return false;
    }
  }

// Set up real-time listener for the primary user ID
  Future<void> _setupRealTimeListener() async {
    try {
      print('👂 Setting up real-time listener for: $_consistentUserId');

      _chatsSubscription = FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: _consistentUserId!)
          .snapshots()
          .listen(
            (snapshot) {
          print('📨 Real-time update: ${snapshot.docs.length} chats');

          final chats = <Chat>[];
          for (var doc in snapshot.docs) {
            try {
              final data = doc.data();
              final chat = _createChatFromFirestoreData(doc.id, data);
              chats.add(chat);
            } catch (e) {
              print('❌ Error parsing real-time chat ${doc.id}: $e');
            }
          }

          _processChatData(chats);
        },
        onError: (error) {
          print('❌ Error in real-time chat listener: $error');
          connectionStatus.value = 'Connected (Local)';
        },
      );

    } catch (e) {
      print('❌ Error setting up real-time listener: $e');
    }
  }

// Enhanced debug method to check what chats exist
  Future<void> debugChatSearch() async {
    if (_currentUserData == null) {
      print('❌ No user data for debug search');
      return;
    }

    print('🔍 DEBUG: Searching for all possible chats...');

    final userEmail = _currentUserData!['email']?.toString() ?? '';
    final userId = _currentUserData!['id']?.toString() ?? '';

    print('👤 Current user data:');
    print('   - Email: $userEmail');
    print('   - ID: $userId');
    print('   - Consistent ID: $_consistentUserId');

    // Search for chats with different user ID formats
    List<String> searchTerms = [
      userEmail,
      userId,
      _consistentUserId ?? '',
      'app_user_$userId',
      'app_user_${userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}',
    ].where((s) => s.isNotEmpty).toList();

    for (String searchTerm in searchTerms) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: searchTerm)
            .get();

        print('🔍 Search term "$searchTerm": ${snapshot.docs.length} chats found');

        for (var doc in snapshot.docs.take(3)) {
          final data = doc.data();
          final participants = data['participants'] ?? [];
          final lastMessage = data['lastMessage'] ?? '';
          print('   - Chat ${doc.id}: participants=$participants, lastMsg="$lastMessage"');
        }
      } catch (e) {
        print('❌ Error searching with "$searchTerm": $e');
      }
    }

    // Also search without arrayContains to see all chats
    try {
      final allChats = await FirebaseFirestore.instance
          .collection('chats')
          .limit(10)
          .get();

      print('📊 Total recent chats in database: ${allChats.docs.length}');
      for (var doc in allChats.docs) {
        final data = doc.data();
        final participants = data['participants'] ?? [];
        print('   - Chat ${doc.id}: participants=$participants');
      }
    } catch (e) {
      print('❌ Error getting all chats: $e');
    }
  }

// Add this method to force debug and reload
  Future<void> forceDebugAndReload() async {
    print('🔄 FORCE DEBUG AND RELOAD');

    // Run debug search
    await debugChatSearch();

    // Force reload chats
    await _loadChats();

    // Update UI
    refreshChatListUI();
  }





  List<Chat> get currentChatList {
    List<Chat> sourceList;

    if (selectedTabIndex.value == 0) {
      // Personal chats tab
      sourceList = searchQuery.value.isEmpty ? personalChats : filteredPersonalChats;
    } else {
      // Group chats tab
      sourceList = searchQuery.value.isEmpty ? groupChats : filteredGroupChats;
    }

    // Always sort by last message timestamp (newest first)
    final sortedList = List<Chat>.from(sourceList);
    sortedList.sort((a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp));

    return sortedList;
  }





  // NEW: Ensure existing chat appears in local list
  Future<void> _ensureChatInLocalList(String chatId) async {
    try {
      // Check if chat already exists in local lists
      final existsInPersonal = personalChats.any((chat) => chat.id == chatId);
      final existsInGroup = groupChats.any((chat) => chat.id == chatId);

      if (!existsInPersonal && !existsInGroup) {
        print('🔄 Chat not in local list, fetching from Firestore...');

        // Fetch chat from Firestore
        final chatDoc = await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .get();

        if (chatDoc.exists) {
          final data = chatDoc.data()!;
          final chat = _createChatFromFirestoreData(chatDoc.id, data);

          if (chat.isGroup) {
            groupChats.add(chat);
            groupChats.refresh();
          } else {
            personalChats.add(chat);
            personalChats.refresh();
          }

          _applySearchFilter();
          refreshChatListUI();

          print('✅ Added existing chat to local list');
        }
      }
    } catch (e) {
      print('❌ Error ensuring chat in local list: $e');
    }
  }

  // NEW: Add new chat to local list immediately
  Future<void> _addNewChatToLocalList(String chatId, Map<String, dynamic> chatData, String displayName) async {
    try {
      // Create chat object from the data we just created
      final chat = Chat(
        id: chatId,
        name: chatData['name'],
        participants: List<String>.from(chatData['participants']),
        isGroup: chatData['isGroup'] ?? false,
        description: chatData['description'],
        createdBy: chatData['createdBy'],
        createdAt: DateTime.now(), // Use current time
        lastMessage: chatData['lastMessage'] ?? '',
        lastMessageTimestamp: DateTime.now(),
        lastMessageSender: chatData['lastMessageSender'] ?? '',
        participantDetails: (chatData['participantDetails'] as Map<String, dynamic>).map((key, value) {
          final data = value as Map<String, dynamic>;
          return MapEntry(
            key,
            ParticipantInfo(
              id: data['id'] ?? key,
              name: data['name'] ?? 'Unknown',
              avatar: data['avatar'] ?? '',
              isOnline: data['isOnline'] ?? false,
            ),
          );
        }),
        unreadCounts: Map<String, int>.from(
            (chatData['unreadCounts'] as Map<String, dynamic>).map((key, value) =>
                MapEntry(key, value as int? ?? 0))
        ),
      );

      // Add to appropriate list
      if (chat.isGroup) {
        // Insert at beginning for newest first
        groupChats.insert(0, chat);
        groupChats.refresh();
      } else {
        // Insert at beginning for newest first
        personalChats.insert(0, chat);
        personalChats.refresh();
      }

      // Update filtered lists
      _applySearchFilter();

      // Force UI refresh
      refreshChatListUI();

      print('✅ New chat added to local list immediately');
    } catch (e) {
      print('❌ Error adding new chat to local list: $e');
    }
  }

  bool shouldShowEmptyState() {
    final hasNoChats = personalChats.isEmpty && groupChats.isEmpty;
    final isNotLoading = !isLoading.value;
    final isNotCreatingChat = !isCreatingChat.value && !isSendingMessage.value;
    final isNotInitialSetup = !isInitialSetup.value;

    return hasNoChats && isNotLoading && isNotCreatingChat && isNotInitialSetup;
  }

  // Method to mark initial setup as complete
  void markInitialSetupComplete() {
    isInitialSetup.value = false;
  }

  List<Chat> get recentChats {
    final allChats = [...personalChats, ...groupChats];
    allChats.sort((a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp));
    return allChats;
  }

  // Method to get recent personal chats
  List<Chat> get recentPersonalChats {
    final chats = List<Chat>.from(personalChats);
    chats.sort((a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp));
    return chats;
  }

  // Method to get recent group chats
  List<Chat> get recentGroupChats {
    final chats = List<Chat>.from(groupChats);
    chats.sort((a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp));
    return chats;
  }

  // Add these enhanced methods to your ChatController class

// 1. Enhanced _processChatData method with better debugging
  void _processChatData(List<Chat> chats) {
    print('📊 Processing ${chats.length} chats...');
    print('📊 Current user ID for processing: $_consistentUserId');

    // Debug: Print all chats before processing
    for (var chat in chats) {
      print('🔍 Chat ${chat.id}: isGroup=${chat.isGroup}, participants=${chat.participants}');
    }

    // Sort chats by last message timestamp (newest first)
    chats.sort((a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp));

    final personalChatsList = chats.where((chat) => !chat.isGroup).toList();
    final groupChatsList = chats.where((chat) => chat.isGroup).toList();

    print('📊 Personal chats found: ${personalChatsList.length}');
    print('📊 Group chats found: ${groupChatsList.length}');

    // Debug: Print details of each personal chat
    for (var chat in personalChatsList) {
      final displayName = chat.getDisplayName(_consistentUserId);
      print('💬 Personal chat: ${chat.id} with $displayName');
      print('   - Last message: "${chat.lastMessage}"');
      print('   - Participants: ${chat.participants}');
      print('   - Timestamp: ${chat.lastMessageTimestamp}');
    }

    // Debug: Print details of each group chat
    for (var chat in groupChatsList) {
      print('👥 Group chat: ${chat.id} - ${chat.name} (${chat.participants.length} members)');
      print('   - Last message: "${chat.lastMessage}"');
      print('   - Participants: ${chat.participants}');
    }

    // Update the observable lists - CRITICAL: Use .value = instead of .assignAll()
    personalChats.value = personalChatsList;
    groupChats.value = groupChatsList;

    // Force immediate refresh of the lists
    personalChats.refresh();
    groupChats.refresh();

    print('✅ personalChats.value updated to ${personalChats.length} items');
    print('✅ groupChats.value updated to ${groupChats.length} items');

    // Apply search filter
    _applySearchFilter();

    // Force UI update using the new method
    refreshChatListUI();

    print('✅ Chat processing completed - UI should show updated chats');
    print('✅ Final count - Personal: ${personalChats.length}, Groups: ${groupChats.length}');
  }

// FIXED: Enhanced createPersonalChat method with consistent user ID handling
  Future<String?> createPersonalChat(String apiUserId, String userName) async {
    if (_consistentUserId == null) {
      _showError('User not authenticated');
      return null;
    }

    try {
      // Set loading states
      isLoading.value = true;
      isCreatingChat.value = true;
      isSendingMessage.value = true;

      print('💬 Creating personal chat with API user: $userName (API ID: $apiUserId)');
      print('👤 Current user consistent ID: $_consistentUserId');

      // CRITICAL: Convert API user ID to consistent format
      final otherUserConsistentId = 'app_user_$apiUserId';
      print('👤 Other user consistent ID: $otherUserConsistentId');

      // Check if chat already exists with BOTH possible ID formats
      final possibleParticipantCombinations = [
        [_consistentUserId!, otherUserConsistentId],
        [_consistentUserId!, apiUserId], // Fallback for old chats
      ];

      String? existingChatId;

      for (var participants in possibleParticipantCombinations) {
        final existingChatQuery = await FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: _consistentUserId!)
            .where('isGroup', isEqualTo: false)
            .get();

        for (var doc in existingChatQuery.docs) {
          final docParticipants = List<String>.from(doc.data()['participants'] ?? []);
          print('📝 Checking existing chat ${doc.id} with participants: $docParticipants');

          // Check if this chat contains both users (in any format)
          if (docParticipants.contains(_consistentUserId!) &&
              (docParticipants.contains(otherUserConsistentId) ||
                  docParticipants.contains(apiUserId))) {

            existingChatId = doc.id;
            print('✅ Found existing chat: $existingChatId');

            // CRITICAL: Migrate chat to use consistent IDs if needed
            await _migrateChatToConsistentIds(doc.id, docParticipants, otherUserConsistentId, apiUserId);
            break;
          }
        }
        if (existingChatId != null) break;
      }

      if (existingChatId != null) {
        // IMPORTANT: Ensure this chat is in our local list
        await _ensureExistingChatInLocalList(existingChatId, {});

        if (!_silentMode) {
          _showSuccess('Opening existing chat with $userName');
        }
        return existingChatId;
      }

      print('🆕 Creating new chat with $userName');

      // Create new chat with CONSISTENT participant IDs
      final chatData = {
        'participants': [_consistentUserId!, otherUserConsistentId], // Both consistent
        'isGroup': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': 'Chat created',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSender': 'system',
        'participantDetails': {
          _consistentUserId!: {
            'id': _consistentUserId!,
            'name': _currentUserData!['full_name']?.toString() ?? 'User',
            'avatar': _currentUserData!['profile_image'] ?? CustomImage.avator,
            'isOnline': true,
            'originalApiId': _currentUserData!['id']?.toString() ?? '',
          },
          otherUserConsistentId: {
            'id': otherUserConsistentId,
            'name': userName,
            'avatar': CustomImage.avator, // Will be updated from UI
            'isOnline': false,
            'originalApiId': apiUserId, // Store original API ID for reference
          },
        },
        'unreadCounts': {
          _consistentUserId!: 0,
          otherUserConsistentId: 0,
        },
        'chatType': 'personal',
        'apiUserMapping': {
          otherUserConsistentId: apiUserId, // Map consistent ID to API ID
        }
      };

      print('📝 Creating chat document with consistent participants: ${chatData['participants']}');

      final docRef = await FirebaseFirestore.instance
          .collection('chats')
          .add(chatData);

      print('✅ Personal chat created successfully: ${docRef.id}');

      // CRITICAL: Create user document for API user in Firebase
      await _ensureApiUserDocumentExists(apiUserId, otherUserConsistentId, userName);

      // CRITICAL: Immediately add to local list with proper data
      await _addNewChatToLocalListImmediate(docRef.id, chatData);

      print('🔍 Personal chats after local addition: ${personalChats.length}');

      // Schedule a delayed refresh to ensure consistency
      Future.delayed(Duration(milliseconds: 1500), () {
        print('🔄 Delayed refresh after chat creation');
        _forceRefreshChats();
      });

      if (!_silentMode) {
        _showSuccess('Chat created with $userName');
      }

      return docRef.id;

    } catch (e) {
      print('❌ Error creating personal chat: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      if (!_silentMode) {
        _showError('Failed to create chat: ${e.toString()}');
      }
      return null;
    } finally {
      // Reset all loading states
      isLoading.value = false;
      isCreatingChat.value = false;
      isSendingMessage.value = false;
    }
  }

// NEW: Migrate existing chat to consistent IDs
  Future<void> _migrateChatToConsistentIds(String chatId, List<String> currentParticipants,
      String consistentId, String apiId) async {
    try {
      print('🔄 Migrating chat $chatId to consistent IDs');

      bool needsUpdate = false;
      final updatedParticipants = List<String>.from(currentParticipants);

      // Replace API ID with consistent ID if needed
      for (int i = 0; i < updatedParticipants.length; i++) {
        if (updatedParticipants[i] == apiId && !updatedParticipants.contains(consistentId)) {
          updatedParticipants[i] = consistentId;
          needsUpdate = true;
          print('🔄 Replaced $apiId with $consistentId');
          break;
        }
      }

      if (needsUpdate) {
        await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
          'participants': updatedParticipants,
          'migratedAt': FieldValue.serverTimestamp(),
          'apiUserMapping.$consistentId': apiId,
        });
        print('✅ Chat migrated to consistent IDs');
      }

    } catch (e) {
      print('❌ Error migrating chat: $e');
    }
  }

// NEW: Ensure API user document exists in Firebase
  Future<void> _ensureApiUserDocumentExists(String apiUserId, String consistentId, String userName) async {
    try {
      print('📝 Ensuring API user document exists: $userName ($consistentId)');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(consistentId)
          .set({
        'id': consistentId,
        'name': userName,
        'avatar': CustomImage.avator,
        'isOnline': false,
        'isApiUser': true,
        'originalApiId': apiUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ API user document created/updated successfully');
    } catch (e) {
      print('❌ Error creating API user document: $e');
    }
  }

// 3. New method to ensure existing chat is in local list
  Future<void> _ensureExistingChatInLocalList(String chatId, Map<String, dynamic> chatData) async {
    try {
      // Check if chat already exists in local lists
      final existsInPersonal = personalChats.any((chat) => chat.id == chatId);
      final existsInGroup = groupChats.any((chat) => chat.id == chatId);

      if (!existsInPersonal && !existsInGroup) {
        print('🔄 Existing chat not in local list, adding...');

        final chat = _createChatFromFirestoreData(chatId, chatData);

        if (chat.isGroup) {
          groupChats.add(chat);
          groupChats.refresh();
          print('✅ Added existing group chat to local list');
        } else {
          personalChats.add(chat);
          personalChats.refresh();
          print('✅ Added existing personal chat to local list');
        }

        _applySearchFilter();
        refreshChatListUI();
      } else {
        print('✅ Existing chat already in local list');
      }
    } catch (e) {
      print('❌ Error ensuring existing chat in local list: $e');
    }
  }

// 4. Enhanced method to add new chat to local list immediately
  Future<void> _addNewChatToLocalListImmediate(String chatId, Map<String, dynamic> chatData) async {
    try {
      print('➕ Adding new chat to local list immediately: $chatId');

      // Create chat object from the data we just created
      final chat = Chat(
        id: chatId,
        name: chatData['name'],
        participants: List<String>.from(chatData['participants']),
        isGroup: chatData['isGroup'] ?? false,
        description: chatData['description'],
        createdBy: chatData['createdBy'],
        createdAt: DateTime.now(), // Use current time
        lastMessage: chatData['lastMessage'] ?? 'Chat created',
        lastMessageTimestamp: DateTime.now(),
        lastMessageSender: chatData['lastMessageSender'] ?? 'system',
        participantDetails: (chatData['participantDetails'] as Map<String, dynamic>).map((key, value) {
          final data = value as Map<String, dynamic>;
          return MapEntry(
            key,
            ParticipantInfo(
              id: data['id'] ?? key,
              name: data['name'] ?? 'Unknown',
              avatar: data['avatar'] ?? '',
              isOnline: data['isOnline'] ?? false,
            ),
          );
        }),
        unreadCounts: Map<String, int>.from(
            (chatData['unreadCounts'] as Map<String, dynamic>).map((key, value) =>
                MapEntry(key, value as int? ?? 0))
        ),
      );

      print('📝 Created chat object: ${chat.id}, isGroup: ${chat.isGroup}');

      // Add to appropriate list at the beginning (newest first)
      if (chat.isGroup) {
        groupChats.insert(0, chat);
        groupChats.refresh();
        print('✅ Added new group chat to local list: ${groupChats.length} total');
      } else {
        personalChats.insert(0, chat);
        personalChats.refresh();
        print('✅ Added new personal chat to local list: ${personalChats.length} total');
      }

      // Update filtered lists
      _applySearchFilter();

      // Force UI refresh
      refreshChatListUI();

      print('✅ New chat successfully added to local list immediately');
    } catch (e) {
      print('❌ Error adding new chat to local list: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

// Add these debug methods to your ChatController class

// 1. COMPREHENSIVE DEBUG METHOD - Add this to ChatController
  Future<void> debugCompleteChatsIssue() async {
    print('🔍 =================== COMPLETE CHAT DEBUG ===================');

    // Current user info
    final userData = StorageService.to.getUser();
    print('👤 Current User Data: ${userData?.keys}');
    print('📧 Email: ${userData?['email']}');
    print('🆔 User ID: ${userData?['id']}');
    print('🎯 Consistent User ID: $_consistentUserId');

    // Check all possible user ID formats
    final userEmail = userData?['email']?.toString() ?? '';
    final userId = userData?['id']?.toString() ?? '';

    List<String> allPossibleIds = [
      userEmail,
      userId,
      _consistentUserId ?? '',
      'app_user_$userId',
      'app_user_${userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}',
    ].where((s) => s.isNotEmpty).toSet().toList();

    print('🔍 Searching for chats with these possible IDs: $allPossibleIds');

    // Search Firestore for ANY chats containing any of these IDs
    try {
      // First, get ALL chats to see what exists
      final allChatsSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .limit(50)
          .get();

      print('📊 Total chats in database: ${allChatsSnapshot.docs.length}');

      for (var doc in allChatsSnapshot.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        final isGroup = data['isGroup'] ?? false;
        final lastMessage = data['lastMessage'] ?? '';

        print('📄 Chat ${doc.id}:');
        print('   - Participants: $participants');
        print('   - Is Group: $isGroup');
        print('   - Last Message: "$lastMessage"');

        // Check if any of our possible IDs are in participants
        final matchingIds = participants.where((p) => allPossibleIds.contains(p)).toList();
        if (matchingIds.isNotEmpty) {
          print('   ✅ MATCH FOUND! Our IDs in this chat: $matchingIds');
        }
      }

      // Now search specifically for chats with each possible ID
      for (String possibleId in allPossibleIds) {
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection('chats')
              .where('participants', arrayContains: possibleId)
              .get();

          print('🔍 Chats found for ID "$possibleId": ${snapshot.docs.length}');

          for (var doc in snapshot.docs) {
            final data = doc.data();
            print('   - ${doc.id}: ${data['name'] ?? 'Personal Chat'} (${data['participants']})');
          }
        } catch (e) {
          print('❌ Error searching for ID "$possibleId": $e');
        }
      }

    } catch (e) {
      print('❌ Error in complete debug: $e');
    }

    print('🔍 =================== END COMPLETE DEBUG ===================');
  }

// 2. FORCE MIGRATION METHOD - Add this to ChatController
  Future<void> forceMigrateAllChats() async {
    print('🔄 =================== FORCE MIGRATION ===================');

    try {
      final userData = StorageService.to.getUser();
      if (userData == null) {
        print('❌ No user data for migration');
        return;
      }

      final userEmail = userData['email']?.toString() ?? '';
      final userId = userData['id']?.toString() ?? '';
      final currentConsistentId = _consistentUserId;

      if (currentConsistentId == null) {
        print('❌ No consistent user ID for migration');
        return;
      }

      print('🎯 Migrating to consistent ID: $currentConsistentId');

      // Find chats with old formats
      List<String> oldFormats = [
        userEmail,
        userId,
        'app_user_${userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}',
      ].where((s) => s.isNotEmpty && s != currentConsistentId).toList();

      print('🔍 Looking for chats with old formats: $oldFormats');

      Set<String> migratedChatIds = {};

      for (String oldFormat in oldFormats) {
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection('chats')
              .where('participants', arrayContains: oldFormat)
              .get();

          print('📨 Found ${snapshot.docs.length} chats with old format: $oldFormat');

          for (var doc in snapshot.docs) {
            if (migratedChatIds.contains(doc.id)) {
              print('⏭️ Chat ${doc.id} already migrated, skipping');
              continue;
            }

            final data = doc.data();
            final participants = List<String>.from(data['participants']);

            print('🔄 Migrating chat ${doc.id} from $oldFormat to $currentConsistentId');

            // Replace old format with new format
            bool updated = false;
            for (int i = 0; i < participants.length; i++) {
              if (participants[i] == oldFormat) {
                participants[i] = currentConsistentId;
                updated = true;
                break;
              }
            }

            if (updated) {
              // Update participant details
              Map<String, dynamic>? participantDetails = data['participantDetails'];
              if (participantDetails != null && participantDetails.containsKey(oldFormat)) {
                final userDetails = participantDetails[oldFormat];
                participantDetails.remove(oldFormat);
                participantDetails[currentConsistentId] = userDetails;
              }

              // Update unread counts
              Map<String, dynamic>? unreadCounts = data['unreadCounts'];
              if (unreadCounts != null && unreadCounts.containsKey(oldFormat)) {
                final count = unreadCounts[oldFormat];
                unreadCounts.remove(oldFormat);
                unreadCounts[currentConsistentId] = count;
              }

              // Perform the update
              await doc.reference.update({
                'participants': participants,
                if (participantDetails != null) 'participantDetails': participantDetails,
                if (unreadCounts != null) 'unreadCounts': unreadCounts,
                'migratedAt': FieldValue.serverTimestamp(),
                'migratedFrom': oldFormat,
                'migratedTo': currentConsistentId,
              });

              print('✅ Successfully migrated chat: ${doc.id}');
              migratedChatIds.add(doc.id);
            }
          }
        } catch (e) {
          print('❌ Error migrating chats for format $oldFormat: $e');
        }
      }

      print('🎉 Migration completed. Migrated ${migratedChatIds.length} chats');

      // Now reload chats
      await _loadChats();

    } catch (e) {
      print('❌ Error in force migration: $e');
    }

    print('🔄 =================== END FORCE MIGRATION ===================');
  }

// 3. FORCE REFRESH WITH COMPREHENSIVE SEARCH - Replace existing _loadChats
  Future<void> _loadChatsComprehensive() async {
    print('📱 COMPREHENSIVE CHAT LOADING...');

    if (_consistentUserId == null || _currentUserData == null) {
      print('❌ No user data available for loading chats');
      _processChatData([]);
      return;
    }

    isLoading.value = true;
    connectionStatus.value = 'Loading chats...';

    try {
      _chatsSubscription?.cancel();

      // Get user info
      final userEmail = _currentUserData!['email']?.toString() ?? '';
      final userId = _currentUserData!['id']?.toString() ?? '';

      // Create COMPREHENSIVE list of possible user IDs
      List<String> possibleUserIds = [
        _consistentUserId!,
        userEmail,
        userId,
        'app_user_$userId',
        'app_user_${userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}',
      ].where((s) => s.isNotEmpty).toSet().toList();

      print('🔍 COMPREHENSIVE search with IDs: $possibleUserIds');

      Set<String> foundChatIds = {};
      List<Chat> allChats = [];

      // Search for each possible user ID
      for (String possibleUserId in possibleUserIds) {
        try {
          print('🔍 Searching with ID: $possibleUserId');

          final snapshot = await FirebaseFirestore.instance
              .collection('chats')
              .where('participants', arrayContains: possibleUserId)
              .get();

          print('📨 Found ${snapshot.docs.length} chats for ID: $possibleUserId');

          for (var doc in snapshot.docs) {
            if (foundChatIds.contains(doc.id)) {
              continue; // Skip duplicates
            }
            foundChatIds.add(doc.id);

            try {
              final data = doc.data();
              print('📄 Processing chat: ${doc.id}');
              print('   - Participants: ${data['participants']}');
              print('   - Is Group: ${data['isGroup']}');
              print('   - Last Message: "${data['lastMessage']}"');

              // Always migrate to consistent ID before processing
              bool migrated = await _migrateChatIfNeeded(doc.id, data, possibleUserId);

              // Get fresh data if migrated
              final chatData = migrated ?
              (await FirebaseFirestore.instance.collection('chats').doc(doc.id).get()).data()! :
              data;

              final chat = _createChatFromFirestoreData(doc.id, chatData);
              allChats.add(chat);

              print('✅ Added chat to list: ${doc.id}');

            } catch (e) {
              print('❌ Error processing chat ${doc.id}: $e');
            }
          }
        } catch (e) {
          print('❌ Error searching with ID $possibleUserId: $e');
        }
      }

      print('📊 TOTAL UNIQUE CHATS FOUND: ${allChats.length}');

      // Process all found chats
      _processChatData(allChats);

      // Set up real-time listener with primary ID
      await _setupRealTimeListener();

    } catch (e) {
      print('❌ Error in comprehensive chat loading: $e');
      _processChatData([]);
    } finally {
      isLoading.value = false;
      connectionStatus.value = 'Connected';
    }
  }


  Future<void> nuclearResetAndReload() async {
    print('💥 =================== NUCLEAR RESET ===================');

    try {
      // Cancel all subscriptions
      _chatsSubscription?.cancel();
      _messagesSubscription?.cancel();

      // Clear all local data
      personalChats.clear();
      groupChats.clear();
      filteredPersonalChats.clear();
      filteredGroupChats.clear();
      currentMessages.clear();

      // Reset states
      isLoading.value = true;
      currentChatId = null;
      currentChat.value = null;

      // Refresh user session
      await refreshUserSession();

      // Wait a moment
      await Future.delayed(Duration(seconds: 1));

      // Force comprehensive reload
      await _loadChatsComprehensive();

      // Wait for processing
      await Future.delayed(Duration(milliseconds: 1500));

      // Force UI update
      refreshChatListUI();

      print('💥 NUCLEAR RESET COMPLETED');

    } catch (e) {
      print('❌ Error in nuclear reset: $e');
    } finally {
      isLoading.value = false;
    }

    print('💥 =================== END NUCLEAR RESET ===================');
  }

  void debugChatControllerState() {
    print('=== CHAT CONTROLLER DEBUG ===');
    print('Initialized: $_isInitialized');
    print('Current User ID: $_consistentUserId');
    print('Current User Data: ${_currentUserData?.keys}');
    print('Firebase Service: ${_firebaseService != null}');
    print('Connected: ${isConnected.value}');
    print('Connection Status: ${connectionStatus.value}');
    print('Loading: ${isLoading.value}');
    print('Creating Chat: ${isCreatingChat.value}');
    print('Initial Setup: ${isInitialSetup.value}');
    print('Personal Chats: ${personalChats.length}');
    print('Group Chats: ${groupChats.length}');
    print('Current Chat ID: $currentChatId');

    print('Personal Chats Details:');
    for (int i = 0; i < personalChats.length; i++) {
      final chat = personalChats[i];
      print('  [$i] ${chat.id}: ${chat.getDisplayName(_consistentUserId)}');
      print('      - Last: "${chat.lastMessage}"');
      print('      - Participants: ${chat.participants}');
    }

    print('Group Chats Details:');
    for (int i = 0; i < groupChats.length; i++) {
      final chat = groupChats[i];
      print('  [$i] ${chat.id}: ${chat.name}');
      print('      - Last: "${chat.lastMessage}"');
      print('      - Members: ${chat.participants.length}');
    }
    print('=== END CONTROLLER DEBUG ===');
  }


  Map<String, dynamic> getChatDisplayInfo(Chat chat) {
    return {
      'displayName': chat.getDisplayName(_consistentUserId),
      'displayAvatar': chat.getDisplayAvatar(_consistentUserId),
      'unreadCount': chat.unreadCounts[_consistentUserId] ?? 0,
      'lastMessagePreview': chat.lastMessage.isNotEmpty
          ? chat.lastMessage.length > 50
          ? '${chat.lastMessage.substring(0, 50)}...'
          : chat.lastMessage
          : 'No messages yet',
      'lastMessageTime': _formatLastMessageTime(chat.lastMessageTimestamp),
      'isOnline': _isParticipantOnline(chat),
    };
  }

  // Helper method to format last message time
  String _formatLastMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  // Helper method to check if any participant is online
  bool _isParticipantOnline(Chat chat) {
    for (var participantId in chat.participants) {
      if (participantId != _consistentUserId) {
        final participant = chat.participantDetails[participantId];
        if (participant?.isOnline == true) {
          return true;
        }
      }
    }
    return false;
  }

  // Enhanced refreshChats method
  Future<void> refreshChats() async {
    try {
      print('🔄 Manual refresh requested...');
      connectionStatus.value = 'Refreshing...';

      // Don't set isLoading to true to avoid showing loading state
      // isLoading.value = true;

      // Force a fresh load from Firestore
      await _forceRefreshChats();

      // Wait for the UI to process
      await Future.delayed(Duration(milliseconds: 800));

      connectionStatus.value = 'Connected';

      // if (!_silentMode) {
      //   _showSuccess('Chats refreshed');
      // }

      print('✅ Manual refresh completed');
    } catch (e) {
      connectionStatus.value = 'Connected (Local)';
      print('❌ Error refreshing chats: $e');
    }
  }

  // NEW: Force refresh chats method
  Future<void> _forceRefreshChats() async {
    try {
      print('🔄 Force refreshing chats...');

      if (_consistentUserId == null) {
        print('❌ No user ID for force refresh');
        return;
      }

      // Get fresh data from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: _consistentUserId!)
          .get();

      print('🔄 Force refresh found ${snapshot.docs.length} chats');

      final chats = <Chat>[];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final chat = _createChatFromFirestoreData(doc.id, data);
          chats.add(chat);

        } catch (e) {
          print('❌ Error processing chat ${doc.id} in force refresh: $e');
        }
      }

      print('✅ Force refresh processed ${chats.length} chats');
      _processChatData(chats);

    } catch (e) {
      print('❌ Error in force refresh: $e');
    }
  }

  // REPLACE your existing _createChatFromFirestoreData method in ChatController with this:

  Chat _createChatFromFirestoreData(String docId, Map<String, dynamic> data) {
    try {
      print('🔧 Creating chat from Firestore data for: $docId');
      print('📄 Raw data keys: ${data.keys.toList()}');

      // Extract participants safely
      final participants = List<String>.from(data['participants'] ?? []);
      print('👥 Participants: $participants');

      // Extract participant details safely
      final participantDetailsRaw = data['participantDetails'] as Map<String, dynamic>? ?? {};
      print('📝 Raw participant details: ${participantDetailsRaw.keys.toList()}');

      // Build participant details map with null safety
      Map<String, ParticipantInfo> participantDetails = {};

      for (String participantId in participants) {
        try {
          final detailsRaw = participantDetailsRaw[participantId] as Map<String, dynamic>?;

          if (detailsRaw != null) {
            participantDetails[participantId] = ParticipantInfo(
              id: detailsRaw['id']?.toString() ?? participantId,
              name: detailsRaw['name']?.toString() ?? 'Unknown User',
              avatar: detailsRaw['avatar']?.toString() ?? '',
              isOnline: detailsRaw['isOnline'] as bool? ?? false,
            );
          } else {
            // Create default participant info if details are missing
            participantDetails[participantId] = ParticipantInfo(
              id: participantId,
              name: _getDefaultUserName(participantId),
              avatar: _getDefaultUserAvatar(participantId),
              isOnline: false,
            );
          }

          print('✅ Created participant info for: ${participantDetails[participantId]?.name}');
        } catch (e) {
          print('❌ Error creating participant info for $participantId: $e');
          // Create minimal participant info
          participantDetails[participantId] = ParticipantInfo(
            id: participantId,
            name: 'Unknown User',
            avatar: '',
            isOnline: false,
          );
        }
      }

      // Extract unread counts safely
      final unreadCountsRaw = data['unreadCounts'] as Map<String, dynamic>? ?? {};
      Map<String, int> unreadCounts = {};

      for (String participantId in participants) {
        unreadCounts[participantId] = (unreadCountsRaw[participantId] as num?)?.toInt() ?? 0;
      }

      // Extract timestamps safely
      DateTime createdAt = DateTime.now();
      DateTime lastMessageTimestamp = DateTime.now();

      try {
        if (data['createdAt'] != null) {
          createdAt = (data['createdAt'] as Timestamp).toDate();
        }
      } catch (e) {
        print('⚠️ Error parsing createdAt: $e');
      }

      try {
        if (data['lastMessageTimestamp'] != null) {
          lastMessageTimestamp = (data['lastMessageTimestamp'] as Timestamp).toDate();
        }
      } catch (e) {
        print('⚠️ Error parsing lastMessageTimestamp: $e');
      }

      // Extract other fields safely
      final isGroup = data['isGroup'] as bool? ?? false;
      final name = data['name'].toString(); // Can be null for personal chats
      final description = data['description'].toString();
      final createdBy = data['createdBy'].toString();
      final lastMessage = data['lastMessage']?.toString() ?? '';
      final lastMessageSender = data['lastMessageSender']?.toString() ?? '';

      print('📊 Chat details:');
      print('   - ID: $docId');
      print('   - Name: $name');
      print('   - Is Group: $isGroup');
      print('   - Participants: ${participants.length}');
      print('   - Last Message: "$lastMessage"');

      final chat = Chat(
        id: docId,
        name: name,
        participants: participants,
        isGroup: isGroup,
        description: description,
        createdBy: createdBy,
        createdAt: createdAt,
        lastMessage: lastMessage,
        lastMessageTimestamp: lastMessageTimestamp,
        lastMessageSender: lastMessageSender,
        participantDetails: participantDetails,
        unreadCounts: unreadCounts,
      );

      print('✅ Successfully created chat object: $docId');
      return chat;

    } catch (e) {
      print('❌ Error in _createChatFromFirestoreData for $docId: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }



  RxString selectedGroupImagePath = ''.obs;
  final ImagePicker _groupImagePicker = ImagePicker();

// Method to pick group image
  Future<void> pickGroupImage() async {
    try {
      final XFile? image = await _groupImagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        selectedGroupImagePath.value = image.path;
        print('✅ Group image selected: ${image.path}');
      }
    } catch (e) {
      print('❌ Error picking group image: $e');
      if (!_silentMode) {
        _showError('Failed to select image');
      }
    }
  }

// Method to clear selected group image
  void clearGroupImage() {
    selectedGroupImagePath.value = '';
  }

  Future<void> _forceRefreshChatsWithErrorHandling() async {
    try {
      print('🔄 Force refreshing chats with error handling...');

      if (_consistentUserId == null) {
        print('❌ No user ID for force refresh');
        return;
      }

      // Get fresh data from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: _consistentUserId!)
          .get();

      print('🔄 Force refresh found ${snapshot.docs.length} chats');

      final chats = <Chat>[];

      for (var doc in snapshot.docs) {
        try {
          print('🔧 Processing chat: ${doc.id}');
          final data = doc.data();

          // Debug the raw data
          print('📊 Chat ${doc.id} raw data:');
          print('   - participants: ${data['participants']}');
          print('   - isGroup: ${data['isGroup']}');
          print('   - lastMessage: ${data['lastMessage']}');
          print('   - participantDetails: ${data['participantDetails']?.keys}');

          final chat = _createChatFromFirestoreData(doc.id, data);
          chats.add(chat);

          print('✅ Successfully processed chat: ${doc.id}');

        } catch (e) {
          print('❌ Error processing chat ${doc.id}: $e');
          print('❌ Chat data: ${doc.data()}');

          // Try to create a minimal chat object to not lose the chat completely
          try {
            final data = doc.data();
            final participants = List<String>.from(data['participants'] ?? []);

            final minimalChat = Chat(
              id: doc.id,
              name: data['name']!.toString(),
              participants: participants,
              isGroup: data['isGroup'] as bool? ?? false,
              description: data['description']!.toString(),
              createdBy: data['createdBy']!.toString(),
              createdAt: DateTime.now(),
              lastMessage: data['lastMessage']?.toString() ?? 'Error loading message',
              lastMessageTimestamp: DateTime.now(),
              lastMessageSender: data['lastMessageSender']?.toString() ?? '',
              participantDetails: _createMinimalParticipantDetails(participants),
              unreadCounts: _createMinimalUnreadCounts(participants),
            );

            chats.add(minimalChat);
            print('✅ Created minimal chat object for: ${doc.id}');

          } catch (e2) {
            print('❌ Failed to create even minimal chat for ${doc.id}: $e2');
            // Skip this chat entirely
          }
        }
      }

      print('✅ Force refresh processed ${chats.length} chats');
      _processChatData(chats);

    } catch (e) {
      print('❌ Error in force refresh with error handling: $e');
    }
  }

// Helper methods for minimal chat creation:

  Map<String, ParticipantInfo> _createMinimalParticipantDetails(List<String> participants) {
    Map<String, ParticipantInfo> details = {};

    for (String participantId in participants) {
      details[participantId] = ParticipantInfo(
        id: participantId,
        name: _getDefaultUserName(participantId),
        avatar: _getDefaultUserAvatar(participantId),
        isOnline: false,
      );
    }

    return details;
  }

  Map<String, int> _createMinimalUnreadCounts(List<String> participants) {
    Map<String, int> counts = {};

    for (String participantId in participants) {
      counts[participantId] = 0;
    }

    return counts;
  }

// UPDATE your existing forceRefreshChats method to use the error handling version:

  Future<void> forceRefreshChats() async {
    try {
      print('🔄 Manual refresh requested...');
      connectionStatus.value = 'Refreshing...';

      // Use the error handling version
      await _forceRefreshChatsWithErrorHandling();

      // Wait for the UI to process
      await Future.delayed(Duration(milliseconds: 800));

      connectionStatus.value = 'Connected';

      // if (!_silentMode) {
      //   _showSuccess('Chats refreshed');
      // }

      print('✅ Manual refresh completed');
    } catch (e) {
      connectionStatus.value = 'Connected (Local)';
      print('❌ Error refreshing chats: $e');
    }
  }

  void _clearChatData() {
    personalChats.clear();
    groupChats.clear();
    filteredPersonalChats.clear();
    filteredGroupChats.clear();
    currentMessages.clear();
    currentChatId = null;
    currentChat.value = null;
  }

  // ========== TAB AND SEARCH MANAGEMENT ==========

  void switchTab(int index) {
    selectedTabIndex.value = index;
    print('🔄 Switched to tab $index');
  }

  void updateSearch(String query) {
    searchQuery.value = query;
    _applySearchFilter();
  }

  void _applySearchFilter() {
    if (searchQuery.value.isEmpty) {
      filteredPersonalChats.assignAll(personalChats);
      filteredGroupChats.assignAll(groupChats);
    } else {
      String query = searchQuery.value.toLowerCase();

      filteredPersonalChats.value = personalChats
          .where((chat) => chat.getDisplayName(_consistentUserId).toLowerCase().contains(query))
          .toList();
      filteredGroupChats.value = groupChats
          .where((chat) => chat.getDisplayName(_consistentUserId).toLowerCase().contains(query))
          .toList();
    }
  }

  // ========== MESSAGE MANAGEMENT ==========

  void loadMessages(String chatId) async {
    if (_firebaseService == null) {
      print('❌ Firebase service not available for loading messages');
      _loadMessagesDirectly(chatId);
      return;
    }

    currentChatId = chatId;
    isLoadingMessages.value = true;

    final chat = [...personalChats, ...groupChats].firstWhereOrNull(
          (chat) => chat.id == chatId,
    );
    currentChat.value = chat;

    try {
      // Load messages directly from Firestore
      _loadMessagesDirectly(chatId);

    } catch (e) {
      print('❌ Error in loadMessages: $e');
      isLoadingMessages.value = false;
      currentMessages.clear();
    }
  }



  // Mark chat as read
  Future<void> _markAsRead(String chatId) async {
    try {
      if (_consistentUserId == null) return;

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .update({
        'unreadCounts.$_consistentUserId': 0,
      });
    } catch (e) {
      print('❌ Error marking as read: $e');
    }
  }



  // NEW: Update local chat list immediately after sending a message
  Future<void> _updateLocalChatAfterMessage(String chatId, String lastMessage) async {
    try {
      // Find the chat in personal or group chats
      Chat? targetChat;
      int personalIndex = -1;
      int groupIndex = -1;

      // Check personal chats
      for (int i = 0; i < personalChats.length; i++) {
        if (personalChats[i].id == chatId) {
          targetChat = personalChats[i];
          personalIndex = i;
          break;
        }
      }

      // Check group chats if not found in personal
      if (targetChat == null) {
        for (int i = 0; i < groupChats.length; i++) {
          if (groupChats[i].id == chatId) {
            targetChat = groupChats[i];
            groupIndex = i;
            break;
          }
        }
      }

      if (targetChat != null) {
        // Create updated chat with new last message
        final updatedChat = Chat(
          id: targetChat.id,
          name: targetChat.name,
          participants: targetChat.participants,
          isGroup: targetChat.isGroup,
          description: targetChat.description,
          createdBy: targetChat.createdBy,
          createdAt: targetChat.createdAt,
          lastMessage: lastMessage,
          lastMessageTimestamp: DateTime.now(), // Use current time for immediate update
          lastMessageSender: _consistentUserId!,
          participantDetails: targetChat.participantDetails,
          unreadCounts: targetChat.unreadCounts,
        );

        // Update the appropriate list
        if (personalIndex >= 0) {
          personalChats[personalIndex] = updatedChat;
          personalChats.refresh();
        } else if (groupIndex >= 0) {
          groupChats[groupIndex] = updatedChat;
          groupChats.refresh();
        }

        // Update current chat if it's the same
        if (currentChat.value?.id == chatId) {
          currentChat.value = updatedChat;
        }

        // Apply search filter to update filtered lists
        _applySearchFilter();

        // Force UI refresh
        refreshChatListUI();

        print('✅ Local chat updated immediately after message');
      }
    } catch (e) {
      print('❌ Error updating local chat: $e');
    }
  }



  bool get isFirebaseConnected => _firebaseService?.isConnected ?? false;




  void searchUsers(String query) async {
    if (query.isEmpty) {
      filteredUsers.clear();
      return;
    }

    isSearchingUsers.value = true;

    try {
      // Search in Firestore users collection
      final searchResults = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20)
          .get();

      final users = searchResults.docs.map((doc) {
        final data = doc.data();
        return AppUser(
          id: data['id'] ?? doc.id,
          name: data['name'] ?? 'Unknown',
          email: data['email'] ?? '',
          avatar: data['avatar'] ?? CustomImage.avator,
          isOnline: data['isOnline'] ?? false,
        );
      }).toList();

      filteredUsers.value = users;
      allUsers.assignAll(users);
    } catch (e) {
      print('❌ Error searching users: $e');
      _showError('Failed to search users');
    } finally {
      isSearchingUsers.value = false;
    }
  }

  // Create static user document in Firestore
  Future<void> _createStaticUserInFirestore(String userId, String userName) async {
    try {
      print('📝 Creating static user document in Firestore: $userName');

      final staticUserData = _getStaticUserData(userId);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
        'id': userId,
        'name': staticUserData['name'] ?? userName,
        'email': staticUserData['email'] ?? '$userId@lupuscare.com',
        'avatar': staticUserData['avatar'] ?? CustomImage.avator,
        'isOnline': staticUserData['isOnline'] ?? true,
        'specialty': staticUserData['specialty'] ?? 'Community Member',
        'description': staticUserData['description'] ?? 'Lupus Care community member',
        'isStaticUser': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Static user document created successfully');
    } catch (e) {
      print('❌ Error creating static user document: $e');
    }
  }

  // Get static user data based on ID
  Map<String, dynamic> _getStaticUserData(String userId) {
    final staticPeople = {
      'static_user_1': {
        'name': 'Dr. Sarah Johnson',
        'email': 'dr.sarah@lupuscare.com',
        'avatar': CustomImage.avator,
        'isOnline': false,
        'specialty': 'Rheumatologist',
        'description': 'Lupus specialist with 15+ years experience',
      },
      'static_user_2': {
        'name': 'Emily Rodriguez',
        'email': 'emily.r@lupuscare.com',
        'avatar': CustomImage.avator1,
        'isOnline': false,
        'specialty': 'Patient Advocate',
        'description': 'Living with lupus for 8 years, here to help',
      },
      'static_user_3': {
        'name': 'Dr. Michael Chen',
        'email': 'dr.chen@lupuscare.com',
        'avatar': CustomImage.avator,
        'isOnline': false,
        'specialty': 'Immunologist',
        'description': 'Autoimmune disease researcher and clinician',
      },
      'static_user_4': {
        'name': 'Maria Gonzalez',
        'email': 'maria.g@lupuscare.com',
        'avatar': CustomImage.avator1,
        'isOnline': false,
        'specialty': 'Nutritionist',
        'description': 'Specialized in anti-inflammatory nutrition',
      },
      'static_user_5': {
        'name': 'James Wilson',
        'email': 'james.w@lupuscare.com',
        'avatar': CustomImage.avator,
        'isOnline': false,
        'specialty': 'Support Group Leader',
        'description': 'Caregiver and support group facilitator',
      },
      'static_user_6': {
        'name': 'Dr. Lisa Park',
        'email': 'dr.park@lupuscare.com',
        'avatar': CustomImage.avator1,
        'isOnline': false,
        'specialty': 'Mental Health Counselor',
        'description': 'Specializing in chronic illness mental health',
      },
    };

    return staticPeople[userId] ?? {
      'name': 'Community Member',
      'email': '$userId@lupuscare.com',
      'avatar': CustomImage.avator,
      'isOnline': false,
      'specialty': 'Community Member',
      'description': 'Lupus Care community member',
    };
  }



// 1. FIXED: Enhanced Group Creation Method in ChatController
  Future<void> createGroup() async {
    if (groupName.value.trim().isEmpty) {
      _showError('Please enter a group name');
      return;
    }

    if (selectedMembers.isEmpty) {
      _showError('Please select at least one member');
      return;
    }

    if (_consistentUserId == null) {
      _showError('User not authenticated');
      return;
    }

    isLoading.value = true;
    isCreatingChat.value = true;

    try {
      print('👥 Creating group: ${groupName.value}');
      print('👥 Selected members: ${selectedMembers.length}');

      // CRITICAL: Get all participants with consistent user ID format
      final allParticipants = await _prepareGroupParticipants();
      print('👥 All participants prepared: ${allParticipants.length}');

      // Create group document with comprehensive participant data
      final groupData = await _createGroupDocument(allParticipants);

      // Add group to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('chats')
          .add(groupData);

      print('✅ Group created successfully: ${docRef.id}');

      // CRITICAL: Notify all participants about the new group
      await _notifyParticipantsAboutNewGroup(docRef.id, allParticipants);

      // Add to local list immediately
      await _addNewChatToLocalListImmediate(docRef.id, groupData);

      // Reset form and close
      _resetGroupForm();
      Get.back();

      if (!_silentMode) {
        _showSuccess('Group "${groupName.value}" created successfully!');
      }

    } catch (e) {
      print('❌ Error creating group: $e');
      if (!_silentMode) {
        _showError('Failed to create group: ${e.toString()}');
      }
    } finally {
      isLoading.value = false;
      isCreatingChat.value = false;
    }
  }

// 2. CRITICAL: Prepare group participants with consistent user ID format
  Future<List<Map<String, dynamic>>> _prepareGroupParticipants() async {
    final participants = <Map<String, dynamic>>[];

    try {
      // Add current user first
      participants.add({
        'userId': _consistentUserId!,
        'userData': {
          'id': _consistentUserId!,
          'name': _currentUserData!['full_name']?.toString() ?? 'User',
          'avatar': _currentUserData!['profile_image'] ?? CustomImage.avator,
          'isOnline': true,
          'email': _currentUserData!['email']?.toString() ?? '',
          'isGroupCreator': true,
        }
      });

      // Add selected members with API user ID format
      for (var member in selectedMembers) {
        final apiUserId = member.id; // This should be the API user ID
        final consistentUserId = 'app_user_$apiUserId'; // Convert to consistent format

        participants.add({
          'userId': consistentUserId,
          'userData': {
            'id': consistentUserId,
            'name': member.name,
            'avatar': member.avatar.isNotEmpty ? member.avatar : CustomImage.avator,
            'isOnline': member.isOnline,
            'email': member.email,
            'originalApiId': apiUserId, // Store original API ID for reference
            'isGroupCreator': false,
          }
        });

        print('👤 Added participant: ${member.name} (API: $apiUserId, Consistent: $consistentUserId)');
      }

      return participants;
    } catch (e) {
      print('❌ Error preparing participants: $e');
      throw Exception('Failed to prepare group participants');
    }
  }

// 3. CRITICAL: Create group document with comprehensive participant data
  Future<Map<String, dynamic>> _createGroupDocument(List<Map<String, dynamic>> participants) async {
    try {
      final participantIds = participants.map((p) => p['userId'] as String).toList();
      final participantDetails = <String, dynamic>{};
      final unreadCounts = <String, dynamic>{};

      // Build participant details and unread counts
      for (var participant in participants) {
        final userId = participant['userId'] as String;
        final userData = participant['userData'] as Map<String, dynamic>;

        participantDetails[userId] = userData;
        unreadCounts[userId] = 0;
      }

      final groupData = {
        'name': groupName.value.trim(),
        'description': groupDescription.value.trim(),
        'groupImage': selectedGroupImagePath.value.isNotEmpty
            ? await _processGroupImage(selectedGroupImagePath.value)
            : '',
        'participants': participantIds,
        'isGroup': true,
        'createdBy': _consistentUserId!,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': 'Group created',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSender': _consistentUserId!,
        'participantDetails': participantDetails,
        'unreadCounts': unreadCounts,
        'memberCount': participants.length,
        'groupType': 'created', // Mark as created group vs joined group
        'realTimeSync': true, // Flag for real-time sync
      };

      return groupData;
    } catch (e) {
      print('❌ Error creating group document: $e');
      throw Exception('Failed to create group document');
    }
  }

// 4. CRITICAL: Notify all participants about new group
  Future<void> _notifyParticipantsAboutNewGroup(String groupId, List<Map<String, dynamic>> participants) async {
    try {
      print('🔔 Notifying ${participants.length} participants about new group: $groupId');

      // Create notification documents for each participant
      final batch = FirebaseFirestore.instance.batch();

      for (var participant in participants) {
        final userId = participant['userId'] as String;
        final userData = participant['userData'] as Map<String, dynamic>;

        // Skip current user (creator)
        if (userId == _consistentUserId!) continue;

        // Create a notification document
        final notificationRef = FirebaseFirestore.instance
            .collection('notifications')
            .doc();

        batch.set(notificationRef, {
          'type': 'new_group',
          'groupId': groupId,
          'groupName': groupName.value.trim(),
          'userId': userId,
          'createdBy': _consistentUserId!,
          'createdByName': _currentUserData!['full_name']?.toString() ?? 'User',
          'timestamp': FieldValue.serverTimestamp(),
          'processed': false,
          'forceSync': true, // Force clients to sync
        });

        print('🔔 Created notification for user: ${userData['name']} ($userId)');
      }

      await batch.commit();
      print('✅ All participants notified about new group');

    } catch (e) {
      print('❌ Error notifying participants: $e');
      // Don't throw error as group was created successfully
    }
  }

  bool isOtherParticipantOnline(Chat chat) {
    try {
      if (chat.isGroup) return false;

      for (String participantId in chat.participants) {
        if (participantId != currentUserId) {
          // Check real-time online status
          return isUserActuallyOnline(participantId);
        }
      }
      return false;
    } catch (e) {
      print('❌ Error checking other participant online status: $e');
      return false;
    }
  }

// 2. Update the isUserActuallyOnline method in ChatController:
  bool isUserActuallyOnline(String userId) {
    try {
      // Don't show online status for current user
      if (userId == _consistentUserId) return false;

      // Check cache first
      if (_userOnlineStatus.containsKey(userId)) {
        final isOnline = _userOnlineStatus[userId] ?? false;
        final lastSeen = _userLastSeen[userId];

        if (lastSeen != null) {
          final minutesSinceLastSeen = DateTime.now().difference(lastSeen).inMinutes;

          // Consider user offline if last seen > 3 minutes ago
          if (minutesSinceLastSeen > 3) {
            _userOnlineStatus[userId] = false;
            return false;
          }

          return isOnline;
        }
      }

      // Fetch fresh status if not in cache
      _fetchUserOnlineStatus(userId);

      return false; // Default to offline while fetching
    } catch (e) {
      print('❌ Error checking if user is actually online: $e');
      return false;
    }
  }

  void _fetchUserOnlineStatus(String userId) {
    Future.delayed(Duration.zero, () async {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          final isOnline = data['isOnline'] as bool? ?? false;
          final lastSeenTimestamp = data['lastSeen'] as Timestamp?;
          final lastActivityTimestamp = data['lastActivity'] as Timestamp?;

          if (lastSeenTimestamp != null || lastActivityTimestamp != null) {
            // Use the most recent timestamp
            final lastSeen = lastSeenTimestamp?.toDate() ?? DateTime.now();
            final lastActivity = lastActivityTimestamp?.toDate() ?? DateTime.now();
            final mostRecentActivity = lastActivity.isAfter(lastSeen) ? lastActivity : lastSeen;

            final minutesSinceLastActivity = DateTime.now().difference(mostRecentActivity).inMinutes;

            // User is online if:
            // 1. They're marked as online in Firestore AND
            // 2. Their last activity was less than 3 minutes ago
            final isActuallyOnline = isOnline && minutesSinceLastActivity < 3;

            _userOnlineStatus[userId] = isActuallyOnline;
            _userLastSeen[userId] = mostRecentActivity;

            print('🔄 Updated online status for $userId: $isActuallyOnline (last activity: ${minutesSinceLastActivity}min ago)');

            // Refresh UI if this user is in current chat
            _refreshOnlineStatusUI();
          }
        } else {
          // User document doesn't exist, mark as offline
          _userOnlineStatus[userId] = false;
          _userLastSeen[userId] = DateTime.now();
        }
      } catch (e) {
        print('❌ Error fetching user online status: $e');
        _userOnlineStatus[userId] = false;
      }
    });
  }



  Future<String> _processGroupImage(String imagePath) async {
    try {
      if (imagePath.isEmpty) return '';

      final File imageFile = File(imagePath);
      if (!await imageFile.exists()) return '';

      final bytes = await imageFile.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        throw Exception('Image too large (max 2MB)');
      }

      final base64String = base64Encode(bytes);
      final imageDataUri = 'data:image/jpeg;base64,$base64String';

      return imageDataUri;
    } catch (e) {
      print('❌ Error processing group image: $e');
      return '';
    }
  }

// 9. DEBUGGING: Method to check user ID consistency
  Future<void> debugUserIdConsistency() async {
    try {
      print('🔍 =================== USER ID CONSISTENCY DEBUG ===================');

      final userData = StorageService.to.getUser();
      print('👤 Raw user data: ${userData?.keys}');
      print('👤 User ID from storage: ${userData?['id']}');
      print('👤 Full name: ${userData?['full_name']}');
      print('👤 Email: ${userData?['email']}');

      final consistentId = _generateConsistentUserId(userData ?? {});
      print('👤 Generated consistent ID: $consistentId');

      // Check what chats exist for this user
      final chatsSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: consistentId)
          .get();

      print('📊 Chats found for consistent ID: ${chatsSnapshot.docs.length}');

      for (var doc in chatsSnapshot.docs) {
        final data = doc.data();
        final participants = data['participants'] as List?;
        final isGroup = data['isGroup'] as bool?;
        final name = data['name'] as String?;

        print('📄 Chat: ${doc.id}');
        print('   - Is Group: $isGroup');
        print('   - Name: $name');
        print('   - Participants: $participants');
        print('   - Contains our ID: ${participants?.contains(consistentId)}');
      }

      print('🔍 =================== END USER ID DEBUG ===================');
    } catch (e) {
      print('❌ Error in user ID consistency debug: $e');
    }
  }



  Future<Map<String, dynamic>> testApiHealth() async {
    try {
      print('🏥 Testing API health...');

      final userData = StorageService.to.getUser();
      final token = StorageService.to.getToken();

      if (userData == null || token == null) {
        return {
          'status': 'error',
          'message': 'No authentication data available',
        };
      }

      final userId = userData['id']?.toString() ?? '';

      // Test with a simple request
      final response = await http.post(
        Uri.parse('https://alliedtechnologies.cloud/clients/lupus_care/api/v1/user.php'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'request': 'get_user_profile',
          'user_id': userId,
        },
      );

      print('🏥 Health check response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return {
          'status': 'success',
          'message': 'API is healthy',
          'response': jsonResponse,
        };
      } else {
        return {
          'status': 'error',
          'message': 'API health check failed: ${response.statusCode}',
          'status_code': response.statusCode,
        };
      }

    } catch (e) {
      return {
        'status': 'error',
        'message': 'Health check failed: $e',
      };
    }
  }

// Add a method to create group with minimal data (for testing)
  Future<Map<String, dynamic>> createGroupMinimal({
    required String userId,
    required String groupName,
  }) async {
    try {
      print('📤 Creating group with minimal data...');

      final userData = StorageService.to.getUser();
      final token = StorageService.to.getToken();

      if (userData == null || token == null) {
        throw Exception('No authentication data available');
      }

      final response = await http.post(
        Uri.parse('https://alliedtechnologies.cloud/clients/lupus_care/api/v1/user.php'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'request': 'create_group',
          'user_id': userId,
          'group_name': groupName.trim(),
          'group_description': 'Test group',
          'is_public': '1',
        },
      );

      print('📥 Minimal group creation response: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

    } catch (e) {
      print('❌ Minimal group creation error: $e');
      return {
        'status': 'error',
        'message': e.toString(),
      };
    }
  }





// Update the _getDefaultUserName method to handle API users:
  String _getDefaultUserName(String userId) {
    if (userId == _consistentUserId) {
      return _currentUserData?['full_name']?.toString() ?? 'You';
    }

    return 'Community Member';
  }

// Update the _getDefaultUserAvatar method:
  String _getDefaultUserAvatar(String userId) {
    if (userId == _consistentUserId) {
      return _currentUserData?['profile_image']?.toString() ?? CustomImage.avator;
    }

    return CustomImage.avator;
  }

  void _resetGroupForm() {
    groupName.value = '';
    groupDescription.value = '';
    selectedMembers.clear();

    for (var user in allUsers) {
      user.isSelected = false;
    }
    allUsers.refresh();
    filteredUsers.clear();
  }

  void toggleUserSelection(AppUser user) {
    user.isSelected = !user.isSelected;
    allUsers.refresh();
    filteredUsers.refresh();

    if (user.isSelected) {
      if (!selectedMembers.contains(user)) {
        selectedMembers.add(user);
      }
    } else {
      selectedMembers.remove(user);
    }
  }




  void leaveChatScreen() {
    print('🔄 Leaving chat screen, refreshing chat list...');

    // Clean up current chat state
    currentChatId = null;
    currentChat.value = null;
    _messagesSubscription?.cancel();
    currentMessages.clear();

    // Force refresh the chat list when leaving a chat
    Future.delayed(Duration(milliseconds: 300), () {
      forceRefreshChats().then((_) {
        print('✅ Chat list refreshed after leaving chat screen');
      });
    });
  }

  int getUnreadCount(String chatId) {
    final chat = [...personalChats, ...groupChats].firstWhereOrNull((c) => c.id == chatId);
    return chat?.unreadCount ?? 0;
  }

  String getDisplayName(Chat chat) {
    return chat.getDisplayName(_consistentUserId);
  }

  String? getDisplayAvatar(Chat chat) {
    return chat.getDisplayAvatar(_consistentUserId);
  }

  List<Map<String, dynamic>> get messages {
    return currentMessages.map((msg) => msg.toCompatibleMap(_consistentUserId ?? 'guest_user')).toList();
  }

  void _showSuccess(String message) {
    if (!_silentMode) {
      Get.snackbar(
        'Success',
        message,
        backgroundColor: Colors.green,
        colorText: Colors.white,

      );
    }
  }

  void _showError(String message) {
    if (!_silentMode) {
      Get. snackbar(
        'Error',
        message,
        backgroundColor: Colors.red,
        colorText: Colors.white,

      );
    }
  }

  void setSilentMode(bool silent) {
    _silentMode = silent;
  }

  // Method to refresh user session and migrate chats
  Future<void> refreshUserSession() async {
    print('🔄 Refreshing user session...');

    _currentUserData = StorageService.to.getUser();

    if (_currentUserData != null) {
      _consistentUserId = _generateConsistentUserId(_currentUserData!);
      await _authenticateWithFirebase();
    } else {
      print('❌ No user data found for session refresh');
      _handleOfflineMode();
    }
  }

  // ADD THESE METHODS TO YOUR EXISTING ChatController CLASS

  // Leave group method
  Future<void> leaveGroup(String chatId) async {
    try {
      isLoading.value = true;
      print('🚪 Leaving group: $chatId');

      final userId = currentUserId;
      if (userId == null) {
        _showError('User not authenticated');
        return;
      }

      // Update the chat document to remove user from participants
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .update({
        'participants': FieldValue.arrayRemove([userId]),
        'participantDetails.$userId': FieldValue.delete(),
        'unreadCounts.$userId': FieldValue.delete(),
        'lastMessage': '$currentUserName left the group',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSender': 'system',
      });

      // If currently viewing this chat, go back
      if (currentChatId == chatId) {
        Get.back();
        leaveChatScreen();
      }

      // Remove from local chat lists
      personalChats.removeWhere((chat) => chat.id == chatId);
      groupChats.removeWhere((chat) => chat.id == chatId);
      _applySearchFilter();

      if (!_silentMode) {
        _showSuccess('Left group successfully');
      }

      print('✅ Successfully left group: $chatId');

    } catch (e) {
      print('❌ Error leaving group: $e');
      if (!_silentMode) {
        _showError('Failed to leave group: ${e.toString()}');
      }
    } finally {
      isLoading.value = false;
    }
  }

  // Delete chat method (optional - for clearing chat history)
  Future<void> deleteChat(String chatId) async {
    try {
      isLoading.value = true;
      print('🗑️ Deleting chat: $chatId');

      // Delete all messages in the chat
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      // Delete messages in batches
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Delete the chat document
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .delete();

      // If currently viewing this chat, go back
      if (currentChatId == chatId) {
        Get.back();
        leaveChatScreen();
      }

      // Remove from local chat lists
      personalChats.removeWhere((chat) => chat.id == chatId);
      groupChats.removeWhere((chat) => chat.id == chatId);
      _applySearchFilter();

      if (!_silentMode) {
        _showSuccess('Chat deleted successfully');
      }

      print('✅ Successfully deleted chat: $chatId');

    } catch (e) {
      print('❌ Error deleting chat: $e');
      if (!_silentMode) {
        _showError('Failed to delete chat: ${e.toString()}');
      }
    } finally {
      isLoading.value = false;
    }
  }

  // Clear chat messages method
  Future<void> clearChatMessages(String chatId) async {
    try {
      isLoading.value = true;
      print('🧹 Clearing messages for chat: $chatId');

      // Get all messages
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      // Delete messages in batches
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Update chat's last message
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .update({
        'lastMessage': 'Messages cleared',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSender': 'system',
      });

      // Clear local messages if viewing this chat
      if (currentChatId == chatId) {
        currentMessages.clear();
      }

      // if (!_silentMode) {
      //   _showSuccess('Chat messages cleared');
      // }

      print('✅ Successfully cleared messages for chat: $chatId');

    } catch (e) {
      print('❌ Error clearing chat messages: $e');
      if (!_silentMode) {
        _showError('Failed to clear messages: ${e.toString()}');
      }
    } finally {
      isLoading.value = false;
    }
  }

  // Block user method (for direct chats)
  Future<void> blockUser(String userId) async {
    try {
      isLoading.value = true;
      print('🚫 Blocking user: $userId');

      final currentUser = currentUserId;
      if (currentUser == null) {
        _showError('User not authenticated');
        return;
      }

      // Add to blocked users list in current user's document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser)
          .update({
        'blockedUsers': FieldValue.arrayUnion([userId]),
      });

      // Find and hide chats with this user
      final chatsWithUser = [...personalChats, ...groupChats]
          .where((chat) => chat.participants.contains(userId))
          .toList();

      for (var chat in chatsWithUser) {
        if (!chat.isGroup) {
          // Hide direct chat with blocked user
          personalChats.removeWhere((c) => c.id == chat.id);
        }
      }

      _applySearchFilter();

      if (!_silentMode) {
        _showSuccess('User blocked successfully');
      }

      print('✅ Successfully blocked user: $userId');

    } catch (e) {
      print('❌ Error blocking user: $e');
      if (!_silentMode) {
        _showError('Failed to block user: ${e.toString()}');
      }
    } finally {
      isLoading.value = false;
    }
  }

  // Unblock user method
  Future<void> unblockUser(String userId) async {
    try {
      isLoading.value = true;
      print('✅ Unblocking user: $userId');

      final currentUser = currentUserId;
      if (currentUser == null) {
        _showError('User not authenticated');
        return;
      }

      // Remove from blocked users list
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser)
          .update({
        'blockedUsers': FieldValue.arrayRemove([userId]),
      });

      // Reload chats to show unblocked user's chats
      await refreshChats();

      if (!_silentMode) {
        _showSuccess('User unblocked successfully');
      }

      print('✅ Successfully unblocked user: $userId');

    } catch (e) {
      print('❌ Error unblocking user: $e');
      if (!_silentMode) {
        _showError('Failed to unblock user: ${e.toString()}');
      }
    } finally {
      isLoading.value = false;
    }
  }

  // Get blocked users list
  Future<List<String>> getBlockedUsers() async {
    try {
      final currentUser = currentUserId;
      if (currentUser == null) return [];

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        return List<String>.from(data['blockedUsers'] ?? []);
      }

      return [];
    } catch (e) {
      print('❌ Error getting blocked users: $e');
      return [];
    }
  }

  // Mute/unmute chat notifications
  Future<void> toggleChatMute(String chatId, bool mute) async {
    try {
      final currentUser = currentUserId;
      if (currentUser == null) {
        _showError('User not authenticated');
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser)
          .update({
        'mutedChats.$chatId': mute ? FieldValue.serverTimestamp() : FieldValue.delete(),
      });

      if (!_silentMode) {
        _showSuccess(mute ? 'Chat muted' : 'Chat unmuted');
      }

      print('✅ Chat ${mute ? 'muted' : 'unmuted'}: $chatId');

    } catch (e) {
      print('❌ Error toggling chat mute: $e');
      if (!_silentMode) {
        _showError('Failed to ${mute ? 'mute' : 'unmute'} chat');
      }
    }
  }

  // Check if chat is muted
  Future<bool> isChatMuted(String chatId) async {
    try {
      final currentUser = currentUserId;
      if (currentUser == null) return false;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final mutedChats = data['mutedChats'] as Map<String, dynamic>? ?? {};
        return mutedChats.containsKey(chatId);
      }

      return false;
    } catch (e) {
      print('❌ Error checking if chat is muted: $e');
      return false;
    }
  }




// CORRECTED: Helper method to create basic message when constructor fails
  ChatMessage _createBasicMessage(String docId, Map<String, dynamic> data) {
    return ChatMessage(
      id: docId,
      chatId: data['chatId'] ?? currentChatId ?? '',
      senderId: data['senderId'] ?? 'unknown',
      senderName: data['senderName'] ?? 'Unknown',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: MessageType.text, // Use enum instead of string
      readBy: [], // Add required field
    );
  }

// Add these debug methods to your ChatController class

// Complete Firebase and Authentication Debug
  Future<void> debugFirebaseSetup() async {
    print('🔍 =================== FIREBASE DEBUG ===================');

    try {
      // 1. Check Firebase App
      final app = Firebase.app();
      print('✅ Firebase App: ${app.name}');
      print('📱 App Options: ${app.options.projectId}');

      // 2. Check Authentication
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        print('✅ Firebase Auth User: ${currentUser.uid}');
        print('🔐 Auth Provider: ${currentUser.providerData.map((e) => e.providerId)}');
        print('🔐 Is Anonymous: ${currentUser.isAnonymous}');
      } else {
        print('❌ No Firebase Auth user');
      }

      // 3. Check Firestore Connection
      try {
        final testDoc = await FirebaseFirestore.instance
            .collection('test')
            .doc('connection')
            .get();
        print('✅ Firestore connection working');
      } catch (e) {
        print('❌ Firestore connection error: $e');
      }

      // 4. Check Storage Connection
      try {
        final storageRef = FirebaseStorage.instance.ref();
        print('✅ Storage reference created: ${storageRef.bucket}');

        // Try to list files in root (this tests permissions)
        try {
          final result = await storageRef.list(ListOptions(maxResults: 1));
          print('✅ Storage list operation successful');
        } catch (e) {
          print('⚠️ Storage list failed (might be normal): $e');
        }

      } catch (e) {
        print('❌ Storage connection error: $e');
      }

      // 5. Test Storage Upload with minimal data
      await testMinimalStorageUpload();

    } catch (e) {
      print('❌ Firebase debug error: $e');
    }

    print('🔍 =================== END FIREBASE DEBUG ===================');
  }

// Test minimal storage upload
  Future<void> testMinimalStorageUpload() async {
    try {
      print('🧪 Testing minimal storage upload...');

      // Create minimal test data
      final testData = Uint8List.fromList('test'.codeUnits);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final testPath = 'debug_test/test_$timestamp.txt';

      print('📁 Test path: $testPath');

      // Get storage reference
      final ref = FirebaseStorage.instance.ref().child(testPath);
      print('📍 Storage reference created');

      // Try upload
      final task = ref.putData(testData, SettableMetadata(contentType: 'text/plain'));
      print('⬆️ Upload task created');

      final snapshot = await task;
      print('📊 Upload state: ${snapshot.state}');

      if (snapshot.state == TaskState.success) {
        // Try to get download URL
        final url = await ref.getDownloadURL();
        print('✅ Minimal upload successful!');
        print('🔗 Test URL: $url');

        // Clean up
        try {
          await ref.delete();
          print('🧹 Test file cleaned up');
        } catch (e) {
          print('⚠️ Cleanup failed: $e');
        }

      } else {
        throw Exception('Upload failed with state: ${snapshot.state}');
      }

    } catch (e) {
      print('❌ Minimal storage test failed: $e');
      print('💡 This suggests a storage configuration issue');
    }
  }

// Debug image file before upload
  Future<void> debugImageFile(File imageFile) async {
    try {
      print('🔍 =================== IMAGE FILE DEBUG ===================');

      print('📁 File path: ${imageFile.path}');
      print('📁 File exists: ${await imageFile.exists()}');

      if (await imageFile.exists()) {
        final stats = await imageFile.stat();
        print('📊 File size: ${stats.size} bytes');
        print('📅 Modified: ${stats.modified}');
        print('📝 Type: ${stats.type}');

        // Try to read first few bytes
        try {
          final bytes = await imageFile.readAsBytes();
          print('📄 Bytes length: ${bytes.length}');
          print('📄 First 10 bytes: ${bytes.take(10).toList()}');

          // Check if it looks like a valid image
          if (bytes.length >= 4) {
            final header = bytes.take(4).toList();
            if (header[0] == 0xFF && header[1] == 0xD8) {
              print('✅ Appears to be JPEG format');
            } else if (header[0] == 0x89 && header[1] == 0x50) {
              print('✅ Appears to be PNG format');
            } else {
              print('⚠️ Unknown image format, header: $header');
            }
          }

        } catch (e) {
          print('❌ Cannot read file bytes: $e');
        }
      }

      print('🔍 =================== END IMAGE DEBUG ===================');
    } catch (e) {
      print('❌ Image debug error: $e');
    }
  }

// Fixed upload methods without path dependency

// Upload with debug - NO PATH DEPENDENCY
  Future<String> _uploadImageToFirebaseWithDebug(File imageFile) async {
    try {
      print('☁️ Upload with debug starting...');

      // Extract filename manually without path package
      String originalFileName = imageFile.path.split('/').last;
      if (originalFileName.isEmpty || !originalFileName.contains('.')) {
        originalFileName = 'image.jpg';
      }

      // Create reference
      final fileName = 'chat_images/${DateTime.now().millisecondsSinceEpoch}_$originalFileName';
      final ref = FirebaseStorage.instance.ref().child(fileName);

      print('📁 Upload path: $fileName');
      print('📍 Storage bucket: ${FirebaseStorage.instance.bucket}');

      // Create metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploaded_by': currentUserId ?? 'unknown',
          'chat_id': currentChatId ?? 'unknown',
        },
      );

      print('📝 Metadata: ${metadata.customMetadata}');

      // Start upload
      print('⬆️ Starting putFile...');
      final task = ref.putFile(imageFile, metadata);

      // Monitor progress
      task.snapshotEvents.listen((snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('📊 Progress: ${progress.toStringAsFixed(1)}% (${snapshot.bytesTransferred}/${snapshot.totalBytes})');
      });

      // Wait for completion
      final snapshot = await task;
      print('📋 Final state: ${snapshot.state}');
      print('📋 Total bytes: ${snapshot.totalBytes}');
      print('📋 Metadata: ${snapshot.metadata?.customMetadata}');

      if (snapshot.state == TaskState.success) {
        final url = await ref.getDownloadURL();
        print('🔗 Download URL: $url');
        return url;
      } else {
        throw Exception('Upload state was ${snapshot.state}');
      }

    } catch (e) {
      print('❌ Debug upload error: $e');
      rethrow;
    }
  }

// Main upload method - NO PATH DEPENDENCY
  Future<String> _uploadImageToFirebase(File imageFile) async {
    try {
      print('☁️ Starting Firebase Storage upload...');
      print('📁 File path: ${imageFile.path}');
      print('📁 File exists: ${await imageFile.exists()}');

      // Check if file exists
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist at path: ${imageFile.path}');
      }

      // Get file size
      final fileSize = await imageFile.length();
      print('📊 File size: $fileSize bytes');

      if (fileSize == 0) {
        throw Exception('Image file is empty');
      }

      // Extract filename manually
      String originalFileName = imageFile.path.split('/').last;
      if (originalFileName.isEmpty) {
        originalFileName = 'image.jpg';
      }

      // Ensure proper extension
      if (!originalFileName.toLowerCase().contains('.')) {
        originalFileName += '.jpg';
      }

      // Create unique filename
      final String fileName = 'chat_images/${DateTime.now().millisecondsSinceEpoch}_$originalFileName';
      print('📝 Upload filename: $fileName');

      // Get Firebase Storage reference
      final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      print('📍 Storage reference created: ${storageRef.fullPath}');

      // Prepare upload metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploaded_by': currentUserId ?? 'unknown',
          'chat_id': currentChatId ?? 'unknown_chat',
          'upload_timestamp': DateTime.now().toIso8601String(),
        },
      );

      print('⬆️ Starting file upload...');

      // Upload file
      final UploadTask uploadTask = storageRef.putFile(imageFile, metadata);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('📊 Upload progress: ${progress.toStringAsFixed(1)}%');
      });

      // Wait for upload completion
      final TaskSnapshot snapshot = await uploadTask;
      print('✅ Upload completed. State: ${snapshot.state}');

      // Verify upload was successful
      if (snapshot.state != TaskState.success) {
        throw Exception('Upload failed with state: ${snapshot.state}');
      }

      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      print('🔗 Download URL obtained: $downloadUrl');

      // Verify the URL is accessible
      if (downloadUrl.isEmpty || !downloadUrl.startsWith('http')) {
        throw Exception('Invalid download URL received: $downloadUrl');
      }

      print('✅ Image uploaded successfully to Firebase Storage');
      return downloadUrl;

    } catch (e) {
      print('❌ Firebase Storage upload error: $e');
      print('❌ Error type: ${e.runtimeType}');

      // Provide more specific error messages
      if (e.toString().contains('object-not-found')) {
        throw Exception('Firebase Storage upload failed: Object not found. Check your Firebase Storage setup.');
      } else if (e.toString().contains('unauthorized')) {
        throw Exception('Firebase Storage upload failed: Unauthorized. Check your storage rules.');
      } else if (e.toString().contains('network')) {
        throw Exception('Firebase Storage upload failed: Network error. Check your internet connection.');
      } else {
        throw Exception('Firebase Storage upload failed: $e');
      }
    }
  }

// Bytes upload with debug - NO PATH DEPENDENCY
  Future<String> _uploadImageAsBytesWithDebug(File imageFile) async {
    try {
      print('☁️ Bytes upload with debug starting...');

      final bytes = await imageFile.readAsBytes();
      print('📊 Read ${bytes.length} bytes from file');

      final fileName = 'chat_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);

      print('📁 Upload path: $fileName');

      final task = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final snapshot = await task;

      print('📋 Bytes upload state: ${snapshot.state}');

      if (snapshot.state == TaskState.success) {
        final url = await ref.getDownloadURL();
        print('🔗 Bytes upload URL: $url');
        return url;
      } else {
        throw Exception('Bytes upload state was ${snapshot.state}');
      }

    } catch (e) {
      print('❌ Bytes upload error: $e');
      rethrow;
    }
  }

// Enhanced image processing with extensive debugging - NO PATH DEPENDENCY
  Future<void> _processAndSendImageWithDebug(File imageFile) async {
    try {
      print('🔄 =================== PROCESSING IMAGE WITH DEBUG ===================');

      // Debug the image file first
      await debugImageFile(imageFile);

      // Set sending state
      isSendingMessage.value = true;

      // Check chat state
      if (currentChatId == null || currentChatId!.isEmpty) {
        throw Exception('No active chat selected');
      }
      print('✅ Current chat ID: $currentChatId');

      // Check authentication
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated with Firebase');
      }
      print('✅ Firebase user authenticated: ${currentUser.uid}');

      // Try upload with extensive error handling
      String imageUrl;

      try {
        print('⬆️ Attempting primary upload method...');
        imageUrl = await _uploadImageToFirebaseWithDebug(imageFile);

      } catch (primaryError) {
        print('❌ Primary upload failed: $primaryError');

        try {
          print('⬆️ Attempting alternative upload method...');
          imageUrl = await _uploadImageAsBytesWithDebug(imageFile);

        } catch (altError) {
          print('❌ Alternative upload failed: $altError');
          throw Exception('All upload methods failed. Primary: $primaryError, Alternative: $altError');
        }
      }

      if (imageUrl.isNotEmpty) {
        print('✅ Upload successful, creating message...');

        // Create and send message
        final message = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          chatId: currentChatId!,
          senderId: currentUserId ?? 'unknown',
          senderName: currentUserName ?? 'Unknown User',
          text: imageUrl,
          timestamp: DateTime.now(),
          type: MessageType.image,
          imageUrl: imageUrl,
          readBy: [currentUserId ?? ''],
        );

        currentMessages.add(message);
        await _sendMessageToFirestore(message);

        print('✅ Image message sent successfully!');
      }

    } catch (e) {
      print('❌ Complete process failed: $e');
      print('❌ Stack: ${StackTrace.current}');

      Get.snackbar(
        'Upload Failed',
        'Could not send image: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,

      );

    } finally {
      isSendingMessage.value = false;
      print('🔄 =================== END PROCESSING ===================');
    }
  }

// Simple helper function to extract filename from path
  String _getFileNameFromPath(String filePath) {
    final parts = filePath.split('/');
    if (parts.isNotEmpty) {
      final fileName = parts.last;
      return fileName.isNotEmpty ? fileName : 'image.jpg';
    }
    return 'image.jpg';
  }

// Alternative helper using RegExp if you prefer
  String _extractFileName(String filePath) {
    final regex = RegExp(r'[^/\\]+$');
    final match = regex.firstMatch(filePath);
    return match?.group(0) ?? 'image.jpg';
  }

// Super simple version if you just want basic functionality
  Future<String> _uploadImageSimple(File imageFile) async {
    try {
      // Create simple unique filename
      final fileName = 'chat_images/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload to Firebase Storage
      final ref = FirebaseStorage.instance.ref().child(fileName);
      final task = await ref.putFile(imageFile);

      if (task.state == TaskState.success) {
        return await ref.getDownloadURL();
      } else {
        throw Exception('Upload failed');
      }
    } catch (e) {
      print('❌ Simple upload error: $e');
      throw Exception('Upload failed: $e');
    }
  }



// Call this method when your app starts to check everything
  Future<void> initializeWithFullDebug() async {
    print('🚀 Starting full debug initialization...');

    await debugFirebaseSetup();

    // Also test a minimal upload
    try {
      await testMinimalStorageUpload();
    } catch (e) {
      print('⚠️ Minimal upload test failed: $e');
    }
  }





// Alternative method using bytes (no external dependencies)
  Future<String> _uploadImageAsBytes(File imageFile) async {
    try {
      print('☁️ Starting Firebase Storage upload using bytes...');

      // Read file as bytes
      final Uint8List imageBytes = await imageFile.readAsBytes();
      print('📊 Image bytes length: ${imageBytes.length}');

      if (imageBytes.isEmpty) {
        throw Exception('Image file is empty or could not be read');
      }

      // Create unique filename
      final String fileName = 'chat_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
      print('📝 Upload filename: $fileName');

      // Get Firebase Storage reference
      final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

      // Upload bytes
      final UploadTask uploadTask = storageRef.putData(
        imageBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploaded_by': currentUserId ?? 'unknown',
            'chat_id': currentChatId ?? 'unknown_chat',
          },
        ),
      );

      // Wait for completion
      final TaskSnapshot snapshot = await uploadTask;

      if (snapshot.state != TaskState.success) {
        throw Exception('Upload failed with state: ${snapshot.state}');
      }

      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      print('✅ Image uploaded successfully using bytes method');

      return downloadUrl;

    } catch (e) {
      print('❌ Bytes upload error: $e');
      throw Exception('Failed to upload image as bytes: $e');
    }
  }

// Updated _processAndSendImage method
  Future<void> _processAndSendImage(File imageFile) async {
    try {
      print('🔄 Processing image for sending...');
      print('📁 Original file path: ${imageFile.path}');

      // Set sending state
      isSendingMessage.value = true;

      // Check if we have a valid chat ID
      if (currentChatId == null || currentChatId!.isEmpty) {
        throw Exception('No active chat selected');
      }

      // Verify file exists and is readable
      if (!await imageFile.exists()) {
        throw Exception('Selected image file no longer exists');
      }

      final fileSize = await imageFile.length();
      print('📊 Image file size: $fileSize bytes');

      if (fileSize == 0) {
        throw Exception('Selected image file is empty');
      }

      if (fileSize > 10 * 1024 * 1024) { // 10MB limit
        throw Exception('Image file is too large (max 10MB)');
      }

      String imageUrl;

      try {
        // Try the primary upload method
        imageUrl = await _uploadImageToFirebase(imageFile);
      } catch (e) {
        print('⚠️ Primary upload failed, trying alternative method...');

        try {
          // Try alternative upload method
          imageUrl = await _uploadImageAsBytes(imageFile);
        } catch (altError) {
          print('❌ Alternative upload also failed: $altError');
          throw Exception('All upload methods failed. Last error: $altError');
        }
      }

      if (imageUrl.isNotEmpty) {
        print('✅ Image uploaded successfully: $imageUrl');

        // Create message
        final message = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          chatId: currentChatId!,
          senderId: currentUserId ?? 'unknown',
          senderName: currentUserName ?? 'Unknown User',
          text: imageUrl, // Store URL in text for fallback
          timestamp: DateTime.now(),
          type: MessageType.image,
          imageUrl: imageUrl, // Store in dedicated field
          readBy: [currentUserId ?? ''],
        );

        print('📝 Created image message: ${message.id}');

        // Add to local messages for immediate display
        currentMessages.add(message);
        currentMessages.refresh();

        // Send to Firestore
        await _sendMessageToFirestore(message);

        // Update local chat after message
        if (currentChatId != null) {
          await _updateLocalChatAfterMessage(currentChatId!, '📷 Image');
        }

        print('✅ Image message sent successfully');
      } else {
        throw Exception('Upload completed but no URL was returned');
      }

    } catch (e) {
      print('❌ Error processing image: $e');
      print('❌ Stack trace: ${StackTrace.current}');

      // Show user-friendly error message
      String userMessage = 'Failed to send image';

      if (e.toString().contains('No active chat')) {
        userMessage = 'Please select a chat first';
      } else if (e.toString().contains('no longer exists')) {
        userMessage = 'Image file no longer exists. Please try again.';
      } else if (e.toString().contains('too large')) {
        userMessage = 'Image is too large. Please choose a smaller image.';
      } else if (e.toString().contains('Storage')) {
        userMessage = 'Upload failed. Please check your internet connection.';
      } else if (e.toString().contains('unauthorized')) {
        userMessage = 'Upload permission denied. Please contact support.';
      }

      Get.snackbar(
        'Error',
        userMessage,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isSendingMessage.value = false;
    }
  }

// Test method to check if Firebase Storage is working
  Future<void> testFirebaseStorage() async {
    try {
      print('🧪 Testing Firebase Storage...');

      // Create a simple test file
      final testData = Uint8List.fromList('Hello Firebase Storage'.codeUnits);
      final testFileName = 'test/storage_test_${DateTime.now().millisecondsSinceEpoch}.txt';

      final ref = FirebaseStorage.instance.ref().child(testFileName);

      // Upload test data
      final uploadTask = await ref.putData(testData);

      if (uploadTask.state == TaskState.success) {
        final downloadUrl = await ref.getDownloadURL();
        print('✅ Firebase Storage test successful!');
        print('🔗 Test URL: $downloadUrl');

        // Clean up test file
        try {
          await ref.delete();
          print('🧹 Test file deleted');
        } catch (e) {
          print('⚠️ Could not delete test file: $e');
        }

      } else {
        print('❌ Firebase Storage test failed with state: ${uploadTask.state}');
      }

    } catch (e) {
      print('❌ Firebase Storage test error: $e');

      if (e.toString().contains('unauthorized')) {
        print('💡 This suggests your Firebase Storage rules need to be updated');
      } else if (e.toString().contains('object-not-found')) {
        print('💡 This suggests Firebase Storage is not properly configured');
      }
    }
  }


  bool isUserOnlineInChat(Chat chat, String? targetUserId) {
    try {
      if (targetUserId == null) return false;

      // Use the actual online status checker instead of stored value
      final isOnline = isUserActuallyOnline(targetUserId);

      print('🔍 Checking online status for $targetUserId: $isOnline');
      return isOnline;

    } catch (e) {
      print('❌ Error checking user online status: $e');
      return false;
    }
  }


  String? getOtherParticipantId(Chat chat) {
    try {
      if (chat.isGroup) return null;
      for (String participantId in chat.participants) {
        if (participantId != currentUserId) {
          return participantId;
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting other participant: $e');
      return null;
    }
  }

  void _refreshOnlineStatusUI() {
    try {
      // Small delay to prevent too frequent updates
      Timer(Duration(milliseconds: 500), () {
        update(); // Update GetX controller

        // If currently viewing a chat, refresh the specific UI elements
        if (currentChat.value != null) {
          currentChat.refresh();
        }
      });
    } catch (e) {
      print('❌ Error refreshing online status UI: $e');
    }
  }


  Future<void> sendImageFromCamera() async {
    try {
      print('📷 Starting camera image capture...');

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50, // Lower quality for camera images
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image != null) {
        print('✅ Image captured: ${image.path}');
        await _processAndSendImageAsBase64(File(image.path));
      } else {
        print('❌ No image captured');
      }
    } catch (e) {
      print('❌ Error capturing image: $e');
      Get.snackbar(
        'Camera Error',
        'Failed to capture image: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }


  Future<void> _processAndSendImageAsBase64(File imageFile) async {
    try {
      print('🔄 Processing image as Base64...');

      if (currentChatId == null || currentChatId!.isEmpty) {
        throw Exception('No active chat selected');
      }

      isSendingMessage.value = true;

      if (!await imageFile.exists()) {
        throw Exception('Image file not found');
      }

      final Uint8List imageBytes = await imageFile.readAsBytes();
      print('📊 Image size: ${imageBytes.length} bytes');

      if (imageBytes.length > 800000) { // ~800KB limit
        throw Exception('Image too large (${(imageBytes.length / 1024).toInt()}KB). Please choose a smaller image.');
      }

      final String base64Image = base64Encode(imageBytes);
      final String imageDataUri = 'data:image/jpeg;base64,$base64Image';

      print('✅ Base64 conversion complete. Data URI length: ${imageDataUri.length}');

      // Create message with proper properties
      final message = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        chatId: currentChatId!,
        senderId: currentUserId ?? 'unknown',
        senderName: currentUserName ?? 'Unknown User',
        text: '📷 Image', // Display text
        timestamp: DateTime.now(),
        type: MessageType.image,
        imageUrl: imageDataUri, // Store base64 data URI
        readBy: [currentUserId ?? ''],
        // These properties are now optional and will be null for image messages
        fileSize: imageBytes.length, // Store actual file size
        mimeType: 'image/jpeg', // Store MIME type
      );

      print('📝 Created image message:');
      print('   - ID: ${message.id}');
      print('   - Type: ${message.type}');
      print('   - ImageUrl length: ${message.imageUrl?.length ?? 0}');
      print('   - IsImageMessage: ${message.isImageMessage}');
      print('   - File size: ${message.fileSize}');
      print('   - MIME type: ${message.mimeType}');

      // Add to local messages
      currentMessages.add(message);
      currentMessages.refresh();

      // Send to Firestore
      await _sendMessageToFirestore(message);

      // Update local chat
      await _updateLocalChatAfterMessage(currentChatId!, '📷 Image');

      print('✅ Base64 image message sent successfully');

      if (!_silentMode) {
        Get.snackbar(
          'Success',
          'Image sent successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 2),
        );
      }

    } catch (e) {
      print('❌ Error processing Base64 image: $e');

      String userMessage = 'Failed to send image';
      if (e.toString().contains('too large')) {
        userMessage = e.toString();
      } else if (e.toString().contains('No active chat')) {
        userMessage = 'Please select a chat first';
      } else if (e.toString().contains('not found')) {
        userMessage = 'Image file not found. Please try again.';
      }

      Get.snackbar(
        'Error',
        userMessage,
        backgroundColor: Colors.red,
        colorText: Colors.white,

      );
    } finally {
      isSendingMessage.value = false;
    }
  }



// Method to check Firebase Storage configuration
  Future<void> testFirebaseStorageConnection() async {
    try {
      print('🧪 Testing Firebase Storage connection...');

      // Create a small test file
      final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
      final testRef = FirebaseStorage.instance.ref().child('test/connection_test.dat');

      // Try to upload test data
      final uploadTask = await testRef.putData(testData);

      if (uploadTask.state == TaskState.success) {
        // Try to get download URL
        final downloadUrl = await testRef.getDownloadURL();
        print('✅ Firebase Storage test successful');
        print('🔗 Test URL: $downloadUrl');

        // Clean up test file
        try {
          await testRef.delete();
          print('🧹 Test file cleaned up');
        } catch (e) {
          print('⚠️ Could not delete test file: $e');
        }

        return;
      } else {
        throw Exception('Test upload failed with state: ${uploadTask.state}');
      }

    } catch (e) {
      print('❌ Firebase Storage test failed: $e');
      throw Exception('Firebase Storage is not properly configured: $e');
    }
  }



// Updated _messageFromDocument method
  ChatMessage? _messageFromDocument(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;

      print('🔧 Converting Firestore document to ChatMessage: ${doc.id}');
      print('📄 Raw data keys: ${data.keys.toList()}');
      print('📄 Type field: ${data['type']}');
      print('📄 ImageUrl field: ${data['imageUrl']}');
      print('📄 Text field: ${data['text']}');

      // Use the factory constructor from ChatMessage
      final message = ChatMessage.fromMap(data, doc.id);

      print('✅ Successfully created ChatMessage:');
      print('   - ID: ${message.id}');
      print('   - Type: ${message.type}');
      print('   - HasMedia: ${message.hasMedia}');
      print('   - ImageURL: ${message.imageUrl}');
      print('   - IsImageMessage: ${message.isImageMessage}');

      return message;

    } catch (e) {
      print('❌ Error converting message document ${doc.id}: $e');
      print('❌ Document data: ${doc.data()}');
      return null;
    }
  }



  Future<void> _sendMessageToFirestore(ChatMessage message) async {
    try {
      print('📤 Sending message to Firestore: ${message.id}');
      print('📤 Message type: ${message.type}');
      print('📤 Message hasMedia: ${message.hasMedia}');
      print('📤 ImageUrl present: ${message.imageUrl != null && message.imageUrl!.isNotEmpty}');

      // Use the toMap method from ChatMessage which handles all fields properly
      final messageData = message.toMap();

      print('📤 Firestore data keys: ${messageData.keys.toList()}');

      // Send to Firestore
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(message.chatId)
          .collection('messages')
          .doc(message.id)
          .set(messageData);

      // Update chat's last message using displayText
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(message.chatId)
          .update({
        'lastMessage': message.displayText,
        'lastMessageTimestamp': Timestamp.fromDate(message.timestamp),
        'lastMessageSender': message.senderId,
      });

      print('✅ Message sent to Firestore successfully');

      // Send notifications to other participants
      await _sendNotificationToParticipants(message);

    } catch (e) {
      print('❌ Error sending message to Firestore: $e');
      print('❌ Stack trace: ${StackTrace.current}');

      // Check if it's a size limit error
      if (e.toString().contains('maximum size') || e.toString().contains('too large')) {
        throw Exception('Image too large for Firestore. Please choose a smaller image.');
      }

      throw Exception('Failed to send message: $e');
    }
  }

  Future<void> _sendNotificationToParticipants(ChatMessage message) async {
    try {
      print('🔔 Sending notifications to participants...');

      // Get current chat
      final chat = currentChat.value;
      if (chat == null) {
        print('⚠️ No current chat for notifications');
        return;
      }

      // Get notification service
      if (!Get.isRegistered<NotificationService>()) {
        print('⚠️ NotificationService not registered');
        return;
      }

      final notificationService = Get.find<NotificationService>();

      // Get current user info
      final currentUserId = _consistentUserId;
      final currentUserName = _currentUserData?['full_name']?.toString() ?? 'Someone';

      if (currentUserId == null) {
        print('⚠️ No current user ID for notifications');
        return;
      }

      // Get other participants (exclude current user)
      final otherParticipants = chat.participants
          .where((participantId) => participantId != currentUserId)
          .toList();

      if (otherParticipants.isEmpty) {
        print('⚠️ No other participants to notify');
        return;
      }

      print('📤 Sending notifications to ${otherParticipants.length} participants');

      // Prepare notification content
      String notificationTitle;
      String notificationBody;

      if (chat.isGroup) {
        notificationTitle = chat.name.isNotEmpty ? chat.name : 'Group Chat';
        notificationBody = '$currentUserName: ${_getNotificationBody(message)}';
      } else {
        notificationTitle = currentUserName;
        notificationBody = _getNotificationBody(message);
      }

      // Send notifications to all participants
      await notificationService.sendNotificationToUsers(
        userIds: otherParticipants,
        title: notificationTitle,
        body: notificationBody,
        chatId: chat.id,
        senderId: currentUserId,
        senderName: currentUserName,
      );

      print('✅ Notifications sent successfully');

    } catch (e) {
      print('❌ Error sending notifications: $e');
      // Don't throw error here as message was already sent successfully
    }
  }


  String _getNotificationBody(ChatMessage message) {
    switch (message.type) {
      case MessageType.text:
        return message.text.length > 100
            ? '${message.text.substring(0, 100)}...'
            : message.text;
      case MessageType.image:
        return '📷 Sent a photo';
      case MessageType.video:
        return '🎥 Sent a video';
      case MessageType.audio:
        return '🎵 Sent an audio';
      case MessageType.file:
        return '📄 Sent a file';
      default:
        return 'Sent a message';
    }
  }


  /// Handle notification when app is opened from notification
  Future<void> handleNotificationOpened(Map<String, dynamic> data) async {
    try {
      print('📱 Handling notification opened from ChatController');
      print('📱 Data: $data');

      final chatId = data['chatId'] as String?;
      final senderId = data['senderId'] as String?;

      if (chatId != null) {
        // Find the chat in our lists
        final chat = [...personalChats, ...groupChats]
            .firstWhereOrNull((c) => c.id == chatId);

        if (chat != null) {
          // Load messages for this chat
          loadMessages(chatId);

          // Navigate to chat screen if not already there
          if (Get.currentRoute != '/chat_screen') {
            Get.toNamed('/chat_screen', arguments: {
              'chat': chat,
              'chatId': chatId,
            });
          }
        } else {
          print('⚠️ Chat not found in local lists: $chatId');
          // Force refresh chats and try again
          await forceRefreshChats();

          // Try to find chat again after refresh
          final refreshedChat = [...personalChats, ...groupChats]
              .firstWhereOrNull((c) => c.id == chatId);

          if (refreshedChat != null) {
            loadMessages(chatId);
            if (Get.currentRoute != '/chat_screen') {
              Get.toNamed('/chat_screen', arguments: {
                'chat': refreshedChat,
                'chatId': chatId,
              });
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error handling notification opened: $e');
    }
  }

  /// Initialize user FCM token
  Future<void> _initializeUserFCMToken() async {
    try {
      print('🔑 Initializing user FCM token...');



      final notificationService = Get.find<NotificationService>();
      final currentUserId = _consistentUserId;

      if (currentUserId == null) {
        print('⚠️ No current user ID for FCM token');
        return;
      }

      // Wait for FCM token to be available
      int attempts = 0;
      const maxAttempts = 10;

      while (notificationService.currentFCMToken.isEmpty && attempts < maxAttempts) {
        await Future.delayed(Duration(milliseconds: 500));
        attempts++;
      }

      if (notificationService.currentFCMToken.isNotEmpty) {
        // Store FCM token in user document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .update({
          'fcmToken': notificationService.currentFCMToken,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          'platform': Platform.isAndroid ? 'android' : 'ios',
        });

        print('✅ FCM token stored for user: $currentUserId');
      } else {
        print('⚠️ FCM token not available after waiting');
      }

    } catch (e) {
      print('❌ Error initializing user FCM token: $e');
    }
  }



  /// Clear FCM token on logout
  Future<void> clearNotificationToken() async {
    try {
      print('🧹 Clearing notification token...');

      if (Get.isRegistered<NotificationService>()) {
        final notificationService = Get.find<NotificationService>();
        await notificationService.clearFCMToken();
      }

      print('✅ Notification token cleared');
    } catch (e) {
      print('❌ Error clearing notification token: $e');
    }
  }

  /// Updated signOut method to clear FCM token
  Future<void> signOut() async {
    try {
      // Clear FCM token first
      await clearNotificationToken();

      await FirebaseAuth.instance.signOut();
      _clearChatData();
      _currentUserData = null;
      _consistentUserId = null;
      isConnected.value = true;
      connectionStatus.value = 'Connected (Local)';

      print('✅ Signed out successfully');
    } catch (e) {
      print('❌ Error signing out: $e');
    }
  }



  /// Request notification permissions
  Future<void> requestNotificationPermissions() async {
    try {
      if (Get.isRegistered<NotificationService>()) {
        final notificationService = Get.find<NotificationService>();
        await notificationService.initializeNotifications();
      }
    } catch (e) {
      print('❌ Error requesting notification permissions: $e');
    }
  }



  String getGroupImageForChatList(Chat chat) {
    try {
      print('🖼️ Getting group image for chat list: ${chat.id}');
      print('   Is Group: ${chat.isGroup}');
      print('   Chat Name: ${chat.name}');

      if (!chat.isGroup) {
        return getPersonalChatDisplayImage(chat);
      }

      // Get group image from chat object
      final groupImage = chat.groupImage;
      print('   Raw group image: ${groupImage?.length ?? 0} chars');
      print('   Image type: ${_getImageType(groupImage)}');

      // Return the image if it exists and is valid
      if (groupImage != null && groupImage.isNotEmpty) {
        // Base64 image
        if (groupImage.startsWith('data:image')) {
          print('📸 Returning base64 group image');
          return groupImage;
        }
        // HTTP URL
        else if (groupImage.startsWith('http')) {
          print('🌐 Returning HTTP group image');
          return groupImage;
        }
        // Local file path
        else if (groupImage.contains('/') && !groupImage.contains('assets/')) {
          print('📁 Returning local file group image');
          return groupImage;
        }
      }

      // Fallback: Try to get from Firestore if not in local chat object
      if (groupImage == null || groupImage.isEmpty) {
        print('⚠️ No group image in chat object, will use default');
        // Optionally trigger a background refresh
        _refreshGroupImageFromFirestore(chat.id);
      }

      // Return default group image
      print('📁 Returning default group image');
      return CustomImage.userGroup;

    } catch (e) {
      print('❌ Error getting group image for chat list: $e');
      return CustomImage.userGroup;
    }
  }

// Background method to refresh group image from Firestore
  void _refreshGroupImageFromFirestore(String chatId) {
    // Don't block the UI, do this in background
    Future.delayed(Duration.zero, () async {
      try {
        print('🔄 Background refresh of group image for: $chatId');

        final chatDoc = await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .get();

        if (chatDoc.exists && chatDoc.data() != null) {
          final data = chatDoc.data()!;
          final firestoreGroupImage = data['groupImage']?.toString() ?? '';

          if (firestoreGroupImage.isNotEmpty) {
            print('✅ Found group image in Firestore, updating local chat');
            await _updateLocalChatGroupImageComprehensive(chatId, firestoreGroupImage);
          }
        }
      } catch (e) {
        print('❌ Error in background group image refresh: $e');
      }
    });
  }

// ENHANCED: Method to ensure chat list shows updated group images
  void forceRefreshChatListImages() {
    try {
      print('🔄 Force refreshing chat list images...');

      // Trigger refresh of all reactive lists
      personalChats.refresh();
      groupChats.refresh();
      filteredPersonalChats.refresh();
      filteredGroupChats.refresh();

      // Force UI update
      update();

      print('✅ Chat list images refreshed');
    } catch (e) {
      print('❌ Error refreshing chat list images: $e');
    }
  }

// ENHANCED: Method to update group image and immediately reflect in chat list
  Future<void> updateGroupImageAndRefreshList(String chatId, String newImageData) async {
    try {
      print('🔄 Updating group image and refreshing list...');
      print('   Chat ID: $chatId');
      print('   Image type: ${_getImageType(newImageData)}');

      // Update the image in Firestore
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .update({
        'groupImage': newImageData,
        'imageUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Update local chat data immediately
      await _updateLocalChatGroupImageComprehensive(chatId, newImageData);

      // Force refresh the UI
      forceRefreshChatListImages();

      // Small delay then refresh again to ensure it's visible
      Future.delayed(Duration(milliseconds: 500), () {
        forceRefreshChatListImages();
      });

      print('✅ Group image updated and chat list refreshed');

    } catch (e) {
      print('❌ Error updating group image and refreshing list: $e');
    }
  }

// DEBUGGING: Method to check group image status
  void debugGroupImageInChatList(String chatId) {
    try {
      print('🔍 =================== GROUP IMAGE DEBUG ===================');
      print('🔍 Debugging group image for chat: $chatId');

      // Find the chat in our lists
      Chat? foundChat;
      String foundIn = '';

      for (var chat in personalChats) {
        if (chat.id == chatId) {
          foundChat = chat;
          foundIn = 'personalChats';
          break;
        }
      }

      if (foundChat == null) {
        for (var chat in groupChats) {
          if (chat.id == chatId) {
            foundChat = chat;
            foundIn = 'groupChats';
            break;
          }
        }
      }

      if (foundChat != null) {
        print('✅ Found chat in: $foundIn');
        print('   - Chat ID: ${foundChat.id}');
        print('   - Is Group: ${foundChat.isGroup}');
        print('   - Group Image: ${foundChat.groupImage?.length ?? 0} chars');
        print('   - Image Type: ${_getImageType(foundChat.groupImage)}');

        if (foundChat.groupImage != null && foundChat.groupImage!.isNotEmpty) {
          final preview = foundChat.groupImage!.length > 100
              ? '${foundChat.groupImage!.substring(0, 100)}...'
              : foundChat.groupImage!;
          print('   - Image Preview: $preview');
        }

        // Test the display method
        final displayImage = getGroupImageForChatList(foundChat);
        print('   - Display Image: ${displayImage.length > 50 ? "${displayImage.substring(0, 50)}..." : displayImage}');

      } else {
        print('❌ Chat not found in local lists');
        print('   - Personal chats: ${personalChats.length}');
        print('   - Group chats: ${groupChats.length}');
      }

      print('🔍 =================== END GROUP IMAGE DEBUG ===================');

    } catch (e) {
      print('❌ Error in group image debug: $e');
    }
  }

// TESTING: Method to verify group image is working
  Future<void> testGroupImageInChatList(String chatId) async {
    try {
      print('🧪 Testing group image in chat list for: $chatId');

      // Debug current state
      debugGroupImageInChatList(chatId);

      // Try to refresh from Firestore
      await refreshGroupImageFromFirestore(chatId);

      // Wait a moment
      await Future.delayed(Duration(milliseconds: 500));

      // Debug again
      debugGroupImageInChatList(chatId);

      // Force refresh UI
      forceRefreshChatListImages();

      print('✅ Group image test completed');

    } catch (e) {
      print('❌ Error in group image test: $e');
    }
  }


  final Map<String, String> _groupImageCache = {};


// 2. FIXED: Stable group display image method with caching
  String getGroupDisplayImageStable(Chat chat) {
    try {
      print('🖼️ Getting STABLE group display image for chat: ${chat.id}');
      print('   Is Group: ${chat.isGroup}');
      print('   Chat Name: ${chat.name}');

      if (!chat.isGroup) {
        return getPersonalChatDisplayImage(chat);
      }

      final chatId = chat.id;

      // Check cache first (prevents loss during rebuilds)
      if (_groupImageCache.containsKey(chatId)) {
        final cachedImage = _groupImageCache[chatId]!;
        final cacheTime = _groupImageCacheTimestamp[chatId]!;

        // Use cache if less than 5 minutes old
        if (DateTime.now().difference(cacheTime).inMinutes < 5 && cachedImage.isNotEmpty) {
          print('📦 Using cached group image (${cachedImage.length} chars)');
          return cachedImage;
        }
      }

      // Get group image from chat object
      String groupImage = chat.groupImage ?? '';

      print('   Raw group image: ${groupImage.length} chars');
      print('   Image type: ${_getImageType(groupImage)}');

      // Validate and cache the image
      if (groupImage.isNotEmpty && _isValidImageData(groupImage)) {
        print('📦 Caching valid group image');
        _groupImageCache[chatId] = groupImage;
        _groupImageCacheTimestamp[chatId] = DateTime.now();

        print('📸 Returning valid group image');
        return groupImage;
      }

      // If no valid image in chat object, try to get from Firestore
      print('⚠️ No valid image in chat object, checking Firestore...');
      _fetchAndCacheGroupImageFromFirestore(chatId);

      // Return default while fetching
      print('📁 Returning default group image');
      return CustomImage.userGroup;

    } catch (e) {
      print('❌ Error getting stable group display image: $e');
      return CustomImage.userGroup;
    }
  }

// 3. Helper method to validate image data
  bool _isValidImageData(String imageData) {
    if (imageData.isEmpty || imageData == 'null' || imageData == 'undefined') {
      return false;
    }

    // Check for valid image formats
    return imageData.startsWith('data:image') ||
        imageData.startsWith('http') ||
        imageData.startsWith('assets/') ||
        imageData.startsWith('local:') ||
        imageData.length > 100; // Assume long strings are base64
  }

// 4. Background method to fetch and cache image from Firestore
  void _fetchAndCacheGroupImageFromFirestore(String chatId) {
    // Don't block the UI, fetch in background
    Future.delayed(Duration.zero, () async {
      try {
        print('🔍 Background fetch of group image for: $chatId');

        final doc = await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final firestoreImage = data['groupImage']?.toString() ?? '';

          if (firestoreImage.isNotEmpty && _isValidImageData(firestoreImage)) {
            print('✅ Found valid image in Firestore, updating cache');

            // Update cache
            _groupImageCache[chatId] = firestoreImage;
            _groupImageCacheTimestamp[chatId] = DateTime.now();

            // Update local chat data
            await updateLocalChatGroupImageStable(chatId, firestoreImage);

            print('✅ Background fetch completed');
          }
        }
      } catch (e) {
        print('❌ Error in background fetch: $e');
      }
    });
  }

// 5. STABLE update method that preserves data during rebuilds
  Future<void> updateLocalChatGroupImageStable(String chatId, String newImageData) async {
    try {
      print('🔄 STABLE update of local chat group image...');
      print('   Target chat ID: $chatId');
      print('   New image type: ${_getImageType(newImageData)}');

      if (!_isValidImageData(newImageData)) {
        print('❌ Invalid image data, skipping update');
        return;
      }

      // Update cache immediately
      _groupImageCache[chatId] = newImageData;
      _groupImageCacheTimestamp[chatId] = DateTime.now();

      bool foundAndUpdated = false;

      // Update in personal chats with stability check
      for (int i = 0; i < personalChats.length; i++) {
        final chat = personalChats[i];
        if (chat.id == chatId || chat.apiGroupId == chatId) {
          if (chat.groupImage != newImageData) {
            print('🎯 Updating chat in personalChats at index $i');

            final updatedChat = _createStableChatWithImage(chat, newImageData);
            personalChats[i] = updatedChat;
            foundAndUpdated = true;
          }
          break;
        }
      }

      // Update in group chats with stability check
      for (int i = 0; i < groupChats.length; i++) {
        final chat = groupChats[i];
        if (chat.id == chatId || chat.apiGroupId == chatId) {
          if (chat.groupImage != newImageData) {
            print('🎯 Updating chat in groupChats at index $i');

            final updatedChat = _createStableChatWithImage(chat, newImageData);
            groupChats[i] = updatedChat;
            foundAndUpdated = true;
          }
          break;
        }
      }

      // Update current chat with stability check
      if (currentChat.value != null) {
        final currentChatValue = currentChat.value!;
        if ((currentChatValue.id == chatId || currentChatValue.apiGroupId == chatId) &&
            currentChatValue.groupImage != newImageData) {
          print('🎯 Updating current chat');

          final updatedCurrentChat = _createStableChatWithImage(currentChatValue, newImageData);
          currentChat.value = updatedCurrentChat;
          foundAndUpdated = true;
        }
      }

      if (foundAndUpdated) {
        // Controlled refresh to prevent loss
        _stableUIRefresh();
        print('✅ STABLE update completed successfully');
      }

    } catch (e) {
      print('❌ Error in stable update: $e');
    }
  }

// 6. Create stable chat with image
  Chat _createStableChatWithImage(Chat originalChat, String newImageData) {
    return Chat(
      id: originalChat.id,
      name: originalChat.name,
      participants: originalChat.participants,
      isGroup: originalChat.isGroup,
      description: originalChat.description,
      createdBy: originalChat.createdBy,
      createdAt: originalChat.createdAt,
      lastMessage: originalChat.lastMessage,
      lastMessageTimestamp: originalChat.lastMessageTimestamp,
      lastMessageSender: originalChat.lastMessageSender,
      participantDetails: originalChat.participantDetails,
      unreadCounts: originalChat.unreadCounts,
      groupImage: newImageData, // Stable image update
      apiGroupId: originalChat.apiGroupId,
    );
  }

// 7. STABLE UI refresh that prevents data loss
  void _stableUIRefresh() {
    try {
      print('🎨 Performing STABLE UI refresh...');

      // Delay refresh to prevent race conditions
      Timer(Duration(milliseconds: 100), () {
        try {
          personalChats.refresh();
          groupChats.refresh();

          // Update filtered lists
          _applySearchFilter();

          // Gentle update without forcing
          update();

          print('✅ STABLE UI refresh completed');
        } catch (e) {
          print('❌ Error in delayed refresh: $e');
        }
      });

    } catch (e) {
      print('❌ Error in stable UI refresh: $e');
    }
  }

// 8. Method to clear cache when needed
  void clearGroupImageCache() {
    print('🧹 Clearing group image cache');
    _groupImageCache.clear();
    _groupImageCacheTimestamp.clear();
  }

// 9. Method to get cached image directly
  String? getCachedGroupImage(String chatId) {
    if (_groupImageCache.containsKey(chatId)) {
      final cachedImage = _groupImageCache[chatId]!;
      final cacheTime = _groupImageCacheTimestamp[chatId]!;

      // Return cache if less than 5 minutes old
      if (DateTime.now().difference(cacheTime).inMinutes < 5) {
        return cachedImage;
      }
    }
    return null;
  }

// 10. REPLACE your existing onGroupImageUpdatedFromGroupController with this stable version
  Future<void> onGroupImageUpdatedFromGroupControllerStable(String chatId, String newImageData) async {
    try {
      print('🔄 ChatController: STABLE group image update notification');
      print('   Chat ID: $chatId');
      print('   New image data type: ${newImageData.startsWith('data:image') ? 'Base64' : 'URL'}');
      print('   Image data length: ${newImageData.length}');

      // Validate the image data first
      if (!_isValidImageData(newImageData)) {
        print('❌ Invalid image data received, ignoring update');
        return;
      }

      // Update with stable method
      await updateLocalChatGroupImageStable(chatId, newImageData);

      print('✅ ChatController: STABLE group image sync completed');

    } catch (e) {
      print('❌ ChatController: Error in stable group image sync: $e');
    }
  }


  Future<void> markMessagesAsRead(String chatId, String userId) async {
    final unreadMessages = currentMessages.where((msg) =>
    !msg.readBy.contains(userId) && msg.senderId != userId
    ).toList();

    if (unreadMessages.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();

    for (var message in unreadMessages) {
      batch.update(
          FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').doc(message.id),
          {'readBy': FieldValue.arrayUnion([userId])}
      );
    }

    await batch.commit();

    // Update local messages
    for (int i = 0; i < currentMessages.length; i++) {
      if (!currentMessages[i].readBy.contains(userId) && currentMessages[i].senderId != userId) {
        final updatedReadBy = List<String>.from(currentMessages[i].readBy)..add(userId);
        currentMessages[i] = currentMessages[i].copyWith(readBy: updatedReadBy);
      }
    }

    currentMessages.refresh();
  }

// Method to get message statistics
  Map<String, int> getMessageStats(String chatId) {
    final messages = currentMessages;

    return {
      'total': messages.length,
      'text': messages.textMessages.length,
      'images': messages.imageMessages.length,
      'videos': messages.videoMessages.length,
      'audio': messages.audioMessages.length,
      'files': messages.fileMessages.length,
      'media': messages.mediaMessages.length,
      'unread': messages.unreadBy(currentUserId ?? '').length,
    };
  }

// Method to search messages
  List<ChatMessage> searchMessages(String query) {
    if (query.trim().isEmpty) return [];

    final lowercaseQuery = query.toLowerCase();

    return currentMessages.where((message) {
      return message.text.toLowerCase().contains(lowercaseQuery) ||
          message.senderName.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

// Method to get messages by date range
  List<ChatMessage> getMessagesByDateRange(DateTime startDate, DateTime endDate) {
    return currentMessages.where((message) {
      return message.timestamp.isAfter(startDate) &&
          message.timestamp.isBefore(endDate);
    }).toList();
  }

// Method to export chat messages
  List<Map<String, dynamic>> exportMessages(String currentUserId) {
    return currentMessages.map((message) => message.toCompatibleMap(currentUserId)).toList();
  }

// CORRECTED: Load messages with null safety
  void _loadMessagesDirectly(String chatId) {
    try {
      print('🔄 Loading messages for chat: $chatId');
      isLoadingMessages.value = true;

      // Update current chat ID
      currentChatId = chatId; // Direct assignment for String

      _messagesSubscription?.cancel();

      _messagesSubscription = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots()
          .listen(
            (snapshot) {
          print('📨 Received ${snapshot.docs.length} messages');

          final messages = snapshot.docs.map((doc) {
            try {
              return _messageFromDocument(doc);
            } catch (e) {
              print('❌ Error parsing message ${doc.id}: $e');
              return _createBasicMessage(doc.id, doc.data() as Map<String, dynamic>);
            }
          }).where((msg) => msg != null).cast<ChatMessage>().toList();

          currentMessages.value = messages;
          isLoadingMessages.value = false;

          print('✅ Successfully loaded ${messages.length} messages');

          // Mark messages as read
          _markAsRead(chatId);
        },
        onError: (error) {
          print('❌ Error loading messages: $error');
          currentMessages.clear();
          isLoadingMessages.value = false;
        },
      );

    } catch (e) {
      print('❌ Error setting up message listener: $e');
      isLoadingMessages.value = false;
    }
  }



// Helper method to set current chat ID
  void setCurrentChatId(String chatId) {
    currentChatId = chatId;
    print('📍 Current chat ID set to: $chatId');
  }





  // Enhanced version with Firebase Storage upload (optional)
  Future<void> sendImageWithUpload({String? caption}) async {
    if (currentChatId == null) {
      _showError('No active chat');
      return;
    }

    if (currentUserId == null) {
      _showError('User not authenticated');
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        isSendingMessage.value = true;

        // Upload to Firebase Storage (you'll need to implement this)
        String? imageUrl = await _uploadImageToStorage(File(image.path));

        if (imageUrl != null) {
          final userId = currentUserId!;
          final userName = currentUserName ?? 'User';

          final messageData = {
            'senderId': userId,
            'senderName': userName,
            'text': caption ?? '📷 Image',
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'image',
            'imageUrl': imageUrl,
          };

          // Add message to Firestore
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(currentChatId!)
              .collection('messages')
              .add(messageData);

          // Update chat's last message
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(currentChatId!)
              .update({
            'lastMessage': '📷 Image',
            'lastMessageTimestamp': FieldValue.serverTimestamp(),
            'lastMessageSender': userId,
          });

          // if (!_silentMode) {
          //   _showSuccess('Image sent successfully');
          // }
        } else {
          throw Exception('Failed to upload image');
        }
      }
    } catch (e) {
      print('❌ Error sending image: $e');
      _showError('Failed to send image');
    } finally {
      isSendingMessage.value = false;
    }
  }

  // Placeholder for Firebase Storage upload (implement if needed)
  Future<String?> _uploadImageToStorage(File imageFile) async {
    try {
      // This is where you'd implement Firebase Storage upload
      // For now, return null
      print('📸 Image upload not implemented yet');
      return null;
    } catch (e) {
      print('❌ Error uploading image: $e');
      return null;
    }
  }

  // Send file method (optional)
  Future<void> sendFile() async {
    if (currentChatId == null) {
      _showError('No active chat');
      return;
    }

    try {
      // This would use file_picker package
      _showError('File sending not implemented yet');
    } catch (e) {
      print('❌ Error sending file: $e');
      _showError('Failed to send file');
    }
  }

  @override
  void onClose() {
    print('🧹 ChatController: Cleaning up...');
    _initTimer?.cancel();
    _chatsSubscription?.cancel();
    _messagesSubscription?.cancel();
    _authStateSubscription?.cancel();
    _onlineStatusTimer?.cancel();
    super.onClose();
  }
}