// Add these methods to your ChatController or create a new mixin/service

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lupus_care/views/chat_screen/chat_controller.dart';
import 'package:lupus_care/views/group_chat/group_chat_controller.dart';

class ChatRestrictions {

  // Check if current user is still a member of the group
  static bool isUserStillMember(String groupId, String userId) {
    try {
      if (Get.isRegistered<ChatController>()) {
        final chatController = Get.find<ChatController>();

        // Find the group in chats
        final allChats = [...chatController.personalChats, ...chatController.groupChats];
        final group = allChats.firstWhereOrNull((chat) => chat.id == groupId);

        if (group != null) {
          // Check if user is still in participants
          return group.participants.contains(userId);
        }
      }

      // Also check GroupController if available
      if (Get.isRegistered<GroupController>()) {
        final groupController = Get.find<GroupController>();
        if (groupController.groupId == groupId && groupController.groupData != null) {
          final members = groupController.groupData!['members'] as List?;
          final participants = groupController.groupData!['participants'] as List?;

          if (members != null) {
            return members.any((member) =>
            member['id'] == userId || member['user_id'] == userId);
          }

          if (participants != null) {
            return participants.contains(userId);
          }
        }
      }

      return false; // Default to restricted if can't verify
    } catch (e) {
      print("❌ Error checking user membership: $e");
      return false; // Default to restricted on error
    }
  }

  // Get current user ID (implement based on your auth system)
  static Future<String?> getCurrentUserId() async {
    try {
      // Replace with your actual user ID retrieval
      // Examples:
      // final user = FirebaseAuth.instance.currentUser;
      // return user?.uid;

      // final prefs = await SharedPreferences.getInstance();
      // return prefs.getString('user_id');

      // final authController = Get.find<AuthController>();
      // return authController.currentUserId;

      return "current_user_id"; // Replace with actual implementation
    } catch (e) {
      print("❌ Error getting current user ID: $e");
      return null;
    }
  }

  // Check if current user can perform actions in this group
  static Future<bool> canPerformGroupActions(String groupId) async {
    final userId = await getCurrentUserId();
    if (userId == null) return false;

    return isUserStillMember(groupId, userId);
  }

  // Show restriction message
  static void showRestrictionMessage() {
    Get.snackbar(
      'Access Restricted',
      'You are no longer a member of this group',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      icon: const Icon(Icons.warning, color: Colors.white),
    );
  }

  // Show message input restriction
  static void showMessageRestriction() {
    Get.snackbar(
      'Cannot Send Message',
      'You cannot send messages because you left this group',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      icon: const Icon(Icons.block, color: Colors.white),
    );
  }
}

// Enhanced ChatScreen with restrictions
class RestrictedChatInput extends StatefulWidget {
  final String groupId;
  final VoidCallback? onSendMessage;
  final TextEditingController? messageController;

  const RestrictedChatInput({
    Key? key,
    required this.groupId,
    this.onSendMessage,
    this.messageController,
  }) : super(key: key);

  @override
  State<RestrictedChatInput> createState() => _RestrictedChatInputState();
}

class _RestrictedChatInputState extends State<RestrictedChatInput> {
  bool _canSendMessages = true;
  bool _isCheckingMembership = true;

  @override
  void initState() {
    super.initState();
    _checkMembershipStatus();
  }

  Future<void> _checkMembershipStatus() async {
    final canPerform = await ChatRestrictions.canPerformGroupActions(widget.groupId);
    setState(() {
      _canSendMessages = canPerform;
      _isCheckingMembership = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingMembership) {
      return Container(
        height: 60,
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (!_canSendMessages) {
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.block, color: Colors.grey.shade600, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'You cannot send messages because you left this group',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Regular message input if user is still a member
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.newline,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.blue,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () async {
                // Double-check membership before sending
                final canSend = await ChatRestrictions.canPerformGroupActions(widget.groupId);
                if (canSend) {
                  widget.onSendMessage?.call();
                } else {
                  ChatRestrictions.showMessageRestriction();
                  // Refresh the input state
                  _checkMembershipStatus();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Restricted Group Options (for app bar or options menu)
class RestrictedGroupOptions extends StatelessWidget {
  final String groupId;
  final List<Widget> normalOptions;

  const RestrictedGroupOptions({
    Key? key,
    required this.groupId,
    required this.normalOptions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: ChatRestrictions.canPerformGroupActions(groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final canPerformActions = snapshot.data ?? false;

        if (!canPerformActions) {
          // Show restricted options or empty
          return PopupMenuButton<String>(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'restricted',
                enabled: false,
                child: Row(
                  children: [
                    Icon(Icons.block, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      'Limited access - You left this group',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        // Show normal options if user is still a member
        return Row(children: normalOptions);
      },
    );
  }
}

// Extension for ChatController to handle restrictions
extension ChatControllerRestrictions on ChatController {

  Future<bool> canSendMessage(String chatId) async {
    return await ChatRestrictions.canPerformGroupActions(chatId);
  }

  Future<void> sendMessageWithRestrictionCheck(String chatId, String message) async {
    final canSend = await canSendMessage(chatId);

    if (!canSend) {
      ChatRestrictions.showMessageRestriction();
      return;
    }

    // Proceed with normal message sending
    // Your existing sendMessage logic here
    print("✅ Sending message: $message");
  }

  void blockRestrictedActions(String chatId, VoidCallback action, [String? customMessage]) {
    ChatRestrictions.canPerformGroupActions(chatId).then((canPerform) {
      if (canPerform) {
        action.call();
      } else {
        if (customMessage != null) {
          Get.snackbar(
            'Action Restricted',
            customMessage,
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
        } else {
          ChatRestrictions.showRestrictionMessage();
        }
      }
    });
  }
}