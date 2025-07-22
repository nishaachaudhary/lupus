import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/images.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/chat_screen/chat_controller.dart';
import 'package:lupus_care/views/chat_screen/firebase/firebase_model.dart';
import 'package:lupus_care/views/group_chat/group_info_screen.dart';

class PersonalChatScreen extends StatefulWidget {
  final Chat chat;

  const PersonalChatScreen({super.key, required this.chat});

  @override
  State<PersonalChatScreen> createState() => _PersonalChatScreenState();
}

class _PersonalChatScreenState extends State<PersonalChatScreen> {
  final TextEditingController textController = TextEditingController();
  bool isEmojiVisible = false;
  late final ChatController controller;
  late final FocusNode focusNode;
  late final ScrollController _scrollController;

  // CRITICAL: Add membership checking variables for group restrictions
  bool _isUserStillMember = true;
  bool _isCheckingMembership = false;

  // Emoji categories and data
  final List<String> emojiCategories = [
    'Smileys & People',
    'Animals & Nature',
    'Food & Drink',
    'Activities',
    'Travel & Places',
    'Objects',
    'Symbols',
    'Flags'
  ];

  final Map<String, List<String>> emojiData = {
    'Smileys & People': [
      '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃',
      '😉', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗', '☺️', '😚',
      '😙', '🥲', '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭',
      '🤫', '🤔', '🤐', '🤨', '😐', '😑', '😶', '😏', '😒', '🙄',
      '😬', '🤥', '😔', '😪', '🤤', '😴', '😷', '🤒', '🤕', '🤢',
      '🤮', '🤧', '🥵', '🥶', '🥴', '😵', '🤯', '🤠', '🥳', '😎',
      '🤓', '🧐', '😕', '😟', '🙁', '☹️', '😮', '😯', '😲', '😳',
      '🥺', '😦', '😧', '😨', '😰', '😥', '😢', '😭', '😱', '😖',
      '😣', '😞', '😓', '😩', '😫', '🥱', '😤', '😡', '😠', '🤬',
      '👶', '🧒', '👦', '👧', '🧑', '👱', '👨', '🧔', '👩', '🧓',
      '👴', '👵', '🙍', '🙎', '🙅', '🙆', '💁', '🙋', '🧏', '🙇',
      '🤦', '🤷', '👮', '🕵️', '💂', '👷', '🤴', '👸', '👳', '👲',
      '🧕', '🤵', '👰', '🤰', '🤱', '👼', '🎅', '🤶', '🦸', '🦹',
      '🧙', '🧚', '🧛', '🧜', '🧝', '🧞', '🧟', '💆', '💇', '🚶',
      '🏃', '💃', '🕺', '🕴️', '👯', '🧖', '🧗', '🤺', '🏇', '⛷️',
      '🏂', '🏌️', '🏄', '🚣', '🏊', '⛹️', '🏋️', '🚴', '🚵', '🤸',
      '🤼', '🤽', '🤾', '🤹', '🧘', '🛀', '🛌', '👭', '👫', '👬',
      '💏', '💑', '👪', '👤', '👥', '👣', '🦰', '🦱', '🦳', '🦲'
    ],
    'Animals & Nature': [
      '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯',
      '🦁', '🐮', '🐷', '🐽', '🐸', '🐵', '🙈', '🙉', '🙊', '🐒',
      '🐔', '🐧', '🐦', '🐤', '🐣', '🐥', '🦆', '🦅', '🦉', '🦇',
      '🐺', '🐗', '🐴', '🦄', '🐝', '🐛', '🦋', '🐌', '🐞', '🐜',
      '🦟', '🦗', '🕷️', '🕸️', '🦂', '🐢', '🐍', '🦎', '🦖', '🦕',
      '🐙', '🦑', '🦐', '🦞', '🦀', '🐡', '🐠', '🐟', '🐬', '🐳',
      '🐋', '🦈', '🐊', '🐅', '🐆', '🦓', '🦍', '🦧', '🐘', '🦛',
      '🦏', '🐪', '🐫', '🦒', '🦘', '🐃', '🐂', '🐄', '🐎', '🐖',
      '🐏', '🐑', '🦙', '🐐', '🦌', '🐕', '🐩', '🦮', '🐕‍🦺', '🐈',
      '🐓', '🦃', '🦚', '🦜', '🦢', '🦩', '🕊️', '🐇', '🦝', '🦨',
      '🦡', '🦦', '🦥', '🐁', '🐀', '🐿️', '🦔', '🌲', '🌳', '🌴',
      '🌵', '🌶️', '🍄', '🌾', '💐', '🌷', '🌹', '🥀', '🌺', '🌸',
      '🌼', '🌻', '🌞', '🌝', '🌛', '🌜', '🌚', '🌕', '🌖', '🌗',
      '🌘', '🌑', '🌒', '🌓', '🌔', '🌙', '🌎', '🌍', '🌏', '🔥',
      '💧', '🌊', '💥', '⭐', '🌟', '✨', '⚡', '☄️', '💫', '🌈'
    ],
    'Food & Drink': [
      '🍏', '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🫐',
      '🍈', '🍒', '🍑', '🥭', '🍍', '🥥', '🥝', '🍅', '🍆', '🥑',
      '🥦', '🥬', '🥒', '🌶️', '🫑', '🌽', '🥕', '🫒', '🧄', '🧅',
      '🥔', '🍠', '🥐', '🥯', '🍞', '🥖', '🥨', '🧀', '🥚', '🍳',
      '🧈', '🥞', '🧇', '🥓', '🥩', '🍗', '🍖', '🦴', '🌭', '🍔',
      '🍟', '🍕', '🫓', '🥪', '🥙', '🧆', '🌮', '🌯', '🫔', '🥗',
      '🥘', '🫕', '🍝', '🍜', '🍲', '🍛', '🍣', '🍱', '🥟', '🦪',
      '🍤', '🍙', '🍚', '🍘', '🍥', '🥠', '🥮', '🍢', '🍡', '🍧',
      '🍨', '🍦', '🥧', '🧁', '🍰', '🎂', '🍮', '🍭', '🍬', '🍫',
      '🍿', '🍩', '🍪', '🌰', '🥜', '🍯', '🥛', '🍼', '☕', '🫖',
      '🍵', '🧃', '🥤', '🍶', '🍺', '🍻', '🥂', '🍷', '🥃', '🍸',
      '🍹', '🧉', '🍾', '🧊', '🥄', '🍴', '🍽️', '🥣', '🥡', '🥢'
    ],
    'Activities': [
      '⚽', '🏀', '🏈', '⚾', '🥎', '🎾', '🏐', '🏉', '🥏', '🎱',
      '🪀', '🏓', '🏸', '🏒', '🏑', '🥍', '🏏', '⛳', '🪁', '🏹',
      '🎣', '🤿', '🥊', '🥋', '🎽', '🛹', '🛷', '⛸️', '🥌', '🎿',
      '⛷️', '🏂', '🪂', '🏋️', '🤸', '🤺', '🤾', '🏌️', '🏇', '🧘',
      '🏄', '🏊', '🤽', '🚣', '🧗', '🚵', '🚴', '🏆', '🥇', '🥈',
      '🥉', '🏅', '🎖️', '🏵️', '🎗️', '🎫', '🎟️', '🎪', '🤹', '🎭',
      '🩰', '🎨', '🎬', '🎤', '🎧', '🎼', '🎵', '🎶', '🥇', '🥈',
      '🥉', '🏆', '🏅', '🎖️', '🏵️', '🎗️', '🎫', '🎟️', '🎪', '🤹',
      '🎭', '🩰', '🎨', '🎬', '🎤', '🎧', '🎼', '🎵', '🎶', '🎹',
      '🥁', '🎷', '🎺', '🎸', '🪕', '🎻', '🎲', '♠️', '♥️', '♦️',
      '♣️', '♟️', '🃏', '🀄', '🎴', '🎯', '🎳', '🎮', '🕹️', '🎰'
    ],
    'Travel & Places': [
      '🚗', '🚕', '🚙', '🚌', '🚎', '🏎️', '🚓', '🚑', '🚒', '🚐',
      '🛻', '🚚', '🚛', '🚜', '🏍️', '🛵', '🚲', '🛴', '🛹', '🛼',
      '🚁', '🛸', '✈️', '🛩️', '🛫', '🛬', '🪂', '💺', '🚀', '🛰️',
      '🚊', '🚝', '🚄', '🚅', '🚈', '🚂', '🚆', '🚇', '🚉', '🚞',
      '🚋', '🚃', '🚟', '🚠', '🚡', '⛴️', '🛥️', '🚤', '⛵', '🛶',
      '🚢', '⚓', '⛽', '🚧', '🚨', '🚥', '🚦', '🛑', '🚏', '🗺️',
      '🗿', '🗽', '🗼', '🏰', '🏯', '🏟️', '🎡', '🎢', '🎠', '⛲',
      '⛱️', '🏖️', '🏝️', '🏜️', '🌋', '⛰️', '🏔️', '🗻', '🏕️', '⛺',
      '🏠', '🏡', '🏘️', '🏚️', '🏗️', '🏭', '🏢', '🏬', '🏣', '🏤',
      '🏥', '🏦', '🏨', '🏪', '🏫', '🏩', '💒', '🏛️', '⛪', '🕌',
      '🕍', '🛕', '🗾', '🎑', '🏞️', '🌅', '🌄', '🌠', '🎇', '🎆',
      '🌇', '🌆', '🏙️', '🌃', '🌌', '🌉', '🌁', '⭐', '🌟', '✨'
    ],
    'Objects': [
      '⌚', '📱', '📲', '💻', '⌨️', '🖥️', '🖨️', '🖱️', '🖲️', '🕹️',
      '🗜️', '💽', '💾', '💿', '📀', '📼', '📷', '📸', '📹', '🎥',
      '📽️', '🎞️', '📞', '☎️', '📟', '📠', '📺', '📻', '🎙️', '🎚️',
      '🎛️', '🧭', '⏱️', '⏲️', '⏰', '🕰️', '⌛', '⏳', '📡', '🔋',
      '🔌', '💡', '🔦', '🕯️', '🪔', '🧯', '🛢️', '💸', '💵', '💴',
      '💶', '💷', '💰', '💳', '💎', '⚖️', '🪜', '🧰', '🔧', '🔨',
      '⚒️', '🛠️', '⛏️', '🔩', '⚙️', '🧱', '⛓️', '🧲', '🔫', '💣',
      '🧨', '🪓', '🔪', '🗡️', '⚔️', '🛡️', '🚬', '⚰️', '⚱️', '🏺',
      '🔮', '📿', '🧿', '💈', '⚗️', '🔭', '🔬', '🕳️', '🩹', '🩺',
      '💊', '💉', '🧬', '🦠', '🧫', '🧪', '🌡️', '🧹', '🧺', '🧻',
      '🚽', '🚰', '🚿', '🛁', '🛀', '🧼', '🪒', '🧽', '🧴', '🛎️',
      '🔑', '🗝️', '🚪', '🪑', '🛋️', '🛏️', '🛌', '🧸', '🖼️', '🛍️',
      '🛒', '🎁', '🎀', '🎊', '🎉', '🎈', '🎄', '🎃', '🎗️', '🥇',
      '🥈', '🥉', '🏆', '🏅', '🎖️', '🏵️', '🎗️', '🎫', '🎟️', '🎪'
    ],
    'Symbols': [
      '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
      '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝', '💟', '☮️',
      '✝️', '☪️', '🕉️', '☸️', '✡️', '🔯', '🕎', '☯️', '☦️', '🛐',
      '⛎', '♈', '♉', '♊', '♋', '♌', '♍', '♎', '♏', '♐',
      '♑', '♒', '♓', '🆔', '⚛️', '🉑', '☢️', '☣️', '📴', '📳',
      '🈶', '🈚', '🈸', '🈺', '🈷️', '✴️', '🆚', '💮', '🉐', '㊙️',
      '㊗️', '🈴', '🈵', '🈹', '🈲', '🅰️', '🅱️', '🆎', '🆑', '🅾️',
      '🆘', '❌', '⭕', '🛑', '⛔', '📛', '🚫', '💯', '💢', '♨️',
      '🚷', '🚯', '🚳', '🚱', '🔞', '📵', '🚭', '❗', '❕', '❓',
      '❔', '‼️', '⁉️', '🔅', '🔆', '〽️', '⚠️', '🚸', '🔱', '⚜️',
      '🔰', '♻️', '✅', '🈯', '💹', '❇️', '✳️', '❎', '🌐', '💠',
      'Ⓜ️', '🌀', '💤', '🏧', '🚾', '♿', '🅿️', '🈳', '🈂️', '🛗',
      '🛂', '🛃', '🛄', '🛅', '🚹', '🚺', '🚼', '⚧️', '🚻', '🚮',
      '🎦', '📶', '🈁', '🔣', 'ℹ️', '🔤', '🔡', '🔠', '🆖', '🆗',
      '🆙', '🆒', '🆕', '🆓', '0️⃣', '1️⃣', '2️⃣', '3️⃣', '4️⃣', '5️⃣',
      '6️⃣', '7️⃣', '8️⃣', '9️⃣', '🔟', '🔢', '#️⃣', '*️⃣', '⏏️', '▶️',
      '⏸️', '⏯️', '⏹️', '⏺️', '⏭️', '⏮️', '⏩', '⏪', '⏫', '⏬',
      '◀️', '🔼', '🔽', '➡️', '⬅️', '⬆️', '⬇️', '↗️', '↘️', '↙️',
      '↖️', '↕️', '↔️', '↪️', '↩️', '⤴️', '⤵️', '🔀', '🔁', '🔂',
      '🔄', '🔃', '🎵', '🎶', '➕', '➖', '➗', '✖️', '♾️', '💲',
      '💱', '™️', '©️', '®️', '👁️‍🗨️', '🔚', '🔙', '🔛', '🔝', '🔜'
    ],
    'Flags': [
      '🏁', '🚩', '🎌', '🏴', '🏳️', '🏳️‍🌈', '🏳️‍⚧️', '🏴‍☠️',
      '🇦🇨', '🇦🇩', '🇦🇪', '🇦🇫', '🇦🇬', '🇦🇮', '🇦🇱', '🇦🇲',
      '🇦🇴', '🇦🇶', '🇦🇷', '🇦🇸', '🇦🇹', '🇦🇺', '🇦🇼', '🇦🇽',
      '🇦🇿', '🇧🇦', '🇧🇧', '🇧🇩', '🇧🇪', '🇧🇫', '🇧🇬', '🇧🇭',
      '🇧🇮', '🇧🇯', '🇧🇱', '🇧🇲', '🇧🇳', '🇧🇴', '🇧🇶', '🇧🇷',
      '🇧🇸', '🇧🇹', '🇧🇻', '🇧🇼', '🇧🇾', '🇧🇿', '🇨🇦', '🇨🇨',
      '🇨🇩', '🇨🇫', '🇨🇬', '🇨🇭', '🇨🇮', '🇨🇰', '🇨🇱', '🇨🇲',
      '🇨🇳', '🇨🇴', '🇨🇵', '🇨🇷', '🇨🇺', '🇨🇻', '🇨🇼', '🇨🇽',
      '🇨🇾', '🇨🇿', '🇩🇪', '🇩🇬', '🇩🇯', '🇩🇰', '🇩🇲', '🇩🇴',
      '🇩🇿', '🇪🇦', '🇪🇨', '🇪🇪', '🇪🇬', '🇪🇭', '🇪🇷', '🇪🇸',
      '🇪🇹', '🇪🇺', '🇫🇮', '🇫🇯', '🇫🇰', '🇫🇲', '🇫🇴', '🇫🇷',
      '🇬🇦', '🇬🇧', '🇬🇩', '🇬🇪', '🇬🇫', '🇬🇬', '🇬🇭', '🇬🇮',
      '🇬🇱', '🇬🇲', '🇬🇳', '🇬🇵', '🇬🇶', '🇬🇷', '🇬🇸', '🇬🇹',
      '🇬🇺', '🇬🇼', '🇬🇾', '🇭🇰', '🇭🇲', '🇭🇳', '🇭🇷', '🇭🇹',
      '🇭🇺', '🇮🇨', '🇮🇩', '🇮🇪', '🇮🇱', '🇮🇲', '🇮🇳', '🇮🇴',
      '🇮🇶', '🇮🇷', '🇮🇸', '🇮🇹', '🇯🇪', '🇯🇲', '🇯🇴', '🇯🇵',
      '🇰🇪', '🇰🇬', '🇰🇭', '🇰🇮', '🇰🇲', '🇰🇳', '🇰🇵', '🇰🇷',
      '🇰🇼', '🇰🇾', '🇰🇿', '🇱🇦', '🇱🇧', '🇱🇨', '🇱🇮', '🇱🇰',
      '🇱🇷', '🇱🇸', '🇱🇹', '🇱🇺', '🇱🇻', '🇱🇾', '🇲🇦', '🇲🇨',
      '🇲🇩', '🇲🇪', '🇲🇫', '🇲🇬', '🇲🇭', '🇲🇰', '🇲🇱', '🇲🇲'
    ]
  };

