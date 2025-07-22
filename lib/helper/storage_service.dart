import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

class StorageService extends GetxService {
  static StorageService get to => Get.find<StorageService>();
  SharedPreferences? _prefs;
  bool _isInitialized = false;
  bool _usingMemoryStorage = false;
  static const String lastRouteKey = 'last_route';

  // In-memory fallback storage
  final Map<String, dynamic> _memoryStorage = {};

  // Keys for storage - UNIFIED NAMING
  static const String userKey = 'user_data';
  static const String tokenKey = 'auth_token';
  static const String isLoggedInKey = 'is_logged_in';

  // CRITICAL: User-specific subscription storage
  static const String userSubscriptionsKey = 'user_subscriptions_v2';
  static const String subscriptionStatusKey = 'subscription_status';
  static const String subscriptionPlanKey = 'subscription_plan';
  static const String subscriptionExpiryKey = 'subscription_expiry';

  // ONBOARDING - The key flag for showing onboarding
  static const String hasCompletedOnboardingKey = 'has_completed_onboarding';

  // NEW: PROFILE COMPLETION - Track if user has completed profile setup
  static const String hasCompletedProfileKey = 'has_completed_profile';

  // APP USAGE TRACKING - For analytics/debugging
  static const String hasUsedAppBeforeKey = 'has_used_app_before';
  static const String hasSeenLoginKey = 'has_seen_login';
  static const String firstInstallCompleteKey = 'first_install_complete';

  // ✅ FIXED: Enhanced profile storage keys
  static const String profileImagePathKey = 'local_profile_image_path';
  static const String profileImageHashKey = 'profile_image_hash';
  static const String profileDataKey = 'local_profile_data';
  static const String profileLastSyncKey = 'profile_last_sync';
  static const String profileOfflineModeKey = 'profile_offline_mode';

  // Profile image storage directory
  static const String profileImagesDir = 'profile_images';

  // Enhanced profile data structure
  Map<String, dynamic> _cachedProfileData = {};
  bool _profileCacheLoaded = false;

  // Getter to check if service is initialized
  bool get isInitialized => _isInitialized;
  String get storageType => _usingMemoryStorage ? 'Memory (Temporary)' : 'SharedPreferences (Persistent)';

  Future<StorageService> init() async {
    print("📱 Initializing StorageService...");

    try {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
      _usingMemoryStorage = false;
      print("✅ SharedPreferences initialized successfully");

      // Debug current state
      _debugInitialState();
    } catch (e) {
      print("⚠️ SharedPreferences failed: $e");
      print("🧠 Falling back to in-memory storage");
      _isInitialized = true;
      _usingMemoryStorage = true;
      _memoryStorage.clear();
    }

    return this;
  }

  // ✅ FIXED: Save profile image locally with hash verification
  Future<String?> saveProfileImageLocally(File imageFile, String userId) async {
    if (!_isInitialized) return null;

    try {
      print('💾 === SAVING PROFILE IMAGE LOCALLY ===');
      print('   User ID: $userId');
      print('   Source path: ${imageFile.path}');

      // Verify source file exists
      if (!await imageFile.exists()) {
        print('❌ Source image file does not exist');
        return null;
      }

      // ✅ FIXED: Get application documents directory with proper import
      final appDir = await getApplicationDocumentsDirectory();
      final profileDir = Directory('${appDir.path}/$profileImagesDir');

      // Create profile images directory if it doesn't exist
      if (!await profileDir.exists()) {
        await profileDir.create(recursive: true);
        print('📁 Created profile images directory: ${profileDir.path}');
      }

      // Generate unique filename with user ID and timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last.toLowerCase();
      final filename = 'profile_${userId}_$timestamp.$extension';
      final localImagePath = '${profileDir.path}/$filename';

      // Copy image to local storage
      final localImageFile = await imageFile.copy(localImagePath);
      print('📱 Image copied to local storage: $localImagePath');

      // ✅ FIXED: Generate hash for integrity verification with proper import
      final imageBytes = await localImageFile.readAsBytes();
      final imageHash = sha256.convert(imageBytes).toString();

      // Save metadata to preferences
      await _setValue(profileImagePathKey, localImagePath);
      await _setValue(profileImageHashKey, imageHash);

      // Update profile data cache
      await _updateLocalProfileData({
        'local_image_path': localImagePath,
        'local_image_hash': imageHash,
        'local_image_size': imageBytes.length,
        'local_image_saved_at': DateTime.now().toIso8601String(),
      });

      print('✅ Profile image saved locally with hash: ${imageHash.substring(0, 8)}...');
      return localImagePath;

    } catch (e) {
      print('❌ Error saving profile image locally: $e');
      return null;
    }
  }

