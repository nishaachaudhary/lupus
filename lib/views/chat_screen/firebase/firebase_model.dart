

import 'package:cloud_firestore/cloud_firestore.dart';



class AppUser {
  final String id;
  final String name;
  final String email;
  final String avatar;
  final bool isOnline;
  bool isSelected;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatar = '',
    this.isOnline = false,
    this.isSelected = false,
  });

  factory AppUser.fromFirestore(Map<String, dynamic> data, String id) {
    return AppUser(
      id: id,
      name: data['name'] ?? 'Unknown User',
      email: data['email'] ?? '',
      avatar: data['avatar'] ?? '',
      isOnline: data['isOnline'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar': avatar,
      'isOnline': isOnline,
      'lastSeen': DateTime.now(),
      'createdAt': DateTime.now(),
    };
  }

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    String? avatar,
    bool? isOnline,
    bool? isSelected,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      isOnline: isOnline ?? this.isOnline,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppUser && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'AppUser(id: $id, name: $name, email: $email, isOnline: $isOnline)';
  }
}

class ParticipantInfo {
  final String id;
  final String name;
  final String avatar;
  final bool isOnline;

  ParticipantInfo({
    required this.id,
    required this.name,
    this.avatar = '',
    this.isOnline = false,
  });

  factory ParticipantInfo.fromFirestore(Map<String, dynamic> data, String id) {
    return ParticipantInfo(
      id: id,
      name: data['name'] ?? 'Unknown User',
      avatar: data['avatar'] ?? '',
      isOnline: data['isOnline'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'isOnline': isOnline,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParticipantInfo && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ParticipantInfo(id: $id, name: $name, isOnline: $isOnline)';
  }
}

class Chat {
  final String id;
  final String name;
  final List<String> participants;
  final bool isGroup;
  final String description;
  final String createdBy;
  final DateTime createdAt;
  final String lastMessage;
  final DateTime lastMessageTimestamp;
  final String lastMessageSender;
  final Map<String, ParticipantInfo> participantDetails;
  final Map<String, int> unreadCounts;
  final String? apiGroupId; // Add this property to link with API groups
  final String? groupImage; // Add this for group image support
  final Map<String, dynamic>? groupData;
  final bool isTemporary;


  Chat({
    required this.id,
    this.name = '',
    required this.participants,
    this.isGroup = false,
    this.description = '',
    this.createdBy = '',
    DateTime? createdAt,
    this.lastMessage = '',
    DateTime? lastMessageTimestamp,
    this.lastMessageSender = '',
    this.participantDetails = const {},
    this.unreadCounts = const {},
    this.apiGroupId, // Add to constructor
    this.groupImage,
    this.isTemporary = false,
    this.groupData,// Add to constructor
  })  : createdAt = createdAt ?? DateTime.now(),
        lastMessageTimestamp = lastMessageTimestamp ?? DateTime.now();

  factory Chat.fromFirestore(Map<String, dynamic> data, String id) {
    // Parse participants
    final participants = List<String>.from(data['participants'] ?? []);

    // Parse participant details
    Map<String, ParticipantInfo> participantDetails = {};
    final participantDetailsData = data['participantDetails'] as Map<String, dynamic>? ?? {};
    participantDetailsData.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        participantDetails[key] = ParticipantInfo.fromFirestore(value, key);
      }
    });

    // Parse unread counts
    Map<String, int> unreadCounts = {};
    final unreadCountsData = data['unreadCounts'] as Map<String, dynamic>? ?? {};
    unreadCountsData.forEach((key, value) {
      unreadCounts[key] = value is int ? value : 0;
    });

