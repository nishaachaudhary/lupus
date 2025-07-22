import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/data/api/auth_service.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';

class DeleteConfirmDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final String userId;

  const DeleteConfirmDialog({
    super.key,
    required this.onConfirm,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Close icon
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Delete Account",
                  style: mediumStyle.copyWith(
                    fontSize: Dimensions.fontSizeExtraLarge,
                    color: const Color(0xFF535353),
                  ),),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          Divider(
            height: 2,
            thickness: 0.89,
            color: Colors.grey.shade300,
          ),

          const SizedBox(height: 2),
          // Message
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
                "Are you sure you want to Delete your Account?",
                textAlign: TextAlign.center,
                style: semiLightStyle.copyWith(
                    fontSize: 20,
                    color: Color(0xff6B7280)
                )
            ),
          ),
          const SizedBox(height: 2),

          Divider(
            height: 2,
            thickness: 0.89,
            color: Colors.grey.shade300,
          ),

          const SizedBox(height: 4),
          // Buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 51,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CustomColors.buttonGrey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(38),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel",
                          style: semiBoldStyle.copyWith(
                              fontSize: Dimensions.fontSizeExtraLarge,
                              color: Colors.white
                          )),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 51,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CustomColors.darkredColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(38),
                        ),
                      ),
                      onPressed: () => _deleteAccount(context),
                      child: Text("Delete",
                          style: semiBoldStyle.copyWith(
                              fontSize: Dimensions.fontSizeExtraLarge,
                              color: Colors.white
                          )),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    // Close the confirmation dialog first
    Navigator.pop(context);

    // Use Get.dialog instead of context-based showDialog for the loading indicator
    // This ensures we can dismiss it regardless of context state
    Get.dialog(
      const Center(
        child: CircularProgressIndicator(),
      ),
      barrierDismissible: false,
    );

    try {
      // Call the delete API
      final authService = AuthService();
      final response = await authService.deleteAccount(userId: userId);

      print("Delete API response received: ${response['status']}");

      // Close the loading dialog using Get, which doesn't rely on context
      Get.back();

      if (response['status'] == 'success') {
        // Call the onConfirm callback which should handle storage clearing and navigation
        print("Account deletion successful. Calling onConfirm...");
        // Use a small delay to ensure the dialog is fully closed
        await Future.delayed(const Duration(milliseconds: 100));
        onConfirm();
      } else {
        // Show error message using GetX
        Get.snackbar(
          'Error',
          response['message'] ?? 'Failed to delete account',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print("Error in _deleteAccount: $e");

      // Close the loading dialog using Get
      Get.back();

      // Show error using GetX
      Get.snackbar(
        'Error',
        'An error occurred: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}