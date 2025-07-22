import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lupus_care/data/api/auth_service.dart';
import 'package:lupus_care/data/api/profile_service.dart';
import 'package:lupus_care/helper/storage_service.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:http/http.dart' as http;

class CreateProfileController extends GetxController with WidgetsBindingObserver {
  // Service instance
  final ProfileService _profileService = ProfileService();
  Timer? _autoSaveTimer;
  bool _isAutoSaving = false;
  static const int USERNAME_MIN_LENGTH = 3;
  static const int USERNAME_MAX_LENGTH = 30;
  static const int FULL_NAME_MIN_LENGTH = 2;
  static const int FULL_NAME_MAX_LENGTH = 50;

  RxString usernameText = ''.obs;
  // Image selection
  Rx<File?> selectedImage = Rx<File?>(null);
  final ImagePicker _picker = ImagePicker();
  final RxString imageError = ''.obs;
  String _originalUsername = '';

  // Form controllers
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController editUsernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  // Reactive state variables
  final RxString username = ''.obs;
  final RxString usernameError = ''.obs;
  var isPushNotificationEnabled = true.obs;
  RxBool notificationsEnabled = true.obs;
  RxBool isLoading = false.obs;

  // Profile completion tracking
  RxBool hasCompletedProfile = false.obs;
  RxBool hasDraftData = false.obs;

  @override

  void onInit() {
    super.onInit();
    print("🔄 === PROFILE CONTROLLER INITIALIZED (ENHANCED) ===");

    // CRITICAL: Add app lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // Check if user is returning from app kill
    _checkReturnFromAppKill();

    // Initialize profile state
    _initializeProfileState();

    // Set up auto-save listeners
    _setupEnhancedAutoSaveListeners();

    // Load any existing draft data
    _loadDraftData();

    // Pre-populate fields from user data
    _populateUserData();

    // CRITICAL: Mark that user is actively in profile creation ONLY if profile is not completed
    if (!hasCompletedProfile.value) {
      _markProfileCreationInProgress();
    }

    // ENHANCED: Add real-time username validation listener
    usernameController.addListener(() {
      // Real-time validation - update error as user types
      final validation = validateUsername(usernameController.text);
      usernameError.value = validation ?? '';

      // Sync the reactive variable with controller text
      usernameText.value = usernameController.text;
    });

    // NEW: Add listener to clear image error when image is selected
    selectedImage.listen((image) {
      if (image != null && imageError.value.isNotEmpty) {
        imageError.value = '';
      }
    });
  }

// ENHANCED: Create reactive username validation getter
  String? get usernameValidationError {
    // This will be reactive and update automatically
    return usernameError.value.isEmpty ? null : usernameError.value;
  }

  Future<Map<String, dynamic>> _createGoogleUserProfileEnhanced({
    required String userId,
    required String username,
    required String fullName,
    required String email,
    required bool hasImage,
  }) async {
    try {
      print('📤 === ENHANCED GOOGLE USER PROFILE CREATION ===');

      final token = StorageService.to.getToken() ?? '';
      final userData = StorageService.to.getUser();

      // CRITICAL: Check for existing Google profile image first
      String? googleProfileImageUrl = _extractGoogleProfileImage(userData);
      print('🖼️ Google profile image URL found: ${googleProfileImageUrl ?? 'None'}');

      final authService = AuthService();
      final baseUrl = authService.baseUrl;

      var request = http.MultipartRequest('POST', Uri.parse(baseUrl));

      // Add form fields with Google-specific data
      request.fields.addAll({
        'request': 'create_profile',
        'user_id': userId,
        'username': username,
        'unique_username': username,
        'full_name': fullName,
        'email': email,
        'provider': 'google',
        'is_google_user': 'true',
        'google_user': '1',
        'notifications_enabled': notificationsEnabled.value.toString(),
        'profile_type': 'google_enhanced',
      });

      // ENHANCED: Handle Google profile image URL if available
      if (googleProfileImageUrl != null && googleProfileImageUrl.isNotEmpty) {
        request.fields['google_profile_image_url'] = googleProfileImageUrl;
        request.fields['has_google_image'] = 'true';
        print('✅ Added Google profile image URL to request: $googleProfileImageUrl');
      }

      // ENHANCED: Handle user-selected image (if any) - this takes precedence over Google image
      if (hasImage && selectedImage.value != null) {
        try {
          print('🔄 Processing user-selected image (overrides Google image)...');

          if (!selectedImage.value!.existsSync()) {
            throw Exception('Selected image file not found');
          }

          String fileName = selectedImage.value!.path.split('/').last;
          String fileExtension = fileName.split('.').last.toLowerCase();

          if (!['jpg', 'jpeg', 'png'].contains(fileExtension)) {
            throw Exception('Invalid image format. Use JPG, JPEG, or PNG');
          }

          String contentType = fileExtension == 'png' ? 'image/png' : 'image/jpeg';
          String uniqueFileName = 'google_profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

          request.files.add(
            await http.MultipartFile.fromPath(
              'profile_image',
              selectedImage.value!.path,
              filename: uniqueFileName,
              contentType: MediaType.parse(contentType),
            ),
          );

          // Override Google image flag since user selected a new one
          request.fields['has_user_selected_image'] = 'true';
          request.fields['override_google_image'] = 'true';

          print('✅ User-selected image added, will override Google image');

        } catch (e) {
          print('❌ Failed to process user-selected image: $e');
          // Fall back to Google image if available
          if (googleProfileImageUrl == null || googleProfileImageUrl.isEmpty) {
            throw Exception('Failed to process profile image and no Google image available: $e');
          }
          print('⚠️ Falling back to Google profile image due to user image error');
        }
      }

      // Add headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'User-Agent': 'LupusCare-GoogleEnhanced/1.0',
      });

      print('📤 Sending enhanced Google profile request...');
      print('🌐 URL: $baseUrl');
      print('📋 Fields: ${request.fields.keys.toList()}');
      print('📎 Files: ${request.files.length}');
      print('🖼️ Has Google Image URL: ${googleProfileImageUrl != null}');
      print('🖼️ Has User Selected Image: ${selectedImage.value != null}');

      // Send request with extended timeout
      http.StreamedResponse response = await request.send().timeout(
        Duration(seconds: 45),
        onTimeout: () => throw Exception('Request timeout - please try again'),
      );

      final responseString = await response.stream.bytesToString();

      print('📥 Enhanced Google response status: ${response.statusCode}');
      print('📥 Enhanced Google response: $responseString');

      return _parseGoogleProfileResponseEnhanced(
        response.statusCode,
        responseString,
        hasImage || googleProfileImageUrl != null,
        originalGoogleImageUrl: googleProfileImageUrl,
      );

    } catch (e) {
      print('❌ Enhanced Google profile creation error: $e');
      return {
        'status': 'error',
        'message': 'Enhanced Google profile creation failed: ${e.toString()}',
      };
    }
  }

