import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/icons.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/create_profile/create_profile_controller.dart';
import 'package:lupus_care/widgets/customTextflied.dart';

class CreateProfileScreen extends StatelessWidget {
  final CreateProfileController controller = Get.put(CreateProfileController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomColors.lightPurpleColor,
      body: Stack(
        children: [
          // Main content
          SizedBox.expand(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 40),
                    Text(
                      'Create Profile',
                      style: semiBoldStyle.copyWith(
                        fontSize: Dimensions.fontSizeExtraLarge,
                      ),
                    ),
                    SizedBox(height: 30),
                    Obx(() => GestureDetector(
                      onTap: () => _showImagePickerDialog(context),
                      child: DottedBorder(
                        color: CustomColors.purpleColor,
                        borderType: BorderType.Circle,
                        dashPattern: [6, 3],
                        strokeWidth: 1,
                        padding: EdgeInsets.all(4),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.white,
                          backgroundImage: controller.selectedImage.value != null
                              ? FileImage(controller.selectedImage.value!)
                              : null,
                          child: controller.selectedImage.value == null
                              ? Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: CustomColors.lightPurpleColor,
                            ),
                            padding: EdgeInsets.all(16),
                            child: SvgPicture.asset(
                              CustomIcons.cameraIcon,
                            ),
                          )
                              : null,
                        ),
                      ),
                    )),

                    SizedBox(height: 20),

                    CustomTextField(
                      titleStyle: mediumStyle.copyWith(
                        fontSize: Dimensions.fontSizeDefault,
                      ),
                      title: "Username",
                      controller: controller.usernameController,
                      hintText: "Enter a  username",
                    ),
                    Obx(() {
                      final validation = controller.usernameError.value;
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

                    SizedBox(height: 20),

                    // Save button
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CustomColors.greenColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => controller.saveProfile(),
                        child: Text(
                          "Save",
                          style: semiBoldStyle.copyWith(
                            fontSize: Dimensions.fontSizeExtraLarge,
                            color: CustomColors.darkGreenColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Simple centered loader overlay
          Obx(() => controller.isLoading.value
              ? Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: CircularProgressIndicator(
                color: CustomColors.purpleColor,
              ),
            ),
          )
              : SizedBox.shrink()
          ),
        ],
      ),
    );
  }

  void _showImagePickerDialog(BuildContext context) {
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



                // Then trigger the gallery picker
                await controller.pickImageFromGallery();
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
                // Close the bottom sheet first
                Get.back();



                // Then trigger the camera picker
                await controller.pickImageFromCamera();
              },
            ),


          ],
        ),
      ),
      isScrollControlled: true, // This helps with better positioning
      ignoreSafeArea: false,
    );
  }
}