import 'dart:io';

import 'package:get/get.dart';
import 'package:lupus_care/data/api/profile_service.dart';
import 'package:lupus_care/helper/storage_service.dart';

class ProfileController extends GetxController {
  final ProfileService _profileService = ProfileService();

  // Observable variables
  RxString username = ''.obs;
  RxString email = ''.obs;
  RxString fullName = ''.obs;
  RxString profileImageUrl = ''.obs;
  RxString localImagePath = ''.obs;
  RxString displayImagePath = ''.obs; // The actual image to display
  RxBool notificationsEnabled = true.obs;
  RxBool isLoading = false.obs;
  RxBool isImageLoading = false.obs;
  RxBool hasApiImage = false.obs;
  RxBool hasLocalImage = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Initial load when controller is first created
    loadUserProfile();
    forceRefreshAfterEdit();
  }

  @override
  void onReady() {
    super.onReady();
    // This will be called every time the controller becomes active
    // Refresh profile data when screen opens
    print("ProfileController onReady - refreshing profile data");
    loadUserProfile();
  }

  // Enhanced method to force refresh after profile edit
  Future<void> forceRefreshAfterEdit() async {
    print("Force refreshing profile after edit...");
    isLoading.value = true;

    // Clear cached data first
    username.value = '';
    email.value = '';
    fullName.value = '';
    profileImageUrl.value = '';
    localImagePath.value = '';
    displayImagePath.value = '';
    hasApiImage.value = false;
    hasLocalImage.value = false;

    // Force reload from server
    await loadUserProfile();

    print("Profile force refresh completed");
  }

  // Enhanced profile loading with image priority logic
  Future<void> loadUserProfile() async {
    try {
      isLoading.value = true;

      // Get user ID from storage
      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString() ?? '';

      if (userId.isEmpty) {
        print("User ID not found in storage");
        // Load from cached data if available
        await _loadFromCache();
        return;
      }

      print("Fetching profile for user ID: $userId");

      // Call get_profile API using ProfileService
      final response = await _profileService.getUserProfile(userId: userId);

      print("Profile API response: $response");

      if (response['status'] == 'success' && response['data'] != null) {
        final profileData = response['data'];

        // Update basic profile information
         _updateBasicProfileData(profileData);

        // Handle profile image with priority logic
        await _handleProfileImagePriority(profileData, userId);

        // Update local storage with fresh data
        await _updateLocalStorage(profileData);

      } else {
        print("Failed to load profile: ${response['message']}");
        // Load from cached data as fallback
        await _loadFromCache();
      }
    } catch (e) {
      print("Error loading user profile: $e");
      // Load from cached data on error
      await _loadFromCache();
    } finally {
      isLoading.value = false;
    }
  }

  // Extract basic profile data update logic
  void _updateBasicProfileData(Map<String, dynamic> profileData) {
    if (profileData['unique_username'] != null) {
      username.value = profileData['unique_username'].toString();
    }

    if (profileData['email'] != null) {
      email.value = profileData['email'].toString();
    }

    if (profileData['full_name'] != null) {
      fullName.value = profileData['full_name'].toString();
    }

    // Update notifications setting if available
    if (profileData['push_notifications'] != null) {
      notificationsEnabled.value = profileData['push_notifications'].toString() == '1' ||
          profileData['push_notifications'].toString().toLowerCase() == 'true';
    }

    print("Basic profile data loaded:");
    print("Username: ${username.value}");
    print("Email: ${email.value}");
    print("Full Name: ${fullName.value}");
  }

  // Enhanced image handling with priority logic
  Future<void> _handleProfileImagePriority(Map<String, dynamic> profileData, String userId) async {
    try {
      isImageLoading.value = true;

      // Step 1: Check API image
      final apiImageUrl = profileData['profile_image']?.toString() ?? '';
      final hasValidApiImage = apiImageUrl.isNotEmpty &&
          apiImageUrl != 'null' &&
          apiImageUrl != 'undefined';

      print("🖼️ === PROFILE IMAGE PRIORITY LOGIC ===");
      print("API Image URL: $apiImageUrl");
      print("Has Valid API Image: $hasValidApiImage");

      // Step 2: Check local image
      final localPath = StorageService.to.getLocalProfileImagePath();
      final hasValidLocalImage = localPath != null && localPath.isNotEmpty;

      print("Local Image Path: $localPath");
      print("Has Valid Local Image: $hasValidLocalImage");

      // Step 3: Apply priority logic
      if (hasValidApiImage) {
        // Priority 1: API image exists - use it
        await _useApiImage(apiImageUrl, userId);
      } else if (hasValidLocalImage) {
        // Priority 2: No API image but local image exists - use local
        await _useLocalImage(localPath!);
      } else {
        // Priority 3: No image available
        await _useDefaultImage();
      }

      // Update status flags
      hasApiImage.value = hasValidApiImage;
      hasLocalImage.value = hasValidLocalImage;

      print("🖼️ Final Image Decision:");
      print("Display Image Path: ${displayImagePath.value}");
      print("Has API Image: ${hasApiImage.value}");
      print("Has Local Image: ${hasLocalImage.value}");
      print("🖼️ === END IMAGE PRIORITY LOGIC ===");

    } catch (e) {
      print("❌ Error handling profile image priority: $e");
      await _useDefaultImage();
    } finally {
      isImageLoading.value = false;
    }
  }

  // Use API image (and optionally download for offline use)
  Future<void> _useApiImage(String apiImageUrl, String userId) async {
    try {
      print("✅ Using API image: $apiImageUrl");

      // Set API image as primary
      profileImageUrl.value = apiImageUrl;
      displayImagePath.value = apiImageUrl;

      // Optional: Download API image for offline use if not already cached
      final localPath = StorageService.to.getLocalProfileImagePath();
      if (localPath == null) {
        print("📥 Downloading API image for offline caching...");

        // Download in background without blocking UI
        _downloadImageInBackground(apiImageUrl, userId);
      } else {
        // Verify if local image matches API image (optional integrity check)
        localImagePath.value = localPath;
      }

    } catch (e) {
      print("❌ Error using API image: $e");
      // Fallback to local image if API image fails
      final localPath = StorageService.to.getLocalProfileImagePath();
      if (localPath != null) {
        await _useLocalImage(localPath);
      } else {
        await _useDefaultImage();
      }
    }
  }

  // Use local image
  Future<void> _useLocalImage(String localPath) async {
    try {
      print("✅ Using local image: $localPath");

      localImagePath.value = localPath;
      displayImagePath.value = localPath;
      profileImageUrl.value = ''; // Clear API URL since we're using local

      // Verify image integrity
      final isValid = await StorageService.to.verifyLocalImageIntegrity();
      if (!isValid) {
        print("⚠️ Local image integrity check failed");
        await _useDefaultImage();
      }

    } catch (e) {
      print("❌ Error using local image: $e");
      await _useDefaultImage();
    }
  }

  // Use default/placeholder image
  Future<void> _useDefaultImage() async {
    print("📷 Using default image - no valid image source available");

    profileImageUrl.value = '';
    localImagePath.value = '';
    displayImagePath.value = ''; // Empty means use default in UI
  }

  // Background download of API image for offline caching
  void _downloadImageInBackground(String imageUrl, String userId) async {
    try {
      print("🔄 Background download started for: $imageUrl");

      final downloadedPath = await StorageService.to.downloadAndSaveProfileImage(imageUrl, userId);

      if (downloadedPath != null) {
        localImagePath.value = downloadedPath;
        hasLocalImage.value = true;
        print("✅ Background download completed: $downloadedPath");
      } else {
        print("❌ Background download failed");
      }
    } catch (e) {
      print("❌ Background download error: $e");
    }
  }

  // Enhanced cache loading with image priority
  Future<void> _loadFromCache() async {
    try {
      print("📱 Loading profile from cache...");

      // Load basic data from storage
      final userData = StorageService.to.getUser();
      final profileData = StorageService.to.getLocalProfileData();

      if (userData != null) {
        if (userData['unique_username'] != null) {
          username.value = userData['unique_username'].toString();
        }
        if (userData['email'] != null) {
          email.value = userData['email'].toString();
        }
        if (userData['full_name'] != null) {
          fullName.value = userData['full_name'].toString();
        }
      }

      // Apply image priority logic for cached data
      final userId = userData?['id']?.toString() ?? '';
      if (userId.isNotEmpty) {
        // Check if we have cached API image URL
        String cachedApiImage = '';
        if (profileData != null && profileData['profile_image_url'] != null) {
          cachedApiImage = profileData['profile_image_url'].toString();
        } else if (userData != null && userData['profile_image'] != null) {
          cachedApiImage = userData['profile_image'].toString();
        }

        // Apply the same priority logic for cached data
        final mockProfileData = {'profile_image': cachedApiImage};
        await _handleProfileImagePriority(mockProfileData, userId);
      }

      print("📱 Cache loading completed");
    } catch (e) {
      print("❌ Error loading from cache: $e");
    }
  }

  // Update local storage with comprehensive data
  Future<void> _updateLocalStorage(Map<String, dynamic> profileData) async {
    try {
      final currentUserData = StorageService.to.getUser() ?? {};

      // Update user data
      currentUserData.addAll({
        'unique_username': username.value,
        'email': email.value,
        'full_name': fullName.value,
        'profile_image': profileImageUrl.value,
      });

      await StorageService.to.saveUser(currentUserData);

      // Update comprehensive profile data in StorageService
      await StorageService.to.saveLocalProfileData(
        username: username.value,
        fullName: fullName.value,
        email: email.value,
        profileImageUrl: profileImageUrl.value,
        localImagePath: localImagePath.value,
        additionalData: {
          'api_image_available': hasApiImage.value,
          'local_image_available': hasLocalImage.value,
          'last_image_sync': DateTime.now().toIso8601String(),
          'image_source': hasApiImage.value ? 'api' : (hasLocalImage.value ? 'local' : 'none'),
        },
      );

      print("✅ Local storage updated successfully");
    } catch (e) {
      print("❌ Error updating local storage: $e");
    }
  }

  // Enhanced refresh methods
  Future<void> refreshProfile() async {
    print("Manual refresh profile called");
    await loadUserProfile();
  }

  Future<void> forceRefresh() async {
    print("Force refresh profile from server");
    isLoading.value = true;
    await loadUserProfile();
  }

  // Method to handle image update after user changes profile picture
  Future<void> updateProfileImage(String newImagePath, {bool isLocal = true}) async {
    try {
      print("🔄 Updating profile image: $newImagePath (Local: $isLocal)");

      if (isLocal) {
        // User uploaded a new local image
        final userData = StorageService.to.getUser();
        final userId = userData?['id']?.toString() ?? '';

        if (userId.isNotEmpty) {
          // Save the new image locally
          final savedPath = await StorageService.to.saveProfileImageLocally(
              File(newImagePath),
              userId
          );

          if (savedPath != null) {
            localImagePath.value = savedPath;
            displayImagePath.value = savedPath;
            hasLocalImage.value = true;

            // Clear API image since user uploaded new local image
            profileImageUrl.value = '';
            hasApiImage.value = false;

            print("✅ New local image saved and set as display image");
          }
        }
      } else {
        // New API image URL
        profileImageUrl.value = newImagePath;
        displayImagePath.value = newImagePath;
        hasApiImage.value = true;

        print("✅ New API image set as display image");
      }

      // Update storage
      final currentUserData = StorageService.to.getUser() ?? {};
      currentUserData['profile_image'] = profileImageUrl.value;
      await StorageService.to.saveUser(currentUserData);

    } catch (e) {
      print("❌ Error updating profile image: $e");
    }
  }

  // Utility method to check if we have any image available
  bool get hasAnyImage => hasApiImage.value || hasLocalImage.value;

  // Get the best available image source
  String get bestImageSource {
    if (hasApiImage.value) return 'API';
    if (hasLocalImage.value) return 'Local';
    return 'None';
  }

  // Method to force re-download API image
  Future<void> refreshApiImage() async {
    try {
      if (profileImageUrl.value.isNotEmpty) {
        isImageLoading.value = true;

        final userData = StorageService.to.getUser();
        final userId = userData?['id']?.toString() ?? '';

        if (userId.isNotEmpty) {
          // Clear existing local image
          await StorageService.to.clearAllProfileData();

          // Re-download API image
          final downloadedPath = await StorageService.to.downloadAndSaveProfileImage(
              profileImageUrl.value,
              userId
          );

          if (downloadedPath != null) {
            localImagePath.value = downloadedPath;
            hasLocalImage.value = true;
            print("✅ API image re-downloaded successfully");
          }
        }
      }
    } catch (e) {
      print("❌ Error refreshing API image: $e");
    } finally {
      isImageLoading.value = false;
    }
  }

  // Notification toggle
  void toggleNotifications(bool value) {
    notificationsEnabled.value = value;
    // Here you can add API call to update notification preferences
    // _updateNotificationPreferences(value);
  }

  // Get display name (prioritize full name, fall back to username)
  String get displayName {
    if (fullName.value.isNotEmpty) {
      return fullName.value;
    } else if (username.value.isNotEmpty) {
      return username.value;
    }
    return 'User';
  }

  // Get username with email display
  String get usernameDisplay {
    if (email.value.isNotEmpty) {
      return email.value;
    }
    return '@username';
  }

  // Debug method to print image status
  void debugImageStatus() {
    print("🔍 === PROFILE IMAGE DEBUG STATUS ===");
    print("API Image URL: ${profileImageUrl.value}");
    print("Local Image Path: ${localImagePath.value}");
    print("Display Image Path: ${displayImagePath.value}");
    print("Has API Image: ${hasApiImage.value}");
    print("Has Local Image: ${hasLocalImage.value}");
    print("Best Image Source: $bestImageSource");
    print("Has Any Image: $hasAnyImage");
    print("Is Image Loading: ${isImageLoading.value}");
    print("🔍 === END IMAGE DEBUG STATUS ===");
  }
}