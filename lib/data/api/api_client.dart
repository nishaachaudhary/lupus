import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:lupus_care/helper/storage_service.dart';

class ApiClient {
  static const String baseUrl = 'https://alliedtechnologies.cloud/clients/lupus_care/api/v1/user.php';

  // Core request method that handles all HTTP communication
  Future<Map<String, dynamic>> makeRequest({
    required String requestType,
    required Map<String, String> body,
    File? imageFile,
    String? fileKey,
    List<File>? multipleFiles,
  }) async {
    try {
      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse(baseUrl));

      // Add request type to body
      final Map<String, String> requestBody = {
        'request': requestType,
        ...body,
      };

      // Add headers including authentication token
      request.headers.addAll(_getHeaders());

      // Add form fields
      request.fields.addAll(requestBody);

      // Add single image file if provided
      if (imageFile != null && fileKey != null) {
        await _addFileToRequest(
          request: request,
          file: imageFile,
          fileKey: fileKey,
          contentType: 'image/${_getFileExtension(imageFile)}',
        );
      }

      // Add multiple files if provided
      if (multipleFiles != null && multipleFiles.isNotEmpty) {
        for (int i = 0; i < multipleFiles.length; i++) {
          var file = multipleFiles[i];
          await _addFileToRequest(
            request: request,
            file: file,
            fileKey: fileKey ?? 'file_$i',
            contentType: _getContentType(file),
          );
        }
      }

      // Log request details for debugging
      _logRequestDetails(request);

      // Send request and handle response
      var response = await request.send();
      return await _handleResponse(response);
    } catch (e) {
      print('API Request Error: $e');
      rethrow;
    }
  }

  // Get authentication headers
  Map<String, String> _getHeaders() {
    final token = StorageService.to.getToken();
    if (token != null && token.isNotEmpty) {
      return {
        'Authorization': 'Bearer $token',
      };
    } else {
      // Default authorization if no token is available
      return {
        'Authorization': 'Basic YWRtaW46MTIzNA==',
      };
    }
  }

  // Helper method to add files to the request
  Future<void> _addFileToRequest({
    required http.MultipartRequest request,
    required File file,
    required String fileKey,
    required String contentType,
  }) async {
    var multipartFile = await http.MultipartFile.fromPath(
      fileKey,
      file.path,
      contentType: MediaType.parse(contentType),
    );
    request.files.add(multipartFile);
    print('Added file: ${file.path} as $fileKey');
  }

  // Helper method to determine content type
  String _getContentType(File file) {
    String extension = _getFileExtension(file);
    if (extension == 'pdf') return 'application/pdf';
    if (extension == 'jpg' || extension == 'jpeg') return 'image/jpeg';
    if (extension == 'png') return 'image/png';
    return 'application/octet-stream';
  }

  // Helper method to get file extension
  String _getFileExtension(File file) {
    return file.path.split('.').last.toLowerCase();
  }

  // Helper method to log request details
  void _logRequestDetails(http.MultipartRequest request) {
    print('Request URL: ${request.url}');
    print('Request headers: ${request.headers}');
    print('Request fields: ${request.fields}');
    print('Files to upload:');
    request.files.forEach((file) {
      print(' - ${file.field}: ${file.filename} (${file.contentType})');
    });
  }

  // Helper method to handle the response
  Future<Map<String, dynamic>> _handleResponse(http.StreamedResponse response) async {
    final responseString = await response.stream.bytesToString();
    print('Response status: ${response.statusCode}');
    print('Response body: $responseString');

    Map<String, dynamic> responseData;
    try {
      responseData = json.decode(responseString);
    } catch (e) {
      throw Exception('Failed to parse response: Invalid format');
    }

    if (responseData['status'] == "success") {
      return responseData;
    } else {
      throw Exception(responseData['message'] ?? 'Unknown error occurred');
    }
  }
}