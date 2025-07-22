// lib/views/chat_screen/firebase/user_list_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/images.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/chat_screen/chat_controller.dart';
import 'package:lupus_care/views/chat_screen/firebase/firebase_model.dart';
import 'package:lupus_care/views/chat_screen/personal_chat_screen.dart';

class UserListScreen extends StatefulWidget {
  final bool isForGroupCreation;

  const UserListScreen({
    super.key,
    required this.isForGroupCreation,
  });

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final ChatController _chatController;
  final List<AppUser> _selectedUsers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    // Get ChatController
    try {
      _chatController = Get.find<ChatController>();
    } catch (e) {
      print('❌ ChatController not found, creating new instance');
      _chatController = ChatController();
      Get.put<ChatController>(_chatController, permanent: true);
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchController.text.isNotEmpty) {
      _chatController.searchUsers(_searchController.text);
    } else {
      _chatController.filteredUsers.clear();
    }
  }

  String _getAvatar(String name) {
    List<String> avatars = [
      CustomImage.avator,
      CustomImage.avator1,
    ];
    int index = name.hashCode % avatars.length;
    return avatars[index];
  }

  String _getOnlineStatusText(AppUser user) {
    return user.isOnline ? 'Online' : 'Last seen recently';
  }

  Future<void> _createDirectChat(AppUser user) async {
    if (_isLoading) return;

    try {
      setState(() => _isLoading = true);

      Get.dialog(
        const Center(
          child: CircularProgressIndicator(color: CustomColors.purpleColor),
        ),
        barrierDismissible: false,
      );

      print('🔧 Creating direct chat with user: ${user.name}');

      final chatId = await _chatController.createPersonalChat(user.id, user.name);

      // Close loading dialog
      if (Get.isDialogOpen == true) {
        Get.back();
      }

      if (chatId != null && chatId.isNotEmpty) {
        print('✅ Chat created successfully: $chatId');

        // Create a temporary chat object for navigation
        final tempChat = Chat(
          id: chatId,
          participants: [_chatController.currentUserId ?? 'current_user', user.id],
          isGroup: false,
          unreadCounts: {
            _chatController.currentUserId ?? 'current_user': 0,
            user.id: 0,
          },
          participantDetails: {
            user.id: ParticipantInfo(
              id: user.id,
              name: user.name,
              avatar: user.avatar,
              isOnline: user.isOnline,
            ),
          },
          lastMessage: '',
          lastMessageTimestamp: DateTime.now(),
          lastMessageSender: '',
        );

        // Navigate to chat screen
        Get.off(() => PersonalChatScreen(chat: tempChat));
      } else {
        throw Exception('Failed to create chat - invalid chat ID');
      }
    } catch (e) {
      print('❌ Error creating direct chat: $e');

      // Close loading dialog if still open
      if (Get.isDialogOpen == true) {
        Get.back();
      }

      Get.snackbar(
        'Error',
        'Failed to create chat. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleUserSelection(AppUser user) {
    setState(() {
      if (_selectedUsers.contains(user)) {
        _selectedUsers.remove(user);
        user.isSelected = false;
      } else {
        _selectedUsers.add(user);
        user.isSelected = true;
      }
    });

    // Update controller selection
    _chatController.toggleUserSelection(user);
  }

  void _confirmSelection() {
    if (_selectedUsers.isEmpty) {
      Get.snackbar(
        'Error',
        'Please select at least one member',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    Get.back(result: _selectedUsers);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(
          widget.isForGroupCreation ? 'Select Members' : 'Find People',
          style: mediumStyle.copyWith(
            fontSize: Dimensions.fontSizeOverLarge,
          ),
        ),
        actions: widget.isForGroupCreation
            ? [
          if (_selectedUsers.isNotEmpty)
            TextButton(
              onPressed: _isLoading ? null : _confirmSelection,
              child: Text(
                'Done (${_selectedUsers.length})',
                style: mediumStyle.copyWith(
                  color: _isLoading
                      ? Colors.grey
                      : CustomColors.purpleColor,
                  fontSize: Dimensions.fontSizeLarge,
                ),
              ),
            ),
        ]
            : null,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: _searchController,
              enabled: !_isLoading,
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                hintStyle: regularStyle.copyWith(
                  color: Colors.grey[500],
                  fontSize: Dimensions.fontSizeLarge,
                ),
                border: InputBorder.none,
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey[500],
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[500]),
                  onPressed: _isLoading ? null : () {
                    _searchController.clear();
                    _chatController.filteredUsers.clear();
                  },
                )
                    : null,
              ),
            ),
          ),

          // Selected Users (for group creation)
          if (widget.isForGroupCreation && _selectedUsers.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CustomColors.purpleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: CustomColors.purpleColor.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_selectedUsers.length} members selected:',
                    style: mediumStyle.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: CustomColors.purpleColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _selectedUsers
                        .map((user) => Chip(
                      label: Text(
                        user.name,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.white,
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: _isLoading ? null : () => _toggleUserSelection(user),
                    ))
                        .toList(),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // User List
          Expanded(
            child: Obx(() {
              if (_chatController.isSearchingUsers.value) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: CustomColors.purpleColor),
                      SizedBox(height: 16),
                      Text('Searching users...'),
                    ],
                  ),
                );
              }

              if (_searchController.text.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Search for people to chat with',
                        style: mediumStyle.copyWith(
                          fontSize: Dimensions.fontSizeLarge,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter a name or email address to find users',
                        style: regularStyle.copyWith(
                          fontSize: Dimensions.fontSizeDefault,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final users = _chatController.filteredUsers;

              if (users.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: mediumStyle.copyWith(
                          fontSize: Dimensions.fontSizeLarge,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try searching with a different name or email',
                        style: regularStyle.copyWith(
                          fontSize: Dimensions.fontSizeDefault,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (_searchController.text.length < 3)
                        Container(
                          padding: EdgeInsets.all(12),
                          margin: EdgeInsets.symmetric(horizontal: 32),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue[700], size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Try typing at least 3 characters for better results',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final isSelected = _selectedUsers.contains(user);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? CustomColors.purpleColor.withOpacity(0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? CustomColors.purpleColor
                            : Colors.grey.shade200,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            child: ClipOval(
                              child: user.avatar.isNotEmpty &&
                                  user.avatar.startsWith('http')
                                  ? Image.network(
                                user.avatar,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.asset(
                                    _getAvatar(user.name),
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  );
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    width: 48,
                                    height: 48,
                                    color: Colors.grey[200],
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
                                _getAvatar(user.name),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          if (user.isOnline)
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
                        ],
                      ),
                      title: Text(
                        user.name,
                        style: mediumStyle.copyWith(
                          fontSize: Dimensions.fontSizeLarge,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (user.email.isNotEmpty)
                            Text(
                              user.email,
                              style: regularStyle.copyWith(
                                fontSize: Dimensions.fontSizeDefault,
                                color: Colors.grey[600],
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            _getOnlineStatusText(user),
                            style: regularStyle.copyWith(
                              fontSize: Dimensions.fontSizeSmall,
                              color: user.isOnline ? Colors.green : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      trailing: widget.isForGroupCreation
                          ? Checkbox(
                        value: isSelected,
                        onChanged: _isLoading ? null : (value) => _toggleUserSelection(user),
                        activeColor: CustomColors.purpleColor,
                      )
                          : _isLoading
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: CustomColors.purpleColor,
                        ),
                      )
                          : Icon(
                        Icons.chat_bubble_outline,
                        color: CustomColors.purpleColor,
                      ),
                      onTap: _isLoading
                          ? null
                          : widget.isForGroupCreation
                          ? () => _toggleUserSelection(user)
                          : () => _createDirectChat(user),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}