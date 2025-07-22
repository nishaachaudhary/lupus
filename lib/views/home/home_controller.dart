import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lupus_care/data/api/profile_service.dart';
import 'package:lupus_care/data/api/auth_service.dart';
import 'package:lupus_care/helper/storage_service.dart';
import 'dart:io';

class HomeController extends GetxController {
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();

  // ✅ Enhanced observables with image priority support
  RxString username = 'User'.obs;
  RxString profileImageUrl = ''.obs;
  RxString localImagePath = ''.obs;
  RxString displayImagePath = ''.obs; // The actual image to display on home screen
  RxBool hasApiImage = false.obs;
  RxBool hasLocalImage = false.obs;
  RxBool isLoading = false.obs;
  RxBool isImageLoading = false.obs;
  RxBool isLoadingReminders = false.obs;
  RxList<Map<String, dynamic>> upcomingReminders = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadUserProfile();
    loadUpcomingReminders();
  }

  @override
  void onReady() {
    super.onReady();
    print("HomeController onReady - refreshing profile data and reminders");
    loadUserProfile();
    loadUpcomingReminders();
  }

  Future<void> logout() async {
    try {
      print("👋 Starting logout process...");

      // Clear user data but preserve app usage history
      final success = await StorageService.to.logout();

      if (success) {
        Get.snackbar(
          'Signed Out',
          'You have been signed out successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        // Navigate to login screen
        Get.offAllNamed('/login');
      } else {
        throw Exception('Failed to sign out');
      }
    } catch (e) {
      print("❌ Logout error: $e");
      Get.snackbar(
        'Logout Failed',
        'Failed to sign out: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // ✅ Enhanced profile loading with image priority logic
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

      print("🏠 Fetching profile for Home screen - user ID: $userId");

      // Call get_profile API
      final response = await _profileService.getUserProfile(userId: userId);

      print("Home Profile API response: $response");

      if (response['status'] == 'success' && response['data'] != null) {
        final profileData = response['data'];

        // Update basic profile information
        _updateBasicProfileData(profileData);

        // ✅ Handle profile image with priority logic
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

  // ✅ Extract basic profile data update logic
  void _updateBasicProfileData(Map<String, dynamic> profileData) {
    // Update username (prioritize full_name, fallback to unique_username)
    if (profileData['full_name'] != null && profileData['full_name'].toString().isNotEmpty) {
      username.value = profileData['full_name'].toString();
    } else if (profileData['unique_username'] != null && profileData['unique_username'].toString().isNotEmpty) {
      username.value = profileData['unique_username'].toString();
    }

    print("🏠 Home basic profile data loaded: Username: ${username.value}");
  }

  // ✅ Enhanced image handling with priority logic for Home screen
  Future<void> _handleProfileImagePriority(Map<String, dynamic> profileData, String userId) async {
    try {
      isImageLoading.value = true;

      // Step 1: Check API image
      final apiImageUrl = profileData['profile_image']?.toString() ?? '';
      final hasValidApiImage = apiImageUrl.isNotEmpty &&
          apiImageUrl != 'null' &&
          apiImageUrl != 'undefined';

      print("🏠🖼️ === HOME IMAGE PRIORITY LOGIC ===");
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

      print("🏠🖼️ Final Home Image Decision:");
      print("Display Image Path: ${displayImagePath.value}");
      print("Has API Image: ${hasApiImage.value}");
      print("Has Local Image: ${hasLocalImage.value}");
      print("🏠🖼️ === END HOME IMAGE PRIORITY LOGIC ===");

    } catch (e) {
      print("❌ Error handling home profile image priority: $e");
      await _useDefaultImage();
    } finally {
      isImageLoading.value = false;
    }
  }

  // ✅ Use API image for Home screen
  Future<void> _useApiImage(String apiImageUrl, String userId) async {
    try {
      print("🏠✅ Using API image for Home: $apiImageUrl");

      // Set API image as primary
      profileImageUrl.value = apiImageUrl;
      displayImagePath.value = apiImageUrl;

      // Optional: Download API image for offline use if not already cached
      final localPath = StorageService.to.getLocalProfileImagePath();
      if (localPath == null) {
        print("🏠📥 Downloading API image for offline caching...");

        // Download in background without blocking UI
        _downloadImageInBackground(apiImageUrl, userId);
      } else {
        // We have a local image cached
        localImagePath.value = localPath;
      }

    } catch (e) {
      print("❌ Error using API image in Home: $e");
      // Fallback to local image if API image fails
      final localPath = StorageService.to.getLocalProfileImagePath();
      if (localPath != null) {
        await _useLocalImage(localPath);
      } else {
        await _useDefaultImage();
      }
    }
  }

  // ✅ Use local image for Home screen
  Future<void> _useLocalImage(String localPath) async {
    try {
      print("🏠✅ Using local image for Home: $localPath");

      localImagePath.value = localPath;
      displayImagePath.value = localPath;
      profileImageUrl.value = ''; // Clear API URL since we're using local

      // Verify image integrity
      final isValid = await StorageService.to.verifyLocalImageIntegrity();
      if (!isValid) {
        print("⚠️ Local image integrity check failed in Home");
        await _useDefaultImage();
      }

    } catch (e) {
      print("❌ Error using local image in Home: $e");
      await _useDefaultImage();
    }
  }

  // ✅ Use default/placeholder image for Home screen
  Future<void> _useDefaultImage() async {
    print("🏠📷 Using default image for Home - no valid image source available");

    profileImageUrl.value = '';
    localImagePath.value = '';
    displayImagePath.value = ''; // Empty means use default in UI
  }

  // ✅ Background download of API image for offline caching
  void _downloadImageInBackground(String imageUrl, String userId) async {
    try {
      print("🏠🔄 Background download started for Home: $imageUrl");

      final downloadedPath = await StorageService.to.downloadAndSaveProfileImage(imageUrl, userId);

      if (downloadedPath != null) {
        localImagePath.value = downloadedPath;
        hasLocalImage.value = true;
        print("🏠✅ Background download completed for Home: $downloadedPath");
      } else {
        print("🏠❌ Background download failed for Home");
      }
    } catch (e) {
      print("❌ Background download error in Home: $e");
    }
  }

  // ✅ Enhanced cache loading with image priority for Home
  Future<void> _loadFromCache() async {
    try {
      print("🏠📱 Loading Home profile from cache...");

      // Load basic data from storage
      final userData = StorageService.to.getUser();
      final profileData = StorageService.to.getLocalProfileData();

      if (userData != null) {
        // Update username (prioritize full_name, fallback to unique_username)
        if (userData['full_name'] != null && userData['full_name'].toString().isNotEmpty) {
          username.value = userData['full_name'].toString();
        } else if (userData['unique_username'] != null && userData['unique_username'].toString().isNotEmpty) {
          username.value = userData['unique_username'].toString();
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

      print("🏠📱 Home cache loading completed");
    } catch (e) {
      print("❌ Error loading Home cache: $e");
    }
  }

  // ✅ Update local storage with comprehensive data
  Future<void> _updateLocalStorage(Map<String, dynamic> profileData) async {
    try {
      final currentUserData = StorageService.to.getUser() ?? {};

      // Update user data
      if (profileData['full_name'] != null) {
        currentUserData['full_name'] = profileData['full_name'];
      }
      if (profileData['unique_username'] != null) {
        currentUserData['unique_username'] = profileData['unique_username'];
      }
      if (profileData['profile_image'] != null) {
        currentUserData['profile_image'] = profileData['profile_image'];
      }

      await StorageService.to.saveUser(currentUserData);

      // Update comprehensive profile data in StorageService
      await StorageService.to.saveLocalProfileData(
        username: currentUserData['unique_username']?.toString() ?? '',
        fullName: currentUserData['full_name']?.toString() ?? '',
        email: currentUserData['email']?.toString() ?? '',
        profileImageUrl: profileImageUrl.value,
        localImagePath: localImagePath.value,
        additionalData: {
          'api_image_available': hasApiImage.value,
          'local_image_available': hasLocalImage.value,
          'last_image_sync': DateTime.now().toIso8601String(),
          'image_source': hasApiImage.value ? 'api' : (hasLocalImage.value ? 'local' : 'none'),
          'updated_from': 'home_controller',
        },
      );

      print("🏠✅ Home local storage updated successfully");
    } catch (e) {
      print("❌ Error updating Home local storage: $e");
    }
  }

  // ✅ Utility methods for Home controller
  bool get hasAnyImage => hasApiImage.value || hasLocalImage.value;

  String get bestImageSource {
    if (hasApiImage.value) return 'API';
    if (hasLocalImage.value) return 'Local';
    return 'None';
  }

  // FIXED loadUpcomingReminders method for HomeController
  Future<void> loadUpcomingReminders() async {
    try {
      isLoadingReminders.value = true;

      // Get user ID from storage
      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString() ?? '';

      if (userId.isEmpty) {
        print("User ID not found in storage for reminders");
        return;
      }

      print("Fetching upcoming reminders for user ID: $userId");

      // Call get_upcoming_reminders API
      final response = await _authService.getUpcomingReminders(userId: userId);

      print("Upcoming reminders API response: $response");

      if (response['status'] == 'success') {

        // FIXED: Handle the actual API response structure
        upcomingReminders.clear(); // Clear existing reminders first

        // Check for single 'reminder' field first (your actual API response)
        if (response['reminder'] != null) {
          print("Found single reminder in response");
          final reminderData = response['reminder'] as Map<String, dynamic>;

          // Format the reminder_time from 24-hour to 12-hour format
          if (reminderData['reminder_time'] != null) {
            reminderData['formatted_time'] = _formatTime(reminderData['reminder_time'].toString());
          }

          // Add the single reminder to the list
          upcomingReminders.add(reminderData);

          print("Added single reminder: ${reminderData['medication_name']} at ${reminderData['formatted_time'] ?? reminderData['reminder_time']}");
        }

        // Check for 'reminders' field (plural - if API returns multiple)
        else if (response['reminders'] != null) {
          print("Found multiple reminders in response");
          final remindersData = response['reminders'] as List<dynamic>?;

          if (remindersData != null && remindersData.isNotEmpty) {
            upcomingReminders.value = remindersData
                .map((item) {
              final reminder = Map<String, dynamic>.from(item as Map);

              // Format the reminder_time from 24-hour to 12-hour format
              if (reminder['reminder_time'] != null) {
                reminder['formatted_time'] = _formatTime(reminder['reminder_time'].toString());
              }

              return reminder;
            })
                .toList();

            print("Added ${upcomingReminders.length} reminders from 'reminders' field");
          }
        }

        // Check for 'data' field (fallback)
        else if (response['data'] != null) {
          print("Found reminders in 'data' field");
          final dataField = response['data'];

          // Handle if 'data' is a single object
          if (dataField is Map<String, dynamic>) {
            // Format the reminder_time
            if (dataField['reminder_time'] != null) {
              dataField['formatted_time'] = _formatTime(dataField['reminder_time'].toString());
            }

            upcomingReminders.add(dataField);
            print("Added single reminder from 'data' field: ${dataField['medication_name']}");
          }
          // Handle if 'data' is a list
          else if (dataField is List<dynamic> && dataField.isNotEmpty) {
            upcomingReminders.value = dataField
                .map((item) {
              final reminder = Map<String, dynamic>.from(item as Map);

              // Format the reminder_time
              if (reminder['reminder_time'] != null) {
                reminder['formatted_time'] = _formatTime(reminder['reminder_time'].toString());
              }

              return reminder;
            })
                .toList();

            print("Added ${upcomingReminders.length} reminders from 'data' list");
          }
        }

        // No reminders found
        else {
          print("No reminders found in any expected field");
          upcomingReminders.clear();
        }

        print("Final reminder count: ${upcomingReminders.length}");

        // Debug: Print all reminders
        upcomingReminders.forEach((reminder) {
          print("Loaded reminder: ${reminder['medication_name']} at ${reminder['formatted_time'] ?? reminder['reminder_time']}");
        });

      } else {
        print("Failed to load reminders: ${response['message']}");
        upcomingReminders.clear();
      }
    } catch (e) {
      print("Error loading upcoming reminders: $e");
      upcomingReminders.clear();
    } finally {
      isLoadingReminders.value = false;
    }
  }

  // ENHANCED debug method to help troubleshoot
  void debugReminderState() {
    print("🔍 === REMINDER STATE DEBUG ===");
    print("   isLoadingReminders: ${isLoadingReminders.value}");
    print("   upcomingReminders.length: ${upcomingReminders.length}");
    print("   hasUpcomingReminders: $hasUpcomingReminders");
    print("   nextReminder: ${nextReminder?.toString() ?? 'null'}");

    if (upcomingReminders.isNotEmpty) {
      print("   === REMINDERS DETAILS ===");
      for (int i = 0; i < upcomingReminders.length; i++) {
        final reminder = upcomingReminders[i];
        print("   [$i] Medication: ${reminder['medication_name']}");
        print("       Time: ${reminder['formatted_time'] ?? reminder['reminder_time']}");
        print("       Date: ${reminder['reminder_date']}");
        print("       DateTime: ${reminder['reminder_datetime']}");
      }
    }
    print("=================================");
  }

  // ✅ Debug method for Home image status
  void debugHomeImageStatus() {
    print("🏠🔍 === HOME IMAGE DEBUG STATUS ===");
    print("API Image URL: ${profileImageUrl.value}");
    print("Local Image Path: ${localImagePath.value}");
    print("Display Image Path: ${displayImagePath.value}");
    print("Has API Image: ${hasApiImage.value}");
    print("Has Local Image: ${hasLocalImage.value}");
    print("Best Image Source: $bestImageSource");
    print("Has Any Image: $hasAnyImage");
    print("Is Image Loading: ${isImageLoading.value}");
    print("🏠🔍 === END HOME IMAGE DEBUG STATUS ===");
  }

  // ENHANCED API response debug method - Add this to HomeController
  Future<void> testReminderAPI() async {
    try {
      print("🧪 === TESTING REMINDER API ===");

      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString() ?? '';

      if (userId.isEmpty) {
        print("❌ No user ID for testing");
        return;
      }

      print("📞 Calling reminder API for user: $userId");

      final response = await _authService.getUpcomingReminders(userId: userId);

      print("📥 Raw API Response:");
      print("   Status: ${response['status']}");
      print("   Message: ${response['message'] ?? 'No message'}");

      // Check all possible response fields
      print("📊 Response Structure Analysis:");
      response.forEach((key, value) {
        print("   '$key': ${value.runtimeType} = $value");
      });

      // Test the reminder processing logic
      if (response['status'] == 'success') {
        if (response['reminder'] != null) {
          print("✅ Found 'reminder' field (singular)");
          final reminder = response['reminder'];
          print("   Medication: ${reminder['medication_name']}");
          print("   Time: ${reminder['reminder_time']}");
          print("   Date: ${reminder['reminder_date']}");
        }

        if (response['reminders'] != null) {
          print("✅ Found 'reminders' field (plural)");
        }

        if (response['data'] != null) {
          print("✅ Found 'data' field");
        }
      }

      print("🧪 === END API TEST ===");

    } catch (e) {
      print("❌ Error testing reminder API: $e");
    }
  }


  String _formatTime(String time24) {
    try {
      // Parse the time (expecting format like "16:00:00" or "16:00")
      final parts = time24.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);

        String period = hour >= 12 ? 'PM' : 'AM';
        if (hour > 12) {
          hour -= 12;
        } else if (hour == 0) {
          hour = 12;
        }

        return '${hour.toString()}:${minute.toString().padLeft(2, '0')} $period';
      }
    } catch (e) {
      print("Error formatting time: $e");
    }

    // Return original time if formatting fails
    return time24;
  }

  // Method to refresh profile data manually
  Future<void> refreshProfile() async {
    print("🏠 Manual refresh profile called in HomeController");
    await loadUserProfile();
  }

  // Method to refresh reminders manually
  Future<void> refreshReminders() async {
    print("🏠 Manual refresh reminders called in HomeController");
    await loadUpcomingReminders();
  }

  // Force refresh from server (bypass cache)
  Future<void> forceRefresh() async {
    print("🏠 Force refresh profile and reminders from server in HomeController");
    isLoading.value = true;
    await Future.wait([
      loadUserProfile(),
      loadUpcomingReminders(),
    ]);
  }

  // Get display name for greeting
  String get displayName {
    if (username.value.isNotEmpty && username.value != 'User') {
      return username.value;
    }
    return 'User';
  }

  // Get the next upcoming reminder
  Map<String, dynamic>? get nextReminder {
    if (upcomingReminders.isNotEmpty) {
      return upcomingReminders.first;
    }
    return null;
  }

  // Check if there are any upcoming reminders
  bool get hasUpcomingReminders => upcomingReminders.isNotEmpty;
}