// NEW: Extract Google profile image from user data
  String? _extractGoogleProfileImage(Map<String, dynamic>? userData) {
    if (userData == null) return null;

    // Check for Google profile image in various possible fields
    final googleImageFields = [
      'picture',           // Standard Google profile field
      'google_picture',    // Our custom field
      'photo',            // Alternative Google field
      'avatar',           // Generic avatar field
      'profile_image',    // Our standard field
      'image',            // Generic image field
      'google_profile_image', // Explicit Google profile image
    ];

    for (String field in googleImageFields) {
      final imageUrl = userData[field];
      if (imageUrl != null && imageUrl.toString().trim().isNotEmpty) {
        String url = imageUrl.toString().trim();

        // Validate that it looks like a valid image URL
        if (url.startsWith('http') &&
            (url.contains('googleusercontent') ||
                url.contains('google') ||
                url.contains('.jpg') ||
                url.contains('.png') ||
                url.contains('.jpeg'))) {
          print('🖼️ Found Google profile image in field "$field": $url');
          return url;
        }
      }
    }

    print('❌ No Google profile image found in user data');
    return null;
  }

// ENHANCED: Update the response parsing to handle Google images better
  Map<String, dynamic> _parseGoogleProfileResponseEnhanced(
      int statusCode,
      String responseString,
      bool hasImage, {
        String? originalGoogleImageUrl,
      }) {
    print('🔍 === ENHANCED GOOGLE RESPONSE PARSING ===');
    print('📊 Status Code: $statusCode');
    print('📊 Has Image: $hasImage');
    print('📊 Original Google Image: ${originalGoogleImageUrl ?? 'None'}');

    if (responseString.trim().isEmpty) {
      print('⚠️ Empty response from server');
      var result = statusCode == 200
          ? {'status': 'success', 'message': 'Profile created successfully'}
          : {'status': 'error', 'message': 'Server returned empty response'};

      // CRITICAL: Preserve Google image URL in successful empty responses
      if (statusCode == 200 && originalGoogleImageUrl != null) {
        result['profile_image_url'] = originalGoogleImageUrl;
        result['google_image_preserved'] = true as String;
        print('✅ Google image URL preserved in empty response: $originalGoogleImageUrl');
      }

      return result;
    }

    // Handle HTML error responses
    if (responseString.trim().toLowerCase().startsWith('<html')) {
      print('❌ HTML error response received');
      return {'status': 'error', 'message': 'Server error (HTML response)'};
    }

    // Handle non-JSON responses
    if (!responseString.trim().startsWith('{') && !responseString.trim().startsWith('[')) {
      print('⚠️ Non-JSON response: ${responseString.substring(0, 100)}...');

      final lowerResponse = responseString.toLowerCase();
      if (lowerResponse.contains('success') || lowerResponse.contains('created')) {
        var result = {
          'status': 'success',
          'message': 'Profile created successfully',
          'raw_response': responseString.trim()
        };

        // CRITICAL: Preserve Google image URL in non-JSON success responses
        if (originalGoogleImageUrl != null) {
          result['profile_image_url'] = originalGoogleImageUrl;
          result['google_image_preserved'] = true as String;
          print('✅ Google image URL preserved in non-JSON response: $originalGoogleImageUrl');
        }

        return result;
      } else {
        return {
          'status': 'error',
          'message': 'Server error: ${responseString.trim()}'
        };
      }
    }

    // Parse JSON response
    try {
      final jsonResponse = json.decode(responseString);
      print('✅ JSON parsed successfully');
      print('🔍 Response keys: ${jsonResponse.keys.toList()}');

      // Ensure status field exists
      if (!jsonResponse.containsKey('status')) {
        jsonResponse['status'] = statusCode == 200 ? 'success' : 'error';
        print('➕ Added status field: ${jsonResponse['status']}');
      }

      // CRITICAL: Enhanced image URL handling for successful responses
      if (jsonResponse['status'] == 'success') {
        String? finalImageUrl;

        // First, try to extract image URL from API response
        String? apiImageUrl = _extractImageUrlFromResponse(jsonResponse);

        if (apiImageUrl != null && apiImageUrl.isNotEmpty) {
          finalImageUrl = apiImageUrl;
          jsonResponse['image_source'] = 'api_response';
          print('🖼️ ✅ Using image URL from API response: $finalImageUrl');
        } else if (originalGoogleImageUrl != null && originalGoogleImageUrl.isNotEmpty) {
          finalImageUrl = originalGoogleImageUrl;
          jsonResponse['image_source'] = 'google_original';
          print('🖼️ ✅ Using original Google image URL: $finalImageUrl');
        }

        if (finalImageUrl != null) {
          jsonResponse['profile_image_url'] = finalImageUrl;
          jsonResponse['profile_image'] = finalImageUrl; // Also save in standard field
          jsonResponse['image_found'] = true;
          print('🖼️ ✅ Final image URL set: $finalImageUrl');
        } else {
          print('⚠️ No image URL available for Google user');
          jsonResponse['image_found'] = false;
          _logResponseFields(jsonResponse);
        }
      }

      return jsonResponse;

    } catch (e) {
      print('❌ JSON parse error: $e');
      print('📄 Raw response: $responseString');

      // Fallback for non-JSON success responses
      var result = statusCode == 200
          ? {
        'status': 'success',
        'message': 'Profile created successfully',
        'parse_error': e.toString(),
        'raw_response': responseString
      }
          : {
        'status': 'error',
        'message': 'Response parse error: ${e.toString()}'
      };

      // CRITICAL: Preserve Google image even in parse errors
      if (statusCode == 200 && originalGoogleImageUrl != null) {
        result['profile_image_url'] = originalGoogleImageUrl;
        result['google_image_preserved'] = true as String;
        print('✅ Google image URL preserved despite parse error: $originalGoogleImageUrl');
      }

      return result;
    }
  }

