// File: lib/data/api/token_expiration_handler.dart
// Enhanced version with better error handling and user experience

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lupus_care/helper/storage_service.dart';
import 'package:lupus_care/data/api/auth_service.dart';

class TokenExpirationHandler extends GetxService {
  static TokenExpirationHandler get to => Get.find<TokenExpirationHandler>();

  Timer? _tokenCheckTimer;
  bool _isCheckingToken = false;
  bool _hasLoggedOut = false;
  int _consecutiveFailures = 0;
  DateTime? _lastSuccessfulCheck;

  // Configuration
  static const Duration _initialCheckInterval = Duration(minutes: 15); // Less frequent
  static const Duration _maxCheckInterval = Duration(hours: 1);
  static const int _maxRetries = 3;
  static const int _maxConsecutiveFailures = 3;

  @override
  void onInit() {
    super.onInit();
    print("🕐 Enhanced TokenExpirationHandler initialized");
    _startTokenMonitoring();
  }

  @override
  void onClose() {
    _stopTokenMonitoring();
    super.onClose();
  }

  void _startTokenMonitoring() {
    print("🕐 Starting enhanced token monitoring...");
    print("   - Check interval: ${_initialCheckInterval.inMinutes} minutes");
    print("   - Max retries per check: $_maxRetries");
    print("   - Max consecutive failures: $_maxConsecutiveFailures");

    // Initial check after a longer delay (2 minutes)
    Future.delayed(Duration(minutes: 2), () {
      _checkTokenExpiration();
    });

    // Set up periodic checks with initial interval
    _tokenCheckTimer = Timer.periodic(_initialCheckInterval, (_) {
      _checkTokenExpiration();
    });
  }

  void _stopTokenMonitoring() {
    print("🕐 Stopping token monitoring...");
    _tokenCheckTimer?.cancel();
    _tokenCheckTimer = null;
  }

  Future<void> _checkTokenExpiration() async {
    if (_isCheckingToken || _hasLoggedOut) return;

    try {
      _isCheckingToken = true;

      final storageService = StorageService.to;

      // Don't check if user is not logged in
      if (!storageService.isLoggedIn()) {
        print("🕐 User not logged in - skipping token check");
        return;
      }

      final userData = storageService.getUser();
      final token = storageService.getToken();

      if (userData == null || token == null) {
        print("🕐 No user data or token found during check");
        return;
      }

      // Check internet connectivity first
      if (!await _hasInternetConnection()) {
        print("🌐 No internet connection - skipping token validation");
        return;
      }

      print("🕐 Checking token expiration for user: ${userData['email']} (attempt ${_consecutiveFailures + 1})");

      // Perform token validation with retry logic
      final validationResult = await _validateTokenWithRetry();

      if (validationResult['success'] == true) {
        // Token is valid
        print("✅ Token validation successful");
        _consecutiveFailures = 0;
        _lastSuccessfulCheck = DateTime.now();
        _resetCheckInterval(); // Reset to normal interval
      } else if (validationResult['is_auth_error'] == true) {
        // Definite authentication error - handle logout
        print("❌ Authentication error detected: ${validationResult['message']}");
        await _handleAuthenticationError(validationResult);
      } else {
        // Network/server error - increment failure count
        _consecutiveFailures++;
        print("⚠️ Token validation failed (${_consecutiveFailures}/$_maxConsecutiveFailures): ${validationResult['message']}");

        if (_consecutiveFailures >= _maxConsecutiveFailures) {
          print("🚨 Max consecutive failures reached - showing user dialog");
          await _showConnectionIssueDialog();
        } else {
          // Increase check interval temporarily
          _adjustCheckInterval();
        }
      }

    } catch (e) {
      _consecutiveFailures++;
      print("❌ Error during token check (${_consecutiveFailures}/$_maxConsecutiveFailures): $e");

      if (_consecutiveFailures >= _maxConsecutiveFailures) {
        await _showConnectionIssueDialog();
      }
    } finally {
      _isCheckingToken = false;
    }
  }

