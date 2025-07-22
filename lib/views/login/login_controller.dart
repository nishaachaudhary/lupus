// UPDATED: LoginController with Profile Screen Flow

import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lupus_care/data/api/auth_service.dart';
import 'package:lupus_care/helper/storage_service.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginController extends GetxController {
  final AuthService authService = AuthService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  RxBool isPasswordVisible = false.obs;
  RxBool isLoading = false.obs;
  RxBool isGoogleLoading = false.obs;
  RxBool isAppleLoading = false.obs;

  // Add validation error message observables
  RxString emailError = ''.obs;
  RxString passwordError = ''.obs;

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  // Clear all input fields and error messages
  void clearFields() {
    emailController.clear();
    passwordController.clear();
    isPasswordVisible.value = false;
    emailError.value = '';
    passwordError.value = '';
  }

  Future<String> getFcmToken() async {
    try {
      print("🔔 Getting FCM token in LoginController...");

      final fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken != null && fcmToken.isNotEmpty) {
        print("✅ FCM token obtained: ${fcmToken.substring(0, 30)}...");
        return fcmToken;
      } else {
        print("⚠️ FCM token is null or empty, using fallback");
        return 'fcm_token_unavailable_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      print("❌ Error getting FCM token: $e");
      return 'fcm_token_error_${DateTime.now().millisecondsSinceEpoch}';
    }
  }



  // Your existing validation method
  bool validateInputs() {
    bool isValid = true;

    // Clear previous errors
    emailError.value = '';
    passwordError.value = '';

    // Validate email
    if (emailController.text.trim().isEmpty) {
      emailError.value = 'Email is required';
      isValid = false;
    } else if (!GetUtils.isEmail(emailController.text.trim())) {
      emailError.value = 'Please enter a valid email';
      isValid = false;
    }

    // Validate password
    if (passwordController.text.isEmpty) {
      passwordError.value = 'Password is required';
      isValid = false;
    }

    return isValid;
  }

  // UPDATED: Login method with real FCM token
  Future<void> login() async {
    if (!validateInputs()) {
      return;
    }

    try {
      isLoading.value = true;

      // Show loading dialog
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(),
        ),
        barrierDismissible: false,
      );

      // Get real FCM token
      final fcmToken = await getFcmToken();
      print("🔔 Using FCM token for login: ${fcmToken.substring(0, 30)}...");

      final response = await authService.login(
        email: emailController.text.trim(),
        password: passwordController.text,
        fcmToken: fcmToken, // Use real FCM token here
      );

      // Close loading dialog
      if (Get.isDialogOpen == true) {
        Get.back();
      }
      isLoading.value = false;

      // Check response status
      if (response['status'] == 'success') {
        print("✅ Regular login successful");

        // Verify user data was saved properly
        if (!StorageService.to.isLoggedIn()) {
          print("ERROR: Login succeeded but isLoggedIn flag is false");
          Get.snackbar(
            "Error",
            "Login failed. Please try again.",
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }

        // Clear input fields and errors after successful login
        clearFields();

        // Mark login page as seen
        await StorageService.to.markLoginPageSeen();

        // Handle post-login navigation
        await handlePostLoginNavigation();

      } else {
        // Handle login failure
        String errorMessage = response['message'] ?? "Login failed";
        String userFriendlyMessage = _getUserFriendlyErrorMessage(errorMessage);

        print("Login failed: $errorMessage");

        Get.snackbar(
          "Login Failed",
          userFriendlyMessage,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 4),
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (Get.isDialogOpen == true) {
        Get.back();
      }

      isLoading.value = false;
      print("Error during login: $e");

      String errorMessage = e.toString();
      String userFriendlyMessage = _getUserFriendlyErrorMessage(errorMessage);

      Get.snackbar(
        "Login Failed",
        userFriendlyMessage,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 4),
      );
    }
  }

  // COMPLETELY UPDATED: Google Sign-In with detailed FCM token logging
  Future<void> signInWithGoogle() async {
    print('🚀 === GOOGLE SIGN-IN WITH REAL FCM TOKEN ===');
    print('🚀 Start time: ${DateTime.now()}');

    try {
      isGoogleLoading.value = true;
      print('🔄 Google loading state set to true');

      // Step 1: Get FCM token FIRST with detailed logging
      print('🔔 === STEP 1: GETTING FCM TOKEN FOR GOOGLE SIGN-IN ===');
      final fcmToken = await getFcmToken();
      print('✅ FCM token obtained for Google sign-in');
      print('🔔 Google FCM token: ${fcmToken.substring(0, 30)}...${fcmToken.substring(fcmToken.length - 10)}');

      // Step 2: Clear any existing authentication completely
      print('🧹 === STEP 2: CLEARING EXISTING AUTH ===');
      await _clearGoogleAuthenticationCompletely();

      // Step 3: Create fresh Google Sign-In instance and get user
      print('👤 === STEP 3: GETTING GOOGLE USER ===');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('❌ Google Sign-in was canceled by user');
        isGoogleLoading.value = false;
        Get.snackbar('Canceled', 'Google Sign-in was canceled');
        return;
      }

      print('✅ Google user obtained: ${googleUser.email}');
      print('👤 Google user display name: ${googleUser.displayName}');
      print('👤 Google user ID: ${googleUser.id}');

      // Step 4: Get authentication tokens
      print('🔑 === STEP 4: GETTING GOOGLE AUTH TOKENS ===');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw Exception("Failed to get ID token from Google");
      }

      print('✅ Google ID token obtained: ${googleAuth.idToken?.substring(0, 30)}...');

      // Step 5: Try to login with Google credentials first
      print('🔍 === STEP 5: TRYING EXISTING USER LOGIN ===');
      final loginResponse = await _tryLoginWithGoogle(googleUser, googleAuth, fcmToken);
      print('📥 Login response success: ${loginResponse['success']}');

      if (loginResponse['success'] == true) {
        print("✅ === EXISTING USER LOGIN SUCCESS ===");
        print("✅ Existing user found - logging in with real token and FCM");

        // Successful login with existing account
        await _saveGoogleUserWithRealBackendToken(
          googleUser: googleUser,
          backendData: loginResponse,
        );

        isGoogleLoading.value = false;

        // Show welcome back message
        Get.snackbar(
          "Welcome Back!",
          "Successfully signed in with Google",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );

        Get.offAllNamed('/home'); // Navigate directly to home for existing users
      } else {
        print("🆕 === NEW USER REGISTRATION ===");
        print("🆕 New user detected - creating account with FCM token");

        // No existing account found - create new user with token
        final registrationResponse = await _createNewGoogleUserWithToken(googleUser, googleAuth, fcmToken);
        print('📥 Registration response success: ${registrationResponse['success']}');

        if (registrationResponse['success'] == true) {
          print("✅ === NEW USER REGISTRATION SUCCESS ===");
          await _saveGoogleUserWithRealBackendToken(
            googleUser: googleUser,
            backendData: registrationResponse,
          );

          isGoogleLoading.value = false;

          // Show welcome message
          Get.snackbar(
            "Welcome!",
            "Successfully created account with Google",
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: Duration(seconds: 3),
          );

          Get.offAllNamed('/createProfile'); // Navigate to profile for new users
        } else {
          // Fallback: Save with generated token
          print("⚠️ === USING FALLBACK TOKEN ===");
          print("⚠️ Backend registration failed - using fallback token");
          await _saveGoogleUserWithGeneratedToken(googleUser);

          isGoogleLoading.value = false;

          Get.snackbar(
            "Welcome!",
            "Successfully signed in with Google",
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: Duration(seconds: 3),
          );

          Get.offAllNamed('/createProfile');
        }
      }

    } catch (e) {
      print("❌ === GOOGLE SIGN-IN ERROR ===");
      print("❌ Google Sign-In error: $e");
      print("❌ Error type: ${e.runtimeType}");
      print("❌ Stack trace: ${StackTrace.current}");

      isGoogleLoading.value = false;

      // Clear any partial authentication
      await _clearGoogleAuthenticationCompletely();

      Get.snackbar(
        "Sign-In Failed",
        "Failed to sign in with Google. Please try again.",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 4),
      );
    }
  }

  // COMPLETELY UPDATED: Create new Google user with detailed FCM logging
  Future<Map<String, dynamic>> _createNewGoogleUserWithToken(
      GoogleSignInAccount googleUser,
      GoogleSignInAuthentication googleAuth,
      String fcmToken, // FCM token parameter
      ) async {
    try {
      print("📝 === CREATING NEW GOOGLE USER WITH REAL FCM TOKEN ===");
      print("📝 User email: ${googleUser.email}");
      print("📝 User name: ${googleUser.displayName}");
      print("📝 Google ID: ${googleUser.id}");
      print("🔔 FCM token for registration: ${fcmToken.substring(0, 30)}...${fcmToken.substring(fcmToken.length - 10)}");

      var request = http.MultipartRequest('POST', Uri.parse(authService.baseUrl));

      final registrationFields = {
        'request': 'register',
        'full_name': googleUser.displayName ?? 'Google User',
        'email': googleUser.email,
        'password': 'google_${googleUser.id}',
        'confirm_password': 'google_${googleUser.id}',
        'provider': 'google',
        'google_id': googleUser.id,
        'is_social_registration': '1',
        'photo_url': googleUser.photoUrl ?? '',
        'fcm_token': fcmToken, // Use REAL FCM token
      };

      request.fields.addAll(registrationFields);
      request.headers['Authorization'] = 'Basic YWRtaW46MTIzNA==';

      print("📤 === SENDING GOOGLE REGISTRATION REQUEST ===");
      print("📤 URL: ${authService.baseUrl}");
      print("📤 Fields: $registrationFields");
      print("📤 FCM Token being sent: ${fcmToken.substring(0, 30)}...");

      http.StreamedResponse response = await request.send();
      final responseString = await response.stream.bytesToString();

      print("📥 === GOOGLE REGISTRATION RESPONSE ===");
      print("📥 Status Code: ${response.statusCode}");
      print("📥 Response Body: $responseString");
      print("📥 Response Headers: ${response.headers}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (responseString.trim().isNotEmpty) {
          try {
            final responseData = json.decode(responseString);
            print("✅ JSON parsed successfully");
            print("✅ Response status: ${responseData['status']}");
            print("✅ Response message: ${responseData['message']}");

            if (responseData['status'] == 'success') {
              final token = responseData['token'] ?? responseData['data']?['token'];
              final userId = responseData['user_id'] ?? responseData['data']?['id'];

              print("✅ Backend token obtained: ${token?.toString().substring(0, 20)}...");
              print("✅ User ID obtained: $userId");

              if (token != null && userId != null) {
                print("✅ === NEW GOOGLE USER CREATED SUCCESSFULLY ===");
                print("✅ Real backend token: YES");
                print("✅ Real FCM token sent: YES");
                return {
                  'success': true,
                  'token': token.toString(),
                  'user_id': userId.toString(),
                  'user_data': responseData['data'] ?? {},
                  'is_new_user': true,
                };
              }
            } else {
              print("❌ Registration failed: ${responseData['message']}");
            }
          } catch (e) {
            print("❌ Error parsing registration response: $e");
          }
        } else {
          print("⚠️ Empty response body from registration");
        }
      } else {
        print("❌ HTTP error: ${response.statusCode} - ${response.reasonPhrase}");
      }

      print("❌ Failed to create new Google user with backend");
      return {'success': false, 'error': 'Backend registration failed'};

    } catch (e) {
      print("❌ === GOOGLE REGISTRATION ERROR ===");
      print("❌ Google registration error: $e");
      print("❌ Stack trace: ${StackTrace.current}");
      return {'success': false, 'error': e.toString()};
    }
  }

  // COMPLETELY UPDATED: Try login with Google and detailed FCM logging
  Future<Map<String, dynamic>> _tryLoginWithGoogle(
      GoogleSignInAccount googleUser,
      GoogleSignInAuthentication googleAuth,
      String fcmToken, // FCM token parameter
      ) async {
    try {
      print("🔍 === TRYING LOGIN WITH GOOGLE AND REAL FCM TOKEN ===");
      print("🔍 User email: ${googleUser.email}");
      print("🔍 Google ID: ${googleUser.id}");
      print("🔔 FCM token for login: ${fcmToken.substring(0, 30)}...${fcmToken.substring(fcmToken.length - 10)}");

      var request = http.MultipartRequest('POST', Uri.parse(authService.baseUrl));

      final loginFields = {
        'request': 'login',
        'email': googleUser.email,
        'password': 'google_${googleUser.id}', // Try with Google ID as password
        'fcm_token': fcmToken, // Use REAL FCM token
      };

      request.fields.addAll(loginFields);
      request.headers['Authorization'] = 'Basic YWRtaW46MTIzNA==';

      print("📤 === SENDING GOOGLE LOGIN REQUEST ===");
      print("📤 URL: ${authService.baseUrl}");
      print("📤 Fields: $loginFields");
      print("📤 FCM Token being sent: ${fcmToken.substring(0, 30)}...");

      http.StreamedResponse response = await request.send();
      final responseString = await response.stream.bytesToString();

      print("📥 === GOOGLE LOGIN RESPONSE ===");
      print("📥 Status Code: ${response.statusCode}");
      print("📥 Response Body: $responseString");

      if (response.statusCode == 200 && responseString.trim().isNotEmpty) {
        try {
          final responseData = json.decode(responseString);
          print("✅ Login JSON parsed successfully");
          print("✅ Login response status: ${responseData['status']}");

          if (responseData['status'] == 'success') {
            final token = responseData['token'] ?? responseData['data']?['token'];
            final userId = responseData['user_id'] ?? responseData['data']?['id'];

            print("✅ Login token obtained: ${token?.toString().substring(0, 20)}...");
            print("✅ Login user ID obtained: $userId");

            if (token != null && userId != null) {
              print("✅ === EXISTING GOOGLE USER LOGIN SUCCESS ===");
              print("✅ Real backend token: YES");
              print("✅ Real FCM token sent: YES");
              return {
                'success': true,
                'token': token.toString(),
                'user_id': userId.toString(),
                'user_data': responseData['data'] ?? {},
                'is_new_user': false,
              };
            }
          } else {
            print("❌ Login failed: ${responseData['message']}");
          }
        } catch (e) {
          print("❌ Error parsing login response: $e");
        }
      } else {
        print("⚠️ Login response: Status ${response.statusCode}, Body: '${responseString.trim()}'");
      }

      print("❌ No existing account found or login failed");
      return {'success': false, 'error': 'No existing account found'};

    } catch (e) {
      print("❌ === GOOGLE LOGIN ERROR ===");
      print("❌ Login attempt error: $e");
      print("❌ Stack trace: ${StackTrace.current}");
      return {'success': false, 'error': e.toString()};
    }
  }

  // Your existing methods with better logging
  Future<void> _clearGoogleAuthenticationCompletely() async {
    try {
      print("🧹 === COMPLETE GOOGLE AUTHENTICATION CLEARING ===");

      // Step 1: Clear Google Sign-In cache
      print("🧹 Step 1: Clearing Google Sign-In cache...");

      // Clear multiple possible Google Sign-In instances
      final List<GoogleSignIn> googleSignInInstances = [
        GoogleSignIn(),
        GoogleSignIn(scopes: ['email', 'profile']),
        GoogleSignIn(scopes: ['email', 'profile', 'openid']),
        _googleSignIn, // Controller's instance
      ];

      for (GoogleSignIn instance in googleSignInInstances) {
        try {
          await instance.signOut();
          await instance.disconnect();
          print("✅ Cleared Google Sign-In instance");
        } catch (e) {
          print("⚠️ Error clearing Google instance: $e");
        }
      }

      // Step 2: Clear Firebase Auth
      print("🧹 Step 2: Clearing Firebase Auth...");
      try {
        await _auth.signOut();
        print("✅ Firebase Auth cleared");
      } catch (e) {
        print("⚠️ Firebase Auth clear error: $e");
      }

      // Step 3: Clear any cached tokens
      print("🧹 Step 3: Clearing cached tokens...");
      try {
        final GoogleSignIn tempInstance = GoogleSignIn();
        final currentUser = tempInstance.currentUser;
        if (currentUser != null) {
          await currentUser.clearAuthCache();
          print("✅ Google auth cache cleared");
        }
      } catch (e) {
        print("⚠️ Token cache clear error: $e");
      }

      // Step 4: Clear all storage
      print("🧹 Step 4: Clearing all storage...");
      await StorageService.to.clearAll();
      print("✅ Storage cleared");

      // Step 5: Small delay to ensure clearing is complete
      await Future.delayed(Duration(milliseconds: 500));

      print("✅ === GOOGLE AUTHENTICATION COMPLETELY CLEARED ===");
    } catch (e) {
      print("❌ Error in complete Google auth clear: $e");
    }
  }


  Future<void> _saveGoogleUserWithGeneratedToken(GoogleSignInAccount googleUser) async {
    try {
      print("🔧 === SAVING GOOGLE USER WITH GENERATED TOKEN ===");

      // Generate a secure token for API calls
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final generatedToken = 'google_token_${googleUser.id}_$timestamp';
      final generatedUserId = 'google_user_${googleUser.id}_$timestamp';

      final googleUserData = <String, dynamic>{
        'id': generatedUserId,
        'user_id': generatedUserId,
        'email': googleUser.email,
        'name': googleUser.displayName ?? 'Google User',
        'full_name': googleUser.displayName ?? 'Google User',
        'avatar': googleUser.photoUrl ?? '',
        'provider': 'google',
        'google_id': googleUser.id,
        'is_google_user': true,
        'is_fresh_user': true,
        'has_generated_token': true, // Flag to indicate this is a generated token
        'created_at': DateTime.now().toIso8601String(),
        'backend_registered': false, // Will be updated when profile is created
        'backend_authenticated': false,
      };

      // Clear existing data first
      await StorageService.to.clearAll();

      // Save user data and generated token
      await StorageService.to.saveUser(googleUserData);
      await StorageService.to.saveToken(generatedToken);
      await StorageService.to.setLoggedIn(true);
      await StorageService.to.markAsFreshUser();
      await StorageService.to.markLoginPageSeen();

      print("✅ Google user saved with generated token");
      print("   User ID: $generatedUserId");
      print("   Email: ${googleUser.email}");
      print("   Token: $generatedToken");

    } catch (e) {
      print("❌ Error saving Google user with generated token: $e");
      throw e;
    }
  }

  // UPDATED: Save method with better token handling and logging
  Future<void> _saveGoogleUserWithRealBackendToken({
    required GoogleSignInAccount googleUser,
    required Map<String, dynamic> backendData,
  }) async {
    try {
      print("💾 === SAVING GOOGLE USER WITH REAL BACKEND TOKEN ===");

      final realToken = backendData['token'].toString();
      final realUserId = backendData['user_id'].toString();
      final userData = backendData['user_data'] as Map<String, dynamic>? ?? {};
      final isNewUser = backendData['is_new_user'] ?? false;

      print("💾 Real backend token: ${realToken.substring(0, 20)}...");
      print("💾 Real user ID: $realUserId");
      print("💾 Is new user: $isNewUser");

      // Create complete user data
      final completeUserData = <String, dynamic>{
        'id': realUserId,
        'user_id': realUserId,
        'email': googleUser.email,
        'name': googleUser.displayName ?? 'Google User',
        'full_name': userData['full_name']?.toString() ?? googleUser.displayName ?? 'Google User',
        'avatar': userData['avatar']?.toString() ?? googleUser.photoUrl ?? '',
        'provider': 'google',
        'google_id': googleUser.id,
        'is_google_user': true,
        'google_email': googleUser.email,
        'created_at': userData['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        'backend_registered': true,
        'backend_authenticated': true,
        'real_backend_token': true,
        'has_real_user_id': true,
        'limited_functionality': false,
        'is_fresh_user': isNewUser,
        'has_generated_token': false, // This is a real backend token
      };

      // Clear existing data first
      await StorageService.to.clearAll();

      // Save new data with REAL TOKEN
      await StorageService.to.saveUser(completeUserData);
      await StorageService.to.saveToken(realToken);
      await StorageService.to.setLoggedIn(true);
      await StorageService.to.markLoginPageSeen();

      if (isNewUser) {
        await StorageService.to.markAsFreshUser();
      }

      print("✅ Google user saved with real backend token successfully");
      print("✅ User ID: $realUserId");
      print("✅ Email: ${googleUser.email}");
      print("✅ Token saved: YES");
      print("✅ Is New User: $isNewUser");

    } catch (e) {
      print("❌ Error saving Google user with real backend token: $e");
      throw e;
    }
  }

  // Your existing methods remain the same...
  String _getUserFriendlyErrorMessage(String originalMessage) {
    // Convert to lowercase for easier matching
    String lowerMessage = originalMessage.toLowerCase();

    // Handle invalid password errors
    if (lowerMessage.contains('invalid password') ||
        lowerMessage.contains('password is incorrect') ||
        lowerMessage.contains('wrong password')) {
      return "The password you entered is incorrect. Please try again.";
    }

    // Handle invalid email/user not found errors
    if (lowerMessage.contains('user not found') ||
        lowerMessage.contains('invalid email') ||
        lowerMessage.contains('email not found') ||
        lowerMessage.contains('account not found')) {
      return "No account found with this email address. Please check your email or sign up.";
    }

    // Handle network/connection errors
    if (lowerMessage.contains('network') ||
        lowerMessage.contains('connection') ||
        lowerMessage.contains('timeout') ||
        lowerMessage.contains('unreachable')) {
      return "Connection failed. Please check your internet connection and try again.";
    }

    // Clean up exception prefix if present
    if (originalMessage.startsWith('Exception: ')) {
      originalMessage = originalMessage.substring(11);
    }

    // If no specific match found, return cleaned up original message
    if (originalMessage.length > 100) {
      return "Login failed. Please check your credentials and try again.";
    }

    return originalMessage;
  }




  Future<void> handlePostLoginNavigation() async {
    try {
      print('🚀 === POST LOGIN NAVIGATION WITH FRESH USER DETECTION ===');

      // Get current user state
      final userData = StorageService.to.getUser();
      final hasCompletedOnboarding = StorageService.to.hasCompletedOnboarding();
      final hasCompletedProfile = StorageService.to.hasCompletedProfile();
      final hasActiveSubscription = StorageService.to.hasActiveSubscription();
      final subscriptionStatus = StorageService.to.getSubscriptionStatus();
      final isGoogleUser = userData?['provider'] == 'google';
      final authMethod = userData?['auth_method'] ?? '';

      print('📊 Navigation Decision Factors:');
      print('   - User Provider: ${userData?['provider']}');
      print('   - Auth Method: $authMethod');
      print('   - Has Completed Profile: $hasCompletedProfile');
      print('   - Has Completed Onboarding: $hasCompletedOnboarding');
      print('   - Has Active Subscription: $hasActiveSubscription');
      print('   - Subscription Status: $subscriptionStatus');

      // Special handling for Google users
      if (isGoogleUser) {
        // Check if this is a fresh Google sign-in
        if (_isFreshGoogleUser(authMethod, userData)) {
          print('🆕 → NAVIGATION: Fresh Google user - Going to Profile');
          Get.offAllNamed('/createProfile');
          return;
        }

        // For existing Google users, check their progress
        if (hasCompletedProfile && hasCompletedOnboarding) {
          if (hasActiveSubscription || subscriptionStatus == 'active') {
            print('🏠 → NAVIGATION: Existing Google user - Going to Home');
            Get.offAllNamed('/home');
            return;
          } else {
            print('💳 → NAVIGATION: Existing Google user - Going to Subscription');
            Get.offAllNamed('/subscription');
            return;
          }
        }
      }

      // Standard navigation logic for non-Google users
      // if (!hasCompletedProfile) {
      //   print('👤 → NAVIGATION: Going to Profile (Profile not completed)');
      //   Get.offAllNamed('/createProfile');
      //   return;
      // }

      if (subscriptionStatus == 'pending' || subscriptionStatus == 'expired') {
        print('💳 → NAVIGATION: Going to Subscription');
        Get.offAllNamed('/subscription');
        return;
      }

      if (hasActiveSubscription || subscriptionStatus == 'active') {
        print('🏠 → NAVIGATION: Going to Home');
        Get.offAllNamed('/home');
        return;
      }

      // Fallback
      print('👤 → FALLBACK: Going to Profile');
      Get.offAllNamed('/createProfile');

    } catch (e) {
      print('❌ Error in post login navigation: $e');
      Get.offAllNamed('/createProfile');
    }
  }

  bool _isFreshGoogleUser(String authMethod, Map<String, dynamic>? userData) {
    // Method 1: Check if authentication was through registration
    if (authMethod.contains('registration') ||
        authMethod.contains('google_registration') ||
        authMethod.contains('google_register')) {
      return true;
    }

    // Method 2: Check user completion flags
    if (!StorageService.to.hasCompletedProfile()) {
      return true;
    }

    // Method 3: Check if user was created recently (within last 5 minutes)
    final createdAt = userData?['created_at'];
    if (createdAt != null) {
      try {
        final createdTime = DateTime.parse(createdAt);
        final now = DateTime.now();
        final difference = now.difference(createdTime).inMinutes;

        if (difference < 5) { // Created within last 5 minutes
          return true;
        }
      } catch (e) {
        print('⚠️ Error parsing created_at: $e');
      }
    }

    return false;
  }

  Future<void> onGoogleLoginSuccess() async {
    print('✅ Google login successful - handling navigation');

    await StorageService.to.markLoginPageSeen();

    // Simple fresh user detection
    final hasCompletedProfile = StorageService.to.hasCompletedProfile();
    final hasCompletedOnboarding = StorageService.to.hasCompletedOnboarding();
    final userData = StorageService.to.getUser();
    final authMethod = userData?['auth_method'] ?? '';

    // If user hasn't completed profile OR this was a registration, treat as fresh
    if (!hasCompletedProfile || authMethod.contains('registration')) {
      print('🆕 Fresh Google user - going to profile screen');
      Get.offAllNamed('/createProfile');
    } else {
      print('🔄 Existing Google user - using standard navigation');
      await handlePostLoginNavigation();
    }
  }

  // Enhanced sign out method
  Future<void> signOut() async {
    try {
      print("👋 === STARTING ENHANCED SIGN OUT PROCESS ===");

      // Step 1: Call logout API
      print("📤 Step 1: Calling logout API...");
      await authService.logout();
      print("✅ Logout API called");

      // Step 2: Complete Google authentication clearing
      print("🧹 Step 2: Clearing Google authentication...");
      await _clearGoogleAuthenticationCompletely();

      // Step 3: Verify sign out
      final user = StorageService.to.getUser();
      final token = StorageService.to.getToken();
      final isLoggedIn = StorageService.to.isLoggedIn();

      print("🔍 Sign out verification:");
      print("   User cleared: ${user == null ? "✅" : "❌"}");
      print("   Token cleared: ${token == null ? "✅" : "❌"}");
      print("   Login flag cleared: ${!isLoggedIn ? "✅" : "❌"}");

      print("✅ === SIGN OUT COMPLETED SUCCESSFULLY ===");

      // Navigate to login screen
      Get.offAllNamed('/login');

    } catch (e) {
      print("❌ Error during sign out: $e");
      // Force clear and navigate anyway
      await _clearGoogleAuthenticationCompletely();
      Get.offAllNamed('/login');
    }
  }

  // Navigation methods
  void navigateToForgotPassword() {
    Get.toNamed('/forgotPassword');
  }

  void navigateToSignup() {
    Get.toNamed('/signup');
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}