// ALTERNATIVE: If you want even more immediate feedback, you can use this approach:
  String? get realtimeUsernameValidationError {
    return validateUsername(usernameController.text);
  }


  String? validateUsername(String value) {
    final trimmedValue = value.trim();

    if (trimmedValue.isEmpty) {
      return "Username is required";
    }

    if (trimmedValue.length < USERNAME_MIN_LENGTH) {
      return "Username must be at least $USERNAME_MIN_LENGTH characters long";
    }

    if (trimmedValue.length > USERNAME_MAX_LENGTH) {
      return "Username cannot exceed $USERNAME_MAX_LENGTH characters";
    }

    if (!RegExp(r'^[a-zA-Z]').hasMatch(trimmedValue)) {
      return "Username must start with a letter";
    }

    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_.]*$').hasMatch(trimmedValue)) {
      return "Username can only contain letters, numbers, underscore (_), and dot (.)";
    }

    if (trimmedValue.contains(' ')) {
      return "Username cannot contain spaces";
    }

    if (trimmedValue.contains('..') || trimmedValue.contains('__')) {
      return "Username cannot contain consecutive dots or underscores";
    }

    if (trimmedValue.endsWith('.') || trimmedValue.endsWith('_')) {
      return "Username cannot end with dot or underscore";
    }

    return null; // null means validation passed
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
        print("📱 App paused - auto-saving profile data");
        if (!hasCompletedProfile.value) {
          _autoSaveProfileData();
        }
        break;
      case AppLifecycleState.detached:
        print("📱 App detached - auto-saving profile data");
        if (!hasCompletedProfile.value) {
          _autoSaveProfileData();
        }
        break;
      case AppLifecycleState.inactive:
        print("📱 App inactive - auto-saving profile data");
        if (!hasCompletedProfile.value) {
          _autoSaveProfileData();
        }
        break;
      case AppLifecycleState.resumed:
        print("📱 App resumed - checking for draft data");
        _loadDraftData();
        break;
      default:
        break;
    }
  }

  @override
  void onClose() {
    // CRITICAL: Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // CRITICAL: Auto-save before closing ONLY if profile is not completed
    if (!hasCompletedProfile.value) {
      print("💾 === PROFILE CONTROLLER CLOSING - AUTO-SAVING ===");
      _autoSaveProfileData();
    }

    _autoSaveTimer?.cancel();

    fullNameController.dispose();
    usernameController.dispose();
    editUsernameController.dispose();
    emailController.dispose();

    super.onClose();
  }

  // Mark that user is actively in profile creation
  Future<void> _markProfileCreationInProgress() async {
    try {
      final userData = StorageService.to.getUser();
      if (userData == null) return;

      if (!hasCompletedProfile.value) {
        final updatedUserData = Map<String, dynamic>.from(userData);
        updatedUserData['draft_in_progress'] = true;
        updatedUserData['profile_creation_started_at'] = DateTime.now().toIso8601String();

        await StorageService.to.saveUser(updatedUserData);
        print("✅ Profile creation marked as in progress");
      }
    } catch (e) {
      print("❌ Error marking profile creation in progress: $e");
    }
  }

  void _checkReturnFromAppKill() {
    try {
      final userData = StorageService.to.getUser();
      if (userData == null) return;

      final wasInProfileCreation = userData['draft_in_progress'] == true;
      final hasSignificantDraft = userData.containsKey('draft_full_name') &&
          userData['draft_full_name']?.toString().trim().isNotEmpty == true;

      if (wasInProfileCreation || hasSignificantDraft) {
        print("🔄 User returning from app kill with draft data");
      }
    } catch (e) {
      print("❌ Error checking return from app kill: $e");
    }
  }

  void _setupEnhancedAutoSaveListeners() {
    fullNameController.addListener(() => _scheduleAutoSave(immediate: false));
    usernameController.addListener(() => _scheduleAutoSave(immediate: false));
    notificationsEnabled.listen((_) => _scheduleAutoSave(immediate: true));
    selectedImage.listen((_) => _scheduleAutoSave(immediate: true));

    print("✅ Enhanced auto-save listeners set up");
  }

  void _scheduleAutoSave({bool immediate = false}) {
    if (_isAutoSaving || hasCompletedProfile.value) return;

    _autoSaveTimer?.cancel();

    if (immediate) {
      _autoSaveProfileData();
    } else {
      _autoSaveTimer = Timer(Duration(milliseconds: 800), () {
        _autoSaveProfileData();
      });
    }
  }

  void _initializeProfileState() {
    try {
      hasCompletedProfile.value = StorageService.to.hasCompletedProfile();
      print("👤 Profile completion status: ${hasCompletedProfile.value}");
    } catch (e) {
      print("❌ Error initializing profile state: $e");
    }
  }





  Future<void> _clearDraftData() async {
    try {
      final userData = StorageService.to.getUser();
      if (userData == null) return;

      print("🧹 === CLEARING ALL DRAFT DATA ===");

      final keysToRemove = [
        'draft_full_name',
        'draft_username',
        'draft_notifications_enabled',
        'draft_saved_at',
        'draft_has_image',
        'draft_image_path',
        'draft_in_progress',
        'profile_creation_started_at'
      ];

      for (String key in keysToRemove) {
        userData.remove(key);
      }

      await StorageService.to.saveUser(userData);
      hasDraftData.value = false;

      print("✅ ALL draft profile data cleared completely");
    } catch (e) {
      print("❌ Error clearing draft data: $e");
    }
  }

  Future<void> forceSaveProfileData() async {
    if (!hasCompletedProfile.value) {
      print("🔄 Force saving profile data...");
      await _autoSaveProfileData();
    }
  }

  Future<void> clearAllProfileData() async {
    try {
      fullNameController.clear();
      usernameController.clear();
      emailController.clear();
      selectedImage.value = null;
      notificationsEnabled.value = true;

      usernameError.value = '';
      imageError.value = '';

      await _clearDraftData();

      print("✅ All profile data cleared");
    } catch (e) {
      print("❌ Error clearing profile data: $e");
    }
  }

  void _populateUserData() {
    try {
      final userData = StorageService.to.getUser();
      if (userData != null) {
        print('📋 Populating form with user data: ${userData['email']}');

        emailController.text = userData['email']?.toString() ?? '';

        if (fullNameController.text.isEmpty) {
          final fullName = userData['full_name'] ?? userData['name'] ?? '';
          fullNameController.text = fullName.toString();
        }

        if (usernameController.text.isEmpty) {
          final email = userData['email']?.toString() ?? '';
          if (email.isNotEmpty) {
            final emailPart = email.split('@')[0];
            usernameController.text = emailPart.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
          }
        }

        print('✅ Form pre-populated with user data');
      } else {
        print('⚠️ No user data found for form population');
      }
    } catch (e) {
      print('❌ Error populating user data: $e');
    }
  }

  void toggleNotifications(bool value) {
    notificationsEnabled.value = value;
    if (!hasCompletedProfile.value) {
      _scheduleAutoSave();
    }
  }

  void saveProfile() async {
    if (!validateProfileData()) {
      return;
    }

    try {
      isLoading.value = true;
      print('🚀 === STARTING ENHANCED PROFILE CREATION ===');

      final userData = StorageService.to.getUser();
      final token = StorageService.to.getToken();

      if (userData == null || token == null) {
        throw Exception("Authentication data missing. Please sign in again.");
      }

      String? userId = _extractUserId(userData);
      if (userId == null || userId.isEmpty) {
        throw Exception("User ID not found. Please sign in again.");
      }

      String username = usernameController.text.trim();
      String fullName = fullNameController.text.trim();
      String email = emailController.text.trim();

      print('📋 Enhanced profile creation details:');
      print('   User ID: $userId');
      print('   Username: $username');
      print('   Full Name: $fullName');
      print('   Email: $email');
      print('   Image selected: ${selectedImage.value != null}');

      // ✅ STEP 1: Save image locally FIRST (for offline capability)
      String? localImagePath;
      if (selectedImage.value != null) {
        print('💾 Saving profile image locally...');
        localImagePath = await StorageService.to.saveProfileImageLocally(
          selectedImage.value!,
          userId,
        );

        if (localImagePath != null) {
          print('✅ Profile image saved locally: $localImagePath');
        } else {
          print('⚠️ Failed to save image locally, continuing with upload...');
        }
      }

      // ✅ STEP 2: Save basic profile data locally (for offline access)
      print('💾 Saving profile data locally...');
      await StorageService.to.saveLocalProfileData(
        username: username,
        fullName: fullName,
        email: email,
        localImagePath: localImagePath,
        additionalData: {
          'user_id': userId,
          'provider': userData['provider'],
          'profile_creation_method': 'mobile_app',
          'offline_created': true,
          'needs_server_sync': true,
        },
      );

      // ✅ STEP 3: Create profile on server
      Map<String, dynamic> response = await _createProfileUnified(
        userId: userId,
        username: username,
        fullName: fullName,
        email: email,
        userData: userData,
        hasImage: true,
      );

      print('📥 Profile creation response: ${response['status']}');

      if (response['status'] == 'success') {
        print('✅ Profile creation API successful');

        // ✅ STEP 4: Extract and handle server response
        String? serverImageUrl = _extractProfileImageUrl(response);

        // ✅ STEP 5: Update local storage with server data
        await _handleSuccessfulProfileCreation(
          username: username,
          fullName: fullName,
          email: email,
          userId: userId,
          userData: userData,
          serverImageUrl: serverImageUrl,
          localImagePath: localImagePath,
          serverResponse: response,
        );

        // ✅ STEP 6: Clean up old images and navigate
        await StorageService.to.cleanupOldProfileImages(userId);
        await _handlePostProfileNavigation();

      } else {
        // ✅ Handle server error but keep local data
        await _handleProfileCreationError(response, keepLocalData: true);
      }

    } catch (e) {
      print('❌ Profile creation error: $e');
      await _handleProfileCreationError({'message': e.toString()}, keepLocalData: true);
    } finally {
      isLoading.value = false;
    }
  }

  // ✅ NEW: Handle successful profile creation with comprehensive local storage
  Future<void> _handleSuccessfulProfileCreation({
    required String username,
    required String fullName,
    required String email,
    required String userId,
    required Map<String, dynamic> userData,
    String? serverImageUrl,
    String? localImagePath,
    required Map<String, dynamic> serverResponse,
  }) async {
    try {
      print('✅ === HANDLING SUCCESSFUL PROFILE CREATION ===');

      // ✅ Mark profile as completed FIRST
      final profileCompleted = await StorageService.to.markProfileAsCompleted();
      if (profileCompleted) {
        print('✅ Profile completion status saved');
        hasCompletedProfile.value = true;
      }

      // ✅ Update user data with comprehensive profile information
      final updatedUserData = Map<String, dynamic>.from(userData);
      updatedUserData.addAll({
        'username': username,
        'unique_username': username,
        'full_name': fullName,
        'profile_completed': true,
        'profile_completed_at': DateTime.now().toIso8601String(),
        'has_profile_picture': true,
        'local_profile_image_path': localImagePath,
      });

      // ✅ Handle image URLs (prefer server URL, keep local as backup)
      if (serverImageUrl != null && serverImageUrl.isNotEmpty) {
        updatedUserData['profile_image'] = serverImageUrl;
        updatedUserData['profile_picture'] = serverImageUrl;
        print('✅ Server image URL saved: $serverImageUrl');

        // ✅ Download server image to replace local image if different
        if (localImagePath == null) {
          final downloadedPath = await StorageService.to.downloadAndSaveProfileImage(
            serverImageUrl,
            userId,
          );
          if (downloadedPath != null) {
            updatedUserData['local_profile_image_path'] = downloadedPath;
            print('✅ Server image downloaded locally: $downloadedPath');
          }
        }
      } else if (localImagePath != null) {
        // Use local image path as fallback
        updatedUserData['profile_image'] = localImagePath;
        updatedUserData['profile_picture'] = localImagePath;
        print('✅ Using local image path as primary: $localImagePath');
      }

      // ✅ Save comprehensive local profile data
      await StorageService.to.saveLocalProfileData(
        username: username,
        fullName: fullName,
        email: email,
        profileImageUrl: serverImageUrl,
        localImagePath: localImagePath,
        additionalData: {
          'user_id': userId,
          'provider': userData['provider'],
          'server_response': serverResponse,
          'profile_creation_method': 'mobile_app',
          'server_synced': true,
          'sync_timestamp': DateTime.now().toIso8601String(),
        },
      );

      // ✅ Clear ALL draft data completely
      await _clearDraftData();

      // ✅ Save updated user data
      await StorageService.to.saveUser(updatedUserData);

      // ✅ Clear form after successful submission
      clearPreviousSessionData();

      // ✅ Show success message
      final hasImage = serverImageUrl != null || localImagePath != null;
      Get.snackbar(
        "Profile Created Successfully!",
        hasImage
            ? "Your profile and picture have been saved locally and synced!"
            : "Your profile has been created successfully!",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );

      print('✅ === PROFILE CREATION SUCCESS HANDLING COMPLETE ===');

    } catch (e) {
      print('❌ Error handling successful profile creation: $e');
      throw Exception('Profile created but local storage failed: $e');
    }
  }

  // ✅ NEW: Handle profile creation errors with local data preservation
  Future<void> _handleProfileCreationError(
      Map<String, dynamic> errorResponse,
      {bool keepLocalData = true}
      ) async {
    try {
      String errorMessage = errorResponse['message'] ?? "Failed to create profile";
      print('❌ Profile creation failed: $errorMessage');

      // ✅ Keep local data for offline access and retry capability
      if (keepLocalData) {
        print('💾 Preserving local profile data for offline access');

        // Mark that we need to sync with server later
        final profileData = StorageService.to.getLocalProfileData();
        if (profileData != null) {
          await StorageService.to.saveLocalProfileData(
            username: profileData['username'] ?? '',
            fullName: profileData['full_name'] ?? '',
            email: profileData['email'] ?? '',
            profileImageUrl: profileData['profile_image_url'],
            localImagePath: profileData['local_image_path'],
            additionalData: {
              'needs_server_sync': true,
              'last_sync_error': errorMessage,
              'last_sync_attempt': DateTime.now().toIso8601String(),
            },
          );
        }
      }

      // ✅ Handle specific error types
      if (errorMessage.toLowerCase().contains('user not found') ||
          errorMessage.toLowerCase().contains('invalid user')) {
        errorMessage = "User account not found. Please sign in again.";
        await StorageService.to.logout();
        Get.offAllNamed('/login');
        return;
      } else if (errorMessage.toLowerCase().contains('username')) {
        usernameError.value = errorMessage;
        return;
      } else if (errorMessage.toLowerCase().contains('token') ||
          errorMessage.toLowerCase().contains('unauthorized')) {
        errorMessage = "Authentication expired. Please sign in again.";
        await StorageService.to.logout();
        Get.offAllNamed('/login');
        return;
      } else if (errorMessage.contains('network') || errorMessage.contains('connection')) {
        errorMessage = "Network error. Your profile data has been saved locally and will sync when connection is restored.";

        // ✅ For network errors, still mark profile as completed locally
        if (keepLocalData) {
          await StorageService.to.markProfileAsCompleted();
          hasCompletedProfile.value = true;

          Get.snackbar(
            "Profile Saved Locally",
            "Your profile has been saved on your device and will sync when you're back online.",
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: Duration(seconds: 5),
          );

          // Navigate normally for network errors since data is saved locally
          await _handlePostProfileNavigation();
          return;
        }
      }

      // ✅ Show error for other cases
      Get.snackbar(
        "Profile Creation Failed",
        errorMessage,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 4),
      );

    } catch (e) {
      print('❌ Error handling profile creation error: $e');
    }
  }

  // ✅ UPDATED: Auto-save with local image handling
  Future<void> _autoSaveProfileData() async {
    if (_isAutoSaving || hasCompletedProfile.value) return;

    try {
      _isAutoSaving = true;

      final userData = StorageService.to.getUser();
      if (userData == null) return;

      final userId = userData['id']?.toString();
      if (userId == null) return;

      final hasData = fullNameController.text.trim().isNotEmpty ||
          usernameController.text.trim().isNotEmpty ||
          selectedImage.value != null;

      if (!hasData) {
        // Just mark that profile creation started
        final updatedUserData = Map<String, dynamic>.from(userData);
        updatedUserData['draft_in_progress'] = true;
        updatedUserData['profile_creation_started_at'] = DateTime.now().toIso8601String();
        await StorageService.to.saveUser(updatedUserData);
        return;
      }

      // ✅ Save image locally during auto-save for better UX
      String? localImagePath;
      if (selectedImage.value != null) {
        print('💾 Auto-saving profile image locally...');
        localImagePath = await StorageService.to.saveProfileImageLocally(
          selectedImage.value!,
          userId,
        );
      }

      // ✅ Save comprehensive draft data
      final draftData = {
        'draft_full_name': fullNameController.text.trim(),
        'draft_username': usernameController.text.trim(),
        'draft_notifications_enabled': notificationsEnabled.value,
        'draft_saved_at': DateTime.now().toIso8601String(),
        'draft_has_image': selectedImage.value != null,
        'draft_image_path': selectedImage.value?.path ?? '',
        'draft_local_image_path': localImagePath ?? '',
        'draft_in_progress': true,
        'profile_creation_started_at': userData['profile_creation_started_at'] ?? DateTime.now().toIso8601String(),
      };

      // ✅ Also save to local profile data for consistency
      await StorageService.to.saveLocalProfileData(
        username: usernameController.text.trim(),
        fullName: fullNameController.text.trim(),
        email: emailController.text.trim(),
        localImagePath: localImagePath,
        additionalData: {
          'user_id': userId,
          'is_draft': true,
          'draft_saved_at': DateTime.now().toIso8601String(),
          'needs_completion': true,
        },
      );

      final updatedUserData = Map<String, dynamic>.from(userData);
      updatedUserData.addAll(draftData);

      final saved = await StorageService.to.saveUser(updatedUserData);

      if (saved) {
        hasDraftData.value = true;
        print("💾 Enhanced profile data auto-saved successfully");
      }

    } catch (e) {
      print("❌ Error in enhanced auto-save: $e");
    } finally {
      _isAutoSaving = false;
    }
  }

  // ✅ UPDATED: Load draft data with local image support
  Future<void> _loadDraftData() async {
    try {
      final userData = StorageService.to.getUser();
      if (userData == null || hasCompletedProfile.value) return;

      print("🔄 Loading enhanced draft profile data...");

      // ✅ First try to load from local profile data
      final localProfileData = StorageService.to.getLocalProfileData();
      if (localProfileData != null && localProfileData['is_draft'] == true) {
        print("📱 Loading from local profile data...");

        fullNameController.text = localProfileData['full_name'] ?? '';
        usernameController.text = localProfileData['username'] ?? '';
        emailController.text = localProfileData['email'] ?? '';

        // Load local image if available
        final localImagePath = localProfileData['local_image_path'];
        if (localImagePath?.isNotEmpty == true && File(localImagePath).existsSync()) {
          selectedImage.value = File(localImagePath);
          print("✅ Local image loaded: $localImagePath");
        }
      }

      // ✅ Then load from user data drafts (for compatibility)
      final hasDraftData = userData.containsKey('draft_full_name') ||
          userData.containsKey('draft_username');

      if (hasDraftData) {
        print("📝 Loading from user data drafts...");

        // Only override if local profile data didn't have values
        if (fullNameController.text.isEmpty) {
          fullNameController.text = userData['draft_full_name'] ?? '';
        }
        if (usernameController.text.isEmpty) {
          usernameController.text = userData['draft_username'] ?? '';
        }

        notificationsEnabled.value = userData['draft_notifications_enabled'] ?? true;

        // ✅ Load local image with multiple fallbacks
        if (selectedImage.value == null) {
          // Try local image path first
          final localImagePath = userData['draft_local_image_path'] ?? '';
          if (localImagePath.isNotEmpty && File(localImagePath).existsSync()) {
            selectedImage.value = File(localImagePath);
            print("✅ Local draft image loaded: $localImagePath");
          } else {
            // Fall back to original image path
            final imagePath = userData['draft_image_path'] ?? '';
            if (imagePath.isNotEmpty && File(imagePath).existsSync()) {
              selectedImage.value = File(imagePath);
              print("✅ Original draft image loaded: $imagePath");
            }
          }
        }

        this.hasDraftData.value = true;
        print("✅ Enhanced draft profile data loaded");
      }

    } catch (e) {
      print("❌ Error loading enhanced draft data: $e");
    }
  }

  // ✅ NEW: Check if we can work offline
  bool canWorkOffline() {
    return StorageService.to.isProfileDataAvailableOffline();
  }

  // ✅ NEW: Get profile display data (for UI)
  Map<String, dynamic> getProfileDisplayData() {
    final localData = StorageService.to.getLocalProfileData();
    final userData = StorageService.to.getUser();

    return {
      'username': StorageService.to.getStoredUsername() ?? 'Unknown User',
      'full_name': StorageService.to.getStoredFullName() ?? 'Unknown Name',
      'profile_image': StorageService.to.getBestAvailableProfileImage(),
      'has_local_image': StorageService.to.getLocalProfileImagePath() != null,
      'is_offline_ready': canWorkOffline(),
      'needs_sync': localData?['needs_server_sync'] == true,
      'last_sync': localData?['sync_timestamp'],
    };
  }

  // ✅ NEW: Retry sync with server
  Future<bool> retrySyncWithServer() async {
    try {
      print('🔄 === RETRYING SYNC WITH SERVER ===');

      final localData = StorageService.to.getLocalProfileData();
      if (localData == null || localData['needs_server_sync'] != true) {
        print('ℹ️ No sync needed');
        return true;
      }

      isLoading.value = true;

      // Re-attempt the profile creation
       saveProfile();

      return true;
    } catch (e) {
      print('❌ Error retrying sync: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ✅ NEW: Debug method for troubleshooting
  void debugProfileStorage() {
    print('🔍 === PROFILE STORAGE DEBUG ===');

    final debugData = StorageService.to.exportProfileDataForDebug();
    debugData.forEach((key, value) {
      print('   $key: $value');
    });

    print('🔍 === END PROFILE STORAGE DEBUG ===');
  }

  // ✅ UPDATED: Enhanced image selection with local storage
  Future<void> pickImageFromGallery() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);

        // Validate the selected image
        if (!imageFile.existsSync()) {
          throw Exception('Selected image file not found');
        }

        // Check file size
        final fileSizeInBytes = imageFile.lengthSync();
        final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
        if (fileSizeInMB > 5) {
          throw Exception('Image size should be less than 5MB');
        }

        selectedImage.value = imageFile;
        imageError.value = '';

        print('✅ Image selected successfully: ${pickedFile.path}');
        print('📄 File size: ${fileSizeInBytes} bytes (${fileSizeInMB.toStringAsFixed(2)} MB)');

        // ✅ Auto-save image locally immediately for better UX
        final userData = StorageService.to.getUser();
        final userId = userData?['id']?.toString();
        if (userId != null && !hasCompletedProfile.value) {
          final localPath = await StorageService.to.saveProfileImageLocally(imageFile, userId);
          if (localPath != null) {
            print('✅ Image auto-saved locally during selection: $localPath');
          }
          _scheduleAutoSave();
        }
      }
    } catch (e) {
      print('Gallery error: $e');
      selectedImage.value = null;
      imageError.value = e.toString();

      Get.snackbar(
        "Gallery Error",
        e.toString(),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // ✅ UPDATED: Enhanced image selection from camera with local storage
  Future<void> pickImageFromCamera() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);

        // Validate the captured image
        if (!imageFile.existsSync()) {
          throw Exception('Captured image file not found');
        }

        // Check file size
        final fileSizeInBytes = imageFile.lengthSync();
        final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
        if (fileSizeInMB > 5) {
          throw Exception('Image size should be less than 5MB');
        }

        selectedImage.value = imageFile;
        imageError.value = '';

        print('✅ Image captured successfully: ${pickedFile.path}');
        print('📄 File size: ${fileSizeInBytes} bytes (${fileSizeInMB.toStringAsFixed(2)} MB)');

        // ✅ Auto-save image locally immediately for better UX
        final userData = StorageService.to.getUser();
        final userId = userData?['id']?.toString();
        if (userId != null && !hasCompletedProfile.value) {
          final localPath = await StorageService.to.saveProfileImageLocally(imageFile, userId);
          if (localPath != null) {
            print('✅ Image auto-saved locally during capture: $localPath');
          }
          _scheduleAutoSave();
        }
      }
    } catch (e) {
      print('Camera error: $e');
      selectedImage.value = null;
      imageError.value = e.toString();

      Get.snackbar(
        "Camera Error",
        e.toString(),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // ✅ NEW: Clear all profile data including local images
  Future<void> clearAllProfileDataIncludingImages() async {
    try {
      selectedImage.value = null;
      fullNameController.clear();
      usernameController.clear();
      emailController.clear();

      usernameError.value = '';
      imageError.value = '';

      // Clear all local profile data including images
      await StorageService.to.clearAllProfileData();

      // Clear draft data
      await _clearDraftData();

      print("✅ All profile data cleared including local images");
    } catch (e) {
      print("❌ Error clearing all profile data: $e");
    }
  }






  Future<void> _handlePostProfileNavigation() async {
    try {
      print('🧭 === POST PROFILE NAVIGATION ===');

      final hasActiveSubscription = StorageService.to.hasActiveSubscription();
      final subscriptionStatus = StorageService.to.getSubscriptionStatus();

      print('📊 Navigation factors:');
      print('   - Profile completed: ${hasCompletedProfile.value}');
      print('   - Has active subscription: $hasActiveSubscription');
      print('   - Subscription status: $subscriptionStatus');

      if (hasActiveSubscription || subscriptionStatus == 'active') {
        print('🏠 → Navigation: Going to Home');
        Get.offAllNamed('/home');
      } else {
        print('💳 → Navigation: Going to Subscription');
        Get.offAllNamed('/subscription');
      }

    } catch (e) {
      print('❌ Error in post-profile navigation: $e');
      Get.offAllNamed('/subscription');
    }
  }

  Future<bool> onWillPop() async {
    if (!hasCompletedProfile.value) {
      await _autoSaveProfileData();
    }
    return true;
  }

  String? _extractUserId(Map<String, dynamic> userData) {
    final possibleIdFields = ['id', 'user_id', 'google_id'];
    for (String field in possibleIdFields) {
      final value = userData[field];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _createProfileUnified({
    required String userId,
    required String username,
    required String fullName,
    required String email,
    required Map<String, dynamic> userData,
    required bool hasImage,
  }) async {
    try {
      print('📤 === UNIFIED PROFILE CREATION ===');

      final isGoogleUser = userData['provider'] == 'google';

      if (isGoogleUser) {
        return await _createGoogleUserProfile(
          userId: userId,
          username: username,
          fullName: fullName,
          email: email,
          hasImage: hasImage,
        );
      } else {
        return await _createRegularUserProfile(
          userId: userId,
          username: username,
          fullName: fullName,
          email: email,
          hasImage: hasImage,
        );
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Profile creation failed: $e',
      };
    }
  }

  // Enhanced validation methods

  // CORRECTED: Enhanced image validation before upload
  bool validateImageFile() {
    if (selectedImage.value == null) {
      imageError.value = 'Profile picture is required';
      return false;
    }

    // Check if file exists
    if (!selectedImage.value!.existsSync()) {
      imageError.value = 'Selected image file not found. Please select again.';
      selectedImage.value = null;
      return false;
    }

    // Check file size (limit to 5MB)
    final fileSizeInBytes = selectedImage.value!.lengthSync();
    final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
    if (fileSizeInMB > 5) {
      imageError.value = 'Image size should be less than 5MB';
      return false;
    }

    imageError.value = '';
    return true;
  }

  bool validateProfileData() {
    bool isValid = true;
    List<String> errorMessages = [];

    // Validate username - Store error but don't add to snackbar messages
    final usernameValidationError = validateUsername(usernameController.text);
    if (usernameValidationError != null) {
      isValid = false;
      usernameError.value = usernameValidationError; // This will show below text field
      // DON'T add to errorMessages - we want it shown below text field only
    } else {
      usernameError.value = ''; // Clear error if valid
    }

    // Validate image file - Add to snackbar messages (since no dedicated UI space)
    if (!validateImageFile()) {
      isValid = false;
      String imageErrorMsg = imageError.value.isNotEmpty
          ? imageError.value
          : "Please select a profile picture to continue";
      errorMessages.add(imageErrorMsg);
    }



    // Only show snackbar for non-username errors
    if (errorMessages.isNotEmpty) {
      _showValidationErrors(errorMessages);
    }

    return isValid;
  }



  // ENHANCED: Show validation errors with better UX
  void _showValidationErrors(List<String> errorMessages) {
    if (errorMessages.length == 1) {
      // Single error - show specific snackbar
      Get.snackbar(
        _getErrorTitle(errorMessages.first),
        errorMessages.first,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 4),
        margin: EdgeInsets.all(10),
      );
    } else {
      // Multiple errors - show consolidated message
      Get.snackbar(
        "Please Fix These Issues",
        "• ${errorMessages.join('\n• ')}",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 6),
        margin: EdgeInsets.all(10),
        maxWidth: double.infinity,
      );
    }
  }

  String _getErrorTitle(String errorMessage) {
    if (errorMessage.toLowerCase().contains('username')) {
      return "Invalid Username";
    } else if (errorMessage.toLowerCase().contains('picture') ||
        errorMessage.toLowerCase().contains('image')) {
      return "Profile Picture Required";
    }
    return "Validation Error";
  }

  // Enhanced validation method with detailed error reporting
  Map<String, String?> validateAllFields() {
    return {
      'username': validateUsername(usernameController.text),
      'profileImage': !validateImageFile()
          ? (imageError.value.isNotEmpty
          ? imageError.value
          : "Please select a profile picture")
          : null,
    };
  }

  // Alternative method that returns detailed validation results
  ValidationResult validateProfileDataDetailed() {
    final errors = validateAllFields();
    final hasErrors = errors.values.any((error) => error != null);

    return ValidationResult(
      isValid: !hasErrors,
      errors: Map.from(errors)..removeWhere((key, value) => value == null),
    );
  }

  Future<Map<String, dynamic>> _createGoogleUserProfile({
    required String userId,
    required String username,
    required String fullName,
    required String email,
    required bool hasImage,
  }) async {
    try {
      print('📤 Creating profile for Google user...');
      print('🖼️ Has image: $hasImage');
      print('📁 Image path: ${selectedImage.value?.path}');

      final token = StorageService.to.getToken() ?? '';

      // Use the same endpoint as regular users for consistency
      final authService = AuthService();
      final baseUrl = authService.baseUrl; // Use same base URL as regular users

      var request = http.MultipartRequest('POST', Uri.parse(baseUrl));

      // Add form fields with explicit Google user indicators
      request.fields.addAll({
        'request': 'create_profile',
        'user_id': userId,
        'username': username,
        'unique_username': username,
        'full_name': fullName,
        'email': email,
        'provider': 'google',
        'is_google_user': 'true',
        'google_user': '1', // Additional flag for API
        'notifications_enabled': notificationsEnabled.value.toString(),
        'profile_type': 'google_with_image', // Explicit type
      });

      // CRITICAL: Enhanced image handling for Google users
      if (hasImage && selectedImage.value != null) {
        try {
          print('🔄 Processing Google user image...');

          // Verify file exists
          if (!selectedImage.value!.existsSync()) {
            throw Exception('Image file not found');
          }

          // Get file info
          String fileName = selectedImage.value!.path.split('/').last;
          String fileExtension = fileName.split('.').last.toLowerCase();
          final fileSize = selectedImage.value!.lengthSync();

          print('📄 Image details:');
          print('   File name: $fileName');
          print('   Extension: $fileExtension');
          print('   Size: ${fileSize} bytes');

          // Validate file extension
          if (!['jpg', 'jpeg', 'png'].contains(fileExtension)) {
            throw Exception('Invalid image format. Use JPG, JPEG, or PNG');
          }

          // Determine content type
          String contentType = fileExtension == 'png' ? 'image/png' : 'image/jpeg';

          // Create unique filename for Google users
          String uniqueFileName = 'google_profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

          // Add image to request with explicit field name
          request.files.add(
            await http.MultipartFile.fromPath(
              'profile_image', // Main field
              selectedImage.value!.path,
              filename: uniqueFileName,
              contentType: MediaType.parse(contentType),
            ),
          );

          // ADDITIONAL: Add backup field for Google users (some APIs expect different field names)
          request.files.add(
            await http.MultipartFile.fromPath(
              'image', // Backup field
              selectedImage.value!.path,
              filename: uniqueFileName,
              contentType: MediaType.parse(contentType),
            ),
          );

          print('✅ Google user image added to request');
          print('🔧 Content type: $contentType');
          print('📎 Unique filename: $uniqueFileName');

        } catch (e) {
          print('❌ Failed to process Google user image: $e');
          throw Exception('Failed to process profile image: $e');
        }
      } else {
        print('⚠️ No image selected for Google user');
      }

      // Add headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'User-Agent': 'LupusCare-GoogleUser/1.0',
      });

      print('📤 Sending Google user profile request...');
      print('🌐 URL: $baseUrl');
      print('📋 Fields: ${request.fields.keys.toList()}');
      print('📎 Files: ${request.files.length}');

      // Send request with extended timeout
      http.StreamedResponse response = await request.send().timeout(
        Duration(seconds: 45), // Extended timeout for image upload
        onTimeout: () => throw Exception('Request timeout - please try again'),
      );

      final responseString = await response.stream.bytesToString();

      print('📥 Google user response status: ${response.statusCode}');
      print('📥 Google user response length: ${responseString.length}');
      print('📥 Google user response: $responseString');
      print('🔍 Response headers: ${response.headers}');

      // Use enhanced response parsing
      return _parseGoogleProfileResponseEnhanced(response.statusCode, responseString, hasImage);

    } catch (e) {
      print('❌ Google profile creation error: $e');
      return {
        'status': 'error',
        'message': 'Google profile creation failed: ${e.toString()}',
      };
    }
  }


  String? _extractImageUrlFromResponse(Map<String, dynamic> response) {
    print('🔍 === EXTRACTING IMAGE URL FROM RESPONSE ===');

    // Check at root level first
    final rootFields = [
      'profile_image', 'profile_picture', 'avatar', 'image',
      'photo', 'profile_photo', 'image_url', 'profile_image_url',
      'profile_pic', 'user_image', 'uploaded_image'
    ];

    for (String field in rootFields) {
      if (response.containsKey(field) && response[field] != null && response[field].toString().isNotEmpty) {
        final imageUrl = response[field].toString();
        if (imageUrl != 'null' && imageUrl != 'undefined') {
          print('🖼️ Found image URL in root field "$field": $imageUrl');
          return _processImageUrl(imageUrl);
        }
      }
    }

    // Check in data object
    if (response['data'] != null && response['data'] is Map) {
      final data = response['data'] as Map<String, dynamic>;
      print('🔍 Checking data object with keys: ${data.keys.toList()}');

      for (String field in rootFields) {
        if (data.containsKey(field) && data[field] != null && data[field].toString().isNotEmpty) {
          final imageUrl = data[field].toString();
          if (imageUrl != 'null' && imageUrl != 'undefined') {
            print('🖼️ Found image URL in data field "$field": $imageUrl');
            return _processImageUrl(imageUrl);
          }
        }
      }
    }

    // Check in user object (sometimes APIs return user data separately)
    if (response['user'] != null && response['user'] is Map) {
      final userData = response['user'] as Map<String, dynamic>;
      print('🔍 Checking user object with keys: ${userData.keys.toList()}');

      for (String field in rootFields) {
        if (userData.containsKey(field) && userData[field] != null && userData[field].toString().isNotEmpty) {
          final imageUrl = userData[field].toString();
          if (imageUrl != 'null' && imageUrl != 'undefined') {
            print('🖼️ Found image URL in user field "$field": $imageUrl');
            return _processImageUrl(imageUrl);
          }
        }
      }
    }

    print('❌ No image URL found in response');
    return null;
  }

  // Helper method to log response fields for debugging
  void _logResponseFields(Map<String, dynamic> response, {String prefix = ''}) {
    response.forEach((key, value) {
      final fullKey = prefix.isEmpty ? key : '$prefix.$key';

      if (value is Map<String, dynamic>) {
        print('🔍   $fullKey: [Map with ${value.length} keys]');
        if (value.length <= 10) { // Only recurse if not too deep
          _logResponseFields(value, prefix: fullKey);
        }
      } else if (value is List) {
        print('🔍   $fullKey: [List with ${value.length} items]');
      } else {
        final valueStr = value.toString();
        final displayValue = valueStr.length > 50 ? '${valueStr.substring(0, 50)}...' : valueStr;
        print('🔍   $fullKey: $displayValue');
      }
    });
  }

  // Enhanced profile image URL extraction with better error handling
  String? _extractProfileImageUrl(Map<String, dynamic> response) {
    try {
      print('🖼️ === EXTRACTING PROFILE IMAGE URL ===');
      print('🔍 Response structure: ${response.keys.toList()}');

      // Use the enhanced extraction method
      String? imageUrl = _extractImageUrlFromResponse(response);

      if (imageUrl != null && imageUrl.isNotEmpty) {
        final processedUrl = _processImageUrl(imageUrl);
        print('✅ Final processed image URL: $processedUrl');
        return processedUrl;
      }

      // Additional debugging for Google users
      print('⚠️ Image URL extraction failed - logging full response structure:');
      _logResponseFields(response);

      return null;
    } catch (e) {
      print('❌ Error extracting profile image URL: $e');
      return null;
    }
  }

  // Enhanced image URL processing with better validation
  String _processImageUrl(String url) {
    if (url.isEmpty) return '';

    // Clean up the URL
    String cleanUrl = url.trim();

    // If already absolute URL, validate and return
    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      print('🌐 Using absolute URL: $cleanUrl');
      return cleanUrl;
    }

    // If relative URL, make it absolute
    const String baseUrl = 'https://alliedtechnologies.cloud/clients/lupus_care/';

    // Remove leading slash if present
    if (cleanUrl.startsWith('/')) {
      cleanUrl = cleanUrl.substring(1);
    }

    final absoluteUrl = '$baseUrl$cleanUrl';
    print('🔗 Converted to absolute URL: $absoluteUrl');
    return absoluteUrl;
  }

  // Enhanced regular user profile creation with consistent image handling
  Future<Map<String, dynamic>> _createRegularUserProfile({
    required String userId,
    required String username,
    required String fullName,
    required String email,
    required bool hasImage,
  }) async {
    try {
      print('📤 Creating profile for regular user...');

      final authService = AuthService();
      final token = StorageService.to.getToken() ?? '';

      var request = http.MultipartRequest('POST', Uri.parse(authService.baseUrl));

      // Add form fields
      request.fields.addAll({
        'request': 'create_profile',
        'user_id': userId,
        'username': username,
        'unique_username': username,
        'full_name': fullName,
        'email': email,
        'notifications_enabled': notificationsEnabled.value.toString(),
      });

      // Enhanced image handling (same as Google version)
      if (hasImage && selectedImage.value != null) {
        try {
          // Verify file exists
          if (!selectedImage.value!.existsSync()) {
            throw Exception('Image file not found');
          }

          // Get file extension
          String fileName = selectedImage.value!.path.split('/').last;
          String fileExtension = fileName.split('.').last.toLowerCase();

          // Determine content type
          String contentType = 'image/jpeg'; // default
          if (fileExtension == 'png') {
            contentType = 'image/png';
          } else if (fileExtension == 'jpg' || fileExtension == 'jpeg') {
            contentType = 'image/jpeg';
          }

          // Add image to request
          request.files.add(
            await http.MultipartFile.fromPath(
              'profile_image', // Make sure this matches what your API expects
              selectedImage.value!.path,
              filename: 'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension',
              contentType: MediaType.parse(contentType),
            ),
          );

          print('✅ Profile image added to request: ${selectedImage.value!.path}');
          print('📄 File size: ${selectedImage.value!.lengthSync()} bytes');
          print('🔧 Content type: $contentType');

        } catch (e) {
          print('❌ Failed to add image to request: $e');
          throw Exception('Failed to process profile image: $e');
        }
      }

      // Add headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Send request with timeout
      http.StreamedResponse response = await request.send().timeout(
        Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timeout'),
      );

      final responseString = await response.stream.bytesToString();

      print('📤 Regular user response status: ${response.statusCode}');
      print('📤 Regular user response: $responseString');

      return _parseServerResponse(response.statusCode, responseString);

    } catch (e) {
      print('❌ Regular profile creation error: $e');
      return {
        'status': 'error',
        'message': 'Network error: $e',
      };
    }
  }


  Map<String, dynamic> _parseServerResponse(int statusCode, String responseString) {
    if (responseString.trim().isEmpty) {
      return {
        'status': statusCode == 200 ? 'success' : 'error',
        'message': 'Server returned empty response'
      };
    }

    try {
      final jsonResponse = json.decode(responseString);

      // Ensure status field exists
      if (!jsonResponse.containsKey('status')) {
        jsonResponse['status'] = statusCode == 200 ? 'success' : 'error';
      }

      // Debug: Print entire response
      print('🔍 Parsed response: $jsonResponse');

      // Check for image URL in common fields
      final possibleImageFields = [
        'profile_image', 'profile_picture', 'avatar',
        'image', 'image_url', 'profile_image_url'
      ];

      for (var field in possibleImageFields) {
        if (jsonResponse.containsKey(field) && jsonResponse[field] != null) {
          print('🖼️ Found image URL in field "$field": ${jsonResponse[field]}');
          jsonResponse['image_url'] = jsonResponse[field];
          break;
        }
      }

      return jsonResponse;
    } catch (e) {
      print('❌ JSON parse error: $e');
      return {
        'status': 'error',
        'message': 'Failed to parse server response: ${e.toString()}',
      };
    }
  }

  void clearPreviousSessionData() {
    selectedImage.value = null;
    fullNameController.clear();
    usernameController.clear();
    editUsernameController.clear();
    emailController.clear();
    username.value = '';
    usernameError.value = '';
    imageError.value = '';
    isPushNotificationEnabled.value = true;
    notificationsEnabled.value = true;
    isLoading.value = false;

    print('Previous session data cleared');
  }

  void resetControllerState() {
    clearPreviousSessionData();
    _populateUserData();
  }



  void debugUserData() {
    print('🔍 === USER DATA DEBUG ===');
    try {
      final userData = StorageService.to.getUser();
      final token = StorageService.to.getToken();
      final isLoggedIn = StorageService.to.isLoggedIn();
      final hasCompletedProfile = StorageService.to.hasCompletedProfile();

      print('📊 Current Storage State:');
      print('   User exists: ${userData != null ? '✅' : '❌'}');
      print('   Token exists: ${token != null ? '✅' : '❌'}');
      print('   Is logged in: ${isLoggedIn ? '✅' : '❌'}');
      print('   Has completed profile: ${hasCompletedProfile ? '✅' : '❌'}');
      print('   Has draft data: ${hasDraftData.value ? '✅' : '❌'}');
      print('   Has profile image: ${selectedImage.value != null ? '✅' : '❌'}');

      if (userData != null) {
        print('👤 User Data:');
        print('   ID: ${userData['id']}');
        print('   User ID: ${userData['user_id']}');
        print('   Email: ${userData['email']}');
        print('   Name: ${userData['name']}');
        print('   Username: ${userData['username']}');
        print('   Unique Username: ${userData['unique_username']}');
        print('   Profile Image: ${userData['profile_image']}');
        print('   Provider: ${userData['provider']}');
        print('   Google ID: ${userData['google_id']}');
        print('   Is Google User: ${userData['is_google_user']}');

        final draftKeys = userData.keys.where((key) => key.startsWith('draft_')).toList();
        if (draftKeys.isNotEmpty) {
          print('📝 Draft Data Keys: $draftKeys');
        } else {
          print('📝 No draft data keys found');
        }
      }

      if (token != null) {
        print('🔑 Token: ${token.substring(0, 30)}...');
      }

      StorageService.to.printStorageInfo();

    } catch (e) {
      print('❌ Debug error: $e');
    }
    print('🔍 === DEBUG COMPLETE ===');
  }

  Future<void> skipProfileSetup() async {
    try {
      print('⏭️ === ATTEMPTING TO SKIP PROFILE SETUP ===');

      Get.dialog(
        AlertDialog(
          title: Text('Profile Picture Required 📸'),
          content: Text(
              'A profile picture is required to use Lupus Care.\n\n'
                  'This helps us provide a personalized experience and allows other users to recognize you in the community.'
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('OK', style: TextStyle(color: CustomColors.purpleColor)),
            ),
          ],
        ),
      );

    } catch (e) {
      print('❌ Error in skip profile setup: $e');
    }
  }

  bool get hasChanges {
    return selectedImage.value != null ||
        usernameText.value.trim() != _originalUsername;
  }

  bool get hasTextFieldChanges {
    return usernameText.value.trim() != _originalUsername;
  }




  void togglePushNotification() {
    isPushNotificationEnabled.value = !isPushNotificationEnabled.value;
    if (!hasCompletedProfile.value) {
      _scheduleAutoSave();
    }
  }
}

// ValidationResult helper class
class ValidationResult {
  final bool isValid;
  final Map<String, String> errors;

  ValidationResult({
    required this.isValid,
    required this.errors,
  });

  String get firstError => errors.values.first;
  bool hasError(String field) => errors.containsKey(field);
  String? getError(String field) => errors[field];
}