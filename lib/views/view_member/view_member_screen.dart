import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/images.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/view_member/group_member_widgets.dart';
import 'package:lupus_care/views/view_member/view_member_controller.dart';
import 'package:lupus_care/data/api/auth_service.dart';
import 'package:lupus_care/helper/storage_service.dart';

class ViewMembersScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final Map<String, dynamic>? groupData;

  const ViewMembersScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
    this.groupData,
  }) : super(key: key);

  @override
  _ViewMembersScreenState createState() => _ViewMembersScreenState();
}

class _ViewMembersScreenState extends State<ViewMembersScreen> {
  late ViewMembersController controller;
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> membersList = [];
  List<Map<String, dynamic>> filteredMembersList = [];
  bool isLoading = true;
  String? error;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    print("🏗️ ViewMembersScreen initState:");
    print("   Group ID: ${widget.groupId}");
    print("   Group Name: ${widget.groupName}");

    controller = ViewMembersController();
    controller.init(groupId: widget.groupId);

    // Load members immediately
    _loadMembers();

    // Setup search listener
    searchController.addListener(_filterMembers);

    print("✅ ViewMembersScreen initialization complete");
  }

  @override
  void dispose() {
    controller.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      print("🔄 Loading members for group: ${widget.groupId}");

      // Step 1: Get Firebase group participants
      final doc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.groupId)
          .get();

      if (!doc.exists || doc.data() == null) {
        throw Exception('Group document not found');
      }

      final data = doc.data()!;
      final participants = List<String>.from(data['participants'] ?? []);

      print("✅ Found ${participants.length} participants from Firebase: $participants");

      if (participants.isEmpty) {
        setState(() {
          membersList = [];
          filteredMembersList = [];
          isLoading = false;
        });
        return;
      }

      // Step 2: Get user data from your backend API
      List<Map<String, dynamic>> loadedMembers = [];

      // Get current user ID for API call
      final userData = StorageService.to.getUser();
      final currentUserId = userData?['id']?.toString();

      if (currentUserId == null) {
        throw Exception('Current user ID not found. Please log in again.');
      }

      print("👤 Current user ID: $currentUserId");

      // Call your API to get all users
      final apiResponse = await _authService.getAllUsers(userId: currentUserId);

      print("📥 API Response: ${apiResponse['status']}");

      if (apiResponse['status'] == 'success' && apiResponse['data'] != null) {
        final allUsers = List<Map<String, dynamic>>.from(apiResponse['data']);
        print("👥 Got ${allUsers.length} users from API");

        // Step 3: Match Firebase participants with API users
        for (String participantId in participants) {
          print("🔍 Processing participant: $participantId");

          // Extract the actual user ID from participant ID
          // Participant IDs might be in format 'app_user_123' or just '123'
          String actualUserId = participantId;
          if (participantId.startsWith('app_user_')) {
            actualUserId = participantId.replaceFirst('app_user_', '');
          }

          print("   Extracted user ID: $actualUserId");

          // Find matching user in API data
          Map<String, dynamic>? matchedUser = allUsers.cast<Map<String, dynamic>?>().firstWhere(
                (user) {
              final userId = user?['id']?.toString();
              final userIdAlt = user?['user_id']?.toString();
              return userId == actualUserId || userIdAlt == actualUserId;
            },
            orElse: () => null,
          );

          Map<String, dynamic> memberData;

          if (matchedUser != null) {
            // User found in API - use their data
            memberData = {
              'id': participantId, // Keep original participant ID
              'user_id': actualUserId,
              'name': matchedUser['name'] ??
                  matchedUser['full_name'] ??
                  matchedUser['email'] ??
                  'User $actualUserId',
              'email': matchedUser['email'] ?? matchedUser['unique_username'] ?? '',
              'photoUrl': matchedUser['profile_image'] ?? // This is the correct field from your API
                  matchedUser['avatar'] ??
                  matchedUser['profile_picture'] ??
                  matchedUser['photo_url'] ?? '',
              'provider': matchedUser['provider'] ?? 'unknown',
              'isCurrentUser': actualUserId == currentUserId,
              'role': 'Member', // Default role, could be enhanced
            };

            print("✅ Found user in API: ${memberData['name']} (${memberData['email']})");
          } else {
            // User not found in API - create minimal data
            memberData = {
              'id': participantId,
              'user_id': actualUserId,
              'name': 'User $actualUserId',
              'email': '',
              'photoUrl': '',
              'provider': 'unknown',
              'isCurrentUser': actualUserId == currentUserId,
              'role': 'Member',
            };

            print("⚠️ User not found in API, using minimal data: $actualUserId");
          }

          loadedMembers.add(memberData);
        }

        // Sort members: current user first, then alphabetically
        loadedMembers.sort((a, b) {
          if (a['isCurrentUser'] == true && b['isCurrentUser'] != true) {
            return -1;
          } else if (b['isCurrentUser'] == true && a['isCurrentUser'] != true) {
            return 1;
          } else {
            return (a['name'] as String).compareTo(b['name'] as String);
          }
        });

        setState(() {
          membersList = loadedMembers;
          filteredMembersList = List.from(loadedMembers);
          isLoading = false;
        });

        print("✅ Successfully loaded ${loadedMembers.length} members with proper data");

      } else {
        throw Exception(apiResponse['message'] ?? 'Failed to load users from API');
      }

    } catch (e) {
      print("❌ Error loading members: $e");
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  void _filterMembers() {
    final query = searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredMembersList = List.from(membersList);
      } else {
        filteredMembersList = membersList.where((member) {
          final name = member['name'].toString().toLowerCase();
          final email = member['email'].toString().toLowerCase();
          return name.contains(query) || email.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Container(
          width: 31,
          height: 51,
          margin: const EdgeInsets.only(
            left: Dimensions.fontSizeLarge,
            top: Dimensions.fontSizeExtraSmall,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(width: 1, color: Colors.grey.shade300),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
            splashRadius: 20,
          ),
        ),
        centerTitle: true,
        title: Text(
          "View Members",
          style: mediumStyle.copyWith(fontSize: 18),
        ),
      ),
      body: Column(
        children: [


          // Search Bar
          Container(
            margin: EdgeInsets.only(left: 16, right: 16, top: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(50),
            ),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search members...',
                hintStyle: regularStyle.copyWith(
                  fontSize: 16,
                  color: Color(0xFFA1A1A1),
                ),
                prefixIcon: Icon(Icons.search, color: CustomColors.buttonGrey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12.0),
              ),
            ),
          ),

          // Members List
          Expanded(
            child: _buildMembersContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersContent() {
    // Loading State
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),

          ],
        ),
      );
    }

    // Error State
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              'Error loading members',
              style: mediumStyle.copyWith(
                fontSize: 18,
                color: Colors.red[600],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red[500],
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadMembers,
              child: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        ),
      );
    }

    // Empty State
    if (filteredMembersList.isEmpty && membersList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No members found',
              style: mediumStyle.copyWith(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This group appears to be empty.',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadMembers,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    // No search results
    if (filteredMembersList.isEmpty && searchController.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No matching members',
              style: mediumStyle.copyWith(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term.',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
    }

    // SUCCESS: Members List
    return Column(
      children: [

        Expanded(
          child: ListView.builder(
            itemCount: filteredMembersList.length,
            itemBuilder: (context, index) {
              final member = filteredMembersList[index];

              return Container(
                // margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),

                child: ListTile(
                  contentPadding: EdgeInsets.only(left: 16,top: 8,right: 16),
                  leading: _buildMemberAvatar(member),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          member['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),

                    ],
                  ),


                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMemberAvatar(Map<String, dynamic> member) {
    final isCurrentUser = member['isCurrentUser'] == true;
    final photoUrl = member['photoUrl']?.toString() ?? '';
    final name = member['name']?.toString() ?? '';
    final hasValidUrl = photoUrl.isNotEmpty && (photoUrl.startsWith('http') || photoUrl.startsWith('https'));

    print('🖼️ Building avatar for ${member['name']}');
    print('   Photo URL: $photoUrl');
    print('   URL valid: $hasValidUrl');

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCurrentUser
            ? CustomColors.purpleColor.withOpacity(0.2)
            : Colors.blue[100],
      ),
      child: hasValidUrl
          ? ClipOval(
        child: Image.network(
          photoUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('❌ Error loading network image for ${member['name']}: $error');
            // Fallback to default asset image on network error
            return ClipOval(
              child: Image.asset(
                CustomImage.avator,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
              ),
            );
          },
        ),
      )
          : ClipOval(
        child: Image.asset(
          CustomImage.avator,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

}