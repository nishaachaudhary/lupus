import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lupus_care/data/api/auth_service.dart';
import 'package:lupus_care/helper/storage_service.dart';
import 'package:lupus_care/style/colors.dart';

class OtpController extends GetxController {
  final TextEditingController otp1 = TextEditingController();
  final TextEditingController otp2 = TextEditingController();
  final TextEditingController otp3 = TextEditingController();
  final TextEditingController otp4 = TextEditingController();
  final TextEditingController otp5 = TextEditingController();
  final TextEditingController otp6 = TextEditingController();

  final AuthService _authService = AuthService();

  // Add loading state
  RxBool isLoading = false.obs;



  void verifyCode() async {
    final otp = otp1.text + otp2.text + otp3.text + otp4.text + otp5.text + otp6.text;

    // Validate OTP length
    if (otp.length < 6) {
      Get.snackbar(
        "Error",
        "Please enter the complete 6-digit code.",

        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // Check if all digits are entered
    if (otp1.text.isEmpty || otp2.text.isEmpty || otp3.text.isEmpty ||
        otp4.text.isEmpty || otp5.text.isEmpty || otp6.text.isEmpty) {
      Get.snackbar(
        "Error",
        "Please fill all OTP fields.",

        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {

      isLoading.value = true;

      // Get user ID from storage
      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString();


      print("Verifying OTP: $otp for user ID: $userId");

      final response = await _authService.confirmOtp(otp: otp);

      print("OTP verification response: $response");

      // Check if response is successful
      if (response['status'] == 'success') {
        // Show success message
        Get.snackbar(
          "Success",
          response['message'] ?? "OTP Verified Successfully",

          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,

        );

        // Navigate to reset password screen
        Get.toNamed('/resetPassword');
      } else {
        // Handle API error response
        throw Exception(response['message'] ?? "OTP verification failed");
      }
    } catch (e) {
      // Handle error
      String errorMessage = e.toString();
      if (errorMessage.contains('Exception: ')) {
        errorMessage = errorMessage.split('Exception: ')[1];
      }

      print("Error in OTP verification: $errorMessage");

      Get.snackbar(
        "Verification Failed",
        errorMessage,

        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,

      );
    } finally {
      // Set loading to false regardless of success or failure
      isLoading.value = false;
    }
  }

  // Method to clear all OTP fields
  void clearOtp() {
    otp1.clear();
    otp2.clear();
    otp3.clear();
    otp4.clear();
    otp5.clear();
    otp6.clear();
  }

  // Get complete OTP string
  String get completeOtp {
    return otp1.text + otp2.text + otp3.text + otp4.text + otp5.text + otp6.text;
  }

  // Check if OTP is complete
  bool get isOtpComplete {
    return completeOtp.length == 6;
  }

  @override
  void onClose() {
    otp1.dispose();
    otp2.dispose();
    otp3.dispose();
    otp4.dispose();
    otp5.dispose();
    otp6.dispose();
    super.onClose();
  }
}