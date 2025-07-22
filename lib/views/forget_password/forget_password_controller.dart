import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lupus_care/data/api/auth_service.dart';
import 'package:lupus_care/style/colors.dart';

class ForgotPasswordController extends GetxController {
  TextEditingController emailController = TextEditingController();
  final AuthService _authService = AuthService();

  // Add loading state
  RxBool isLoading = false.obs;

  void sendCode() async {
    final email = emailController.text.trim();

    // Validate email
    if (email.isEmpty || !email.contains('@')) {
      Get.snackbar(
        "Invalid Email",
        "Please enter a valid email address.",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      // Set loading to true
      isLoading.value = true;

      print("Sending forgot password request for email: $email");

      final response = await _authService.forgotPassword(email: email);

      print("Forgot password response: $response");

      // IMPORTANT: Only navigate if response is successful
      if (response['status'] == 'success') {
        print("Forgot password API succeeded - navigating to OTP screen");

        // Show success message
        Get.snackbar(
          "Code Sent",
          response['message'] ?? "Reset code sent to your email.",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        // Navigate to OTP verification screen ONLY on success
        Get.toNamed('/otpVerification', arguments: {'email': email});
      } else {
        // API returned error status - DO NOT navigate
        print("Forgot password API failed with status: ${response['status']}");

        // Handle API error response
        String errorMessage = response['message'] ?? "Failed to send reset code";

        Get.snackbar(
          "Error",
          errorMessage,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );

        // DO NOT navigate - user stays on current screen
      }
    } catch (e) {
      // Handle network errors or exceptions - DO NOT navigate
      String errorMessage = e.toString();
      if (errorMessage.contains('Exception: ')) {
        errorMessage = errorMessage.split('Exception: ')[1];
      }

      print("Error in forgot password: $errorMessage");

      Get.snackbar(
        "Error",
        errorMessage,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );

      // DO NOT navigate - user stays on current screen
    } finally {
      // Set loading to false regardless of success or failure
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    emailController.dispose();
    super.onClose();
  }
}