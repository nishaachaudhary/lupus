import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lupus_care/data/api/profile_service.dart';
import 'package:lupus_care/helper/storage_service.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/views/home/home_controller.dart';

class EditProfileController extends GetxController {
  final ProfileService _profileService = ProfileService();
  final ImagePicker _picker = ImagePicker();

  // Character limits constants
  static const int FULL_NAME_MAX_LENGTH = 30;
  static const int USERNAME_MAX_LENGTH = 30;
  static const int FULL_NAME_MIN_LENGTH = 2;
  static const int USERNAME_MIN_LENGTH = 3;

  // Form controllers
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  // Observable variables
  Rx<File?> selectedImage = Rx<File?>(null);
  RxString currentProfileImageUrl = ''.obs;
  RxString localProfileImagePath = ''.obs;
  RxBool isLoading = false.obs;
  RxBool isSaving = false.obs;
  RxBool imageLoadError = false.obs;

  // ✅ NEW: Enhanced observables for username priority logic
  RxString serverUsername = ''.obs; // Username from API
  RxString localUsername = ''.obs;  // Username from local storage
  RxString displayUsername = ''.obs; // The actual username to display
  RxBool hasServerUsername = false.obs;
  RxBool hasLocalUsername = false.obs;

  // ✅ ENHANCED: Same for other fields
  RxString serverFullName = ''.obs;
  RxString localFullName = ''.obs;
  RxString displayFullName = ''.obs;
  RxBool hasServerFullName = false.obs;
  RxBool hasLocalFullName = false.obs;

  RxString serverEmail = ''.obs;
  RxString localEmail = ''.obs;
  RxString displayEmail = ''.obs;
  RxBool hasServerEmail = false.obs;
  RxBool hasLocalEmail = false.obs;

  // Reactive variables for real-time validation
  RxString fullNameText = ''.obs;
  RxString usernameText = ''.obs;
  RxString emailText = ''.obs;

  // Store original values to compare changes
  String _originalFullName = '';
  String _originalUsername = '';
  String _originalEmail = '';
  String _originalImageUrl = '';
  String _originalLocalPath = '';

  @override
  void onInit() {
    super.onInit();

    // Add listeners to text controllers for real-time updates
    fullNameController.addListener(() {
      fullNameText.value = fullNameController.text;
    });

    usernameController.addListener(() {
      usernameText.value = usernameController.text;
    });

    emailController.addListener(() {
      emailText.value = emailController.text;
    });

    // ✅ ENHANCED: Listen for profile image changes to reset error state
    currentProfileImageUrl.listen((url) {
      if (url.isNotEmpty) {
        imageLoadError.value = false;
      }
    });

    localProfileImagePath.listen((path) {
      if (path.isNotEmpty) {
        imageLoadError.value = false;
      }
    });

    loadCurrentProfile();
  }

  @override
  void onClose() {
    fullNameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    super.onClose();
  }

  // ✅ ENHANCED: Load current profile with comprehensive priority logic
  Future<void> loadCurrentProfile() async {
    try {
      isLoading.value = true;
      print("🔄 === LOADING PROFILE FOR EDITING WITH PRIORITY LOGIC ===");

      // Get user ID from storage
      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString() ?? '';

      if (userId.isEmpty) {
        print("❌ User ID not found in storage");
        await _loadFromCache();
        return;
      }

      print("✅ Loading profile for user ID: $userId");

      // ✅ STEP 1: Load local data first (always available offline)
      await _loadLocalDataPriority(userId);

      // ✅ STEP 2: Load from API and apply priority logic
      try {
        final response = await _profileService.getUserProfile(userId: userId);

        if (response['status'] == 'success' && response['data'] != null) {
          final profileData = response['data'];
          print("✅ Profile data loaded from API");

          await _applyServerDataPriority(profileData, userId);
        } else {
          print("❌ Failed to load profile from API: ${response['message']}");
          print("✅ Using local data as primary source");
        }
      } catch (e) {
        print("❌ API error, using local data: $e");
      }

      // ✅ STEP 3: Apply final priority logic and update controllers
      await _applyFinalPriorityLogic();

    } catch (e) {
      print("❌ Error loading profile: $e");
      await _loadFromCache();
    } finally {
      isLoading.value = false;
    }
  }

  // ✅ NEW: Load local data with priority tracking
  Future<void> _loadLocalDataPriority(String userId) async {
    try {
      print("📱 === LOADING LOCAL DATA WITH PRIORITY TRACKING ===");

      // Get local profile data
      final localData = StorageService.to.getLocalProfileData();
      final userData = StorageService.to.getUser();

      // ✅ Load username with priority tracking
      await _loadLocalUsername(localData, userData);

      // ✅ Load full name with priority tracking
      await _loadLocalFullName(localData, userData);

      // ✅ Load email with priority tracking
      await _loadLocalEmail(localData, userData);

      // ✅ Load image with existing priority logic
      await _loadLocalImage();

      print("📱 ✅ Local data priority loading completed");
    } catch (e) {
      print("❌ Error loading local data with priority: $e");
    }
  }

