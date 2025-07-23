// ignore_for_file: prefer_final_fields, unused_field, avoid_print, prefer_const_constructors, unused_element, prefer_const_literals_to_create_immutables, prefer_const_declarations

import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'dart:convert'; // ADD THIS LINE
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/icons.dart';
import 'package:lupus_care/constant/images.dart';
import 'package:lupus_care/helper/storage_service.dart';
import 'package:lupus_care/data/api/auth_service.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/chat_screen/chat_controller.dart';
import 'package:lupus_care/views/chat_screen/chat_tab_bar.dart';
import 'package:lupus_care/views/chat_screen/find_friend_screen.dart';
import 'package:lupus_care/views/chat_screen/find_group_screen.dart';
import 'package:lupus_care/views/chat_screen/firebase/firebase_model.dart';
import 'package:lupus_care/views/chat_screen/personal_chat_screen.dart';
import 'package:lupus_care/views/chat_screen/search_bar_widget.dart';
import 'package:lupus_care/views/group_chat/group_info_screen.dart';

class CommunityChatScreen extends StatefulWidget {
  const CommunityChatScreen({super.key});

  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  // Keep the widget alive to maintain state
  @override
  bool get wantKeepAlive => true;
  List<Map<String, dynamic>> availableGroups = [];
  bool _isLoadingGroups = false;

  ChatController? controller;
  bool _isInitializing = true;
  bool _hasError = false;
  String _errorMessage = '';

  // API Users data
  List<Map<String, dynamic>> communityUsers = [];
  bool _isLoadingUsers = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChatController();

    // Load users from API
    _loadCommunityUsers();
    _loadCommunityData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _onlineStatusTimer?.cancel(); // Cancel the timer

    // Disable silent mode when leaving
    if (controller != null) {
      controller!.setSilentMode(false);
    }
    super.dispose();
  }

  Future<void> _loadCommunityData() async {
    await Future.wait([
      _loadCommunityUsers(),
      _loadAvailableGroups(),
    ]);
  }

