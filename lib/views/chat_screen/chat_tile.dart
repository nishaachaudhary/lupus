// lib/views/chat_screen/chat_tile.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/images.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/chat_screen/chat_controller.dart';
import 'package:lupus_care/views/chat_screen/firebase/firebase_model.dart';
import 'package:lupus_care/views/chat_screen/personal_chat_screen.dart';

class ChatTile extends StatelessWidget {
  final Chat chat;

  const ChatTile({
    super.key,
    required this.chat,
  });

  String _getAvatar(String name) {
    List<String> avatars = [
      CustomImage.avator,
      CustomImage.avator1,
    ];
    int index = name.hashCode % avatars.length;
    return avatars[index];
  }

  String _getLastMessagePreview(String lastMessage, bool isGroup,
      String? senderId, String? currentUserId) {
    // if (lastMessage.isEmpty) {
    //   return isGroup ? 'Group created' : 'Chat started';
    // }

    // Handle different message types
    if (lastMessage.startsWith('📷')) {
      return isGroup && senderId != currentUserId ? 'Photo' : lastMessage;
    }

    // Truncate long messages
    if (lastMessage.length > 30) {
      return '${lastMessage.substring(0, 30)}...';
    }

    return lastMessage;
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      // More than a week ago - show date
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inDays > 0) {
      // Days ago
      if (difference.inDays == 1) {
        return 'Yesterday';
      } else {
        return '${difference.inDays}d ago';
      }
    } else if (difference.inHours > 0) {
      // Hours ago
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      // Minutes ago
      return '${difference.inMinutes}m ago';
    } else {
      // Just now
      return 'Now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ChatController controller = Get.find<ChatController>();
    final currentUserId = controller.currentUserId;
    final displayName = chat.getDisplayName(currentUserId);
    final displayAvatar = chat.getDisplayAvatar(currentUserId);
    final unreadCount = chat.getUnreadCountForUser(currentUserId ?? '');
    final lastMessagePreview = _getLastMessagePreview(
      chat.lastMessage,
      chat.isGroup,
      chat.lastMessageSender,
      currentUserId,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            // Avatar
            chat.isGroup
                ? Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: CustomColors.lightPurpleColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          CustomImage.userGroup,
                          width: 24,
                          height: 24,
                        ),
                      ),
                    ),
                  )
                : CircleAvatar(
                    radius: 24,
                    child: ClipOval(
                      child: displayAvatar != null &&
                              displayAvatar.startsWith('http')
                          ? Image.network(
                              displayAvatar,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  _getAvatar(displayName),
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                );
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  width: 48,
                                  height: 48,
                                  color: Colors.grey[300],
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: CustomColors.purpleColor,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )
                          : Image.asset(
                              displayAvatar ?? _getAvatar(displayName),
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),

            // Online indicator for direct chats
            if (!chat.isGroup && _isUserOnline(currentUserId))
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),

            // Unread count badge
            if (unreadCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  decoration: BoxDecoration(
                    color: CustomColors.purpleColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                style: mediumStyle.copyWith(
                  fontSize: Dimensions.fontSizeLarge,
                  fontWeight:
                      unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _formatMessageTime(chat.lastMessageTimestamp),
              style: regularStyle.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: unreadCount > 0
                    ? CustomColors.purpleColor
                    : Colors.grey[500],
                fontWeight:
                    unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            // Message status indicator for sent messages
            if (chat.lastMessageSender == currentUserId && !chat.isGroup) ...[
              Icon(
                Icons.done,
                size: 14,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 4),
            ],

            // Group message sender name
            if (chat.isGroup &&
                chat.lastMessageSender != currentUserId &&
                chat.lastMessage.isNotEmpty &&
                chat.lastMessageSender.isNotEmpty) ...[
              Text(
                '${_getSenderName(chat.lastMessageSender)}: ',
                style: regularStyle.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                  color: CustomColors.purpleColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            // Last message preview
            Expanded(
              child: Text(
                lastMessagePreview,
                style: regularStyle.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                  color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                  fontWeight:
                      unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        onTap: () {
          // Navigate to chat screen
          Get.to(() => PersonalChatScreen(chat: chat));
        },
        onLongPress: () {
          // Show options menu
          _showChatOptions(context);
        },
      ),
    );
  }

  bool _isUserOnline(String? currentUserId) {
    if (chat.isGroup) return false;

    // Find the other participant
    final otherParticipantId = chat.participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    if (otherParticipantId.isNotEmpty &&
        chat.participantDetails.containsKey(otherParticipantId)) {
      return chat.participantDetails[otherParticipantId]!.isOnline;
    }

    return false;
  }

  String _getSenderName(String senderId) {
    if (senderId.isEmpty) return 'Unknown';

    if (chat.participantDetails.containsKey(senderId)) {
      return chat.participantDetails[senderId]!.name;
    }

    // Fallback to a shortened sender ID
    if (senderId.length > 8) {
      return 'User ${senderId.substring(0, 8)}';
    }

    return 'Unknown User';
  }

  void _showChatOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Chat info
            Row(
              children: [
                // Avatar
                chat.isGroup
                    ? Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: CustomColors.lightPurpleColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Image.asset(
                            CustomImage.userGroup,
                            width: 25,
                            height: 25,
                          ),
                        ),
                      )
                    : CircleAvatar(
                        radius: 25,
                        child: ClipOval(
                          child: Image.asset(
                            _getAvatar(chat.getDisplayName(
                                Get.find<ChatController>().currentUserId)),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                const SizedBox(width: 16),

                // Chat details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat.getDisplayName(
                            Get.find<ChatController>().currentUserId),
                        style: mediumStyle.copyWith(
                          fontSize: Dimensions.fontSizeLarge,
                        ),
                      ),
                      if (chat.isGroup)
                        Text(
                          '${chat.participants.length} members',
                          style: regularStyle.copyWith(
                            fontSize: Dimensions.fontSizeDefault,
                            color: Colors.grey[600],
                          ),
                        )
                      else
                        Text(
                          _isUserOnline(
                                  Get.find<ChatController>().currentUserId)
                              ? 'Online'
                              : 'Last seen recently',
                          style: regularStyle.copyWith(
                            fontSize: Dimensions.fontSizeDefault,
                            color: _isUserOnline(
                                    Get.find<ChatController>().currentUserId)
                                ? Colors.green
                                : Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Options
            ..._buildChatOptions(context),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildChatOptions(BuildContext context) {
    final ChatController controller = Get.find<ChatController>();
    final List<Widget> options = [];

    // Mark as read option (if there are unread messages)
    final unreadCount =
        chat.getUnreadCountForUser(controller.currentUserId ?? '');
    if (unreadCount > 0) {
      options.add(
        _buildOptionTile(
          icon: Icons.mark_email_read,
          title: 'Mark as read',
          onTap: () {
            Get.back();
            controller.loadMessages(chat.id); // This will mark as read
            Get.snackbar('Success', 'Chat marked as read');
          },
        ),
      );
    }

    // Mute option
    options.add(
      _buildOptionTile(
        icon: Icons.notifications_off_outlined,
        title: 'Mute notifications',
        onTap: () {
          Get.back();
          Get.snackbar('Info', 'Mute feature coming soon');
        },
      ),
    );

    // Clear chat option
    options.add(
      _buildOptionTile(
        icon: Icons.clear_all,
        title: 'Clear chat',
        onTap: () {
          Get.back();
          _showClearChatDialog(context);
        },
      ),
    );

    // Group-specific options
    if (chat.isGroup) {
      options.add(
        _buildOptionTile(
          icon: Icons.info_outline,
          title: 'Group info',
          onTap: () {
            Get.back();
            Get.snackbar('Info', 'Group info coming soon');
          },
        ),
      );

      options.add(
        _buildOptionTile(
          icon: Icons.exit_to_app,
          title: 'Leave group',
          isDestructive: true,
          onTap: () {
            Get.back();
            _showLeaveGroupDialog(context);
          },
        ),
      );
    } else {
      // Direct chat options
      options.add(
        _buildOptionTile(
          icon: Icons.person_outline,
          title: 'View profile',
          onTap: () {
            Get.back();
            Get.snackbar('Info', 'Profile view coming soon');
          },
        ),
      );

      options.add(
        _buildOptionTile(
          icon: Icons.block,
          title: 'Block user',
          isDestructive: true,
          onTap: () {
            Get.back();
            Get.snackbar('Info', 'Block feature coming soon');
          },
        ),
      );
    }

    return options;
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : Colors.grey[700],
      ),
      title: Text(
        title,
        style: regularStyle.copyWith(
          fontSize: Dimensions.fontSizeLarge,
          color: isDestructive ? Colors.red : Colors.black87,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  void _showClearChatDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('Clear Chat'),
        content: Text(
          'Are you sure you want to clear all messages in "${chat.getDisplayName(Get.find<ChatController>().currentUserId)}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              Get.snackbar('Info', 'Clear chat feature coming soon');
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showLeaveGroupDialog(BuildContext context) {
    final ChatController controller = Get.find<ChatController>();

    Get.dialog(
      AlertDialog(
        title: const Text('Leave Group'),
        content: Text(
          'Are you sure you want to leave "${chat.name.isEmpty ? 'this group' : chat.name}"?\n\nYou won\'t receive any more messages from this group.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Get.back();

              try {
                await controller.leaveGroup(chat.id);
                Get.snackbar(
                  'Success',
                  'Left group successfully',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } catch (e) {
                Get.snackbar(
                  'Error',
                  'Failed to leave group: $e',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
