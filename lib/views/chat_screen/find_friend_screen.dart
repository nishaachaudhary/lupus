import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/images.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/chat_screen/chat_controller.dart';
import 'package:lupus_care/views/chat_screen/personal_chat_screen.dart';
import 'package:lupus_care/views/chat_screen/firebase/firebase_model.dart';

class FindFriendScreen extends StatefulWidget {
  final List<Map<String, dynamic>> communityUsers;
  final Function(Map<String, dynamic>) onChatWithUser;

  const FindFriendScreen({
    Key? key,
    required this.communityUsers,
    required this.onChatWithUser,
  }) : super(key: key);

  @override
  State<FindFriendScreen> createState() => _FindFriendScreenState();
}

class _FindFriendScreenState extends State<FindFriendScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _filteredUsers = List.from(widget.communityUsers);
    _searchController.addListener(_onSearchChanged);
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
        _filteredUsers = List.from(widget.communityUsers);
      } else {
        _filteredUsers = widget.communityUsers.where((user) {
          final name = user['name']?.toString().toLowerCase() ?? '';
          final email = user['email']?.toString().toLowerCase() ?? '';
          final specialty = user['specialty']?.toString().toLowerCase() ?? '';

          return name.contains(query) ||
              email.contains(query) ||
              specialty.contains(query);
        }).toList();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _filteredUsers = List.from(widget.communityUsers);
    });
  }

  Widget _buildUserImage(String? imageUrl, {double width = 48, double height = 48}) {
    // Check if imageUrl is a network URL
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
          return Image.asset(
            CustomImage.avator,
            width: width,
            height: height,
            fit: BoxFit.cover,
          );
        },
      );
    }

    // If not a network URL, treat as asset or use default
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.asset(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            CustomImage.avator,
            width: width,
            height: height,
            fit: BoxFit.cover,
          );
        },
      );
    }

    // Default avatar
    return Image.asset(
      CustomImage.avator,
      width: width,
      height: height,
      fit: BoxFit.cover,
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
              hintText: 'Search',
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
          // Search results info (optional)
          if (_isSearching && _filteredUsers.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${_filteredUsers.length} result${_filteredUsers.length != 1 ? 's' : ''} found',
                    style: regularStyle.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

          // Users list
          Expanded(
            child: _filteredUsers.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredUsers.length,
              itemBuilder: (context, index) {
                final user = _filteredUsers[index];
                return _buildUserTile(user);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    return Container(
      margin: EdgeInsets.only(bottom: 1),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: CustomColors.lightPurpleColor,
              child: ClipOval(
                child: _buildUserImage(
                  user['avatar'],
                  width: 48,
                  height: 48,
                ),
              ),
            ),
            // Online indicator
            if (user['isOnline'] == true)
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
                ),
              ),
          ],
        ),
        title: Text(
          user['name'] ?? 'Unknown User',
          style: semiBoldStyle.copyWith(
            fontSize: 17,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: user['specialty'] != null && user['specialty'].toString().isNotEmpty
            ? Text(
          user['specialty'],
          style: regularStyle.copyWith(
            fontSize: 15,
            color: Colors.grey[600],
          ),
        )
            : null,
        onTap: () {
          // Navigate back and open chat
          Get.back();
          widget.onChatWithUser(user);
        },
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
              'No results found',
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
      // No users available
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No community members found',
              style: mediumStyle.copyWith(
                fontSize: Dimensions.fontSizeLarge,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Check back later for new members',
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
  }
}