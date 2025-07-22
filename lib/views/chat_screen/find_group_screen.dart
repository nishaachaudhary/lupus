import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/images.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/data/api/auth_service.dart';
import 'package:lupus_care/helper/storage_service.dart';
import 'package:lupus_care/views/group_chat/group_info_screen.dart';

class FindGroupScreen extends StatefulWidget {
  final List<Map<String, dynamic>> availableGroups;
  final Function() onRefreshGroups;
  final Function(Map<String, dynamic>) onJoinGroup;
  final Function(Map<String, dynamic>) onOpenGroupChat;

  const FindGroupScreen({
    Key? key,
    required this.availableGroups,
    required this.onRefreshGroups,
    required this.onJoinGroup,
    required this.onOpenGroupChat,
  }) : super(key: key);

  @override
  State<FindGroupScreen> createState() => _FindGroupScreenState();
}

class _FindGroupScreenState extends State<FindGroupScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _filteredGroups = [];
  bool _isSearching = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _filteredGroups = List.from(widget.availableGroups);
    _searchController.addListener(_onSearchChanged);

    // Load groups if empty
    if (_filteredGroups.isEmpty) {
      _loadGroups();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      _isSearching = query.isNotEmpty;

      if (query.isEmpty) {
        _filteredGroups = List.from(widget.availableGroups);
      } else {
        _filteredGroups = widget.availableGroups.where((group) {
          final name = group['name']?.toString().toLowerCase() ?? '';
          final description = group['description']?.toString().toLowerCase() ?? '';

          return name.contains(query) || description.contains(query);
        }).toList();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _filteredGroups = List.from(widget.availableGroups);
    });
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
    });

    try {
      widget.onRefreshGroups();
      // Wait for parent to update
      await Future.delayed(Duration(milliseconds: 1000));
      setState(() {
        _filteredGroups = List.from(widget.availableGroups);
      });
    } catch (e) {
      print('❌ Error loading groups: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _joinGroup(Map<String, dynamic> group) async {
    try {
      final userData = StorageService.to.getUser();
      if (userData == null) {
        Get.snackbar('Error', 'User not logged in');
        return;
      }

      final userId = userData['id']?.toString() ?? '';
      final groupId = group['id']?.toString() ?? '';

      if (userId.isEmpty || groupId.isEmpty) {
        Get.snackbar('Error', 'Invalid user or group data');
        return;
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
                SizedBox(height: 16),
                Text('Joining ${group['name']}...'),
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );

      print('🔗 Joining group: ${group['name']} (${groupId})');

      final response = await _authService.joinGroup(
        userId: userId,
        groupId: groupId,
      );

      Get.back(); // Close loading dialog

      if (response['status'] == 'success') {
        // Update local group data
        setState(() {
          final groupIndex = _filteredGroups.indexWhere((g) => g['id'] == groupId);
          if (groupIndex >= 0) {
            _filteredGroups[groupIndex]['isJoined'] = true;
            // Increment member count
            final currentCount = int.tryParse(_filteredGroups[groupIndex]['memberCount'] ?? '0') ?? 0;
            _filteredGroups[groupIndex]['memberCount'] = (currentCount + 1).toString();
          }
        });

        Get.snackbar(
          'Success',
          'Successfully joined ${group['name']}!',
          backgroundColor: Colors.green,
          colorText: Colors.white,

        );

        // Call parent's join group method
        widget.onJoinGroup(group);

      } else {
        Get.snackbar(
          'Error',
          response['message'] ?? 'Failed to join group',
          backgroundColor: Colors.red,
          colorText: Colors.white,

        );
      }

    } catch (e) {
      Get.back(); // Close loading dialog if still open
      print('❌ Error joining group: $e');
      Get.snackbar(
        'Error',
        'Failed to join group: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,

      );
    }
  }

  void _openGroupChat(Map<String, dynamic> group) {
    // Navigate back first
    Get.back();
    // Then open group chat
    widget.onOpenGroupChat(group);
  }

  void _showGroupPreview(Map<String, dynamic> group) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: CustomColors.lightPurpleColor,
              child: group['image'] != null && group['image'].isNotEmpty
                  ? ClipOval(
                child: _buildGroupImage(
                  group['image'],
                  width: 40,
                  height: 40,
                ),
              )
                  : Icon(Icons.group, color: CustomColors.purpleColor),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                group['name'],
                style: semiBoldStyle.copyWith(fontSize: Dimensions.fontSizeLarge),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (group['description'] != null && group['description'].isNotEmpty)
              Text(
                group['description'],
                style: regularStyle.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                  color: Colors.grey[700],
                ),
              ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.people, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text('${group['memberCount']} members'),
              ],
            ),
            if (group['isPublic'] == true) ...[
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.public, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Text('Public Group'),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _joinGroup(group);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: CustomColors.purpleColor,
            ),
            child: Text('Join Group', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupImage(String? imageUrl, {double width = 48, double height = 48}) {
    if (imageUrl != null && (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
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
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.group,
            size: width * 0.6,
            color: CustomColors.purpleColor,
          );
        },
      );
    }

    return Icon(
      Icons.group,
      size: width * 0.6,
      color: CustomColors.purpleColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(),
        ),
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Search groups',
              hintStyle: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.grey[500],
                size: 20,
              ),
              suffixIcon: _isSearching
                  ? IconButton(
                icon: Icon(
                  Icons.clear,
                  color: Colors.grey[500],
                  size: 20,
                ),
                onPressed: _clearSearch,
              )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            style: TextStyle(
              fontSize: 16,
              color: Colors.black,
            ),
          ),
        ),
        titleSpacing: 0,

      ),
      body: Column(
        children: [
          // Search results info
          if (_isSearching && _filteredGroups.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${_filteredGroups.length} group${_filteredGroups.length != 1 ? 's' : ''} found',
                    style: regularStyle.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

          // Groups list
          Expanded(
            child: _isLoading
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: CustomColors.purpleColor),
                  SizedBox(height: 16),
                  Text('Loading groups...'),
                ],
              ),
            )
                : _filteredGroups.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredGroups.length,
              itemBuilder: (context, index) {
                final group = _filteredGroups[index];
                return _buildGroupTile(group);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTile(Map<String, dynamic> group) {
    final isJoined = group['isJoined'] == true;
    final memberCount = group['memberCount']?.toString() ?? '0';

    return Container(
      margin: EdgeInsets.only(bottom: 1),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: CustomColors.lightPurpleColor,
              child: group['image'] != null && group['image'].isNotEmpty
                  ? ClipOval(
                child: _buildGroupImage(
                  group['image'],
                  width: 48,
                  height: 48,
                ),
              )
                  : Icon(
                Icons.group,
                color: CustomColors.purpleColor,
                size: 28,
              ),
            ),
            // Joined indicator
            if (isJoined)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 8,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          group['name'] ?? 'Unknown Group',
          style: semiBoldStyle.copyWith(
            fontSize: 17,
            color: isJoined ? Colors.green[700] : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (group['description'] != null && group['description'].toString().isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text(
                  group['description'],
                  style: regularStyle.copyWith(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.people, size: 14, color: Colors.grey[500]),
                  SizedBox(width: 4),
                  Text(
                    '$memberCount members',
                    style: regularStyle.copyWith(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                  if (group['isPublic'] == true) ...[
                    SizedBox(width: 8),
                    Icon(Icons.public, size: 14, color: Colors.grey[500]),
                    SizedBox(width: 4),
                    Text(
                      'Public',
                      style: regularStyle.copyWith(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        trailing: isJoined
            ? Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Joined',
            style: mediumStyle.copyWith(
              fontSize: 12,
              color: Colors.green[700],
            ),
          ),
        )
            : TextButton(
          onPressed: () => _joinGroup(group),
          style: TextButton.styleFrom(
            backgroundColor: CustomColors.purpleColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(
            'Join',
            style: mediumStyle.copyWith(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ),
        onTap: isJoined
            ? () => _openGroupChat(group)
            : () => _showGroupPreview(group),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_isSearching) {
      // No search results
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No groups found',
              style: mediumStyle.copyWith(
                fontSize: Dimensions.fontSizeLarge,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try searching with different keywords',
              style: regularStyle.copyWith(
                fontSize: Dimensions.fontSizeDefault,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      // No groups available
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No groups available',
              style: mediumStyle.copyWith(
                fontSize: Dimensions.fontSizeLarge,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Check back later for new groups',
              style: regularStyle.copyWith(
                fontSize: Dimensions.fontSizeDefault,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGroups,
              style: ElevatedButton.styleFrom(
                backgroundColor: CustomColors.purpleColor,
              ),
              child: Text('Refresh Groups', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }
}