import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/icons.dart';
import 'package:lupus_care/helper/storage_service.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/widgets/customTextflied.dart';
import 'package:lupus_care/views/login/login_controller.dart';
import 'package:flutter/foundation.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Initialize the controller using Get.put to ensure it's created
  final LoginController controller = Get.put(LoginController());

  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markLoginPageSeen();

    });
  }

  // Add this method to force refresh text fields
  // void _refreshTextFields() {
  //   // Force refresh email field if it has content
  //   if (controller.emailController.text.isNotEmpty) {
  //     final email = controller.emailController.text;
  //     controller.emailController.value = controller.emailController.value.copyWith(
  //       text: email,
  //       selection: TextSelection.collapsed(offset: email.length),
  //     );
  //   }
  //
  //   // Force refresh password field if it has content
  //   if (controller.passwordController.text.isNotEmpty) {
  //     final password = controller.passwordController.text;
  //     controller.passwordController.value = controller.passwordController.value.copyWith(
  //       text: password,
  //       selection: TextSelection.collapsed(offset: password.length),
  //     );
  //   }
  // }

  Future<void> _markLoginPageSeen() async {
    try {
      print('🔧 SIMPLE: Marking login page as seen');

      if (Get.isRegistered<StorageService>() && StorageService.to.isInitialized) {
        // Method 1: Use the existing method
        await StorageService.to.markLoginPageSeen();
        print('✅ markLoginPageSeen() called');

        // Method 2: Also mark app as used
        await StorageService.to.markAppAsUsed();
        print('✅ markAppAsUsed() called');

        // Verify it worked
        final seenLogin = StorageService.to.hasSeenLogin();
        final usedApp = StorageService.to.hasUsedAppBefore();

        print('🔍 Verification:');
        print('   - hasSeenLogin(): $seenLogin');
        print('   - hasUsedAppBefore(): $usedApp');
      } else {
        print('⚠️ StorageService not available');
      }
    } catch (e) {
      print('❌ Error marking login page as seen: $e');
    }
  }

  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // for Android
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: CustomColors.lightPurpleColor,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 80),

              Text(
                "Welcome back! Glad to see you, Again!",
                style: boldStyle.copyWith(
                  fontSize: Dimensions.fontSizeBigger,
                  color: CustomColors.purpleColor,
                ),
              ),
              const SizedBox(height: 24),

              // Email field with error message
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomTextField(
                    titleStyle: mediumStyle.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                    ),
                    title: "Enter Email",
                    controller: controller.emailController,
                    hintText: "Enter your email",
                  ),
                  // Email error message
                  Obx(() => controller.emailError.value.isNotEmpty
                      ? Container(
                    margin: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      controller.emailError.value,
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: Dimensions.fontSizeSmall,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  )
                      : const SizedBox.shrink()),
                ],
              ),

              const SizedBox(height: 16),

              // Password field with error message
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Obx(() => CustomTextField(
                    titleStyle: mediumStyle.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                    ),
                    title: "Password",
                    obscureText: !controller.isPasswordVisible.value,
                    controller: controller.passwordController,
                    hintText: "Enter your password",
                    suffixIcon: IconButton(
                      icon: SvgPicture.asset(
                        controller.isPasswordVisible.value
                            ? CustomIcons.eyeOnIcon
                            : CustomIcons.eyeOffIcon,
                        width: 22,
                        height: 22,
                      ),
                      onPressed: () => controller.togglePasswordVisibility(),
                    ),
                  )),
                  // Password error message
                  Obx(() => controller.passwordError.value.isNotEmpty
                      ? Container(
                    margin: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      controller.passwordError.value,
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: Dimensions.fontSizeSmall,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  )
                      : const SizedBox.shrink()),
                ],
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Get.toNamed('/forgetPassword'),
                  child: Text(
                    "Forgot Password?",
                    style: mediumStyle.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: CustomColors.purpleColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Login button with loading state
              Obx(() => SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CustomColors.greenColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: controller.isLoading.value
                        ? null
                        : () => controller.login(),
                    child: Text(
                      "Login",
                      style: semiBoldStyle.copyWith(
                        fontSize: Dimensions.fontSizeExtraLarge,
                        color: CustomColors.darkGreenColor,
                      ),
                    ),
                  ))),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account? ",
                      style: semiBoldStyle.copyWith(
                        fontSize: Dimensions.fontSizeDefault,
                        color: CustomColors.greyTextColor,
                      )),
                  GestureDetector(
                    onTap: () => Get.toNamed('/signup'),
                    child: Text(
                      "Signup",
                      style: semiBoldStyle.copyWith(
                        fontSize: Dimensions.fontSizeDefault,
                        color: CustomColors.purpleColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(child: Divider(color: CustomColors.greyColor)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      "Or Login with",
                      style: semiLightStyle.copyWith(
                        fontSize: Dimensions.fontSizeDefault,
                        color: CustomColors.greyColor,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: CustomColors.greyColor)),
                ],
              ),

              const SizedBox(height: 16),

              // FIXED: Clean Google Sign-In button without auto-triggering
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Google Sign-In Button - ONLY calls signInWithGoogle() when tapped
                  Obx(() => GestureDetector(
                    onTap: controller.isGoogleLoading.value
                        ? null
                        : () {
                      controller.signInWithGoogle();
                    },
                    child: Container(
                      width: 105,
                      height: 56,
                      margin: const EdgeInsets.only(top: Dimensions.fontSizeLarge),
                      padding: const EdgeInsets.all(Dimensions.fontSizeDefault),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          width: 1,
                          color: Colors.grey.shade300,
                        ),
                      ),
                      child: controller.isGoogleLoading.value
                          ? const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : SvgPicture.asset(
                        CustomIcons.googleIcon,
                        width: 26,
                        height: 26,
                      ),
                    ),
                  )),

                  const SizedBox(width: 20),



                  Obx(() => GestureDetector(
                    onTap: () {
                      // controller.signInWithApple();
                    },
                    child: Container(
                      width: 105,
                      height: 56,
                      margin: const EdgeInsets.only(top: Dimensions.fontSizeLarge),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(width: 1, color: Colors.grey.shade300),
                      ),
                      child: controller.isAppleLoading.value
                          ? const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : Center(
                        child: FaIcon(
                          FontAwesomeIcons.apple,
                          color: Colors.black,
                          size: 26,
                        ),
                      ),
                    ),
                  )),

                ],
              ),


              const SizedBox(height: 20),


            ],
          ),
        ),
      ),
    );
  }

  // Helper method for debug buttons
  Widget _buildDebugButton(String text, VoidCallback onPressed) {
    return SizedBox(
      height: 30,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade300,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: const TextStyle(fontSize: 10),
        ),
        child: Text(text),
      ),
    );
  }
}

