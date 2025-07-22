import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lupus_care/helper/storage_service.dart';
import 'package:lupus_care/views/chat_screen/chat_controller.dart';
import 'package:lupus_care/views/chat_screen/firebase/firebase_model.dart';
import 'package:lupus_care/views/chat_screen/notification_api_service.dart';
import 'package:lupus_care/views/chat_screen/notification_service.dart';
import 'package:lupus_care/views/group_chat/edit_group_dialog.dart';
import 'package:lupus_care/views/group_chat/leave_group_dialog.dart';
import 'package:lupus_care/views/view_member/view_member_screen.dart';
import 'package:lupus_care/constant/images.dart';
import 'dart:math' as math;

class GroupController extends GetxController {
  // Use proper reactive variables
  final RxString _groupName = 'Lupus Recovery'.obs;
  final RxInt _memberCount = 44.obs;
  final RxString _groupId = ''.obs;
  final RxString _actualGroupName = ''.obs;
  final RxString _groupImage = ''.obs;

  // Store complete group data for better member access
  final Rx<Map<String, dynamic>?> _groupData = Rx<Map<String, dynamic>?>(null);

  // Image picker and loading states
  final ImagePicker _picker = ImagePicker();
  final RxBool isUploadingImage = false.obs;
  final RxString selectedImagePath = ''.obs;
  final RxDouble uploadProgress = 0.0.obs;
  final RxString uploadStatus = ''.obs;

  // Flag to prevent re-initialization
  bool _isInitialized = false;

  // Getters that return reactive values
  String get groupName => _actualGroupName.value.isNotEmpty ? _actualGroupName.value : _groupName.value;
  int get memberCount => _memberCount.value;
  String get groupId => _groupId.value;
  String get groupImage => _groupImage.value;

  Map<String, dynamic>? get groupData => _groupData.value;

  // Reactive getters for Obx to work properly
  RxString get reactiveGroupName => _actualGroupName.value.isNotEmpty ? _actualGroupName : _groupName;
  RxInt get reactiveMemberCount => _memberCount;
  RxString get reactiveGroupImage => _groupImage;

  // Enhanced initialization method
  void initializeGroupData({
    required String groupId,
    required String groupName,
    int? memberCount,
    String? groupImage,
    Map<String, dynamic>? fullGroupData,
    bool forceReinit = false,
  }) {
    if (_isInitialized && !forceReinit && _groupId.value == groupId) {
      print("⚠️ GroupController already initialized for this group, skipping");
      return;
    }

    _groupId.value = groupId;
    _actualGroupName.value = groupName;
    _groupName.value = groupName;
    _groupImage.value = groupImage ?? '';

    if (memberCount != null) {
      _memberCount.value = memberCount;
    }

    if (fullGroupData != null) {
      _groupData.value = fullGroupData;

      if (memberCount == null) {
        final members = fullGroupData['members'] ??
            fullGroupData['participants'] ??
            fullGroupData['users'] ?? [];

        if (members is List) {
          _memberCount.value = members.length;
        }
      }

      if (groupImage == null) {
        _groupImage.value = fullGroupData['groupImage']?.toString() ??
            fullGroupData['group_image']?.toString() ??
            fullGroupData['image']?.toString() ?? '';
      }
    }

    _isInitialized = true;

    _setupGroupImageChangeListener();

    print("🎮 GroupController initialized with real-time updates");
    print("🎮 GroupController initialized:");
    print("   Group ID: '${_groupId.value}'");
    print("   Group Name: '${_actualGroupName.value}'");
    print("   Group Image: '${_groupImage.value}'");
    print("   Member Count: ${_memberCount.value}");

    update();
  }

