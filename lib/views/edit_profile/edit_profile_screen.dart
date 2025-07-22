import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/icons.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/edit_profile/edit_profile_controller.dart';
import 'package:lupus_care/views/profile_screen/profile_controller.dart';
import 'package:lupus_care/widgets/customTextflied.dart';

class EditProfileScreen extends StatelessWidget {
  EditProfileScreen({super.key});
  final ProfileController controllers = Get.put(ProfileController());
  final EditProfileController controller = Get.put(EditProfileController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6EDFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6EDFF),
        elevation: 0,
        leading: Container(
          width: 31,
          height: 51,
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
          "Edit Profile",
          style: mediumStyle.copyWith(fontSize: 20),
        ),
      ),
      body: Stack(
        children: [
          // Main content
          Obx(() => controller.isLoading.value
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: CustomColors.purpleColor),
              ],
            ),
          )
              : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Image Section
                  Center(
                    child: Obx(() => GestureDetector(
                      onTap: () {
                        _showImagePickerDialog(context);
                      },
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        backgroundImage: controller.displayImage,
                        radius: 64,
                        onBackgroundImageError: (exception, stackTrace) {
                          print("Profile image loading error: $exception");
                        },
                        child: controller.selectedImage.value == null &&
                            controller.currentProfileImageUrl.value.isEmpty
                            ? Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0x14000000),
                                offset: const Offset(5.55, 6.66),
                                blurRadius: 19.98,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.camera_alt_outlined,
                              size: 24,
                              color: CustomColors.purpleColor,
                            ),
                          ),
                        )
                            : Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.3),
                          ),
                          child: const Icon(
                            Icons.camera_alt_outlined,
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )),
                  ),

                  const SizedBox(height: 30),

                  // Full Name Field with Character Limit
                  _buildFullNameField(),

                  const SizedBox(height: 14),

                  // Username Field with Character Limit
                  _buildUsernameField(),

                  const SizedBox(height: 14),

                  // Email Field - READ ONLY
                  _buildReadOnlyEmailField(),

                  const SizedBox(height: 24),


                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Obx(() => ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: controller.hasChanges
                            ? CustomColors.greenColor
                            : Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: controller.hasChanges ? 2 : 0,
                      ),
                      onPressed: controller.hasChanges ? () async {
                        controller.saveChanges();
                        Get.back();
                        await controllers.loadUserProfile();
                        await controllers.forceRefreshAfterEdit();
                      } : null, // Disable button when no changes
                      child: Text(
                        "Save Changes",
                        style: semiBoldStyle.copyWith(
                          color: controller.hasChanges
                              ? CustomColors.darkGreenColor
                              : Colors.grey[600],
                          fontSize: Dimensions.fontSizeExtraLarge,
                        ),
                      ),
                    )),
                  ),
                ],
              ),
            ),
          ),
          ),

          // Full-screen loader overlay for saving
          Obx(() => controller.isSaving.value
              ? Container(
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: Container(
                padding: EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: CustomColors.purpleColor,
                      strokeWidth: 3,
                    ),
                  ],
                ),
              ),
            ),
          )
              : SizedBox.shrink()
          ),
        ],
      ),
    );
  }

  // Full Name Field with Character Limit and Validation
  Widget _buildFullNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Full Name",
          style: mediumStyle.copyWith(
            fontSize: Dimensions.fontSizeDefault,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller.fullNameController,
          maxLength: EditProfileController.FULL_NAME_MAX_LENGTH,
          decoration: InputDecoration(
            hintText: "Enter Full Name",
            hintStyle: regularStyle.copyWith(
              fontSize: Dimensions.fontSizeDefault,
              color: Colors.grey[500],
            ),
            filled: true,
            fillColor: Colors.white,
            counterText: "", // Hide default counter
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: CustomColors.purpleColor,
                width: 1,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.red,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.red,
                width: 1,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: regularStyle.copyWith(
            fontSize: Dimensions.fontSizeDefault,
            color: CustomColors.blackColor,
          ),
        ),
        // Error message for full name
        Obx(() {
          final validation = controller.fullNameValidationError;
          return validation != null
              ? Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              validation,
              style: regularStyle.copyWith(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          )
              : const SizedBox.shrink();
        }),
      ],
    );
  }

  // Username Field with Character Limit and Validation
  Widget _buildUsernameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Username",
          style: mediumStyle.copyWith(
            fontSize: Dimensions.fontSizeDefault,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller.usernameController,
          maxLength: EditProfileController.USERNAME_MAX_LENGTH,
          decoration: InputDecoration(
            hintText: "Enter Username",
            hintStyle: regularStyle.copyWith(
              fontSize: Dimensions.fontSizeDefault,
              color: Colors.grey[500],
            ),
            filled: true,
            fillColor: Colors.white,
            counterText: "", // Hide default counter
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: CustomColors.purpleColor,
                width: 1,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.red,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.red,
                width: 1,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: regularStyle.copyWith(
            fontSize: Dimensions.fontSizeDefault,
            color: CustomColors.blackColor,
          ),
        ),
        // Error message for username
        Obx(() {
          final validation = controller.usernameValidationError;
          return validation != null
              ? Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              validation,
              style: regularStyle.copyWith(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          )
              : const SizedBox.shrink();
        }),
      ],
    );
  }

  // Custom read-only email field
  Widget _buildReadOnlyEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Email",
          style: mediumStyle.copyWith(
            fontSize: Dimensions.fontSizeDefault,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey[100], // Light gray background to indicate read-only
            border: Border.all(
              color: Colors.grey[300]!,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  controller.emailController.text.isNotEmpty
                      ? controller.emailController.text
                      : "No email available",
                  style: regularStyle.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                    color: controller.emailController.text.isNotEmpty
                        ? CustomColors.blackColor
                        : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showImagePickerDialog(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Wrap(
          children: [
            ListTile(
              leading: SvgPicture.asset(CustomIcons.uploadIcon),
              title: Text(
                'Upload from Device',
                style: semiLightStyle.copyWith(
                  fontSize: Dimensions.fontSizeExtraLarge,
                  color: CustomColors.blackColor,
                ),
              ),
              onTap: () {
                controller.pickImageFromGallery();
                Get.back();
              },
            ),
            ListTile(
              leading: SvgPicture.asset(CustomIcons.cameraGreyIcon),
              title: Text(
                'Take a photo',
                style: semiLightStyle.copyWith(
                  fontSize: Dimensions.fontSizeExtraLarge,
                  color: CustomColors.blackColor,
                ),
              ),
              onTap: () {
                controller.pickImageFromCamera();
                Get.back();
              },
            ),
          ],
        ),
      ),
    );
  }
}