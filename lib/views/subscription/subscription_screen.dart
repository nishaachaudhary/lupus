import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/subscription/subscription_controller.dart';

class SubscriptionScreen extends StatefulWidget {
  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late SubscriptionController controller;

  @override
  void initState() {
    super.initState();
    // Always get a fresh controller instance and ensure plans are loaded
    controller = Get.put(SubscriptionController(), tag: DateTime.now().toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomColors.lightPurpleColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Obx(() => _buildMainContent()),

            // Full-page loading overlay
            Obx(() => _buildLoadingOverlay()),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    // Show loading indicator for initial data loading
    if (controller.isLoading.value) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                color: CustomColors.purpleColor,
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Loading subscription plans...",
              style: mediumStyle.copyWith(
                fontSize: Dimensions.fontSizeDefault,
              ),
            ),

          ],
        ),
      );
    }

    // Show error message if plans failed to load
    if (controller.errorMessage.value.isNotEmpty || controller.subscriptionPlans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              color: CustomColors.darkredColor,
              size: 60,
            ),
            const SizedBox(height: 20),
            Text(
              "Unable to Load Plans",
              style: mediumStyle.copyWith(
                fontSize: Dimensions.fontSizeLarge,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                controller.errorMessage.value.isNotEmpty
                    ? controller.errorMessage.value
                    : "We couldn't load the subscription plans. Please check your internet connection and try again.",
                textAlign: TextAlign.center,
                style: semiLightStyle.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                  color: CustomColors.greyTextColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: controller.skipSubscription,
              child: Text(
                "Skip for now",
                style: semiLightStyle.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                  color: CustomColors.greyTextColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Get plans from controller
    final freePlan = controller.freePlan;
    final premiumPlan = controller.premiumPlan;

    // If specific plans are missing, show partial error
    if (freePlan == null && premiumPlan == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              color: CustomColors.purpleColor,
              size: 60,
            ),
            const SizedBox(height: 20),
            Text(
              "No Subscription Plans Available",
              style: mediumStyle.copyWith(
                fontSize: Dimensions.fontSizeLarge,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "We loaded ${controller.subscriptionPlans.length} plans but none match the expected format. Please contact support.",
                textAlign: TextAlign.center,
                style: semiLightStyle.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                  color: CustomColors.greyTextColor,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    // Show successful loaded plans
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header
          Center(
            child: Text(
              "Subscription",
              textAlign: TextAlign.center,
              style: mediumStyle.copyWith(
                fontSize: Dimensions.fontSizeLarger,
              ),
            ),
          ),

          const SizedBox(height: 10),

          Center(
            child: Text(
              "Choose Subscription Plan",
              textAlign: TextAlign.center,
              style: mediumStyle.copyWith(
                fontSize: Dimensions.fontSizeLarger,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Choose a plan that fits your needs—track symptoms, manage medications, and connect with the community",
            textAlign: TextAlign.center,
            style: semiLightStyle.copyWith(
                fontSize: Dimensions.fontSizeDefault,
                color: CustomColors.greyTextColor
            ),
          ),
          const SizedBox(height: 30),

          // Free Plan Card (if available)
          if (freePlan != null) ...[
            _buildPlanCard(
              title: freePlan['name']?.toString() ?? "Free Trial",
              price: freePlan['price']?.toString() ?? "0.00",
              subtitle: "7-day Free trial",
              isSelected: controller.selectedPlan.value == freePlan['id'].toString(),
              onTap: () => controller.selectPlan(freePlan['id'].toString()),
              color: Colors.white,
              borderColor: CustomColors.purpleColor,
            ),
            const SizedBox(height: 16),
          ],

          // Premium Plan Card (if available)
          if (premiumPlan != null) ...[
            _buildPlanCard(
              title: premiumPlan['name']?.toString() ?? "Monthly",
              price: premiumPlan['price']?.toString() ?? "N/A",
              subtitle: "Perfect for Experience",
              features: ["Unlocks advanced tracking insights", "Unlimited Chat", "Detailed Medication History"],
              isSelected: controller.selectedPlan.value == premiumPlan['id'].toString(),
              onTap: () => controller.selectPlan(premiumPlan['id'].toString()),
              color: Colors.white,
              borderColor: CustomColors.purpleColor,
            ),
            const SizedBox(height: 16),
          ],

          // Show message if only one plan type is available
          if (freePlan == null && premiumPlan != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Free trial not available. Only premium plans are currently offered.",
                      style: semiLightStyle.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (premiumPlan == null && freePlan != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Only free trial is currently available. Premium plans coming soon!",
                      style: semiLightStyle.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: Colors.blue[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 24),

          // Subscribe Button - Only show if we have plans and a selection
          if (controller.subscriptionPlans.isNotEmpty && controller.selectedPlan.value.isNotEmpty) ...[
            SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: controller.isPurchasing.value
                    ? null
                    : () {
                  controller.testRevenueCatConnection();
                  controller.subscribe();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: controller.isPurchasing.value
                      ? Colors.grey
                      : CustomColors.greenColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  "Subscribe Now",
                  style: semiBoldStyle.copyWith(
                      fontSize: Dimensions.fontSizeExtraLarge,
                      color: controller.isPurchasing.value
                          ? Colors.white70
                          : CustomColors.darkGreenColor
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            // Show message if no selection is made
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Please select a subscription plan to continue",
                textAlign: TextAlign.center,
                style: semiLightStyle.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                  color: CustomColors.greyTextColor,
                ),
              ),
            ),
          ],

          // Bottom padding to ensure button is fully visible
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    if (!controller.isPurchasing.value) {
      return const SizedBox.shrink();
    }

    return  Center(
      child:  Container(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(
          strokeWidth: 4,
          valueColor: AlwaysStoppedAnimation<Color>(CustomColors.purpleColor),
        ),
      ),
    );
  }

  Widget _buildLoadingStep(String label, bool isActive) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? CustomColors.purpleColor : Colors.grey[300],
            shape: BoxShape.circle,
          ),
        ),
        if (label != "Completing") ...[
          Container(
            width: 20,
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: isActive ? CustomColors.purpleColor : Colors.grey[300],
          ),
        ],
      ],
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    String subtitle = "",
    List<String> features = const ["Symptoms Tracking", "Chat With limited messages", "Basic Medication Logging"],
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
    required Color borderColor,
  }) {
    return GestureDetector(
      onTap: controller.isPurchasing.value ? null : onTap, // Disable tap during purchase
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: controller.isPurchasing.value
              ? Colors.grey[100]
              : (isSelected ? CustomColors.lightPinkColor : Colors.white),
          border: Border.all(
            color: controller.isPurchasing.value
                ? Colors.grey[300]!
                : (isSelected ? CustomColors.purpleColor : CustomColors.textBorderColor),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected && !controller.isPurchasing.value
              ? [
            BoxShadow(
              color: CustomColors.purpleColor.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ]
              : null,
        ),
        child: Opacity(
          opacity: controller.isPurchasing.value ? 0.6 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: controller.isPurchasing.value
                    ? Colors.grey
                    : CustomColors.purpleColor,
                size: 24,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Center-aligned title
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: semiLightStyle.copyWith(
                              fontSize: Dimensions.fontSizeDefault,
                            ),
                          ),
                        ),
                        if (title.toLowerCase().contains("monthly") ||
                            title.toLowerCase().contains("premium")) ...[
                          const SizedBox(height: 8),
                          // Left-aligned price row
                          Row(
                            children: [
                              Text(
                                price == "N/A" ? "N/A" : "\$${price}",
                                textAlign: TextAlign.left,
                                style: mediumStyle.copyWith(
                                  fontSize: Dimensions.fontSizeLarger,
                                  color: price == "N/A" ? Colors.red : null,
                                ),
                              ),
                              if (price != "N/A") ...[
                                Text(
                                  " / ",
                                  textAlign: TextAlign.left,
                                  style: mediumStyle.copyWith(
                                    fontSize: Dimensions.fontSizeLarger,
                                    color: CustomColors.greyTextColor,
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Text(
                                    "Month",
                                    textAlign: TextAlign.end,
                                    style: mediumStyle.copyWith(
                                      fontSize: Dimensions.fontSizeDefault,
                                      color: CustomColors.greyTextColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          // Left-aligned subtitle
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              subtitle,
                              textAlign: TextAlign.left,
                              style: semiLightStyle.copyWith(
                                fontSize: Dimensions.fontSizeDefault,
                                color: CustomColors.purpleColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "You Get",
                          style: semiLightStyle.copyWith(
                            fontSize: Dimensions.fontSizeSmall,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Only show up to 3 features to maintain design
                        ...(features.take(3).map((feature) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check,
                                size: 16,
                                color: CustomColors.purpleColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: semiLightStyle.copyWith(
                                    fontSize: Dimensions.fontSizeSmall,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )).toList()),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up the controller when the screen is disposed
    // if (Get.isRegistered<SubscriptionController>()) {
    //   Get.delete<SubscriptionController>();
    // }
    super.dispose();
  }
}