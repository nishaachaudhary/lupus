// Add these imports at the top of your SymptomsController file
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/data/api/auth_service.dart';
import 'package:lupus_care/helper/storage_service.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';

class SymptomsController extends GetxController {
  // Add these new properties to your existing controller
  final AuthService _authService = AuthService();

  // Loading and error states (ADD THESE)
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  // Your existing properties
  var selectedSymptoms = <String>[].obs;
  var selectedTriggers = <String>[].obs;

  // Loading and error states
  final isGeneratingReport = false.obs;
  final reportData = Rxn<Map<String, dynamic>>();

  var defaultSymptoms = [
    "Fatigue",
    "Joint Pain & Stiffness",
    "Hair Loss",
    "Chest Pain",
    "Muscle Pain",
    "Fever",
    "Shortness of breath",
    "Dry eyes and mouth",
    "Swollen lymph nodes",
  ].obs;

  var defaultTriggers = [
    "Stress",
    "Sun exposure",
    "Cold Weather",
    "Certain medications",
    "Infections",
    "Smoking",
    "Overexertion",
    "Poor Sleep",
    "Lack of rest",
    "Weight fluctuations",
  ].obs;

  // Update your logs to be more structured (MODIFY THIS)
  var logs = <Map<String, dynamic>>[].obs;

  // ADD this onInit method
  @override
  void onInit() {
    super.onInit();
    fetchLogs();
  }

  // NEW: Validate if data exists for the selected date range
  Future<bool> validateDataExistsForDateRange({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      print("🔍 Validating data existence for date range: ${fromDate.toString().substring(0, 10)} to ${toDate.toString().substring(0, 10)}");

      // Get user ID from storage
      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString();

      if (userId == null || userId.isEmpty) {
        throw Exception('User ID not found. Please log in again.');
      }

      // Format dates for comparison
      final startDate = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final endDate = DateTime(toDate.year, toDate.month, toDate.day);

      // Method 1: Check local logs first (if available)
      bool hasLocalData = false;
      if (logs.isNotEmpty) {
        hasLocalData = logs.any((log) {
          try {
            final logDate = DateTime.parse(log['date'] ?? '');
            final logDateOnly = DateTime(logDate.year, logDate.month, logDate.day);
            return (logDateOnly.isAtSameMomentAs(startDate) || logDateOnly.isAfter(startDate)) &&
                (logDateOnly.isAtSameMomentAs(endDate) || logDateOnly.isBefore(endDate));
          } catch (e) {
            return false;
          }
        });
      }

      print("📊 Local data check: ${hasLocalData ? 'Data found' : 'No data found'}");

      // Method 2: If no local data, fetch fresh logs to double-check
      if (!hasLocalData) {
        print("🔄 No local data found, fetching fresh logs...");
        await fetchLogs();

        // Check again with fresh data
        hasLocalData = logs.any((log) {
          try {
            final logDate = DateTime.parse(log['date'] ?? '');
            final logDateOnly = DateTime(logDate.year, logDate.month, logDate.day);
            return (logDateOnly.isAtSameMomentAs(startDate) || logDateOnly.isAfter(startDate)) &&
                (logDateOnly.isAtSameMomentAs(endDate) || logDateOnly.isBefore(endDate));
          } catch (e) {
            return false;
          }
        });
      }

      print("📊 Final data validation result: ${hasLocalData ? 'Data available' : 'No data available'}");
      return hasLocalData;

    } catch (e) {
      print("❌ Error validating data existence: $e");
      // In case of error, assume data might exist and let the API handle it
      return true;
    }
  }