  int selectedEmojiCategoryIndex = 0;

  // Function to select an avatar based on the user name
  String _getAvatar(String name) {
    List<String> avatars = [
      CustomImage.avator,

    ];

    int index = name.hashCode % avatars.length;
    return avatars[index];
  }



  // CRITICAL: Method to check if user is still a member of the group
  Future<void> _checkGroupMembership() async {
    if (!widget.chat.isGroup) {
      setState(() {
        _isUserStillMember = true;
      });
      return;
    }

    setState(() {
      _isCheckingMembership = true;
    });

    try {
      final currentUserId = controller.currentUserId;
      if (currentUserId == null) {
        setState(() {
          _isUserStillMember = false;
          _isCheckingMembership = false;
        });
        return;
      }

      print("🔍 Checking membership for group: ${widget.chat.id}");
      print("🆔 Current user ID: $currentUserId");

      // Check if user is still in the chat participants
      final isInParticipants = widget.chat.participants.contains(currentUserId);

      print("👥 Participants: ${widget.chat.participants}");
      print("✅ Is in participants: $isInParticipants");

      setState(() {
        _isUserStillMember = isInParticipants;
        _isCheckingMembership = false;
      });

      if (!_isUserStillMember) {
        print("⚠️ User is no longer a member of this group");
        _showLeftGroupMessage();
      }

    } catch (e) {
      print("❌ Error checking membership: $e");
      setState(() {
        _isUserStillMember = true; // Default to allowing if check fails
        _isCheckingMembership = false;
      });
    }
  }

