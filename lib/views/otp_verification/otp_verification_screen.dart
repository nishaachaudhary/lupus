import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/otp_verification/otp_verification_controller.dart';

class OtpScreen extends StatelessWidget {
  final OtpController controller = Get.put(OtpController());

  Widget otpTextField(TextEditingController textController, BuildContext context, bool isFirst) {
    return Container(
      width: 50,
      height: 60,
      child: TextField(
        controller: textController,
        maxLength: 1,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        autofocus: isFirst, // Auto-focus first field
        style: semiBoldStyle.copyWith(
          fontSize: Dimensions.fontSizeExtraLarge,
          color: CustomColors.blackColor,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.symmetric(vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: CustomColors.purpleColor, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          fillColor: Colors.white,
          filled: true,
        ),
        onChanged: (value) {
          if (value.length == 1) {
            FocusScope.of(context).nextFocus();
          } else if (value.isEmpty) {
            FocusScope.of(context).previousFocus();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  const SizedBox(height: 40),
                  Container(
                    width: 41,
                    height: 41,
                    margin: const EdgeInsets.only(top: Dimensions.fontSizeLarge, left: Dimensions.fontSizeLarge),
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
                  SizedBox(height: 20),
                  Text(
                    "OTP Verification",
                    style: semiBoldStyle.copyWith(
                      fontSize: Dimensions.fontSizeBigger,
                      color: CustomColors.purpleColor,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Enter the verification code we just sent on your email address.",
                    style: semiLightStyle.copyWith(
                      fontSize: Dimensions.fontSizeLarge,
                      color: CustomColors.greyTextColor,
                    ),
                  ),
                  SizedBox(height: 40),

                  // Updated OTP fields with equal spacing
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: otpTextField(controller.otp1, context, true),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: otpTextField(controller.otp2, context, false),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: otpTextField(controller.otp3, context, false),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: otpTextField(controller.otp4, context, false),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: otpTextField(controller.otp5, context, false),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: otpTextField(controller.otp6, context, false),
                        ),
                      ],
                    ),
                  ),


                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: controller.verifyCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CustomColors.greenColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "Verify Code",
                        style: semiBoldStyle.copyWith(
                          fontSize: Dimensions.fontSizeExtraLarge,
                          color: CustomColors.darkGreenColor,
                        ),
                      ),
                    ),
                  )
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