  // ✅ NEW: Load local username with fallback logic
  Future<void> _loadLocalUsername(Map<String, dynamic>? localData, Map<String, dynamic>? userData) async {
    try {
      print("📱👤 Loading local username...");

      String? foundUsername;

      // Priority 1: Local profile data
      if (localData != null && localData['username']?.toString().trim().isNotEmpty == true) {
        foundUsername = localData['username'].toString().trim();
        print("📱👤 Found username in local profile data: $foundUsername");
      }
      // Priority 2: User data - unique_username field
      else if (userData != null && userData['unique_username']?.toString().trim().isNotEmpty == true) {
        foundUsername = userData['unique_username'].toString().trim();
        print("📱👤 Found username in user data (unique_username): $foundUsername");
      }
      // Priority 3: User data - username field
      else if (userData != null && userData['username']?.toString().trim().isNotEmpty == true) {
        foundUsername = userData['username'].toString().trim();
        print("📱👤 Found username in user data (username): $foundUsername");
      }

      if (foundUsername != null) {
        localUsername.value = foundUsername;
        hasLocalUsername.value = true;
        print("📱👤 ✅ Local username set: $foundUsername");
      } else {
        localUsername.value = '';
        hasLocalUsername.value = false;
        print("📱👤 No local username found");
      }

    } catch (e) {
      print("❌ Error loading local username: $e");
      localUsername.value = '';
      hasLocalUsername.value = false;
    }
  }

  // ✅ NEW: Load local full name with fallback logic
  Future<void> _loadLocalFullName(Map<String, dynamic>? localData, Map<String, dynamic>? userData) async {
    try {
      print("📱📝 Loading local full name...");

      String? foundFullName;

      // Priority 1: Local profile data
      if (localData != null && localData['full_name']?.toString().trim().isNotEmpty == true) {
        foundFullName = localData['full_name'].toString().trim();
        print("📱📝 Found full name in local profile data: $foundFullName");
      }
      // Priority 2: User data - full_name field
      else if (userData != null && userData['full_name']?.toString().trim().isNotEmpty == true) {
        foundFullName = userData['full_name'].toString().trim();
        print("📱📝 Found full name in user data: $foundFullName");
      }

      if (foundFullName != null) {
        localFullName.value = foundFullName;
        hasLocalFullName.value = true;
        print("📱📝 ✅ Local full name set: $foundFullName");
      } else {
        localFullName.value = '';
        hasLocalFullName.value = false;
        print("📱📝 No local full name found");
      }

    } catch (e) {
      print("❌ Error loading local full name: $e");
      localFullName.value = '';
      hasLocalFullName.value = false;
    }
  }

  // ✅ NEW: Load local email with fallback logic
  Future<void> _loadLocalEmail(Map<String, dynamic>? localData, Map<String, dynamic>? userData) async {
    try {
      print("📱📧 Loading local email...");

      String? foundEmail;

      // Priority 1: Local profile data
      if (localData != null && localData['email']?.toString().trim().isNotEmpty == true) {
        foundEmail = localData['email'].toString().trim();
        print("📱📧 Found email in local profile data: $foundEmail");
      }
      // Priority 2: User data
      else if (userData != null && userData['email']?.toString().trim().isNotEmpty == true) {
        foundEmail = userData['email'].toString().trim();
        print("📱📧 Found email in user data: $foundEmail");
      }

      if (foundEmail != null) {
        localEmail.value = foundEmail;
        hasLocalEmail.value = true;
        print("📱📧 ✅ Local email set: $foundEmail");
      } else {
        localEmail.value = '';
        hasLocalEmail.value = false;
        print("📱📧 No local email found");
      }

    } catch (e) {
      print("❌ Error loading local email: $e");
      localEmail.value = '';
      hasLocalEmail.value = false;
    }
  }

  // ✅ Load local image (existing logic)
  Future<void> _loadLocalImage() async {
    try {
      print("📱🖼️ Loading local image...");

      final localImagePath = StorageService.to.getLocalProfileImagePath();
      if (localImagePath != null && File(localImagePath).existsSync()) {
        localProfileImagePath.value = localImagePath;
        _originalLocalPath = localImagePath;
        print("📱🖼️ ✅ Local image found: $localImagePath");
      } else {
        localProfileImagePath.value = '';
        print("📱🖼️ No local image found");
      }

      // Get server image URL as fallback
      final bestImage = StorageService.to.getBestAvailableProfileImage();
      if (bestImage != null && bestImage.startsWith('http')) {
        currentProfileImageUrl.value = bestImage;
        _originalImageUrl = bestImage;
        print("🌐🖼️ Server image URL: $bestImage");
      }

    } catch (e) {
      print("❌ Error loading local image: $e");
    }
  }