  void _showLeftGroupMessage() {
    Get.snackbar(
      'Group Access Restricted',
      'You can no longer send messages because you left this group',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
      icon: const Icon(Icons.warning, color: Colors.white),
    );
  }

  void _showMembershipRestrictedDialog() {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.block, color: Colors.red),
            SizedBox(width: 8),
            Text('Access Restricted'),
          ],
        ),
        content: Text(
          'You cannot send messages to this group because you are no longer a member.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              Get.back(); // Go back to chat list
            },
            child: Text('Back to Chats'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    textController.dispose();
    focusNode.dispose();
    _scrollController.dispose();
    // Clean up when leaving chat
    controller.leaveChatScreen();
    super.dispose();
  }

  void onEmojiSelected(String emoji) {
    // BLOCK emoji for non-members
    if (widget.chat.isGroup && !_isUserStillMember) {
      _showMembershipRestrictedDialog();
      return;
    }

    // Insert emoji at cursor position
    final text = textController.text;
    final selection = textController.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      emoji,
    );

    textController.text = newText;
    controller.messageText.value = newText;

    // Update cursor position
    textController.selection = TextSelection.collapsed(
      offset: selection.start + emoji.length,
    );
  }

  void toggleEmojiKeyboard() {
    // BLOCK emoji keyboard for non-members
    if (widget.chat.isGroup && !_isUserStillMember) {
      _showMembershipRestrictedDialog();
      return;
    }

    setState(() {
      isEmojiVisible = !isEmojiVisible;
    });

    if (isEmojiVisible) {
      focusNode.unfocus();
    } else {
      focusNode.requestFocus();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showAttachmentOptions() {
    // BLOCK attachments for non-members
    if (widget.chat.isGroup && !_isUserStillMember) {
      _showMembershipRestrictedDialog();
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Send Attachment',
              style: mediumStyle.copyWith(fontSize: 18),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.photo_camera,
                  label: 'Camera',
                  color: Colors.pink,
                  onTap: () {
                    Get.back();
                    controller.sendImageFromCamera();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  color: Colors.purple,
                  onTap: () {
                    Get.back();
                    controller.sendImage();
                  },
                ),

              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          SizedBox(width: 8),
          Text(
            label,
            style: regularStyle.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _handleSendMessage() {
    print('📤 Handle send message called');

    // Check group membership first
    if (widget.chat.isGroup && !_isUserStillMember) {
      print('❌ User not a member of group');
      _showMembershipRestrictedDialog();
      return;
    }

    // Validate message content
    final messageContent = textController.text.trim();
    if (messageContent.isEmpty) {
      print('❌ Empty message content');
      return;
    }

    print('✅ Message validation passed');
    print('📝 Message content: $messageContent');

    // Set the message in controller
    controller.messageText.value = messageContent;

    // Clear input field immediately
    textController.clear();

    // Hide emoji keyboard if visible
    if (isEmojiVisible) {
      setState(() {
        isEmojiVisible = false;
      });
    }

    // Send message with enhanced validation
    controller.sendMessageWithApiNotifications();
  }

  // CRITICAL: New method for restricted message input
  Widget _buildRestrictedMessageInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.block, color: Colors.grey[600], size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You cannot send messages because you left this group',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Get.back(),
                child: Text('Back to Chats'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build Emoji Keyboard
  Widget _buildEmojiKeyboard() {
    return Container(
      height: 250,
      color: Colors.white,
      child: Column(
        children: [
          // Emoji Categories
          Container(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: emojiCategories.length,
              itemBuilder: (context, index) {
                final isSelected = selectedEmojiCategoryIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedEmojiCategoryIndex = index;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? CustomColors.purpleColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getCategoryIcon(index),
                      style: TextStyle(
                        fontSize: 20,
                        color: isSelected ? Colors.white : Colors.grey[600],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Divider(height: 1, color: Colors.grey[300]),

          // Emoji Grid
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: emojiData[emojiCategories[selectedEmojiCategoryIndex]]?.length ?? 0,
              itemBuilder: (context, index) {
                final emoji = emojiData[emojiCategories[selectedEmojiCategoryIndex]]![index];
                return GestureDetector(
                  onTap: () => onEmojiSelected(emoji),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryIcon(int index) {
    switch (index) {
      case 0: return '😀';
      case 1: return '🐶';
      case 2: return '🍎';
      case 3: return '⚽';
      case 4: return '🚗';
      case 5: return '💡';
      case 6: return '❤️';
      case 7: return '🏁';
      default: return '😀';
    }
  }

  // Normal message input (extracted from original build method)
  Widget _buildNormalMessageInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Text field
                Padding(
                  padding: EdgeInsets.only(left: 16.0, right: 16),
                  child: Obx(() => TextField(
                    focusNode: focusNode,
                    controller: textController,
                    minLines: 1,
                    maxLines: 3,
                    enabled: !controller.isSendingMessage.value &&
                        controller.isConnected.value,
                    onChanged: (val) => controller.messageText.value = val,
                    onTap: () {

                      if (isEmojiVisible) {
                        setState(() {
                          isEmojiVisible = false;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      hintText: !controller.isConnected.value
                          ? "No connection..."
                          : controller.isSendingMessage.value
                          ? "Sending..."
                          : "Type your message...",
                      hintStyle: regularStyle.copyWith(
                          fontSize: 17,
                          color: !controller.isConnected.value
                              ? Colors.red[400]
                              : controller.isSendingMessage.value
                              ? Colors.grey[400]
                              : Color(0xffA1A1A1)),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      filled: false,
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                    ),
                  )),
                ),

                const SizedBox(height: 4),
                Divider(height: 2, color: Colors.grey.shade300),
                const SizedBox(height: 4),

                Padding(
                  padding: EdgeInsets.only(left: 16.0, right: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.add_circle_outline,
                                color: Colors.grey, size: 26),
                            onPressed: controller.isConnected.value
                                ? _showAttachmentOptions
                                : null,
                          ),

                          const SizedBox(width: 0),

                          // Emoji button
                          IconButton(
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              isEmojiVisible
                                  ? Icons.keyboard
                                  : Icons.emoji_emotions_outlined,
                              color: isEmojiVisible ? CustomColors.purpleColor : Colors.grey,
                              size: 26,
                            ),
                            onPressed: controller.isConnected.value
                                ? toggleEmojiKeyboard
                                : null,
                          ),
                        ],
                      ),

                      // CRITICAL: Send button with membership restriction
                      Obx(() => InkWell(
                        onTap: (controller.isSendingMessage.value ||
                            !controller.isConnected.value)
                            ? null
                            : () => _handleSendMessage(), // Use the enhanced method
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (controller.isSendingMessage.value ||
                                !controller.isConnected.value)
                                ? Colors.grey[400]
                                : CustomColors.purpleColor,
                          ),
                          child: controller.isSendingMessage.value
                              ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.send,
                              color: Colors.white, size: 20),
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Emoji Keyboard
        if (isEmojiVisible) _buildEmojiKeyboard(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = controller.currentUserId;
    final displayName = widget.chat.getDisplayName(controller.currentUserId);
    final displayAvatar = widget.chat.getDisplayAvatar(controller.currentUserId);
    int memberCount = widget.chat.participants.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF6EDFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: InkWell(
          onTap: () {
            if (widget.chat.isGroup) {
              Get.to(() => GroupInfoScreen(
                groupId: widget.chat.apiGroupId ?? widget.chat.id,
                groupName: widget.chat.name ?? displayName,
                memberCount: memberCount,
              ));
            }
          },
          child: Row(
            children: [
              // FIXED: Enhanced Avatar/Group Icon with proper image handling
              _buildEnhancedChatAvatar(),

              const SizedBox(width: 10),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: mediumStyle.copyWith(fontSize: 18),
                  ),
                  if (widget.chat.isGroup)
                    Text(
                      // SHOW RESTRICTION STATUS
                      !_isUserStillMember
                          ? 'You left this group'
                          : '$memberCount Members',
                      style: regularStyle.copyWith(
                        fontSize: 14,
                        color: !_isUserStillMember
                            ? Colors.red
                            : CustomColors.leaveColor,
                      ),
                    )
                  else
                    _buildOnlineStatus(),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // CRITICAL: Group membership status banner for non-members
          if (widget.chat.isGroup && !_isUserStillMember)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              color: Colors.red[100],
              child: Row(
                children: [
                  Icon(Icons.block, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You are no longer a member of this group. You cannot send messages.',
                      style: TextStyle(
                        color: Colors.red[800],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text(
                      'Back',
                      style: TextStyle(color: Colors.red[800]),
                    ),
                  ),
                ],
              ),
            ),

          // Connection status
          Obx(() => !controller.isConnected.value
              ? Container(
            width: double.infinity,
            padding: EdgeInsets.all(8),
            color: Colors.orange[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, size: 16, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Connection lost - messages may not send',
                  style: TextStyle(color: Colors.orange[800], fontSize: 12),
                ),
              ],
            ),
          )
              : SizedBox.shrink()),

          // Chat messages
          Expanded(
            child: Obx(() {
              if (controller.isLoadingMessages.value) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: CustomColors.purpleColor),
                      SizedBox(height: 16),
                      Text('Loading messages...'),
                    ],
                  ),
                );
              }

              final messages = controller.currentMessages.toList();

              // Auto-scroll to bottom when new messages arrive
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

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
                        // SHOW APPROPRIATE MESSAGE BASED ON MEMBERSHIP
                        widget.chat.isGroup && !_isUserStillMember
                            ? 'No messages visible'
                            : 'No messages yet',
                        style: mediumStyle.copyWith(
                          fontSize: Dimensions.fontSizeLarge,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.chat.isGroup && !_isUserStillMember
                            ? 'You left this group'
                            : 'Start the conversation!',
                        style: regularStyle.copyWith(
                          fontSize: Dimensions.fontSizeDefault,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isMe = message.senderId == controller.currentUserId;

                  // SYSTEM MESSAGE CHECK
                  if (message.type == MessageType.system || message.senderId == 'system') {
                    return _buildSystemMessage(message.text, message.timestamp);
                  }

                  // Get sender info from participant details
                  String senderName = message.senderName;
                  String? senderAvatar;

                  if (widget.chat.participantDetails.containsKey(message.senderId)) {
                    final participantInfo = widget.chat.participantDetails[message.senderId]!;
                    senderName = participantInfo.name;
                    senderAvatar = participantInfo.avatar;
                  }

                  return _buildMessageBubble(
                    message: message,
                    isMe: isMe,
                    senderName: senderName,
                    senderAvatar: senderAvatar,
                    isGroup: widget.chat.isGroup,
                  );
                },
              );
            }),
          ),

          // CRITICAL: Show restricted or normal message input
          if (widget.chat.isGroup && !_isUserStillMember)
            _buildRestrictedMessageInput()
          else
            _buildNormalMessageInput(),
        ],
      ),
    );
  }



  Widget _buildOnlineStatus() {
    try {
      final otherParticipantId = controller.getOtherParticipantId(widget.chat);

      if (otherParticipantId == null) {
        return SizedBox.shrink();
      }

      // Use the updated online check method
      final isOnline = controller.isUserActuallyOnline(otherParticipantId);

      if (isOnline) {
        return Text(
          'Online',
          style: regularStyle.copyWith(
            fontSize: 14,
            color: Colors.green,
          ),
        );
      } else {
        // Show last seen instead of nothing
        return Text(
          'Offline',
          style: regularStyle.copyWith(
            fontSize: 14,
            color: CustomColors.greyColor,
          ),
        );
      }

    } catch (e) {
      print('❌ Error in online status: $e');
      return SizedBox.shrink();
    }
  }

  Widget _buildEnhancedChatAvatar() {
    print('🎨 Building enhanced chat avatar for: ${widget.chat.id}');
    print('   Is Group: ${widget.chat.isGroup}');
    print('   Chat Name: ${widget.chat.name}');

    if (widget.chat.isGroup) {
      // For group chats, get the group image using ChatController's method
      final groupImage = controller.getGroupDisplayImage(widget.chat);
      print('   Group Image: ${groupImage != null ? "Found (${groupImage.length} chars)" : "None"}');

      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: CustomColors.lightPurpleColor,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: _buildGroupImageWidget(groupImage),
        ),
      );
    } else {
      // For personal chats, use the existing logic
      final displayAvatar = widget.chat.getDisplayAvatar(controller.currentUserId);
      final displayName = widget.chat.getDisplayName(controller.currentUserId);

      return CircleAvatar(
        radius: 20,
        child: ClipOval(
          child: displayAvatar != null
              ? (displayAvatar.startsWith('http')
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
          )
              : Image.asset(
            displayAvatar,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
          ))
              : Image.asset(
            _getAvatar(displayName),
            width: 48,
            height: 48,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
  }

  Widget _buildGroupImageWidget(String? groupImage) {
    print('🖼️ Building group image widget');
    print('   Image: ${groupImage != null ? "${groupImage.length} chars" : "null"}');

    if (groupImage != null && groupImage.isNotEmpty) {
      // Base64 image (most common after updates)
      if (groupImage.startsWith('data:image')) {
        print('📸 Rendering base64 group image');
        return _buildBase64GroupImage(groupImage);
      }
      // Network URL
      else if (groupImage.startsWith('http')) {
        print('🌐 Rendering network group image');
        return _buildNetworkGroupImage(groupImage);
      }
      // Local file
      else if (groupImage.startsWith('local:')) {
        print('📁 Rendering local group image');
        final localPath = groupImage.substring(6); // Remove 'local:' prefix
        return _buildLocalGroupImage(localPath);
      }
      // Asset path
      else if (groupImage.startsWith('assets/')) {
        print('📁 Rendering asset group image');
        return _buildAssetGroupImage(groupImage);
      }
    }

    // Default group icon
    print('📁 Using default group icon');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          CustomImage.userGroup,
          width: 24,
          height: 24,
        ),
      ),
    );
  }

  Widget _buildBase64GroupImage(String base64Data) {
    try {
      // Extract base64 data (format: data:image/jpeg;base64,/9j/4AAQ...)
      final parts = base64Data.split(',');
      if (parts.length != 2) {
        print('❌ Invalid base64 format');
        return _buildDefaultGroupIcon();
      }

      final base64String = parts[1];
      final Uint8List imageBytes = base64Decode(base64String);

      print('✅ Base64 decoded successfully. Bytes: ${imageBytes.length}');

      return Image.memory(
        imageBytes,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Error displaying base64 group image: $error');
          return _buildDefaultGroupIcon();
        },
      );
    } catch (e) {
      print('❌ Error processing base64 group image: $e');
      return _buildDefaultGroupIcon();
    }
  }

  Widget _buildNetworkGroupImage(String imageUrl) {
    return Image.network(
      imageUrl,
      width: 40,
      height: 40,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: 40,
          height: 40,
          color: Colors.grey[200],
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: CustomColors.purpleColor,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('❌ Error loading network group image: $imageUrl - $error');
        return _buildDefaultGroupIcon();
      },
    );
  }

  Widget _buildLocalGroupImage(String localPath) {
    return Image.file(
      File(localPath),
      width: 40,
      height: 40,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        print('❌ Error loading local group image: $localPath - $error');
        return _buildDefaultGroupIcon();
      },
    );
  }

  Widget _buildAssetGroupImage(String assetPath) {
    return Image.asset(
      assetPath,
      width: 40,
      height: 40,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        print('❌ Error loading asset group image: $assetPath - $error');
        return _buildDefaultGroupIcon();
      },
    );
  }

  Widget _buildDefaultGroupIcon() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          CustomImage.userGroup,
          width: 24,
          height: 24,
        ),
      ),
    );
  }


  Widget _buildMessageBubble({
    required ChatMessage message,
    required bool isMe,
    required String senderName,
    String? senderAvatar,
    required bool isGroup,
  }) {
    // ENHANCED DEBUG LOGGING
    print('🎯 Building message bubble for: ${message.id}');
    print('🎯 Message type: ${message.type}');
    print('🎯 Message text: "${message.text}"');
    print('🎯 Message imageUrl: ${message.imageUrl}');
    print('🎯 Message hasMedia: ${message.hasMedia}');
    print('🎯 Is image message: ${message.isImageMessage}');
    print('🎯 Display text: "${message.displayText}"');

    // SYSTEM MESSAGE CHECK - updated to use isSystemMessage
    if (message.isSystemMessage || message.senderId == 'system') {
      return _buildSystemMessage(message.text, message.timestamp);
    }

    if (isGroup && !isMe) {
      // Group chat - other person's message with avatar and name
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 16,
              child: ClipOval(
                child: senderAvatar != null
                    ? (senderAvatar.startsWith('http')
                    ? Image.network(
                  senderAvatar,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.asset(
                      _getAvatar(senderName),
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                    );
                  },
                )
                    : Image.asset(
                  senderAvatar,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ))
                    : Image.asset(
                  _getAvatar(senderName),
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Message content
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender name
                  Text(
                    senderName.isEmpty ? 'Unknown' : senderName,
                    style: mediumStyle.copyWith(
                      fontSize: Dimensions.fontSizeLarge,
                      color: CustomColors.purpleColor,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Message bubble
                  _buildMessageContent(message, false),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Direct chat or my message in group
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: _buildMessageContent(message, isMe),
            ),
          ],
        ),
      );
    }
  }

  // SYSTEM MESSAGE WIDGET
  Widget _buildSystemMessage(String message, DateTime timestamp) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                _formatTime(timestamp),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // UPDATED: Get image URL using ChatMessage methods
  String _getImageUrlFromMessage(ChatMessage message) {
    try {
      print('🔍 Getting image URL for message: ${message.id}');
      print('🔍 Message type: ${message.type}');
      print('🔍 Message isImageMessage: ${message.isImageMessage}');

      // Use ChatMessage's built-in method first
      final url = message.getImageUrl();
      if (url != null && url.isNotEmpty) {
        print('✅ Found image URL via getImageUrl(): ${url.length > 50 ? "${url.substring(0, 50)}..." : url}');
        return url;
      }

      // Check imageUrl property directly
      if (message.imageUrl != null && message.imageUrl!.isNotEmpty) {
        print('✅ Found imageUrl property: ${message.imageUrl!.length > 50 ? "${message.imageUrl!.substring(0, 50)}..." : message.imageUrl}');
        return message.imageUrl!;
      }

      // Check if text contains a data URI (base64)
      if (message.text.startsWith('data:image')) {
        print('✅ Found base64 data URI in text');
        return message.text;
      }

      // Check if text is a regular URL
      if (message.text.startsWith('http')) {
        print('✅ Found HTTP URL in text');
        return message.text;
      }

      // Check for Firebase Storage URLs in text
      if (message.text.contains('firebasestorage.googleapis.com')) {
        print('✅ Found Firebase Storage URL in text');
        return message.text;
      }

      print('❌ No image URL found');
      return '';
    } catch (e) {
      print('❌ Error getting image URL: $e');
      return '';
    }
  }
