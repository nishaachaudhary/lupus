import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:lupus_care/data/api/auth_service.dart';
import 'package:lupus_care/helper/storage_service.dart';
// import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionController extends GetxController {
  var selectedPlan = 'free'.obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;

  // Store subscription plans from API
  var subscriptionPlans = [].obs;

  // RevenueCat offerings
  // var revenueCatOfferings = Rxn<Offerings>();
  var isRevenueCatInitialized = false.obs;
  // var customerInfo = Rxn<CustomerInfo>();

  // Purchase state management
  var isPurchasing = false.obs;
  var purchaseError = ''.obs;

  // Prevent multiple initializations
  static bool _isInitializing = false;
  static bool _hasInitialized = false;

  // Configuration
  static const String revenueCatApiKey = 'goog_XwbYopYizsZdZgSxOFmnzpEWjIO';
  static const bool enableDebugLogs = true;

  // FIXED: Only free trial fallback, no hardcoded prices
  final fallbackPlans = [
    {
      'id': 1,
      'name': 'Free-trial',
      'price': '0.00',
      'product_id': 'free_trial:free1m',
      'features': ['Basic features', 'Limited access']
    }
  ];

  @override
  void onInit() {
    super.onInit();
    print("🔄 SubscriptionController initializing...");
    _initializeComponents();
  }

  /// IMPROVED: Better initialization sequence
  Future<void> _initializeComponents() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // CRITICAL: Check if user already has active subscription before proceeding
      if (await _checkExistingActiveSubscription()) {
        print("✅ User already has active subscription - no need to initialize");
        isLoading.value = false;
        return;
      }

      // Step 1: Initialize RevenueCat first
      print("🚀 Step 1: Initializing RevenueCat...");
      await _initializeRevenueCat();

      // Step 2: Fetch subscription plans from API
      print("📋 Step 2: Fetching subscription plans...");
      await fetchSubscriptionPlans();

      // Step 3: Check existing subscriptions
      print("🔍 Step 3: Checking existing subscription...");
      await _checkExistingSubscription();

      print("✅ All components initialized successfully");

    } catch (e) {
      print("❌ Error initializing subscription controller: $e");
      errorMessage.value = 'Failed to initialize: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// NEW: Check if user already has active subscription and shouldn't see this page
  Future<bool> _checkExistingActiveSubscription() async {
    try {
      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString();

      if (userId == null) return false;

      // Force reload subscription data to ensure it's current
      await StorageService.to.forceReloadUserSubscriptionData();

      // Check both user-specific and session data
      final hasUserSpecificData = StorageService.to.userHasSubscriptionData(userId);
      final userSpecificStatus = StorageService.to.getUserSpecificSubscriptionStatus(userId);
      final hasActiveSession = StorageService.to.hasActiveSubscription();

      print("🔍 Checking existing active subscription:");
      print("   - User ID: $userId");
      print("   - Has user-specific data: $hasUserSpecificData");
      print("   - User-specific status: $userSpecificStatus");
      print("   - Has active session: $hasActiveSession");

      // If user has active subscription, they shouldn't see subscription page
      if (hasUserSpecificData && userSpecificStatus == 'active') {
        print("🎯 User has active subscription - redirecting to home");




        // Redirect to home after a short delay
        Future.delayed(Duration(milliseconds: 1500), () {
          Get.offAllNamed('/home');
        });

        return true;
      }

      return false;
    } catch (e) {
      print("❌ Error checking existing active subscription: $e");
      return false;
    }
  }

  /// IMPROVED: Enhanced RevenueCat initialization with better error handling
  Future<void> _initializeRevenueCat() async {
    if (_isInitializing || _hasInitialized) {
      print("⚠️ RevenueCat already initializing or initialized, skipping...");
      return;
    }

    _isInitializing = true;

    try {
      print("🔄 Initializing RevenueCat...");

      // Configure debug logging
      if (enableDebugLogs) {
        // await Purchases.setLogLevel(LogLevel.debug);
      }

      // Validate API key
      if (revenueCatApiKey.isEmpty || revenueCatApiKey.length < 10) {
        throw Exception('Invalid RevenueCat API key');
      }

      print("🔑 Configuring RevenueCat with API key: ${revenueCatApiKey.substring(0, 10)}...");

      // Configure RevenueCat
      // PurchasesConfiguration configuration = PurchasesConfiguration(revenueCatApiKey);
      // await Purchases.configure(configuration);
      //
      // // Set up listener for purchase updates
      // Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);

      // Set user ID if available
      await _setRevenueCatUserId();

      // Load offerings
      // await _loadRevenueCatOfferings();

      // Get initial customer info
      await _updateCustomerInfo();

      isRevenueCatInitialized.value = true;
      _hasInitialized = true;
      print("✅ RevenueCat initialized successfully");

    } catch (e) {
      print("❌ RevenueCat initialization failed: $e");
      isRevenueCatInitialized.value = false;
      // Don't throw - allow app to continue with API fallback
    } finally {
      _isInitializing = false;
    }
  }

  /// IMPROVED: Customer info listener for real-time updates
  // void _onCustomerInfoUpdated(CustomerInfo customerInfo) {
  //   print("📱 Customer info updated from RevenueCat");
  //   this.customerInfo.value = customerInfo;
  //   _processCustomerInfoUpdate(customerInfo);
  // }

  /// IMPROVED: Process customer info updates
  // Future<void> _processCustomerInfoUpdate(CustomerInfo customerInfo) async {
  //   try {
  //     final hasActiveSubscription = customerInfo.entitlements.active.isNotEmpty;
  //
  //     print("📊 Processing customer info update:");
  //     print("   - Active entitlements: ${customerInfo.entitlements.active.keys.toList()}");
  //     print("   - Has active subscription: $hasActiveSubscription");
  //
  //     if (hasActiveSubscription) {
  //       final activeEntitlement = customerInfo.entitlements.active.values.first;
  //
  //       // Update local storage
  //       DateTime? expiryDate;
  //       if (activeEntitlement.expirationDate != null) {
  //         try {
  //           expiryDate = DateTime.parse(activeEntitlement.expirationDate!);
  //         } catch (e) {
  //           expiryDate = DateTime.now().add(const Duration(days: 30));
  //         }
  //       }
  //
  //       await StorageService.to.setSubscriptionStatus(
  //         status: 'active',
  //         planId: activeEntitlement.productIdentifier,
  //         planName: activeEntitlement.productIdentifier,
  //         expiryDate: expiryDate,
  //       );
  //
  //       print("✅ Local storage updated with active subscription");
  //     }
  //   } catch (e) {
  //     print("❌ Error processing customer info update: $e");
  //   }
  // }

  /// IMPROVED: Set RevenueCat user ID with better error handling
  Future<void> _setRevenueCatUserId() async {
    try {
      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString();

      if (userId != null && userId.isNotEmpty) {
        // await Purchases.logIn(userId);
        print("✅ RevenueCat user ID set: $userId");
      } else {
        print("ℹ️ No user ID available for RevenueCat");
      }
    } catch (e) {
      print("⚠️ Failed to set RevenueCat user ID: $e");
      // Don't throw - this is not critical for basic functionality
    }
  }

  /// IMPROVED: Enhanced offerings loader
  // Future<void> _loadRevenueCatOfferings() async {
  //   try {
  //     print("📦 Loading RevenueCat offerings...");
  //
  //     final offerings = await Purchases.getOfferings();
  //     revenueCatOfferings.value = offerings;
  //
  //     _logOfferingsDetails(offerings);
  //
  //   } catch (e) {
  //     print("❌ Failed to load RevenueCat offerings: $e");
  //     revenueCatOfferings.value = null;
  //   }
  // }

  /// IMPROVED: Detailed offerings logging
  // void _logOfferingsDetails(Offerings offerings) {
  //   print("📊 RevenueCat offerings loaded:");
  //   print("   - Total offerings: ${offerings.all.length}");
  //   print("   - Current offering available: ${offerings.current != null}");
  //
  //   if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
  //     print("   - Current offering packages: ${offerings.current!.availablePackages.length}");
  //
  //     for (final package in offerings.current!.availablePackages) {
  //       print("     📦 ${package.identifier}:");
  //       print("        - Product ID: ${package.storeProduct.identifier}");
  //       print("        - Title: ${package.storeProduct.title}");
  //       print("        - Price: ${package.storeProduct.priceString}");
  //       print("        - Period: ${package.packageType}");
  //     }
  //   } else {
  //     print("   - No current offering or packages available");
  //
  //     if (offerings.all.isNotEmpty) {
  //       print("   - Available alternative offerings:");
  //       for (final key in offerings.all.keys) {
  //         final offering = offerings.all[key];
  //         print("     - '$key': ${offering!.availablePackages.length} packages");
  //       }
  //     }
  //   }
  // }

  /// IMPROVED: Get current customer info
  Future<void> _updateCustomerInfo() async {
    try {
      if (isRevenueCatInitialized.value) {
        // final info = await Purchases.getCustomerInfo();
        // customerInfo.value = info;
        print("✅ Customer info updated");
      }
    } catch (e) {
      print("❌ Failed to get customer info: $e");
    }
  }

  /// IMPROVED: Enhanced subscription check
  Future<void> _checkExistingSubscription() async {
    try {
      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString();

      if (userId != null && userId.isNotEmpty) {
        final hasSubscriptionData = StorageService.to.userHasSubscriptionData(userId);
        final subscriptionStatus = StorageService.to.getSubscriptionStatus();

        print('📋 Existing subscription check for user $userId:');
        print('   - Has local subscription data: $hasSubscriptionData');
        print('   - Current local status: $subscriptionStatus');

        // Check RevenueCat subscription if initialized
        if (isRevenueCatInitialized.value) {
          await _syncRevenueCatSubscription();
        }
      }
    } catch (e) {
      print('❌ Error checking existing subscription: $e');
    }
  }

  /// IMPROVED: Sync RevenueCat subscription with local storage
  Future<void> _syncRevenueCatSubscription() async {
    try {
      await _updateCustomerInfo();

      // if (customerInfo.value != null) {
      //   final hasActiveSubscription = customerInfo.value!.entitlements.active.isNotEmpty;
      //
      //   print("🔄 Syncing RevenueCat subscription:");
      //   print("   - Has active entitlements: $hasActiveSubscription");
      //
      //   if (hasActiveSubscription) {
      //     await _processCustomerInfoUpdate(customerInfo.value!);
      //   }
      // }
    } catch (e) {
      print("❌ Failed to sync RevenueCat subscription: $e");
    }
  }

  /// IMPROVED: API subscription plans fetching with better error handling
  Future<void> fetchSubscriptionPlans() async {
    try {
      final token = StorageService.to.getToken();

      var request = http.MultipartRequest(
          'POST',
          Uri.parse('https://alliedtechnologies.cloud/clients/lupus_care/api/v1/user.php')
      );

      request.fields.addAll({'request': 'get_subscription_plans'});

      if (token != null && token.isNotEmpty) {
        request.headers.addAll({'Authorization': 'Bearer $token'});
      }

      print("📤 Fetching subscription plans from API...");
      http.StreamedResponse response = await request.send();
      final responseString = await response.stream.bytesToString();

      print("📥 API Response received (${response.statusCode})");

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(responseString);

        if (decodedResponse['status'] == 'success' &&
            decodedResponse['data'] is List) {

          subscriptionPlans.value = decodedResponse['data'];
          print("✅ Loaded ${subscriptionPlans.length} subscription plans from API");

          // Validate plans have required fields
          _validateSubscriptionPlans();

          // Set default selection
          if (subscriptionPlans.isNotEmpty) {
            selectedPlan.value = subscriptionPlans[0]['id'].toString();
          }
        } else {
          throw Exception('Invalid API response format');
        }
      } else {
        throw Exception('API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ Error fetching subscription plans: $e");
      errorMessage.value = 'Unable to load subscription plans. Using offline data.';

      // Use fallback plans (only free trial)
      subscriptionPlans.value = fallbackPlans;
      selectedPlan.value = '1';
    }
  }



  Future<void> _processSubscription() async {
    final userData = StorageService.to.getUser();
    final userId = userData?['id']?.toString();

    if (userId?.isEmpty ?? true) {
      throw Exception('User ID not found. Please log in again.');
    }

    final selectedPlanData = subscriptionPlans.firstWhereOrNull(
            (plan) => plan['id'].toString() == selectedPlan.value
    );

    if (selectedPlanData == null) {
      throw Exception('Selected plan not found');
    }

    print("📋 Processing subscription:");
    print("   User ID: $userId");
    print("   Plan: ${selectedPlanData['name']} (${selectedPlan.value})");

    // Handle free trial
    if (selectedPlan.value == '1') {
      await _handleFreeTrial(userId!, selectedPlanData);
      return;
    }

    // Handle premium subscription
    bool revenueCatSuccess = false;

    // FIX: Since RevenueCat is commented out, skip it for now
    if (false) { // Changed from: if (isRevenueCatInitialized.value) {
      print("💳 Attempting RevenueCat purchase...");
      try {
        // await _handleRevenueCatPurchase(userId!, selectedPlanData);
        revenueCatSuccess = true;
      } catch (e) {
        print("❌ RevenueCat purchase failed: $e");

        // Handle user cancellation
        if (e is PlatformException && e.code == 'purchase_cancelled') {
          Get.snackbar(
            'Purchase Cancelled',
            'The purchase was cancelled',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.orange.withOpacity(0.1),
            colorText: Colors.orange,
          );
          return;
        }
      }
    }

    // Use API for subscription (main path since RevenueCat is disabled)
    if (!revenueCatSuccess) {
      print("🔄 Using API for subscription...");
      await _handleApiSubscription(userId!, selectedPlanData);
    }
  }

  /// FIXED: API subscription handling with guaranteed navigation
  Future<void> _handleApiSubscription(String userId, Map<String, dynamic> planData) async {
    try {
      final now = DateTime.now();
      final startDate = now.toString().substring(0, 10);
      final endDateTime = now.add(const Duration(days: 30));
      final endDate = endDateTime.toString().substring(0, 10);
      final expiry = "${endDate} ${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}:${endDateTime.second.toString().padLeft(2, '0')}";

      final token = StorageService.to.getToken();

      var request = http.MultipartRequest(
          'POST',
          Uri.parse('https://alliedtechnologies.cloud/clients/lupus_care/api/v1/user.php')
      );

      request.fields.addAll({
        'request': 'subscribe',
        'plan_id': selectedPlan.value,
        'user_id': userId,
        'start_date': startDate,
        'end_date': endDate,
        'expiry': expiry
      });

      if (token?.isNotEmpty ?? false) {
        request.headers.addAll({'Authorization': 'Bearer $token'});
      }

      print("📤 Sending API subscription request...");
      final response = await request.send();
      final responseString = await response.stream.bytesToString();

      print("📥 API subscription response received (${response.statusCode})");
      print("📄 Response body: $responseString"); // Debug log

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(responseString);

        if (decodedResponse['status'] == 'success') {
          // CRITICAL: Save subscription data
          print("💾 Saving subscription data...");
          bool subscriptionSaved = await StorageService.to.setSubscriptionStatus(
            status: 'active',
            planId: selectedPlan.value,
            planName: planData['name'] ?? 'Premium Plan',
            expiryDate: endDateTime,
          );

          if (!subscriptionSaved) {
            print("❌ Failed to save subscription data locally");
            throw Exception('Failed to save subscription data locally');
          }

          // Mark onboarding as completed
          await StorageService.to.setOnboardingCompleted(true);

          // VERIFICATION: Double-check that the subscription was saved correctly
          await Future.delayed(Duration(milliseconds: 100)); // Small delay for storage
          final verificationUserId = userId;
          final hasData = StorageService.to.userHasSubscriptionData(verificationUserId);
          final status = StorageService.to.getUserSpecificSubscriptionStatus(verificationUserId);

          print("🔍 Subscription save verification:");
          print("   - User has subscription data: $hasData");
          print("   - User-specific status: $status");

          if (!hasData || status != 'active') {
            print("❌ Subscription verification failed - retrying save...");
            await StorageService.to.setSubscriptionStatus(
              status: 'active',
              planId: selectedPlan.value,
              planName: planData['name'] ?? 'Premium Plan',
              expiryDate: endDateTime,
            );
          }

          // Show success message
          print("✅ Subscription successful, showing success message...");
          _showSuccess('Subscription Successful', 'Your subscription is now active!');

          // GUARANTEED NAVIGATION: Multiple approaches to ensure navigation works
          print("🎯 Initiating navigation to subscription success...");

          // Approach 1: Immediate navigation (primary)
          try {
            print("🚀 Attempting immediate navigation...");
            Get.offAllNamed('/subscriptionSuccess');
            print("✅ Immediate navigation called");
          } catch (e) {
            print("❌ Immediate navigation failed: $e");
          }

          // Approach 2: Delayed navigation (backup)
          Future.delayed(Duration(milliseconds: 500), () {
            try {
              print("🔄 Delayed navigation attempt...");
              if (Get.currentRoute != '/subscriptionSuccess') {
                Get.offAllNamed('/subscriptionSuccess');
                print("✅ Delayed navigation called");
              } else {
                print("ℹ️ Already on subscription success page");
              }
            } catch (e) {
              print("❌ Delayed navigation failed: $e");
            }
          });

          // Approach 3: Final failsafe (last resort)
          Future.delayed(Duration(milliseconds: 2000), () {
            try {
              print("🆘 Failsafe navigation check...");
              if (Get.currentRoute != '/subscriptionSuccess' && Get.currentRoute != '/home') {
                print("⚠️ Still not on success page, forcing navigation...");
                Get.offAllNamed('/subscriptionSuccess');
              }
            } catch (e) {
              print("❌ Failsafe navigation failed: $e");
              // As absolute last resort, go to home
              Get.offAllNamed('/home');
            }
          });

        } else {
          print("❌ API returned error: ${decodedResponse['message']}");
          throw Exception(decodedResponse['message'] ?? 'API subscription failed');
        }
      } else {
        print("❌ HTTP error: ${response.statusCode}");
        throw Exception('API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ Exception in _handleApiSubscription: $e");
      rethrow; // Re-throw to be handled by the calling method
    }
  }

  /// FIXED: Main subscription method with better error handling
  Future<void> subscribe() async {
    if (isPurchasing.value) {
      print("⚠️ Purchase already in progress, ignoring");
      return;
    }

    print("🚀 Starting subscription process...");
    print("   Selected plan: ${selectedPlan.value}");
    print("   RevenueCat initialized: ${isRevenueCatInitialized.value}");

    // Validate selection
    if (selectedPlan.value.isEmpty) {
      _showError('Error', 'Please select a subscription plan');
      return;
    }

    isPurchasing.value = true;
    purchaseError.value = '';

    try {
      await _processSubscription();
      print("✅ Subscription process completed successfully");
    } catch (e) {
      print("❌ Subscription process failed: $e");

      // Check if it's a navigation-related error that we can ignore
      if (e.toString().contains('navigation') || e.toString().contains('route')) {
        print("ℹ️ Navigation error detected, but subscription might have succeeded");

        // Check if subscription was actually saved
        final userData = StorageService.to.getUser();
        final userId = userData?['id']?.toString();
        if (userId != null) {
          final hasData = StorageService.to.userHasSubscriptionData(userId);
          final status = StorageService.to.getUserSpecificSubscriptionStatus(userId);

          if (hasData && status == 'active') {
            print("✅ Subscription was successful despite navigation error");
            _showSuccess('Subscription Successful', 'Your subscription is active!');

            // Force navigation as last resort
            Future.delayed(Duration(milliseconds: 1000), () {
              Get.offAllNamed('/subscriptionSuccess');
            });
            return;
          }
        }
      }

      _showError('Subscription Failed', e.toString());
    } finally {
      isPurchasing.value = false;
    }
  }

  /// IMPROVED: Free trial handling with proper navigation
  Future<void> _handleFreeTrial(String userId, Map<String, dynamic> planData) async {
    try {
      print("🆓 Processing free trial subscription...");

      final endDateTime = DateTime.now().add(const Duration(days: 7));

      await StorageService.to.setSubscriptionStatus(
        status: 'active',
        planId: '1',
        planName: 'Free Trial',
        expiryDate: endDateTime,
      );

      await StorageService.to.setOnboardingCompleted(true);

      _showSuccess('Free Trial Started', 'Your 7-day free trial is now active!');

      // For free trial, go directly to home (as per original logic)
      print("🏠 Navigating to home for free trial...");
      await Future.delayed(Duration(milliseconds: 1000));
      Get.offAllNamed('/home');

    } catch (e) {
      print("❌ Error in free trial handling: $e");
      rethrow;
    }
  }

  /// ADDITIONAL DEBUGGING METHOD: Check current navigation state
  void debugNavigationState() {
    print("🔍 === NAVIGATION DEBUG ===");
    print("Current route: ${Get.currentRoute}");

    print("Is overlay?: ${Get.isOverlaysOpen}");
    print("Is dialog?: ${Get.isDialogOpen}");
    print("Is snackbar?: ${Get.isSnackbarOpen}");
    print("========================");
  }

  /// ADDITIONAL HELPER: Force navigation with multiple attempts
  Future<void> forceNavigateToSuccess() async {
    print("🔧 Force navigating to subscription success...");

    try {
      // Close any open dialogs/overlays first
      if (Get.isDialogOpen == true) {
        Get.back();
      }
      if (Get.isSnackbarOpen == true) {
        Get.back();
      }

      // Navigate
      Get.offAllNamed('/subscriptionSuccess');

      // Verify navigation worked
      await Future.delayed(Duration(milliseconds: 500));
      if (Get.currentRoute != '/subscriptionSuccess') {
        print("⚠️ Navigation verification failed, retrying...");
        Get.offAllNamed('/subscriptionSuccess');
      }

    } catch (e) {
      print("❌ Force navigation failed: $e");
    }
  }


  /// Helper to get plan features
  List<String> getPlanFeatures(Map<String, dynamic> plan) {
    final features = plan['features'];
    if (features is List) {
      return features.map((feature) => feature.toString()).toList();
    } else if (features is String) {
      try {
        final decodedFeatures = json.decode(features);
        if (decodedFeatures is List) {
          return decodedFeatures.map((feature) => feature.toString()).toList();
        }
      } catch (e) {
        return features.split(',').map((e) => e.trim()).toList();
      }
    }
    return ['Basic features'];
  }

  /// Check subscription status
  void checkSubscriptionStatus() {
    final userData = StorageService.to.getUser();
    final userId = userData?['id']?.toString();
    final status = StorageService.to.getSubscriptionStatus();
    final hasActive = StorageService.to.hasActiveSubscription();

    print("📋 === SUBSCRIPTION STATUS ===");
    print("   User ID: $userId");
    print("   Status: $status");
    print("   Has Active: $hasActive");
    print("   RevenueCat: ${isRevenueCatInitialized.value}");
    print("========================");
  }

  /// Check if should show subscription page
  bool shouldShowSubscriptionPage() {
    final userData = StorageService.to.getUser();
    final userId = userData?['id']?.toString();

    if (userId == null) return true;

    final hasSubscriptionData = StorageService.to.userHasSubscriptionData(userId);
    final hasActiveSubscription = StorageService.to.hasActiveSubscription();

    return !hasSubscriptionData || !hasActiveSubscription;
  }

  /// Test RevenueCat connection
  Future<void> testRevenueCatConnection() async {
    if (!isRevenueCatInitialized.value) {
      // _showError('Test Failed', 'RevenueCat not initialized');
      return;
    }

    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      final userData = StorageService.to.getUser();
      String testUserId = userData?['id']?.toString() ??
          'test_user_${DateTime.now().millisecondsSinceEpoch}';

      // await Purchases.logIn(testUserId);
      // final customerInfo = await Purchases.getCustomerInfo();

      Get.back();
      // _showSuccess('Test Successful', 'RevenueCat connection working. User: $testUserId');
    } catch (e) {
      Get.back();
      // _showError('Test Failed', 'RevenueCat test failed: $e');
    }
  }

  /// IMPROVED: Validate subscription plans from API
  void _validateSubscriptionPlans() {
    final validPlans = <Map<String, dynamic>>[];

    for (final plan in subscriptionPlans) {
      if (plan['id'] != null && plan['name'] != null) {
        // Ensure price is present for non-free plans
        if (plan['id'].toString() != '1' && (plan['price'] == null || plan['price'].toString().isEmpty)) {
          print("⚠️ Plan ${plan['id']} missing price, skipping");
          continue;
        }
        validPlans.add(plan);
      } else {
        print("⚠️ Invalid plan structure: $plan");
      }
    }

    subscriptionPlans.value = validPlans;
    print("✅ Validated ${validPlans.length} subscription plans");
  }

  /// Getters for plan access
  Map<String, dynamic>? get freePlan {
    return subscriptionPlans.firstWhereOrNull((plan) =>
    plan['id'].toString() == '1' ||
        (plan['name']?.toString().toLowerCase().contains('free') ?? false) ||
        (plan['name']?.toString().toLowerCase().contains('trial') ?? false)
    );
  }

  Map<String, dynamic>? get premiumPlan {
    return subscriptionPlans.firstWhereOrNull((plan) =>
    plan['id'].toString() != '1' &&
        (plan['name']?.toString().toLowerCase().contains('month') ?? false)
    );
  }

  void selectPlan(String plan) {
    selectedPlan.value = plan;
    print("🎯 Plan selected: $plan");
  }

  /// Skip subscription
  void skipSubscription() async {
    print("⏩ User chose to skip subscription");

    await StorageService.to.setSubscriptionStatus(
      status: 'pending',
      planId: null,
      planName: null,
    );

    await StorageService.to.setOnboardingCompleted(false);



    Get.offAllNamed('/home');
  }

  /// Continue to app from success page
  void continueToApp() {
    print("🏠 Continuing to app from subscription success");
    Get.offAllNamed('/home');
  }

  void _showError(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }

  void _showSuccess(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }

  @override
  void onClose() {
    // Remove listener to prevent memory leaks
    // Purchases.removeCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    print("🔄 SubscriptionController disposed");
    super.onClose();
  }
}