  // ✅ NEW: Apply server data with priority logic
  Future<void> _applyServerDataPriority(Map<String, dynamic> profileData, String userId) async {
    try {
      print("🌐 === APPLYING SERVER DATA WITH PRIORITY LOGIC ===");

      // ✅ Apply server username priority
      await _applyServerUsername(profileData);

      // ✅ Apply server full name priority
      await _applyServerFullName(profileData);

      // ✅ Apply server email priority
      await _applyServerEmail(profileData);

      // ✅ Apply server image priority (existing logic)
      await _applyServerImage(profileData, userId);

      print("🌐 ✅ Server data priority application completed");
    } catch (e) {
      print("❌ Error applying server data priority: $e");
    }
  }

  // ✅ NEW: Apply server username with priority
  Future<void> _applyServerUsername(Map<String, dynamic> profileData) async {
    try {
      print("🌐👤 Applying server username priority...");

      String? foundServerUsername;

      // Try different possible username fields from server
      final possibleUsernameFields = ['unique_username', 'username', 'user_name'];

      for (String field in possibleUsernameFields) {
        if (profileData[field]?.toString().trim().isNotEmpty == true) {
          foundServerUsername = profileData[field].toString().trim();
          print("🌐👤 Found server username in field '$field': $foundServerUsername");
          break;
        }
      }

      if (foundServerUsername != null) {
        serverUsername.value = foundServerUsername;
        hasServerUsername.value = true;
        print("🌐👤 ✅ Server username set: $foundServerUsername");
      } else {
        serverUsername.value = '';
        hasServerUsername.value = false;
        print("🌐👤 No server username found");
      }

    } catch (e) {
      print("❌ Error applying server username: $e");
      serverUsername.value = '';
      hasServerUsername.value = false;
    }
  }

  // ✅ NEW: Apply server full name with priority
  Future<void> _applyServerFullName(Map<String, dynamic> profileData) async {
    try {
      print("🌐📝 Applying server full name priority...");

      String? foundServerFullName;

      // Try different possible full name fields from server
      final possibleFullNameFields = ['full_name', 'name', 'fullName', 'display_name'];

      for (String field in possibleFullNameFields) {
        if (profileData[field]?.toString().trim().isNotEmpty == true) {
          foundServerFullName = profileData[field].toString().trim();
          print("🌐📝 Found server full name in field '$field': $foundServerFullName");
          break;
        }
      }

      if (foundServerFullName != null) {
        serverFullName.value = foundServerFullName;
        hasServerFullName.value = true;
        print("🌐📝 ✅ Server full name set: $foundServerFullName");
      } else {
        serverFullName.value = '';
        hasServerFullName.value = false;
        print("🌐📝 No server full name found");
      }

    } catch (e) {
      print("❌ Error applying server full name: $e");
      serverFullName.value = '';
      hasServerFullName.value = false;
    }
  }

  // ✅ NEW: Apply server email with priority
  Future<void> _applyServerEmail(Map<String, dynamic> profileData) async {
    try {
      print("🌐📧 Applying server email priority...");

      String? foundServerEmail;

      // Try different possible email fields from server
      final possibleEmailFields = ['email', 'email_address', 'user_email'];

      for (String field in possibleEmailFields) {
        if (profileData[field]?.toString().trim().isNotEmpty == true) {
          foundServerEmail = profileData[field].toString().trim();
          print("🌐📧 Found server email in field '$field': $foundServerEmail");
          break;
        }
      }

      if (foundServerEmail != null) {
        serverEmail.value = foundServerEmail;
        hasServerEmail.value = true;
        print("🌐📧 ✅ Server email set: $foundServerEmail");
      } else {
        serverEmail.value = '';
        hasServerEmail.value = false;
        print("🌐📧 No server email found");
      }

    } catch (e) {
      print("❌ Error applying server email: $e");
      serverEmail.value = '';
      hasServerEmail.value = false;
    }
  }

  // ✅ Apply server image (existing logic with some enhancements)
  Future<void> _applyServerImage(Map<String, dynamic> profileData, String userId) async {
    try {
      print("🌐🖼️ Applying server image priority...");

      String? serverImageUrl = _extractServerImageUrl(profileData);
      if (serverImageUrl != null && serverImageUrl.isNotEmpty) {
        final processedUrl = _processImageUrl(serverImageUrl);

        // ✅ CRITICAL: Only use server image if no local image exists (same as before)
        if (localProfileImagePath.value.isEmpty) {
          currentProfileImageUrl.value = processedUrl;
          _originalImageUrl = processedUrl;
          print("🌐🖼️ Using server image (no local image): $processedUrl");

          // ✅ Download server image for offline use
          final downloadedPath = await StorageService.to.downloadAndSaveProfileImage(processedUrl, userId);
          if (downloadedPath != null) {
            localProfileImagePath.value = downloadedPath;
            _originalLocalPath = downloadedPath;
            print("📱🖼️ ✅ Server image downloaded locally: $downloadedPath");
          }
        } else {
          print("📱🖼️ Keeping local image, server image available as backup");
          _originalImageUrl = processedUrl; // Store for comparison
        }
      }
    } catch (e) {
      print("❌ Error applying server image: $e");
    }
  }

