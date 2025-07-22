// // fcm_token_service.dart
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/foundation.dart';
// import 'package:get/get.dart';
// import 'package:lupus_care/helper/storage_service.dart';
//
// class FCMTokenService extends GetxService {
//   static FCMTokenService get to => Get.find();
//
//   FirebaseMessaging? _messaging;
//   String? _currentToken;
//   bool _isInitialized = false;
//
//   // Observable token for reactive updates
//   final Rx<String?> fcmToken = Rx<String?>(null);
//
//   @override
//   Future<void> onInit() async {
//     super.onInit();
//     await initializeFCM();
//   }
//
//   /// Initialize FCM and get initial token
//   Future<void> initializeFCM() async {
//     try {
//       if (_isInitialized) return;
//
//       print("🔔 === INITIALIZING FCM TOKEN SERVICE ===");
//
//       _messaging = FirebaseMessaging.instance;
//
//       // Request notification permissions
//       await _requestNotificationPermissions();
//
//       // Get initial token
//       await _getAndSaveToken();
//
//       // Listen for token refresh
//       _listenForTokenRefresh();
//
//       _isInitialized = true;
//       print("✅ FCM Token Service initialized successfully");
//
//     } catch (e) {
//       print("❌ Error initializing FCM: $e");
//       // Set fallback token for development
//       _setFallbackToken();
//     }
//   }
//
//   /// Request notification permissions
//   Future<void> _requestNotificationPermissions() async {
//     try {
//       print("📱 Requesting notification permissions...");
//
//       NotificationSettings settings = await _messaging!.requestPermission(
//         alert: true,
//         announcement: false,
//         badge: true,
//         carPlay: false,
//         criticalAlert: false,
//         provisional: false,
//         sound: true,
//       );
//
//       print("🔔 Notification permission status: ${settings.authorizationStatus}");
//
//       if (settings.authorizationStatus == AuthorizationStatus.authorized) {
//         print("✅ Notification permissions granted");
//       } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
//         print("⚠️ Provisional notification permissions granted");
//       } else {
//         print("❌ Notification permissions denied");
//       }
//
//     } catch (e) {
//       print("❌ Error requesting notification permissions: $e");
//     }
//   }
//
//
//   /// Get FCM token and save it
//   Future<void> _getAndSaveToken() async {
//     try {
//       print("🔑 Getting FCM token...");
//
//       String? token = await _messaging!.getToken();
//
//       if (token != null) {
//         _currentToken = token;
//         fcmToken.value = token;
//
//         // Save to storage for offline access
//         await StorageService.to.saveFCMToken(token);
//
//         print("✅ FCM token obtained and saved");
//         print("🔑 Token: ${token.substring(0, 50)}...");
//
//       } else {
//         print("⚠️ FCM token is null");
//         _setFallbackToken();
//       }
//
//     } catch (e) {
//       print("❌ Error getting FCM token: $e");
//       _setFallbackToken();
//     }
//   }
//
//   /// Listen for token refresh
//   void _listenForTokenRefresh() {
//     try {
//       print("👂 Setting up FCM token refresh listener...");
//
//       _messaging!.onTokenRefresh.listen((String newToken) {
//         print("🔄 FCM token refreshed");
//         print("🔑 New token: ${newToken.substring(0, 50)}...");
//
//         _currentToken = newToken;
//         fcmToken.value = newToken;
//
//         // Save new token to storage
//         StorageService.to.saveFCMToken(newToken);
//
//         // Update token on backend if user is logged in
//         _updateTokenOnBackend(newToken);
//
//       }, onError: (error) {
//         print("❌ FCM token refresh error: $error");
//       });
//
//     } catch (e) {
//       print("❌ Error setting up token refresh listener: $e");
//     }
//   }
//
//   /// Update token on backend
//   Future<void> _updateTokenOnBackend(String newToken) async {
//     try {
//       final user = StorageService.to.getUser();
//
//       if (user != null && user['id'] != null) {
//         print("📤 Updating FCM token on backend for user: ${user['id']}");
//
//         // You can implement this API call to update token on backend
//         // await AuthService().updateFCMToken(userId: user['id'], fcmToken: newToken);
//
//       }
//     } catch (e) {
//       print("⚠️ Error updating token on backend: $e");
//     }
//   }
//
//   /// Set fallback token for development/testing
//   void _setFallbackToken() {
//     final fallbackToken = "dev_fcm_token_${DateTime.now().millisecondsSinceEpoch}";
//     _currentToken = fallbackToken;
//     fcmToken.value = fallbackToken;
//     StorageService.to.saveFCMToken(fallbackToken);
//
//     print("⚠️ Using fallback FCM token: $fallbackToken");
//   }
//
//   /// Get current FCM token (for login/registration)
//   String getCurrentToken() {
//     // Try to get from memory first
//     if (_currentToken != null && _currentToken!.isNotEmpty) {
//       return _currentToken!;
//     }
//
//     // Try to get from storage
//     final storedToken = StorageService.to.getFCMToken();
//     if (storedToken != null && storedToken.isNotEmpty) {
//       _currentToken = storedToken;
//       fcmToken.value = storedToken;
//       return storedToken;
//     }
//
//     // Return fallback token
//     final fallbackToken = "fallback_fcm_token_${DateTime.now().millisecondsSinceEpoch}";
//     print("⚠️ No FCM token available, using fallback: $fallbackToken");
//     return fallbackToken;
//   }
//
//   /// Get token with async initialization if needed
//   Future<String> getTokenAsync() async {
//     try {
//       // Ensure FCM is initialized
//       if (!_isInitialized) {
//         await initializeFCM();
//       }
//
//       // Try to get fresh token
//       if (_messaging != null) {
//         String? freshToken = await _messaging!.getToken();
//         if (freshToken != null) {
//           _currentToken = freshToken;
//           fcmToken.value = freshToken;
//           await StorageService.to.saveFCMToken(freshToken);
//           return freshToken;
//         }
//       }
//
//       // Fallback to current token
//       return getCurrentToken();
//
//     } catch (e) {
//       print("❌ Error getting token async: $e");
//       return getCurrentToken();
//     }
//   }
//
//   /// Refresh token manually
//   Future<String> refreshToken() async {
//     try {
//       print("🔄 Manually refreshing FCM token...");
//
//       if (_messaging == null) {
//         await initializeFCM();
//       }
//
//       // Delete current token and get new one
//       await _messaging!.deleteToken();
//       String? newToken = await _messaging!.getToken();
//
//       if (newToken != null) {
//         _currentToken = newToken;
//         fcmToken.value = newToken;
//         await StorageService.to.saveFCMToken(newToken);
//
//         print("✅ FCM token refreshed successfully");
//         return newToken;
//       } else {
//         print("⚠️ Failed to get new token, using current");
//         return getCurrentToken();
//       }
//
//     } catch (e) {
//       print("❌ Error refreshing FCM token: $e");
//       return getCurrentToken();
//     }
//   }
//
//   /// Check if token is valid (not expired or fallback)
//   bool isTokenValid() {
//     final token = getCurrentToken();
//
//     // Check if it's a fallback token
//     if (token.startsWith('dev_fcm_token_') ||
//         token.startsWith('fallback_fcm_token_') ||
//         token.startsWith('google_fcm_token') ||
//         token.startsWith('apple_fcm_token')) {
//       return false;
//     }
//
//     // Check if it's a real FCM token (they're usually quite long)
//     return token.length > 100;
//   }
//
//   /// Get token for specific authentication provider
//   String getTokenForAuth(String provider) {
//     final baseToken = getCurrentToken();
//
//     // For development, you might want provider-specific tokens
//     if (kDebugMode && !isTokenValid()) {
//       switch (provider.toLowerCase()) {
//         case 'google':
//           return 'google_fcm_${DateTime.now().millisecondsSinceEpoch}';
//         case 'apple':
//           return 'apple_fcm_${DateTime.now().millisecondsSinceEpoch}';
//         case 'email':
//           return 'email_fcm_${DateTime.now().millisecondsSinceEpoch}';
//         default:
//           return baseToken;
//       }
//     }
//
//     return baseToken;
//   }
//
//   /// Debug token information
//   void debugTokenInfo() {
//     print("🔍 === FCM TOKEN DEBUG INFO ===");
//     print("   Initialized: $_isInitialized");
//     print("   Current Token: ${_currentToken?.substring(0, 50) ?? 'None'}...");
//     print("   Token Valid: ${isTokenValid()}");
//     print("   Stored Token: ${StorageService.to.getFCMToken()?.substring(0, 50) ?? 'None'}...");
//     print("   Observable Token: ${fcmToken.value?.substring(0, 50) ?? 'None'}...");
//   }
//
//   /// Clean up resources
//   void dispose() {
//     fcmToken.close();
//   }
// }