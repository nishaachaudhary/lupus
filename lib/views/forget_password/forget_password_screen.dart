import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/forget_password/forget_password_controller.dart';
import 'package:lupus_care/widgets/customTextflied.dart';

class ForgotPasswordScreen extends StatelessWidget {
  final ForgotPasswordController controller = Get.put(ForgotPasswordController());

  @override
  Widget build(BuildContext context) {
    // Set transparent status bar for immersive look (optional)
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );

    return Scaffold(
      backgroundColor: CustomColors.lightPurpleColor,
      body: Stack(
        children: [
          // Main content
          SizedBox.expand(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 50),
                  Container(
                    width: 41,
                    height: 41,
                    margin: const EdgeInsets.only(
                        top: Dimensions.fontSizeLarge, left: Dimensions.fontSizeExtraSmall),
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
                  const SizedBox(height: 20),
                  Text(
                    "Forgot Password?",
                    style: semiBoldStyle.copyWith(
                      fontSize: Dimensions.fontSizeBigger,
                      color: CustomColors.purpleColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Don't worry! It occurs. Please enter the email address linked with your account.",
                    style: semiLightStyle.copyWith(
                      fontSize: Dimensions.fontSizeLarge,
                      color: CustomColors.greyTextColor,
                    ),
                  ),
                  const SizedBox(height: 30),
                  CustomTextField(
                    titleStyle: mediumStyle.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                    ),
                    title: "Email",
                    controller: controller.emailController,
                    hintText: "Enter Email",
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: controller.sendCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CustomColors.greenColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "Send Code",
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

          // Full-screen loader overlay
          Obx(() => controller.isLoading.value
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
}