  // ✅ NEW: Apply final priority logic and update UI controllers
  Future<void> _applyFinalPriorityLogic() async {
    try {
      print("🏆 === APPLYING FINAL PRIORITY LOGIC ===");

      // ✅ USERNAME PRIORITY: Server > Local > Empty
      if (hasServerUsername.value && serverUsername.value.isNotEmpty) {
        displayUsername.value = serverUsername.value;
        _originalUsername = displayUsername.value;
        usernameController.text = displayUsername.value;
        usernameText.value = displayUsername.value;
        print("🏆👤 Using SERVER username: ${displayUsername.value}");
      } else if (hasLocalUsername.value && localUsername.value.isNotEmpty) {
        displayUsername.value = localUsername.value;
        _originalUsername = displayUsername.value;
        usernameController.text = displayUsername.value;
        usernameText.value = displayUsername.value;
        print("🏆👤 Using LOCAL username: ${displayUsername.value}");
      } else {
        displayUsername.value = '';
        _originalUsername = '';
        usernameController.text = '';
        usernameText.value = '';
        print("🏆👤 No username available");
      }

      // ✅ FULL NAME PRIORITY: Server > Local > Empty
      if (hasServerFullName.value && serverFullName.value.isNotEmpty) {
        displayFullName.value = serverFullName.value;
        _originalFullName = displayFullName.value;
        fullNameController.text = displayFullName.value;
        fullNameText.value = displayFullName.value;
        print("🏆📝 Using SERVER full name: ${displayFullName.value}");
      } else if (hasLocalFullName.value && localFullName.value.isNotEmpty) {
        displayFullName.value = localFullName.value;
        _originalFullName = displayFullName.value;
        fullNameController.text = displayFullName.value;
        fullNameText.value = displayFullName.value;
        print("🏆📝 Using LOCAL full name: ${displayFullName.value}");
      } else {
        displayFullName.value = '';
        _originalFullName = '';
        fullNameController.text = '';
        fullNameText.value = '';
        print("🏆📝 No full name available");
      }

      // ✅ EMAIL PRIORITY: Server > Local > Empty
      if (hasServerEmail.value && serverEmail.value.isNotEmpty) {
        displayEmail.value = serverEmail.value;
        _originalEmail = displayEmail.value;
        emailController.text = displayEmail.value;
        emailText.value = displayEmail.value;
        print("🏆📧 Using SERVER email: ${displayEmail.value}");
      } else if (hasLocalEmail.value && localEmail.value.isNotEmpty) {
        displayEmail.value = localEmail.value;
        _originalEmail = displayEmail.value;
        emailController.text = displayEmail.value;
        emailText.value = displayEmail.value;
        print("🏆📧 Using LOCAL email: ${displayEmail.value}");
      } else {
        displayEmail.value = '';
        _originalEmail = '';
        emailController.text = '';
        emailText.value = '';
        print("🏆📧 No email available");
      }

      // ✅ Update local storage with latest data
      await _updateLocalStorageWithPriorityData();

      print("🏆 ✅ Final priority logic applied successfully");
      _debugPriorityState();

    } catch (e) {
      print("❌ Error applying final priority logic: $e");
    }
  }

  // ✅ NEW: Update local storage with priority data
  Future<void> _updateLocalStorageWithPriorityData() async {
    try {
      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString();

      if (userId == null) return;

      // Update comprehensive profile data in StorageService
      await StorageService.to.saveLocalProfileData(
        username: displayUsername.value,
        fullName: displayFullName.value,
        email: displayEmail.value,
        profileImageUrl: currentProfileImageUrl.value,
        localImagePath: localProfileImagePath.value,
        additionalData: {
          'user_id': userId,
          'synced_at': DateTime.now().toIso8601String(),
          'server_username': serverUsername.value,
          'local_username': localUsername.value,
          'server_full_name': serverFullName.value,
          'local_full_name': localFullName.value,
          'server_email': serverEmail.value,
          'local_email': localEmail.value,
          'has_server_data': hasServerUsername.value || hasServerFullName.value || hasServerEmail.value,
          'has_local_data': hasLocalUsername.value || hasLocalFullName.value || hasLocalEmail.value,
          'priority_source': _getPrioritySource(),
        },
      );

      // Update user data
      final currentUserData = StorageService.to.getUser() ?? {};
      currentUserData.addAll({
        'full_name': displayFullName.value,
        'unique_username': displayUsername.value,
        'username': displayUsername.value,
        'email': displayEmail.value,
        'profile_image': currentProfileImageUrl.value,
        'local_profile_image_path': localProfileImagePath.value,
      });

      await StorageService.to.saveUser(currentUserData);

      print("✅ Local storage updated with priority data");
    } catch (e) {
      print("❌ Error updating local storage with priority data: $e");
    }
  }