// Replace your existing _loadAvailableGroups method with this enhanced debug version

  Future<void> _loadAvailableGroups() async {
    try {
      print("🚀 Starting _loadAvailableGroups...");

      setState(() {
        _isLoadingGroups = true;
      });

      final userData = StorageService.to.getUser();
      print("👤 User data: ${userData?.keys}");

      if (userData == null) {
        print('❌ No user data available for loading groups');
        setState(() {
          _isLoadingGroups = false;
          availableGroups = [];
        });
        return;
      }

      final userId = userData['id']?.toString() ?? '';
      print("🆔 User ID: '$userId'");

      if (userId.isEmpty) {
        print('❌ No user ID available for loading groups');
        setState(() {
          _isLoadingGroups = false;
          availableGroups = [];
        });
        return;
      }

      print('🔍 Loading available groups for user: $userId');

      // Call the API
      final response = await _authService.getAllGroups(userId: userId);

      print("📡 API Response received:");
      print("   Status: ${response['status']}");
      print("   Message: ${response['message']}");
      print("   Data type: ${response['data']?.runtimeType}");
      print("   Data content: ${response['data']}");

      if (response['status'] == 'success') {
        // Check if data exists and is a list
        if (response['data'] != null) {
          print("✅ Response has data field");

          var groupsData = response['data'];

          // Handle different possible data formats
          List<dynamic> groups = [];

          if (groupsData is List) {
            groups = groupsData;
            print("📋 Data is already a List with ${groups.length} items");
          } else if (groupsData is Map) {
            print("📋 Data is a Map, checking for nested list...");

            // Check common nested keys where groups might be stored
            if (groupsData['groups'] != null && groupsData['groups'] is List) {
              groups = groupsData['groups'];
              print("📋 Found groups in 'groups' key: ${groups.length} items");
            } else if (groupsData['data'] != null &&
                groupsData['data'] is List) {
              groups = groupsData['data'];
              print(
                  "📋 Found groups in nested 'data' key: ${groups.length} items");
            } else if (groupsData['results'] != null &&
                groupsData['results'] is List) {
              groups = groupsData['results'];
              print("📋 Found groups in 'results' key: ${groups.length} items");
            } else {
              print(
                  "📋 Map doesn't contain expected list keys. Keys: ${groupsData.keys}");
              // If it's a single group object, wrap it in a list
              groups = [groupsData];
            }
          } else {
            print("⚠️ Unexpected data format: ${groupsData.runtimeType}");
            groups = [];
          }

          print("📊 Processing ${groups.length} groups...");

          // Process each group
          List<Map<String, dynamic>> processedGroups = [];

          for (int i = 0; i < groups.length; i++) {
            final group = groups[i];
            print("🔧 Processing group $i: $group");

            try {
              final processedGroup = {
                'id': group['id']?.toString() ??
                    group['group_id']?.toString() ??
                    group['ID']?.toString() ??
                    i.toString(),
                'name': group['group_name']?.toString() ??
                    group['name']?.toString() ??
                    group['title']?.toString() ??
                    'Unknown Group',
                'description': group['description']?.toString() ??
                    group['desc']?.toString() ??
                    '',
                'image': group['group_image']?.toString() ??
                    group['image']?.toString() ??
                    group['img']?.toString() ??
                    '',
                'memberCount': group['member_count']?.toString() ??
                    group['members']?.toString() ??
                    group['total_members']?.toString() ??
                    '0',
                'createdBy': group['created_by']?.toString() ??
                    group['creator']?.toString() ??
                    group['owner']?.toString() ??
                    '',
                'createdAt': group['created_at']?.toString() ??
                    group['date_created']?.toString() ??
                    '',
                'isJoined': group['is_joined'] == true ||
                    group['is_member'] == true ||
                    group['joined'] == true ||
                    group['member'] == true,
                'isPublic': group['is_public'] == true ||
                    group['type'] == 'public' ||
                    group['visibility'] == 'public',
              };

              processedGroups.add(processedGroup);
              print(
                  "✅ Processed group: ${processedGroup['name']} (ID: ${processedGroup['id']})");
            } catch (e) {
              print("❌ Error processing group $i: $e");
              print("❌ Group data: $group");
            }
          }

          setState(() {
            availableGroups = processedGroups;
            _isLoadingGroups = false;
          });

          print(
              '✅ Successfully loaded ${availableGroups.length} available groups');

          // Debug: Print final processed groups
          for (var group in availableGroups) {
            print(
                "📋 Final group: ${group['name']} - ${group['memberCount']} members - Joined: ${group['isJoined']}");
          }
        } else {
          print('⚠️ API returned success but no data field');
          setState(() {
            availableGroups = [];
            _isLoadingGroups = false;
          });
        }
      } else {
        print('❌ API returned error status: ${response['status']}');
        print('❌ Error message: ${response['message']}');
        setState(() {
          availableGroups = [];
          _isLoadingGroups = false;
        });
      }
    } catch (e) {
      print('❌ Exception in _loadAvailableGroups: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      setState(() {
        availableGroups = [];
        _isLoadingGroups = false;
      });
    }
  }

  Future<void> _loadCommunityUsers() async {
    try {
      setState(() {
        _isLoadingUsers = true;
      });

      final userData = StorageService.to.getUser();
      if (userData == null) {
        print('❌ No user data available');
        setState(() {
          _isLoadingUsers = false;
        });
        return;
      }

      final userId = userData['id']?.toString() ?? '';
      if (userId.isEmpty) {
        print('❌ No user ID available');
        setState(() {
          _isLoadingUsers = false;
        });
        return;
      }

      print('🔍 Loading community users for user: $userId');

      final response = await _authService.getAllUsers(userId: userId);

      if (response['status'] == 'success' && response['data'] != null) {
        final users = response['data'] as List<dynamic>;

        setState(() {
          communityUsers = users
              .map((user) {
                // ENHANCED: Better avatar URL handling
                String avatarUrl = '';

                // Try different possible avatar field names
                if (user['profile_image'] != null &&
                    user['profile_image'].toString().isNotEmpty) {
                  avatarUrl = user['profile_image'].toString();
                } else if (user['avatar'] != null &&
                    user['avatar'].toString().isNotEmpty) {
                  avatarUrl = user['avatar'].toString();
                } else if (user['image'] != null &&
                    user['image'].toString().isNotEmpty) {
                  avatarUrl = user['image'].toString();
                } else if (user['profile_pic'] != null &&
                    user['profile_pic'].toString().isNotEmpty) {
                  avatarUrl = user['profile_pic'].toString();
                }

                // Clean up the avatar URL
                if (avatarUrl.isNotEmpty &&
                    avatarUrl != 'null' &&
                    avatarUrl != 'undefined') {
                  avatarUrl = avatarUrl.trim();
                  if (!avatarUrl.startsWith('http') &&
                      !avatarUrl.startsWith('data:image')) {
                    // Uncomment and modify this if you need to prepend a base URL:
                    // avatarUrl = 'https://your-api-domain.com/uploads/' + avatarUrl;
                  }
                } else {
                  avatarUrl = CustomImage.avator; // Use default
                }

                print(
                    '👤 Processing user: ${user['full_name'] ?? user['name']} with avatar: $avatarUrl');

                return {
                  'id': user['id']?.toString() ??
                      user['user_id']?.toString() ??
                      '',
                  'name': user['full_name']?.toString() ??
                      user['name']?.toString() ??
                      'Unknown User',
                  'email': user['email']?.toString() ?? '',
                  'avatar': avatarUrl,
                  // FIXED: Get online status from API response, not hardcoded
                  'isOnline': _parseOnlineStatus(user),
                  'lastSeen': user['last_seen']?.toString(),
                  'specialty':
                      user['specialty']?.toString() ?? 'Community Member',
                  'description': user['description']?.toString() ??
                      'Lupus Care community member',
                };
              })
              .where((user) => user['id'] != userId)
              .toList(); // Exclude current user

          _isLoadingUsers = false;
        });

        print('✅ Loaded ${communityUsers.length} community users');

        // Start listening for online status updates
        _startOnlineStatusListener();
      } else {
        print('❌ Failed to load users: ${response['message']}');
        setState(() {
          communityUsers = [];
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      print('❌ Error loading community users: $e');
      setState(() {
        communityUsers = [];
        _isLoadingUsers = false;
      });
    }
  }

  bool _parseOnlineStatus(Map<String, dynamic> user) {
    try {
      // Get the raw online status from API
      bool apiOnlineStatus = false;

      if (user['is_online'] != null) {
        apiOnlineStatus = user['is_online'] == true ||
            user['is_online'] == 1 ||
            user['is_online'] == '1';
      } else if (user['online'] != null) {
        apiOnlineStatus = user['online'] == true ||
            user['online'] == 1 ||
            user['online'] == '1';
      } else if (user['status'] != null) {
        final status = user['status'].toString().toLowerCase();
        apiOnlineStatus = status == 'online' || status == 'active';
      }

      // If API says they're online, check last activity
      if (apiOnlineStatus && user['last_seen'] != null) {
        try {
          final lastSeen = DateTime.parse(user['last_seen'].toString());
          final now = DateTime.now();
          final difference = now.difference(lastSeen);

          // Consider online only if active within last 3 minutes
          return difference.inMinutes <= 3;
        } catch (e) {
          print('❌ Error parsing last_seen for ${user['name']}: $e');
        }
      }

      // If API says they're online but no last_seen, consider them online
      if (apiOnlineStatus) {
        return true;
      }

      // Default to offline
      return false;
    } catch (e) {
      print('❌ Error parsing online status for ${user['name']}: $e');
      return false;
    }
  }

  Timer? _onlineStatusTimer;

  void _startOnlineStatusListener() {
    // Stop any existing timer
    _onlineStatusTimer?.cancel();

    // Update online status every 30 seconds
    _onlineStatusTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _updateOnlineStatuses();
    });
  }

  Future<void> _updateOnlineStatuses() async {
    if (!mounted || _isLoadingUsers) return;

    try {
      final userData = StorageService.to.getUser();
      if (userData == null) return;

      final userId = userData['id']?.toString() ?? '';
      if (userId.isEmpty) return;

      // Get fresh user data for online statuses
      final response = await _authService.getAllUsers(userId: userId);

      if (response['status'] == 'success' && response['data'] != null) {
        final users = response['data'] as List<dynamic>;

        // Update online statuses without rebuilding the entire list
        setState(() {
          for (var apiUser in users) {
            final apiUserId = apiUser['id']?.toString() ??
                apiUser['user_id']?.toString() ??
                '';

            // Find corresponding user in communityUsers and update online status
            final userIndex =
                communityUsers.indexWhere((user) => user['id'] == apiUserId);
            if (userIndex >= 0) {
              communityUsers[userIndex]['isOnline'] =
                  _parseOnlineStatus(apiUser);
              communityUsers[userIndex]['lastSeen'] =
                  apiUser['last_seen']?.toString();
            }
          }
        });

        print('🔄 Updated online statuses for ${users.length} users');
      }
    } catch (e) {
      print('❌ Error updating online statuses: $e');
    }
  }

  // Refresh chats when app resumes or screen becomes visible
  Future<void> _refreshChatsOnResume() async {
    try {
      if (controller != null) {
        // Force refresh to get latest chats
        await controller!.forceRefreshChats();

        // Update UI
        if (mounted) {
          setState(() {});
        }

        print('✅ Chats refreshed on resume');
      }
    } catch (e) {
      print('❌ Error refreshing chats on resume: $e');
    }
  }

// ENHANCED CommunityChatScreen methods for real-time personal chat updates

// 1. REPLACE your _initializeChatController method:
  Future<void> _initializeChatController() async {
    try {
      print('🎮 CommunityChatScreen: Initializing ENHANCED ChatController...');

      // Initialize ChatController
      if (Get.isRegistered<ChatController>()) {
        controller = Get.find<ChatController>();
        print('✅ Found existing ChatController');
      } else {
        print('🔧 Creating new ChatController...');
        controller = ChatController();
        Get.put<ChatController>(controller!, permanent: true);
        print('✅ ChatController initialized and registered');
      }

      // Enable silent mode to prevent popups during initialization
      controller!.setSilentMode(true);

      // CRITICAL: Refresh user session to ensure proper user ID
      await controller!.refreshUserSession();

      // ENHANCED: Setup with multi-format real-time listeners
      await controller!.initializeWithEnhancedRealTime();

      // Wait for controller to stabilize
      await Future.delayed(Duration(milliseconds: 1000));

      // Re-enable notifications after initialization
      controller!.setSilentMode(false);

      setState(() {
        _isInitializing = false;
      });

      print('✅ ENHANCED ChatController initialization completed');
    } catch (e) {
      print('❌ ChatController initialization failed: $e');
      setState(() {
        _isInitializing = false;
        _hasError = false; // Don't show error, just continue
      });
    }
  }

// 2. ENHANCED: Handle chat tap with comprehensive real-time refresh
  void _handleChatTapEnhanced(Chat chat, int currentTab) {
    print('🎯 Enhanced chat tap: ${chat.id}');
    print('   Chat type: ${chat.isGroup ? 'Group' : 'Personal'}');
    print('   Display name: ${chat.getDisplayName(controller!.currentUserId)}');

    // CRITICAL: Mark this chat as being viewed to prevent notifications
    controller!.setCurrentChatId(chat.id);

    // Navigate to chat screen with enhanced return handling
    Get.to(() => PersonalChatScreen(chat: chat))?.then((_) {
      print('🔄 Returned from chat - triggering ENHANCED refresh');
      _handleReturnFromChatEnhanced();
    });
  }

// 3. ENHANCED: Handle return from chat with comprehensive refresh
  Future<void> _handleReturnFromChatEnhanced() async {
    try {
      print('🔄 ENHANCED handling return from chat...');

      if (controller != null && mounted) {
        // Clear current chat ID
        controller!.setCurrentChatId('');

        // Force comprehensive refresh to catch any new chats or messages
        await controller!.forceRefreshChats();

        // Small delay to ensure updates propagate
        await Future.delayed(Duration(milliseconds: 500));

        // Re-setup real-time listener to ensure it's active
        await controller!.setupEnhancedRealTimeListener();

        // Force UI update
        if (mounted) {
          setState(() {});
        }

        print('✅ ENHANCED return from chat handling completed');
      }
    } catch (e) {
      print('❌ Error in enhanced return from chat handling: $e');
    }
  }

// 4. ENHANCED: Build real-time chats section with comprehensive update handling
  Widget _buildRealTimeChatsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
      ),
      child: Column(
        children: [
          // Search Bar and Tabs
          Container(
            color: Colors.white,
            child: Column(
              children: [
                const SearchBarWidget(),
                const SizedBox(height: 12),
                ChatTabBar(),
                const SizedBox(height: 8),
              ],
            ),
          ),

          // ENHANCED Real-time Chats Content with better state management
          Expanded(
            child: Obx(() {
              final currentTab = controller!.selectedTabIndex.value;
              final personalChats = List<Chat>.from(controller!.personalChats);
              final groupChats = List<Chat>.from(controller!.groupChats);
              final searchQuery = controller!.searchQuery.value;
              final isLoading = controller!.isLoading.value;
              final isInitialSetup = controller!.isInitialSetup.value;

              // Apply search filter
              List<Chat> currentChats;
              if (currentTab == 0) {
                // Personal chats tab
                if (searchQuery.isEmpty) {
                  currentChats = personalChats;
                } else {
                  currentChats = personalChats
                      .where((chat) => chat
                          .getDisplayName(controller!.currentUserId)
                          .toLowerCase()
                          .contains(searchQuery.toLowerCase()))
                      .toList();
                }
              } else {
                // Group chats tab
                if (searchQuery.isEmpty) {
                  currentChats = groupChats;
                } else {
                  currentChats = groupChats
                      .where((chat) => chat
                          .getDisplayName(controller!.currentUserId)
                          .toLowerCase()
                          .contains(searchQuery.toLowerCase()))
                      .toList();
                }
              }

              // CRITICAL: Sort by last message timestamp (newest first)
              currentChats.sort((a, b) =>
                  b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp));

              // Debug logging for real-time updates
              print('📱 ENHANCED Real-time UI update:');
              print('   Current tab: $currentTab');
              print('   Personal chats: ${personalChats.length}');
              print('   Group chats: ${groupChats.length}');
              print('   Filtered chats: ${currentChats.length}');
              print('   Is loading: $isLoading');
              print('   Is initial setup: $isInitialSetup');

              if (currentChats.isNotEmpty) {
                print(
                    '   Latest chat: ${currentChats.first.getDisplayName(controller!.currentUserId)}');
                print('   Latest message: "${currentChats.first.lastMessage}"');
                print(
                    '   Message timestamp: ${currentChats.first.lastMessageTimestamp}');
              }

              // Show loading only during initial setup
              if (isLoading && isInitialSetup) {
                return _buildInitialLoadingState();
              }

              // Show creating chat state only when creating and no chats exist
              final totalChats = personalChats.length + groupChats.length;
              if (controller!.isCreatingChat.value && totalChats == 0) {
                return _buildCreatingChatState();
              }

              return Column(
                children: [
                  // Chats list or empty state
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _handleEnhancedPullToRefresh,
                      child: currentChats.isEmpty
                          ? _buildEnhancedEmptyState(currentTab)
                          : Container(
                              color: Colors.white,
                              child: ListView.builder(
                                physics: AlwaysScrollableScrollPhysics(),
                                itemCount: currentChats.length,
                                itemBuilder: (context, index) {
                                  final chat = currentChats[index];
                                  return _buildEnhancedLiveChatTile(
                                      chat, currentTab);
                                },
                              ),
                            ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

// 5. NEW: Build initial loading state
  Widget _buildInitialLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: CustomColors.purpleColor,
          ),
        ],
      ),
    );
  }

// 6. ENHANCED: Build live chat tile with comprehensive real-time features
  Widget _buildEnhancedLiveChatTile(Chat chat, int currentTab) {
    final currentUserId = controller!.currentUserId;
    final unreadCount = chat.unreadCounts[currentUserId] ?? 0;

    // Get real-time online status
    final isOnline = currentTab == 0 && !chat.isGroup
        ? controller!.isOtherParticipantOnline(chat)
        : false;

    return Container(
      color: unreadCount > 0 ? Colors.blue.withOpacity(0.02) : Colors.white,
      margin: EdgeInsets.only(bottom: 1),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildEnhancedChatAvatarWithOnlineStatus(
            chat, currentTab, unreadCount, isOnline),
        title: _buildEnhancedChatTitleWithTime(chat, currentTab, unreadCount),
        subtitle: _buildEnhancedChatSubtitleWithPreview(chat, unreadCount),
        onTap: () => _handleChatTapEnhanced(chat, currentTab),
        onLongPress: () => _showChatOptionsBottomSheet(chat),
      ),
    );
  }

  Widget _buildEnhancedChatTitleWithTime(
      Chat chat, int currentTab, int unreadCount) {
    final displayName = chat.getDisplayName(controller!.currentUserId);
    final timeAgo = _formatLastMessageTimeEnhanced(chat.lastMessageTimestamp);

    return Row(
      children: [
        Expanded(
          child: Text(
            displayName ?? 'Unknown',
            style: semiBoldStyle.copyWith(
              fontSize: Dimensions.fontSizeExtraLarge,
              color: unreadCount > 0 ? Colors.black : Colors.grey[800],
              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 8),
        Text(
          timeAgo,
          style: regularStyle.copyWith(
            fontSize: Dimensions.fontSizeSmall,
            color: unreadCount > 0
                ? CustomColors.purpleColor
                : CustomColors.blackColor,
            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedChatSubtitleWithPreview(Chat chat, int unreadCount) {
    String lastMessage = chat.lastMessage.isNotEmpty
        ? (chat.lastMessage.length > 50
            ? '${chat.lastMessage.substring(0, 50)}...'
            : chat.lastMessage)
        : 'No messages yet';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 4),
        Row(
          children: [
            if (chat.lastMessageSender == controller!.currentUserId)
              SizedBox(width: 4),

            Expanded(
              child: Text(
                lastMessage,
                style: regularStyle.copyWith(
                  fontSize: Dimensions.fontSizeLarge,
                  color: unreadCount > 0
                      ? Colors.black87
                      : CustomColors.blackColor,
                  fontWeight:
                      unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                  fontStyle: lastMessage == 'No messages yet'
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Unread count badge
            if (unreadCount > 0)
              Container(
                height: 20,
                width: 20,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    unreadCount.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
          ],
        ),
      ],
    );
  }

  Widget _buildChatAvatarImageEnhanced(
      String? imageUrl, Chat chat, int currentTab) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      // Base64 image
      if (imageUrl.startsWith('data:image')) {
        return _buildBase64ImageEnhanced(imageUrl, chat, currentTab);
      }
      // Network URL
      else if (imageUrl.startsWith('http')) {
        return _buildNetworkImageEnhanced(imageUrl, chat, currentTab);
      }
      // Asset path
      else if (imageUrl.startsWith('assets/')) {
        return _buildAssetImageEnhanced(imageUrl, chat, currentTab);
      }
    }

    // Default image
    return _buildDefaultImageEnhanced(chat, currentTab);
  }

// 11. ENHANCED: Base64 image with better error handling
  Widget _buildBase64ImageEnhanced(
      String base64Data, Chat chat, int currentTab) {
    try {
      final parts = base64Data.split(',');
      if (parts.length != 2) {
        return _buildDefaultImageEnhanced(chat, currentTab);
      }

      final base64String = parts[1];
      final Uint8List imageBytes = base64Decode(base64String);

      return Image.memory(
        imageBytes,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Error displaying base64 image: $error');
          return _buildDefaultImageEnhanced(chat, currentTab);
        },
      );
    } catch (e) {
      print('❌ Error processing base64 image: $e');
      return _buildDefaultImageEnhanced(chat, currentTab);
    }
  }

// 12. ENHANCED: Network image with better loading
  Widget _buildNetworkImageEnhanced(
      String imageUrl, Chat chat, int currentTab) {
    return Image.network(
      imageUrl,
      width: 56,
      height: 56,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: CustomColors.purpleColor,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('❌ Error loading network image: $imageUrl - $error');
        return _buildDefaultImageEnhanced(chat, currentTab);
      },
    );
  }

// 13. ENHANCED: Asset image with error handling
  Widget _buildAssetImageEnhanced(String assetPath, Chat chat, int currentTab) {
    return Image.asset(
      assetPath,
      width: 56,
      height: 56,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        print('❌ Error loading asset image: $assetPath - $error');
        return _buildDefaultImageEnhanced(chat, currentTab);
      },
    );
  }

// 14. ENHANCED: Default image with better styling
  Widget _buildDefaultImageEnhanced(Chat chat, int currentTab) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: CustomColors.lightPurpleColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        chat.isGroup || currentTab == 1 ? Icons.group : Icons.person,
        color: CustomColors.purpleColor,
        size: 30,
      ),
    );
  }

// 15. ENHANCED: Time formatting with relative time
  String _formatLastMessageTimeEnhanced(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 30) {
      return 'Just now';
    } else if (difference.inMinutes < 1) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

// 16. NEW: Chat options bottom sheet
  void _showChatOptionsBottomSheet(Chat chat) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 16),
            Text(
              chat.getDisplayName(controller!.currentUserId) ?? 'Chat Options',
              style: semiBoldStyle.copyWith(
                fontSize: Dimensions.fontSizeLarge,
              ),
            ),
            SizedBox(height: 20),

            // Mark as read option
            if ((chat.unreadCounts[controller!.currentUserId] ?? 0) > 0)
              ListTile(
                leading: Icon(Icons.mark_email_read,
                    color: CustomColors.purpleColor),
                title: Text('Mark as Read'),
                onTap: () {
                  controller!
                      .markMessagesAsRead(chat.id, controller!.currentUserId!);
                  Get.back();
                },
              ),

            // Mute/Unmute option
            ListTile(
              leading: Icon(Icons.notifications_off, color: Colors.orange),
              title: Text('Mute Chat'),
              onTap: () {
                controller!.toggleChatMute(chat.id, true);
                Get.back();
              },
            ),

            // Delete chat option
            if (!chat.isGroup)
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete Chat'),
                onTap: () {
                  Get.back();
                  _confirmDeleteChat(chat);
                },
              ),

            // Leave group option
            if (chat.isGroup)
              ListTile(
                leading: Icon(Icons.exit_to_app, color: Colors.red),
                title: Text('Leave Group'),
                onTap: () {
                  Get.back();
                  _confirmLeaveGroup(chat);
                },
              ),
          ],
        ),
      ),
    );
  }