// REPLACE your existing _buildMessageContent method in PersonalChatScreen with this:

  Widget _buildMessageContent(ChatMessage message, bool isMe) {
    print('🎯 Building message content - Message: ${message.toString()}');

    // Use the built-in isImageMessage property
    final isImageMsg = message.isImageMessage;
    print('🖼️ Is image message: $isImageMsg');

    return IntrinsicWidth(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
          minWidth: 60,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? CustomColors.blue : Color(0xffE8E8E8),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle different message types
            if (isImageMsg) ...[
              _buildImageWidget(message, isMe),
            ] else if (message.isVideoMessage) ...[
              _buildVideoWidget(message, isMe),
            ] else if (message.isAudioMessage) ...[
              _buildAudioWidget(message, isMe),
            ] else if (message.isFileMessage) ...[
              _buildFileWidget(message, isMe),
            ] else ...[
              // Regular text message
              Container(
                child: Text(
                  message.text.isEmpty ? 'Empty message' : message.text,
                  style: semiLightStyle.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                    color: isMe ? Colors.white : Color(0xff141414),
                  ),
                  softWrap: true,
                ),
              ),
            ],

            const SizedBox(height: 4),

            // UPDATED: Time and message status row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: semiLightStyle.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: isMe ? Colors.white70 : Color(0xff727272),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _buildMessageStatusIcon(message),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageStatusIcon(ChatMessage message) {
    try {
      final currentUserId = controller.currentUserId ?? '';
      final chatParticipants = widget.chat.participants;

      // Only show status for messages sent by current user
      if (message.senderId != currentUserId) {
        return SizedBox.shrink();
      }

      final otherParticipants = chatParticipants.where((id) => id != currentUserId).toList();

      // Debug logging to troubleshoot read status
      print('🔵 Message Status Debug for message: ${message.id}');
      print('🔵 Chat participants: $chatParticipants');
      print('🔵 Other participants: $otherParticipants');
      print('🔵 Message readBy: ${message.readBy}');
      print('🔵 Current user: $currentUserId');

      // Check if all recipients have read the message
      final allRead = otherParticipants.every((id) => message.readBy.contains(id));
      print('🔵 All participants read: $allRead');

      if (allRead && otherParticipants.isNotEmpty) {
        print('✅ Showing BLUE double ticks - all members read');
        return Icon(
          Icons.done_all,  // FIXED: was Icons.done*all
          size: 16,
          color: Colors.blue,
        );
      }

      // Check delivery status - if any recipient is online
      final anyOnline = otherParticipants.any((id) => controller.isUserActuallyOnline(id));
      print('🔵 Any participant online: $anyOnline');

      if (anyOnline) {
        print('📤 Showing GREY double ticks - delivered');
        return Icon(
          Icons.done_all,
          size: 16,
          color: Colors.grey[400],
        );
      }

      // Default - single grey tick (sent but not delivered)
      print('📤 Showing GREY single tick - sent');
      return Icon(
        Icons.done,
        size: 16,
        color: Colors.grey[600],
      );

    } catch (e) {
      print('❌ Error building message status icon: $e');
      return Icon(
        Icons.done,
        size: 16,
        color: Colors.grey[600],
      );
    }
  }