  // ✅ NEW: Get priority source for debugging
  String _getPrioritySource() {
    final sources = <String>[];

    if (hasServerUsername.value) sources.add('server_username');
    else if (hasLocalUsername.value) sources.add('local_username');

    if (hasServerFullName.value) sources.add('server_fullname');
    else if (hasLocalFullName.value) sources.add('local_fullname');

    if (hasServerEmail.value) sources.add('server_email');
    else if (hasLocalEmail.value) sources.add('local_email');

    return sources.join(',');
  }

  // ✅ NEW: Debug priority state
  void _debugPriorityState() {
    print("🐛 === PRIORITY STATE DEBUG ===");
    print("👤 USERNAME:");
    print("   Server: '${serverUsername.value}' (Has: ${hasServerUsername.value})");
    print("   Local: '${localUsername.value}' (Has: ${hasLocalUsername.value})");
    print("   Display: '${displayUsername.value}'");
    print("   Controller: '${usernameController.text}'");
    print("");
    print("📝 FULL NAME:");
    print("   Server: '${serverFullName.value}' (Has: ${hasServerFullName.value})");
    print("   Local: '${localFullName.value}' (Has: ${hasLocalFullName.value})");
    print("   Display: '${displayFullName.value}'");
    print("   Controller: '${fullNameController.text}'");
    print("");
    print("📧 EMAIL:");
    print("   Server: '${serverEmail.value}' (Has: ${hasServerEmail.value})");
    print("   Local: '${localEmail.value}' (Has: ${hasLocalEmail.value})");
    print("   Display: '${displayEmail.value}'");
    print("   Controller: '${emailController.text}'");
    print("");
    print("🏆 Priority Source: ${_getPrioritySource()}");
    print("🐛 === END PRIORITY STATE DEBUG ===");
  }

  // ✅ Extract server image URL from profile data (existing)
  String? _extractServerImageUrl(Map<String, dynamic> profileData) {
    final possibleImageFields = [
      'profile_image', 'profile_picture', 'avatar', 'image', 'photo', 'profile_photo'
    ];

    for (String field in possibleImageFields) {
      if (profileData[field] != null && profileData[field].toString().trim().isNotEmpty) {
        String imageUrl = profileData[field].toString().trim();
        if (imageUrl != 'null' && imageUrl != 'undefined') {
          print("🖼️ Server image found in field '$field': $imageUrl");
          return imageUrl;
        }
      }
    }
    return null;
  }

  // Process image URL to ensure it's absolute (existing)
  String _processImageUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;

