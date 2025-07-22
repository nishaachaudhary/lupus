import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lupus_care/data/model/add_user_model.dart';
import 'package:lupus_care/data/api/auth_service.dart';
import 'package:lupus_care/helper/storage_service.dart';
import 'package:lupus_care/views/chat_screen/chat_controller.dart';
import 'package:lupus_care/constant/images.dart';

class AddMembersController extends ChangeNotifier {
  final List<AddUser> _users = [];
  List<AddUser> filteredUsers = [];
  final TextEditingController searchController = TextEditingController();
  final AuthService _authService = AuthService();

  bool isLoading = false;
  bool isAddingMembers = false;
  String? error;
  String? groupId;
  String? groupName;

  List<AddUser> get users => _users;

  void init() {
    print("🚀 AddMembersController.init() called");

    // Get group data from route arguments
    final arguments = Get.arguments as Map<String, dynamic>?;
    if (arguments != null) {
      groupId = arguments['groupId']?.toString();
      groupName = arguments['groupName']?.toString();

      print("📋 Group ID: '$groupId'");
      print("📋 Group Name: '$groupName'");
    }

    // Set up listener for search field
    searchController.addListener(_filterUsers);

    // Load all available users
    loadUsers();
  }

  void _filterUsers() {
    String searchTerm = searchController.text.toLowerCase();
    filteredUsers = _users.where((user) =>
        user.name.toLowerCase().contains(searchTerm)
    ).toList();

    // Notify listeners about the change
    notifyListeners();
  }

  // Load users from API
  Future<void> loadUsers() async {
    print("🔄 ============ LOADING USERS START ============");

    if (isLoading) {
      print("⚠️ Already loading users, skipping...");
      return;
    }

    try {
      isLoading = true;
      error = null;
      notifyListeners();
      print("✅ Set loading=true, error=null");

      // Get current user data
      final userData = StorageService.to.getUser();
      final currentUserId = userData?['id']?.toString() ?? '';

      if (currentUserId.isEmpty) {
        throw Exception('No current user ID available');
      }

      print("👤 Current user ID: $currentUserId");
      print("📞 Calling _authService.getAllUsers(userId: $currentUserId)");

      // Get all users from API
      final response = await _authService.getAllUsers(userId: currentUserId);

      print("📥 ============ GET ALL USERS API RESPONSE DEBUG ============");
      print("📥 Response type: ${response.runtimeType}");
      print("📥 Response keys: ${response.keys.toList()}");
      print("📥 Response status: ${response['status']}");
      print("📥 Response message: ${response['message']}");
      print("📥 Full response: $response");
      print("📥 ========================================================");

      if (response['status'] == 'success') {
        print("✅ API returned success status");
        _users.clear();
        print("🧹 Cleared existing users list");

        // Extract users data
        var usersData = response['data'] ?? response['users'] ?? [];

        print("📊 Users data type: ${usersData.runtimeType}");
        print("📊 Users data is List: ${usersData is List}");

        if (usersData is List) {
          print("📊 Found ${usersData.length} users to process");

          // Get current group members to exclude them
          List<String> currentGroupMembers = [];
          if (groupId != null) {
            currentGroupMembers = await _getCurrentGroupMembers(groupId!);
            print("📊 Current group has ${currentGroupMembers.length} members: $currentGroupMembers");
          }

          // Process each user
          for (int index = 0; index < usersData.length; index++) {
            var userData = usersData[index];
            print("🔧 Processing user $index:");
            print("🔧   Type: ${userData.runtimeType}");
            print("🔧   Content: $userData");

            if (userData is Map<String, dynamic>) {
              print("🔧   Keys available: ${userData.keys.toList()}");

              try {
                final userId = userData['id']?.toString() ??
                    userData['user_id']?.toString() ??
                    index.toString();

                final userName = userData['full_name']?.toString() ??
                    userData['name']?.toString() ??
                    userData['username']?.toString() ??
                    userData['first_name']?.toString() ??
                    'User ${index + 1}';

                // Skip current user and existing group members
                if (userId == currentUserId) {
                  print("⏭️ Skipping current user: $userName");
                  continue;
                }

                if (currentGroupMembers.contains(userId)) {
                  print("⏭️ Skipping existing group member: $userName");
                  continue;
                }

                final user = AddUser(
                  id: userId,
                  name: userName,
                  avatarUrl: userData['profile_image']?.toString() ??
                      userData['avatar']?.toString() ??
                      userData['image']?.toString() ??
                      userData['profile_pic']?.toString() ??
                      CustomImage.avator,

                  isSelected: false, // Start with no users selected
                );

                _users.add(user);
                print("✅ Added user: ${user.name} (ID: ${user.id})");

                print("✅   Avatar: ${user.avatarUrl}");

              } catch (e) {
                print("❌ Error processing user $index: $e");
                print("❌ User data was: $userData");
              }
            } else {
              print("⚠️ User $index is not a Map, skipping: $userData");
            }
          }
        } else {
          print("⚠️ Users data is not a List: $usersData");
        }

        // Initialize filtered list with all users
        filteredUsers = List.from(_users);
        print("✅ Created filtered list with ${filteredUsers.length} users");

        print("✅ ============ FINAL RESULTS ============");
        print("✅ Total users loaded: ${_users.length}");
        print("✅ Filtered users: ${filteredUsers.length}");

        if (_users.isNotEmpty) {
          print("✅ Sample users:");
          for (int i = 0; i < _users.length && i < 3; i++) {
            final user = _users[i];
            print("✅   [$i] ${user.name} (${user.id})");
          }
        } else {
          print("⚠️ No users found in the API response");
          error = "No users available to add";
        }
        print("✅ ====================================");

      } else {
        print("❌ ============ API ERROR ============");
        error = response['message'] ?? 'Failed to load users';
        print("❌ API returned error status: ${response['status']}");
        print("❌ Error message: $error");
        print("❌ Full response: $response");
        print("❌ ================================");
      }
    } catch (e) {
      print("❌ ============ EXCEPTION CAUGHT ============");
      error = 'Network error: $e';
      print("❌ Exception type: ${e.runtimeType}");
      print("❌ Exception message: $e");
      print("❌ Stack trace: ${StackTrace.current}");
      print("❌ ======================================");
    } finally {
      isLoading = false;
      notifyListeners();

      print("🏁 ============ LOAD USERS COMPLETE ============");
      print("🏁 Final state:");
      print("🏁   isLoading: $isLoading");
      print("🏁   error: $error");
      print("🏁   users count: ${_users.length}");
      print("🏁   filtered users count: ${filteredUsers.length}");
      print("🏁 ==========================================");
    }
  }

