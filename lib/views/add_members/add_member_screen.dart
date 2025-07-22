import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/images.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/add_members/add_member_controller.dart';

class AddMembersScreen extends StatefulWidget {
  const AddMembersScreen({Key? key}) : super(key: key);

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  late AddMembersController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AddMembersController();
    _controller.init();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
          height: 31,
          margin: const EdgeInsets.only(left: Dimensions.fontSizeLarge, top: Dimensions.fontSizeExtraSmall),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(width: 1, color: Colors.grey.shade300),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
            onPressed: () => Get.back(),
            splashRadius: 20,
          ),
        ),
        centerTitle: true,
        title: Text(
          "Add Members",
          style: mediumStyle.copyWith(fontSize: 20),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: 24),

              // Search Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: TextField(
                    controller: _controller.searchController,
                    enabled: !_controller.isLoading && !_controller.isAddingMembers,
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: regularStyle.copyWith(
                        fontSize: 20,
                        color: Color(0xFFA1A1A1),
                      ),
                      prefixIcon: Icon(Icons.search, color: CustomColors.buttonGrey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12.0),
                    ),
                  ),
                ),
              ),

              // Content Area
              Expanded(
                child: _buildContent(),
              ),

              // Add Member Button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _controller.isAddingMembers || _controller.isLoading || _controller.getSelectedUsers().isEmpty
                        ? null
                        : () => _controller.addMembers(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CustomColors.purpleColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                    ),
                    child: _controller.isAddingMembers
                        ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Text(
                      _controller.getSelectedUsers().isEmpty
                          ? 'Add Member'
                          : 'Add ${_controller.getSelectedUsers().length} Member${_controller.getSelectedUsers().length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 50,)
            ],
          ),

          // Full screen overlay when adding members
          if (_controller.isAddingMembers)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(CustomColors.purpleColor),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Adding members...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Please wait',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // Loading State (only for initial loading, not for adding members)
    if (_controller.isLoading && !_controller.isAddingMembers) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading users...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // Error State
    if (_controller.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'Error loading users',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _controller.error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _controller.refreshUsers();
              },
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Empty State
    if (_controller.filteredUsers.isEmpty) {
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
              _controller.searchController.text.isNotEmpty
                  ? 'No matching users'
                  : 'No users available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              _controller.searchController.text.isNotEmpty
                  ? 'Try a different search term.'
                  : 'All available users are already in this group.',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
            if (_controller.searchController.text.isEmpty) ...[
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  _controller.refreshUsers();
                },
                child: Text('Refresh'),
              ),
            ],
          ],
        ),
      );
    }

    // User List - Show with opacity when adding members
    return Opacity(
      opacity: _controller.isAddingMembers ? 0.5 : 1.0,
      child: ListView.builder(
        physics: _controller.isAddingMembers ? NeverScrollableScrollPhysics() : null,
        itemCount: _controller.filteredUsers.length,
        itemBuilder: (context, index) {
          final user = _controller.filteredUsers[index];
          return Container(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: user.isSelected ? CustomColors.purpleColor.withOpacity(0.1) : null,
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: user.avatarUrl.isNotEmpty && !user.avatarUrl.startsWith('assets/')
                    ? NetworkImage(user.avatarUrl)
                    : null,
                child: user.avatarUrl.isEmpty || user.avatarUrl.startsWith('assets/')
                    ? Image.asset(
                  CustomImage.avator,
                  fit: BoxFit.contain,
                )
                    : null,
              ),
              title: Text(
                user.name,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: user.isSelected ? CustomColors.purpleColor : Colors.black,
                ),
              ),
              trailing: GestureDetector(
                onTap: _controller.isAddingMembers ? null : () => _controller.toggleUserSelection(user),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: user.isSelected ? CustomColors.purpleColor : Colors.transparent,
                    border: user.isSelected
                        ? null
                        : Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: user.isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              ),
              onTap: _controller.isAddingMembers ? null : () => _controller.toggleUserSelection(user),
            ),
          );
        },
      ),
    );
  }
}