import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/icons.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/create_new_password/create_new_password_controller.dart';
import 'package:lupus_care/widgets/customTextflied.dart';

class ResetPasswordScreen extends StatelessWidget {
  final ResetPasswordController controller =
  Get.put(ResetPasswordController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomColors.lightPurpleColor,
      resizeToAvoidBottomInset: true, // Important: This ensures proper keyboard handling
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
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
                "Create New Password",
                style: semiBoldStyle.copyWith(
                  fontSize: Dimensions.fontSizeBigger,
                  color: CustomColors.purpleColor,
                ),
              ),
              SizedBox(height: 10),
              Text(
                "Your new password must be unique from those previously used.",
                style: semiLightStyle.copyWith(
                  fontSize: Dimensions.fontSizeLarge,
                  color: CustomColors.greyTextColor,
                ),
              ),
              SizedBox(height: 30),

              Obx(() => CustomTextField(
                title: "New Password",
                controller: controller.passwordController,
                hintText: "Enter New Password",
                obscureText: !controller.isPasswordHidden.value,
                suffixIcon: IconButton(
                  icon: SvgPicture.asset(
                    controller.isPasswordHidden.value
                        ? CustomIcons.eyeOnIcon
                        : CustomIcons.eyeOffIcon,
                    width: 22,
                    height: 22,
                  ),
                  onPressed: controller.togglePasswordVisibility,
                  splashRadius: 20,
                ),
                titleStyle: mediumStyle.copyWith(fontSize: Dimensions.fontSizeDefault),
              )),

              // Password validation message
              Obx(() => controller.showPasswordValidation.value
                  ? Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                child: Text(
                  controller.getPasswordValidationMessage(),
                  style: regularStyle.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: controller.getValidationTextColor(controller.isPasswordValid.value),
                  ),
                ),
              )
                  : const SizedBox()),

              SizedBox(height: 20),

              Obx(() => CustomTextField(
                title: "Confirm New Password",
                controller: controller.confirmPasswordController,
                hintText: "Enter New Password",
                obscureText: !controller.isConfirmPasswordHidden.value,
                suffixIcon: IconButton(
                  icon: SvgPicture.asset(
                    controller.isConfirmPasswordHidden.value
                        ? CustomIcons.eyeOnIcon
                        : CustomIcons.eyeOffIcon,
                    width: 22,
                    height: 22,
                  ),
                  onPressed: controller.toggleConfirmPasswordVisibility,
                  splashRadius: 20,
                ),
                titleStyle: mediumStyle.copyWith(fontSize: Dimensions.fontSizeDefault),
              )),

              // Confirm password validation message
              Obx(() => controller.showConfirmPasswordValidation.value
                  ? Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                child: Text(
                  controller.getConfirmPasswordValidationMessage(),
                  style: regularStyle.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: controller.getValidationTextColor(controller.passwordsMatch.value),
                  ),
                ),
              )
                  : const SizedBox()),

              SizedBox(height: 30),

              // Enhanced button with loading state but same design
              Obx(() => SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: controller.isLoading.value ? null : controller.resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: controller.isLoading.value
                        ? Colors.grey.shade300
                        : CustomColors.greenColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: controller.isLoading.value
                      ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        CustomColors.darkGreenColor,
                      ),
                    ),
                  )
                      : Text(
                    "Reset Password",
                    style: semiBoldStyle.copyWith(
                      fontSize: Dimensions.fontSizeExtraLarge,
                      color: CustomColors.darkGreenColor,
                    ),
                  ),
                ),
              )),

              // Add extra space at bottom to ensure button is visible above keyboard
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 50),
            ],
          ),
        ),
      ),
    );
  }
}