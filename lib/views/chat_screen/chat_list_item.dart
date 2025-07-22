// chat_list_item.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/images.dart';

import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/views/chat_screen/chat_controller.dart';

class ChatListItem extends StatelessWidget {
  final dynamic chat; // Your Chat object
  final VoidCallback? onTap;

  const ChatListItem({
    Key? key,
    required this.chat,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ChatController chatController = Get.find<ChatController>();

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 56,
        height: 56,
        child: ClipOval(
          child: _buildChatImage(chatController),
        ),
      ),
      title: Text(
        _getChatDisplayName(chatController),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        chat.lastMessage ?? 'No messages yet',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(chat.lastMessageTimestamp),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
          if (_getUnreadCount(chatController) > 0) ...[
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: CustomColors.purpleColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getUnreadCount(chatController).toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatImage(ChatController chatController) {
    print('🖼️ Building chat image for: ${chat.id}');
    print('   Is Group: ${chat.isGroup}');

    if (chat.isGroup) {
      return _buildGroupImage(chatController);
    } else {
      return _buildPersonalChatImage(chatController);
    }
  }

  Widget _buildGroupImage(ChatController chatController) {
    print('👥 Building group image...');

    // Get the group image using the ChatController method
    final displayImage = chatController.getGroupDisplayImage(chat);
    print('   Group image: ${displayImage.length > 50 ? "${displayImage.substring(0, 50)}..." : displayImage}');
    print('   Image type: ${_getImageType(displayImage)}');

    // Base64 data URI (most common after updates)
    if (displayImage.startsWith('data:image')) {
      print('📸 Displaying base64 group image');
      try {
        final base64String = displayImage.split(',')[1];
        final bytes = base64Decode(base64String);

        return Image.memory(
          bytes,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('❌ Error loading base64 image: $error');
            return _buildErrorImage();
          },
        );
      } catch (e) {
        print('❌ Error decoding base64: $e');
        return _buildErrorImage();
      }
    }

    // HTTP URL
    else if (displayImage.startsWith('http')) {
      print('🌐 Displaying network group image');
      return Image.network(
        displayImage,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingImage();
        },
        errorBuilder: (context, error, stackTrace) {
          print('❌ Error loading network image: $error');
          return _buildDefaultGroupImage();
        },
      );
    }

    // Local file path
    else if (displayImage != CustomImage.userGroup && displayImage.isNotEmpty) {
      print('📁 Displaying local group image');
      try {
        return Image.file(
          File(displayImage),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('❌ Error loading local image: $error');
            return _buildDefaultGroupImage();
          },
        );
      } catch (e) {
        print('❌ Error with local file: $e');
        return _buildDefaultGroupImage();
      }
    }

    // Default group image
    else {
      print('📁 Using default group image');
      return _buildDefaultGroupImage();
    }
  }

  Widget _buildPersonalChatImage(ChatController chatController) {
    print('💬 Building personal chat image...');

    final displayImage = chatController.getPersonalChatDisplayImage(chat);
    print('   Personal image: $displayImage');

    if (displayImage.isNotEmpty && displayImage != CustomImage.avator) {
      if (displayImage.startsWith('data:image')) {
        try {
          final base64String = displayImage.split(',')[1];
          final bytes = base64Decode(base64String);

          return Image.memory(
            bytes,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildDefaultPersonalImage(),
          );
        } catch (e) {
          return _buildDefaultPersonalImage();
        }
      } else if (displayImage.startsWith('http')) {
        return Image.network(
          displayImage,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoadingImage();
          },
          errorBuilder: (context, error, stackTrace) => _buildDefaultPersonalImage(),
        );
      }
    }

    return _buildDefaultPersonalImage();
  }

  Widget _buildDefaultGroupImage() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: CustomColors.lightPurpleColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Image.asset(
          CustomImage.userGroup,
          width: 32,
          height: 32,
          fit: BoxFit.contain,
          color: CustomColors.purpleColor.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildDefaultPersonalImage() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: CustomColors.lightPurpleColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Image.asset(
          CustomImage.avator,
          width: 32,
          height: 32,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildLoadingImage() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: CustomColors.lightPurpleColor,
        shape: BoxShape.circle,
      ),
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
  }

  Widget _buildErrorImage() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Center(
        child: Icon(
          Icons.error_outline,
          color: Colors.red.shade400,
          size: 20,
        ),
      ),
    );
  }

  String _getChatDisplayName(ChatController chatController) {
    if (chat.isGroup) {
      return chat.name ?? 'Group Chat';
    } else {
      return chatController.getDisplayName(chat);
    }
  }

  int _getUnreadCount(ChatController chatController) {
    return chatController.getUnreadCount(chat.id);
  }

  String _formatTime(DateTime? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  String _getImageType(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return 'None';
    if (imageUrl.startsWith('data:image')) return 'Base64';
    if (imageUrl.startsWith('http')) return 'Network';
    if (imageUrl == CustomImage.userGroup) return 'Default';
    return 'Local';
  }
}