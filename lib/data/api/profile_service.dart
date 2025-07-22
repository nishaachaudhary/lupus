import 'dart:io';
import 'package:lupus_care/data/api/api_client.dart';

class ProfileService {
  final ApiClient _apiClient = ApiClient();

  // Upload user profile
  Future<Map<String, dynamic>> uploadUserProfile({
    required String userId,
    required String uniqueUsername,
    required File profileImage,
  }) async {
    return await _apiClient.makeRequest(
      requestType: 'upload_profile',
      body: {
        'user_id': userId,
        'unique_username': uniqueUsername,
      },
      imageFile: profileImage,
      fileKey: 'profile_image',
    );
  }

  // Update profile details - UPDATED to support more fields
  Future<Map<String, dynamic>> updateProfileDetails({
    required String userId,
    String? fullName,
    String? uniqueUsername,
    String? email,
    String? bio,
    String? phoneNumber,
    String? address,
  }) async {
    final Map<String, String> body = {
      'user_id': userId,
    };

    // Only add fields that are provided
    if (fullName != null) body['full_name'] = fullName;
    if (uniqueUsername != null) body['unique_username'] = uniqueUsername;
    if (email != null) body['email'] = email;
    if (bio != null) body['bio'] = bio;
    if (phoneNumber != null) body['phone_number'] = phoneNumber;
    if (address != null) body['address'] = address;

    return await _apiClient.makeRequest(
      requestType: 'update_profile',
      body: body,
    );
  }

  // Get user profile
  Future<Map<String, dynamic>> getUserProfile({
    required String userId,
  }) async {
    return await _apiClient.makeRequest(
      requestType: 'get_profile',
      body: {
        'user_id': userId,
      },
    );
  }

  // Upload multiple documents
  Future<Map<String, dynamic>> uploadDocuments({
    required String userId,
    required String documentType,
    required List<File> documents,
  }) async {
    return await _apiClient.makeRequest(
      requestType: 'upload_documents',
      body: {
        'user_id': userId,
        'document_type': documentType,
      },
      multipleFiles: documents,
      fileKey: 'document',
    );
  }
}