  // NEW: Enhanced method with comprehensive validation
  Future<void> generateInsightReportWithValidation({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      print("🔍 Starting report generation with validation...");

      // Step 1: Validate date range
      if (!isValidDateRange(fromDate, toDate)) {
        _showValidationError(
          'Invalid Date Range',
          'Please select a valid date range. The "From" date should be before the "To" date.',
        );
        return;
      }

      // Step 2: Check if date range is not in the future
      final now = DateTime.now();
      if (fromDate.isAfter(now)) {
        _showValidationError(
          'Invalid Date Range',
          'Cannot generate report for future dates. Please select dates up to today.',
        );
        return;
      }

      // Step 3: Check if date range is reasonable (not too far in the past)
      final oneYearAgo = now.subtract(Duration(days: 365));
      if (fromDate.isBefore(oneYearAgo)) {
        _showValidationError(
          'Date Range Too Old',
          'Reports can only be generated for the last 12 months. Please select a more recent date range.',
        );
        return;
      }

      // Step 4: Show initial loading
      Get.dialog(
        Center(
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: CustomColors.purpleColor),

              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // Step 5: Validate data existence
      final hasData = await validateDataExistsForDateRange(
        fromDate: fromDate,
        toDate: toDate,
      );

      // Close loading dialog
      Get.back();

      if (!hasData) {
        // No data found for the selected date range
        Get.snackbar(
          'Report Generation Failed',
          'No Data Available',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Step 6: Data exists, proceed with report generation
      print("✅ Data validation passed, proceeding with report generation");
      await generateInsightReportWithNavigation(
        fromDate: fromDate,
        toDate: toDate,
      );

    } catch (e) {
      // Close loading dialog if still open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      print("❌ Error in report generation with validation: $e");
      _showValidationError(
        'Validation Error',
        'An error occurred while validating your data. Please try again.',
      );
    }
  }

  // NEW: Show validation error dialog
  void _showValidationError(String title, String message) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text(title, style: semiBoldStyle.copyWith(fontSize: 18)),
          ],
        ),
        content: Text(
          message,
          style: regularStyle.copyWith(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'OK',
              style: semiBoldStyle.copyWith(
                color: CustomColors.purpleColor,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }


  // Helper method to build suggestion items
  Widget _buildSuggestionItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: CustomColors.purpleColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: regularStyle.copyWith(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  // REPLACE your generateInsightReportWithNavigation method with this updated version:
  Future<void> generateInsightReportWithNavigation({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      isGeneratingReport.value = true;
      errorMessage.value = '';

      print("🔍 Starting report generation with navigation...");

      // Show loading dialog while generating
      Get.dialog(
        Center(
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(CustomColors.purpleColor),
                ),

              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // Get user ID from storage
      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString();

      if (userId == null || userId.isEmpty) {
        throw Exception('User ID not found. Please log in again.');
      }

      // Format dates for API (YYYY-MM-DD format)
      final startDate = fromDate.toString().substring(0, 10);
      final endDate = toDate.toString().substring(0, 10);

      print("🔍 Step 1: Generating report for user $userId from $startDate to $endDate");

      // STEP 1: Call generate_report API
      final generateResponse = await _authService.generateInsightReport(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
      );

      print("📥 Generate report response: ${generateResponse['status']}");

      if (generateResponse['status'] == 'success') {
        // Extract report_id from the generate response
        final reportId = generateResponse['report_id']?.toString() ??
            generateResponse['data']?['report_id']?.toString() ??
            generateResponse['id']?.toString();

        print("📊 Generated report ID: $reportId");

        if (reportId != null && reportId.isNotEmpty) {
          print("🔍 Step 2: Fetching detailed report data for report ID: $reportId");

          // STEP 2: Call view_report API to get detailed report data
          final viewResponse = await _authService.viewReport(
            userId: userId,
            reportId: reportId,
          );

          print("📥 View report response: ${viewResponse['status']}");

          // Close loading dialog
          Get.back();

          if (viewResponse['status'] == 'success') {
            print("✅ Detailed report data fetched successfully");

            // Store both responses
            reportData.value = viewResponse; // Use the detailed data from view_report

            // Show success message
            Get.snackbar(
              'Success',
              'Report generated successfully',
              snackPosition: SnackPosition.TOP,
              backgroundColor: Colors.green,
              colorText: Colors.white,
            );

            // Small delay to ensure snackbar shows
            await Future.delayed(Duration(milliseconds: 500));

            print("🔄 Navigating to insight report screen with detailed data...");

            // Navigate to insight report screen with detailed data
            final navigationResult = Get.toNamed('/insightReport', arguments: {
              'reportData': viewResponse, // Use detailed data from view_report API
              'reportId': reportId,
              'startDate': startDate,
              'endDate': endDate,
              'fromDate': fromDate,
              'toDate': toDate,
              'userId': userId,
              'generatedAt': DateTime.now().toIso8601String(),
              'generateResponse': generateResponse, // Keep original for reference
            });

            print("🔄 Navigation initiated with report ID: $reportId");

          } else {
            // view_report API failed, but we still have the generated report
            print("⚠️ Failed to fetch detailed report, using generated data");

            // Store the generate response
            reportData.value = generateResponse;

            Get.snackbar(
              'Warning',
              'Report generated but detailed view unavailable',
              snackPosition: SnackPosition.TOP,
              backgroundColor: Colors.orange,
              colorText: Colors.white,
            );

            // Navigate with basic data
            Get.toNamed('/insightReport', arguments: {
              'reportData': generateResponse,
              'reportId': reportId,
              'startDate': startDate,
              'endDate': endDate,
              'fromDate': fromDate,
              'toDate': toDate,
              'userId': userId,
              'generatedAt': DateTime.now().toIso8601String(),
            });
          }

        } else {
          // No report_id returned - use the generate response directly
          print("⚠️ No report_id returned, using generate response directly");

          // Close loading dialog
          Get.back();

          reportData.value = generateResponse;

          Get.snackbar(
            'Success',
            'Report generated successfully',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );

          // Navigate with generate response
          Get.toNamed('/insightReport', arguments: {
            'reportData': generateResponse,
            'startDate': startDate,
            'endDate': endDate,
            'fromDate': fromDate,
            'toDate': toDate,
            'userId': userId,
            'generatedAt': DateTime.now().toIso8601String(),
          });
        }

      } else {
        // Close loading dialog
        Get.back();

        // Handle generate_report API error
        final errorMsg = generateResponse['message'] ?? 'Failed to generate report';
        print("❌ Report generation failed: $errorMsg");

        errorMessage.value = errorMsg;

        // Check if it's a "no data" error specifically
        if (errorMsg.toLowerCase().contains('no data') ||
            errorMsg.toLowerCase().contains('no logs') ||
            errorMsg.toLowerCase().contains('insufficient data')) {
          Get.snackbar(
            'Report Generation Failed',
            "No Data Available",
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        } else {
          Get.snackbar(
            'Report Generation Failed',
            errorMsg,
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      }

    } catch (e) {
      // Close loading dialog if still open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      print("❌ Error generating report: $e");
      errorMessage.value = e.toString();

      Get.snackbar(
        'Error',
        'An error occurred while generating the report',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isGeneratingReport.value = false;
    }
  }

  // Method to get formatted date range string
  String getDateRangeString(DateTime fromDate, DateTime toDate) {
    final dateFormat = DateFormat('dd MMM yyyy');
    return '${dateFormat.format(fromDate)} - ${dateFormat.format(toDate)}';
  }

  // Method to validate date range
  bool isValidDateRange(DateTime? fromDate, DateTime? toDate) {
    if (fromDate == null || toDate == null) {
      return false;
    }

    // Check if fromDate is not after toDate
    if (fromDate.isAfter(toDate)) {
      return false;
    }

    // Check if date range is not too large (optional - adjust as needed)
    final difference = toDate.difference(fromDate).inDays;
    if (difference > 365) { // Max 1 year range
      return false;
    }

    return true;
  }

  // Clear report data
  void clearReportData() {
    reportData.value = null;
    errorMessage.value = '';
  }

  // ADD this fetchLogs method
  Future<void> fetchLogs() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Get user ID from storage
      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString();

      if (userId == null || userId.isEmpty) {
        errorMessage.value = 'User ID not found. Please log in again.';
        print("Error: $errorMessage");
        return;
      }

      // Call API to get logs
      final response = await _authService.getLogs(userId: userId);

      if (response['status'] == 'success' && response['data'] != null) {
        // Clear existing logs
        logs.clear();

        // Add logs from API response
        final logsData = response['data'] as List;
        for (var logItem in logsData) {
          logs.add({
            'id': logItem['id']?.toString() ?? '',
            'date': logItem['log_date'] ?? '',
            'time': logItem['log_time'] ?? '',
            'symptoms': logItem['symptoms'] ?? '',
            'triggers': logItem['triggers'] ?? '',
            'created_at': logItem['created_at'] ?? '',
          });
        }

        print("Loaded ${logs.length} logs from API");
      } else {
        errorMessage.value = response['message'] ?? 'Failed to load logs';
        print("Error loading logs: $errorMessage");
      }
    } catch (e) {
      errorMessage.value = 'Error fetching logs: $e';
      print("Exception fetching logs: $errorMessage");
    } finally {
      isLoading.value = false;
    }
  }

  // ADD this refreshLogs method
  Future<void> refreshLogs() async {
    await fetchLogs();
  }

  // ADD these formatting methods
  String formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return DateFormat('dd MMMM yyyy').format(date);
    } catch (e) {
      return dateString; // Return original if parsing fails
    }
  }

  String formatTime(String timeString) {
    try {
      // Parse time string (assuming format is HH:mm:ss)
      final timeParts = timeString.split(':');
      if (timeParts.length >= 2) {
        int hour = int.parse(timeParts[0]);
        int minute = int.parse(timeParts[1]);

        // Convert to 12-hour format
        String period = hour >= 12 ? 'PM' : 'AM';
        int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

        return '${displayHour}:${minute.toString().padLeft(2, '0')} $period';
      }
      return timeString;
    } catch (e) {
      return timeString; // Return original if parsing fails
    }
  }

  // Keep your existing methods below
  void toggleSymptom(String item) {
    selectedSymptoms.contains(item)
        ? selectedSymptoms.remove(item)
        : selectedSymptoms.add(item);
  }

  void toggleTrigger(String item) {
    selectedTriggers.contains(item)
        ? selectedTriggers.remove(item)
        : selectedTriggers.add(item);
  }

  void addCustomSymptom(String custom) {
    defaultSymptoms.add(custom);
    selectedSymptoms.add(custom);
  }

  void addCustomTrigger(String custom) {
    defaultTriggers.add(custom);
    selectedTriggers.add(custom);
  }

  void saveLog() {
    logs.add({
      'date': DateTime.now().toString(),
      'time': "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
      'symptoms': selectedSymptoms.join(', '),
      'triggers': selectedTriggers.join(', '),
    });

    selectedSymptoms.clear();
    selectedTriggers.clear();
  }
}