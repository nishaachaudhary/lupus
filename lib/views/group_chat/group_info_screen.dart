import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/icons.dart';
import 'package:lupus_care/constant/images.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/group_chat/group_chat_controller.dart';

// FIXED: Enhanced GroupInfoScreen with proper image display
class GroupInfoScreen extends StatelessWidget {
  final String? groupId;
  final String? groupName;
  final int? memberCount;

  const GroupInfoScreen({
    super.key,
    this.groupId,
    this.groupName,
    this.memberCount,
  });

  @override
  Widget build(BuildContext context) {
    // Get group data from constructor or route arguments
    final arguments = Get.arguments as Map<String, dynamic>?;
    final effectiveGroupId = groupId ?? arguments?['groupId']?.toString();
    final effectiveGroupName = groupName ?? arguments?['groupName']?.toString();
    final effectiveMemberCount = memberCount ?? arguments?['memberCount'] as int?;

    print("🏗️ GroupInfoScreen build:");
    print("   Group ID: '$effectiveGroupId'");
    print("   Group Name: '$effectiveGroupName'");
    print("   Member Count: $effectiveMemberCount");

    final controller = Get.put(GroupController());

    // Initialize controller with group data if available
    if (effectiveGroupId != null && effectiveGroupName != null) {
      controller.initializeGroupData(
        groupId: effectiveGroupId,
        groupName: effectiveGroupName,
        memberCount: effectiveMemberCount ?? 0,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Container(
          width: 31,
          height: 51,
          margin: const EdgeInsets.only(left: Dimensions.fontSizeLarge,top: Dimensions.fontSizeExtraSmall),
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
          "Group Info",
          style: mediumStyle.copyWith(fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        child: Column(
          children: [
            // ENHANCED: Group Header with comprehensive image support
            Column(
              children: [
                Stack(
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: CustomColors.lightPurpleColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: Obx(() => _buildGroupImage(controller)),
                        ),
                      ),
                    ),

                    // Loading overlay when uploading
                    Obx(() {
                      if (controller.isUploadingImage.value) {
                        return Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                    value: controller.uploadProgress.value,
                                  ),
                                  SizedBox(height: 8),
                                  if (controller.uploadStatus.value.isNotEmpty)
                                    Text(
                                      controller.uploadStatus.value,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      return SizedBox.shrink();
                    }),

                    // Camera button positioned at bottom right
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Obx(() => GestureDetector(
                        onTap: controller.isUploadingImage.value
                            ? null
                            : () => _showImagePickerDialog(context, controller),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: controller.isUploadingImage.value
                                ? Colors.grey
                                : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            controller.isUploadingImage.value
                                ? Icons.hourglass_empty
                                : Icons.camera_alt_outlined,
                            color: CustomColors.purpleColor,
                            size: 18,
                          ),
                        ),
                      )),
                    ),
                  ],
                ),
                const SizedBox(height: Dimensions.paddingSizeDefault),
                Obx(() => Text(
                  controller.groupName,
                  style: mediumStyle.copyWith(
                    fontSize: Dimensions.fontSizeExtraLarge,
                    fontWeight: FontWeight.bold,
                  ),
                )),
                const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                Obx(() => Text(
                  '${controller.memberCount} Members',
                  style: semiLightStyle.copyWith(
                    color: CustomColors.blackColor,
                    fontSize: Dimensions.fontSizeDefault,
                  ),
                )),
              ],
            ),

            const SizedBox(height: Dimensions.paddingSizeExtraLarge),

            // Member Actions - Row of buttons
            _buildMemberActions(controller),
            const SizedBox(height: Dimensions.paddingSizeSmall),

            // Leave Group Button
            _buildLeaveButton(controller),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupImage(GroupController controller) {
    print('🖼️ Building group image...');


    // Get the display image URL/data
    final displayImage = controller.getDisplayImage();
    print('   Display image type: ${displayImage.startsWith('data:') ? 'base64' : displayImage.startsWith('http') ? 'network' : 'local/default'}');

    // Base64 data URI from Firestore (most common case now)
    if (displayImage.startsWith('data:image')) {
      print('📷 Loading base64 image from Firestore');
      try {
        final base64String = displayImage.split(',')[1];
        final bytes = base64Decode(base64String);

        return Image.memory(
          bytes,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('❌ Error displaying base64 image: $error');
            return _buildErrorImage('Failed to load saved image');
          },
        );
      } catch (e) {
        print('❌ Error decoding base64 image: $e');
        return _buildErrorImage('Corrupted image data');
      }
    }

    // HTTP URLs (legacy support)
    else if (displayImage.startsWith('http')) {
      print('🌐 Loading HTTP image');
      return Image.network(
        displayImage,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingImage();
        },
        errorBuilder: (context, error, stackTrace) {
          print('❌ Error loading HTTP image: $error');
          return _buildErrorImage('Failed to load image');
        },
      );
    }

