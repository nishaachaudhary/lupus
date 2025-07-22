// lib/services/notification_api_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lupus_care/helper/storage_service.dart';

class NotificationApiService {
  static const String baseUrl = 'https://alliedtechnologies.cloud/clients/lupus_care/api/v1/user.php';

  /// Send personal chat notification via API
  static Future<Map<String, dynamic>> sendChatNotification({
    required String senderId,
    required String receiverId,
    required String message,
  }) async {
    try {
      print('📤 Sending personal chat notification via API...');
      print('   Sender ID: $senderId');
      print('   Receiver ID: $receiverId');
      print('   Message: ${message.length > 50 ? "${message.substring(0, 50)}..." : message}');

      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse(baseUrl));

      // Add fields
      request.fields.addAll({
        'request': 'send_chat_notification',
        'sender_id': senderId,
        'receiver_id': receiverId,
        'message': message,
      });

      // Add authorization header if token exists
      final token = StorageService.to.getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      print('🚀 Sending API request...');

      // Send request
      http.StreamedResponse response = await request.send();

      // Get response body
      String responseBody = await response.stream.bytesToString();

      print('📥 API Response Status: ${response.statusCode}');
      print('📄 API Response Body: $responseBody');

      if (response.statusCode == 200) {
        try {
          final jsonResponse = json.decode(responseBody);
          print('✅ Personal chat notification sent successfully');

          return {
            'success': true,
            'status_code': response.statusCode,
            'data': jsonResponse,
            'message': 'Notification sent successfully'
          };
        } catch (e) {
          print('⚠️ Response is not JSON, treating as success: $responseBody');
          return {
            'success': true,
            'status_code': response.statusCode,
            'data': {'raw_response': responseBody},
            'message': 'Notification sent successfully'
          };
        }
      } else {
        print('❌ Personal chat notification failed: ${response.statusCode}');
        return {
          'success': false,
          'status_code': response.statusCode,
          'error': response.reasonPhrase ?? 'Unknown error',
          'data': {'raw_response': responseBody},
          'message': 'Failed to send notification: ${response.reasonPhrase}'
        };
      }
    } catch (e) {
      print('❌ Error sending personal chat notification: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Network error: $e'
      };
    }
  }

  // ===== 1. FIXED NotificationApiService.dart =====
// Replace your sendGroupChatNotification method with this:

  static Future<Map<String, dynamic>> sendGroupChatNotification({
    required String senderId,
    required String groupId,
    required String message,
  }) async {
    try {
      print('📤 Sending group chat notification via API...');
      print('   Sender ID: $senderId');
      print('   Group ID: $groupId');
      print('   Message: ${message.length > 50 ? "${message.substring(0, 50)}..." : message}');

      // Clean the IDs to ensure proper format
      String cleanSenderId = senderId;
      String cleanGroupId = groupId;

      // Remove prefixes from sender ID if present
      if (cleanSenderId.startsWith('app_user_')) {
        cleanSenderId = cleanSenderId.replaceFirst('app_user_', '');
      }

      // Ensure group ID is numeric
      if (!RegExp(r'^\d+$').hasMatch(cleanGroupId)) {
        final numericMatch = RegExp(r'\d+').firstMatch(cleanGroupId);
        if (numericMatch != null) {
          cleanGroupId = numericMatch.group(0)!;
        } else {
          // If no numeric ID found, try to extract from Firebase ID hash
          cleanGroupId = _generateGroupIdFromFirebaseId(groupId);
        }
      }

      print('📤 Cleaned IDs - Sender: $cleanSenderId, Group: $cleanGroupId');

      // Get authentication token
      final token = StorageService.to.getToken();
      if (token == null) {
        throw Exception('No authentication token available');
      }

      // Create the request
      var request = http.MultipartRequest('POST', Uri.parse(baseUrl));

      // Add form fields with correct field names
      request.fields.addAll({
        'request': 'send_group_chat_notification',
        'sender_id': cleanSenderId,
        'group_id': cleanGroupId,
        'message': message,
        // 'notification_type': 'group_chat',
        // 'timestamp': DateTime.now().toIso8601String(),
      });

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Content-Type'] = 'multipart/form-data';

      print('🚀 Sending group notification API request...');
      print('📝 Request fields: ${request.fields}');

      // Send request with timeout
      http.StreamedResponse response = await request.send().timeout(
        Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Request timed out after 30 seconds'),
      );

      // Get response body
      String responseBody = await response.stream.bytesToString();

      print('📥 Group notification API Response Status: ${response.statusCode}');
      print('📄 Group notification API Response Body: $responseBody');

      // Parse response
      bool success = false;
      Map<String, dynamic> jsonResponse = {};

      if (response.statusCode == 200) {
        try {
          jsonResponse = json.decode(responseBody);
          // Check various success indicators
          success = jsonResponse['status'] == 'success' ||
              jsonResponse['success'] == true ||
              jsonResponse['message']?.toString().toLowerCase().contains('sent') == true ||
              jsonResponse['message']?.toString().toLowerCase().contains('notification') == true;
        } catch (e) {
          // Handle non-JSON responses - check for success keywords
          success = responseBody.toLowerCase().contains('success') ||
              responseBody.toLowerCase().contains('sent') ||
              responseBody.toLowerCase().contains('notification');

          if (success) {
            jsonResponse = {'message': 'Notification sent successfully', 'raw_response': responseBody};
          }
        }
      }

      final result = {
        'success': success,
        'status_code': response.statusCode,
        'data': jsonResponse,
        'raw_response': responseBody,
        'message': success
            ? 'Group notification sent successfully'
            : (jsonResponse['message'] ?? 'Failed to send group notification'),
        'error': success ? null : (jsonResponse['error'] ?? 'Unknown error'),
        'request_details': {
          'original_sender_id': senderId,
          'clean_sender_id': cleanSenderId,
          'original_group_id': groupId,
          'clean_group_id': cleanGroupId,
          'message_preview': message.length > 50 ? '${message.substring(0, 50)}...' : message,
        }
      };

      if (success) {
        print('✅ Group chat notification sent successfully');
      } else {
        print('❌ Group chat notification failed: ${result['message']}');
        print('❌ Full response: $responseBody');
      }

      return result;

    } catch (e) {
      print('❌ Error sending group chat notification: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Network error: $e',
        'request_details': {
          'sender_id': senderId,
          'group_id': groupId,
          'error_type': e.runtimeType.toString(),
        }
      };
    }
  }