    const String baseUrl = 'https://alliedtechnologies.cloud/clients/lupus_care/';
    if (url.startsWith('/')) {
      return '$baseUrl${url.substring(1)}';
    } else {
      return '$baseUrl$url';
    }
  }

  // ✅ ENHANCED: Fallback to cache loading with priority
  Future<void> _loadFromCache() async {
    print("🔄 Loading profile from cache with priority...");

    final userData = StorageService.to.getUser();
    if (userData != null) {
      // Load with priority logic
      await _loadLocalUsername(null, userData);
      await _loadLocalFullName(null, userData);
      await _loadLocalEmail(null, userData);

      // Apply final priority (will use local data since no server data)
      await _applyFinalPriorityLogic();

      // Load image from cache
      final bestImage = StorageService.to.getBestAvailableProfileImage();
      if (bestImage != null) {
        if (bestImage.startsWith('/') || !bestImage.startsWith('http')) {
          // Local file
          localProfileImagePath.value = bestImage;
          _originalLocalPath = bestImage;
        } else {
          // Network URL
          currentProfileImageUrl.value = bestImage;
          _originalImageUrl = bestImage;
        }
      }
    }
  }

  // ✅ ENHANCED: Get display image with priority: selected > local > server > default
  ImageProvider? get displayImage {
    if (selectedImage.value != null) {
      // Show the newly selected image
      return FileImage(selectedImage.value!);
    } else if (localProfileImagePath.value.isNotEmpty && File(localProfileImagePath.value).existsSync()) {
      // Show local saved image
      return FileImage(File(localProfileImagePath.value));
    } else if (currentProfileImageUrl.value.isNotEmpty && !imageLoadError.value) {
      // Show server image
      return NetworkImage(currentProfileImageUrl.value);
    } else {
      // Show default image
      return const AssetImage('assets/image/user.png');
    }
  }

  // ✅ ENHANCED: Get profile image widget with better error handling and priority
  Widget getProfileImageWidget({double size = 80}) {
    return Obx(() {
      // Priority 1: Newly selected image
      if (selectedImage.value != null) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: FileImage(selectedImage.value!),
              fit: BoxFit.cover,
            ),
          ),
        );
      }

      // Priority 2: Local saved image
      if (localProfileImagePath.value.isNotEmpty && File(localProfileImagePath.value).existsSync()) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: FileImage(File(localProfileImagePath.value)),
              fit: BoxFit.cover,
            ),
          ),
        );
      }

      // Priority 3: Server image
      if (currentProfileImageUrl.value.isNotEmpty) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle),
          child: ClipOval(
            child: Image.network(
              currentProfileImageUrl.value,
              width: size,
              height: size,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[300],
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                print("❌ Error loading server image: $error");
                imageLoadError.value = true;
                return _buildDefaultAvatar(size);
              },
            ),
          ),
        );
      }

      // Priority 4: Default avatar
      return _buildDefaultAvatar(size);
    });
  }

  // Build default avatar
  Widget _buildDefaultAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[300],
      ),
      child: Icon(
        Icons.person,
        size: size * 0.6,
        color: Colors.grey[600],
      ),
    );
  }

  // ✅ ENHANCED: Image picker with local storage
  Future<void> pickImageFromGallery() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        selectedImage.value = File(pickedFile.path);
        print("✅ Image selected from gallery: ${pickedFile.path}");

        // ✅ Immediately save locally for better UX
        final userData = StorageService.to.getUser();
        final userId = userData?['id']?.toString();
        if (userId != null) {
          final localPath = await StorageService.to.saveProfileImageLocally(
            selectedImage.value!,
            userId,
          );
          if (localPath != null) {
            print("📱 ✅ Image auto-saved locally: $localPath");
          }
        }
      }
    } catch (e) {
      print('Gallery error: $e');
      Get.snackbar(
        "Gallery Error",
        "Failed to pick image from gallery",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // ✅ ENHANCED: Camera picker with local storage
  Future<void> pickImageFromCamera() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        selectedImage.value = File(pickedFile.path);
        print("✅ Image captured from camera: ${pickedFile.path}");

        // ✅ Immediately save locally for better UX
        final userData = StorageService.to.getUser();
        final userId = userData?['id']?.toString();
        if (userId != null) {
          final localPath = await StorageService.to.saveProfileImageLocally(
            selectedImage.value!,
            userId,
          );
          if (localPath != null) {
            print("📱 ✅ Image auto-saved locally: $localPath");
          }
        }
      }
    } catch (e) {
      print('Camera error: $e');
      Get.snackbar(
        "Camera Error",
        "Failed to capture image from camera",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // ✅ ENHANCED: Save changes with local storage integration
  Future<void> saveChanges() async {
    print("=== ENHANCED SAVE CHANGES WITH PRIORITY LOGIC START ===");

    // Validate username first
    final usernameValidation = validateUsername(usernameController.text);
    if (usernameValidation != null) {
      print("❌ Username validation failed: $usernameValidation");
      Get.snackbar(
        "Validation Error",
        usernameValidation,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // Check if any changes were made
    // if (!hasChanges) {
    //   print("ℹ️ No changes detected");
    //   Get.snackbar(
    //     "No Changes",
    //     "No changes were made to save",
    //     snackPosition: SnackPosition.TOP,
    //   );
    //   return;
    // }

    // Validate full name
    final fullNameValidation = validateFullName(fullNameController.text);
    if (fullNameValidation != null) {
      print("❌ Full name validation failed: $fullNameValidation");
      Get.snackbar(
        "Validation Error",
        fullNameValidation,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // Validate email
    if (emailController.text.trim().isEmpty || !GetUtils.isEmail(emailController.text.trim())) {
      Get.snackbar(
        "Validation Error",
        "Please enter a valid email address",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    print("✅ All validations passed");

    isSaving.value = true;

    try {
      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString() ?? '';

      if (userId.isEmpty) {
        throw Exception("User ID not found");
      }

      String newProfileImageUrl = currentProfileImageUrl.value;
      String newLocalImagePath = localProfileImagePath.value;
      bool imageChanged = selectedImage.value != null;
      bool textFieldsChanged = hasTextFieldChanges;

      print("📊 Changes detected - Image: $imageChanged, Text: $textFieldsChanged");

      // ✅ STEP 1: Handle image upload if changed
      if (imageChanged) {
        print("🖼️ Starting image upload...");

        // Save locally first
        final localPath = await StorageService.to.saveProfileImageLocally(
          selectedImage.value!,
          userId,
        );

        if (localPath != null) {
          newLocalImagePath = localPath;
          localProfileImagePath.value = localPath;
          print("📱 ✅ Image saved locally: $localPath");
        }

        // Upload to server
        final uploadResponse = await _profileService.uploadUserProfile(
          userId: userId,
          uniqueUsername: usernameController.text.trim(),
          profileImage: selectedImage.value!,
        );

        if (uploadResponse['status'] == 'success') {
          if (uploadResponse['data']?['profile_image'] != null) {
            newProfileImageUrl = _processImageUrl(uploadResponse['data']['profile_image'].toString());
            currentProfileImageUrl.value = newProfileImageUrl;
            print("🌐 ✅ Image uploaded to server: $newProfileImageUrl");
          }
        } else {
          print("❌ Server upload failed, keeping local image");
          // Continue with local image even if server upload fails
        }
      }

      // ✅ STEP 2: Update profile details if text changed
      if (textFieldsChanged) {
        print("📝 Starting profile update...");
        final updateResponse = await _profileService.updateProfileDetails(
          userId: userId,
          fullName: fullNameController.text.trim(),
          uniqueUsername: usernameController.text.trim(),
          email: emailController.text.trim(),
        );

        if (updateResponse['status'] != 'success') {
          print("❌ Profile update failed: ${updateResponse['message']}");
          throw Exception(updateResponse['message'] ?? "Failed to update profile details");
        }
      }

      // ✅ STEP 3: Update priority state with new values
      await _updatePriorityStateAfterSave();

      // ✅ STEP 4: Update local storage with all new data
      await StorageService.to.saveLocalProfileData(
        username: usernameController.text.trim(),
        fullName: fullNameController.text.trim(),
        email: emailController.text.trim(),
        profileImageUrl: newProfileImageUrl,
        localImagePath: newLocalImagePath,
        additionalData: {
          'user_id': userId,
          'updated_at': DateTime.now().toIso8601String(),
          'last_edit': DateTime.now().toIso8601String(),
          'saved_from_edit': true,
        },
      );

      // ✅ STEP 5: Update user data in storage
      final currentUserData = StorageService.to.getUser() ?? {};
      currentUserData.addAll({
        'full_name': fullNameController.text.trim(),
        'unique_username': usernameController.text.trim(),
        'username': usernameController.text.trim(),
        'email': emailController.text.trim(),
        'profile_image': newProfileImageUrl,
        'local_profile_image_path': newLocalImagePath,
      });

      await StorageService.to.saveUser(currentUserData);

      // ✅ STEP 6: Update controller state
      _originalFullName = fullNameController.text.trim();
      _originalUsername = usernameController.text.trim();
      _originalEmail = emailController.text.trim();
      _originalImageUrl = newProfileImageUrl;
      _originalLocalPath = newLocalImagePath;

      fullNameText.value = _originalFullName;
      usernameText.value = _originalUsername;
      emailText.value = _originalEmail;

      selectedImage.value = null; // Clear selected image
      imageLoadError.value = false;

      print("✅ Controller state updated");

      // ✅ STEP 7: Show success message
      String successMessage = "Profile updated successfully!";
      if (imageChanged && textFieldsChanged) {
        successMessage = "Profile and image updated successfully!";
      } else if (imageChanged) {
        successMessage = "Profile image updated successfully!";
      } else if (textFieldsChanged) {
        successMessage = "Profile details updated successfully!";
      }

      Get.snackbar(
        "Success",
        successMessage,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 2),
      );

      // ✅ STEP 8: Refresh other controllers
      _refreshOtherControllers();

      print("✅ Enhanced profile save with priority logic completed successfully");

    } catch (e) {
      print("❌ Error during enhanced save: $e");

      String errorMessage = e.toString();
      if (errorMessage.contains('Exception: ')) {
        errorMessage = errorMessage.split('Exception: ')[1];
      }

      Get.snackbar(
        "Update Failed",
        errorMessage,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
    } finally {
      isSaving.value = false;
    }

    print("=== ENHANCED SAVE CHANGES WITH PRIORITY LOGIC END ===");
  }

  // ✅ NEW: Update priority state after successful save
  Future<void> _updatePriorityStateAfterSave() async {
    try {
      print("🔄 Updating priority state after save...");

      // After successful save, the edited values become the new "server" values
      serverUsername.value = usernameController.text.trim();
      serverFullName.value = fullNameController.text.trim();
      serverEmail.value = emailController.text.trim();

      hasServerUsername.value = serverUsername.value.isNotEmpty;
      hasServerFullName.value = serverFullName.value.isNotEmpty;
      hasServerEmail.value = serverEmail.value.isNotEmpty;

      // Update display values
      displayUsername.value = serverUsername.value;
      displayFullName.value = serverFullName.value;
      displayEmail.value = serverEmail.value;

      print("✅ Priority state updated after save");
    } catch (e) {
      print("❌ Error updating priority state after save: $e");
    }
  }

  // Validation methods (existing)
  String? validateFullName(String value) {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) return "Full name is required";
    if (trimmedValue.length < FULL_NAME_MIN_LENGTH) return "Full name must be at least $FULL_NAME_MIN_LENGTH characters long";
    if (trimmedValue.length > FULL_NAME_MAX_LENGTH) return "Full name cannot exceed $FULL_NAME_MAX_LENGTH characters";
    return null;
  }

  String? validateUsername(String value) {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) return "Username is required";
    if (trimmedValue.length < USERNAME_MIN_LENGTH) return "Username must be at least $USERNAME_MIN_LENGTH characters long";
    if (trimmedValue.length > USERNAME_MAX_LENGTH) return "Username cannot exceed $USERNAME_MAX_LENGTH characters";
    if (!RegExp(r'^[a-zA-Z]').hasMatch(trimmedValue)) return "Username must start with a letter";
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_.]*$').hasMatch(trimmedValue)) return "Username cannot contain letters, numbers, underscore (_), and dot (.)";
    if (trimmedValue.contains(' ')) return "Username cannot contain spaces";
    if (trimmedValue.contains('..') || trimmedValue.contains('__')) return "Username cannot contain consecutive dots or underscores";
    if (trimmedValue.endsWith('.') || trimmedValue.endsWith('_')) return "Username cannot end with dot or underscore";
    return null;
  }

  // ✅ ENHANCED: Check for changes including local data
  bool get hasChanges {
    return selectedImage.value != null ||
        fullNameText.value.trim() != _originalFullName ||
        usernameText.value.trim() != _originalUsername ||
        emailText.value.trim() != _originalEmail;
  }

  bool get hasTextFieldChanges {
    return fullNameText.value.trim() != _originalFullName ||
        usernameText.value.trim() != _originalUsername ||
        emailText.value.trim() != _originalEmail;
  }

  // Character count getters
  int get fullNameRemainingChars => FULL_NAME_MAX_LENGTH - fullNameText.value.length;
  int get usernameRemainingChars => USERNAME_MAX_LENGTH - usernameText.value.length;

  // Reactive validation getters
  String? get fullNameValidationError => validateFullName(fullNameText.value);
  String? get usernameValidationError => validateUsername(usernameText.value);

  // Helper methods
  void _refreshOtherControllers() {
    try {
      if (Get.isRegistered<HomeController>()) {
        final homeController = Get.find<HomeController>();
        print("🔄 Refreshing HomeController after profile update");
        homeController.refreshProfile();
      }
    } catch (e) {
      print("❌ Error refreshing other controllers: $e");
    }
  }

  // ✅ NEW: Force refresh with priority logic
  Future<void> forceRefreshProfile() async {
    print("🔄 Force refreshing profile with priority logic...");
    imageLoadError.value = false;
    await loadCurrentProfile();
    _debugPriorityState();
  }

  // ✅ NEW: Test priority logic
  Future<void> testPriorityLogic() async {
    print("🧪 === TESTING PRIORITY LOGIC ===");

    print("🧪 Current Controller Values:");
    print("- Username Controller: '${usernameController.text}'");
    print("- Full Name Controller: '${fullNameController.text}'");
    print("- Email Controller: '${emailController.text}'");

    _debugPriorityState();

    // Test local storage
    final localData = StorageService.to.getLocalProfileData();
    final userData = StorageService.to.getUser();

    print("🧪 Storage Data:");
    print("- Local Profile Data: ${localData != null ? 'EXISTS' : 'NULL'}");
    if (localData != null) {
      print("  * Username: '${localData['username'] ?? 'null'}'");
      print("  * Full Name: '${localData['full_name'] ?? 'null'}'");
      print("  * Email: '${localData['email'] ?? 'null'}'");
    }

    print("- User Data: ${userData != null ? 'EXISTS' : 'NULL'}");
    if (userData != null) {
      print("  * Username: '${userData['username'] ?? 'null'}'");
      print("  * Unique Username: '${userData['unique_username'] ?? 'null'}'");
      print("  * Full Name: '${userData['full_name'] ?? 'null'}'");
      print("  * Email: '${userData['email'] ?? 'null'}'");
    }

    print("🧪 === END PRIORITY LOGIC TEST ===");
  }

  // ✅ ENHANCED: Debug profile image state
  void debugProfileImageState() {
    print("🐛 === ENHANCED PROFILE IMAGE DEBUG ===");
    print("🖼️ Selected Image: ${selectedImage.value?.path ?? 'null'}");
    print("📱 Local Image Path: '${localProfileImagePath.value}'");
    print("🌐 Server Image URL: '${currentProfileImageUrl.value}'");
    print("🖼️ Image Load Error: ${imageLoadError.value}");
    print("🖼️ Display Image Type: ${displayImage.runtimeType}");
    print("📱 Local Image Exists: ${localProfileImagePath.value.isNotEmpty ? File(localProfileImagePath.value).existsSync() : false}");

    final userData = StorageService.to.getUser();
    if (userData != null) {
      print("💾 Storage Profile Image: '${userData['profile_image']}'");
      print("💾 Storage Local Path: '${userData['local_profile_image_path']}'");
    }

    final localData = StorageService.to.getLocalProfileData();
    if (localData != null) {
      print("📱 Local Profile Data Image: '${localData['profile_image_url']}'");
      print("📱 Local Profile Data Path: '${localData['local_image_path']}'");
    }

    print("🐛 === END ENHANCED IMAGE DEBUG ===");
  }

  // ✅ ENHANCED: Debug current profile state
  void debugCurrentProfile() {
    print("🐛 === ENHANCED PROFILE DEBUG WITH PRIORITY ===");
    print("📝 Controllers: ${fullNameController.text} | ${usernameController.text} | ${emailController.text}");
    print("📝 Reactive: ${fullNameText.value} | ${usernameText.value} | ${emailText.value}");
    print("📝 Originals: $_originalFullName | $_originalUsername | $_originalEmail");
    print("🖼️ Original Image URL: $_originalImageUrl");
    print("📱 Original Local Path: $_originalLocalPath");
    print("🔄 Has Changes: $hasChanges");
    debugProfileImageState();
    _debugPriorityState();
    print("🐛 === END ENHANCED PROFILE DEBUG ===");
  }
}