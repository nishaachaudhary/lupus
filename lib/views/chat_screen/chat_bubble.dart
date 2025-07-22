// lib/views/chat_screen/chat_bubble.dart
import 'package:flutter/material.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final String time;
  final bool isMe;
  final bool isRead;
  final String? imageUrl;
  final String messageType;
  final String? senderName;
  final bool isGroup;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const ChatBubble({
    super.key,
    required this.text,
    required this.time,
    required this.isMe,
    this.isRead = false,
    this.imageUrl,
    this.messageType = 'text',
    this.senderName,
    this.isGroup = false,
    this.onLongPress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Show sender name for group chats (only for others' messages)
            if (isGroup && !isMe && senderName != null)
              Padding(
                padding: EdgeInsets.only(
                  left: isMe ? 0 : 16,
                  right: isMe ? 16 : 0,
                  bottom: 4,
                ),
                child: Text(
                  senderName!,
                  style: semiLightStyle.copyWith(
                    fontSize: 12,
                    color: CustomColors.purpleColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            // Message bubble
            Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: isMe ? CustomColors.blue : Colors.grey.shade200,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Message content based on type
                    if (messageType == 'image' && imageUrl != null) ...[
                      _buildImageMessage(),
                      if (text.isNotEmpty && text != '📷 Image') ...[
                        const SizedBox(height: 8),
                        _buildTextContent(),
                      ],
                    ] else if (messageType == 'system') ...[
                      _buildSystemMessage(),
                    ] else ...[
                      _buildTextContent(),
                    ],

                    const SizedBox(height: 4),

                    // Time and read status
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: semiLightStyle.copyWith(
                            fontSize: 11,
                            color: isMe ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                        // Only show read receipts for messages sent by the user
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            isRead ? Icons.done_all : Icons.done,
                            size: 12,
                            color: isRead ? const Color(0xff56E8A7) : Colors.white70,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    return SizedBox(
      width: double.infinity,
      child: Text(
        text,
        style: semiLightStyle.copyWith(
          fontSize: 16,
          color: isMe ? Colors.white : Colors.black87,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildImageMessage() {
    return ClipRounded(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 200,
          maxHeight: 200,
        ),
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 200,
              height: 200,
              color: Colors.grey[200],
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 200,
              height: 200,
              color: Colors.grey[300],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image,
                    size: 40,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load image',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSystemMessage() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.info_outline,
          size: 16,
          color: isMe ? Colors.white70 : Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: semiLightStyle.copyWith(
              fontSize: 14,
              color: isMe ? Colors.white70 : Colors.grey[700],
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class ClipRounded extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const ClipRounded({
    super.key,
    required this.child,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: child,
    );
  }
}

// Enhanced ChatBubble for Firebase messages
class FirebaseChatBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isGroup;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const FirebaseChatBubble({
    super.key,
    required this.message,
    this.isGroup = false,
    this.onLongPress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChatBubble(
      text: message['text'] ?? '',
      time: message['time'] ?? '',
      isMe: message['isMe'] ?? false,
      isRead: message['isRead'] ?? false,
      imageUrl: message['imageUrl'],
      messageType: message['type'] ?? 'text',
      senderName: message['senderName'],
      isGroup: isGroup,
      onLongPress: onLongPress,
      onTap: onTap,
    );
  }
}