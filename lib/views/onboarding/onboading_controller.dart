import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lupus_care/helper/storage_service.dart';

class OnboardingController extends GetxController {
  final pageController = PageController();
  var currentPage = 0.obs;

  @override
  void onInit() {
    super.onInit();
    print('🎯 === ONBOARDING CONTROLLER INITIALIZED ===');
  }

  void onPageChanged(int index) {
    print('📄 Onboarding page changed to: $index');
    currentPage.value = index;
  }

  void nextPage() {
    print('➡️ Next page requested, current: ${currentPage.value}');

    if (currentPage.value < 2) { // Assuming 3 onboarding pages (0, 1, 2)
      pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.ease,
      );
      print('📄 Moving to next page: ${currentPage.value + 1}');
    } else {
      // User completed all onboarding slides
      print('🏁 All onboarding pages completed');
      completeOnboarding();
    }
  }

  void skipOnboarding() {
    print('⏭️ User chose to skip onboarding');
    // User chose to skip onboarding
    completeOnboarding();
  }

  void completeOnboarding() async {
    try {
      print('🎯 === ONBOARDING COMPLETION STARTED ===');

      // Show loading indicator
      Get.dialog(
        Center(
          child: CircularProgressIndicator(),
        ),
        barrierDismissible: false,
      );

      // Mark that the app has been used and onboarding has been seen
      await StorageService.to.markAppAsUsed();
      await StorageService.to.markLoginPageSeen(); // Mark that they've progressed past onboarding

      print('📱 App marked as used and login page marked as seen');

      // Small delay to ensure storage operations complete
      await Future.delayed(Duration(milliseconds: 500));

      // Close loading dialog
      if (Get.isDialogOpen == true) {
        Get.back();
      }

      // For new users who just completed onboarding, they need to create an account
      // So they should go to login/signup screen where they can choose to login or create account
      print('🔐 → LOGIN SCREEN (new user needs to create account or login)');

      // Use Get.offAllNamed to clear all previous routes and go to login
      Get.offAllNamed('/login');

      print('✅ Navigation to login screen completed');
      print('🎯 === ONBOARDING COMPLETION FINISHED ===');

    } catch (e) {
      print('❌ Error completing onboarding: $e');

      // Close loading dialog if open
      if (Get.isDialogOpen == true) {
        Get.back();
      }

      // Show error message
      Get.snackbar(
        'Error',
        'Failed to complete onboarding. Please try again.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );

      // Fallback to login after a short delay
      await Future.delayed(Duration(seconds: 2));
      Get.offAllNamed('/login');
    }
  }

  // Method to handle back button on onboarding
  void handleBackButton() {
    if (currentPage.value > 0) {
      pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.ease,
      );
      print('⬅️ Moving to previous page: ${currentPage.value - 1}');
    } else {
      // On first page, ask if user wants to exit app
      _showExitDialog();
    }
  }

  void _showExitDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Exit App?'),
        content: Text('Are you sure you want to exit Lupus Care?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              // Close the app (this might not work on all platforms)
              // SystemNavigator.pop();
            },
            child: Text('Exit'),
          ),
        ],
      ),
    );
  }

  @override
  void onClose() {
    print('🎯 Onboarding Controller disposed');
    pageController.dispose();
    super.onClose();
  }
}