    return Chat(
      id: id,
      name: data['name'] ?? '',
      participants: participants,
      isGroup: data['isGroup'] ?? false,
      description: data['description'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as DateTime?) ?? DateTime.now(),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTimestamp: (data['lastMessageTimestamp'] as DateTime?) ?? DateTime.now(),
      lastMessageSender: data['lastMessageSender'] ?? '',
      participantDetails: participantDetails,
      unreadCounts: unreadCounts,
      apiGroupId: data['apiGroupId']?.toString(), // Add this line
      groupImage: data['groupImage']?.toString(), // Add this line
    );
  }

  Map<String, dynamic> toFirestore() {
    // Convert participant details to Map
    Map<String, dynamic> participantDetailsMap = {};
    participantDetails.forEach((key, value) {
      participantDetailsMap[key] = value.toFirestore();
    });

    return {
      'name': name,
      'participants': participants,
      'isGroup': isGroup,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'lastMessage': lastMessage,
      'lastMessageTimestamp': lastMessageTimestamp,
      'lastMessageSender': lastMessageSender,
      'participantDetails': participantDetailsMap,
      'unreadCounts': unreadCounts,
      'apiGroupId': apiGroupId, // Add this line
      'groupImage': groupImage, // Add this line
    };
  }

  // Get display name for current user
  String getDisplayName(String? currentUserId) {
    if (isGroup) {
      return name.isNotEmpty ? name : 'Group Chat';
    }

    // For direct chats, find the other participant
    final otherParticipantId = participants.firstWhere(
          (id) => id != currentUserId,
      orElse: () => participants.isNotEmpty ? participants.first : '',
    );

    if (otherParticipantId.isNotEmpty && participantDetails.containsKey(otherParticipantId)) {
      return participantDetails[otherParticipantId]!.name;
    }

    return 'Unknown User';
  }

  // Get display avatar for current user
  String? getDisplayAvatar(String? currentUserId) {
    if (isGroup) {
      // Return group image if available
      return groupImage?.isNotEmpty == true ? groupImage : null;
    }

    // For direct chats, find the other participant
    final otherParticipantId = participants.firstWhere(
          (id) => id != currentUserId,
      orElse: () => participants.isNotEmpty ? participants.first : '',
    );

    if (otherParticipantId.isNotEmpty && participantDetails.containsKey(otherParticipantId)) {
      final avatar = participantDetails[otherParticipantId]!.avatar;
      return avatar.isNotEmpty ? avatar : null;
    }

    return null;
  }

  // Get unread count for current user
  int get unreadCount {
    return unreadCounts.values.fold(0, (sum, count) => sum + count);
  }

  // Get unread count for specific user
  int getUnreadCountForUser(String userId) {
    return unreadCounts[userId] ?? 0;
  }

  // Check if user is online (for direct chats)
  bool isOtherUserOnline(String? currentUserId) {
    if (isGroup) return false;

    final otherParticipantId = participants.firstWhere(
          (id) => id != currentUserId,
      orElse: () => '',
    );

    if (otherParticipantId.isNotEmpty && participantDetails.containsKey(otherParticipantId)) {
      return participantDetails[otherParticipantId]!.isOnline;
    }

    return false;
  }

  Chat copyWith({
    String? id,
    String? name,
    List<String>? participants,
    bool? isGroup,
    String? description,
    String? createdBy,
    DateTime? createdAt,
    String? lastMessage,
    DateTime? lastMessageTimestamp,
    String? lastMessageSender,
    Map<String, ParticipantInfo>? participantDetails,
    Map<String, int>? unreadCounts,
    String? apiGroupId, // Add this parameter
    String? groupImage, // Add this parameter
  }) {
    return Chat(
      id: id ?? this.id,
      name: name ?? this.name,
      participants: participants ?? this.participants,
      isGroup: isGroup ?? this.isGroup,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      lastMessageSender: lastMessageSender ?? this.lastMessageSender,
      participantDetails: participantDetails ?? this.participantDetails,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      apiGroupId: apiGroupId ?? this.apiGroupId, // Add this line
      groupImage: groupImage ?? this.groupImage, // Add this line
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Chat && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Chat(id: $id, name: $name, isGroup: $isGroup, participants: ${participants.length}, apiGroupId: $apiGroupId)';
  }
}