  // Get current group members from Firebase
  Future<List<String>> _getCurrentGroupMembers(String groupId) async {
    try {
      print("🔍 Getting current group members for: $groupId");

      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .get();

      if (chatDoc.exists) {
        final data = chatDoc.data()!;
        final participants = List<String>.from(data['participants'] ?? []);
        print("✅ Found ${participants.length} current members: $participants");
        return participants;
      } else {
        print("⚠️ Group document not found: $groupId");
        return [];
      }
    } catch (e) {
      print("❌ Error getting current group members: $e");
      return [];
    }
  }

  void toggleUserSelection(AddUser user) {
    final index = _users.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      _users[index].isSelected = !_users[index].isSelected;

      // Update the filtered list as well
      final filteredIndex = filteredUsers.indexWhere((u) => u.id == user.id);
      if (filteredIndex != -1) {
        filteredUsers[filteredIndex].isSelected = _users[index].isSelected;
      }

      print("👤 Toggled selection for ${user.name}: ${_users[index].isSelected}");

      // Notify listeners about the change
      notifyListeners();
    }
  }

  List<AddUser> getSelectedUsers() {
    final selected = _users.where((user) => user.isSelected).toList();
    print("📊 ${selected.length} users currently selected");
    return selected;
  }

  Future<void> addMembers(BuildContext context) async {
    final selectedUsers = getSelectedUsers();

    if (selectedUsers.isEmpty) {
      Get.snackbar(
        'No Users Selected',
        'Please select at least one user to add to the group.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    if (groupId == null || groupId!.isEmpty) {
      Get.snackbar(
        'Error',
        'Group information not available.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    print("🔄 ============ ADDING MEMBERS START ============");
    print("👥 Adding ${selectedUsers.length} members to group: $groupId");
    for (var user in selectedUsers) {
      print("   - ${user.name} (${user.id})");
    }

    try {
      isAddingMembers = true;
      notifyListeners();

      // Get current user data for creating user documents
      final currentUserData = StorageService.to.getUser();
      final currentUserId = currentUserData?['id']?.toString() ?? '';

      // Add each selected user to the Firebase group
      for (var user in selectedUsers) {
        await _addUserToFirebaseGroup(user);
      }

      // Update ChatController if available
      if (Get.isRegistered<ChatController>()) {
        final chatController = Get.find<ChatController>();
        await chatController.refreshChats();
        print("✅ Refreshed ChatController");
      }

      print("✅ ============ ADDING MEMBERS COMPLETE ============");

      // Reset the adding state first
      isAddingMembers = false;
      notifyListeners();

      // Show success message
      Get.snackbar(
        'Success',
        '${selectedUsers.length} member${selectedUsers.length > 1 ? 's' : ''} added to $groupName successfully!',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,

      );

      // Use a longer delay to ensure UI updates complete
      await Future.delayed(Duration(milliseconds: 1000));

      // Try multiple navigation approaches
      try {
        print("🔄 Attempting navigation back...");

        // Method 1: Standard Get.back()
        if (Get.routing.current != '/') {
          Get.back();
          print("✅ Navigation attempted with Get.back()");

          // Wait and check if navigation worked
          await Future.delayed(Duration(milliseconds: 500));
          print("📍 Current route after Get.back(): ${Get.routing.current}");
        }

        // Method 2: If still on same screen, try Navigator.pop()
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          print("✅ Fallback navigation with Navigator.pop()");
        }

        // Method 3: Last resort - replace current screen
        // Uncomment if above methods don't work:
        // Get.offNamed('/previous_screen_route');

      } catch (e) {
        print("❌ All navigation methods failed: $e");
        // Force navigation by replacing the route stack
        Navigator.of(context).popUntil((route) => route.isFirst);
      }

    } catch (e) {
      print("❌ Error adding members: $e");
      Get.snackbar(
        'Error',
        'Failed to add members: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      // Ensure the loading state is always reset
      if (isAddingMembers) {
        isAddingMembers = false;
        notifyListeners();
      }
    }
  }

  // Add a user to Firebase group
  Future<void> _addUserToFirebaseGroup(AddUser user) async {
    try {
      print("👤 Adding ${user.name} to Firebase group...");

      // First, ensure the user document exists in Firestore
      await _ensureUserDocumentExists(user);

      // Add user to the group's participants
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId!)
          .update({
        'participants': FieldValue.arrayUnion([user.id]),
        'participantDetails.${user.id}': {
          'id': user.id,
          'name': user.name,
          'avatar': user.avatarUrl,
          'isOnline': true, // Default to online

        },
        'unreadCounts.${user.id}': 0,
      });

      // Add a system message about the new member (single line format)
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId!)
          .collection('messages')
          .add({
        'senderId': 'system',
        'senderName': 'System',
        'text': '${user.name} joined the group',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'system',
      });

      // Update the group's last message
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId!)
          .update({
        'lastMessage': '${user.name} joined the group',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSender': 'system',
      });

      print("✅ Successfully added ${user.name} to Firebase group");

    } catch (e) {
      print("❌ Error adding ${user.name} to Firebase group: $e");
      rethrow;
    }
  }

  // Ensure user document exists in Firestore
  Future<void> _ensureUserDocumentExists(AddUser user) async {
    try {
      print("📝 Ensuring user document exists for: ${user.name}");

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .set({
        'id': user.id,
        'name': user.name,
        'avatar': user.avatarUrl,
        'isOnline': true,
        'isAppUser': true,
        'appUserId': user.id,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        'joinedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print("✅ User document created/updated for: ${user.name}");
    } catch (e) {
      print("❌ Error ensuring user document: $e");
    }
  }

  // Refresh users list
  Future<void> refreshUsers() async {
    print("🔄 Refreshing users list...");
    await loadUsers();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}