  // ✅ FIXED: Download and save profile image from URL
  Future<String?> downloadAndSaveProfileImage(String imageUrl, String userId) async {
    if (!_isInitialized || imageUrl.isEmpty) return null;

    try {
      print('🌐 === DOWNLOADING PROFILE IMAGE ===');
      print('   URL: $imageUrl');
      print('   User ID: $userId');

      // Check if we already have this image
      final existingPath = getLocalProfileImagePath();
      if (existingPath != null && await File(existingPath).exists()) {
        print('ℹ️ Profile image already exists locally: $existingPath');
        return existingPath;
      }

      // Download image with timeout
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: {'User-Agent': 'HRTech-Mobile/1.0'},
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Determine file extension from content type or URL
        String extension = 'jpg'; // default
        final contentType = response.headers['content-type'];
        if (contentType != null) {
          if (contentType.contains('png')) extension = 'png';
          else if (contentType.contains('jpeg') || contentType.contains('jpg')) extension = 'jpg';
        } else {
          // Try to get extension from URL
          final urlExtension = imageUrl.split('.').last.toLowerCase();
          if (['jpg', 'jpeg', 'png'].contains(urlExtension)) {
            extension = urlExtension;
          }
        }

        // ✅ FIXED: Save to temporary file first with proper import
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/temp_profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
        final tempFile = File(tempPath);
        await tempFile.writeAsBytes(response.bodyBytes);

        // Move to permanent location using our save method
        final localPath = await saveProfileImageLocally(tempFile, userId);

        // Clean up temp file
        try {
          await tempFile.delete();
        } catch (e) {
          print('⚠️ Could not delete temp file: $e');
        }

        if (localPath != null) {
          print('✅ Profile image downloaded and saved: $localPath');
        }

        return localPath;
      } else {
        print('❌ Failed to download image: ${response.statusCode}');
        return null;
      }

    } catch (e) {
      print('❌ Error downloading profile image: $e');
      return null;
    }
  }

  // ✅ ENHANCED: Get local profile image path with verification
  String? getLocalProfileImagePath() {
    if (!_isInitialized) return null;

    try {
      final localPath = _getValue(profileImagePathKey, defaultValue: null) as String?;

      if (localPath == null) {
        print('ℹ️ No local profile image path stored');
        return null;
      }

      // Verify file still exists
      if (!File(localPath).existsSync()) {
        print('⚠️ Local profile image file missing, clearing path');
        // Clear invalid path
        Future.microtask(() async {
          await remove(profileImagePathKey);
          await remove(profileImageHashKey);
        });
        return null;
      }

      return localPath;
    } catch (e) {
      print('❌ Error getting local profile image path: $e');
      return null;
    }
  }

  // ✅ FIXED: Verify image integrity
  Future<bool> verifyLocalImageIntegrity() async {
    if (!_isInitialized) return false;

    try {
      final localPath = getLocalProfileImagePath();
      if (localPath == null) return false;

      final storedHash = _getValue(profileImageHashKey, defaultValue: null) as String?;
      if (storedHash == null) return false;

      // ✅ FIXED: Calculate current hash with proper crypto import
      final imageFile = File(localPath);
      final imageBytes = await imageFile.readAsBytes();
      final currentHash = sha256.convert(imageBytes).toString();

      final isValid = currentHash == storedHash;
      print('🔍 Image integrity check: ${isValid ? '✅ VALID' : '❌ CORRUPTED'}');

      return isValid;
    } catch (e) {
      print('❌ Error verifying image integrity: $e');
      return false;
    }
  }

  // ✅ ENHANCED: Save comprehensive profile data locally
  Future<bool> saveLocalProfileData({
    required String username,
    required String fullName,
    required String email,
    String? profileImageUrl,
    String? localImagePath,
    Map<String, dynamic>? additionalData,
  }) async {
    if (!_isInitialized) return false;

    try {
      print('💾 === SAVING COMPREHENSIVE PROFILE DATA ===');

      // ✅ FIXED: Explicitly declare as Map<String, dynamic> to accept additionalData
      final Map<String, dynamic> profileData = {
        'username': username.trim(),
        'full_name': fullName.trim(),
        'email': email.trim(),
        'profile_image_url': profileImageUrl ?? '',
        'local_image_path': localImagePath ?? '',
        'saved_at': DateTime.now().toIso8601String(),
        'app_version': '1.0.0', // Add your app version
        'data_version': '2.0', // Version your data structure
      };

      // Add any additional HR-specific data
      if (additionalData != null) {
        profileData.addAll(additionalData);
      }

      // Save to both cache and persistent storage
      _cachedProfileData = Map.from(profileData);
      _profileCacheLoaded = true;

      final success = await _setValue(profileDataKey, json.encode(profileData));
      await _setValue(profileLastSyncKey, DateTime.now().toIso8601String());

      if (success) {
        print('✅ Comprehensive profile data saved locally');
        print('   - Username: $username');
        print('   - Full name: $fullName');
        print('   - Email: $email');
        print('   - Has image URL: ${profileImageUrl?.isNotEmpty == true}');
        print('   - Has local image: ${localImagePath?.isNotEmpty == true}');
      }

      return success;
    } catch (e) {
      print('❌ Error saving local profile data: $e');
      return false;
    }
  }

  // ✅ ENHANCED: Get comprehensive profile data with caching
  Map<String, dynamic>? getLocalProfileData() {
    if (!_isInitialized) return null;

    try {
      // Return cached data if available
      if (_profileCacheLoaded && _cachedProfileData.isNotEmpty) {
        return Map.from(_cachedProfileData);
      }

      // Load from storage
      final profileString = _getValue(profileDataKey, defaultValue: null) as String?;
      if (profileString == null) {
        print('ℹ️ No local profile data found');
        return null;
      }

      final profileData = json.decode(profileString) as Map<String, dynamic>;

      // Cache for future use
      _cachedProfileData = Map.from(profileData);
      _profileCacheLoaded = true;

      print('✅ Local profile data loaded from storage');
      return Map.from(profileData);
    } catch (e) {
      print('❌ Error getting local profile data: $e');
      return null;
    }
  }

  // ✅ ENHANCED: Get username with fallback logic
  String? getStoredUsername() {
    if (!_isInitialized) return null;

    try {
      // Try profile data first
      final profileData = getLocalProfileData();
      if (profileData != null && profileData['username']?.toString().trim().isNotEmpty == true) {
        return profileData['username'].toString().trim();
      }

      // Fallback to user data
      final userData = getUser();
      if (userData != null) {
        final username = userData['username']?.toString().trim() ??
            userData['unique_username']?.toString().trim();
        if (username?.isNotEmpty == true) {
          return username;
        }
      }

      print('⚠️ No username found in local storage');
      return null;
    } catch (e) {
      print('❌ Error getting stored username: $e');
      return null;
    }
  }

  // ✅ ENHANCED: Get full name with fallback logic
  String? getStoredFullName() {
    if (!_isInitialized) return null;

    try {
      // Try profile data first
      final profileData = getLocalProfileData();
      if (profileData != null && profileData['full_name']?.toString().trim().isNotEmpty == true) {
        return profileData['full_name'].toString().trim();
      }

      // Fallback to user data
      final userData = getUser();
      if (userData != null) {
        final fullName = userData['full_name']?.toString().trim() ??
            userData['name']?.toString().trim();
        if (fullName?.isNotEmpty == true) {
          return fullName;
        }
      }

      print('⚠️ No full name found in local storage');
      return null;
    } catch (e) {
      print('❌ Error getting stored full name: $e');
      return null;
    }
  }

  // ✅ ENHANCED: Update profile data incrementally
  Future<bool> _updateLocalProfileData(Map<String, dynamic> updates) async {
    try {
      final currentData = getLocalProfileData() ?? <String, dynamic>{};
      currentData.addAll(updates);
      currentData['updated_at'] = DateTime.now().toIso8601String();

      _cachedProfileData = Map.from(currentData);
      return await _setValue(profileDataKey, json.encode(currentData));
    } catch (e) {
      print('❌ Error updating local profile data: $e');
      return false;
    }
  }

  // ✅ FIXED: Clean up old profile images
  Future<void> cleanupOldProfileImages(String currentUserId) async {
    try {
      print('🧹 === CLEANING UP OLD PROFILE IMAGES ===');

      // ✅ FIXED: Use proper path_provider import
      final appDir = await getApplicationDocumentsDirectory();
      final profileDir = Directory('${appDir.path}/$profileImagesDir');

      if (!await profileDir.exists()) {
        print('ℹ️ Profile images directory does not exist');
        return;
      }

      final files = await profileDir.list().toList();
      final currentImagePath = getLocalProfileImagePath();
      int deletedCount = 0;

      for (final file in files) {
        if (file is File) {
          // Don't delete current user's image
          if (currentImagePath != null && file.path == currentImagePath) {
            continue;
          }

          // Delete old images from other users or sessions
          try {
            await file.delete();
            deletedCount++;
            print('🗑️ Deleted old image: ${file.path}');
          } catch (e) {
            print('⚠️ Could not delete image: ${file.path} - $e');
          }
        }
      }

      print('✅ Cleanup complete: $deletedCount old images deleted');
    } catch (e) {
      print('❌ Error cleaning up old profile images: $e');
    }
  }

  // ✅ ENHANCED: Get profile image (local first, then URL)
  String? getBestAvailableProfileImage() {
    // Try local image first
    final localPath = getLocalProfileImagePath();
    if (localPath != null) {
      return localPath;
    }

    // Fallback to URL
    final profileData = getLocalProfileData();
    if (profileData != null && profileData['profile_image_url']?.toString().isNotEmpty == true) {
      return profileData['profile_image_url'].toString();
    }

    // Final fallback to user data
    final userData = getUser();
    if (userData != null) {
      final imageUrl = userData['profile_image']?.toString() ??
          userData['profile_picture']?.toString() ??
          userData['avatar']?.toString();
      if (imageUrl?.isNotEmpty == true && imageUrl != 'null') {
        return imageUrl;
      }
    }

    return null;
  }

  // ✅ ENHANCED: Check if profile data is available offline
  bool isProfileDataAvailableOffline() {
    if (!_isInitialized) return false;

    try {
      final profileData = getLocalProfileData();
      final hasBasicData = profileData != null &&
          profileData['username']?.toString().trim().isNotEmpty == true &&
          profileData['full_name']?.toString().trim().isNotEmpty == true;

      final hasLocalImage = getLocalProfileImagePath() != null;

      print('🔍 Offline profile availability:');
      print('   - Basic data: $hasBasicData');
      print('   - Local image: $hasLocalImage');

      return hasBasicData;
    } catch (e) {
      print('❌ Error checking offline profile availability: $e');
      return false;
    }
  }

  // ✅ ENHANCED: Export profile data (for debugging or data migration)
  Map<String, dynamic> exportProfileDataForDebug() {
    try {
      return {
        'cached_profile_loaded': _profileCacheLoaded,
        'cached_profile_data': Map.from(_cachedProfileData),
        'stored_profile_data': getLocalProfileData(),
        'stored_username': getStoredUsername(),
        'stored_full_name': getStoredFullName(),
        'local_image_path': getLocalProfileImagePath(),
        'best_available_image': getBestAvailableProfileImage(),
        'offline_available': isProfileDataAvailableOffline(),
        'user_data': getUser(),
        'export_timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ✅ ENHANCED: Clear all profile data
  Future<bool> clearAllProfileData() async {
    if (!_isInitialized) return false;

    try {
      print('🧹 === CLEARING ALL PROFILE DATA ===');

      // Clear local image file
      final localImagePath = getLocalProfileImagePath();
      if (localImagePath != null) {
        try {
          await File(localImagePath).delete();
          print('🗑️ Deleted local profile image');
        } catch (e) {
          print('⚠️ Could not delete local image: $e');
        }
      }

      // Clear cached data
      _cachedProfileData.clear();
      _profileCacheLoaded = false;

      // Clear storage keys
      final keys = [
        profileImagePathKey,
        profileImageHashKey,
        profileDataKey,
        profileLastSyncKey,
      ];

      for (final key in keys) {
        await remove(key);
      }

      print('✅ All profile data cleared');
      return true;
    } catch (e) {
      print('❌ Error clearing profile data: $e');
      return false;
    }
  }

  // ✅ ENHANCED: Sync profile data (for when coming back online)
  Future<bool> syncProfileDataWithServer(Map<String, dynamic> serverProfileData) async {
    if (!_isInitialized) return false;

    try {
      print('🔄 === SYNCING PROFILE DATA WITH SERVER ===');

      final username = serverProfileData['username']?.toString() ?? '';
      final fullName = serverProfileData['full_name']?.toString() ?? '';
      final email = serverProfileData['email']?.toString() ?? '';
      final profileImageUrl = serverProfileData['profile_image']?.toString() ?? '';

      // Update local profile data
      await saveLocalProfileData(
        username: username,
        fullName: fullName,
        email: email,
        profileImageUrl: profileImageUrl,
        localImagePath: getLocalProfileImagePath(),
        additionalData: {
          'synced_at': DateTime.now().toIso8601String(),
          'server_data': serverProfileData,
        },
      );

      // Download image if URL changed and we don't have it locally
      if (profileImageUrl.isNotEmpty && getLocalProfileImagePath() == null) {
        final userData = getUser();
        final userId = userData?['id']?.toString() ?? 'unknown';
        await downloadAndSaveProfileImage(profileImageUrl, userId);
      }

      print('✅ Profile data synced with server');
      return true;
    } catch (e) {
      print('❌ Error syncing profile data: $e');
      return false;
    }
  }

  // ========================================================================
  // EXISTING METHODS (keeping all your original functionality)
  // ========================================================================

  bool hasExpiredSessionData() {
    if (!_isInitialized) return false;

    try {
      final userData = getUser();
      return userData != null && userData['expired_session'] == true;
    } catch (e) {
      print("❌ Error checking expired session data: $e");
      return false;
    }
  }

  // Track if this is a fresh user session
  static const String isFreshUserKey = 'is_fresh_user';

  Future<bool> markAsFreshUser() async {
    if (!_isInitialized) return false;

    try {
      return await _setValue(isFreshUserKey, true);
    } catch (e) {
      print("❌ Error marking as fresh user: $e");
      return false;
    }
  }

  bool isFreshUser() {
    if (!_isInitialized) return false;

    try {
      return _getValue(isFreshUserKey, defaultValue: false) as bool;
    } catch (e) {
      print("❌ Error checking fresh user: $e");
      return false;
    }
  }

  Future<bool> saveLastRoute(String route) async {
    if (!_isInitialized) return false;
    print('💾 Saving last route: $route');
    return await _setValue(lastRouteKey, route);
  }

  String getLastRoute() {
    if (!_isInitialized) return '/home';
    final route = _getValue(lastRouteKey, defaultValue: '/home') as String;
    print('🔍 Retrieved last route: $route');
    return route;
  }

  Future<bool> clearFreshUserFlag() async {
    if (!_isInitialized) return false;

    try {
      return await remove(isFreshUserKey);
    } catch (e) {
      print("❌ Error clearing fresh user flag: $e");
      return false;
    }
  }

  bool isFreshGoogleUser() {
    if (!_isInitialized) return false;

    try {
      final user = getUser();
      if (user == null || user['provider'] != 'google') {
        return false;
      }

      final isFresh = isFreshUser();
      final hasProfile = hasCompletedProfile();
      final hasOnboarding = hasCompletedOnboarding();
      final authMethod = user['auth_method']?.toString() ?? '';

      return isFresh ||
          !hasProfile ||
          !hasOnboarding ||
          authMethod.contains('registration');
    } catch (e) {
      print("❌ Error checking fresh Google user: $e");
      return false;
    }
  }

  Map<String, dynamic>? getPreservedUserData() {
    if (!_isInitialized) return null;

    try {
      final userData = getUser();
      if (userData != null && userData['expired_session'] == true) {
        return userData;
      }
      return null;
    } catch (e) {
      print("❌ Error getting preserved user data: $e");
      return null;
    }
  }

  Future<bool> clearExpiredSessionFlag() async {
    if (!_isInitialized) return false;

    try {
      final userData = getUser();
      if (userData != null) {
        userData.remove('expired_session');
        userData.remove('needs_reauth');
        userData.remove('preserved_at');

        return await saveUser(userData);
      }
      return true;
    } catch (e) {
      print("❌ Error clearing expired session flag: $e");
      return false;
    }
  }

  Future<bool> logoutPreservingProgress() async {
    if (!_isInitialized) return false;

    try {
      final userData = getUser();
      final userId = userData?['id']?.toString();

      if (userId != null) {
        await _saveCurrentSubscriptionToUserStorage(userId);
      }

      await remove(userKey);
      await remove(tokenKey);
      await remove(isLoggedInKey);
      await remove(subscriptionStatusKey);
      await remove(subscriptionPlanKey);
      await remove(subscriptionExpiryKey);

      print("✅ Smart logout completed - progress, profile, and subscription data preserved");
      return true;
    } catch (e) {
      print("❌ Error during smart logout: $e");
      return false;
    }
  }

  Future<bool> saveUserWithExpirationInfo(Map<String, dynamic> userData, {bool isExpired = false}) async {
    if (!_isInitialized) return false;

    try {
      if (isExpired) {
        userData['expired_session'] = true;
        userData['needs_reauth'] = true;
        userData['preserved_at'] = DateTime.now().toIso8601String();
      }

      final userString = json.encode(userData);
      bool userSaved = await _setValue(userKey, userString);

      if (!isExpired) {
        bool loginSet = await _setValue(isLoggedInKey, true);
        bool appMarked = await _setValue(hasUsedAppBeforeKey, true);
        bool firstInstallMarked = await markFirstInstallComplete();

        final userId = userData['id']?.toString();
        if (userId != null) {
          await _loadUserSubscriptionFromStorage(userId);
        }

        return userSaved && loginSet && appMarked && firstInstallMarked;
      }

      return userSaved;
    } catch (e) {
      print("❌ Error saving user with expiration info: $e");
      return false;
    }
  }

  bool needsReAuthentication() {
    if (!_isInitialized) return false;

    try {
      final userData = getUser();
      return userData != null && userData['needs_reauth'] == true;
    } catch (e) {
      print("❌ Error checking re-authentication need: $e");
      return false;
    }
  }

  bool isFullyLoggedIn() {
    if (!_isInitialized) return false;

    try {
      final loginFlag = _getValue(isLoggedInKey, defaultValue: false) as bool;
      final hasUser = getUser() != null;
      final hasToken = getToken() != null;
      final needsReauth = needsReAuthentication();

      return loginFlag && hasUser && hasToken && !needsReauth;
    } catch (e) {
      print("❌ Error checking full login status: $e");
      return false;
    }
  }

  void printStorageInfo() {
    print("📊 === STORAGE INFO ===");
    print("   Type: $storageType");
    print("   Initialized: $_isInitialized");
    print("   Total Keys: ${getAllKeys().length}");
    print("");
    print("   🔐 AUTHENTICATION:");
    print("   - Has User: ${hasKey(userKey)}");
    print("   - Has Token: ${hasKey(tokenKey)}");
    print("   - Is Logged In: ${isLoggedIn()}");
    print("   - Is Fully Logged In: ${isFullyLoggedIn()}");
    print("   - Needs Re-auth: ${needsReAuthentication()}");
    print("   - Has Expired Session: ${hasExpiredSessionData()}");
    print("");
    print("   📱 ONBOARDING & PROFILE:");
    print("   - Has Completed Onboarding: ${hasCompletedOnboarding()}");
    print("   - Has Completed Profile: ${hasCompletedProfile()}");
    print("");
    print("   💳 SUBSCRIPTION:");
    print("   - Has Active Subscription: ${hasActiveSubscription()}");
    print("   - Subscription Status: ${getSubscriptionStatus()}");

    final userSubs = _getAllUserSubscriptions();
    print("   - All User Subscriptions:");
    userSubs.forEach((userId, data) {
      print("     * User $userId: ${data['status']} (${data['updated_at'] ?? 'no timestamp'})");
    });
    print("");
    print("   📊 APP USAGE TRACKING:");
    print("   - Has Used App Before: ${hasUsedAppBefore()}");
    print("   - Has Seen Login: ${hasSeenLogin()}");
    print("   - First Install Complete: ${hasKey(firstInstallCompleteKey)}");
    print("📊 === END STORAGE INFO ===");
  }

  void _debugInitialState() {
    try {
      print("🔍 === INITIAL STORAGE STATE ===");
      final allKeys = getAllKeys();
      print("   - Total keys: ${allKeys.length}");
      print("   - Keys: $allKeys");

      print("   - Has user data: ${hasKey(userKey)}");
      print("   - Has token: ${hasKey(tokenKey)}");
      print("   - Has login flag: ${hasKey(isLoggedInKey)}");
      print("   - Has completed onboarding: ${hasKey(hasCompletedOnboardingKey)}");
      print("   - Has completed profile: ${hasKey(hasCompletedProfileKey)}");
      print("   - Has used app before: ${hasKey(hasUsedAppBeforeKey)}");
      print("   - Has seen login: ${hasKey(hasSeenLoginKey)}");
      print("   - First install complete: ${hasKey(firstInstallCompleteKey)}");
      print("   - Has user subscriptions: ${hasKey(userSubscriptionsKey)}");

      print("   - isLoggedIn(): ${isLoggedIn()}");
      print("   - hasCompletedOnboarding(): ${hasCompletedOnboarding()}");
      print("   - hasCompletedProfile(): ${hasCompletedProfile()}");
      print("   - hasActiveSubscription(): ${hasActiveSubscription()}");
      print("🔍 === INITIAL STATE END ===");
    } catch (e) {
      print("❌ Error debugging initial state: $e");
    }
  }

  // Helper method to get values safely
  dynamic _getValue(String key, {dynamic defaultValue}) {
    if (!_isInitialized) return defaultValue;

    try {
      if (_usingMemoryStorage) {
        return _memoryStorage[key] ?? defaultValue;
      } else {
        if (defaultValue is bool) {
          return _prefs!.getBool(key) ?? defaultValue;
        } else if (defaultValue is String) {
          return _prefs!.getString(key) ?? defaultValue;
        } else if (defaultValue is int) {
          return _prefs!.getInt(key) ?? defaultValue;
        } else {
          return _prefs!.get(key) ?? defaultValue;
        }
      }
    } catch (e) {
      print("❌ Error getting value for key $key: $e");
      return defaultValue;
    }
  }

  // Helper method to set values safely
  Future<bool> _setValue(String key, dynamic value) async {
    if (!_isInitialized) return false;

    try {
      if (_usingMemoryStorage) {
        _memoryStorage[key] = value;
        return true;
      } else {
        if (value is bool) {
          return await _prefs!.setBool(key, value);
        } else if (value is String) {
          return await _prefs!.setString(key, value);
        } else if (value is int) {
          return await _prefs!.setInt(key, value);
        } else {
          return await _prefs!.setString(key, value.toString());
        }
      }
    } catch (e) {
      print("❌ Error setting value for key $key: $e");
      return false;
    }
  }

  Map<String, dynamic>? getUser() {
    if (!_isInitialized) return null;

    try {
      final userString = _getValue(userKey, defaultValue: null) as String?;
      if (userString == null || userString.isEmpty) return null;
      return json.decode(userString) as Map<String, dynamic>;
    } catch (e) {
      print("❌ Error getting user: $e");
      return null;
    }
  }

  Future<bool> saveToken(String token) async {
    if (!_isInitialized) return false;

    try {
      final result = await _setValue(tokenKey, token);
      if (result) {
        print("✅ Token saved");
      }
      return result;
    } catch (e) {
      print("❌ Error saving token: $e");
      return false;
    }
  }

  String? getToken() {
    if (!_isInitialized) return null;

    try {
      return _getValue(tokenKey, defaultValue: null) as String?;
    } catch (e) {
      print("❌ Error getting token: $e");
      return null;
    }
  }

  bool isLoggedIn() {
    if (!_isInitialized) return false;

    try {
      final loginFlag = _getValue(isLoggedInKey, defaultValue: false) as bool;
      final hasUser = getUser() != null;
      final hasToken = getToken() != null;

      return loginFlag && hasUser && hasToken;
    } catch (e) {
      print("❌ Error checking login status: $e");
      return false;
    }
  }

  Future<bool> setLoggedIn(bool isLoggedIn) async {
    return await _setValue(isLoggedInKey, isLoggedIn);
  }

  // ONBOARDING METHODS
  Future<bool> setOnboardingCompleted(bool completed) async {
    if (!_isInitialized) return false;

    try {
      print("📱 Setting onboarding completed: $completed");

      bool onboardingSet = await _setValue(hasCompletedOnboardingKey, completed);

      if (completed) {
        bool appUsed = await _setValue(hasUsedAppBeforeKey, true);
        bool firstComplete = await markFirstInstallComplete();
        print("✅ Onboarding completed and app usage tracked");
        return onboardingSet && appUsed && firstComplete;
      }

      return onboardingSet;
    } catch (e) {
      print("❌ Error setting onboarding status: $e");
      return false;
    }
  }

  bool hasCompletedOnboarding() {
    if (!_isInitialized) return false;

    try {
      final completed = _getValue(hasCompletedOnboardingKey, defaultValue: false) as bool;
      print("🔍 Onboarding completed: $completed");
      return completed;
    } catch (e) {
      print("❌ Error checking onboarding status: $e");
      return false;
    }
  }

  // PROFILE COMPLETION METHODS
  Future<bool> setProfileCompleted(bool completed) async {
    if (!_isInitialized) return false;

    try {
      print("👤 Setting profile completed: $completed");

      bool profileSet = await _setValue(hasCompletedProfileKey, completed);

      if (completed) {
        bool appUsed = await _setValue(hasUsedAppBeforeKey, true);
        bool firstComplete = await markFirstInstallComplete();
        print("✅ Profile completed and app usage tracked");
        return profileSet && appUsed && firstComplete;
      }

      return profileSet;
    } catch (e) {
      print("❌ Error setting profile completion status: $e");
      return false;
    }
  }

  bool hasCompletedProfile() {
    if (!_isInitialized) return false;

    try {
      final completed = _getValue(hasCompletedProfileKey, defaultValue: false) as bool;
      print("🔍 Profile completed: $completed");
      return completed;
    } catch (e) {
      print("❌ Error checking profile completion status: $e");
      return false;
    }
  }

  Future<bool> markProfileAsCompleted() async {
    return await setProfileCompleted(true);
  }

  Future<bool> clearProfileCompletion() async {
    return await setProfileCompleted(false);
  }

  Future<bool> ensureSubscriptionDataIntegrity() async {
    if (!_isInitialized) return false;

    try {
      print("🔧 Ensuring subscription data integrity...");

      final userData = getUser();
      final userId = userData?['id']?.toString();

      if (userId == null) {
        print("❌ No user ID for subscription data integrity check");
        return false;
      }

      final hasUserSpecificData = userHasSubscriptionData(userId);
      final userSpecificStatus = getUserSpecificSubscriptionStatus(userId);
      final sessionStatus = getSubscriptionStatus();

      print("🔍 Subscription data integrity check:");
      print("   - Has user-specific data: $hasUserSpecificData");
      print("   - User-specific status: $userSpecificStatus");
      print("   - Session status: $sessionStatus");

      final hasProfile = hasCompletedProfile();
      final hasUsedApp = hasUsedAppBefore();

      if (hasProfile && hasUsedApp && !hasUserSpecificData) {
        print("🔧 Creating missing subscription data for returning user");
        await setSubscriptionStatus(status: 'active');
        return true;
      }

      if (hasUserSpecificData && sessionStatus != userSpecificStatus) {
        print("🔧 Syncing session status with user-specific status");
        await _setValue(subscriptionStatusKey, userSpecificStatus);
        return true;
      }

      return true;
    } catch (e) {
      print("❌ Error ensuring subscription data integrity: $e");
      return false;
    }
  }

  Future<bool> saveUser(Map<String, dynamic> userData) async {
    if (!_isInitialized) return false;

    try {
      final userString = json.encode(userData);
      final userId = userData['id']?.toString();

      print("💾 Enhanced user save process starting...");

      bool userSaved = await _setValue(userKey, userString);
      bool loginSet = await _setValue(isLoggedInKey, true);
      bool appMarked = await _setValue(hasUsedAppBeforeKey, true);
      bool firstInstallMarked = await markFirstInstallComplete();

      bool subscriptionLoaded = false;
      if (userId != null) {
        print("🔄 Enhanced subscription data loading for user: $userId");
        subscriptionLoaded = await _loadUserSubscriptionFromStorage(userId);
        await ensureSubscriptionDataIntegrity();

        final finalHasData = userHasSubscriptionData(userId);
        final finalStatus = getSubscriptionStatus();

        print("🔍 Enhanced post-save verification:");
        print("   - User has subscription data: $finalHasData");
        print("   - Final session status: $finalStatus");
        print("   - Subscription loaded successfully: $subscriptionLoaded");
      }

      final allSuccess = userSaved && loginSet && appMarked && firstInstallMarked;

      if (allSuccess) {
        print("✅ Enhanced user save completed: ${userData['email']}");
        print("✅ User logged in with subscription integrity: ${subscriptionLoaded}");
      }

      return allSuccess;
    } catch (e) {
      print("❌ Error in enhanced user save: $e");
      return false;
    }
  }

  Future<bool> setSubscriptionStatus({
    required String status,
    String? planId,
    String? planName,
    DateTime? expiryDate,
  }) async {
    if (!_isInitialized) {
      print("❌ Cannot set subscription status - service not initialized");
      return false;
    }

    try {
      print("📋 Enhanced subscription status setting to: $status");

      final userData = getUser();
      final userId = userData?['id']?.toString();

      if (userId == null) {
        print("❌ Cannot set subscription status - no user ID found");
        return false;
      }

      const validStatuses = ['pending', 'active', 'expired', 'cancelled'];
      if (!validStatuses.contains(status)) {
        print("❌ Invalid subscription status: $status");
        return false;
      }

      bool statusSaved = await _setValue(subscriptionStatusKey, status);
      bool planSaved = true;
      bool expirySaved = true;

      String? planJson;
      if (planId != null) {
        planJson = json.encode({
          'plan_id': planId,
          'plan_name': planName ?? '',
        });
        planSaved = await _setValue(subscriptionPlanKey, planJson);
      }

      String? expiryString;
      if (expiryDate != null) {
        expiryString = expiryDate.toIso8601String();
        expirySaved = await _setValue(subscriptionExpiryKey, expiryString);
      }

      if (statusSaved && planSaved && expirySaved) {
        bool userSpecificSaved = await _saveCurrentSubscriptionToUserStorage(userId);

        if (userSpecificSaved) {
          await Future.delayed(Duration(milliseconds: 50));

          final verifyHasData = userHasSubscriptionData(userId);
          final verifyStatus = getUserSpecificSubscriptionStatus(userId);
          final verifySessionStatus = getSubscriptionStatus();

          print("✅ Enhanced subscription status saved for user $userId:");
          print("   - Session status: $verifySessionStatus");
          print("   - User-specific status: $verifyStatus");
          print("   - User-specific data exists: $verifyHasData");
          print("   - Status match: ${verifySessionStatus == verifyStatus}");

          if (verifySessionStatus != verifyStatus && verifyHasData) {
            print("🔧 Status mismatch detected - attempting to fix...");
            await _setValue(subscriptionStatusKey, verifyStatus);
          }
        } else {
          print("⚠️ Session data saved but user-specific preservation failed");
        }

        return userSpecificSaved;
      }

      return false;
    } catch (e) {
      print("❌ Error in enhanced subscription status setting: $e");
      return false;
    }
  }

  Future<bool> logout() async {
    if (!_isInitialized) return false;

    try {
      print("🚪 Enhanced logout process starting...");

      final userData = getUser();
      final userId = userData?['id']?.toString();

      if (userId != null) {
        print("💾 Ensuring subscription data is preserved for user: $userId");
        await _saveCurrentSubscriptionToUserStorage(userId);

        final hasDataAfterSave = userHasSubscriptionData(userId);
        print("✅ Subscription data preserved: $hasDataAfterSave");
      }

      await remove(userKey);
      await remove(tokenKey);
      await remove(isLoggedInKey);
      await remove(subscriptionStatusKey);
      await remove(subscriptionPlanKey);
      await remove(subscriptionExpiryKey);

      print("✅ Enhanced logout completed - all progress and subscription data preserved");
      return true;
    } catch (e) {
      print("❌ Error during enhanced logout: $e");
      return false;
    }
  }

  void diagnoseSubscriptionState() {
    print("🔍 === SUBSCRIPTION STATE DIAGNOSIS ===");

    try {
      final userData = getUser();
      final userId = userData?['id']?.toString();

      if (userId == null) {
        print("❌ No user ID available for diagnosis");
        return;
      }

      final hasUserSpecificData = userHasSubscriptionData(userId);
      final userSpecificStatus = getUserSpecificSubscriptionStatus(userId);
      final sessionStatus = getSubscriptionStatus();
      final hasActiveSession = hasActiveSubscription();

      final allUserSubs = _getAllUserSubscriptions();
      final currentUserSub = allUserSubs[userId];

      print("   User ID: $userId");
      print("   Has user-specific data: $hasUserSpecificData");
      print("   User-specific status: $userSpecificStatus");
      print("   Session status: $sessionStatus");
      print("   Has active session: $hasActiveSession");
      print("   Status consistency: ${sessionStatus == userSpecificStatus}");

      if (currentUserSub != null) {
        print("   User subscription details:");
        print("     - Status: ${currentUserSub['status']}");
        print("     - Plan: ${currentUserSub['plan']}");
        print("     - Updated: ${currentUserSub['updated_at']}");
      }

      if (!hasUserSpecificData && hasActiveSession) {
        print("⚠️ ISSUE: Has active session but no user-specific data");
      }

      if (hasUserSpecificData && sessionStatus != userSpecificStatus) {
        print("⚠️ ISSUE: Session status doesn't match user-specific status");
      }
    } catch (e) {
      print("❌ Error in subscription state diagnosis: $e");
    }

    print("🔍 === END SUBSCRIPTION STATE DIAGNOSIS ===");
  }

  Future<bool> autoFixSubscriptionState() async {
    if (!_isInitialized) return false;

    try {
      print("🔧 Auto-fixing subscription state...");

      final userData = getUser();
      final userId = userData?['id']?.toString();

      if (userId == null) {
        print("❌ Cannot auto-fix - no user ID");
        return false;
      }

      diagnoseSubscriptionState();

      final hasUserSpecificData = userHasSubscriptionData(userId);
      final userSpecificStatus = getUserSpecificSubscriptionStatus(userId);
      final sessionStatus = getSubscriptionStatus();

      bool fixed = false;

      if (!hasUserSpecificData) {
        final hasProfile = hasCompletedProfile();
        final hasUsedApp = hasUsedAppBefore();

        if (hasProfile && hasUsedApp) {
          print("🔧 Creating missing subscription data for established user");
          await setSubscriptionStatus(status: 'active');
          fixed = true;
        }
      }

      if (hasUserSpecificData && sessionStatus != userSpecificStatus) {
        print("🔧 Syncing session status with user-specific status");
        await _setValue(subscriptionStatusKey, userSpecificStatus);
        fixed = true;
      }

      await ensureSubscriptionDataIntegrity();

      if (fixed) {
        print("✅ Auto-fix completed - running final diagnosis");
        diagnoseSubscriptionState();
      } else {
        print("ℹ️ No fixes needed - subscription state appears consistent");
      }

      return true;
    } catch (e) {
      print("❌ Error in auto-fix subscription state: $e");
      return false;
    }
  }

  Future<bool> completeUserProfile(Map<String, dynamic> profileData) async {
    if (!_isInitialized) return false;

    try {
      print("👤 Completing user profile...");

      final currentUser = getUser();
      if (currentUser != null) {
        currentUser.addAll(profileData);

        currentUser.remove('draft_full_name');
        currentUser.remove('draft_username');
        currentUser.remove('draft_in_progress');
        currentUser.remove('profile_creation_started_at');

        await saveUser(currentUser);
      }

      bool profileMarked = await markProfileAsCompleted();
      bool appMarked = await markAppAsUsed();
      bool firstComplete = await markFirstInstallComplete();

      print("✅ User profile completion process finished");
      print("   - Profile data saved: ${currentUser != null}");
      print("   - Profile marked complete: $profileMarked");
      print("   - App usage tracked: $appMarked");

      return profileMarked && appMarked && firstComplete;
    } catch (e) {
      print("❌ Error completing user profile: $e");
      return false;
    }
  }

  bool shouldSkipProfileScreen() {
    if (!_isInitialized) return false;

    try {
      final isLoggedIn = isFullyLoggedIn();
      final hasProfile = hasCompletedProfile();
      final userData = getUser();
      final userId = userData?['id']?.toString();

      final hasSubscriptionData = userId != null ? userHasSubscriptionData(userId) : false;

      print("🔍 Should skip profile screen analysis:");
      print("   - Is logged in: $isLoggedIn");
      print("   - Has completed profile: $hasProfile");
      print("   - Has subscription data: $hasSubscriptionData");

      final shouldSkip = isLoggedIn && (hasProfile || hasSubscriptionData);
      print("   - Should skip: $shouldSkip");

      return shouldSkip;
    } catch (e) {
      print("❌ Error checking if should skip profile screen: $e");
      return false;
    }
  }

  Future<bool> markLoginPageSeen() async {
    if (!_isInitialized) return false;

    try {
      bool loginSeen = await _setValue(hasSeenLoginKey, true);
      bool appUsed = await _setValue(hasUsedAppBeforeKey, true);
      bool firstComplete = await markFirstInstallComplete();

      print("✅ Login page marked as seen");
      return loginSeen && appUsed && firstComplete;
    } catch (e) {
      print("❌ Error marking login page as seen: $e");
      return false;
    }
  }

  bool hasSeenLogin() {
    return _getValue(hasSeenLoginKey, defaultValue: false) as bool;
  }

  bool hasUsedAppBefore() {
    return _getValue(hasUsedAppBeforeKey, defaultValue: false) as bool;
  }

  Future<bool> markAppAsUsed() async {
    if (!_isInitialized) return false;

    try {
      print("📱 Marking app as used before...");
      return await _setValue(hasUsedAppBeforeKey, true);
    } catch (e) {
      print("❌ Error marking app as used: $e");
      return false;
    }
  }

  Future<bool> markFirstInstallComplete() async {
    if (!_isInitialized) return false;

    try {
      return await _setValue(firstInstallCompleteKey, true);
    } catch (e) {
      print("❌ Error marking first install complete: $e");
      return false;
    }
  }

  Map<String, dynamic> _getAllUserSubscriptions() {
    if (!_isInitialized) return {};

    try {
      final subscriptionsString = _getValue(userSubscriptionsKey, defaultValue: '{}') as String;
      final decoded = json.decode(subscriptionsString) as Map<String, dynamic>;
      print("🔍 Retrieved user subscriptions: ${decoded.keys.toList()}");
      return decoded;
    } catch (e) {
      print("❌ Error getting user subscriptions: $e");
      return {};
    }
  }

  Future<bool> _saveAllUserSubscriptions(Map<String, dynamic> subscriptions) async {
    if (!_isInitialized) return false;

    try {
      final subscriptionsString = json.encode(subscriptions);
      final result = await _setValue(userSubscriptionsKey, subscriptionsString);
      print("💾 Saved user subscriptions: ${subscriptions.keys.toList()} - Success: $result");
      return result;
    } catch (e) {
      print("❌ Error saving user subscriptions: $e");
      return false;
    }
  }

  Future<bool> _saveCurrentSubscriptionToUserStorage(String userId) async {
    if (!_isInitialized) return false;

    try {
      final currentStatus = getSubscriptionStatus();
      final currentPlan = _getValue(subscriptionPlanKey, defaultValue: null) as String?;
      final currentExpiry = _getValue(subscriptionExpiryKey, defaultValue: null) as String?;

      print("💾 Saving subscription data for user $userId:");
      print("   - Status: $currentStatus");
      print("   - Plan: ${currentPlan != null ? 'YES' : 'NO'}");
      print("   - Expiry: ${currentExpiry != null ? 'YES' : 'NO'}");

      final allUserSubscriptions = _getAllUserSubscriptions();

      allUserSubscriptions[userId] = {
        'status': currentStatus,
        'plan': currentPlan,
        'expiry': currentExpiry,
        'updated_at': DateTime.now().toIso8601String(),
      };

      bool saved = await _saveAllUserSubscriptions(allUserSubscriptions);

      if (saved) {
        print("✅ User subscription data saved for user: $userId");
      } else {
        print("❌ Failed to save user subscription data for user: $userId");
      }

      return saved;
    } catch (e) {
      print("❌ Error saving current subscription to user storage: $e");
      return false;
    }
  }

  Future<bool> _loadUserSubscriptionFromStorage(String userId) async {
    if (!_isInitialized) return false;

    try {
      print("🔄 Loading subscription data for user: $userId");

      final allUserSubscriptions = _getAllUserSubscriptions();
      final userSubscriptionData = allUserSubscriptions[userId] as Map<String, dynamic>?;

      if (userSubscriptionData != null) {
        final status = userSubscriptionData['status'] ?? 'pending';
        final plan = userSubscriptionData['plan'];
        final expiry = userSubscriptionData['expiry'];

        await _setValue(subscriptionStatusKey, status);

        if (plan != null) {
          await _setValue(subscriptionPlanKey, plan);
        }

        if (expiry != null) {
          await _setValue(subscriptionExpiryKey, expiry);
        }

        print("✅ User subscription data loaded for user $userId:");
        print("   - Status: $status");
        print("   - Plan: ${plan != null ? 'YES' : 'NO'}");
        print("   - Expiry: ${expiry != null ? 'YES' : 'NO'}");

        return true;
      } else {
        print("ℹ️ No existing subscription data found for user: $userId - setting up new user");

        await _setValue(subscriptionStatusKey, 'pending');

        final allUserSubscriptions = _getAllUserSubscriptions();
        allUserSubscriptions[userId] = {
          'status': 'pending',
          'plan': null,
          'expiry': null,
          'created_at': DateTime.now().toIso8601String(),
        };
        await _saveAllUserSubscriptions(allUserSubscriptions);

        return true;
      }
    } catch (e) {
      print("❌ Error loading user subscription from storage: $e");
      return false;
    }
  }

  bool userHasSubscriptionData(String? userId) {
    if (!_isInitialized || userId == null) return false;

    try {
      final allUserSubscriptions = _getAllUserSubscriptions();
      final hasData = allUserSubscriptions.containsKey(userId);
      print("🔍 User $userId has subscription data: $hasData");
      return hasData;
    } catch (e) {
      print("❌ Error checking user subscription data: $e");
      return false;
    }
  }

  String getUserSpecificSubscriptionStatus(String? userId) {
    if (!_isInitialized || userId == null) return 'pending';

    try {
      final allUserSubscriptions = _getAllUserSubscriptions();
      final userSubscriptionData = allUserSubscriptions[userId] as Map<String, dynamic>?;

      if (userSubscriptionData != null) {
        final status = userSubscriptionData['status'] ?? 'pending';
        print("🔍 User $userId specific status: $status");
        return status;
      }

      print("🔍 User $userId has no specific status, returning pending");
      return 'pending';
    } catch (e) {
      print("❌ Error getting user-specific subscription status: $e");
      return 'pending';
    }
  }

  Future<bool> forceReloadUserSubscriptionData() async {
    if (!_isInitialized) return false;

    try {
      final userData = getUser();
      final userId = userData?['id']?.toString();

      if (userId != null) {
        print("🔄 Force reloading subscription data for user: $userId");
        return await _loadUserSubscriptionFromStorage(userId);
      }

      return false;
    } catch (e) {
      print("❌ Error force reloading user subscription data: $e");
      return false;
    }
  }

  String getSubscriptionStatus() {
    if (!_isInitialized) {
      print("❌ Cannot get subscription status - service not initialized");
      return 'pending';
    }

    try {
      final status = _getValue(subscriptionStatusKey, defaultValue: 'pending') as String;
      print("🔍 Current session subscription status: $status");
      return status;
    } catch (e) {
      print("❌ Error getting subscription status: $e");
      return 'pending';
    }
  }

  bool hasActiveSubscription() {
    final status = getSubscriptionStatus();
    final isActive = status == 'active';
    print("🔍 Has active subscription: $isActive (status: $status)");
    return isActive;
  }

  bool isProfileActuallyComplete() {
    if (!_isInitialized) return false;

    try {
      final userData = getUser();
      if (userData == null) return false;

      final hasFullName = userData['full_name']?.toString().trim().isNotEmpty == true ||
          userData['name']?.toString().trim().isNotEmpty == true;
      final hasUsername = userData['username']?.toString().trim().isNotEmpty == true;
      final hasEmail = userData['email']?.toString().trim().isNotEmpty == true;

      print("🔍 Profile completion analysis:");
      print("   - Has full name: $hasFullName");
      print("   - Has username: $hasUsername");
      print("   - Has email: $hasEmail");

      final isActuallyComplete = hasFullName && hasEmail;

      print("   - Is actually complete: $isActuallyComplete");
      return isActuallyComplete;
    } catch (e) {
      print("❌ Error checking if profile is actually complete: $e");
      return false;
    }
  }

  bool hasCompletedProfileSmart() {
    if (!_isInitialized) return false;

    try {
      final storedFlag = _getValue(hasCompletedProfileKey, defaultValue: false) as bool;
      print("🔍 Stored profile completion flag: $storedFlag");

      if (storedFlag) {
        return true;
      }

      final isActuallyComplete = isProfileActuallyComplete();

      if (isActuallyComplete && !storedFlag) {
        print("🔧 Profile is actually complete but flag was missing - correcting...");
        Future.microtask(() async {
          await markProfileAsCompleted();
        });
        return true;
      }

      return false;
    } catch (e) {
      print("❌ Error in smart profile completion check: $e");
      return false;
    }
  }

  void printProfileStatus() {
    print("👤 === PROFILE STATUS DEBUG ===");
    try {
      final userData = getUser();
      final storedFlag = _getValue(hasCompletedProfileKey, defaultValue: false) as bool;
      final isActuallyComplete = isProfileActuallyComplete();
      final smartCheck = hasCompletedProfileSmart();
      final shouldSkip = shouldSkipProfileScreen();

      print("   - User data exists: ${userData != null}");
      print("   - Stored completion flag: $storedFlag");
      print("   - Is actually complete: $isActuallyComplete");
      print("   - Smart check result: $smartCheck");
      print("   - Should skip profile screen: $shouldSkip");

      if (userData != null) {
        print("   - User fields:");
        print("     * full_name: ${userData['full_name']}");
        print("     * name: ${userData['name']}");
        print("     * username: ${userData['username']}");
        print("     * email: ${userData['email']}");
        print("     * draft_full_name: ${userData['draft_full_name']}");
        print("     * draft_in_progress: ${userData['draft_in_progress']}");
      }
    } catch (e) {
      print("❌ Error printing profile status: $e");
    }
    print("👤 === END PROFILE STATUS DEBUG ===");
  }

  bool hasKey(String key) {
    if (!_isInitialized) return false;

    try {
      if (_usingMemoryStorage) {
        return _memoryStorage.containsKey(key);
      } else {
        return _prefs!.containsKey(key);
      }
    } catch (e) {
      print("❌ Error checking key: $e");
      return false;
    }
  }

  List<String> getAllKeys() {
    if (!_isInitialized) return [];

    try {
      if (_usingMemoryStorage) {
        return _memoryStorage.keys.toList();
      } else {
        return _prefs!.getKeys().toList();
      }
    } catch (e) {
      print("❌ Error getting all keys: $e");
      return [];
    }
  }

  Future<void> clearAll() async {
    if (!_isInitialized) return;

    try {
      if (_usingMemoryStorage) {
        _memoryStorage.clear();
      } else {
        await _prefs!.clear();
      }

      print("✅ Storage cleared completely");
    } catch (e) {
      print("❌ Error clearing storage: $e");
    }
  }

  Future<bool> remove(String key) async {
    if (!_isInitialized) return false;

    try {
      if (_usingMemoryStorage) {
        _memoryStorage.remove(key);
      } else {
        await _prefs!.remove(key);
      }

      return true;
    } catch (e) {
      print("❌ Error removing key: $e");
      return false;
    }
  }

  Future<bool> cleanupInconsistentDraftData() async {
    if (!_isInitialized) return false;

    try {
      print('🧹 === CLEANING UP INCONSISTENT DRAFT DATA ===');

      final userData = getUser();
      if (userData == null) {
        print('   No user data found - nothing to clean');
        return true;
      }

      final hasCompletedProfile = this.hasCompletedProfile();
      final userId = userData['id']?.toString();

      print('   User ID: $userId');
      print('   Profile completed: $hasCompletedProfile');

      final hasDraftData = userData.containsKey('draft_full_name') ||
          userData.containsKey('draft_username') ||
          userData.containsKey('draft_in_progress') ||
          userData.containsKey('profile_creation_started_at');

      print('   Has draft data: $hasDraftData');

      if (hasCompletedProfile && hasDraftData) {
        print('   🔧 Profile completed but draft data exists - cleaning up...');

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

        bool anyRemoved = false;
        for (String key in keysToRemove) {
          if (userData.containsKey(key)) {
            userData.remove(key);
            anyRemoved = true;
            print('     - Removed: $key');
          }
        }

        if (anyRemoved) {
          bool saved = await saveUser(userData);
          if (saved) {
            print('   ✅ Draft data cleaned up successfully');
          } else {
            print('   ❌ Failed to save cleaned user data');
          }
          return saved;
        } else {
          print('   ℹ️ No draft keys found to remove');
        }
      } else if (!hasCompletedProfile && hasDraftData) {
        print('   ℹ️ Profile not completed and has draft data - this is normal');
      } else if (hasCompletedProfile && !hasDraftData) {
        print('   ✅ Profile completed and no draft data - already clean');
      } else {
        print('   ℹ️ Profile not completed and no draft data - clean state');
      }

      if (hasCompletedProfile && userId != null) {
        print('   🔍 Ensuring subscription data integrity for completed profile...');
        await ensureSubscriptionDataIntegrity();
      }

      print('🧹 === CLEANUP COMPLETE ===');
      return true;
    } catch (e) {
      print('❌ Error cleaning up inconsistent draft data: $e');
      return false;
    }
  }

  Future<bool> fixNavigationConsistency() async {
    if (!_isInitialized) return false;

    try {
      print('🔧 === FIXING NAVIGATION CONSISTENCY ===');

      await cleanupInconsistentDraftData();
      await autoFixSubscriptionState();
      printStorageInfo();

      print('✅ Navigation consistency fix completed');
      return true;
    } catch (e) {
      print('❌ Error fixing navigation consistency: $e');
      return false;
    }
  }

  Future<bool> setSubscriptionStatusDirect(String status) async {
    if (!_isInitialized) return false;

    try {
      return await _setValue(subscriptionStatusKey, status);
    } catch (e) {
      print("❌ Error setting subscription status directly: $status");
      return false;
    }
  }
}