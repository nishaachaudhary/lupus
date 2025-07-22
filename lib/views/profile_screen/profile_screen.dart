import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/icons.dart';
import 'package:lupus_care/constant/images.dart';
import 'package:lupus_care/data/api/auth_service.dart';
import 'package:lupus_care/helper/storage_service.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/profile_screen/profile_controller.dart';
import 'package:lupus_care/views/profile_screen/delete_confirm_dialog.dart';
import 'package:lupus_care/views/profile_screen/logout_confirm_dialog.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Use ProfileController
  final ProfileController controller = Get.put(ProfileController());
  final AuthService authService = AuthService();

  // Get userId from StorageService
  String? get userId {
    final userData = StorageService.to.getUser();
    return userData != null ? userData['id']?.toString() : null;
  }

  @override
  void initState() {
    super.initState();
    // Ensure profile is refreshed when screen opens
    controller.loadUserProfile();
    controller.forceRefreshAfterEdit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print("ProfileScreen initState - triggering profile refresh");
      controller.refreshProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // FIXED HEADER SECTION - This won't scroll
          _buildFixedHeader(),

          // SCROLLABLE CONTENT SECTION - Only this part scrolls
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                // Pull-to-refresh functionality
                print("Pull to refresh triggered");
                await controller.forceRefresh();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(), // Enables pull-to-refresh
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Manage Account Section
                    _buildManageAccountSection(),

                    const SizedBox(height: 24),

                    // Notifications Section
                    _buildNotificationsSection(),

                    const SizedBox(height: 24),

                    // Logout and Delete Account Section
                    _buildAccountActionsSection(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Fixed header that doesn't scroll
  Widget _buildFixedHeader() {
    return Container(
      child: Stack(
        children: [
          // Background image
          Container(
            height: 280, // Fixed height for the header
            width: double.infinity,
            child: Image.asset(
              CustomImage.profileBg,
              fit: BoxFit.cover,
            ),
          ),

          // Header content
          Container(
            height: 320,
            child: Column(
              children: [
                const SizedBox(height:55),

                // Header title
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Profile",
                      style: mediumStyle.copyWith(
                        fontSize: Dimensions.fontSizeOverLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ✅ FIXED: Enhanced Profile Image with Local Support
                Center(
                  child: Obx(() {
                    if (controller.isLoading.value) {
                      return Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CustomColors.lightPurpleColor,
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: CustomColors.purpleColor,
                          ),
                        ),
                      );
                    }

                    return Stack(
                      children: [
                        // Main profile image with enhanced logic
                        Container(
                          width: 128,
                          height: 128,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: CustomColors.lightPurpleColor,
                              width: 3,
                            ),
                          ),
                          child: ClipOval(
                            child: _buildEnhancedProfileImage(),
                          ),
                        ),

                        // Loading overlay for image operations
                        if (controller.isImageLoading.value)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withOpacity(0.5),
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),


                      ],
                    );
                  }),
                ),

                const SizedBox(height: 8),

                // Display Name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: Obx(() => controller.isLoading.value
                        ? Container(
                      width: 120,
                      height: 20,
                      decoration: BoxDecoration(
                        color: CustomColors.lightPurpleColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )
                        : Text(
                      controller.displayName.length > 30
                          ? '${controller.displayName.substring(0, 30)}…'
                          : controller.displayName,
                      style: mediumStyle.copyWith(
                        fontSize: Dimensions.fontSizeOverLarge,
                      ),
                    )
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // Username
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: Obx(() => controller.isLoading.value
                        ? Container(
                      width: 100,
                      height: 16,
                      decoration: BoxDecoration(
                        color: CustomColors.lightPurpleColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )
                        : Text(
                      controller.usernameDisplay,
                      style: mediumStyle.copyWith(
                          fontSize: Dimensions.fontSizeLarge,
                          color: CustomColors.purpleColor
                      ),
                    ),
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

  // ✅ NEW: Enhanced profile image widget with local image support
  Widget _buildEnhancedProfileImage() {
    final displayPath = controller.displayImagePath.value;

    print("🖼️ Building profile image with displayPath: $displayPath");
    print("🖼️ Has API Image: ${controller.hasApiImage.value}");
    print("🖼️ Has Local Image: ${controller.hasLocalImage.value}");

    // No image available - show default
    if (displayPath.isEmpty) {
      print("🖼️ Using default avatar - no display path");
      return _buildDefaultAvatar();
    }

    // Check if this is a local file path
    if (controller.hasLocalImage.value && !displayPath.startsWith('http')) {
      print("🖼️ Loading local image from: $displayPath");
      return _buildLocalImage(displayPath);
    }

    // Check if this is an API image (URL)
    if (controller.hasApiImage.value && displayPath.startsWith('http')) {
      print("🖼️ Loading API image from: $displayPath");
      return _buildNetworkImage(displayPath);
    }

    // Fallback to default
    print("🖼️ Falling back to default avatar");
    return _buildDefaultAvatar();
  }

  // Build local image widget
  Widget _buildLocalImage(String imagePath) {
    return Image.file(
      File(imagePath),
      width: 128,
      height: 128,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        print("❌ Local image load error: $error");
        print("❌ Attempted path: $imagePath");

        // Check if file exists
        final file = File(imagePath);
        print("❌ File exists: ${file.existsSync()}");

        // Fallback to API image if available
        if (controller.hasApiImage.value && controller.profileImageUrl.value.isNotEmpty) {
          print("🔄 Falling back to API image");
          return _buildNetworkImage(controller.profileImageUrl.value);
        }

        return _buildDefaultAvatar();
      },
    );
  }

  // Build network image widget
  Widget _buildNetworkImage(String imageUrl) {
    return Image.network(
      imageUrl,
      width: 128,
      height: 128,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildImageLoadingIndicator();
      },
      errorBuilder: (context, error, stackTrace) {
        print("❌ Network image load error: $error");
        print("❌ Attempted URL: $imageUrl");

        // Fallback to local image if available
        if (controller.hasLocalImage.value && controller.localImagePath.value.isNotEmpty) {
          print("🔄 Falling back to local image");
          return _buildLocalImage(controller.localImagePath.value);
        }

        return _buildDefaultAvatar();
      },
    );
  }

  // Default avatar widget with user initials
  Widget _buildDefaultAvatar() {
    return Container(
      width: 128,
      height: 128,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [CustomColors.purpleColor, CustomColors.lightPurpleColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          controller.displayName.isNotEmpty
              ? controller.displayName[0].toUpperCase()
              : 'U',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Image loading indicator
  Widget _buildImageLoadingIndicator() {
    return Container(
      width: 128,
      height: 128,
      color: CustomColors.lightPurpleColor.withOpacity(0.3),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: CustomColors.purpleColor,
        ),
      ),
    );
  }

  // Manage Account section
  Widget _buildManageAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Manage Account",
            textAlign: TextAlign.left,
            style: mediumStyle.copyWith(
              fontSize: Dimensions.fontSizeDefault,
            )),
        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: CustomColors.textBorderColor, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTile(
                  icon: SvgPicture.asset(CustomIcons.profileIcon, width: 20, height: 20),
                  title: "Edit Profile",
                  onTap: () async {
                    print("Navigating to edit profile...");
                    final result = await Get.toNamed('/editProfile');
                    print("Returned from edit profile with result: $result");

                    // Handle different result formats
                    bool shouldRefresh = false;

                    if (result == true) {
                      shouldRefresh = true;
                    } else if (result is Map && (result['success'] == true || result['updated'] == true)) {
                      shouldRefresh = true;
                    }

                    if (shouldRefresh) {
                      print("Refreshing profile after edit...");
                      // Force refresh with loading indicator
                      await controller.forceRefresh();
                      print("Profile refresh completed");
                    } else {
                      print("No refresh needed - result was: $result");
                    }
                  }),
              Divider(height: 2, color: CustomColors.textBorderColor),
              _buildTile(
                  icon: SvgPicture.asset(CustomIcons.reportIcon, width: 20, height: 20),
                  title: "My Reports",
                  onTap: () {
                    Get.toNamed('/report');
                  }),
            ],
          ),
        ),
      ],
    );
  }

  // Notifications section
  Widget _buildNotificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Notifications",
            textAlign: TextAlign.left,
            style: mediumStyle.copyWith(
              fontSize: Dimensions.fontSizeDefault,
            )),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: CustomColors.textBorderColor, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  "Push Notifications",
                  style: mediumStyle.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                  ),
                ),
                subtitle: Text(
                  "Enable push notifications to receive reminders",
                  style: semiLightStyle.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                    color: CustomColors.greyTextColor,
                  ),
                ),
                trailing: Obx(() => Switch(
                  value: controller.notificationsEnabled.value,
                  onChanged: (value) {
                    controller.toggleNotifications(value);
                  },
                )),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Account actions section (Logout and Delete)
  Widget _buildAccountActionsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: CustomColors.textBorderColor, width: 2),
      ),
      child: Column(
        children: [
          _buildTile(
            icon: SvgPicture.asset(CustomIcons.logoutIcon, width: 20, height: 20),
            title: "Logout",
            color: CustomColors.purpleColor,
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => LogoutConfirmDialog(
                  onConfirm: () => _handleLogout(),
                ),
              );
            },
          ),
          Divider(height: 2, color: CustomColors.textBorderColor),
          _buildTile(
            icon: SvgPicture.asset(CustomIcons.deleteIcon, width: 20, height: 20),
            title: "Delete Account",
            color: CustomColors.darkredColor,
            onTap: () {
              final String? userIdValue = userId;

              if (userIdValue == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User information not found. Please log in again.')),
                );
                return;
              }

              print("Delete Account button tapped with userId: $userIdValue");

              showDialog(
                  context: context,
                  builder: (context) => DeleteConfirmDialog(
                    userId: userIdValue,
                    onConfirm: () => _handleAccountDeletion(),
                  )
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required Widget icon,
    required String title,
    Color color = Colors.black,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      child: ListTile(
        leading: icon,
        title: Text(
          title,
          style: mediumStyle.copyWith(
            fontSize: Dimensions.fontSizeLarge,
            color: color,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  // Handle logout with API call and success message
  Future<void> _handleLogout() async {
    try {
      // Show loading indicator
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(),
        ),
        barrierDismissible: false,
      );

      // Call logout API
      print("Calling logout API...");
      final response = await authService.logout();

      // Close loading dialog
      if (Get.isDialogOpen == true) {
        Get.back();
      }

      // Check response
      if (response['status'] == 'success') {
        print("Logout successful");

        // Show success message with good styling
        Get.snackbar(
          'Success',
          'You have been logged out successfully!',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        // Clear local storage
        await StorageService.to.clearAll();

        // Wait for success message to be visible
        await Future.delayed(Duration(milliseconds: 1500));

        // Navigate to login screen
        Get.offAllNamed('/login', predicate: (_) => false);

      } else {
        print("Logout API returned error: ${response['message']}");

        // Show error message
        Get.snackbar(
          'Info',
          'Logout completed with warnings',
          snackPosition: SnackPosition.TOP,
        );

        // Clear local storage anyway
        await StorageService.to.clearAll();

        // Wait a moment then navigate
        await Future.delayed(Duration(milliseconds: 1500));

        // Navigate to login screen
        Get.offAllNamed('/login', predicate: (_) => false);
      }
    } catch (e) {
      // Close loading dialog if open
      if (Get.isDialogOpen == true) {
        Get.back();
      }

      print("Error during logout: $e");

      // Show error message
      Get.snackbar(
        'Error',
        'Logout encountered an error, but you will be signed out',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );

      // Clear local storage anyway for security
      try {
        await StorageService.to.clearAll();
      } catch (storageError) {
        print("Error clearing storage: $storageError");
      }

      // Wait a moment then navigate
      await Future.delayed(Duration(milliseconds: 1500));

      // Navigate to login screen
      Get.offAllNamed('/login', predicate: (_) => false);
    }
  }

  void _handleAccountDeletion() async {
    try {
      print("Handling account deletion...");

      // Show success message first
      Get.snackbar(
        'Success',
        'Your account has been deleted successfully!',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // Wait for success message to be visible
      await Future.delayed(Duration(milliseconds: 2000));

      // Clear storage
      try {
        await StorageService.to.clearAll();
        print("Storage cleared successfully");
      } catch (storageError) {
        print("Error clearing storage: $storageError");
        // Continue anyway for security
      }

      print("Storage cleared, now navigating...");

      // Navigate to login screen
      Get.offAllNamed('/login', predicate: (_) => false);

    } catch (error) {
      print("Error during account deletion: $error");

      // Show error message but still proceed with cleanup
      Get.snackbar(
        'Warning',
        'Account deletion completed with warnings',
        snackPosition: SnackPosition.TOP,
      );

      // Clear storage anyway for security
      try {
        await StorageService.to.clearAll();
      } catch (storageError) {
        print("Error clearing storage: $storageError");
      }

      // Wait a moment then navigate
      await Future.delayed(Duration(milliseconds: 1500));

      // Navigate to login screen
      Get.offAllNamed('/login', predicate: (_) => false);
    }
  }
}