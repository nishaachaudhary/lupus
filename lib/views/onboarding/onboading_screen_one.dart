import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Needed for SystemChrome
import 'package:get/get.dart';

import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/constant/images.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/views/onboarding/onboading_controller.dart';

class OnboardingPage1 extends StatelessWidget {
  final controller = Get.find<OnboardingController>();

  Widget buildIndicator(int index) {
    return Obx(() {
      bool isActive = controller.currentPage.value == index;
      return AnimatedContainer(
        duration: Duration(milliseconds: 300),
        margin: EdgeInsets.symmetric(horizontal: 4),
        height: 10,
        width: isActive ? 25 : 10,
        decoration: BoxDecoration(
          color: CustomColors.greenColor,
          borderRadius: BorderRadius.circular(10),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Set the status bar to dark icons (black)
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Column(
          children: [
            Expanded(
              child: Image.asset(
                CustomImage.onboarding1,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),

            /// Bottom half with background and overlay
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      CustomImage.bg1,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),

                  /// Overlay text and button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Track Your Symptoms & Triggers',
                          style: boldStyle.copyWith(
                            fontSize: Dimensions.fontSizeBigger,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Easily log daily symptoms and identify triggers like stress, food, or weather changes.',
                          style: semiLightStyle.copyWith(
                            fontSize: Dimensions.fontSizeLarge,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// Indicator + Circular Next Button
                  Positioned(
                    bottom: 30,
                    left: 20,
                    right: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: List.generate(
                            3,
                                (index) => buildIndicator(index),
                          ),
                        ),
                        // You can enable the button if needed
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
