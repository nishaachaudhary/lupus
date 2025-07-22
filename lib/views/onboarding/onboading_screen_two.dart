import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/images.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/views/onboarding/onboading_controller.dart';

class OnboardingPage2 extends StatelessWidget {
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
                  CustomImage.onboarding2,
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
                        CustomImage.bg2,
                        fit: BoxFit.cover, // Try BoxFit.contain or BoxFit.fitWidth if cover crops too much
                        alignment: Alignment.topCenter, // You can tweak this to see more top part
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
                            'Join a Supportive Community',
                            style:boldStyle.copyWith(fontSize: Dimensions.fontSizeBigger,color: Colors.white),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Connect with others managing lupus, share experiences, and get support from those who understand.',
                            style:semiLightStyle.copyWith(fontSize: Dimensions.fontSizeLarge,color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                    /// Indicator + Circular Next Button
                    Positioned(
                      bottom: 30,
                      left: 20,
                      right: 20, // allow spacing between both ends
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          /// Page indicator dots (left side)
                          Row(
                            children: List.generate(
                              3,
                                  (index) => buildIndicator(index),
                            ),
                          ),

                          /// Circular "Next" button (right side)
                          // ElevatedButton(
                          //   style: ElevatedButton.styleFrom(
                          //     backgroundColor: CustomColors.greenColor,
                          //     shape: const CircleBorder(),
                          //     padding: EdgeInsets.zero,
                          //     fixedSize: const Size(80, 80),
                          //   ),
                          //   onPressed: controller.nextPage,
                          //   child: Center(
                          //     child: Text(
                          //       "Next",
                          //       style: semiBoldStyle.copyWith(
                          //         fontSize: Dimensions.fontSizeLarge,
                          //         color: CustomColors.darkGreenColor,
                          //       ),
                          //     ),
                          //   ),
                          // ),
                        ],
                      ),
                    ),

                  ],
                ),
              ),
            ],
          )
      ),
    );


  }
}
