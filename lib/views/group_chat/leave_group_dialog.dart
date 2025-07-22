// lib/widgets/leave_group_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/icons.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/chat_screen/community_chat_screen.dart';
import 'package:lupus_care/views/group_chat/group_chat_controller.dart';

class LeaveGroupDialog extends StatelessWidget {
  const LeaveGroupDialog({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the group name from controller if available
    String groupName = "this group";
    try {
      if (Get.isRegistered<GroupController>()) {
        final controller = Get.find<GroupController>();
        groupName = controller.groupName.isNotEmpty ? '"${controller.groupName}"' : "this group";
      }
    } catch (e) {
      // Use default if controller not available
    }

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header
            Center(
              child: Container(
                width: 105,
                height: 105,
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFAFA), // background: #FAFAFA
                  shape: BoxShape.circle, // or use borderRadius if needed
                ),
                child: Center(
                  child: SvgPicture.asset(
                    CustomIcons.leaveGroupIcon,
                    width: 50,
                    height: 50,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Warning message with group name
            Text(
              'Leave $groupName?',
              textAlign: TextAlign.center,
              style: mediumStyle.copyWith(
                fontSize: Dimensions.fontSizeLarger,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Are you sure you want to leave $groupName? You won't receive any more messages from this chat.",
              textAlign: TextAlign.center,
              style: semiLightStyle.copyWith(
                  fontSize: Dimensions.fontSizeLarge,
                  color: CustomColors.leaveColor
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TextButton(
                      onPressed: () => Get.back(result: false),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9.47),
                          side: const BorderSide(
                            color: Color(0xFFDCDCDC),
                            width: 1.19,
                          ),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: semiBoldStyle.copyWith(
                          fontSize: Dimensions.paddingSizeDefault,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TextButton(
                      onPressed: () async {

                        Get.back(result: true);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: CustomColors.redColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9.47),
                          side: BorderSide(
                            width: 1.19,
                            color: CustomColors.redColor,
                          ),
                        ),
                      ),
                      child: Text(
                        'Leave',
                        style: semiBoldStyle.copyWith(
                            fontSize: Dimensions.paddingSizeDefault,
                            color: Colors.white
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}