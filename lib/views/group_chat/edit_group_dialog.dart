import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/group_chat/group_chat_controller.dart';

class EditGroupDialog extends StatefulWidget {
  const EditGroupDialog({Key? key}) : super(key: key);

  @override
  State<EditGroupDialog> createState() => _EditGroupDialogState();
}

class _EditGroupDialogState extends State<EditGroupDialog> {
  late TextEditingController nameController;
  late GroupController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<GroupController>();
    nameController = TextEditingController(text: controller.groupName);
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and close button
          SizedBox(
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Text(
                    'Edit Group',
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
                      icon: const Icon(Icons.close, size: 16, color: Colors.white),
                      onPressed: () => Get.back(),
                      splashRadius: 16,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: Dimensions.paddingSizeDefault),

          // Group Name field
          Text(
            'Group Name',
            style: semiBoldStyle.copyWith(
              fontSize: Dimensions.fontSizeLarge,
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              hintText: 'Enter group name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: CustomColors.purpleColor),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
                vertical: Dimensions.paddingSizeDefault,
              ),
            ),
            maxLength: 50, // Add reasonable limit
          ),
          const SizedBox(height: Dimensions.paddingSizeLarge),

          // Save Changes button
          Padding(
            padding: const EdgeInsets.only(left: 25.0, right: 25),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final newName = nameController.text.trim();
                  if (newName.isNotEmpty) {
                    // Update the group name
                     controller.updateGroupName(newName);

                    // Close the dialog
                    Get.back();

                    // Optional: Small delay to ensure UI updates
                    Future.delayed(Duration(milliseconds: 100), () {
                      // Force a global update if needed
                      Get.forceAppUpdate();
                    });
                  } else {
                    Get.snackbar(
                      'Error',
                      'Group name cannot be empty',
                      snackPosition: SnackPosition.TOP,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomColors.greenColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: Dimensions.paddingSizeDefault,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
                  ),
                ),
                child: Text(
                  'Save Changes',
                  style: mediumStyle.copyWith(
                    color: CustomColors.darkGreenColor,
                    fontSize: Dimensions.fontSizeExtraLarge,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
        ],
      ),
    );
  }
}