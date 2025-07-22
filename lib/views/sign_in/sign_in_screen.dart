import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/icons.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/sign_in/sign_in_controller.dart';
import 'package:lupus_care/widgets/customTextflied.dart';

class SignupScreen extends StatefulWidget {
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final SignupController controller = Get.put(SignupController());
  final ScrollController _scrollController = ScrollController();

  // Focus nodes for each text field
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  // GlobalKeys to get widget positions
  final GlobalKey _nameFieldKey = GlobalKey();
  final GlobalKey _emailFieldKey = GlobalKey();
  final GlobalKey _passwordFieldKey = GlobalKey();
  final GlobalKey _confirmPasswordFieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    // Add listeners to all focus nodes for controlled scrolling
    _nameFocusNode.addListener(() => _handleFocusChange(_nameFieldKey));
    _emailFocusNode.addListener(() => _handleFocusChange(_emailFieldKey));
    _passwordFocusNode.addListener(() => _handleFocusChange(_passwordFieldKey));
    _confirmPasswordFocusNode.addListener(() => _handleFocusChange(_confirmPasswordFieldKey));
  }

  void _handleFocusChange(GlobalKey fieldKey) {
    if (fieldKey.currentContext != null) {
      Future.delayed(Duration(milliseconds: 350), () {
        if (mounted && fieldKey.currentContext != null) {
          Scrollable.ensureVisible(
            fieldKey.currentContext!,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
            // Add some padding above the focused field
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light),
      child: Scaffold(
        backgroundColor: CustomColors.lightPurpleColor,
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            // Fixed Header Section
            Container(
              color: CustomColors.lightPurpleColor,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 24.0,
                    top: 24.0,
                    right: 24.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back button
                      Container(
                        width: 41,
                        height: 41,
                        margin: const EdgeInsets.only(
                            top: Dimensions.fontSizeLarge,
                            left: Dimensions.fontSizeExtraSmall),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(width: 1, color: Colors.grey.shade300),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                          onPressed: () => Navigator.pop(context),
                          splashRadius: 20,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Title
                      Text(
                        "Sign Up to Begin Your Journey",
                        style: semiBoldStyle.copyWith(
                          fontSize: Dimensions.fontSizeBigger,
                          color: CustomColors.purpleColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // Scrollable Content Section
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 24.0,
                    right: 24.0,
                    // Reduced bottom padding to prevent over-scrolling
                    bottom: 24.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Full Name field with error message
                      Column(
                        key: _nameFieldKey, // Add key for position tracking
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomTextField(
                            titleStyle: mediumStyle.copyWith(
                                fontSize: Dimensions.fontSizeDefault),
                            title: "Full Name",
                            controller: controller.nameController,
                            hintText: "Enter Full name",
                            focusNode: _nameFocusNode, // Add focus node
                            onChanged: (value) {
                              if (value.length > 30) {
                                controller.nameError.value = 'Name must be 30 characters or less';
                              }
                            },
                          ),
                          // Name error message
                          Obx(() => controller.nameError.value.isNotEmpty
                              ? Container(
                            margin: const EdgeInsets.only(top: 4, left: 4),
                            child: Text(
                              controller.nameError.value,
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
                      const SizedBox(height: 10),

                      // Email field with error message
                      Column(
                        key: _emailFieldKey, // Add key for position tracking
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomTextField(
                            titleStyle: mediumStyle.copyWith(
                                fontSize: Dimensions.fontSizeDefault),
                            title: "Email",
                            controller: controller.emailController,
                            hintText: "Enter Email",
                            focusNode: _emailFocusNode, // Add focus node
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
                      const SizedBox(height: 10),

                      // Password field with error message
                      Column(
                        key: _passwordFieldKey, // Add key for position tracking
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Obx(() => CustomTextField(
                            title: "Password",
                            controller: controller.passwordController,
                            hintText: "Enter Password",
                            focusNode: _passwordFocusNode, // Add focus node
                            obscureText: !controller.isPasswordVisible.value,
                            suffixIcon: IconButton(
                              icon: SvgPicture.asset(
                                controller.isPasswordVisible.value
                                    ? CustomIcons.eyeOnIcon
                                    : CustomIcons.eyeOffIcon,
                                width: 22,
                                height: 22,
                              ),
                              onPressed: controller.togglePasswordVisibility,
                              splashRadius: 20,
                            ),
                            titleStyle: mediumStyle.copyWith(
                                fontSize: Dimensions.fontSizeDefault),
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
                      const SizedBox(height: 10),

                      // Confirm Password field with error message
                      Column(
                        key: _confirmPasswordFieldKey, // Add key for position tracking
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Obx(() => CustomTextField(
                            title: "Confirm Password",
                            controller: controller.confirmPasswordController,
                            hintText: "Confirm Password",
                            focusNode: _confirmPasswordFocusNode,
                            obscureText: !controller.isConfirmPasswordVisible.value,
                            suffixIcon: IconButton(
                              icon: SvgPicture.asset(
                                controller.isConfirmPasswordVisible.value
                                    ? CustomIcons.eyeOnIcon
                                    : CustomIcons.eyeOffIcon,
                                width: 22,
                                height: 22,
                              ),
                              onPressed: controller.toggleConfirmPasswordVisibility,
                            ),
                            titleStyle: mediumStyle.copyWith(
                                fontSize: Dimensions.fontSizeDefault),
                          )),
                          // Confirm Password error message
                          Obx(() => controller.confirmPasswordError.value.isNotEmpty
                              ? Container(
                            margin: const EdgeInsets.only(top: 4, left: 4),
                            child: Text(
                              controller.confirmPasswordError.value,
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

                      // Register button with loading state
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
                          onPressed: (controller.isLoading.value && !controller.isGoogleLoading.value && !controller.isAppleLoading.value)
                              ? null
                              : controller.register,
                          child: Text(
                            "Register Account",
                            style: semiBoldStyle.copyWith(
                              fontSize: Dimensions.fontSizeExtraLarge,
                              color: CustomColors.darkGreenColor,
                            ),
                          ),
                        ),
                      )),

                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Already have an account? ",
                              style: semiBoldStyle.copyWith(
                                fontSize: Dimensions.fontSizeDefault,
                                color: CustomColors.greyTextColor,
                              )),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Text(
                              "Login",
                              style: semiBoldStyle.copyWith(
                                fontSize: Dimensions.fontSizeDefault,
                                color: CustomColors.purpleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          const Expanded(
                              child: Divider(color: CustomColors.greyTextColor)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text("Or Signup with",
                                style: semiLightStyle.copyWith(
                                  fontSize: Dimensions.fontSizeDefault,
                                  color: CustomColors.greyTextColor,
                                )),
                          ),
                          const Expanded(
                              child: Divider(color: CustomColors.greyTextColor)),
                        ],
                      ),

                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Google Sign-In Button
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

                          // Apple Sign-In Button
                          Obx(() => GestureDetector(
                            onTap: controller.isAppleLoading.value
                                ? null
                                : () {
                              controller.signInWithApple();
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

                      // Add extra space for better keyboard handling
                      SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 100 : 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}