// ALSO UPDATE your markMessagesAsRead method in PersonalChatScreen initState:
  @override
  void initState() {
    super.initState();
    controller = Get.find<ChatController>();
    focusNode = FocusNode();
    _scrollController = ScrollController();

    // Load messages for this chat
    controller.loadMessages(widget.chat.id);

    // UPDATED: Mark messages as read when entering chat with better timing
    if (controller.currentUserId != null) {
      Future.delayed(Duration(milliseconds: 1500), () {
        controller.markMessagesAsRead(widget.chat.id, controller.currentUserId!);
      });
    }

    // Check group membership for group chats
    if (widget.chat.isGroup) {
      _checkGroupMembership();
    }

    // Scroll to bottom after messages load
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }




  // Helper method to determine image URL type
  String _getImageUrlType(String imageUrl) {
    if (imageUrl.startsWith('data:image')) return 'base64';
    if (imageUrl.startsWith('local:')) return 'local';
    if (imageUrl.startsWith('http')) return 'network';
    return 'unknown';
  }

  // FIXED: Updated _buildImageWidget method with proper base64 support
  Widget _buildImageWidget(ChatMessage message, bool isMe) {
    final imageUrl = _getImageUrlFromMessage(message);

    print('🖼️ Building image widget for message ${message.id}');
    print('🖼️ Image URL type: ${_getImageUrlType(imageUrl)}');
    print('🖼️ Image URL length: ${imageUrl.length}');

    if (imageUrl.isNotEmpty) {
      return GestureDetector(
        onTap: () {
          _showFullScreenImage(imageUrl);
        },
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 250,
            maxHeight: 250,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildImageFromUrl(imageUrl),
          ),
        ),
      );
    } else {
      print('❌ No image URL, showing placeholder');
      return _buildImagePlaceholder(message);
    }
  }

  // FIXED: Updated helper method to build image from different URL types
  Widget _buildImageFromUrl(String imageUrl) {
    // Check if it's a base64 data URI
    if (imageUrl.startsWith('data:image')) {
      print('📷 Loading base64 image');
      try {
        // Extract base64 data (format: data:image/jpeg;base64,/9j/4AAQ...)
        final parts = imageUrl.split(',');
        if (parts.length != 2) {
          throw Exception('Invalid base64 format');
        }

        final base64Data = parts[1];
        final Uint8List imageBytes = base64Decode(base64Data);

        print('✅ Base64 decoded successfully. Bytes: ${imageBytes.length}');

        return Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('❌ Error loading base64 image: $error');
            return _buildImageErrorWidget();
          },
        );
      } catch (e) {
        print('❌ Error decoding base64 image: $e');
        return _buildImageErrorWidget();
      }
    }

    // Check if it's a local file path
    else if (imageUrl.startsWith('local:')) {
      print('📁 Loading local image');
      final localPath = imageUrl.substring(6); // Remove 'local:' prefix
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Error loading local image: $error');
          return _buildImageErrorWidget();
        },
      );
    }

    // Regular network image
    else if (imageUrl.startsWith('http')) {
      print('🌐 Loading network image');
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            print('✅ Network image loaded successfully');
            return child;
          }

          double? progress;
          if (loadingProgress.expectedTotalBytes != null) {
            progress = loadingProgress.cumulativeBytesLoaded /
                loadingProgress.expectedTotalBytes!;
          }

          return Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    color: CustomColors.purpleColor,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Loading image...',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (progress != null)
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                ],
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('❌ Error loading network image: $error');
          return _buildImageErrorWidget();
        },
      );
    }

    // Fallback for unknown image types
    else {
      print('❓ Unknown image type: $imageUrl');
      return _buildImageErrorWidget();
    }
  }

  void _showFullScreenImage(String imageUrl) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              // Full screen image with zoom
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5.0,
                  child: buildFullScreenImage(imageUrl),
                ),
              ),

              // Top close button
              Positioned(
                top: 30,
                right: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Get.back(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

// 2. HELPER FUNCTION - Build image widget with support for all formats
  Widget buildFullScreenImage(String imageUrl) {
    // Base64 image
    if (imageUrl.startsWith('data:image')) {
      try {
        final parts = imageUrl.split(',');
        if (parts.length != 2) {
          throw Exception('Invalid base64 format');
        }

        final base64Data = parts[1];
        final imageBytes = base64Decode(base64Data);

        return Image.memory(
          imageBytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorWidget('Failed to load base64 image');
          },
        );
      } catch (e) {
        return _buildErrorWidget('Failed to decode base64 image');
      }
    }

    // Local file
    else if (imageUrl.startsWith('local:')) {
      final localPath = imageUrl.substring(6);
      return Image.file(
        File(localPath),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget('Failed to load local image');
        },
      );
    }

    // Network image
    else if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: Colors.white,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
                SizedBox(height: 16),
                Text(
                  'Loading image...',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget('Failed to load network image');
        },
      );
    }

    // Asset image
    else if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget('Failed to load asset image');
        },
      );
    }

    // Regular file path
    else {
      return Image.file(
        File(imageUrl),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget('Failed to load image file');
        },
      );
    }
  }