    // Local file path (during upload/selection)
    else if (displayImage != CustomImage.userGroup && displayImage.isNotEmpty) {
      print('📁 Loading local file image');
      try {
        return Image.file(
          File(displayImage),
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('❌ Error displaying local image: $error');
            return _buildDefaultImage();
          },
        );
      } catch (e) {
        print('❌ Error loading local file: $e');
        return _buildDefaultImage();
      }
    }

    // Default group image
    else {
      print('📁 Using default group image');
      return _buildDefaultImage();
    }
  }

  Widget _buildLoadingImage() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: CustomColors.lightPurpleColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: CustomColors.purpleColor,
              strokeWidth: 2,
            ),
            SizedBox(height: 8),
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 10,
                color: CustomColors.purpleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build error image with message
  Widget _buildErrorImage(String message) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade400,
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              message,
              style: TextStyle(
                fontSize: 9,
                color: Colors.red.shade600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ENHANCED: Image picker dialog with size warning
  void _showImagePickerDialog(BuildContext context, GroupController controller) {
    if (controller.isUploadingImage.value) {
      Get.snackbar(
        'Upload in Progress',
        'Please wait for the current upload to complete',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }



    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Wrap(
          children: [
            ListTile(
              leading: SvgPicture.asset(
                CustomIcons.uploadIcon,
              ),
              title: Text('Upload from Device', style: semiLightStyle.copyWith(
                fontSize: Dimensions.fontSizeExtraLarge,
                color: CustomColors.blackColor,
              )),
              onTap: () async {
                // Close the bottom sheet first
                Get.back();
                controller.pickImageFromGallery();
              },
            ),
            ListTile(
              leading: SvgPicture.asset(
                CustomIcons.cameraGreyIcon,
              ),
              title: Text('Take a photo', style: semiLightStyle.copyWith(
                fontSize: Dimensions.fontSizeExtraLarge,
                color: CustomColors.blackColor,
              )),
              onTap: () async {

                Get.back();
                controller.pickImageFromCamera();
              },
            ),


          ],
        ),
      ),
      isScrollControlled: true, // This helps with better positioning
      ignoreSafeArea: false,
    );
  }

  // Helper method to build default image
  Widget _buildDefaultImage() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: CustomColors.lightPurpleColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Image.asset(
            CustomImage.userGroup,
            width: 80,
            height: 80,
            fit: BoxFit.contain,
            color: CustomColors.purpleColor.withOpacity(0.7),
          ),
        ),
      ),
    );
  }




  Widget _buildMemberActions(GroupController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge),
      child: Row(
        children: [
          Expanded(
            child: _buildActionColumnButton(
              icon: Icons.person_add_alt,
              label: 'Add Members',
              onTap: controller.addMembers,
            ),
          ),
          const SizedBox(width: Dimensions.paddingSizeDefault),
          Expanded(
            child: _buildActionColumnButton(
              icon: Icons.people_outline,
              label: 'View Members',
              onTap: controller.viewMembers,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionColumnButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black,
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          vertical: Dimensions.paddingSizeDefault,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        elevation: 0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: CustomColors.purpleColor, size: 28),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text(
            label,
            style: semiLightStyle.copyWith(fontSize: Dimensions.fontSizeDefault),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveButton(GroupController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            icon: SvgPicture.asset(
              CustomIcons.profileIcon,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                CustomColors.purpleColor,
                BlendMode.srcIn,
              ),
            ),
            label: Text(
              'Edit Group info',
              style: mediumStyle.copyWith(
                color: CustomColors.purpleColor,
                fontSize: Dimensions.fontSizeOverLarge,
              ),
            ),
            onPressed: () {
              try {
                controller.editGroupInfo();
              } catch (e) {
                print("❌ Error opening edit dialog: $e");
                Get.snackbar(
                  'Error',
                  'Unable to open edit dialog',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: Dimensions.paddingSizeLarge,
                horizontal: Dimensions.paddingSizeDefault,
              ),
              alignment: Alignment.centerLeft,
            ),
          ),
        ),

        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            icon: SvgPicture.asset(
              CustomIcons.leaveGroup,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                CustomColors.redColor,
                BlendMode.srcIn,
              ),
            ),
            label: Text(
              'Leave Group',
              style: mediumStyle.copyWith(
                color: CustomColors.redColor,
                fontSize: Dimensions.fontSizeOverLarge,
              ),
            ),
            onPressed: controller.leaveGroup,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: Dimensions.paddingSizeLarge,
                horizontal: Dimensions.paddingSizeDefault,
              ),
              alignment: Alignment.centerLeft,
            ),
          ),
        ),
      ],
    );
  }
}