// 17. NEW: Confirm delete chat
  void _confirmDeleteChat(Chat chat) {
    Get.dialog(
      AlertDialog(
        title: Text('Delete Chat'),
        content: Text(
            'Are you sure you want to delete this chat? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller!.deleteChat(chat.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

// 18. NEW: Confirm leave group
  void _confirmLeaveGroup(Chat chat) {
    Get.dialog(
      AlertDialog(
        title: Text('Leave Group'),
        content: Text('Are you sure you want to leave "${chat.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller!.leaveGroup(chat.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Leave'),
          ),
        ],
      ),
    );
  }

// 19. ENHANCED: Open chat with user using enhanced method
  Future<void> _openChatWithUserEnhanced(Map<String, dynamic> userData) async {
    print('🔧 Opening ENHANCED chat with ${userData['name']}');
    print('🔧 User data: $userData');

    try {
      // Initialize controller if not available
      if (controller == null) {
        print('🔧 Creating ChatController...');
        controller = ChatController();
        Get.put<ChatController>(controller!, permanent: true);
        controller!.setSilentMode(true);
        await Future.delayed(Duration(milliseconds: 1000));
      }

      // Set loading state
      controller!.isSendingMessage.value = true;

      // Show loading indicator
      // Get.dialog(
      //   Center(
      //     child:   CircularProgressIndicator(color: CustomColors.purpleColor),
      //   ),
      //   barrierDismissible: false,
      // );

      // Ensure user session is fresh
      await controller!.refreshUserSession();

      final currentUserId = controller!.currentUserId;
      print('👤 Current User ID: $currentUserId');

      if (currentUserId == null) {
        controller!.isSendingMessage.value = false;
        Get.back();
        Get.snackbar(
          'Error',
          'Please restart the app and try again',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Use the enhanced createPersonalChat method
      String? chatId = await controller!.createPersonalChatEnhanced(
        userData['id'],
        userData['name'],
      );

      Get.back(); // Close loading dialog

      if (chatId != null) {
        print('✅ Chat created successfully: $chatId');

        // Wait for real-time updates to propagate
        await Future.delayed(Duration(milliseconds: 1000));

        // Force refresh to ensure chat is in local list
        await controller!.forceRefreshChats();

        // Find the created chat
        final createdChat = [
          ...controller!.personalChats,
          ...controller!.groupChats
        ].firstWhereOrNull((chat) => chat.id == chatId);

        if (createdChat != null) {
          print('✅ Found created chat in list, navigating...');
          controller!.isSendingMessage.value = false;

          Get.to(() => PersonalChatScreen(chat: createdChat))?.then((_) {
            _handleReturnFromChatEnhanced();
          });
        } else {
          print('⚠️ Creating manual chat object...');

          // Create manual chat object as fallback
          final chat = Chat(
            id: chatId,
            participants: [currentUserId, 'app_user_${userData['id']}'],
            isGroup: false,
            unreadCounts: {
              currentUserId: 0,
              'app_user_${userData['id']}': 0,
            },
            participantDetails: {
              currentUserId: ParticipantInfo(
                id: currentUserId,
                name: controller!.currentUserName ?? 'You',
                avatar: controller!.currentUserAvatar,
                isOnline: true,
              ),
              'app_user_${userData['id']}': ParticipantInfo(
                id: 'app_user_${userData['id']}',
                name: userData['name'],
                avatar: userData['avatar'] ?? CustomImage.avator,
                isOnline: userData['isOnline'] ?? false,
              ),
            },
            lastMessage: 'Chat created',
            lastMessageTimestamp: DateTime.now(),
            lastMessageSender: 'system',
            createdAt: DateTime.now(),
          );

          controller!.isSendingMessage.value = false;

          Get.snackbar(
            'Success',
            'Chat started with ${userData['name']}',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );

          Get.to(() => PersonalChatScreen(chat: chat))?.then((_) {
            _handleReturnFromChatEnhanced();
          });
        }
      } else {
        controller!.isSendingMessage.value = false;
        Get.snackbar(
          'Error',
          'Unable to start chat right now. Please try again.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      controller?.isSendingMessage.value = false;
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      print('❌ Error in _openChatWithUserEnhanced: $e');
      Get.snackbar(
        'Error',
        'Something went wrong. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

// 20. UPDATE your _openChatWithUser method to use the enhanced version:
  Future<void> _openChatWithUser(Map<String, dynamic> userData) async {
    await _openChatWithUserEnhanced(userData);
  }

// ENHANCED: Handle chat tap with proper return handling
  void _handleChatTap(Chat chat, int currentTab) {
    print('🎯 Enhanced chat tap: ${chat.id}');

    // Navigate to chat screen with enhanced return handling
    Get.to(() => PersonalChatScreen(chat: chat))?.then((_) {
      print('🔄 Returned from chat - triggering enhanced refresh');
      _handleReturnFromChat();
    });
  }

// ENHANCED: Handle return from chat with forced refresh
  Future<void> _handleReturnFromChat() async {
    try {
      print('🔄 Enhanced handling return from chat...');

      if (controller != null && mounted) {
        // Force refresh chats to get latest updates
        await controller!.forceRefreshChats();

        // Small delay to ensure updates propagate
        await Future.delayed(Duration(milliseconds: 300));

        // Force UI update
        if (mounted) {
          setState(() {});
        }

        print('✅ Enhanced return from chat handling completed');
      }
    } catch (e) {
      print('❌ Error in enhanced return from chat handling: $e');
    }
  }

  Future<void> _handleEnhancedPullToRefresh() async {
    try {
      print('⬇️ Enhanced pull to refresh triggered');

      if (controller != null) {
        // Force refresh chats
        await controller!.forceRefreshChats();

        // Setup real-time listener again to ensure it's active
        await controller!.setupEnhancedRealTimeListener();
      }

      // Refresh community data
      await _loadCommunityData();

      // Brief delay for smooth animation
      await Future.delayed(Duration(milliseconds: 500));

      if (mounted) {
        setState(() {});
      }

      print('✅ Enhanced pull to refresh completed');
    } catch (e) {
      print('❌ Error in enhanced pull to refresh: $e');
    }
  }

// ENHANCED: App lifecycle handling for real-time updates
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed && controller != null) {
      print('📱 App resumed - setting up enhanced refresh');
      _handleAppResume();
    } else if (state == AppLifecycleState.paused) {
      print('📱 App paused');
    }
  }

// ENHANCED: Handle app resume with comprehensive refresh
  Future<void> _handleAppResume() async {
    try {
      print('📱 Enhanced app resume handling...');

      // Refresh user session
      await controller!.refreshUserSession();

      // Setup real-time listener again
      await controller!.setupEnhancedRealTimeListener();

      // Force refresh chats
      await controller!.forceRefreshChats();

      // Refresh community data
      _loadCommunityUsers();
      _loadCommunityData();

      if (mounted) {
        setState(() {});
      }

      print('✅ Enhanced app resume handling completed');
    } catch (e) {
      print('❌ Error in enhanced app resume handling: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Show loading while initializing
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            'Community & Chat',
            style: mediumStyle.copyWith(
              fontSize: Dimensions.fontSizeOverLarge,
            ),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: CustomColors.purpleColor,
              ),
            ],
          ),
        ),
      );
    }

    // Show the main chat interface
    return _buildEnhancedChatInterface();
  }

  Widget _buildEnhancedChatInterface() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Community & Chat',
          style: mediumStyle.copyWith(
            fontSize: Dimensions.fontSizeOverLarge,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: controller != null
          ? Obx(() {
              // Show loading state only during initial setup
              if (controller!.isLoading.value &&
                  controller!.isInitialSetup.value) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                          color: CustomColors.purpleColor),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // Recent Chats Section with Real-time Updates
                  Expanded(child: _buildRealTimeChatsSection()),
                ],
              );
            })
          : _buildControllerNotAvailableState(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildCreatingChatState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // CircularProgressIndicator(color: CustomColors.purpleColor),
          // SizedBox(height: 16),
          // Text(
          //   'Setting up your chat...',
          //   style: mediumStyle.copyWith(
          //     fontSize: Dimensions.fontSizeLarge,
          //     color: Colors.grey[600],
          //   ),
          // ),
          // SizedBox(height: 8),
          // Text(
          //   'Connecting you with the community',
          //   style: regularStyle.copyWith(
          //     fontSize: Dimensions.fontSizeDefault,
          //     color: Colors.grey[500],
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildEnhancedEmptyState(int currentTab) {
    final isPersonalTab = currentTab == 0;

    if (isPersonalTab) {
      // For personal chats, show clean empty state
      return Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.all(20),
          children: [
            SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  SvgPicture.asset(
                    CustomIcons.leaveEmpty,
                    width: 100,
                    height: 100,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No Conversations Yet',
                    style: mediumStyle.copyWith(
                      fontSize: Dimensions.fontSizeOverLarge,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Search for a user & Start a new chat or join the conversation.',
                    style: semiLightStyle.copyWith(
                        fontSize: Dimensions.fontSizeLarge,
                        color: CustomColors.leaveColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _buildStartChatButton(),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Keep the original empty state for groups
      return Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.all(20),
          children: [
            SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  SvgPicture.asset(
                    CustomIcons.leaveEmpty,
                    width: 100,
                    height: 100,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No Conversations Yet',
                    style: mediumStyle.copyWith(
                      fontSize: Dimensions.fontSizeOverLarge,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Search for a group & Start a new chat or join a Group.',
                    style: semiLightStyle.copyWith(
                        fontSize: Dimensions.fontSizeLarge,
                        color: CustomColors.leaveColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _buildCreateGroupButton(),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

// ENHANCED: Always show status indicator - green for online, grey for offline

// 1. UPDATE: _buildDetailedPersonTile method to always show status dot
  Widget _buildDetailedPersonTile(Map<String, dynamic> person) {
    final isOnline = person['isOnline'] == true;
    final lastSeen = person['lastSeen']?.toString();

    print('👤 Building person tile for: ${person['name']}');
    print('🟢 Online status: $isOnline');
    print('⏰ Last seen: $lastSeen');

    return Container(
      margin: EdgeInsets.only(bottom: 5),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: Stack(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CustomColors.lightPurpleColor,
              ),
              child: ClipOval(
                child: _buildUserImage(
                  person['avatar'],
                  width: 56,
                  height: 56,
                ),
              ),
            ),
            // ALWAYS show status indicator - green for online, grey for offline
            Positioned(
              right: 2,
              bottom: 2,
              child: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.grey[400],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: (isOnline ? Colors.green : Colors.grey[400]!)
                          .withOpacity(0.3),
                      blurRadius: 3,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        title: Text(
          person['name'],
          style: semiBoldStyle.copyWith(
            fontSize: Dimensions.fontSizeLarge,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced status text with better formatting
            // Row(
            //   children: [
            //     Container(
            //       width: 8,
            //       height: 8,
            //       decoration: BoxDecoration(
            //         shape: BoxShape.circle,
            //         color: isOnline ? Colors.green : Colors.grey[400],
            //       ),
            //     ),
            //     SizedBox(width: 6),
            //     Text(
            //       isOnline ? 'Online' : (lastSeen != null ? _formatLastSeen(lastSeen) : 'Offline'),
            //       style: regularStyle.copyWith(
            //         fontSize: Dimensions.fontSizeSmall,
            //         color: isOnline ? Colors.green[600] : Colors.grey[500],
            //         fontWeight: isOnline ? FontWeight.w500 : FontWeight.normal,
            //       ),
            //     ),
            //   ],
            // ),
          ],
        ),
        onTap: () {
          print('👆 Tapping on user: ${person['name']} (Online: $isOnline)');
          Get.back(); // Close bottom sheet
          _openChatWithUser(person);
        },
      ),
    );
  }

// 2. UPDATE: _buildEnhancedChatAvatarWithOnlineStatus to always show status
  Widget _buildEnhancedChatAvatarWithOnlineStatus(
      Chat chat, int currentTab, int unreadCount, bool isOnline) {
    print('🖼️ Building ENHANCED chat avatar for: ${chat.id}');
    print('   Is Group: ${chat.isGroup}');
    print('   Is Online: $isOnline');
    print('   Unread Count: $unreadCount');

    String? displayImage;

    if (chat.isGroup) {
      displayImage = controller!.getGroupDisplayImage(chat);
    } else {
      displayImage = chat.getDisplayAvatar(controller!.currentUserId);
    }

    return Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: CustomColors.lightPurpleColor,
            // Add subtle border for active chats
            border: unreadCount > 0
                ? Border.all(color: CustomColors.purpleColor, width: 2)
                : null,
          ),
          child: ClipOval(
            child:
                _buildChatAvatarImageEnhanced(displayImage, chat, currentTab),
          ),
        ),

        // ENHANCED: Always show status indicator for personal chats (not groups)
        if (currentTab == 0 && !chat.isGroup)
          Positioned(
            right: 2,
            bottom: 2,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isOnline ? Colors.green : Colors.grey[400],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: (isOnline ? Colors.green : Colors.grey[400]!)
                        .withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),

        // ENHANCED: Unread count badge with animation (positioned differently to avoid overlap)
        if (unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              constraints: BoxConstraints(minWidth: 20, minHeight: 20),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  String _formatLastSeen(String lastSeenStr) {
    try {
      final lastSeen = DateTime.parse(lastSeenStr);
      final now = DateTime.now();
      final difference = now.difference(lastSeen);

      if (difference.inSeconds < 30) {
        return 'Just now';
      } else if (difference.inMinutes < 1) {
        return '${difference.inSeconds}s ago';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        // For HRMS, show actual date for longer periods
        return '${lastSeen.day}/${lastSeen.month}/${lastSeen.year}';
      }
    } catch (e) {
      print('❌ Error formatting last seen: $e');
      return 'Offline';
    }
  }

  Widget _buildStartChatButton() {
    return ElevatedButton.icon(
      onPressed: () {
        Get.to(() => FindFriendScreen(
              communityUsers: communityUsers, // Your list of users
              onChatWithUser: _openChatWithUser, // Your chat opening function
            ));
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: CustomColors.purpleColor,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      icon: Icon(Icons.chat, size: 20),
      label: Text(
        'Find a Friend',
        style: mediumStyle.copyWith(
          color: Colors.white,
          fontSize: Dimensions.fontSizeDefault,
        ),
      ),
    );
  }

  Widget _buildCreateGroupButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: () {
            Get.to(() => FindGroupScreen(
                  availableGroups: availableGroups,
                  onRefreshGroups: _loadAvailableGroups,
                  onJoinGroup: _createFirebaseGroupFromAPI,
                  onOpenGroupChat: _openExistingGroupChat,
                ));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: CustomColors.purpleColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          icon: Icon(Icons.search, size: 20),
          label: Text(
            'Find Group',
            style: mediumStyle.copyWith(
              color: Colors.white,
              fontSize: Dimensions.fontSizeDefault,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createFirebaseGroupFromAPI(
      Map<String, dynamic> apiGroup) async {
    try {
      if (controller == null || controller!.currentUserId == null) {
        print('❌ Controller or user ID not available');
        return;
      }

      print('🔥 Creating Firebase group for API group: ${apiGroup['name']}');
      print('🔥 API Group ID: ${apiGroup['id']}');

      // Check if Firebase group already exists
      final existingGroups = await FirebaseFirestore.instance
          .collection('chats')
          .where('apiGroupId', isEqualTo: apiGroup['id'])
          .where('isGroup', isEqualTo: true)
          .get();

      if (existingGroups.docs.isNotEmpty) {
        print(
            '✅ Firebase group already exists: ${existingGroups.docs.first.id}');
        return;
      }

      // CRITICAL: Get ALL group members from API
      final membersResponse = await _authService.getGroupMembers(
        groupId: apiGroup['id'].toString(),
      );

      // Prepare all participants with consistent user ID format
      final allParticipants = <String>[];
      final participantDetails = <String, dynamic>{};
      final unreadCounts = <String, dynamic>{};

      // Add current user first
      final currentUserId = controller!.currentUserId!;
      allParticipants.add(currentUserId);
      participantDetails[currentUserId] = {
        'id': currentUserId,
        'name': controller!.currentUserName ?? 'User',
        'avatar': controller!.currentUserAvatar ?? CustomImage.avator,
        'isOnline': true,
        'joinedAt': FieldValue.serverTimestamp(),
        'role': 'member',
      };
      unreadCounts[currentUserId] = 0;

      // Add API group members with consistent user ID format
      if (membersResponse['status'] == 'success' &&
          membersResponse['data'] != null) {
        final members = membersResponse['data'] as List<dynamic>;
        print('👥 Found ${members.length} API group members');

        for (var member in members) {
          final apiUserId = member['id']?.toString();
          if (apiUserId == null || apiUserId.isEmpty) continue;

          // Convert API user ID to consistent format
          final consistentUserId = 'app_user_$apiUserId';

          // Skip if already added (current user)
          if (allParticipants.contains(consistentUserId)) continue;

          allParticipants.add(consistentUserId);
          participantDetails[consistentUserId] = {
            'id': consistentUserId,
            'name': member['name'] ?? member['full_name'] ?? 'Member',
            'avatar': member['avatar'] ??
                member['profile_image'] ??
                CustomImage.avator,
            'isOnline': false,
            'joinedAt': FieldValue.serverTimestamp(),
            'role': 'member',
            'originalApiId': apiUserId, // Store original API ID
          };
          unreadCounts[consistentUserId] = 0;

          print(
              '👤 Added member: ${member['name']} (API: $apiUserId, Consistent: $consistentUserId)');
        }
      }

      print('👥 Total participants: ${allParticipants.length}');

      // Create comprehensive group document
      final groupData = {
        'name': apiGroup['name'],
        'description': apiGroup['description'] ?? '',
        'groupImage': apiGroup['image'] ?? '',
        'participants': allParticipants,
        'isGroup': true,
        'createdBy': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': 'Group created',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSender': 'system',
        'apiGroupId': apiGroup['id']?.toString(),
        'apiSyncStatus': 'synced',
        'participantDetails': participantDetails,
        'unreadCounts': unreadCounts,
        'memberCount': allParticipants.length,
        'groupType': 'joined', // Mark as joined group vs created group
        'realTimeSync': true,
      };

      // Create Firebase group document
      final docRef =
          await FirebaseFirestore.instance.collection('chats').add(groupData);

      print('✅ Firebase group created successfully: ${docRef.id}');
      print('🔗 Linked with API group ID: ${apiGroup['id']}');

      // CRITICAL: Notify all participants about the new group
      await _notifyAllParticipantsAboutGroup(
          docRef.id, allParticipants, groupData);

      // Force refresh chats to show new group
      await Future.delayed(Duration(milliseconds: 1000));
      await controller!.forceRefreshChats();
    } catch (e) {
      print('❌ Error creating Firebase group from API: $e');
    }
  }

// 2. CRITICAL: Notify all participants about new group
  Future<void> _notifyAllParticipantsAboutGroup(String groupId,
      List<String> participants, Map<String, dynamic> groupData) async {
    try {
      print(
          '🔔 Notifying ${participants.length} participants about new group: $groupId');

      final batch = FirebaseFirestore.instance.batch();
      final currentUserId = controller!.currentUserId!;

      for (String participantId in participants) {
        // Skip current user
        if (participantId == currentUserId) continue;

        // Create notification document
        final notificationRef =
            FirebaseFirestore.instance.collection('notifications').doc();

        batch.set(notificationRef, {
          'type': 'new_group',
          'groupId': groupId,
          'groupName': groupData['name'],
          'userId': participantId,
          'createdBy': currentUserId,
          'createdByName': controller!.currentUserName ?? 'User',
          'timestamp': FieldValue.serverTimestamp(),
          'processed': false,
          'forceSync': true,
          'apiGroupId': groupData['apiGroupId'],
        });
      }

      await batch.commit();
      print('✅ All participants notified about new group');
    } catch (e) {
      print('❌ Error notifying participants about group: $e');
    }
  }

  Future<void> _createGroupWithUsers() async {
    if (controller == null) return;

    try {
      controller!.isLoading.value = true;

      // Get current user info
      final currentUserId = controller!.currentUserId!;
      final currentUserName = controller!.currentUserName ?? 'User';
      final currentUserAvatar =
          controller!.currentUserAvatar ?? CustomImage.avator;

      // Prepare all participants with consistent user ID format
      final allParticipants = <String>[currentUserId];
      final participantDetails = <String, dynamic>{};
      final unreadCounts = <String, dynamic>{};

      // Add current user
      participantDetails[currentUserId] = {
        'id': currentUserId,
        'name': currentUserName,
        'avatar': currentUserAvatar,
        'isOnline': true,
        'role': 'admin',
        'joinedAt': FieldValue.serverTimestamp(),
      };
      unreadCounts[currentUserId] = 0;

      // Add selected members with consistent user ID format
      for (var member in controller!.selectedMembers) {
        final apiUserId = member.id;
        final consistentUserId = 'app_user_$apiUserId';

        allParticipants.add(consistentUserId);
        participantDetails[consistentUserId] = {
          'id': consistentUserId,
          'name': member.name,
          'avatar':
              member.avatar.isNotEmpty ? member.avatar : CustomImage.avator,
          'isOnline': member.isOnline,
          'role': 'member',
          'originalApiId': apiUserId,
          'joinedAt': FieldValue.serverTimestamp(),
        };
        unreadCounts[consistentUserId] = 0;

        print(
            '👤 Added member: ${member.name} (API: $apiUserId, Consistent: $consistentUserId)');
      }

      // Create group document
      final groupData = {
        'name': controller!.groupName.value.trim(),
        'description': controller!.groupDescription.value.trim(),
        'groupImage': '', // Will be updated if image is selected
        'participants': allParticipants,
        'isGroup': true,
        'createdBy': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': 'Group created',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSender': currentUserId,
        'participantDetails': participantDetails,
        'unreadCounts': unreadCounts,
        'memberCount': allParticipants.length,
        'groupType': 'created',
        'realTimeSync': true,
      };

      // Create group in Firebase
      final docRef =
          await FirebaseFirestore.instance.collection('chats').add(groupData);

      print('✅ Group created successfully: ${docRef.id}');

      // CRITICAL: Notify all participants
      await _notifyAllParticipantsAboutGroup(
          docRef.id, allParticipants, groupData);

      // Close bottom sheet
      Get.back();

      // Show success message
      Get.snackbar(
        'Success',
        'Group created successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );

      // Force refresh chats
      await Future.delayed(Duration(milliseconds: 1000));
      await controller!.forceRefreshChats();
    } catch (e) {
      print('❌ Error creating group with users: $e');
      Get.snackbar(
        'Error',
        'Failed to create group: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      controller!.isLoading.value = false;
    }
  }

  Future<void> testNotificationSystem() async {
    try {
      print('🧪 Testing notification system...');

      final currentUserId = controller!.currentUserId!;
      final testUserId = 'app_user_test';

      // Create test notification
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'test',
        'userId': testUserId,
        'createdBy': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'processed': false,
        'forceSync': true,
        'message': 'This is a test notification',
      });

      print('✅ Test notification created');

      // Listen for notifications
      FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: currentUserId)
          .where('processed', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        print('🔔 Received ${snapshot.docs.length} notifications');
        for (var doc in snapshot.docs) {
          print('🔔 Notification: ${doc.data()}');
        }
      });
    } catch (e) {
      print('❌ Error testing notification system: $e');
    }
  }

  void _openExistingGroupChat(Map<String, dynamic> group) async {
    final groupId = group['id']?.toString();
    final groupName = group['name']?.toString() ?? 'Group';

    print("🔥 Opening existing group chat:");
    print("   Group ID: '$groupId'");
    print("   Group Name: '$groupName'");
    print("   Full group data: $group");

    if (groupId == null || groupId.isEmpty) {
      print("❌ Group ID is null or empty from group data");
      Get.snackbar(
        'Error',
        'Group ID not found',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
      return;
    }

    // Close the bottom sheet first
    if (Get.isBottomSheetOpen ?? false) {
      Get.back();
    }

    // Show loading dialog
    Get.dialog(
      Center(
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: CustomColors.purpleColor),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );

    try {
      // Step 1: Get group details first
      print("📞 Step 1: Calling get_group_details API for group: $groupId");
      final groupDetailsResponse =
          await _authService.getGroupDetails(groupId: groupId);

      print("📥 Group details response: ${groupDetailsResponse['status']}");
      print("📊 Group details data: ${groupDetailsResponse['data']}");

      if (groupDetailsResponse['status'] != 'success') {
        Get.back(); // Close loading dialog
        Get.snackbar(
          'Error',
          'Failed to load group details: ${groupDetailsResponse['message'] ?? 'Unknown error'}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
        return;
      }

      // Extract group details from response
      final groupDetailsData =
          groupDetailsResponse['data'] as Map<String, dynamic>? ?? {};

      // Get the group ID from the details response (in case it's different)
      final actualGroupId = groupDetailsData['id']?.toString() ??
          groupDetailsData['group_id']?.toString() ??
          groupId;

      print("📋 Extracted group details:");
      print("   Original Group ID: '$groupId'");
      print("   Actual Group ID: '$actualGroupId'");
      print(
          "   Group Name: '${groupDetailsData['name'] ?? groupDetailsData['group_name'] ?? groupName}'");

      // Step 2: Get group members using the actual group ID
      print(
          "📞 Step 2: Calling get_group_members API for group: $actualGroupId");
      final membersResponse =
          await _authService.getGroupMembers(groupId: actualGroupId);

      print("📥 Group members response: ${membersResponse['status']}");
      print("📊 Group members data: ${membersResponse['data']}");

      // Close loading dialog
      Get.back();

      if (membersResponse['status'] != 'success') {
        Get.snackbar(
          'Warning',
          'Group loaded but failed to get members: ${membersResponse['message'] ?? 'Unknown error'}',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
      }

      // Ensure we're passing a non-null group ID
      final finalGroupId = actualGroupId.isNotEmpty ? actualGroupId : groupId;
      final finalGroupName = groupDetailsData['name']?.toString() ??
          groupDetailsData['group_name']?.toString() ??
          groupName;

      print("🎯 Final navigation parameters:");
      print("   Final Group ID: '$finalGroupId'");
      print("   Final Group Name: '$finalGroupName'");

      // OPTION 1: Navigate to GroupInfoScreen first
      Get.to(() => GroupInfoScreen(
            groupId: finalGroupId,
            groupName: finalGroupName,
            memberCount: int.tryParse(group['memberCount']?.toString() ?? '0'),
          ));

      // OPTION 2: Or navigate directly to chat if Firebase group exists
      // You can check if Firebase group exists and navigate to PersonalChatScreen
      /*
    final existingGroups = await FirebaseFirestore.instance
        .collection('chats')
        .where('apiGroupId', isEqualTo: finalGroupId)
        .where('isGroup', isEqualTo: true)
        .get();

    if (existingGroups.docs.isNotEmpty) {
      final firebaseChat = Chat.fromFirestore(
        existingGroups.docs.first.data(),
        existingGroups.docs.first.id,
      );

      Get.to(() => PersonalChatScreen(chat: firebaseChat));
    } else {
      // Navigate to GroupInfoScreen if no Firebase chat exists
      Get.to(() => GroupInfoScreen(
        groupId: finalGroupId,
        groupName: finalGroupName,
        memberCount: int.tryParse(group['memberCount']?.toString() ?? '0'),
      ));
    }
    */
    } catch (e) {
      // Close loading dialog if still open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      print("❌ Error in group chat workflow: $e");
      print("❌ Stack trace: ${StackTrace.current}");
      Get.snackbar(
        'Error',
        'Failed to open group chat: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
    }
  }

  Widget _buildControllerNotAvailableState() {
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
            'Community Chat Ready',
            style: mediumStyle.copyWith(
              fontSize: Dimensions.fontSizeLarge,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect with community members above',
            style: regularStyle.copyWith(
              fontSize: Dimensions.fontSizeDefault,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (controller == null) return null;

    return Obx(() {
      final isLoading = controller!.isLoading.value;
      final isInitialSetup = controller!.isInitialSetup.value;
      final currentTab = controller!.selectedTabIndex.value;

      // Only hide during initial setup loading
      final shouldHide = isLoading && isInitialSetup;

      if (shouldHide) {
        return SizedBox.shrink();
      }

      return FloatingActionButton.extended(
        onPressed: () {
          if (currentTab == 0) {
            // Personal chat tab - show community members
            _showAllCommunityMembers();
          } else {
            // Group chat tab - create new group
            _showCreateGroupBottomSheet();
          }
        },
        backgroundColor: CustomColors.purpleColor,
        foregroundColor: Colors.white,
        elevation: 6,
        icon: Icon(
          currentTab == 0 ? Icons.chat : Icons.group_add,
          size: 20,
        ),
        label: Text(
          currentTab == 0 ? 'New Chat' : 'New Group',
          style: mediumStyle.copyWith(
            color: Colors.white,
            fontSize: Dimensions.fontSizeDefault,
          ),
        ),
      );
    });
  }

  void _showAllCommunityMembers() {
    Get.bottomSheet(
      Container(
        height: Get.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_isLoadingUsers)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: CustomColors.purpleColor,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoadingUsers
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                              color: CustomColors.purpleColor),
                        ],
                      ),
                    )
                  : communityUsers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline,
                                  size: 64, color: Colors.grey[400]),
                              SizedBox(height: 16),
                              Text(
                                'No community members found',
                                style: mediumStyle.copyWith(
                                  fontSize: Dimensions.fontSizeLarge,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _loadCommunityUsers,
                                child: Text('Refresh'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          itemCount: communityUsers.length,
                          itemBuilder: (context, index) {
                            final person = communityUsers[index];
                            return _buildDetailedPersonTile(person);
                          },
                        ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showCreateGroupBottomSheet() {
    if (controller == null) return;

    // Reset form values
    controller!.groupName.value = '';
    controller!.groupDescription.value = '';
    controller!.selectedMembers.clear();
    controller!.filteredUsers.clear();

    // Convert API users to AppUser objects for selection
    final availableUsers = communityUsers
        .map((person) => AppUser(
              id: person['id'],
              name: person['name'],
              email: person['email'],
              avatar: person['avatar'],
              isOnline: person['isOnline'] ?? false,
            ))
        .toList();

    // Reset selection state
    for (var user in availableUsers) {
      user.isSelected = false;
    }

    // Add search controller for members
    final TextEditingController memberSearchController =
        TextEditingController();
    List<AppUser> filteredUsers = List.from(availableUsers);

    Get.bottomSheet(
      Container(
        height: Get.height * 0.9,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: StatefulBuilder(
          builder: (context, setStateLocal) {
            // Search functionality
            void onSearchChanged(String query) {
              setStateLocal(() {
                if (query.isEmpty) {
                  filteredUsers = List.from(availableUsers);
                } else {
                  filteredUsers = availableUsers.where((user) {
                    final name = user.name.toLowerCase();
                    final email = user.email.toLowerCase();
                    final searchQuery = query.toLowerCase();
                    return name.contains(searchQuery) ||
                        email.contains(searchQuery);
                  }).toList();
                }
              });
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                SizedBox(
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: Text(
                          'New Group',
                          style: semiBoldStyle.copyWith(
                            fontSize: Dimensions.fontSizeLarge,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close,
                                size: 16, color: Colors.white),
                            onPressed: () {
                              memberSearchController.dispose();
                              Get.back();
                            },
                            splashRadius: 16,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Group Name field
                Text(
                  'Group Name',
                  style: semiBoldStyle.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                  ),
                ),

                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        maxLength: 30, // This enforces the maximum length
                        onChanged: (value) {
                          // Update the controller value
                          controller!.groupName.value = value;
                        },
                        decoration: InputDecoration(
                          hintText: 'Enter group name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: CustomColors.purpleColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          counterText: '', // Hide default counter
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Add Member Section
                // Add Member Section
                Text(
                  'Add Member',
                  style: semiBoldStyle.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                  ),
                ),

                const SizedBox(height: 8),

                // Search field for members
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: memberSearchController,
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search members...',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 15,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey[500],
                        size: 20,
                      ),
                      suffixIcon: memberSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Colors.grey[500],
                                size: 20,
                              ),
                              onPressed: () {
                                memberSearchController.clear();
                                onSearchChanged('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Show loading state for users
                if (_isLoadingUsers)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                          color: CustomColors.purpleColor),
                    ),
                  )
                else if (availableUsers.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.people_outline,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          const Text('No users available for group'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loadCommunityUsers,
                            child: const Text('Refresh'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (filteredUsers.isEmpty)
                  // No search results
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.search_off,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          const Text('No members found'),
                          const SizedBox(height: 4),
                          Text(
                            'Try searching with different keywords',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // Members list
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        // Find the original person data
                        final personIndex =
                            availableUsers.indexWhere((u) => u.id == user.id);
                        final person = personIndex >= 0
                            ? communityUsers[personIndex]
                            : null;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 8,
                            ),
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor:
                                      CustomColors.lightPurpleColor,
                                  child: ClipOval(
                                    child: _buildUserImage(
                                      person?['avatar'] ?? user.avatar,
                                      width: 48,
                                      height: 48,
                                    ),
                                  ),
                                ),
                                // Online indicator
                              ],
                            ),
                            title: Text(
                              user.name,
                              style: mediumStyle.copyWith(
                                fontSize: Dimensions.fontSizeLarge,
                                fontWeight: user.isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: user.isSelected
                                    ? CustomColors.purpleColor
                                    : Colors.black,
                              ),
                            ),
                            subtitle: person?['specialty'] != null
                                ? Text(
                                    person!['specialty'],
                                    style: regularStyle.copyWith(
                                      fontSize: Dimensions.fontSizeDefault,
                                      color: Colors.grey[600],
                                    ),
                                  )
                                : null,
                            trailing: Checkbox(
                              value: user.isSelected,
                              onChanged: (value) {
                                setStateLocal(() {
                                  user.isSelected = !user.isSelected;
                                  if (user.isSelected) {
                                    if (!controller!.selectedMembers
                                        .contains(user)) {
                                      controller!.selectedMembers.add(user);
                                    }
                                  } else {
                                    controller!.selectedMembers.remove(user);
                                  }
                                });
                              },
                              activeColor: CustomColors.purpleColor,
                            ),
                            onTap: () {
                              setStateLocal(() {
                                user.isSelected = !user.isSelected;
                                if (user.isSelected) {
                                  if (!controller!.selectedMembers
                                      .contains(user)) {
                                    controller!.selectedMembers.add(user);
                                  }
                                } else {
                                  controller!.selectedMembers.remove(user);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 16),

                // Create Group Button
                Obx(() => ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CustomColors.greenColor,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: controller!.isLoading.value
                          ? null
                          : () {
                              if (controller!.groupName.value.trim().isEmpty) {
                                Get.snackbar(
                                  'Error',
                                  'Please enter a group name',
                                  backgroundColor: Colors.red,
                                  colorText: Colors.white,
                                );
                                return;
                              }
                              if (controller!.selectedMembers.isEmpty) {
                                Get.snackbar(
                                  'Error',
                                  'Please select at least one member',
                                  backgroundColor: Colors.red,
                                  colorText: Colors.white,
                                );
                                return;
                              }
                              memberSearchController.dispose();
                              _createGroupWithUsers();
                            },
                      icon: controller!.isLoading.value
                          ? SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: CustomColors.purpleColor,
                              ),
                            )
                          : Icon(Icons.group_add,
                              color: CustomColors.darkGreenColor),
                      label: Text(
                        controller!.isLoading.value
                            ? "Creating..."
                            : "Create Group",
                        style: boldStyle.copyWith(
                          fontSize: Dimensions.fontSizeExtraLarge,
                          color: CustomColors.darkGreenColor,
                        ),
                      ),
                    )),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildUserImage(String? imageUrl,
      {double width = 48, double height = 48}) {
    print('🖼️ Building user image with URL: $imageUrl');

    // Handle different image URL formats
    if (imageUrl != null && imageUrl.isNotEmpty) {
      // Check if it's a network URL (HTTP or HTTPS)
      if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
        print('🌐 Loading network image: $imageUrl');
        return Image.network(
          imageUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              print('✅ Network image loaded successfully');
              return child;
            }
            return Container(
              width: width,
              height: height,
              color: Colors.grey[200],
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: CustomColors.purpleColor,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('❌ Error loading network image: $imageUrl - $error');
            return Image.asset(
              CustomImage.avator,
              width: width,
              height: height,
              fit: BoxFit.cover,
            );
          },
        );
      }

      // Check if it's a base64 data URI
      else if (imageUrl.startsWith('data:image/')) {
        print('📷 Loading base64 image');
        try {
          final parts = imageUrl.split(',');
          if (parts.length == 2) {
            final base64Data = parts[1];
            final imageBytes = base64Decode(base64Data);
            return Image.memory(
              imageBytes,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                print('❌ Error loading base64 image: $error');
                return Image.asset(
                  CustomImage.avator,
                  width: width,
                  height: height,
                  fit: BoxFit.cover,
                );
              },
            );
          }
        } catch (e) {
          print('❌ Error decoding base64 image: $e');
        }
      }

      // Try to load as asset if it's not a URL
      else {
        print('📁 Loading asset image: $imageUrl');
        return Image.asset(
          imageUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('❌ Error loading asset image: $imageUrl - $error');
            return Image.asset(
              CustomImage.avator,
              width: width,
              height: height,
              fit: BoxFit.cover,
            );
          },
        );
      }
    }

    // Default avatar if no imageUrl provided
    print('📁 Using default avatar');
    return Image.asset(
      CustomImage.avator,
      width: width,
      height: height,
      fit: BoxFit.cover,
    );
  }
}
