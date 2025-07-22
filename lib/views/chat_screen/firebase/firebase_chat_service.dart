// lib/views/chat_screen/firebase/firebase_chat_service.dart
import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';
import 'package:lupus_care/helper/storage_service.dart';
import 'firebase_model.dart';

class FirebaseChatService extends GetxService {
  static FirebaseChatService? _instance;
  static FirebaseChatService get instance => _instance ??= FirebaseChatService._();

  FirebaseChatService._();

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Stream controllers
  final StreamController<List<Chat>> _chatsController = StreamController<List<Chat>>.broadcast();
  final StreamController<List<ChatMessage>> _messagesController = StreamController<List<ChatMessage>>.broadcast();

  // Current user info
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserEmail;

  // Connection status
  bool _isConnected = false;

  // Streams
  Stream<List<Chat>> get chatsStream => _chatsController.stream;
  Stream<List<ChatMessage>> get messagesStream => _messagesController.stream;

  // Getters
  bool get isConnected => _isConnected;
  String? get currentUserId => _currentUserId;
  String? get currentUserName => _currentUserName;
  String? get currentUserEmail => _currentUserEmail;

  @override
  void onInit() {
    super.onInit();
    print('🔥 FirebaseChatService initialized');
    _setupAuthListener();
  }

  void _setupAuthListener() {
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _currentUserId = user.uid;
        _currentUserEmail = user.email;
        _currentUserName = user.displayName;
        _isConnected = true;
        print('✅ Firebase user authenticated: ${user.email}');
      } else {
        _currentUserId = null;
        _currentUserEmail = null;
        _currentUserName = null;
        _isConnected = false;
        print('❌ Firebase user signed out');
      }
    });
  }

  // ========== AUTHENTICATION ==========

  Future<bool> signInWithAppUser() async {
    try {
      print('🔐 Attempting to sign in with app user credentials...');

      if (!Get.isRegistered<StorageService>()) {
        throw Exception('StorageService not available');
      }

      final storage = Get.find<StorageService>();
      final userData = storage.getUser();

      if (userData == null) {
        throw Exception('No user data found');
      }

      // Try anonymous sign in first
      final result = await _auth.signInAnonymously();

      if (result.user != null) {
        _currentUserId = result.user!.uid;
        _currentUserEmail = userData['email'] ?? 'anonymous@lupuscare.com';
        _currentUserName = userData['name'] ?? 'Anonymous User';
        _isConnected = true;

        // Store user info in Firestore
        await _createOrUpdateUserDocument();

        print('✅ Anonymous sign in successful');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Error in signInWithAppUser: $e');
      return false;
    }
  }

  Future<bool> signInUser({required String email, required String password}) async {
    try {
      print('🔐 Signing in user: $email');

      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        _currentUserId = result.user!.uid;
        _currentUserEmail = result.user!.email;
        _currentUserName = result.user!.displayName;
        _isConnected = true;

        // Update user document
        await _createOrUpdateUserDocument();

        print('✅ User sign in successful');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Error signing in user: $e');
      rethrow;
    }
  }

  Future<bool> signUpUser({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      print('📝 Signing up user: $email');

      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        // Update display name
        await result.user!.updateDisplayName(name);

        _currentUserId = result.user!.uid;
        _currentUserEmail = result.user!.email;
        _currentUserName = name;
        _isConnected = true;

        // Create user document
        await _createOrUpdateUserDocument();

        print('✅ User sign up successful');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Error signing up user: $e');
      rethrow;
    }
  }

  Future<void> _createOrUpdateUserDocument() async {
    if (_currentUserId == null) return;

    try {
      await _firestore.collection('users').doc(_currentUserId).set({
        'id': _currentUserId,
        'email': _currentUserEmail ?? '',
        'name': _currentUserName ?? 'Anonymous User',
        'avatar': '',
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ User document created/updated successfully');
    } catch (e) {
      print('❌ Error creating/updating user document: $e');
    }
  }

  Future<void> signOut() async {
    try {
      if (_currentUserId != null) {
        // Update online status before signing out
        await _firestore.collection('users').doc(_currentUserId).update({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }

      await _auth.signOut();
      _isConnected = false;
      print('✅ User signed out successfully');
    } catch (e) {
      print('❌ Error signing out: $e');
    }
  }

  Future<String?> createDirectChat(String otherUserId) async {
    if (!_isConnected || _currentUserId == null) {
      print('❌ Not connected or no user ID');
      return null;
    }

    try {
      print('💬 Creating direct chat with user: $otherUserId');
      print('👤 Current user: $_currentUserId');

      // Check if chat already exists using array-contains-any query
      try {
        print('🔍 Checking for existing chat...');

        // Query for chats where current user is a participant
        final existingChatsQuery = await _firestore
            .collection('chats')
            .where('participants', arrayContains: _currentUserId)
            .where('isGroup', isEqualTo: false)
            .get()
            .timeout(const Duration(seconds: 10));

        print('📝 Found ${existingChatsQuery.docs.length} existing chats for current user');

        // Check if any of these chats include the other user
        for (var doc in existingChatsQuery.docs) {
          final data = doc.data();
          final participants = List<String>.from(data['participants'] ?? []);

          if (participants.contains(otherUserId)) {
            print('✅ Existing chat found: ${doc.id}');
            return doc.id;
          }
        }

        print('🆕 No existing chat found, creating new one...');
      } catch (e) {
        print('⚠️ Error checking for existing chat: $e');
        print('🔄 Proceeding to create new chat anyway...');
      }

      // Create new chat document
      final chatData = {
        'participants': [_currentUserId!, otherUserId],
        'isGroup': false,
        'createdBy': _currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSender': '',
        'unreadCounts': {
          _currentUserId!: 0,
          otherUserId: 0,
        },
        // Add these fields for better querying
        'type': 'direct',
        'active': true,
      };

      print('📤 Creating new chat document...');
      final chatRef = await _firestore
          .collection('chats')
          .add(chatData)
          .timeout(const Duration(seconds: 15));

      print('✅ Direct chat created successfully: ${chatRef.id}');

      // Send a welcome message (only for non-API users)
      await _sendWelcomeMessage(chatRef.id, otherUserId);

      return chatRef.id;

    } catch (e) {
      print('❌ Error creating direct chat: $e');

      // Provide more specific error information
      if (e.toString().contains('permission-denied')) {
        print('🔒 Permission denied - check Firestore security rules');
      } else if (e.toString().contains('timeout')) {
        print('⏰ Request timed out - check network connection');
      }

      return null;
    }
  }

  Future<void> _sendWelcomeMessage(String chatId, String otherUserId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      await sendTextMessage(
        chatId: chatId,
        text: '👋 Chat started! Say hello to begin the conversation.',
      );

      print('✅ Welcome message sent to chat: $chatId');
    } catch (e) {
      print('⚠️ Could not send welcome message: $e');
      // Don't rethrow as this is not critical
    }
  }

  // Updated getChats method with better error handling
  Future<void> getChats() async {
    if (!_isConnected || _currentUserId == null) {
      print('❌ Not connected or no user ID for getChats');
      _chatsController.add([]);
      return;
    }

    try {
      print('📱 Fetching chats for user: $_currentUserId');

      // Use simpler query with better error handling
      _firestore
          .collection('chats')
          .where('participants', arrayContains: _currentUserId)
          .snapshots()
          .listen(
            (snapshot) async {
          try {
            List<Chat> chats = [];

            print('📨 Processing ${snapshot.docs.length} chat documents');

            for (var doc in snapshot.docs) {
              try {
                final chat = await _chatFromDocument(doc);
                if (chat != null) {
                  chats.add(chat);
                }
              } catch (e) {
                print('❌ Error processing chat document ${doc.id}: $e');
                // Continue processing other chats
              }
            }

            // Sort chats by last message timestamp
            chats.sort((a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp));

            print('✅ Successfully processed ${chats.length} chats');
            _chatsController.add(chats);
          } catch (e) {
            print('❌ Error processing chat snapshot: $e');
            _chatsController.add([]);
          }
        },
        onError: (error) {
          print('❌ Error in chats stream: $error');

          if (error.toString().contains('permission-denied')) {
            print('🔒 Permission denied - check Firestore security rules and user authentication');
          }

          _chatsController.add([]);
        },
      );
    } catch (e) {
      print('❌ Error setting up chats stream: $e');
      _chatsController.add([]);
    }
  }

  Future<Chat?> _chatFromDocument(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>?;

      if (data == null) {
        print('⚠️ Chat document ${doc.id} has no data');
        return null;
      }

      final participants = List<String>.from(data['participants'] ?? []);

      if (participants.isEmpty) {
        print('⚠️ Chat document ${doc.id} has no participants');
        return null;
      }

      // Get participant details with timeout and error handling
      Map<String, ParticipantInfo> participantDetails = {};

      for (String participantId in participants) {
        if (participantId != _currentUserId) {
          try {
            final userDoc = await _firestore
                .collection('users')
                .doc(participantId)
                .get()
                .timeout(const Duration(seconds: 5));

            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>? ?? {};
              participantDetails[participantId] = ParticipantInfo(
                id: participantId,
                name: userData['name'] ?? 'Unknown User',
                avatar: userData['avatar'] ?? '',
                isOnline: userData['isOnline'] ?? false,
              );
            } else {
              // Create placeholder for missing user
              participantDetails[participantId] = ParticipantInfo(
                id: participantId,
                name: 'Community Member', // Generic name for API users
                avatar: '',
                isOnline: false,
              );
            }
          } catch (e) {
            print('⚠️ Error getting participant $participantId details: $e');
            // Create placeholder participant
            participantDetails[participantId] = ParticipantInfo(
              id: participantId,
              name: 'Community Member',
              avatar: '',
              isOnline: false,
            );
          }
        }
      }

      // Get unread counts
      Map<String, int> unreadCounts = {};
      final unreadData = data['unreadCounts'] as Map<String, dynamic>? ?? {};
      unreadData.forEach((key, value) {
        unreadCounts[key] = value is int ? value : 0;
      });

      return Chat(
        id: doc.id,
        name: data['name'] ?? '',
        participants: participants,
        isGroup: data['isGroup'] ?? false,
        description: data['description'] ?? '',
        createdBy: data['createdBy'] ?? '',
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        lastMessage: data['lastMessage'] ?? '',
        lastMessageTimestamp: (data['lastMessageTimestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        lastMessageSender: data['lastMessageSender'] ?? '',
        participantDetails: participantDetails,
        unreadCounts: unreadCounts,
      );

    } catch (e) {
      print('❌ Error converting chat document ${doc.id}: $e');
      return null;
    }
  }

  // Helper method to get static user names
  String _getStaticUserName(String userId) {
    final staticNames = {
      'static_user_1': 'Dr. Sarah Johnson',
      'static_user_2': 'Emily Rodriguez',
      'static_user_3': 'Dr. Michael Chen',
      'static_user_4': 'Maria Gonzalez',
      'static_user_5': 'James Wilson',
      'static_user_6': 'Dr. Lisa Park',
    };

    return staticNames[userId] ?? 'Community Member';
  }

  Future<String?> createGroupChat({
    required String name,
    required List<String> userIds,
    String? description,
  }) async {
    if (!_isConnected || _currentUserId == null) {
      print('❌ Not connected or no user ID');
      return null;
    }

    try {
      print('👥 Creating group chat: $name');

      List<String> participants = [_currentUserId!, ...userIds];
      Map<String, int> unreadCounts = {};
      for (String userId in participants) {
        unreadCounts[userId] = 0;
      }

      final chatRef = await _firestore.collection('chats').add({
        'name': name,
        'description': description ?? '',
        'participants': participants,
        'isGroup': true,
        'createdBy': _currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSender': '',
        'unreadCounts': unreadCounts,
      });

      print('✅ Group chat created: ${chatRef.id}');
      return chatRef.id;
    } catch (e) {
      print('❌ Error creating group chat: $e');
      return null;
    }
  }

  // ========== MESSAGE MANAGEMENT ==========

  Future<void> getMessages(String chatId) async {
    if (!_isConnected || _currentUserId == null) {
      print('❌ Not connected or no user ID');
      _messagesController.add([]);
      return;
    }

    try {
      print('📨 Fetching messages for chat: $chatId');

      _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots()
          .listen((snapshot) {
        List<ChatMessage> messages = [];

        for (var doc in snapshot.docs) {
          try {
            final message = _messageFromDocument(doc);
            if (message != null) {
              messages.add(message);
            }
          } catch (e) {
            print('❌ Error processing message document ${doc.id}: $e');
          }
        }

        print('✅ Loaded ${messages.length} messages');
        _messagesController.add(messages);
      });
    } catch (e) {
      print('❌ Error getting messages: $e');
      _messagesController.add([]);
    }
  }

  // Fixed _messageFromDocument method for your ChatController

  ChatMessage? _messageFromDocument(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;

      print('🔧 Converting document to ChatMessage: ${doc.id}');
      print('📄 Document data: $data');

      // Parse MessageType safely
      MessageType messageType = MessageType.text;
      if (data['type'] != null) {
        try {
          final typeString = data['type'].toString();
          messageType = MessageType.values.firstWhere(
                (type) => type.toString() == typeString || type.name == typeString.split('.').last,
            orElse: () => MessageType.text,
          );
        } catch (e) {
          print('⚠️ Error parsing message type, defaulting to text: $e');
        }
      }

      // Handle imageUrl - can be in different fields
      String? finalImageUrl;
      if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
        finalImageUrl = data['imageUrl'].toString();
      } else if (messageType == MessageType.image && data['text'] != null && data['text'].toString().startsWith('http')) {
        finalImageUrl = data['text'].toString();
      }

      // Handle readBy list safely
      List<String> readByList = [];
      if (data['readBy'] != null) {
        try {
          if (data['readBy'] is List) {
            readByList = List<String>.from(data['readBy']);
          } else if (data['readBy'] is String) {
            readByList = [data['readBy']];
          }
        } catch (e) {
          print('⚠️ Error parsing readBy list: $e');
        }
      }

      final message = ChatMessage(
        id: doc.id,
        chatId: data['chatId']?.toString() ?? '',
        senderId: data['senderId']?.toString() ?? '',
        senderName: data['senderName']?.toString() ?? 'Unknown',
        text: data['text']?.toString() ?? '',
        timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        type: messageType,
        imageUrl: finalImageUrl,
        readBy: readByList,
        replyToMessageId: data['replyToMessageId']?.toString(),
      );

      print('✅ Successfully created ChatMessage: ${message.id}');
      return message;

    } catch (e) {
      print('❌ Error converting message document: $e');
      print('📄 Document ID: ${doc.id}');
      print('📄 Document data: ${doc.data()}');

      // Return a basic message as fallback
      return ChatMessage(
        id: doc.id,
        chatId: '',
        senderId: 'error',
        senderName: 'Error',
        text: 'Failed to load message',
        timestamp: DateTime.now(),
        type: MessageType.text,
        readBy: [],
      );
    }
  }

  Future<void> sendTextMessage({
    required String chatId,
    required String text,
    String? replyToMessageId,
  }) async {
    if (!_isConnected || _currentUserId == null) {
      throw Exception('Not connected or no user ID');
    }

    try {
      print('💬 Sending text message to chat: $chatId');

      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();

      await messageRef.set({
        'chatId': chatId,
        'senderId': _currentUserId,
        'senderName': _currentUserName ?? 'Unknown User',
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'type': MessageType.text.toString(),
        'readBy': [_currentUserId],
        'replyToMessageId': replyToMessageId,
      });

      // Update chat's last message
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': text,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSender': _currentUserId,
      });

      print('✅ Text message sent successfully');
    } catch (e) {
      print('❌ Error sending text message: $e');
      rethrow;
    }
  }

  Future<void> sendImageMessage({
    required String chatId,
    required File imageFile,
    String? caption,
  }) async {
    if (!_isConnected || _currentUserId == null) {
      throw Exception('Not connected or no user ID');
    }

    try {
      print('📷 Sending image message to chat: $chatId');

      // Upload image to Firebase Storage
      final fileName = 'chat_images/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
      final storageRef = _storage.ref().child(fileName);

      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask;
      final imageUrl = await snapshot.ref.getDownloadURL();

      // Send message with image URL
      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();

      await messageRef.set({
        'chatId': chatId,
        'senderId': _currentUserId,
        'senderName': _currentUserName ?? 'Unknown User',
        'text': caption ?? '📷 Image',
        'timestamp': FieldValue.serverTimestamp(),
        'type': MessageType.image.toString(),
        'imageUrl': imageUrl,
        'readBy': [_currentUserId],
      });

      // Update chat's last message
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': caption ?? '📷 Image',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSender': _currentUserId,
      });

      print('✅ Image message sent successfully');
    } catch (e) {
      print('❌ Error sending image message: $e');
      rethrow;
    }
  }

  Future<void> markAsRead(String chatId) async {
    if (!_isConnected || _currentUserId == null) return;

    try {
      // Reset unread count for current user
      await _firestore.collection('chats').doc(chatId).update({
        'unreadCounts.$_currentUserId': 0,
      });

      print('✅ Chat marked as read: $chatId');
    } catch (e) {
      print('❌ Error marking chat as read: $e');
    }
  }

  // ========== USER SEARCH ==========

  Future<List<AppUser>> searchUsers(String query) async {
    if (!_isConnected || _currentUserId == null) {
      return [];
    }

    try {
      print('🔍 Searching users: $query');

      final querySnapshot = await _firestore
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: query + 'z')
          .limit(20)
          .get();

      List<AppUser> users = [];
      for (var doc in querySnapshot.docs) {
        if (doc.id != _currentUserId) {
          final data = doc.data();
          users.add(AppUser(
            id: doc.id,
            name: data['name'] ?? 'Unknown User',
            email: data['email'] ?? '',
            avatar: data['avatar'] ?? '',
            isOnline: data['isOnline'] ?? false,
          ));
        }
      }

      print('✅ Found ${users.length} users');
      return users;
    } catch (e) {
      print('❌ Error searching users: $e');
      return [];
    }
  }

  // ========== LEAVE CHAT ==========

  Future<void> leaveChat(String chatId) async {
    if (!_isConnected || _currentUserId == null) {
      throw Exception('Not connected or no user ID');
    }

    try {
      print('🚪 Leaving chat: $chatId');

      await _firestore.collection('chats').doc(chatId).update({
        'participants': FieldValue.arrayRemove([_currentUserId]),
        'unreadCounts.$_currentUserId': FieldValue.delete(),
      });

      print('✅ Left chat successfully');
    } catch (e) {
      print('❌ Error leaving chat: $e');
      rethrow;
    }
  }

  // ========== CLEAN UP ==========

  @override
  void onClose() {
    print('🧹 FirebaseChatService: Cleaning up...');
    _chatsController.close();
    _messagesController.close();
    super.onClose();
  }
}