// Private helper for error display
  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, color: Colors.white54, size: 60),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Tap anywhere to close',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Updated error widget
  Widget _buildImageErrorWidget() {
    return GestureDetector(
      onTap: () {
        setState(() {}); // Retry loading
      },
      child: Container(
        width: 200,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[300]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[600], size: 40),
            SizedBox(height: 8),
            Text(
              'Failed to load image',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Tap to retry',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build image placeholder when URL is not available
  Widget _buildImagePlaceholder(ChatMessage message) {
    return Container(
      width: 200,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image, color: Colors.grey[600], size: 40),
          SizedBox(height: 8),
          Text(
            'Image',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (message.text.isNotEmpty && message.text != '📷 Image') ...[
            SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Placeholder widgets for other media types
  Widget _buildVideoWidget(ChatMessage message, bool isMe) {
    return Container(
      width: 200,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.play_circle_outline, size: 50, color: Colors.grey[600]),
          SizedBox(height: 8),
          Text('Video', style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildAudioWidget(ChatMessage message, bool isMe) {
    return Container(
      width: 200,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.audiotrack, color: Colors.grey[600]),
          SizedBox(width: 8),
          Text('Audio', style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildFileWidget(ChatMessage message, bool isMe) {
    return Container(
      width: 200,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insert_drive_file, color: Colors.grey[600]),
          SizedBox(height: 4),
          Text(
            message.fileName ?? 'File',
            style: TextStyle(color: Colors.grey[700]),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    try {
      // Debug: Print the original timestamp for troubleshooting
      print('🕐 Formatting time: $dateTime');
      print('🕐 DateTime type: ${dateTime.runtimeType}');
      print('🕐 Is UTC: ${dateTime.isUtc}');

      // Always convert to local time for consistent comparison
      final localTime = dateTime.isUtc ? dateTime.toLocal() : dateTime;
      final now = DateTime.now();

      print('🕐 Local time: $localTime');
      print('🕐 Current time: $now');

      // Calculate the difference in hours instead of days for more accurate comparison
      final difference = now.difference(localTime);
      final hoursDifference = difference.inHours;

      print('🕐 Hours difference: $hoursDifference');

      // Show time format for messages within the last 24 hours
      if (hoursDifference.abs() < 24) {
        // Convert to 12-hour format with AM/PM
        int hour = localTime.hour;
        String period = hour >= 12 ? 'pm' : 'am';

        // Convert hour to 12-hour format
        if (hour == 0) {
          hour = 12; // Midnight becomes 12 AM
        } else if (hour > 12) {
          hour = hour - 12; // Convert PM hours
        }

        String minute = localTime.minute.toString().padLeft(2, '0');
        String timeString = '$hour:$minute $period';

        print('🕐 Time string: $timeString');

        // Add "Yesterday" prefix for messages from previous day but within 24 hours
        if (hoursDifference > 0 && hoursDifference < 24) {
          final isYesterday = now.day != localTime.day;
          if (isYesterday) {
            return 'Yesterday $timeString';
          }
        }

        return timeString;
      } else {
        // For messages older than 24 hours, show the date
        final dateString = '${localTime.day}/${localTime.month}/${localTime.year}';
        print('🕐 Date string: $dateString');
        return dateString;
      }
    } catch (e) {
      print('❌ Error formatting time: $e');
      // Fallback to simple 12-hour format
      final hour = dateTime.hour == 0 ? 12 : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
      final period = dateTime.hour >= 12 ? 'pm' : 'am';
      return '$hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
    }
  }


}

class ClipRounded extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const ClipRounded({
    Key? key,
    required this.child,
    required this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: child,
    );
  }
}