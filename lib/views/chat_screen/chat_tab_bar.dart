// lib/views/chat_screen/chat_tab_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/icons.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/chat_screen/chat_controller.dart';

class ChatTabBar extends StatelessWidget {
  const ChatTabBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ChatController>();

    return Obx(() => Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _buildTab(controller, "Personal", 0),
        const SizedBox(width: 16),
        _buildTab(controller, "Group Chat", 1),
      ],
    ));
  }

  Widget _buildTab(ChatController controller, String label, int index) {
    bool isSelected = controller.selectedTabIndex.value == index;
    final Color activeColor = CustomColors.purpleColor;
    final Color inactiveColor = CustomColors.greyColor;

    final String assetPath = label == "Personal"
        ? CustomIcons.userChat
        : CustomIcons.group;

    return GestureDetector(
      onTap: () => controller.switchTab(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  assetPath,
                  height: 16,
                  width: 16,
                  colorFilter: ColorFilter.mode(
                    isSelected ? activeColor : inactiveColor,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: (isSelected ? semiBoldStyle : semiLightStyle).copyWith(
                    fontSize: isSelected
                        ? Dimensions.fontSizeExtraLarge
                        : Dimensions.fontSizeLarge,
                    color: isSelected ? activeColor : inactiveColor,
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              height: 2,
              width: label == "Personal" ? 120 : 140,
              color: isSelected ? activeColor : Colors.transparent,
            ),
          )
        ],
      ),
    );
  }
}