import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/icons.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/views/chat_screen/community_chat_screen.dart';
import 'package:lupus_care/views/home/home_tab.dart';
import 'package:lupus_care/views/login/main_screen_controller.dart';
import 'package:lupus_care/views/medication_tracker/medication_tracker_screen.dart';
import 'package:lupus_care/views/profile_screen/profile_controller.dart';
import 'package:lupus_care/views/profile_screen/profile_screen.dart';
import 'package:lupus_care/views/symptom/symptoms_screen.dart';

class HomeScreen extends StatelessWidget {
  final MainScreenController controller = Get.put(MainScreenController());

  HomeScreen({super.key}) {
    // Check if we have arguments for initial tab index
    if (Get.arguments != null && Get.arguments is int) {
      controller.selectedIndex.value = Get.arguments;
    }
  }
  final List<Widget> screens = [
     HomeTab(),          // Your current home content
    SymptomScreen(),      // Symptoms
    MedicationTrackerScreen(),      // Medication
    CommunityChatScreen(),      // Chat
    ProfileScreen(),    // Profile screen
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() => Scaffold(
      body: IndexedStack(
        index: controller.selectedIndex.value,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: controller.selectedIndex.value,
        onTap: controller.changeTabIndex,
        selectedItemColor: CustomColors.purpleColor,
        unselectedItemColor: CustomColors.blackColor,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: controller.selectedIndex.value == 0
                        ? CustomColors.purpleColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 3),
                  child: SvgPicture.asset(
                    CustomIcons.homeIcon,
                    width: 30,
                    height: 30,
                    color: controller.selectedIndex.value == 0
                        ? CustomColors.purpleColor
                        : CustomColors.blackColor,
                  ),
                ),
              ],
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 44,
                  decoration: BoxDecoration(
                    color: controller.selectedIndex.value == 1
                        ? CustomColors.purpleColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 3),
                  child: SvgPicture.asset(
                    CustomIcons.symptomsIcon,
                    width: 30,
                    height: 30,
                    color: controller.selectedIndex.value == 1
                        ? CustomColors.purpleColor
                        : CustomColors.blackColor,
                  ),
                ),
              ],
            ),
            label: 'Symptoms',
          ),
          BottomNavigationBarItem(
            icon: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: controller.selectedIndex.value == 2
                        ? CustomColors.purpleColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 3),
                  child: SvgPicture.asset(
                    controller.selectedIndex.value == 2
                        ? CustomIcons.medicationIconSelected
                        : CustomIcons.medicationIcon,
                    width: 30,
                    height: 30,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
            label: 'Medication',
          ),

          BottomNavigationBarItem(
            icon: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: controller.selectedIndex.value == 3
                        ? CustomColors.purpleColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 3),
                  child: SvgPicture.asset(
                    CustomIcons.chatIcon,
                    width: 30,
                    height: 30,
                    color: controller.selectedIndex.value == 3
                        ? CustomColors.purpleColor
                        : CustomColors.blackColor,
                  ),
                ),
              ],
            ),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: controller.selectedIndex.value == 4
                        ? CustomColors.purpleColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 3),
                  child: SvgPicture.asset(
                    CustomIcons.userIcon,
                    width: 30,
                    height: 30,
                    color: controller.selectedIndex.value == 4
                        ? CustomColors.purpleColor
                        : CustomColors.blackColor,
                  ),
                ),
              ],
            ),
            label: 'Profile',
          ),
        ],
      ),

    ));
  }
}
