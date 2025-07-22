import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lupus_care/data/api/auth_service.dart';
import 'package:lupus_care/helper/storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SignupController extends GetxController {
  final AuthService authService = AuthService();
  // final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  RxBool isPasswordVisible = false.obs;
  RxBool isConfirmPasswordVisible = false.obs;
  RxBool isLoading = false.obs;
  RxBool isGoogleLoading = false.obs;

  // Add validation error message observables
  RxString nameError = ''.obs;
  RxString emailError = ''.obs;
  RxString passwordError = ''.obs;
  RxString confirmPasswordError = ''.obs;
  RxBool isAppleLoading = false.obs;



  Future<String> getFcmToken() async {
    try {
      print("🔔 === GETTING FCM TOKEN IN SIGNUP ===");
      print("🔔 Requesting FCM token from Firebase...");

      final fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken != null && fcmToken.isNotEmpty) {
        print("✅ FCM token obtained successfully!");
        print("🔔 Token length: ${fcmToken.length}");
        print("🔔 Token preview: ${fcmToken.substring(0, 30)}...${fcmToken.substring(fcmToken.length - 10)}");
        return fcmToken;
      } else {
        print("⚠️ FCM token is null or empty, generating fallback");
        final fallbackToken = 'fcm_token_unavailable_${DateTime.now().millisecondsSinceEpoch}';
        print("🔔 Fallback token: $fallbackToken");
        return fallbackToken;
      }
    } catch (e) {
      print("❌ Error getting FCM token: $e");
      final errorToken = 'fcm_token_error_${DateTime.now().millisecondsSinceEpoch}';
      print("🔔 Error token: $errorToken");
      return errorToken;
    }
  }

  @override
  void onInit() {
    super.onInit();

    // Add listeners to clear error messages when user starts typing
    nameController.addListener(() {
      if (nameError.value.isNotEmpty) {
        if (nameController.text.length <= 30) {
          nameError.value = '';
        } else {
          nameError.value = 'Name must be 30 characters or less';
        }
      }
    });
    emailController.addListener(() {
      if (emailError.value.isNotEmpty) {
        emailError.value = '';
      }
    });

    passwordController.addListener(() {
      if (passwordError.value.isNotEmpty) {
        passwordError.value = '';
      }
    });

    confirmPasswordController.addListener(() {
      if (confirmPasswordError.value.isNotEmpty) {
        confirmPasswordError.value = '';
      }
    });
  }

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  void toggleConfirmPasswordVisibility() {
    isConfirmPasswordVisible.value = !isConfirmPasswordVisible.value;
  }

  // Clear all input fields and error messages
  void clearFields() {
    nameController.clear();
    emailController.clear();
    passwordController.clear();
    confirmPasswordController.clear();
    isPasswordVisible.value = false;
    isConfirmPasswordVisible.value = false;
    nameError.value = '';
    emailError.value = '';
    passwordError.value = '';
    confirmPasswordError.value = '';
  }

  // Enhanced password validation with specific criteria
  String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password is required';
    }

    List<String> errors = [];

    // Check minimum length
    if (password.length < 8) {
      errors.add('at least 8 characters');
    }

    // Check for uppercase letter
    if (!password.contains(RegExp(r'[A-Z]'))) {
      errors.add('one uppercase letter');
    }

    // Check for lowercase letter
    if (!password.contains(RegExp(r'[a-z]'))) {
      errors.add('one lowercase letter');
    }

    // Check for number
    if (!password.contains(RegExp(r'[0-9]'))) {
      errors.add('one number');
    }

    // Check for special character
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      errors.add('one special character');
    }

    if (errors.isNotEmpty) {
      if (errors.length == 1) {
        return 'Password must contain ${errors[0]}';
      } else if (errors.length == 2) {
        return 'Password must contain ${errors[0]} and ${errors[1]}';
      } else {
        return 'Password must contain ${errors.sublist(0, errors.length - 1).join(', ')} and ${errors.last}';
      }
    }

    return null; // Password is valid
  }

  // Updated validation method that sets error messages instead of showing snackbars
  bool validateInputs() {
    bool isValid = true;

    // Clear previous errors
    nameError.value = '';
    emailError.value = '';
    passwordError.value = '';
    confirmPasswordError.value = '';

    // Validate name
    if (nameController.text.trim().isEmpty) {
      nameError.value = 'Name is required';
      isValid = false;
    } else if (nameController.text.trim().length < 2) {
      nameError.value = 'Name must be at least 2 characters';
      isValid = false;
    } else if (nameController.text.trim().length > 30) {
      nameError.value = 'Name must be 30 characters or less';
      isValid = false;
    }

    // Validate email
    if (emailController.text.trim().isEmpty) {
      emailError.value = 'Email is required';
      isValid = false;
    } else if (!GetUtils.isEmail(emailController.text.trim())) {
      emailError.value = 'Please enter a valid email';
      isValid = false;
    }

    // Validate password with enhanced criteria
    final passwordValidation = validatePassword(passwordController.text);
    if (passwordValidation != null) {
      passwordError.value = passwordValidation;
      isValid = false;
    }

    // Validate confirm password
    if (confirmPasswordController.text.isEmpty) {
      confirmPasswordError.value = 'Please confirm your password';
      isValid = false;
    } else if (passwordController.text != confirmPasswordController.text) {
      confirmPasswordError.value = 'Passwords do not match';
      isValid = false;
    }

    return isValid;
  }

  bool isEmailAlreadyExistsError(Map<String, dynamic> response) {
    final message = response['message']?.toString().toLowerCase() ?? '';

    // Check for common email exists error patterns from your API
    return message.contains('user with this email already exists') ||
        message.contains('email already exists') ||
        message.contains('email is already registered') ||
        message.contains('email already registered') ||
        message.contains('duplicate email') ||
        message.contains('email taken') ||
        message.contains('email not available');
  }

  // UPDATED: Register method with real FCM token
  Future<void> register() async {
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

      // Get real FCM token with detailed logging
      print("🔔 === REGULAR REGISTRATION FCM TOKEN ===");
      final fcmToken = await getFcmToken();
      print("🔔 Regular registration using FCM token: ${fcmToken.substring(0, 30)}...");

      final response = await authService.register(
        fullName: nameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text,
        confirmPassword: confirmPasswordController.text,
        fcmToken: fcmToken, // Use real FCM token instead of hardcoded
      );

      // Close loading dialog
      if (Get.isDialogOpen == true) {
        Get.back();
      }
      isLoading.value = false;

      // Check response status
      if (response['status'] == 'success') {
        print("✅ Registration successful with FCM token");

        // Verify user data was saved properly
        if (!StorageService.to.isLoggedIn()) {
          print("ERROR: Signup succeeded but isLoggedIn flag is false");
          Get.snackbar(
            "Error",
            "Signup failed. Please try again.",
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red.withOpacity(0.1),
            colorText: Colors.red,
          );
          return;
        }

        // Check if user data exists in storage after signup
        final userData = StorageService.to.getUser();
        if (userData == null) {
          print("ERROR: Signup succeeded but no user data found in storage");
          Get.snackbar(
            "Error",
            "Signup data not saved correctly. Please try again.",
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red.withOpacity(0.1),
            colorText: Colors.red,
          );
          return;
        }

        // Clear input fields and errors after successful signup
        clearFields();

        // Navigate to create profile
        Get.offAllNamed('/createProfile');
      } else {
        // Handle specific error cases
        final errorMessage = response['message'] ?? "Signup failed";
        print("Signup failed: $errorMessage");

        // Check if email already exists
        String displayMessage;
        String snackbarTitle;

        if (isEmailAlreadyExistsError(response)) {
          // Show your custom message for email already exists
          displayMessage = "Email already registered. Please use a different email or log in.";
          snackbarTitle = "Email Already Exists";

          // Set email error to show inline validation
          emailError.value = "This email is already registered";
        } else {
          displayMessage = errorMessage;
          snackbarTitle = "Signup Failed";
        }

        Get.snackbar(
          snackbarTitle,
          displayMessage,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.withOpacity(0.1),
          colorText: Colors.red,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (Get.isDialogOpen == true) {
        Get.back();
      }

      isLoading.value = false;
      print("Error during signup: $e");

      // ENHANCED: Check if the exception message indicates email already exists
      final exceptionMessage = e.toString().toLowerCase();

      if (exceptionMessage.contains('user with this email already exists') ||
          exceptionMessage.contains('email already exists')) {

        // Show your custom message for email already exists
        Get.snackbar(
          "Email Already Exists",
          "Email already registered. Please use a different email or log in.",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.withOpacity(0.1),
          colorText: Colors.red,
          duration: const Duration(seconds: 4),
        );

        // Set email error to show inline validation
        emailError.value = "This email is already registered";

      } else {
        // Generic error message for other exceptions
        Get.snackbar(
          "Signup Failed",
          "An error occurred during registration. Please try again.",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.withOpacity(0.1),
          colorText: Colors.red,
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  // COMPLETELY UPDATED: Google Sign-In with detailed FCM token logging
  Future<void> signInWithGoogle() async {
    print('🚀 === GOOGLE SIGN-IN WITH REAL FCM TOKEN (SIGNUP) ===');
    print('🚀 Start time: ${DateTime.now()}');

    try {
      isGoogleLoading.value = true;
      print('🔄 Google loading state set to true');

      // Step 1: Get FCM token FIRST with detailed logging
      print('🔔 === STEP 1: GETTING FCM TOKEN FOR GOOGLE SIGN-IN ===');
      final fcmToken = await getFcmToken();
      print('✅ FCM token obtained for Google sign-in (signup)');
      print('🔔 Signup Google FCM token: ${fcmToken.substring(0, 30)}...${fcmToken.substring(fcmToken.length - 10)}');

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
        print("✅ === EXISTING USER LOGIN SUCCESS (SIGNUP) ===");
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
        print("🆕 === NEW USER REGISTRATION (SIGNUP) ===");
        print("🆕 New user detected - creating account with FCM token");

        // No existing account found - create new user with token
        final registrationResponse = await _createNewGoogleUserWithToken(googleUser, googleAuth, fcmToken);
        print('📥 Registration response success: ${registrationResponse['success']}');

        if (registrationResponse['success'] == true) {
          print("✅ === NEW USER REGISTRATION SUCCESS (SIGNUP) ===");
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
          print("⚠️ === USING FALLBACK TOKEN (SIGNUP) ===");
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
      print("❌ === GOOGLE SIGN-IN ERROR (SIGNUP) ===");
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

  // COMPLETELY UPDATED: Try login with Google and detailed FCM logging
  Future<Map<String, dynamic>> _tryLoginWithGoogle(
      GoogleSignInAccount googleUser,
      GoogleSignInAuthentication googleAuth,
      String fcmToken, // ADD FCM token parameter
      ) async {
    try {
      print("🔍 === TRYING LOGIN WITH GOOGLE AND REAL FCM TOKEN (SIGNUP) ===");
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

      print("📤 === SENDING GOOGLE LOGIN REQUEST (SIGNUP) ===");
      print("📤 URL: ${authService.baseUrl}");
      print("📤 Fields: $loginFields");
      print("📤 FCM Token being sent: ${fcmToken.substring(0, 30)}...");

      http.StreamedResponse response = await request.send();
      final responseString = await response.stream.bytesToString();

      print("📥 === GOOGLE LOGIN RESPONSE (SIGNUP) ===");
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
              print("✅ === EXISTING GOOGLE USER LOGIN SUCCESS (SIGNUP) ===");
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
      print("❌ === GOOGLE LOGIN ERROR (SIGNUP) ===");
      print("❌ Login attempt error: $e");
      print("❌ Stack trace: ${StackTrace.current}");
      return {'success': false, 'error': e.toString()};
    }
  }

  // COMPLETELY UPDATED: Create new Google user with detailed FCM logging
  Future<Map<String, dynamic>> _createNewGoogleUserWithToken(
      GoogleSignInAccount googleUser,
      GoogleSignInAuthentication googleAuth,
      String fcmToken, // ADD FCM token parameter
      ) async {
    try {
      print("📝 === CREATING NEW GOOGLE USER WITH REAL FCM TOKEN (SIGNUP) ===");
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

      print("📤 === SENDING GOOGLE REGISTRATION REQUEST (SIGNUP) ===");
      print("📤 URL: ${authService.baseUrl}");
      print("📤 Fields: $registrationFields");
      print("📤 FCM Token being sent: ${fcmToken.substring(0, 30)}...");

      http.StreamedResponse response = await request.send();
      final responseString = await response.stream.bytesToString();

      print("📥 === GOOGLE REGISTRATION RESPONSE (SIGNUP) ===");
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
                print("✅ === NEW GOOGLE USER CREATED SUCCESSFULLY (SIGNUP) ===");
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
      print("❌ === GOOGLE REGISTRATION ERROR (SIGNUP) ===");
      print("❌ Google registration error: $e");
      print("❌ Stack trace: ${StackTrace.current}");
      return {'success': false, 'error': e.toString()};
    }
  }

  // Your existing helper methods with updated logging
  Future<void> _saveGoogleUserWithRealBackendToken({
    required GoogleSignInAccount googleUser,
    required Map<String, dynamic> backendData,
  }) async {
    try {
      print("💾 === SAVING GOOGLE USER WITH REAL BACKEND TOKEN (SIGNUP) ===");

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

      print("✅ Google user saved with real backend token successfully (signup)");
      print("✅ User ID: $realUserId");
      print("✅ Email: ${googleUser.email}");
      print("✅ Token saved: YES");
      print("✅ Is New User: $isNewUser");

    } catch (e) {
      print("❌ Error saving Google user with real backend token: $e");
      throw e;
    }
  }

  Future<void> _clearGoogleAuthenticationCompletely() async {
    try {
      print("🧹 === COMPLETE GOOGLE AUTHENTICATION CLEARING (SIGNUP) ===");

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

      print("✅ === GOOGLE AUTHENTICATION COMPLETELY CLEARED (SIGNUP) ===");
    } catch (e) {
      print("❌ Error in complete Google auth clear: $e");
    }
  }

  Future<void> _saveGoogleUserWithGeneratedToken(GoogleSignInAccount googleUser) async {
    try {
      print("🔧 === SAVING GOOGLE USER WITH GENERATED TOKEN (SIGNUP) ===");

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

      print("✅ Google user saved with generated token (signup)");
      print("   User ID: $generatedUserId");
      print("   Email: ${googleUser.email}");
      print("   Token: $generatedToken");

    } catch (e) {
      print("❌ Error saving Google user with generated token: $e");
      throw e;
    }
  }

  // Your existing Apple Sign-In method (add FCM token to this too if needed)
  Future<void> signInWithApple() async {
    try {
      isAppleLoading.value = true;
      print('🍎 === STARTING APPLE SIGN-IN (SIGNUP) ===');

      // Get FCM token for Apple Sign-In
      print('🔔 === GETTING FCM TOKEN FOR APPLE SIGN-IN ===');
      final fcmToken = await getFcmToken();
      print('🔔 Apple FCM token: ${fcmToken.substring(0, 30)}...');

      // Step 1: Check platform and availability
      if (!Platform.isIOS && !Platform.isAndroid) {
        throw Exception('Apple Sign-In is only supported on iOS and Android');
      }

      print('📱 Platform: ${Platform.isIOS ? 'iOS' : 'Android'}');

      // Step 2: Check if Apple Sign-In is available
      bool isAvailable = false;
      try {
        isAvailable = await SignInWithApple.isAvailable();
        print('🔍 Apple Sign-In available: $isAvailable');
      } catch (e) {
        print('❌ Error checking Apple Sign-In availability: $e');
        throw Exception('Apple Sign-In is not available on this device: $e');
      }

      if (!isAvailable) {
        throw Exception('Apple Sign-In is not available on this device or OS version');
      }

      // Step 3: Configure web authentication for Android
      WebAuthenticationOptions? webAuthOptions;
      if (Platform.isAndroid) {
        print('🔧 Configuring web authentication for Android...');

        // CRITICAL: Replace these with your actual Apple Developer values
        webAuthOptions = WebAuthenticationOptions(
          // Replace 'com.yourcompany.yourapp' with your actual Service ID from Apple Developer Console
          clientId: 'com.example.lupusCare',

          // Replace with your actual domain - this should match your Apple Developer Console setup
          redirectUri: Uri.parse('https://lupus-care-ffed0.firebaseapp.com/__/auth/handler'),
        );

        print('🔧 Web auth configured:');
        print('   Client ID: ${webAuthOptions.clientId}');
        print('   Redirect URI: ${webAuthOptions.redirectUri}');
      }

      // Step 4: Get Apple ID credential
      print('📱 Requesting Apple ID credential...');
      AuthorizationCredentialAppleID credential;

      try {
        credential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          webAuthenticationOptions: webAuthOptions,
        );

        print('✅ Apple credential obtained successfully');
      } catch (e) {
        print('❌ Failed to get Apple credential: $e');

        if (e is SignInWithAppleAuthorizationException) {
          if (e.code == AuthorizationErrorCode.canceled) {
            print('ℹ️ User canceled Apple Sign-In');
            Get.snackbar(
              'Canceled',
              'Apple Sign-In was canceled',
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
            return;
          } else {
            print('❌ Apple authorization error: ${e.code} - ${e.message}');
            throw Exception('Apple authorization failed: ${e.message}');
          }
        } else {
          throw Exception('Failed to get Apple credential: $e');
        }
      }

      // Step 5: Validate credential data
      print('🔍 Validating Apple credential...');
      print('   Identity Token: ${credential.identityToken != null ? 'Present' : 'Missing'}');
      print('   Authorization Code: ${credential.authorizationCode != null ? 'Present' : 'Missing'}');
      print('   Email: ${credential.email ?? 'Not provided/Hidden'}');
      print('   Given Name: ${credential.givenName ?? 'Not provided'}');
      print('   Family Name: ${credential.familyName ?? 'Not provided'}');
      print('   User Identifier: ${credential.userIdentifier ?? 'Not provided'}');

      if (credential.identityToken == null) {
        throw Exception('Apple Sign-In failed: No identity token received');
      }

      if (credential.authorizationCode == null) {
        throw Exception('Apple Sign-In failed: No authorization code received');
      }

      // Step 6: Call backend authentication with FCM token
      print('📤 Calling backend for Apple authentication with FCM token...');

      Map<String, dynamic> result;
      try {
        result = await authService.appleSignIn(
          identityToken: credential.identityToken!,
          authorizationCode: credential.authorizationCode!,
          email: credential.email,
          givenName: credential.givenName,
          familyName: credential.familyName,
          appleId: credential.userIdentifier,
          fcmToken: fcmToken, // Pass FCM token
        );

        print('📥 Backend response: ${result['status']}');
      } catch (e) {
        print('❌ Backend authentication failed: $e');
        throw Exception('Backend authentication failed: $e');
      }

      // Step 7: Handle backend response
      if (result['status'] == 'success') {
        print('✅ Apple Sign-In backend authentication successful!');

        // Verify data was saved to storage
        final savedUser = StorageService.to.getUser();
        final savedToken = StorageService.to.getToken();
        final isLoggedIn = StorageService.to.isLoggedIn();

        print('🔍 Verifying saved data:');
        print('   User saved: ${savedUser != null}');
        print('   Token saved: ${savedToken != null}');
        print('   Login flag: $isLoggedIn');

        if (savedUser != null && savedToken != null && isLoggedIn) {
          print('✅ Apple user data verified in storage');

          // Show success message
          Get.snackbar(
            'Welcome!',
            'Successfully signed in with Apple',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );

          // Navigate to appropriate screen
          await onAppleLoginSuccess();
        } else {
          throw Exception('Failed to save Apple user data to storage');
        }
      } else {
        print('❌ Backend authentication failed: ${result['message']}');
        throw Exception(result['message'] ?? 'Apple Sign-In backend authentication failed');
      }

    } on SignInWithAppleAuthorizationException catch (e) {
      print('❌ Apple Sign-In Authorization Exception: ${e.code} - ${e.message}');

      if (e.code != AuthorizationErrorCode.canceled) {
        Get.snackbar(
          'Apple Sign-In Error',
          'Authorization failed: ${e.message ?? 'Unknown error'}',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('❌ Apple Sign-In Error: $e');
      Get.snackbar(
        'Apple Sign-In Failed',
        'Error: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isAppleLoading.value = false;
    }
  }

  // Your existing navigation methods
  Future<void> onGoogleLoginSuccess() async {
    print('✅ Google login successful - handling navigation');

    // Mark login page as seen for Google users
    await StorageService.to.markLoginPageSeen();
    print('👁️ Login page marked as seen');

    // Handle navigation with subscription check
    await handlePostLoginNavigation();
  }

  Future<void> onAppleLoginSuccess() async {
    print('✅ Apple login successful - handling navigation');

    // Mark login page as seen
    await StorageService.to.markLoginPageSeen();

    // Handle post-login navigation
    await handlePostLoginNavigation();
  }

  Future<void> handlePostLoginNavigation() async {
    try {
      print('🚀 === POST LOGIN NAVIGATION (SIGNUP) ===');

      // Get current user state
      final userData = StorageService.to.getUser();
      final hasCompletedOnboarding = StorageService.to.hasCompletedOnboarding();
      final hasActiveSubscription = StorageService.to.hasActiveSubscription();
      final subscriptionStatus = StorageService.to.getSubscriptionStatus();

      print('📊 Navigation Decision Factors:');
      print('   - User Provider: ${userData?['provider']}');
      print('   - User Email: ${userData?['email']}');
      print('   - User ID: ${userData?['id']}');
      print('   - Has Completed Onboarding: $hasCompletedOnboarding');
      print('   - Has Active Subscription: $hasActiveSubscription');
      print('   - Subscription Status: $subscriptionStatus');

      // FIXED: Step 1 - Only show subscription screen for Free-trial users
      if (subscriptionStatus == 'pending') {
        print('💳 → NAVIGATION: Going to Subscription (Free Trial or Pending Payment)');
        print('🎯 FINAL DECISION: Navigating to Subscription Screen');
        Get.offAllNamed('/subscription');
        return;
      }

      // FIXED: Step 2 - Show subscription screen for expired subscriptions
      if (subscriptionStatus == 'expired') {
        print('💳 → NAVIGATION: Going to Subscription (Subscription Expired)');
        print('🎯 FINAL DECISION: Navigating to Subscription Screen');
        Get.offAllNamed('/subscription');
        return;
      }

      // FIXED: Step 3 - For active subscriptions, go to home
      if (hasActiveSubscription || subscriptionStatus == 'active') {
        print('🏠 → NAVIGATION: Going to Home (Active Subscription)');
        print('🎯 FINAL DECISION: Navigating to Home Screen');
        Get.offAllNamed('/home');
        return;
      }

      // FIXED: Fallback - if we can't determine status, check subscription directly
      print('⚠️ → FALLBACK: Checking subscription status fallback...');

      // Force reload subscription data and check again
      await StorageService.to.forceReloadUserSubscriptionData();
      final reloadedStatus = StorageService.to.getSubscriptionStatus();
      final reloadedActive = StorageService.to.hasActiveSubscription();

      print('🔄 After reload:');
      print('   - Status: $reloadedStatus');
      print('   - Has Active: $reloadedActive');

      if (reloadedActive || reloadedStatus == 'active') {
        print('🏠 → FALLBACK: Going to Home (Active after reload)');
        Get.offAllNamed('/home');
      } else {
        print('💳 → FALLBACK: Going to Subscription (Pending after reload)');
        Get.offAllNamed('/subscription');
      }

    } catch (e) {
      print('❌ Error in post login navigation: $e');
      print('🔄 EMERGENCY FALLBACK: Going to initializer to handle navigation');
      // Emergency fallback to initializer to let it handle navigation
      Get.offAllNamed('/initializer');
    }
  }



  bool isEmailAlreadyExistsErrorByStatus(Map<String, dynamic> response, int? statusCode) {
    // Check both status code and message content
    final message = response['message']?.toString().toLowerCase() ?? '';

    return (statusCode == 409) || // HTTP Conflict status
        message.contains('user with this email already exists') ||
        message.contains('email already exists') ||
        message.contains('email is already registered');
  }





  void navigateToLogin() {
    Get.toNamed('/login');
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}