  // ENHANCED: Check Firebase prerequisites before any operation
  Future<bool> _checkFirebasePrerequisites() async {
    try {
      print('🔍 Checking Firebase prerequisites...');

      // 1. Check if Firebase is initialized
      try {
        final app = Firebase.app();
        print('✅ Firebase app initialized: ${app.name}');
      } catch (e) {
        print('❌ Firebase not initialized: $e');
        _showErrorSnackbar('Firebase not properly initialized');
        return false;
      }

      // 2. Check and setup Firebase Auth (anonymous is fine)
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        print('⚠️ No Firebase Auth user, attempting anonymous sign-in...');
        try {
          final UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
          currentUser = userCredential.user;
          print('✅ Anonymous Firebase Auth successful: ${currentUser?.uid}');
        } catch (authError) {
          print('❌ Anonymous Firebase Auth failed: $authError');
          _showErrorSnackbar('Authentication required');
          return false;
        }
      } else {
        print('✅ Firebase Auth user exists: ${currentUser.uid}');
      }

      // 3. Test Firestore connection only
      try {
        await FirebaseFirestore.instance
            .collection('chats')
            .limit(1)
            .get(GetOptions(source: Source.server));
        print('✅ Firestore connection working');
      } catch (firestoreError) {
        print('❌ Firestore connection failed: $firestoreError');
        _showErrorSnackbar('Database connection failed');
        return false;
      }

      print('✅ All Firebase prerequisites met');
      return true;

    } catch (e) {
      print('❌ Error checking Firebase prerequisites: $e');
      _showErrorSnackbar('Firebase service check failed');
      return false;
    }
  }

  // ENHANCED: Pick image from gallery with better error handling
  Future<void> pickImageFromGallery() async {
    try {
      print('📱 Opening gallery for group image...');
      uploadStatus.value = 'Opening gallery...';

      // Check prerequisites first
      if (!await _checkFirebasePrerequisites()) {
        return;
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        selectedImagePath.value = image.path;
        print('✅ Image selected from gallery: ${image.path}');

        // Validate the selected image
        if (await _validateImageFile(File(image.path))) {
          await _processAndUploadImageToFirebase(File(image.path));
        }
      } else {
        print('❌ No image selected from gallery');
        uploadStatus.value = 'No image selected';
      }
    } catch (e) {
      print('❌ Error picking image from gallery: $e');
      uploadStatus.value = 'Error selecting image';
      Get.snackbar(
        'Error',
        'Failed to select image from gallery: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,

      );
    }
  }

  // ENHANCED: Pick image from camera with better error handling
  Future<void> pickImageFromCamera() async {
    try {
      print('📷 Opening camera for group image...');
      uploadStatus.value = 'Opening camera...';

      // Check prerequisites first
      if (!await _checkFirebasePrerequisites()) {
        return;
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        selectedImagePath.value = image.path;
        print('✅ Image captured from camera: ${image.path}');

        // Validate the captured image
        if (await _validateImageFile(File(image.path))) {
          await _processAndUploadImageToFirebase(File(image.path));
        }
      } else {
        print('❌ No image captured from camera');
        uploadStatus.value = 'No image captured';
      }
    } catch (e) {
      print('❌ Error capturing image from camera: $e');
      uploadStatus.value = 'Error capturing image';
      Get.snackbar(
        'Error',
        'Failed to capture image from camera: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,

      );
    }
  }

  // ENHANCED: Image validation with smaller size limit
  Future<bool> _validateImageFile(File imageFile) async {
    try {
      print('🔍 Validating image file...');
      uploadStatus.value = 'Validating image...';

      // Check if file exists
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      // Check file size (2MB limit for Firestore efficiency)
      final fileSize = await imageFile.length();
      print('📊 File size: $fileSize bytes');

      if (fileSize == 0) {
        throw Exception('Image file is empty');
      }

      if (fileSize > 2 * 1024 * 1024) { // 2MB limit
        throw Exception('Image file is too large (max 2MB for database storage)');
      }

      // Check if it's a valid image format
      final bytes = await imageFile.readAsBytes();
      if (bytes.length < 4) {
        throw Exception('Invalid image file format');
      }

      // Check image headers
      final header = bytes.take(4).toList();
      bool isValidImage = false;

      // JPEG
      if (header[0] == 0xFF && header[1] == 0xD8) {
        isValidImage = true;
        print('✅ Valid JPEG image detected');
      }
      // PNG
      else if (header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47) {
        isValidImage = true;
        print('✅ Valid PNG image detected');
      }

      if (!isValidImage) {
        throw Exception('Unsupported image format. Please use JPEG or PNG.');
      }

      print('✅ Image validation successful');
      return true;

    } catch (e) {
      print('❌ Image validation failed: $e');
      uploadStatus.value = 'Validation failed';

      String userMessage = 'Invalid image file';
      if (e.toString().contains('does not exist')) {
        userMessage = 'Image file not found. Please try again.';
      } else if (e.toString().contains('empty')) {
        userMessage = 'Selected image is empty. Please choose another image.';
      } else if (e.toString().contains('too large')) {
        userMessage = 'Image is too large. Please choose a smaller image (max 2MB).';
      } else if (e.toString().contains('format')) {
        userMessage = 'Unsupported image format. Please use JPEG or PNG.';
      }

      _showErrorSnackbar(userMessage);
      return false;
    }
  }


  Future<void> sendGroupCreationNotification(List<String> memberIds) async {
    try {
      print('📢 Sending group creation notifications...');

      if (_groupId.value.isEmpty || memberIds.isEmpty) {
        print('⚠️ No group ID or members for notification');
        return;
      }

      // Get current user data
      final userData = StorageService.to.getUser();
      if (userData == null) {
        print('❌ No user data for group creation notification');
        return;
      }

      final currentUserId = userData['id']?.toString() ?? '';
      if (currentUserId.isEmpty) {
        print('❌ No current user ID for group creation notification');
        return;
      }

      final creatorName = userData['full_name']?.toString() ?? 'Someone';
      final groupName = _actualGroupName.value.isNotEmpty ? _actualGroupName.value : _groupName.value;

      // Create notification message
      final notificationMessage = '$creatorName added you to the group "$groupName"';

      // Extract API group ID
      final apiGroupId = _extractApiGroupIdForNotification();
      if (apiGroupId.isEmpty) {
        print('❌ Could not determine API group ID for notification');
        return;
      }

      print('📤 Sending group creation notification...');
      print('   Creator ID: $currentUserId');
      print('   Group ID: $apiGroupId');
      print('   Members: ${memberIds.length}');
      print('   Message: $notificationMessage');

      // Send group notification via API
      final result = await NotificationApiService.sendGroupChatNotification(
        senderId: currentUserId,
        groupId: apiGroupId,
        message: notificationMessage,
      );

      if (result['success'] == true) {
        print('✅ Group creation notification sent successfully');
      } else {
        print('❌ Group creation notification failed: ${result['message']}');
      }

      // Optional: Send individual notifications to each member
      await _sendIndividualGroupCreationNotifications(
        creatorId: currentUserId,
        creatorName: creatorName,
        groupName: groupName,
        memberIds: memberIds,
      );

    } catch (e) {
      print('❌ Error sending group creation notification: $e');
    }
  }

  /// Send individual notifications to each member about group creation
  Future<void> _sendIndividualGroupCreationNotifications({
    required String creatorId,
    required String creatorName,
    required String groupName,
    required List<String> memberIds,
  }) async {
    try {
      print('📤 Sending individual group creation notifications...');

      final notificationMessage = '$creatorName added you to the group "$groupName"';

      // Remove creator from notification list (don't notify themselves)
      final membersToNotify = memberIds.where((id) => id != creatorId).toList();

      if (membersToNotify.isEmpty) {
        print('⚠️ No members to notify individually');
        return;
      }

      // Send individual notifications
      final results = await NotificationApiService.sendMultiplePersonalNotifications(
        senderId: creatorId,
        receiverIds: membersToNotify,
        message: notificationMessage,
      );

      int successCount = 0;
      int failedCount = 0;

      for (var result in results) {
        if (result['success'] == true) {
          successCount++;
        } else {
          failedCount++;
          print('❌ Failed to notify member ${result['receiver_id']}: ${result['message']}');
        }
      }

      print('📊 Individual notifications result: $successCount successful, $failedCount failed');

    } catch (e) {
      print('❌ Error sending individual group creation notifications: $e');
    }
  }

  Future<void> sendGroupUpdateNotification(String updateType, {String? additionalInfo}) async {
    try {
      print('📢 Sending group update notification...');
      print('   Group ID: ${_groupId.value}');
      print('   Update Type: $updateType');
      print('   Additional Info: $additionalInfo');

      if (_groupId.value.isEmpty) {
        print('⚠️ No group ID for update notification');
        return;
      }

      // Get current user data
      final userData = StorageService.to.getUser();
      if (userData == null) {
        print('❌ No user data for group update notification');
        return;
      }

      final currentUserId = userData['id']?.toString() ?? '';
      if (currentUserId.isEmpty) {
        print('❌ No current user ID for group update notification');
        return;
      }

      final updaterName = userData['full_name']?.toString() ?? 'Someone';
      final groupName = _actualGroupName.value.isNotEmpty ? _actualGroupName.value : _groupName.value;

      // Create notification message based on update type
      String notificationMessage;
      switch (updateType) {
        case 'name_changed':
          notificationMessage = '$updaterName changed the group name to "$groupName"';
          break;
        case 'image_updated':
          notificationMessage = '$updaterName updated the group image';
          break;
        case 'description_updated':
          notificationMessage = '$updaterName updated the group description';
          break;
        case 'member_added':
          notificationMessage = '$updaterName added ${additionalInfo ?? 'a member'} to the group';
          break;
        case 'member_removed':
          notificationMessage = '$updaterName removed ${additionalInfo ?? 'a member'} from the group';
          break;
        default:
          notificationMessage = '$updaterName updated the group';
      }

      // Get API group ID with enhanced extraction
      final apiGroupId = _extractApiGroupIdForNotification();

      print('📤 Sending group update notification...');
      print('   Updater ID: $currentUserId');
      print('   API Group ID: $apiGroupId');
      print('   Update Type: $updateType');
      print('   Message: $notificationMessage');

      // Send notification using the enhanced method
      final result = await NotificationApiService.sendGroupChatNotification(
        senderId: currentUserId,
        groupId: apiGroupId,
        message: notificationMessage,
      );

      if (result['success'] == true) {
        print('✅ Group update notification sent successfully');
        print('✅ Response: ${result['message']}');
      } else {
        print('❌ Group update notification failed');
        print('❌ Error: ${result['message']}');
        print('❌ Request details: ${result['request_details']}');
      }

    } catch (e) {
      print('❌ Error sending group update notification: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }



  Future<Map<String, dynamic>> _sendEnhancedGroupNotification({
    required String senderId,
    required String groupId,
    required String message,
  }) async {
    try {
      print('📤 Enhanced group notification...');

      // Clean the IDs to ensure they're numeric (API requirement)
      String cleanSenderId = senderId;
      String cleanGroupId = groupId;

      // Remove any prefixes from sender ID
      if (cleanSenderId.startsWith('app_user_')) {
        cleanSenderId = cleanSenderId.replaceFirst('app_user_', '');
      }

      // Extract numeric part from group ID if needed
      if (!RegExp(r'^\d+$').hasMatch(cleanGroupId)) {
        final numericMatch = RegExp(r'\d+').firstMatch(cleanGroupId);
        if (numericMatch != null) {
          cleanGroupId = numericMatch.group(0)!;
        }
      }

      print('📤 Cleaned IDs - Sender: $cleanSenderId, Group: $cleanGroupId');

      // Get authentication
      final userData = StorageService.to.getUser();
      final token = StorageService.to.getToken();

      if (userData == null || token == null) {
        return {
          'success': false,
          'error_message': 'No authentication data available',
        };
      }

      // Prepare the request
      final request = http.MultipartRequest('POST', Uri.parse('https://alliedtechnologies.cloud/clients/lupus_care/api/v1/user.php'));

      // Add form fields
      request.fields.addAll({
        'request': 'send_group_chat_notification',
        'sender_id': cleanSenderId,
        'group_id': cleanGroupId,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';


      print('📤 Sending request with fields group: ${request.fields}');

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Request timed out after 30 seconds'),
      );

      // Get response
      final responseBody = await streamedResponse.stream.bytesToString();

      print('📥 Response received:');
      print('   Status Code: ${streamedResponse.statusCode}');
      print('   Response Body: $responseBody');

      // Parse response
      bool success = false;
      Map<String, dynamic> responseData = {};

      if (streamedResponse.statusCode == 200) {
        try {
          responseData = json.decode(responseBody);
          success = responseData['status'] == 'success' ||
              responseData['success'] == true ||
              responseData['message']?.toString().toLowerCase().contains('sent') == true;
        } catch (e) {
          // Handle non-JSON responses
          success = responseBody.toLowerCase().contains('success') ||
              responseBody.toLowerCase().contains('sent') ||
              responseBody.toLowerCase().contains('notification');
        }
      }

      final result = {
        'success': success,
        'status_code': streamedResponse.statusCode,
        'response_body': responseBody,
        'response_data': responseData,
        'error_message': success ? null : (responseData['message'] ?? 'Unknown error'),
        'request_details': {
          'sender_id': cleanSenderId,
          'group_id': cleanGroupId,
          'message_preview': message.length > 50 ? '${message.substring(0, 50)}...' : message,
        },
      };

      return result;

    } catch (e) {
      print('❌ Enhanced notification error: $e');
      return {
        'success': false,
        'error_message': 'Network or processing error: $e',
      };
    }
  }

  Future<void> debugGroupNotificationSystem() async {
    try {
      print('🔍 =================== GROUP NOTIFICATION DEBUG ===================');

      // Check current state
      print('📊 Current State:');
      print('   Group ID: ${_groupId.value}');
      print('   Group Name: ${_actualGroupName.value}');
      print('   Group Data: ${_groupData.value?.keys}');

      // Check user data
      final userData = StorageService.to.getUser();
      print('👤 User Data:');
      print('   Available: ${userData != null}');
      print('   User ID: ${userData?['id']}');
      print('   Full Name: ${userData?['full_name']}');

      // Check token
      final token = StorageService.to.getToken();
      print('🔑 Token: ${token != null ? 'Available' : 'Missing'}');

      // Test API group ID extraction
      final apiGroupId = _extractApiGroupIdForNotification();
      print('🆔 Extracted API Group ID: $apiGroupId');

      // Test notification sending
      if (userData != null && token != null && apiGroupId.isNotEmpty) {
        print('🧪 Testing notification...');

        final result = await NotificationApiService.sendGroupChatNotification(
          senderId: userData['id'].toString(),
          groupId: apiGroupId,
          message: 'Test notification from debug system at ${DateTime.now()}',
        );

        print('📊 Test Result:');
        print('   Success: ${result['success']}');
        print('   Message: ${result['message']}');
        print('   Status Code: ${result['status_code']}');

        if (result['success'] != true) {
          print('❌ Test failed - Response: ${result['raw_response']}');
        }
      } else {
        print('❌ Cannot test - missing required data');
      }

      print('🔍 =================== END DEBUG ===================');

    } catch (e) {
      print('❌ Error in debug: $e');
    }
  }

// DEBUGGING: Test your group notification immediately
  Future<void> testGroupNotification() async {
    try {
      print('🧪 Testing group notification...');

      if (_groupId.value.isEmpty) {
        print('❌ No group selected for testing');
        return;
      }

      // Get current user data
      final userData = StorageService.to.getUser();
      if (userData == null) {
        print('❌ No user data available');
        return;
      }

      final currentUserId = userData['id']?.toString() ?? '';
      if (currentUserId.isEmpty) {
        print('❌ No user ID available');
        return;
      }

      final testMessage = 'Test group notification at ${DateTime.now().toLocal()}';

      print('🧪 Testing with:');
      print('   User ID: $currentUserId');
      print('   Group ID: ${_groupId.value}');
      print('   Message: $testMessage');

      final result = await _sendEnhancedGroupNotification(
        senderId: currentUserId,
        groupId: _groupId.value,
        message: testMessage,
      );

      if (result['success'] == true) {
        Get.snackbar('Test Success', 'Group notification API test passed!',
            backgroundColor: Colors.green, colorText: Colors.white);
        print('✅ Group notification API test successful');
      } else {
        Get.snackbar('Test Failed', 'Group notification API test failed: ${result['error_message']}',
            backgroundColor: Colors.red, colorText: Colors.white);
        print('❌ Group notification API test failed: ${result['error_message']}');

        // Print debug info
        print('🔍 Debug Info:');
        print('   Status Code: ${result['status_code']}');
        print('   Response Body: ${result['response_body']}');
        print('   Request Details: ${result['request_details']}');
      }

    } catch (e) {
      print('❌ Error testing group notification API: $e');
      Get.snackbar('Test Error', 'Group notification API test error: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  String _extractApiGroupIdForNotification() {
    print('🔍 GroupController: Extracting API group ID for notification');
    print('   Group ID: ${_groupId.value}');
    print('   Group Data available: ${_groupData.value != null}');

    // Method 1: Check group data for API mapping
    if (_groupData.value != null) {
      final groupData = _groupData.value!;
      print('   Checking group data fields...');

      // Try different possible field names for API group ID
      final possibleApiIdFields = [
        'apiGroupId',
        'api_group_id',
        'backend_group_id',
        'group_id',
        'id',
        'remote_id',
        'server_id'
      ];

      for (String field in possibleApiIdFields) {
        final value = groupData[field]?.toString();
        if (value != null && value.isNotEmpty && value != 'null') {
          print('✅ Found API group ID in field "$field": $value');
          return value;
        }
      }
    }

    // Method 2: Check if current group ID is already numeric
    final currentGroupId = _groupId.value;
    if (currentGroupId.isNotEmpty) {
      // If it's already numeric, use it
      if (RegExp(r'^\d+$').hasMatch(currentGroupId)) {
        print('✅ Group ID is already numeric: $currentGroupId');
        return currentGroupId;
      }

      // Try to extract numeric part
      final numericMatch = RegExp(r'\d+').firstMatch(currentGroupId);
      if (numericMatch != null) {
        final numericId = numericMatch.group(0)!;
        print('✅ Extracted numeric part: $numericId');
        return numericId;
      }
    }

    // Method 3: Generate consistent numeric ID from Firebase group ID
    if (currentGroupId.isNotEmpty) {
      try {
        final hashCode = currentGroupId.hashCode.abs();
        final generatedId = (hashCode % 99999999).toString();
        print('🔄 Generated numeric ID from hash: $generatedId');

        // Store this mapping for future use
        if (_groupData.value != null) {
          _groupData.value!['generated_api_id'] = generatedId;
        }

        return generatedId;
      } catch (e) {
        print('❌ Error generating ID from hash: $e');
      }
    }

    // Fallback: Use a default ID (this should rarely happen)
    print('⚠️ Using fallback group ID: 1');
    return '1';
  }



  Future<void> sendGroupLeaveNotification(String leavingUserId, String leavingUserName) async {
    try {
      print('📢 Sending group leave notification...');

      if (_groupId.value.isEmpty) {
        print('⚠️ No group ID for leave notification');
        return;
      }

      final groupName = _actualGroupName.value.isNotEmpty ? _actualGroupName.value : _groupName.value;
      final notificationMessage = '$leavingUserName left the group "$groupName"';

      // Extract API group ID
      final apiGroupId = _extractApiGroupIdForNotification();
      if (apiGroupId.isEmpty) {
        print('❌ Could not determine API group ID for leave notification');
        return;
      }

      print('📤 Sending group leave notification...');
      print('   Leaving User ID: $leavingUserId');
      print('   Group ID: $apiGroupId');
      print('   Message: $notificationMessage');

      // Send group notification via API (using system as sender)
      final result = await NotificationApiService.sendGroupChatNotification(
        senderId: leavingUserId,
        groupId: apiGroupId,
        message: notificationMessage,
      );

      if (result['success'] == true) {
        print('✅ Group leave notification sent successfully');
      } else {
        print('❌ Group leave notification failed: ${result['message']}');
      }

    } catch (e) {
      print('❌ Error sending group leave notification: $e');
    }
  }


  Future<void> testGroupNotificationApi() async {
    try {
      print('🧪 Testing group notification API...');

      if (_groupId.value.isEmpty) {
        Get.snackbar('Test Failed', 'No group selected for testing',
            backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }

      // Get current user data
      final userData = StorageService.to.getUser();
      if (userData == null) {
        Get.snackbar('Test Failed', 'No user data available',
            backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }

      final currentUserId = userData['id']?.toString() ?? '';
      if (currentUserId.isEmpty) {
        Get.snackbar('Test Failed', 'No user ID available',
            backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }

      final apiGroupId = _extractApiGroupIdForNotification();
      final testMessage = 'Test group notification at ${DateTime.now().toLocal()}';

      print('🧪 Testing with:');
      print('   Sender ID: $currentUserId');
      print('   Group ID: $apiGroupId');
      print('   Message: $testMessage');

      final result = await NotificationApiService.sendGroupChatNotification(
        senderId: currentUserId,
        groupId: apiGroupId,
        message: testMessage,
      );

      if (result['success'] == true) {
        Get.snackbar('Test Success', 'Group notification API test passed!',
            backgroundColor: Colors.green, colorText: Colors.white);
        print('✅ Group notification API test successful');
      } else {
        Get.snackbar('Test Failed', 'Group notification API test failed: ${result['message']}',
            backgroundColor: Colors.red, colorText: Colors.white);
        print('❌ Group notification API test failed: ${result['message']}');
      }

    } catch (e) {
      print('❌ Error testing group notification API: $e');
      Get.snackbar('Test Error', 'Group notification API test error: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }


  void updateGroupNameWithNotification(String newName) {
    if (newName.isNotEmpty && newName.trim() != groupName) {
      print("🔄 Updating group name with notification from '${groupName}' to '${newName.trim()}'");

      final oldName = groupName;

      _groupName.value = newName.trim();
      _actualGroupName.value = newName.trim();

      if (_groupData.value != null) {
        _groupData.value!['name'] = newName.trim();
        _groupData.refresh();
      }

      // Send notification about name change
      sendGroupUpdateNotification('name_changed');

      try {
        if (Get.isRegistered<ChatController>()) {
          final chatController = Get.find<ChatController>();
          chatController.refreshChats();
          chatController.update();
        }
      } catch (e) {
        print("⚠️ Could not update ChatController: $e");
      }

      update();

      Get.snackbar(
        'Group Updated',
        'Group name has been updated successfully',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
  }


  void updateGroupName(String newName) {
    if (newName.isNotEmpty && newName.trim() != groupName) {
      print("🔄 Updating group name from '${groupName}' to '${newName.trim()}'");

      _groupName.value = newName.trim();
      _actualGroupName.value = newName.trim();

      if (_groupData.value != null) {
        _groupData.value!['name'] = newName.trim();
        _groupData.refresh();
      }

      try {
        if (Get.isRegistered<ChatController>()) {
          final chatController = Get.find<ChatController>();
          chatController.refreshChats();
          chatController.update();
        }
      } catch (e) {
        print("⚠️ Could not update ChatController: $e");
      }

      update();

      Get.snackbar(
        'Group Updated',
        'Group name has been updated successfully',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,

      );
    }
  }

  Future<void> _updateGroupImageInFirebase(String imageUrl) async {
    try {
      print('🔄 Updating group image in Firestore...');
      print('📝 Group ID: ${_groupId.value}');
      print('🔗 Image URL: ${imageUrl.substring(0, 60)}...');

      if (_groupId.value.isEmpty) {
        throw Exception('Group ID is required for updating image');
      }

      if (!imageUrl.startsWith('http')) {
        throw Exception('Invalid image URL format');
      }

      // Get current user info for system message
      final currentUser = FirebaseAuth.instance.currentUser;
      final userId = currentUser?.uid ?? 'unknown';

      // Update the group document in Firestore
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_groupId.value)
          .update({
        'groupImage': imageUrl,
        'lastMessage': 'Group image was updated',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSender': 'system',
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userId,
      });

      print('✅ Group document updated in Firestore');

      // Add system message about image update
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_groupId.value)
          .collection('messages')
          .add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'senderId': 'system',
        'senderName': 'System',
        'text': 'Group image was updated',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'system',
        'messageType': 'system',
        'isSystemMessage': true,
        'readBy': [], // Empty initially, will be populated as users read
      });

      print('✅ System message added');

      // Update local reactive variables immediately
      _groupImage.value = imageUrl;

      // Update group data if available
      if (_groupData.value != null) {
        _groupData.value!['groupImage'] = imageUrl;
        _groupData.value!['group_image'] = imageUrl; // Alternative field name
        _groupData.refresh();
      }

      // Force UI update
      update();

      print('✅ Local data updated');

      // Sync with ChatController to update chat list
      await _syncImageUpdateWithChatController(imageUrl);

      print('✅ Group image update completed successfully');

    } catch (e) {
      print('❌ Error updating group image in Firestore: $e');

      if (e.toString().contains('permission-denied')) {
        throw Exception('Database permission denied. Check Firestore rules.');
      } else if (e.toString().contains('not-found')) {
        throw Exception('Group not found in database.');
      } else if (e.toString().contains('unavailable')) {
        throw Exception('Database temporarily unavailable. Please try again.');
      } else {
        throw Exception('Failed to update group image: ${e.toString()}');
      }
    }
  }


  Future<void> _syncImageUpdateWithChatController(String newImageData) async {
    try {
      print('🔄 Starting comprehensive sync with ChatController...');

      // Ensure ChatController is available
      ChatController? chatController = await _ensureChatControllerAvailable();
      if (chatController == null) {
        print('❌ Could not access ChatController for sync');
        return;
      }

      // Multi-strategy sync approach
      final syncStrategies = [
            () => _syncStrategy1_DirectUpdate(chatController, newImageData),
            () => _syncStrategy2_ForceRefresh(chatController),
            () => _syncStrategy3_FirestoreRefresh(chatController),
            () => _syncStrategy4_ManualUpdate(chatController, newImageData),
      ];

      // Execute all strategies
      for (int i = 0; i < syncStrategies.length; i++) {
        try {
          print('📞 Executing sync strategy ${i + 1}...');
          await syncStrategies[i]();
          print('✅ Strategy ${i + 1} completed successfully');

          // Small delay between strategies
          if (i < syncStrategies.length - 1) {
            await Future.delayed(Duration(milliseconds: 300));
          }
        } catch (e) {
          print('❌ Sync strategy ${i + 1} failed: $e');
        }
      }

      // Final verification and UI update
      await _finalSyncVerification(chatController, newImageData);

      print('✅ Comprehensive sync completed');

    } catch (e) {
      print('❌ Error in comprehensive sync: $e');
    }
  }


  String getDisplayImage() {
    print('🖼️ Getting display image...');
    print('   Has group image: ${_groupImage.value.isNotEmpty}');

    if (_groupImage.value.isNotEmpty) {
      if (_groupImage.value.startsWith('data:image')) {
        return _groupImage.value;
      }
      else if (_groupImage.value.startsWith('http')) {
        return _groupImage.value;
      }
      else if (_groupImage.value.startsWith('local:') && selectedImagePath.value.isNotEmpty) {
        return selectedImagePath.value;
      }
    }

    if (selectedImagePath.value.isNotEmpty) {
      return selectedImagePath.value;
    }

    return CustomImage.userGroup;
  }


  void _setupGroupImageChangeListener() {
    try {
      if (_groupId.value.isNotEmpty) {
        // Listen for real-time changes to the group document
        FirebaseFirestore.instance
            .collection('chats')
            .doc(_groupId.value)
            .snapshots()
            .listen((DocumentSnapshot snapshot) {

          if (snapshot.exists && snapshot.data() != null) {
            final data = snapshot.data() as Map<String, dynamic>;
            final newImageUrl = data['groupImage']?.toString() ?? '';

            // Only update if the image URL actually changed
            if (newImageUrl != _groupImage.value && newImageUrl.isNotEmpty) {
              print('🔄 Real-time group image update detected: $newImageUrl');

              // Update local data
              _groupImage.value = newImageUrl;

              if (_groupData.value != null) {
                _groupData.value!['groupImage'] = newImageUrl;
                _groupData.refresh();
              }

              // Force UI update
              update();

              print('✅ Group image updated from real-time listener');
            }
          }
        }, onError: (error) {
          print('❌ Error in group image listener: $error');
        });
      }
    } catch (e) {
      print('❌ Error setting up group image listener: $e');
    }
  }




  // ENHANCED: Check if group has custom image
  bool get hasCustomImage {
    final hasImage = _groupImage.value.isNotEmpty && (
        _groupImage.value.startsWith('data:image') ||
            _groupImage.value.startsWith('http') ||
            (_groupImage.value.startsWith('local:') && selectedImagePath.value.isNotEmpty)
    );

    print('🔍 Has custom image: $hasImage');
    return hasImage;
  }


  // Check if image is from Firebase Storage
  bool get isFirebaseStorageImage => _groupImage.value.startsWith('https://firebasestorage.googleapis.com');

  Future<void> _processAndUploadImageToFirebase(File imageFile) async {
    try {
      isUploadingImage.value = true;
      uploadProgress.value = 0.0;
      uploadStatus.value = 'Preparing image...';
      update();

      print('🔄 Starting comprehensive group image update...');
      print('   Group ID: ${_groupId.value}');
      print('   Group Name: ${groupName}');

      // Step 1: Check prerequisites
      uploadStatus.value = 'Checking connection...';
      if (!await _checkFirebasePrerequisites()) {
        throw Exception('Firebase connection failed');
      }

      if (_groupId.value.isEmpty) {
        throw Exception('Group ID is required for image upload');
      }

      uploadStatus.value = 'Validating image...';
      uploadProgress.value = 0.2;

      // Step 2: Validate the image file
      if (!await _validateImageFile(imageFile)) {
        throw Exception('Image validation failed');
      }

      uploadStatus.value = 'Converting image...';
      uploadProgress.value = 0.4;

      // Step 3: Convert image to base64
      final String base64Image = await _convertImageToBase64(imageFile);
      if (base64Image.isEmpty) {
        throw Exception('Failed to convert image to base64');
      }

      uploadStatus.value = 'Updating database...';
      uploadProgress.value = 0.6;

      // Step 4: Update Firestore with comprehensive data
      await _updateFirestoreWithImageData(base64Image);

      uploadStatus.value = 'Syncing with chat...';
      uploadProgress.value = 0.8;

      // Step 5: CRITICAL - Comprehensive sync with ChatController
      await _performComprehensiveSync(base64Image);

      uploadStatus.value = 'Complete!';
      uploadProgress.value = 1.0;

      // Success notification
      Get.snackbar(
        '✅ Success',
        'Group image updated successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );

      print('✅ Group image update completed successfully');

    } catch (e) {
      print('❌ Error in group image update: $e');
      uploadStatus.value = 'Failed';

      Get.snackbar(
        'Update Failed',
        'Failed to update group image: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,

        snackPosition: SnackPosition.TOP,
      );
    } finally {
      isUploadingImage.value = false;
      uploadProgress.value = 0.0;

      Future.delayed(Duration(seconds: 3), () {
        uploadStatus.value = '';
        update();
      });
    }
  }

// 2. ENHANCED Firestore update method
  Future<void> _updateFirestoreWithImageData(String base64Image) async {
    try {
      print('🔄 Updating Firestore with comprehensive image data...');

      final timestamp = FieldValue.serverTimestamp();
      final imageVersion = DateTime.now().millisecondsSinceEpoch;

      // Prepare comprehensive update data
      final updateData = {
        // Primary image field
        'groupImage': base64Image,

        // Alternative image fields for compatibility
        'group_image': base64Image,
        'image': base64Image,

        // Tracking fields
        'imageUpdatedAt': timestamp,
        'imageVersion': imageVersion,
        'imageUpdateSource': 'group_controller',

        // Chat list fields
        'lastMessage': 'Group image was updated',
        'lastMessageTimestamp': timestamp,
        'lastMessageSender': 'system',
        'updatedAt': timestamp,

        // Force sync flag
        'forceSyncRequired': true,
        'syncTimestamp': imageVersion,
      };

      // Update the group document
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_groupId.value)
          .update(updateData);

      print('✅ Firestore update completed with version: $imageVersion');

      // Update local reactive variables
      _groupImage.value = base64Image;

      if (_groupData.value != null) {
        _groupData.value!['groupImage'] = base64Image;
        _groupData.value!['group_image'] = base64Image;
        _groupData.value!['imageVersion'] = imageVersion;
        _groupData.refresh();
      }

      update();

      // Add system message about the update
      await _addSystemMessage('Group image was updated');

      print('✅ Local data and system message updated');

    } catch (e) {
      print('❌ Error updating Firestore: $e');
      throw Exception('Failed to update database: $e');
    }
  }

// 3. COMPREHENSIVE sync method
  Future<void> _performComprehensiveSync(String newImageData) async {
    try {
      print('🔄 Starting comprehensive sync with ChatController...');

      // Ensure ChatController is available
      ChatController? chatController = await _ensureChatControllerAvailable();
      if (chatController == null) {
        print('❌ Could not access ChatController for sync');
        return;
      }

      // Multi-strategy sync approach
      final syncStrategies = [
            () => _syncStrategy1_DirectUpdate(chatController, newImageData),
            () => _syncStrategy2_ForceRefresh(chatController),
            () => _syncStrategy3_FirestoreRefresh(chatController),
            () => _syncStrategy4_ManualUpdate(chatController, newImageData),
      ];

      // Execute all strategies
      for (int i = 0; i < syncStrategies.length; i++) {
        try {
          print('📞 Executing sync strategy ${i + 1}...');
          await syncStrategies[i]();

          // Small delay between strategies
          if (i < syncStrategies.length - 1) {
            await Future.delayed(Duration(milliseconds: 300));
          }
        } catch (e) {
          print('❌ Sync strategy ${i + 1} failed: $e');
        }
      }

      // Final verification and UI update
      await _finalSyncVerification(chatController, newImageData);

      print('✅ Comprehensive sync completed');

    } catch (e) {
      print('❌ Error in comprehensive sync: $e');
    }
  }


  Future<void> _syncStrategy1_DirectUpdate(ChatController chatController, String imageData) async {
    try {
      print('📞 Strategy 1: Direct ChatController update...');
      await chatController.updateGroupImageWithFullSync(_groupId.value, imageData);
      print('✅ Strategy 1 (Direct Update) - Success');
    } catch (e) {
      print('❌ Strategy 1 (Direct Update) - Failed: $e');
      rethrow;
    }
  }

  Future<void> _syncStrategy2_ForceRefresh(ChatController chatController) async {
    try {
      print('📞 Strategy 2: Force refresh chats...');
      await chatController.forceRefreshChats();
      print('✅ Strategy 2 (Force Refresh) - Success');
    } catch (e) {
      print('❌ Strategy 2 (Force Refresh) - Failed: $e');
      rethrow;
    }
  }

  Future<void> _syncStrategy3_FirestoreRefresh(ChatController chatController) async {
    try {
      print('📞 Strategy 3: Refresh from Firestore...');
      await chatController.refreshGroupImageFromFirestore(_groupId.value);
      print('✅ Strategy 3 (Firestore Refresh) - Success');
    } catch (e) {
      print('❌ Strategy 3 (Firestore Refresh) - Failed: $e');
      rethrow;
    }
  }

  Future<void> _syncStrategy4_ManualUpdate(ChatController chatController, String imageData) async {
    try {
      print('📞 Strategy 4: Manual chat list update...');
      await chatController.updateGroupImageInChatList(_groupId.value, imageData);
      print('✅ Strategy 4 (Manual Update) - Success');
    } catch (e) {
      print('❌ Strategy 4 (Manual Update) - Failed: $e');
      rethrow;
    }
  }

  Future<ChatController?> _ensureChatControllerAvailable() async {
    try {
      if (Get.isRegistered<ChatController>()) {
        final controller = Get.find<ChatController>();
        print('✅ Found existing ChatController');
        return controller;
      }

      print('⚠️ ChatController not registered, attempting registration...');

      // Try to register ChatController
      final chatController = ChatController();
      Get.put<ChatController>(chatController, permanent: true);

      // Give it time to initialize
      await Future.delayed(Duration(milliseconds: 1000));

      if (Get.isRegistered<ChatController>()) {
        print('✅ ChatController successfully registered');
        return Get.find<ChatController>();
      } else {
        print('❌ Failed to register ChatController');
        return null;
      }

    } catch (e) {
      print('❌ Error ensuring ChatController availability: $e');
      return null;
    }
  }

// Enhanced final verification:
  Future<void> _finalSyncVerification(ChatController chatController, String expectedImageData) async {
    try {
      print('🔍 Final sync verification...');

      // Wait for propagation
      await Future.delayed(Duration(milliseconds: 500));

      // Check if sync was successful
      bool syncSuccessful = await _verifySyncSuccess(chatController, expectedImageData);

      if (!syncSuccessful) {
        print('⚠️ Sync verification failed, attempting recovery...');

        // Recovery attempt - use the new comprehensive method
        await chatController.updateGroupImageWithFullSync(_groupId.value, expectedImageData);
        await Future.delayed(Duration(milliseconds: 1000));

        // Final check
        syncSuccessful = await _verifySyncSuccess(chatController, expectedImageData);

        if (syncSuccessful) {
          print('✅ Sync recovery successful');
        } else {
          print('❌ Sync recovery failed');
        }
      }

      // Force UI updates regardless
      chatController.refreshChatListUI();
      chatController.update();
      update();
      Get.forceAppUpdate();

      print('✅ Final verification and UI update completed');

    } catch (e) {
      print('❌ Error in final sync verification: $e');
    }
  }

  Future<bool> _verifySyncSuccess(ChatController chatController, String expectedImageData) async {
    try {
      // Check both personal and group chats for our group
      final allChats = [...chatController.personalChats, ...chatController.groupChats];

      for (var chat in allChats) {
        if (chat.id == _groupId.value || chat.apiGroupId == _groupId.value ||
            (chat.isGroup && chat.name == _actualGroupName.value)) {
          final chatImage = chat.groupImage ?? '';

          if (chatImage == expectedImageData) {
            print('✅ Sync verification successful: Chat found with correct image');
            return true;
          } else {
            print('⚠️ Sync verification issue: Image mismatch');
            print('   Expected length: ${expectedImageData.length}');
            print('   Found length: ${chatImage.length}');
            print('   Chat ID: ${chat.id}');
            print('   Chat Name: ${chat.name}');
            return false;
          }
        }
      }

      print('❌ Sync verification failed: Chat not found in lists');
      return false;

    } catch (e) {
      print('❌ Error in sync verification: $e');
      return false;
    }
  }

// 8. Add system message helper
  Future<void> _addSystemMessage(String message) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_groupId.value)
          .collection('messages')
          .add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'senderId': 'system',
        'senderName': 'System',
        'text': message,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'system',
        'messageType': 'system',
        'isSystemMessage': true,
        'readBy': [],
      });
    } catch (e) {
      print('⚠️ Could not add system message: $e');
    }
  }


  Future<void> _verifyFinalSync(ChatController chatController, String expectedImageData) async {
    try {
      print('🔍 Verifying final sync status...');

      // Check if the chat exists with updated image
      final allChats = [...chatController.personalChats, ...chatController.groupChats];

      bool foundWithCorrectImage = false;

      for (var chat in allChats) {
        if (chat.id == _groupId.value || chat.apiGroupId == _groupId.value) {
          final chatImage = chat.groupImage ?? '';

          if (chatImage == expectedImageData) {
            foundWithCorrectImage = true;
            print('✅ Verification successful: Chat found with correct image');
            break;
          } else {
            print('⚠️ Verification issue: Chat found but image mismatch');
            print('   Expected: ${expectedImageData.substring(0, 50)}...');
            print('   Found: ${chatImage.substring(0, 50)}...');
          }
        }
      }

      if (!foundWithCorrectImage) {
        print('❌ Verification failed: Chat not found or image not updated');

        // One final attempt
        print('🔄 Final attempt: Complete refresh...');
        await chatController.forceRefreshChats();
        await Future.delayed(Duration(milliseconds: 500));
        chatController.refreshChatListUI();
      }

    } catch (e) {
      print('❌ Error in final verification: $e');
    }
  }


  // NEW: Convert image to base64 (similar to how text data is handled)
  Future<String> _convertImageToBase64(File imageFile) async {
    try {
      print('🔄 Converting image to base64...');

      // Read image as bytes
      final Uint8List imageBytes = await imageFile.readAsBytes();
      print('📊 Image size: ${imageBytes.length} bytes');

      // Check size limit (2MB for Firestore efficiency)
      if (imageBytes.length > 2 * 1024 * 1024) {
        throw Exception('Image too large. Please choose an image smaller than 2MB.');
      }

      uploadProgress.value = 0.6;

      // Convert to base64
      final String base64String = base64Encode(imageBytes);

      // Create data URI (same format used elsewhere in your app)
      final String dataUri = 'data:image/jpeg;base64,$base64String';

      uploadProgress.value = 0.7;

      print('✅ Base64 conversion complete');
      print('📏 Base64 length: ${base64String.length}');

      return dataUri;
    } catch (e) {
      print('❌ Error converting to base64: $e');
      throw Exception('Failed to process image: $e');
    }
  }


  // Helper method to identify image type
  String _getImageType(String imageData) {
    if (imageData.startsWith('data:image')) {
      return 'Base64';
    } else if (imageData.startsWith('https://firebasestorage.googleapis.com')) {
      return 'Firebase Storage';
    } else if (imageData.startsWith('http')) {
      return 'HTTP URL';
    } else if (imageData.startsWith('local:')) {
      return 'Local File';
    }
    return 'Unknown';
  }



  // Check if image is base64
  bool get isBase64Image => _groupImage.value.startsWith('data:image');

  // Check if image is local
  bool get isLocalImage => _groupImage.value.startsWith('local:') && selectedImagePath.value.isNotEmpty;

  void addMembers() {
    if (_groupId.value.isNotEmpty) {
      Get.toNamed('/addMember', arguments: {
        'groupId': _groupId.value,
        'groupName': _actualGroupName.value.isNotEmpty ? _actualGroupName.value : _groupName.value,
        'groupData': _groupData.value,
      });
    } else {
      _showErrorSnackbar('Group information not available');
    }
  }

  void viewMembers() {
    if (_groupId.value.isNotEmpty) {
      Get.to(() => ViewMembersScreen(
        groupId: _groupId.value,
        groupName: _actualGroupName.value.isNotEmpty ? _actualGroupName.value : _groupName.value,
        groupData: _groupData.value,
      ));
    } else {
      _showErrorSnackbar('Group information not available. Please try again.');
    }
  }

  void editGroupInfo() {
    Get.bottomSheet(
      const EditGroupDialog(),
      isScrollControlled: true,
      enableDrag: true,
    );
  }

  Future<void> leaveGroup() async {
    final shouldLeave = await Get.dialog<bool>(
      const LeaveGroupDialog(),
      barrierDismissible: false,
    );

    if (shouldLeave == true) {
      await _performLeaveGroup();
    }
  }

  Future<void> _performLeaveGroup() async {
    try {
      Get.dialog(
        Center(child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [CircularProgressIndicator()],
          ),
        )),
        barrierDismissible: false,
      );

      final currentUserId = await _getCurrentUserId();
      if (currentUserId == null) {
        Get.back();
        _showErrorSnackbar('Unable to identify current user');
        return;
      }

      bool success = await _removeFromFirebaseGroup(currentUserId);

      if (success) {
        _updateLocalGroupData(currentUserId);
      }

      Get.back();

      if (success) {
        final leftGroupName = groupName;
        _clearGroupData();

        try {
          Get.until((route) {
            return route.settings.name == '/community_chat' ||
                route.settings.name == '/chat_screen' ||
                route.settings.name == '/home' ||
                route.isFirst;
          });
        } catch (e) {
          Get.offNamed('/community_chat');
        }

        Future.delayed(Duration(milliseconds: 500), () {
          Get.snackbar(
            'Left Group',
            'You have successfully left "$leftGroupName"',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        });

        if (Get.isRegistered<ChatController>()) {
          try {
            final chatController = Get.find<ChatController>();
            await chatController.refreshChats();
          } catch (e) {
            print("⚠️ Could not refresh ChatController: $e");
          }
        }
      } else {
        _showErrorSnackbar('Failed to leave group. Please try again.');
      }

    } catch (e) {
      Get.back();
      _showErrorSnackbar('An error occurred while leaving the group');
    }
  }

  Future<bool> _removeFromFirebaseGroup(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_groupId.value)
          .update({
        'participants': FieldValue.arrayRemove([userId]),
        'participantDetails.$userId': FieldValue.delete(),
        'unreadCounts.$userId': FieldValue.delete(),
        'lastMessage': 'A member left the group',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSender': 'system',
      });

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_groupId.value)
          .collection('messages')
          .add({
        'senderId': 'system',
        'senderName': 'System',
        'text': 'A member left the group',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'system',
      });

      return true;
    } catch (e) {
      print("❌ Error removing from Firebase group: $e");
      return false;
    }
  }

  void _updateLocalGroupData(String userId) {
    if (_groupData.value != null) {
      final members = _groupData.value!['members'] as List?;
      if (members != null) {
        members.removeWhere((member) => member['id'] == userId || member['user_id'] == userId);
        _groupData.value!['members'] = members;
        _groupData.value!['member_count'] = members.length;
      }

      final participants = _groupData.value!['participants'] as List?;
      if (participants != null) {
        participants.remove(userId);
        _groupData.value!['participants'] = participants;
      }

      _memberCount.value = _memberCount.value - 1;
      _groupData.refresh();
    }
  }

  Future<String?> _getCurrentUserId() async {
    try {
      final userData = StorageService.to.getUser();
      if (userData != null) {
        final rawUserId = userData['id']?.toString();
        if (rawUserId != null && rawUserId.isNotEmpty) {
          return 'app_user_$rawUserId';
        }
      }
      return null;
    } catch (e) {
      print("❌ Error getting current user ID: $e");
      return null;
    }
  }

  void _clearGroupData() {
    _groupId.value = '';
    _actualGroupName.value = '';
    _groupName.value = 'Lupus Recovery';
    _memberCount.value = 0;
    _groupImage.value = '';
    selectedImagePath.value = '';
    _groupData.value = null;
    _isInitialized = false;
    update();
  }

  void _showErrorSnackbar(String message) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }

  @override
  void onClose() {
    _isInitialized = false;
    super.onClose();
  }
}