enum MessageType {
  text,
  image,
  system,
  file,
  video,
  audio,
}

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final MessageType type;
  final String? imageUrl;
  final String? videoUrl;
  final String? audioUrl;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize; // ADD: File size in bytes
  final String? mimeType; // ADD: MIME type for files
  final String? replyToMessageId;
  final List<String> readBy;
  final DateTime? sentAt;
  final List<String> deliveredTo;


  ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.type,
    this.imageUrl,
    this.videoUrl,
    this.audioUrl,
    this.fileUrl,
    this.fileName,
    this.sentAt,
    this.fileSize, // ADD: Include in constructor
    this.mimeType, // ADD: Include in constructor
    this.replyToMessageId,
    this.deliveredTo = const [],
    this.readBy = const [],

  });


  bool get hasMedia {
    return type == MessageType.image ||
        type == MessageType.video ||
        type == MessageType.audio ||
        type == MessageType.file ||
        imageUrl != null ||
        videoUrl != null ||
        audioUrl != null ||
        fileUrl != null;
  }


  bool isDeliveredTo(String userId) => deliveredTo.contains(userId);

  bool isReadBy(String userId) => readBy.contains(userId);


  bool get isImageMessage => type == MessageType.image;


  bool get isVideoMessage => type == MessageType.video;

  // Check if message is an audio
  bool get isAudioMessage => type == MessageType.audio;

  // Check if message is a file
  bool get isFileMessage => type == MessageType.file;

  // Check if message is a system message
  bool get isSystemMessage => type == MessageType.system;

  // Check if message is a text message
  bool get isTextMessage => type == MessageType.text;

  // Get the appropriate media URL based on message type
  String? getMediaUrl() {
    switch (type) {
      case MessageType.image:
        return getImageUrl();
      case MessageType.video:
        return videoUrl;
      case MessageType.audio:
        return audioUrl;
      case MessageType.file:
        return fileUrl;
      default:
        return null;
    }
  }

  // Enhanced image URL detection
  String? getImageUrl() {
    // First check the dedicated imageUrl field
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      print('✅ Found imageUrl: ${imageUrl!.length > 50 ? "${imageUrl!.substring(0, 50)}..." : imageUrl}');
      return imageUrl;
    }

    // If message type is image, check if text contains URL or base64
    if (type == MessageType.image && text.isNotEmpty) {
      // Check for base64 data URI
      if (text.startsWith('data:image')) {
        print('✅ Found base64 image in text');
        return text;
      }

      // Check if text is a direct URL
      if (text.startsWith('http')) {
        print('✅ Found image URL in text: $text');
        return text;
      }

      // Check for Firebase Storage URLs
      if (text.contains('firebasestorage.googleapis.com')) {
        print('✅ Found Firebase Storage URL in text: $text');
        return text;
      }

      // Check for other common image hosting services
      if (_isImageUrl(text)) {
        print('✅ Found image URL in text: $text');
        return text;
      }
    }

    print('❌ No image URL found for message: $id');
    return null;
  }

  // Helper method to check if a string is an image URL
  bool _isImageUrl(String url) {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
    final lowerUrl = url.toLowerCase();

    return imageExtensions.any((ext) => lowerUrl.contains(ext)) ||
        lowerUrl.contains('firebasestorage.googleapis.com') ||
        lowerUrl.contains('cloudinary.com') ||
        lowerUrl.contains('amazonaws.com') ||
        lowerUrl.contains('imgur.com') ||
        lowerUrl.contains('unsplash.com') ||
        lowerUrl.contains('imgbb.com');
  }

  // Get formatted file size
  String get formattedFileSize {
    if (fileSize == null) return '';

    if (fileSize! < 1024) {
      return '${fileSize} B';
    } else if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  // Mark message as read by a user
  ChatMessage markAsReadBy(String userId) {
    if (!readBy.contains(userId)) {
      final newReadBy = List<String>.from(readBy)..add(userId);
      return copyWith(readBy: newReadBy);
    }
    return this;
  }

  // Create a copy with updated fields
  ChatMessage copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    String? text,
    DateTime? timestamp,
    MessageType? type,
    String? imageUrl,
    String? videoUrl,
    String? audioUrl,
    String? fileUrl,
    String? fileName,
    int? fileSize, // ADD: Include in copyWith
    String? mimeType, // ADD: Include in copyWith
    String? replyToMessageId,
    List<String>? readBy,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize, // ADD: Include in copyWith
      mimeType: mimeType ?? this.mimeType, // ADD: Include in copyWith
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      readBy: readBy ?? this.readBy,
    );
  }

  // Convert to map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type.toString(),
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (videoUrl != null) 'videoUrl': videoUrl,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
      if (fileSize != null) 'fileSize': fileSize, // ADD: Include in toMap
      if (mimeType != null) 'mimeType': mimeType, // ADD: Include in toMap
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      'readBy': readBy,
    };
  }

  // Create from Firebase document
  factory ChatMessage.fromMap(Map<String, dynamic> map, String docId) {
    // Parse message type
    MessageType msgType = MessageType.text;
    if (map['type'] != null) {
      String typeStr = map['type'].toString().toLowerCase();

      if (typeStr.contains('image')) {
        msgType = MessageType.image;
      } else if (typeStr.contains('video')) {
        msgType = MessageType.video;
      } else if (typeStr.contains('audio')) {
        msgType = MessageType.audio;
      } else if (typeStr.contains('file')) {
        msgType = MessageType.file;
      } else if (typeStr.contains('system')) {
        msgType = MessageType.system;
      }
    }

    // Handle timestamp
    DateTime messageTimestamp = DateTime.now();
    if (map['timestamp'] is Timestamp) {
      messageTimestamp = (map['timestamp'] as Timestamp).toDate();
    } else if (map['timestamp'] is DateTime) {
      messageTimestamp = map['timestamp'];
    }

    return ChatMessage(
      id: docId,
      chatId: map['chatId']?.toString() ?? '',
      senderId: map['senderId']?.toString() ?? '',
      senderName: map['senderName']?.toString() ?? 'Unknown',
      text: map['text']?.toString() ?? '',
      timestamp: messageTimestamp,
      type: msgType,
      imageUrl: map['imageUrl']?.toString(),
      videoUrl: map['videoUrl']?.toString(),
      audioUrl: map['audioUrl']?.toString(),
      fileUrl: map['fileUrl']?.toString(),
      fileName: map['fileName']?.toString(),
      fileSize: map['fileSize'] as int?, // ADD: Parse fileSize
      mimeType: map['mimeType']?.toString(), // ADD: Parse mimeType
      replyToMessageId: map['replyToMessageId']?.toString(),
      readBy: List<String>.from(map['readBy'] ?? []),
    );
  }

  MessageStatus getMessageStatus(String currentUserId, List<String> chatParticipants) {
    // Don't show status for messages from others
    if (senderId != currentUserId) {
      return MessageStatus.sent; // Default for non-current user messages
    }

    // Get other participants (excluding current user)
    final otherParticipants = chatParticipants.where((id) => id != currentUserId).toList();

    if (otherParticipants.isEmpty) {
      return MessageStatus.sent; // No other participants
    }

    // Check if all other participants have read the message
    bool allRead = otherParticipants.every((participantId) => readBy.contains(participantId));

    if (allRead) {
      return MessageStatus.read; // Blue double tick
    }

    // Check if message is delivered (at least one participant received it)
    // For simplicity, we'll consider a message delivered if it's been sent and has timestamp
    // In a more complex system, you might track delivery separately
    bool isDelivered = otherParticipants.any((participantId) =>
    readBy.contains(participantId) ||
        timestamp.isBefore(DateTime.now().subtract(Duration(seconds: 5)))
    );

    if (isDelivered) {
      return MessageStatus.delivered; // Double tick
    }

    return MessageStatus.sent; // Single tick
  }

  // Check if message is read by all participants (excluding sender)
  bool isReadByAll(String currentUserId, List<String> chatParticipants) {
    final otherParticipants = chatParticipants.where((id) => id != currentUserId).toList();
    return otherParticipants.every((participantId) => readBy.contains(participantId));
  }

  // Check if message is delivered to any participant
  bool isDelivered(String currentUserId, List<String> chatParticipants) {
    final otherParticipants = chatParticipants.where((id) => id != currentUserId).toList();
    return otherParticipants.any((participantId) =>
    readBy.contains(participantId) ||
        timestamp.isBefore(DateTime.now().subtract(Duration(seconds: 5)))
    );
  }
  // Convert to compatible map format (for legacy compatibility)
  Map<String, dynamic> toCompatibleMap(String currentUserId) {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'type': type.toString(),
      'isMe': senderId == currentUserId,
      'isRead': readBy.contains(currentUserId),
      'hasMedia': hasMedia,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (videoUrl != null) 'videoUrl': videoUrl,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
      if (fileSize != null) 'fileSize': fileSize, // ADD: Include in compatible map
      if (mimeType != null) 'mimeType': mimeType, // ADD: Include in compatible map
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      'readBy': readBy,
    };
  }

  // Get display text for message preview
  String get displayText {
    switch (type) {
      case MessageType.image:
        return '📷 Image';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.audio:
        return '🎵 Audio';
      case MessageType.file:
        return fileName != null ? '📎 $fileName' : '📎 File';
      case MessageType.system:
        return text;
      default:
        return text.isNotEmpty ? text : 'Message';
    }
  }

  // Check if message is empty
  bool get isEmpty {
    return text.isEmpty &&
        imageUrl == null &&
        videoUrl == null &&
        audioUrl == null &&
        fileUrl == null;
  }

  // Check if message is not empty
  bool get isNotEmpty => !isEmpty;

  @override
  String toString() {
    return 'ChatMessage(id: $id, type: $type, text: "$text", hasMedia: $hasMedia)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Extension for message list operations
extension MessageListExtensions on List<ChatMessage> {
  List<ChatMessage> get unreadMessages => where((msg) => msg.readBy.isEmpty).toList();
  List<ChatMessage> get mediaMessages => where((msg) => msg.hasMedia).toList();

  List<ChatMessage> fromSender(String senderId) =>
      where((msg) => msg.senderId == senderId).toList();

  List<ChatMessage> ofType(MessageType type) =>
      where((msg) => msg.type == type).toList();

  List<ChatMessage> get imageMessages =>
      where((msg) => msg.type == MessageType.image).toList();

  List<ChatMessage> get textMessages =>
      where((msg) => msg.type == MessageType.text).toList();

  List<ChatMessage> get systemMessages =>
      where((msg) => msg.type == MessageType.system).toList();

  List<ChatMessage> get videoMessages =>
      where((msg) => msg.type == MessageType.video).toList();

  List<ChatMessage> get audioMessages =>
      where((msg) => msg.type == MessageType.audio).toList();

  List<ChatMessage> get fileMessages =>
      where((msg) => msg.type == MessageType.file).toList();

  List<ChatMessage> readBy(String userId) =>
      where((msg) => msg.isReadBy(userId)).toList();

  List<ChatMessage> unreadBy(String userId) =>
      where((msg) => !msg.isReadBy(userId)).toList();

  // Get messages from today
  List<ChatMessage> get today {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return where((msg) => msg.timestamp.isAfter(today)).toList();
  }

  // Get messages from yesterday
  List<ChatMessage> get yesterday {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final today = DateTime(now.year, now.month, now.day);
    return where((msg) =>
    msg.timestamp.isAfter(yesterday) &&
        msg.timestamp.isBefore(today)).toList();
  }

  // Get messages from last week
  List<ChatMessage> get lastWeek {
    final now = DateTime.now();
    final weekAgo = now.subtract(Duration(days: 7));
    return where((msg) => msg.timestamp.isAfter(weekAgo)).toList();
  }

  // Get unread count for specific user
  int unreadCountFor(String userId) {
    return unreadBy(userId).length;
  }

  // Get latest message
  ChatMessage? get latest {
    if (isEmpty) return null;
    return reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);
  }

  // Get oldest message
  ChatMessage? get oldest {
    if (isEmpty) return null;
    return reduce((a, b) => a.timestamp.isBefore(b.timestamp) ? a : b);
  }

  // Sort by timestamp (newest first)
  List<ChatMessage> get sortedByNewest {
    final sorted = List<ChatMessage>.from(this);
    sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted;
  }

  // Sort by timestamp (oldest first)
  List<ChatMessage> get sortedByOldest {
    final sorted = List<ChatMessage>.from(this);
    sorted.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return sorted;
  }
}