// Helper method to generate numeric group ID from Firebase ID
  static String _generateGroupIdFromFirebaseId(String firebaseId) {
    try {
      // Use hash code to generate a consistent numeric ID
      int hashCode = firebaseId.hashCode.abs();
      // Ensure it's a reasonable length (max 8 digits)
      String numericId = (hashCode % 99999999).toString();
      print('🔄 Generated numeric group ID: $numericId from Firebase ID: $firebaseId');
      return numericId;
    } catch (e) {
      print('❌ Error generating group ID: $e');
      return '1'; // Fallback
    }
  }


  static String extractApiUserId(String consistentUserId) {
    if (consistentUserId.startsWith('app_user_')) {
      return consistentUserId.replaceFirst('app_user_', '');
    }
    return consistentUserId;
  }

  /// Helper method to get API group ID from chat or group data
  static String? extractApiGroupId(Map<String, dynamic>? chatData, String? fallbackId) {
    if (chatData != null) {
      // Try various possible field names for API group ID
      return chatData['apiGroupId']?.toString() ??
          chatData['api_group_id']?.toString() ??
          chatData['backend_group_id']?.toString() ??
          chatData['group_id']?.toString() ??
          fallbackId;
    }
    return fallbackId;
  }

  /// Comprehensive notification sender that handles both personal and group chats
  static Future<Map<String, dynamic>> sendChatNotificationComprehensive({
    required String currentUserId,
    required String message,
    required bool isGroupChat,
    String? receiverId,
    String? groupId,
    Map<String, dynamic>? chatData,
  }) async {
    try {
      print('📡 Sending comprehensive chat notification...');
      print('   Current User: $currentUserId');
      print('   Is Group Chat: $isGroupChat');
      print('   Message: ${message.length > 50 ? "${message.substring(0, 50)}..." : message}');

      // Extract API user ID from consistent user ID
      final apiSenderId = extractApiUserId(currentUserId);

      if (isGroupChat) {
        // Handle group chat notification
        if (groupId == null && chatData == null) {
          throw Exception('Group ID or chat data required for group notifications');
        }

        final apiGroupId = extractApiGroupId(chatData, groupId);
        if (apiGroupId == null || apiGroupId.isEmpty) {
          throw Exception('Could not determine API group ID');
        }

        print('   API Group ID: $apiGroupId');

        return await sendGroupChatNotification(
          senderId: apiSenderId,
          groupId: apiGroupId,
          message: message,
        );
      } else {
        // Handle personal chat notification
        if (receiverId == null || receiverId.isEmpty) {
          throw Exception('Receiver ID required for personal chat notifications');
        }

        final apiReceiverId = extractApiUserId(receiverId);
        print('   API Receiver ID: $apiReceiverId');

        return await sendChatNotification(
          senderId: apiSenderId,
          receiverId: apiReceiverId,
          message: message,
        );
      }
    } catch (e) {
      print('❌ Error in comprehensive notification: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to send notification: $e'
      };
    }
  }

  /// Send notifications to multiple users (for group chats with individual notifications)
  static Future<List<Map<String, dynamic>>> sendMultiplePersonalNotifications({
    required String senderId,
    required List<String> receiverIds,
    required String message,
  }) async {
    final results = <Map<String, dynamic>>[];

    for (String receiverId in receiverIds) {
      try {
        final result = await sendChatNotification(
          senderId: senderId,
          receiverId: receiverId,
          message: message,
        );
        results.add({
          'receiver_id': receiverId,
          ...result,
        });
      } catch (e) {
        results.add({
          'receiver_id': receiverId,
          'success': false,
          'error': e.toString(),
        });
      }

      // Small delay to prevent API rate limiting
      await Future.delayed(Duration(milliseconds: 200));
    }

    return results;
  }
}