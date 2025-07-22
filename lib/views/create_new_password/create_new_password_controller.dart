import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lupus_care/data/api/auth_service.dart';
import 'package:lupus_care/helper/storage_service.dart';

class ResetPasswordController extends GetxController {
  var isPasswordHidden = true.obs;
  var isConfirmPasswordHidden = true.obs;
  var isLoading = false.obs;

  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();

  // Password validation reactive variables
  var isPasswordValid = false.obs;
  var hasMinLength = false.obs;
  var hasUppercase = false.obs;
  var hasLowercase = false.obs;
  var hasNumber = false.obs;
  var hasSpecialChar = false.obs;
  var passwordsMatch = false.obs;
  var showPasswordValidation = false.obs;
  var showConfirmPasswordValidation = false.obs;

  final AuthService _authService = AuthService();

  @override
  void onInit() {
    super.onInit();
    // Listen to password changes for real-time validation
    passwordController.addListener(_validatePassword);
    confirmPasswordController.addListener(_checkPasswordsMatch);
  }

  void togglePasswordVisibility() {
    isPasswordHidden.value = !isPasswordHidden.value;
  }

  void toggleConfirmPasswordVisibility() {
    isConfirmPasswordHidden.value = !isConfirmPasswordHidden.value;
  }

  // Real-time password validation
  void _validatePassword() {
    final password = passwordController.text;

    // Show validation after user starts typing
    showPasswordValidation.value = password.isNotEmpty;

    // Check each validation criteria
    hasMinLength.value = password.length >= 8;
    hasUppercase.value = password.contains(RegExp(r'[A-Z]'));
    hasLowercase.value = password.contains(RegExp(r'[a-z]'));
    hasNumber.value = password.contains(RegExp(r'[0-9]'));
    hasSpecialChar.value = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    // Overall password validity
    isPasswordValid.value = hasMinLength.value &&
        hasUppercase.value &&
        hasLowercase.value &&
        hasNumber.value &&
        hasSpecialChar.value;

    // Re-check password match when password changes
    _checkPasswordsMatch();
  }

  // Check if passwords match
  void _checkPasswordsMatch() {
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    // Show validation after user starts typing in confirm password field
    showConfirmPasswordValidation.value = confirmPassword.isNotEmpty;

    passwordsMatch.value = password.isNotEmpty &&
        confirmPassword.isNotEmpty &&
        password == confirmPassword;
  }

  // Get password validation message
  String getPasswordValidationMessage() {
    if (!showPasswordValidation.value) return '';

    List<String> failedCriteria = [];

    if (!hasMinLength.value) failedCriteria.add("At least 8 characters");
    if (!hasUppercase.value) failedCriteria.add("One uppercase letter");
    if (!hasLowercase.value) failedCriteria.add("One lowercase letter");
    if (!hasNumber.value) failedCriteria.add("One number");
    if (!hasSpecialChar.value) failedCriteria.add("One special character");

    if (failedCriteria.isEmpty) {
      return "";
    } else {
      return "Required: ${failedCriteria.join(', ')}";
    }
  }

  // Get confirm password validation message
  String getConfirmPasswordValidationMessage() {
    if (!showConfirmPasswordValidation.value) return '';

    if (passwordsMatch.value) {
      return "";
    } else {
      return "";
    }
  }

  // Get validation text color
  Color getValidationTextColor(bool isValid) {
    return isValid ? Colors.green : Colors.red;
  }

  // Enhanced reset password method with full validation and API integration
  void resetPassword() async {
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    // Basic validation
    if (password.isEmpty || confirmPassword.isEmpty) {
      Get.snackbar(
        "Error",
        "Please fill in both password fields",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // Password strength validation - removed snackbar, validation shown inline
    if (!isPasswordValid.value) {
      // Validation messages are shown inline below the fields
      return;
    }

    // Password match validation - removed snackbar, validation shown inline
    if (!passwordsMatch.value) {
      // Validation messages are shown inline below the fields
      return;
    }

    try {
      isLoading.value = true;

      // Get user data from storage (saved during forgot password flow)
      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString();
      final email = userData?['email'];

      if (userId == null || email == null) {
        throw Exception("User session not found. Please start the process again.");
      }

      print("🔄 Resetting password for user ID: $userId, email: $email");

      // Call reset password API
      final response = await _authService.resetPassword(
        userId: userId,
        newPassword: password,
        confirmPassword: confirmPassword,
      );

      print("Reset password response: $response");

      if (response['status'] == 'success') {
        // Clear temporary user data from forgot password flow
        await StorageService.to.clearAll();

        Get.snackbar(
          "Success",
          response['message'] ?? "Password reset successfully",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        // Navigate to login screen
        Get.offAllNamed('/login');
      } else {
        throw Exception(response['message'] ?? "Password reset failed");
      }

    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('Exception: ')) {
        errorMessage = errorMessage.split('Exception: ')[1];
      }

      print("❌ Reset password error: $errorMessage");

      Get.snackbar(
        "Reset Failed",
        errorMessage,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Check if the form is ready for submission
  bool get canSubmit {
    return isPasswordValid.value && passwordsMatch.value && !isLoading.value;
  }

  @override
  void onClose() {
    passwordController.removeListener(_validatePassword);
    confirmPasswordController.removeListener(_checkPasswordsMatch);
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}