// Utility class for chat statistics
class ChatStats {
  final int totalMessages;
  final int unreadMessages;
  final DateTime? lastActivity;
  final int activeUsers;

  const ChatStats({
    this.totalMessages = 0,
    this.unreadMessages = 0,
    this.lastActivity,
    this.activeUsers = 0,
  });

  factory ChatStats.fromFirestore(Map<String, dynamic> data) {
    return ChatStats(
      totalMessages: data['totalMessages'] ?? 0,
      unreadMessages: data['unreadMessages'] ?? 0,
      lastActivity: data['lastActivity'] as DateTime?,
      activeUsers: data['activeUsers'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'totalMessages': totalMessages,
      'unreadMessages': unreadMessages,
      'lastActivity': lastActivity,
      'activeUsers': activeUsers,
    };
  }
}

// Extension methods for easier data handling
extension ChatListExtensions on List<Chat> {
  List<Chat> get personalChats => where((chat) => !chat.isGroup).toList();
  List<Chat> get groupChats => where((chat) => chat.isGroup).toList();

  List<Chat> searchByName(String query) {
    final lowerQuery = query.toLowerCase();
    return where((chat) =>
    chat.name.toLowerCase().contains(lowerQuery) ||
        chat.participants.any((participant) =>
        chat.participantDetails[participant]?.name.toLowerCase().contains(lowerQuery) ?? false
        )
    ).toList();
  }
}
enum MessageStatus {
  sent,      // Single tick - Message sent successfully
  delivered, // Double tick - Message delivered but not read by all
  read,      // Blue double tick - Message read by all recipients
}

