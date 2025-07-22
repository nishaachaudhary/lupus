// REPLACE your existing InsightReportController with this FIXED version:

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:lupus_care/data/api/auth_service.dart';
import 'package:lupus_care/helper/storage_service.dart';

class InsightReportController extends GetxController {
  final AuthService _authService = AuthService();

  // Loading states
  final isLoading = false.obs;
  final isLoadingReportsList = false.obs;
  final errorMessage = ''.obs;

  // Current report data
  final currentReport = Rxn<Map<String, dynamic>>();
  final reportMetadata = Rxn<Map<String, dynamic>>();

  // Report arguments from navigation
  String? reportId;
  String? startDate;
  String? endDate;
  DateTime? fromDate;
  DateTime? toDate;
  String? userId;

  // User reports list
  final userReports = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadReportFromArguments();
  }

  // Enhanced method to load report data from navigation arguments
  void _loadReportFromArguments() {
    try {
      final arguments = Get.arguments as Map<String, dynamic>?;

      if (arguments != null) {
        print("📊 Loading report from arguments: ${arguments.keys}");

        // Extract basic metadata
        reportId = arguments['reportId']?.toString();
        startDate = arguments['startDate']?.toString();
        endDate = arguments['endDate']?.toString();
        fromDate = arguments['fromDate'] as DateTime?;
        toDate = arguments['toDate'] as DateTime?;
        userId = arguments['userId']?.toString();

        // Extract report data
        final reportData = arguments['reportData'];
        if (reportData != null) {
          currentReport.value = reportData;
          print("✅ Report data loaded from arguments");
          print("📊 Report data keys: ${reportData.keys}");

          // FIXED: Check for 'report' field instead of 'data'
          if (reportData['report'] != null) {
            print("📊 Report.report keys: ${reportData['report'].keys}");
          } else if (reportData['data'] != null) {
            print("📊 Report.data keys: ${reportData['data'].keys}");
          }
        }

        // If we have a reportId but no detailed data, load it
        if (reportId != null && userId != null && !_hasDetailedData()) {
          print("🔍 Missing detailed data, loading report by ID: $reportId");
          loadReportById(reportId!, userId!);
        } else {
          // Extract date info from current data
          _extractDateInfo(currentReport.value ?? {});
        }

        // Create metadata
        reportMetadata.value = {
          'reportId': reportId,
          'startDate': startDate,
          'endDate': endDate,
          'fromDate': fromDate,
          'toDate': toDate,
          'dateRange': _getFormattedDateRange(),
          'userId': userId,
        };

        print("✅ Report loaded successfully");
        print("📊 Report ID: $reportId");
        print("📅 Date Range: ${_getFormattedDateRange()}");

        // DEBUG: Print the actual data being parsed
        _debugPrintReportData();
      } else {
        errorMessage.value = 'No report data provided';
        print("❌ No arguments provided for report");
      }
    } catch (e) {
      errorMessage.value = 'Error loading report: $e';
      print("❌ Error loading report from arguments: $e");
    }
  }

  // FIXED: Check if we have detailed report data
  bool _hasDetailedData() {
    final data = currentReport.value;
    if (data == null) return false;

    // FIXED: Check both 'report' and 'data' fields
    final reportData = data['report'] ?? data['data'];
    if (reportData == null) return false;

    // Check if we have the expected detailed fields
    return reportData['frequent_symptoms'] != null ||
        reportData['common_triggers'] != null ||
        reportData['overall_severity'] != null ||
        reportData['suggested_management_tips'] != null;
  }

  // Enhanced method to load specific report by ID
  Future<void> loadReportById(String reportId, String userId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      print("🔍 Loading detailed report $reportId for user $userId");

      final response = await _authService.viewReport(
        userId: userId,
        reportId: reportId,
      );

      print("📥 View report response status: ${response['status']}");
      print("📥 View report response keys: ${response.keys}");

      if (response['status'] == 'success') {
        currentReport.value = response;
        this.reportId = reportId;

        print("✅ Detailed report loaded successfully");

        // Extract date information if available
        _extractDateInfo(response);

      } else {
        final errorMsg = response['message'] ?? 'Failed to load detailed report';
        print("❌ Failed to load detailed report: $errorMsg");
      }
    } catch (e) {
      print("❌ Error loading detailed report: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // FIXED: Enhanced method to extract date information from any response format
  void _extractDateInfo(Map<String, dynamic> response) {
    try {
      // FIXED: Try multiple possible locations for date information
      final reportData = response['report'] ?? response['data'];

      // Try to get dates from report section
      if (reportData != null) {
        startDate = startDate ?? reportData['start_date']?.toString();
        endDate = endDate ?? reportData['end_date']?.toString();
      }

      // Try to get dates from root level
      startDate = startDate ?? response['start_date']?.toString();
      endDate = endDate ?? response['end_date']?.toString();

      // Try to parse dates if we have them
      if (startDate != null && endDate != null && fromDate == null && toDate == null) {
        try {
          fromDate = DateTime.parse(startDate!);
          toDate = DateTime.parse(endDate!);
          print("📅 Parsed dates from API: $startDate to $endDate");
        } catch (e) {
          print("⚠️ Error parsing dates from API: $e");
        }
      }
    } catch (e) {
      print("⚠️ Error extracting date info: $e");
    }
  }

  // FIXED: Enhanced method to get frequent symptoms from any response format
  List<String> getFrequentSymptoms() {
    try {
      final report = currentReport.value;
      if (report == null) return [];

      // FIXED: Try multiple possible locations for symptoms data
      final locations = [
        report['report']?['frequent_symptoms'], // MAIN API RESPONSE FORMAT
        report['data']?['frequent_symptoms'],
        report['frequent_symptoms'],
        report['report']?['symptoms'],
        report['data']?['symptoms'],
        report['symptoms'],
      ];

      for (final location in locations) {
        if (location != null) {
          if (location is List) {
            final symptoms = List<String>.from(location);
            if (symptoms.isNotEmpty) {
              print("✅ Found frequent symptoms (list): ${symptoms.length} items");
              return symptoms;
            }
          } else if (location is String && location.isNotEmpty) {
            final symptoms = location.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
            if (symptoms.isNotEmpty) {
              print("✅ Found frequent symptoms (string): ${symptoms.length} items - $symptoms");
              return symptoms;
            }
          }
        }
      }

      print("⚠️ No frequent symptoms found in report data");
    } catch (e) {
      print("⚠️ Error getting frequent symptoms: $e");
    }
    return [];
  }

  // FIXED: Enhanced method to get common triggers from any response format
  List<String> getCommonTriggers() {
    try {
      final report = currentReport.value;
      if (report == null) return [];

      // FIXED: Try multiple possible locations for triggers data
      final locations = [
        report['report']?['common_triggers'], // MAIN API RESPONSE FORMAT
        report['data']?['common_triggers'],
        report['common_triggers'],
        report['report']?['triggers'],
        report['data']?['triggers'],
        report['triggers'],
      ];

      for (final location in locations) {
        if (location != null) {
          if (location is List) {
            final triggers = List<String>.from(location);
            if (triggers.isNotEmpty) {
              print("✅ Found common triggers (list): ${triggers.length} items");
              return triggers;
            }
          } else if (location is String && location.isNotEmpty) {
            final triggers = location.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
            if (triggers.isNotEmpty) {
              print("✅ Found common triggers (string): ${triggers.length} items - $triggers");
              return triggers;
            }
          }
        }
      }

      print("⚠️ No common triggers found in report data");
    } catch (e) {
      print("⚠️ Error getting common triggers: $e");
    }
    return [];
  }

  // FIXED: Enhanced method to get overall severity from any response format
  String getOverallSeverity() {
    try {
      final report = currentReport.value;
      if (report == null) return 'Not available';

      // FIXED: Try multiple possible locations for severity data
      final locations = [
        report['report']?['overall_severity'], // MAIN API RESPONSE FORMAT
        report['data']?['overall_severity'],
        report['overall_severity'],
        report['report']?['severity'],
        report['data']?['severity'],
        report['severity'],
      ];

      for (final location in locations) {
        if (location != null && location.toString().isNotEmpty) {
          final severity = location.toString();
          print("✅ Found overall severity: $severity");
          return severity;
        }
      }

      print("⚠️ No overall severity found in report data");
    } catch (e) {
      print("⚠️ Error getting overall severity: $e");
    }
    return 'Not available';
  }

  // FIXED: Enhanced method to get management tips from any response format
  List<Map<String, dynamic>> getManagementTips() {
    try {
      final report = currentReport.value;
      if (report == null) return _getDefaultManagementTips();

      // FIXED: Try multiple possible locations for management tips
      final locations = [
        report['report']?['suggested_management_tips'], // MAIN API RESPONSE FORMAT
        report['data']?['suggested_management_tips'],
        report['suggested_management_tips'],
        report['report']?['management_tips'],
        report['data']?['management_tips'],
        report['management_tips'],
        report['report']?['tips'],
        report['data']?['tips'],
        report['tips'],
      ];

      for (final location in locations) {
        if (location != null) {
          if (location is List) {
            final tips = List<Map<String, dynamic>>.from(
                location.map((item) => Map<String, dynamic>.from(item))
            );
            if (tips.isNotEmpty) {
              print("✅ Found management tips (list): ${tips.length} sections");
              return tips;
            }
          } else if (location is Map) {
            print("✅ Found single management tip section");
            return [Map<String, dynamic>.from(location)];
          } else if (location is String && location.isNotEmpty) {
            // FIXED: Handle string management tips from API
            print("✅ Found management tips (string): $location");
            return [
              {
                'title': 'Management Recommendations',
                'tips': [location], // Wrap the string in a list
              }
            ];
          }
        }
      }

      print("⚠️ No management tips found, using defaults");
    } catch (e) {
      print("⚠️ Error getting management tips: $e");
    }

    // Return default tips if none available
    return _getDefaultManagementTips();
  }

  // Get formatted date range string
  String _getFormattedDateRange() {
    if (fromDate != null && toDate != null) {
      final dateFormat = DateFormat('dd MMMM');
      final yearFormat = DateFormat('yyyy');

      if (fromDate!.year == toDate!.year) {
        return '${dateFormat.format(fromDate!)} - ${dateFormat.format(toDate!)} ${yearFormat.format(toDate!)}';
      } else {
        return '${DateFormat('dd MMMM yyyy').format(fromDate!)} - ${DateFormat('dd MMMM yyyy').format(toDate!)}';
      }
    } else if (startDate != null && endDate != null) {
      // Try to parse the string dates for better formatting
      try {
        final from = DateTime.parse(startDate!);
        final to = DateTime.parse(endDate!);
        final dateFormat = DateFormat('dd MMMM');
        final yearFormat = DateFormat('yyyy');

        if (from.year == to.year) {
          return '${dateFormat.format(from)} - ${dateFormat.format(to)} ${yearFormat.format(to)}';
        } else {
          return '${DateFormat('dd MMMM yyyy').format(from)} - ${DateFormat('dd MMMM yyyy').format(to)}';
        }
      } catch (e) {
        return '$startDate - $endDate';
      }
    }
    return 'Date range not available';
  }

  // Get severity color
  Color getSeverityColor() {
    final severity = getOverallSeverity().toLowerCase();
    switch (severity) {
      case 'mild':
      case 'low':
        return Colors.green;
      case 'moderate':
      case 'medium':
        return Colors.orange;
      case 'severe':
      case 'high':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Default management tips if none from API
  List<Map<String, dynamic>> _getDefaultManagementTips() {
    return [
      {
        'title': 'Stress Management',
        'tips': [
          'Practice deep breathing, meditation, or gentle yoga to reduce stress.',
          'Maintain a balanced routine to avoid overexertion.',
          'Engage in activities you enjoy, such as reading or listening to music, to relax.',
        ]
      },
      {
        'title': 'Joint Care & Pain Relief',
        'tips': [
          'Apply heat or cold therapy as needed.',
          'Gentle stretching and low-impact exercises.',
          'Maintain good posture and ergonomics.',
        ]
      },
    ];
  }

  // Get report summary for display
  Map<String, dynamic> getReportSummary() {
    return {
      'dateRange': _getFormattedDateRange(),
      'frequentSymptoms': getFrequentSymptoms(),
      'commonTriggers': getCommonTriggers(),
      'overallSeverity': getOverallSeverity(),
      'severityColor': getSeverityColor(),
      'managementTips': getManagementTips(),
      'hasData': currentReport.value != null,
      'reportId': reportId,
    };
  }

  // ADDED: Debug method to print current report structure
  void _debugPrintReportData() {
    print("🔍 === REPORT DEBUG INFO ===");
    print("📊 Report ID: $reportId");
    print("📅 Date Range: ${_getFormattedDateRange()}");
    print("📊 Current Report Keys: ${currentReport.value?.keys}");

    final report = currentReport.value;
    if (report != null) {
      if (report['report'] != null) {
        print("📊 Report.report Keys: ${report['report'].keys}");
        print("📊 Report.report Content: ${report['report']}");
      }
      if (report['data'] != null) {
        print("📊 Report.data Keys: ${report['data'].keys}");
      }
    }

    print("📊 Parsed Frequent Symptoms: ${getFrequentSymptoms()}");
    print("📊 Parsed Common Triggers: ${getCommonTriggers()}");
    print("📊 Parsed Overall Severity: ${getOverallSeverity()}");
    print("📊 Parsed Management Tips Count: ${getManagementTips().length}");
    print("🔍 === END DEBUG INFO ===");
  }

  // Enhanced debug method to print current report structure
  void debugReportStructure() {
    _debugPrintReportData();
  }

  // NEW: Get symptoms visualization data for pie chart
  Map<String, int> getSymptomsVisualizationData() {
    try {
      final report = currentReport.value;
      if (report == null) return {};

      // Try multiple possible locations for symptoms visualization data
      final locations = [
        report['report']?['symptoms_visualization']?['symptoms_count'],
        report['data']?['symptoms_visualization']?['symptoms_count'],
        report['symptoms_visualization']?['symptoms_count'],
      ];

      for (final location in locations) {
        if (location != null && location is Map) {
          final symptomsData = <String, int>{};
          location.forEach((key, value) {
            if (value is int && value > 0) {
              symptomsData[key.toString()] = value;
            } else if (value is String) {
              final intValue = int.tryParse(value);
              if (intValue != null && intValue > 0) {
                symptomsData[key.toString()] = intValue;
              }
            }
          });

          if (symptomsData.isNotEmpty) {
            print("✅ Found symptoms visualization data: $symptomsData");
            return symptomsData;
          }
        }
      }

      print("⚠️ No symptoms visualization data found");
    } catch (e) {
      print("⚠️ Error getting symptoms visualization data: $e");
    }
    return {};
  }

  // NEW: Get triggers visualization data for pie chart
  Map<String, int> getTriggersVisualizationData() {
    try {
      final report = currentReport.value;
      if (report == null) return {};

      // Try multiple possible locations for triggers visualization data
      final locations = [
        report['report']?['symptoms_visualization']?['triggers_count'],
        report['data']?['symptoms_visualization']?['triggers_count'],
        report['symptoms_visualization']?['triggers_count'],
      ];

      for (final location in locations) {
        if (location != null && location is Map) {
          final triggersData = <String, int>{};
          location.forEach((key, value) {
            if (value is int && value > 0) {
              triggersData[key.toString()] = value;
            } else if (value is String) {
              final intValue = int.tryParse(value);
              if (intValue != null && intValue > 0) {
                triggersData[key.toString()] = intValue;
              }
            }
          });

          if (triggersData.isNotEmpty) {
            print("✅ Found triggers visualization data: $triggersData");
            return triggersData;
          }
        }
      }

      print("⚠️ No triggers visualization data found");
    } catch (e) {
      print("⚠️ Error getting triggers visualization data: $e");
    }
    return {};
  }

  // NEW: Get logs data for display
  List<Map<String, dynamic>> getLogsData() {
    try {
      final report = currentReport.value;
      if (report == null) return [];

      // Try multiple possible locations for logs data
      final locations = [
        report['report']?['logs'],
        report['data']?['logs'],
        report['logs'],
      ];

      for (final location in locations) {
        if (location != null && location is List) {
          final logsData = <Map<String, dynamic>>[];

          for (var log in location) {
            if (log is Map) {
              logsData.add(Map<String, dynamic>.from(log));
            }
          }

          if (logsData.isNotEmpty) {
            print("✅ Found logs data: ${logsData.length} logs");
            return logsData;
          }
        }
      }

      print("⚠️ No logs data found");
    } catch (e) {
      print("⚠️ Error getting logs data: $e");
    }
    return [];
  }

  // Load user's reports list
  Future<void> loadUserReports() async {
    try {
      isLoadingReportsList.value = true;

      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString();

      if (userId == null || userId.isEmpty) {
        throw Exception('User ID not found');
      }

      print("📊 Loading reports list for user $userId");

      final response = await _authService.getUserReports(userId: userId);

      if (response['status'] == 'success' && response['data'] != null) {
        final reports = response['data'] as List<dynamic>;

        userReports.clear();
        for (var reportItem in reports) {
          userReports.add({
            'id': reportItem['id']?.toString() ?? '',
            'title': reportItem['title']?.toString() ?? 'Insight Report',
            'date_created': reportItem['date_created']?.toString() ?? '',
            'start_date': reportItem['start_date']?.toString() ?? '',
            'end_date': reportItem['end_date']?.toString() ?? '',
            'status': reportItem['status']?.toString() ?? 'completed',
          });
        }

        print("✅ Loaded ${userReports.length} reports");
      } else {
        print("⚠️ No reports found or error: ${response['message']}");
      }
    } catch (e) {
      print("❌ Error loading user reports: $e");
    } finally {
      isLoadingReportsList.value = false;
    }
  }

  // Share report functionality
  void shareReport() {
    Get.snackbar(
      'Share Report',
      'Report sharing feature coming soon',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  // Export report functionality
  void exportReport() {
    Get.snackbar(
      'Export Report',
      'Report export feature coming soon',
      snackPosition: SnackPosition.TOP,
    );
  }

  // Navigate back
  void goBack() {
    Get.back();
  }

  // Clear report data
  void clearReport() {
    currentReport.value = null;
    reportMetadata.value = null;
    errorMessage.value = '';
    reportId = null;
    startDate = null;
    endDate = null;
    fromDate = null;
    toDate = null;
    userId = null;
  }
}