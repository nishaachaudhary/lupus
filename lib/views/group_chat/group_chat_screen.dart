// Enhanced GroupChatScreen with integrated notifications
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lupus_care/helper/storage_service.dart';
import 'package:lupus_care/views/chat_screen/chat_controller.dart';
import 'package:lupus_care/views/chat_screen/firebase/firebase_model.dart';
import 'package:lupus_care/views/chat_screen/notification_api_service.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/views/group_chat/group_chat_controller.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final Chat? chat;
  final Map<String, dynamic>? groupData;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.chat,
    this.groupData,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {

  // Controllers
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  // State variables
  String currentUserId = '';
  String currentUserName = '';
  String currentUserAvatar = '';
  List<Message> messages = [];
  bool isLoading = true;
  bool isSendingMessage = false;
  bool isTyping = false;
  bool isAppInForeground = true;

  // Notification state
  bool isNotificationEnabled = true;
  List<String> groupMemberIds = [];

  // Real-time listeners
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<DocumentSnapshot>? _groupSubscription;
  StreamSubscription<QuerySnapshot>? _typingSubscription;

  // Background/Foreground handling
  Timer? _backgroundTimer;
  DateTime? _lastMessageTime;

  // Controllers
  ChatController? chatController;
  GroupController? groupController;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Image picker
  final ImagePicker _imagePicker = ImagePicker();

  // Retry mechanism
  Timer? _retryTimer;
  int _retryCount = 0;
  static const int maxRetries = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    print('📱 Enhanced Group Chat: initState called for group ${widget.groupId}');
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      print('🚀 Enhanced Group Chat: Initializing chat - ${widget.groupId}');

      // Get current user information
      await _getCurrentUserInfo();

      // Load group members for notifications
      await _loadGroupMembers();

      // Ensure user is added to group participants
      await _ensureUserInGroupParticipants();

      // Initialize controllers
      await _initializeControllers();

      // Setup real-time listeners
      await _setupRealTimeListeners();

      // Mark messages as read
      await _markMessagesAsRead();

      if (mounted) {
        setState(() {
          isLoading = false;
        });
        _animationController.forward();
      }

      print('✅ Enhanced Group Chat: Initialization successful');

    } catch (e) {
      print('❌ Enhanced Group Chat: Initialization failed - $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ENHANCED: Load group members for notification targeting
  Future<void> _loadGroupMembers() async {
    try {
      print('👥 Loading group members for notifications...');

      final groupDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.groupId)
          .get();

      if (groupDoc.exists) {
        final groupData = groupDoc.data()!;

        // Get participants list
        final participants = List<String>.from(groupData['participants'] ?? []);

        // Filter out current user (don't send notifications to self)
        groupMemberIds = participants
            .where((id) => id != currentUserId)
            .toList();

        print('📋 Loaded ${groupMemberIds.length} members for notifications');
        print('👥 Member IDs: $groupMemberIds');
      }
    } catch (e) {
      print('❌ Error loading group members: $e');
    }
  }

  // ENHANCED: Send message with comprehensive notification support
  Future<void> _sendMessage({String? messageText, String? imageUrl}) async {
    final text = messageText ?? _messageController.text.trim();

    if (text.isEmpty && imageUrl == null) return;

    if (currentUserId.isEmpty) {
      _showErrorSnackbar('Unable to send message. Please restart the app.');
      return;
    }

    try {
      if (mounted) {
        setState(() {
          isSendingMessage = true;
        });
      }

      // Clear typing indicator
      await _updateTypingStatus(false);

      // Generate message ID
      final messageId = DateTime.now().millisecondsSinceEpoch.toString();

      // Prepare message data
      final messageData = {
        'id': messageId,
        'senderId': currentUserId,
        'senderName': currentUserName,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'type': imageUrl != null ? 'image' : 'text',
        'messageType': imageUrl != null ? 'image' : 'text',
        'imageUrl': imageUrl,
        'readBy': [currentUserId], // Mark as read by sender
        'isDeleted': false,
        'editedAt': null,
        'platform': Platform.isIOS ? 'ios' : 'android',
      };

      // Use batch write for atomic updates
      final batch = FirebaseFirestore.instance.batch();

      // Add message
      final messageRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.groupId)
          .collection('messages')
          .doc(messageId);

      batch.set(messageRef, messageData);

      // Update group's last message and participant info
      final groupRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.groupId);

      final lastMessageText = imageUrl != null ? '📷 Image' : text;

      batch.update(groupRef, {
        'lastMessage': lastMessageText,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSender': currentUserId,
        'lastMessageSenderName': currentUserName,
        // Ensure current user is in participants
        'participants': FieldValue.arrayUnion([currentUserId]),
        'participantDetails.$currentUserId': {
          'id': currentUserId,
          'name': currentUserName,
          'avatar': currentUserAvatar,
          'isOnline': true,
        },
      });

      // Execute batch
      await batch.commit();

      // CRITICAL: Send notifications after successful message send
      await _sendGroupMessageNotification(lastMessageText);

      // Clear message input
      _messageController.clear();

      // Scroll to bottom
      _scrollToBottom();

      print('✅ Message sent successfully with notifications');

    } catch (e) {
      print('❌ Error sending message: $e');
      _showErrorSnackbar('Failed to send message. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          isSendingMessage = false;
        });
      }
    }
  }

  // ENHANCED: Send group message notifications
  Future<void> _sendGroupMessageNotification(String messagePreview) async {
    try {
      if (!isNotificationEnabled || groupMemberIds.isEmpty) {
        print('⚠️ Notifications disabled or no members to notify');
        return;
      }

      print('📢 Sending group message notifications...');
      print('   Group ID: ${widget.groupId}');
      print('   Sender: $currentUserName ($currentUserId)');
      print('   Members to notify: ${groupMemberIds.length}');
      print('   Message preview: $messagePreview');

      // Get API user ID (remove prefix if present)
      final apiSenderId = NotificationApiService.extractApiUserId(currentUserId);

      // Get API group ID from group data
      final apiGroupId = _extractApiGroupIdFromData();

      if (apiGroupId.isEmpty) {
        print('❌ Could not determine API group ID for notifications');
        return;
      }

      // Create notification message
      final notificationText = '$currentUserName: $messagePreview';

      // Strategy 1: Send group notification (preferred)
      try {
        final groupNotificationResult = await NotificationApiService.sendGroupChatNotification(
          senderId: apiSenderId,
          groupId: apiGroupId,
          message: notificationText,
        );

        if (groupNotificationResult['success'] == true) {
          print('✅ Group notification sent successfully');
          return; // Success, no need for individual notifications
        } else {
          print('⚠️ Group notification failed, trying individual notifications');
        }
      } catch (e) {
        print('❌ Group notification error: $e');
      }

      // Strategy 2: Send individual notifications as fallback
      await _sendIndividualNotifications(notificationText);

    } catch (e) {
      print('❌ Error sending group message notifications: $e');
    }
  }

  // Send individual notifications to group members
  Future<void> _sendIndividualNotifications(String notificationText) async {
    try {
      print('📤 Sending individual notifications to group members...');

      // Extract API user IDs from group member IDs
      final apiMemberIds = groupMemberIds
          .map((id) => NotificationApiService.extractApiUserId(id))
          .where((id) => id.isNotEmpty)
          .toList();

      if (apiMemberIds.isEmpty) {
        print('⚠️ No valid API member IDs for individual notifications');
        return;
      }

      final apiSenderId = NotificationApiService.extractApiUserId(currentUserId);

      // Send individual notifications
      final results = await NotificationApiService.sendMultiplePersonalNotifications(
        senderId: apiSenderId,
        receiverIds: apiMemberIds,
        message: notificationText,
      );

      // Log results
      int successCount = 0;
      int failedCount = 0;

      for (var result in results) {
        if (result['success'] == true) {
          successCount++;
        } else {
          failedCount++;
          print('❌ Failed individual notification to ${result['receiver_id']}: ${result['message']}');
        }
      }

      print('📊 Individual notifications result: $successCount successful, $failedCount failed');

    } catch (e) {
      print('❌ Error sending individual notifications: $e');
    }
  }

  // Extract API group ID from various data sources
  String _extractApiGroupIdFromData() {
    // Try to get from widget data
    if (widget.groupData != null) {
      final possibleIds = [
        widget.groupData!['apiGroupId']?.toString(),
        widget.groupData!['api_group_id']?.toString(),
        widget.groupData!['backend_group_id']?.toString(),
        widget.groupData!['group_id']?.toString(),
        widget.groupData!['id']?.toString(),
      ];

      for (String? id in possibleIds) {
        if (id != null && id.isNotEmpty && id != 'null') {
          return id;
        }
      }
    }

    // Try to get from GroupController
    if (groupController?.groupData != null) {
      final groupData = groupController!.groupData!;
      final possibleIds = [
        groupData['apiGroupId']?.toString(),
        groupData['api_group_id']?.toString(),
        groupData['backend_group_id']?.toString(),
        groupData['group_id']?.toString(),
        groupData['id']?.toString(),
      ];

      for (String? id in possibleIds) {
        if (id != null && id.isNotEmpty && id != 'null') {
          return id;
        }
      }
    }

    // Fallback to widget groupId
    return widget.groupId;
  }

  // ENHANCED: Send notification when user joins group
  Future<void> _sendUserJoinNotification() async {
    try {
      if (!isNotificationEnabled) return;

      print('📢 Sending user join notification...');

      final notificationText = '$currentUserName joined the group';

      // Send via GroupController if available
      if (groupController != null) {
        await groupController!.sendGroupUpdateNotification(
          'member_added',
          additionalInfo: currentUserName,
        );
      } else {
        // Fallback to direct API call
        final apiSenderId = NotificationApiService.extractApiUserId(currentUserId);
        final apiGroupId = _extractApiGroupIdFromData();

        if (apiGroupId.isNotEmpty) {
          await NotificationApiService.sendGroupChatNotification(
            senderId: apiSenderId,
            groupId: apiGroupId,
            message: notificationText,
          );
        }
      }

      print('✅ User join notification sent');

    } catch (e) {
      print('❌ Error sending user join notification: $e');
    }
  }

  // ENHANCED: Handle user typing with optional notification
  Future<void> _updateTypingStatus(bool typing) async {
    try {
      if (currentUserId.isEmpty) return;

      final typingRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.groupId)
          .collection('typing')
          .doc(currentUserId);

      if (typing) {
        await typingRef.set({
          'userId': currentUserId,
          'userName': currentUserName,
          'isTyping': true,
          'timestamp': FieldValue.serverTimestamp(),
          'platform': Platform.isIOS ? 'ios' : 'android',
        });

        // Auto-clear typing status after 3 seconds
        Timer(const Duration(seconds: 3), () {
          if (mounted) {
            _updateTypingStatus(false);
          }
        });
      } else {
        await typingRef.delete();
      }

    } catch (e) {
      print('❌ Error updating typing status: $e');
    }
  }

  // ENHANCED: Send image message with notification
  Future<void> _sendImageMessage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        // Show loading dialog
        if (mounted) {
          Get.dialog(
            WillPopScope(
              onWillPop: () async => false,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
            barrierDismissible: false,
          );
        }

        // Convert image to base64
        final bytes = await File(image.path).readAsBytes();

        // Check image size (5MB limit)
        if (bytes.length > 5 * 1024 * 1024) {
          Get.back();
          _showErrorSnackbar('Image too large. Please select a smaller image.');
          return;
        }

        final base64String = base64Encode(bytes);
        final imageData = 'data:image/jpeg;base64,$base64String';

        Get.back(); // Close loading dialog

        // Send message with image - notification will be sent automatically
        await _sendMessage(
          messageText: '',
          imageUrl: imageData,
        );
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      print('❌ Error sending image: $e');
      _showErrorSnackbar('Failed to send image. Please try again.');
    }
  }

  // Toggle notification settings
  void _toggleNotifications() {
    setState(() {
      isNotificationEnabled = !isNotificationEnabled;
    });

    Get.snackbar(
      'Notifications ${isNotificationEnabled ? 'Enabled' : 'Disabled'}',
      isNotificationEnabled
          ? 'Group members will receive notifications for your messages'
          : 'Group members will not receive notifications for your messages',
      backgroundColor: isNotificationEnabled ? Colors.green : Colors.orange,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  // Test notification functionality
  Future<void> _testNotifications() async {
    try {
      if (groupController != null) {
        await groupController!.testGroupNotificationApi();
      } else {
        Get.snackbar('Test Unavailable', 'Group controller not available',
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      print('❌ Error testing notifications: $e');
      Get.snackbar('Test Failed', 'Failed to test notifications: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  // EXISTING METHODS (unchanged)
  Future<void> _getCurrentUserInfo() async {
    try {
      final userData = StorageService.to.getUser();
      if (userData != null) {
        final rawUserId = userData['id']?.toString() ?? '';
        currentUserId = rawUserId.isNotEmpty ? 'app_user_$rawUserId' : '';
        currentUserName = userData['full_name']?.toString() ??
            userData['name']?.toString() ?? 'You';
        currentUserAvatar = userData['profile_image']?.toString() ?? '';
      }

      // Fallback to Firebase Auth if available
      if (currentUserId.isEmpty) {
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          currentUserId = firebaseUser.uid;
          currentUserName = firebaseUser.displayName ?? 'You';
          currentUserAvatar = firebaseUser.photoURL ?? '';
        }
      }

      print('👤 Enhanced Group Chat: Current user - $currentUserId ($currentUserName)');

    } catch (e) {
      print('❌ Enhanced Group Chat: Error getting user info - $e');
      throw Exception('Failed to get user information');
    }
  }

  Future<void> _ensureUserInGroupParticipants() async {
    try {
      print('👥 Ensuring user is in group participants...');

      if (currentUserId.isEmpty) {
        print('❌ No current user ID');
        return;
      }

      // Get group document
      final groupDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.groupId)
          .get();

      if (!groupDoc.exists) {
        print('❌ Group document does not exist: ${widget.groupId}');
        return;
      }

      final groupData = groupDoc.data()!;
      final participants = List<String>.from(groupData['participants'] ?? []);

      print('📋 Current participants: $participants');
      print('👤 Current user ID: $currentUserId');

      // Check if user is already in participants
      if (!participants.contains(currentUserId)) {
        print('➕ Adding user to group participants...');

        // Add user to participants
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.groupId)
            .update({
          'participants': FieldValue.arrayUnion([currentUserId]),
          'participantDetails.$currentUserId': {
            'id': currentUserId,
            'name': currentUserName,
            'avatar': currentUserAvatar,
            'isOnline': true,
            'joinedAt': FieldValue.serverTimestamp(),
          },
          'unreadCounts.$currentUserId': 0,
        });

        // Send join notification
        await _sendUserJoinNotification();

        print('✅ User added to group participants');
      } else {
        print('✅ User already in group participants');
      }

    } catch (e) {
      print('❌ Error ensuring user in group participants: $e');
    }
  }

  Future<void> _initializeControllers() async {
    try {
      // Initialize ChatController
      if (Get.isRegistered<ChatController>()) {
        chatController = Get.find<ChatController>();
      } else {
        chatController = ChatController();
        Get.put<ChatController>(chatController!, permanent: true);
      }

      // Initialize GroupController
      if (Get.isRegistered<GroupController>()) {
        groupController = Get.find<GroupController>();
      } else {
        groupController = GroupController();
        Get.put<GroupController>(groupController!, permanent: true);
      }

      // Initialize GroupController with data
      groupController?.initializeGroupData(
        groupId: widget.groupId,
        groupName: widget.groupName,
        fullGroupData: widget.groupData,
      );

      print('✅ Enhanced Group Chat: Controllers initialized');

    } catch (e) {
      print('❌ Enhanced Group Chat: Error initializing controllers - $e');
    }
  }

  Future<void> _setupRealTimeListeners() async {
    try {
      print('🔄 Setting up real-time listeners for group: ${widget.groupId}');

      // Clean up existing listeners
      _cleanupListeners();

      // Add delay to ensure cleanup is complete
      await Future.delayed(Duration(milliseconds: 100));

      // Setup messages listener with proper error handling
      _messagesSubscription = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.groupId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots(includeMetadataChanges: false)
          .listen(
            (snapshot) {
          print('📨 Messages update received: ${snapshot.docs.length} messages');
          _onMessagesUpdated(snapshot);
        },
        onError: (error) {
          print('❌ Messages listener error: $error');
          _retryMessageListener();
        },
        cancelOnError: false,
      );

      // Setup group listener
      _groupSubscription = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.groupId)
          .snapshots(includeMetadataChanges: false)
          .listen(
            (snapshot) {
          print('📨 Group update received');
          _onGroupUpdated(snapshot);
        },
        onError: (error) {
          print('❌ Group listener error: $error');
        },
        cancelOnError: false,
      );

      print('✅ Real-time listeners setup complete');

    } catch (e) {
      print('❌ Error setting up real-time listeners: $e');
    }
  }

  void _onMessagesUpdated(QuerySnapshot snapshot) {
    try {
      print('📨 Processing ${snapshot.docs.length} messages...');

      if (!mounted) {
        print('⚠️ Widget not mounted, skipping message update');
        return;
      }

      final newMessages = <Message>[];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final message = Message.fromMap(data, doc.id);

          // Validate message
          if (message.senderId.isNotEmpty && message.text.isNotEmpty) {
            newMessages.add(message);
          }

        } catch (e) {
          print('❌ Error parsing message ${doc.id}: $e');
        }
      }

      print('✅ Successfully parsed ${newMessages.length} messages');

      if (mounted) {
        setState(() {
          messages = newMessages;
        });

        // Auto-scroll to bottom for new messages
        if (messages.isNotEmpty && _scrollController.hasClients) {
          _scrollToBottom();
        }

        // Mark messages as read
        _markMessagesAsRead();
      }

    } catch (e) {
      print('❌ Error processing messages update: $e');
    }
  }

  void _onGroupUpdated(DocumentSnapshot snapshot) {
    try {
      if (!isAppInForeground) return;

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;

        // Update group info if changed
        final newGroupName = data['name']?.toString() ?? widget.groupName;
        if (newGroupName != widget.groupName && mounted) {
          setState(() {});
        }

        // Update group members list for notifications
        final participants = List<String>.from(data['participants'] ?? []);
        groupMemberIds = participants
            .where((id) => id != currentUserId)
            .toList();

        // Update group image if changed
        groupController?.initializeGroupData(
          groupId: widget.groupId,
          groupName: newGroupName,
          fullGroupData: data,
          forceReinit: true,
        );
      }
    } catch (e) {
      print('❌ Enhanced Group Chat: Error processing group update - $e');
    }
  }

  void _retryMessageListener() {
    Timer(Duration(seconds: 2), () {
      if (mounted && isAppInForeground) {
        print('🔄 Retrying message listener...');
        _setupRealTimeListeners();
      }
    });
  }

  Future<void> _markMessagesAsRead() async {
    try {
      if (currentUserId.isEmpty || !isAppInForeground) return;

      // Use transaction for better reliability
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Get unread messages
        final messagesQuery = await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.groupId)
            .collection('messages')
            .where('readBy', whereNotIn: [currentUserId])
            .limit(50) // Limit batch size
            .get();

        // Mark messages as read
        for (var doc in messagesQuery.docs) {
          transaction.update(doc.reference, {
            'readBy': FieldValue.arrayUnion([currentUserId]),
          });
        }

        // Reset unread count for this user
        final groupRef = FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.groupId);

        transaction.update(groupRef, {
          'unreadCounts.$currentUserId': 0,
        });
      });

    } catch (e) {
      print('❌ Enhanced Group Chat: Error marking messages as read - $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      Get.snackbar(
        'Error',
        message,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  void _cleanupListeners() {
    print('📱 Cleaning up listeners');

    _messagesSubscription?.cancel();
    _messagesSubscription = null;

    _groupSubscription?.cancel();
    _groupSubscription = null;

    _typingSubscription?.cancel();
    _typingSubscription = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        isAppInForeground = true;
        _backgroundTimer?.cancel();
        _handleAppResumed();
        break;

      case AppLifecycleState.paused:
        isAppInForeground = false;
        _handleAppPaused();
        break;

      case AppLifecycleState.inactive:
        isAppInForeground = false;
        break;

      case AppLifecycleState.detached:
        _cleanupListeners();
        break;

      case AppLifecycleState.hidden:
        isAppInForeground = false;
        break;
    }
  }

  void _handleAppResumed() {
    Timer(Duration(milliseconds: 500), () {
      if (mounted) {
        _setupRealTimeListeners();
        _markMessagesAsRead();
      }
    });
  }

  void _handleAppPaused() {
    _backgroundTimer = Timer(Duration(seconds: 25), () {
      print('📱 Background timer expired - cleaning up listeners');
      _cleanupListeners();
    });
  }

  @override
  void dispose() {
    print('📱 Enhanced Group Chat: dispose called');

    WidgetsBinding.instance.removeObserver(this);
    _cleanupListeners();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _animationController.dispose();
    _backgroundTimer?.cancel();
    _retryTimer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.groupName),
          backgroundColor: CustomColors.purpleColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Connection status indicator
            if (!isAppInForeground)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: Colors.orange,
                child: const Text(
                  'Reconnecting...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),

            // Notification status indicator
            if (!isNotificationEnabled)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(4),
                color: Colors.red,
                child: const Text(
                  'Notifications disabled for this chat',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),

            // Messages list
            Expanded(
              child: _buildMessagesList(),
            ),

            // Typing indicator
            if (isTyping) _buildTypingIndicator(),

            // Message input
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          // Group image
          Obx(() {
            final groupImage = groupController?.getDisplayImage();
            return CircleAvatar(
              radius: 20,
              backgroundColor: CustomColors.lightPurpleColor,
              child: groupImage != null && groupImage.isNotEmpty
                  ? ClipOval(child: _buildGroupImage(groupImage))
                  : const Icon(Icons.group, color: CustomColors.purpleColor),
            );
          }),

          const SizedBox(width: 12),

          // Group name and member count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.groupName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Obx(() {
                  final memberCount = groupController?.memberCount ?? 0;
                  return Text(
                    '$memberCount members',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: CustomColors.purpleColor,
      foregroundColor: Colors.white,
      actions: [
        // Notification toggle
        IconButton(
          icon: Icon(
            isNotificationEnabled ? Icons.notifications : Icons.notifications_off,
          ),
          onPressed: _toggleNotifications,
          tooltip: isNotificationEnabled ? 'Disable notifications' : 'Enable notifications',
        ),

        // More options
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'info':
                Get.to(() => GroupInfoScreen(
                  groupId: widget.groupId,
                  groupName: widget.groupName,
                ));
                break;
              case 'test_notifications':
                _testNotifications();
                break;
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem<String>(
              value: 'info',
              child: Text('Group Info'),
            ),
            const PopupMenuItem<String>(
              value: 'test_notifications',
              child: Text('Test Notifications'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGroupImage(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      try {
        final bytes = base64Decode(imageUrl.split(',')[1]);
        return Image.memory(
          bytes,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.group, color: CustomColors.purpleColor);
          },
        );
      } catch (e) {
        return const Icon(Icons.group, color: CustomColors.purpleColor);
      }
    } else if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.group, color: CustomColors.purpleColor);
        },
      );
    } else {
      return const Icon(Icons.group, color: CustomColors.purpleColor);
    }
  }

  Widget _buildMessagesList() {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start the conversation!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMe = message.senderId == currentUserId;
        final showSenderName = !isMe &&
            (index == messages.length - 1 ||
                messages[index + 1].senderId != message.senderId);

        return _buildMessageBubble(message, isMe, showSenderName);
      },
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe, bool showSenderName) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            // Sender avatar
            CircleAvatar(
              radius: 16,
              backgroundColor: CustomColors.lightPurpleColor,
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: CustomColors.purpleColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Message bubble
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Sender name
                if (showSenderName)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                // Message content
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? CustomColors.purpleColor : Colors.grey[200],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Message text or image
                      if (message.type == 'image' && message.imageUrl != null)
                        _buildImageMessage(message.imageUrl!)
                      else
                        Text(
                          message.text,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 16,
                          ),
                        ),

                      // Timestamp
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildImageMessage(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      try {
        final bytes = base64Decode(imageUrl.split(',')[1]);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 200,
                height: 200,
                color: Colors.grey[300],
                child: const Icon(Icons.image, size: 50),
              );
            },
          ),
        );
      } catch (e) {
        return const Text('🖼️ Image');
      }
    } else if (imageUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 200,
              height: 200,
              color: Colors.grey[300],
              child: const Icon(Icons.image, size: 50),
            );
          },
        ),
      );
    } else {
      return const Text('🖼️ Image');
    }
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 12,
            backgroundColor: CustomColors.lightPurpleColor,
            child: Icon(Icons.more_horiz, size: 16, color: CustomColors.purpleColor),
          ),
          const SizedBox(width: 8),
          Text(
            'Someone is typing...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Image button
            IconButton(
              icon: const Icon(Icons.image, color: CustomColors.purpleColor),
              onPressed: isSendingMessage ? null : _sendImageMessage,
            ),

            // Message input field
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  decoration: const InputDecoration(
                    hintText: "Type a message...",
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (text) {
                    if (text.trim().isNotEmpty) {
                      _updateTypingStatus(true);
                    } else {
                      _updateTypingStatus(false);
                    }
                  },
                  onSubmitted: (text) {
                    if (text.trim().isNotEmpty && !isSendingMessage) {
                      _sendMessage();
                    }
                  },
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Send button
            GestureDetector(
              onTap: isSendingMessage ? null : () {
                if (_messageController.text.trim().isNotEmpty) {
                  _sendMessage();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSendingMessage ? Colors.grey : CustomColors.purpleColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSendingMessage ? Icons.hourglass_empty : Icons.send,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
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
}

// Message model class (unchanged)
class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final String type;
  final String? imageUrl;
  final List<String> readBy;
  final bool isDeleted;
  final DateTime? editedAt;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.type,
    this.imageUrl,
    required this.readBy,
    required this.isDeleted,
    this.editedAt,
  });

  static Message fromMap(Map<String, dynamic> map, String id) {
    return Message(
      id: id,
      senderId: map['senderId']?.toString() ?? '',
      senderName: map['senderName']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      type: map['type']?.toString() ?? 'text',
      imageUrl: map['imageUrl']?.toString(),
      readBy: List<String>.from(map['readBy'] ?? []),
      isDeleted: map['isDeleted'] ?? false,
      editedAt: map['editedAt'] != null
          ? (map['editedAt'] as Timestamp).toDate()
          : null,
    );
  }
}

// Placeholder for GroupInfoScreen (unchanged)
class GroupInfoScreen extends StatelessWidget {
  final String groupId;
  final String groupName;

  const GroupInfoScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Group Info'),
        backgroundColor: CustomColors.purpleColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Text('Group Info Screen\nGroup: $groupName'),
      ),
    );
  }
}