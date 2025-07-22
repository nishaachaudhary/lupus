import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lupus_care/views/onboarding/onboading_controller.dart';
import 'package:lupus_care/views/onboarding/onboading_screen_one.dart';
import 'package:lupus_care/views/onboarding/onboading_screen_three.dart';
import 'package:lupus_care/views/onboarding/onboading_screen_two.dart';



class OnboardingScreen extends StatelessWidget {
  final controller = Get.put(OnboardingController());

  final List<Widget> pages = [
    OnboardingPage1(),
    OnboardingPage2(),
    OnboardingPage3(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: PageView(
          controller: controller.pageController,
          onPageChanged: controller.onPageChanged,
          children: pages,
        ),
      ),
    );
  }
}