  Future<Map<String, dynamic>> _validateTokenWithRetry() async {
    final authService = AuthService();

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        print("🔄 Token validation attempt $attempt/$_maxRetries");

        final result = await authService.testCurrentToken()
            .timeout(Duration(seconds: 30));

        if (result['valid'] == true) {
          return {'success': true, 'message': 'Token is valid'};
        }

        // Check if this is a definite authentication error
        if (_isAuthenticationError(result)) {
          return {
            'success': false,
            'is_auth_error': true,
            'message': result['message'] ?? 'Authentication failed'
          };
        }

        // If not the last attempt, wait before retrying
        if (attempt < _maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2)); // Exponential backoff
        }

      } catch (e) {
        print("⚠️ Token validation attempt $attempt failed: $e");

        // If it's a timeout or network error, continue retrying
        if (attempt < _maxRetries && _isNetworkError(e)) {
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }
      }
    }

    // All retries failed
    return {
      'success': false,
      'is_auth_error': false,
      'message': 'Token validation failed after $_maxRetries attempts'
    };
  }

  bool _isAuthenticationError(Map<String, dynamic> result) {
    // Only treat as auth error if we have clear indicators
    final message = result['message']?.toString().toLowerCase() ?? '';

    return result['unauthorized'] == true ||
        result['status_code'] == 401 ||
        message.contains('token expired') ||
        message.contains('token invalid') ||
        message.contains('authentication failed');
  }

  bool _isNetworkError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('timeout') ||
        errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('socket') ||
        error is SocketException ||
        error is TimeoutException;
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print("⚠️ Error checking connectivity: $e");
      return true; // Assume connected if check fails
    }
  }

  void _adjustCheckInterval() {
    // Temporarily increase check interval when having issues
    final newInterval = Duration(
        minutes: (_initialCheckInterval.inMinutes * (_consecutiveFailures + 1)).clamp(
            _initialCheckInterval.inMinutes,
            _maxCheckInterval.inMinutes
        )
    );

    print("⏰ Adjusting check interval to ${newInterval.inMinutes} minutes due to failures");
    _restartTimerWithInterval(newInterval);
  }

  void _resetCheckInterval() {
    if (_tokenCheckTimer?.isActive == true) {
      _restartTimerWithInterval(_initialCheckInterval);
    }
  }

  void _restartTimerWithInterval(Duration interval) {
    _stopTokenMonitoring();
    _tokenCheckTimer = Timer.periodic(interval, (_) {
      _checkTokenExpiration();
    });
  }

  Future<void> _handleAuthenticationError(Map<String, dynamic> error) async {
    if (_hasLoggedOut) return;

    try {
      print("🚨 === HANDLING AUTHENTICATION ERROR ===");
      print("🚨 Reason: ${error['message']}");

      // Show user a choice instead of automatic logout
      final shouldLogout = await _showAuthErrorDialog(error);

      if (shouldLogout) {
        await _performLogout(error, userInitiated: false);
      } else {
        // User chose to stay - pause monitoring temporarily
        print("👤 User chose to stay logged in");
        _pauseMonitoringTemporarily();
      }

    } catch (e) {
      print("❌ Error handling authentication error: $e");
      await _performLogout(error, userInitiated: false);
    }
  }

  Future<void> _showConnectionIssueDialog() async {
    if (_hasLoggedOut) return;

    try {
      Get.dialog(
        AlertDialog(
          title: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.orange),
              SizedBox(width: 8),
              Text("Connection Issues"),
            ],
          ),
          content: Text(
              "We're having trouble verifying your session due to connection issues. "
                  "Would you like to:\n\n"
                  "• Keep using the app (some features may be limited)\n"
                  "• Sign out and sign back in"
          ),
          actions: [
            TextButton(
              onPressed: () {
                Get.back();
                _pauseMonitoringTemporarily();
                _consecutiveFailures = 0; // Reset failures
              },
              child: Text("Keep Using App"),
            ),
            ElevatedButton(
              onPressed: () {
                Get.back();
                _performLogout({
                  'message': 'User chose to sign out due to connection issues'
                }, userInitiated: true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text("Sign Out", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        barrierDismissible: false,
      );
    } catch (e) {
      print("⚠️ Error showing connection issue dialog: $e");
    }
  }

  Future<bool> _showAuthErrorDialog(Map<String, dynamic> error) async {
    try {
      final result = await Get.dialog<bool>(
        AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.red),
              SizedBox(width: 8),
              Text("Session Issue"),
            ],
          ),
          content: Text(
              "Your session appears to be invalid. This could be due to:\n\n"
                  "• Session expired\n"
                  "• Security policy changes\n"
                  "• Account logged in elsewhere\n\n"
                  "Would you like to sign out and sign back in?"
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text("Not Now"),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: Text("Sign Out", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        barrierDismissible: false,
      );

      return result ?? false;
    } catch (e) {
      print("⚠️ Error showing auth error dialog: $e");
      return true; // Default to logout if dialog fails
    }
  }

  Future<void> _performLogout(Map<String, dynamic> reason, {required bool userInitiated}) async {
    if (_hasLoggedOut) return;

    try {
      print("🚪 Performing logout (user initiated: $userInitiated)...");
      _hasLoggedOut = true;

      // Show appropriate notification
      if (!userInitiated) {
        _showLogoutNotification(reason);
      }

      // Clear any chat sessions
      await _clearAnyChatSessions();

      // Clear storage
      final storageService = StorageService.to;
      await storageService.logout();

      // Stop token monitoring
      _stopTokenMonitoring();

      // Navigate to login screen
      Get.offAllNamed('/login');

      print("✅ Logout completed");

    } catch (e) {
      print("❌ Error during logout: $e");
      await _forceLogout();
    }
  }

  void _pauseMonitoringTemporarily() {
    print("⏸️ Pausing token monitoring temporarily (30 minutes)");
    _stopTokenMonitoring();

    // Resume monitoring after 30 minutes
    Timer(Duration(minutes: 30), () {
      if (!_hasLoggedOut) {
        print("▶️ Resuming token monitoring after temporary pause");
        _consecutiveFailures = 0; // Reset failure count
        _startTokenMonitoring();
      }
    });
  }

  Future<void> _forceLogout() async {
    try {
      print("🚨 Force logout initiated");
      await _clearAnyChatSessions();
      final storageService = StorageService.to;
      await storageService.clearAll();
      _stopTokenMonitoring();
      Get.offAllNamed('/login');
    } catch (e) {
      print("❌ Force logout error: $e");
      Get.offAllNamed('/login');
    }
  }

  Future<void> _clearAnyChatSessions() async {
    try {
      final authService = AuthService();
      // AuthService logout already clears chat sessions
      print("✅ Chat session clearing completed");
    } catch (e) {
      print("❌ Error clearing chat sessions: $e");
    }
  }

  void _showLogoutNotification(Map<String, dynamic> reason) {
    try {
      Get.snackbar(
        "Session Expired",
        "Your session has expired. Please sign in again.",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange.shade700,
        colorText: Colors.white,
        duration: Duration(seconds: 4),
        margin: EdgeInsets.all(16),
        icon: Icon(Icons.warning, color: Colors.white),
      );
    } catch (e) {
      print("⚠️ Error showing logout notification: $e");
    }
  }

  // Public methods
  Future<bool> checkTokenNow() async {
    if (_isCheckingToken) return false;
    await _checkTokenExpiration();
    return !_hasLoggedOut;
  }

  void resetHandler() {
    print("🔄 Resetting TokenExpirationHandler state");
    _hasLoggedOut = false;
    _isCheckingToken = false;
    _consecutiveFailures = 0;
    _lastSuccessfulCheck = DateTime.now();
    _stopTokenMonitoring();
    _startTokenMonitoring();
  }

  void pauseMonitoring() {
    print("⏸️ Pausing token monitoring");
    _tokenCheckTimer?.cancel();
  }

  void resumeMonitoring() {
    print("▶️ Resuming token monitoring");
    if (!isMonitoring && !_hasLoggedOut) {
      _startTokenMonitoring();
    }
  }

  // Getters
  bool get hasLoggedOut => _hasLoggedOut;
  bool get isMonitoring => _tokenCheckTimer?.isActive ?? false;
  int get consecutiveFailures => _consecutiveFailures;
  DateTime? get lastSuccessfulCheck => _lastSuccessfulCheck;
}