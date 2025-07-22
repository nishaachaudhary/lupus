import 'package:get/get.dart';
import 'package:lupus_care/data/api/auth_service.dart';
import 'package:lupus_care/helper/storage_service.dart';

class AllReportsController extends GetxController {
  final AuthService _authService = AuthService();

  // Observables
  var isLoading = false.obs;
  var errorMessage = ''.obs;
  var allReports = <Map<String, dynamic>>[].obs;
  var hasData = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadAllReports();
  }

  // Load all reports from API
  Future<void> loadAllReports() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString();

      if (userId == null) {
        throw Exception('User ID not found');
      }

      print("🔄 Loading all reports for user: $userId");

      final response = await _authService.getAllReports(userId: userId);

      if (response['status'] == 'success') {
        final reports = response['data'] as List<dynamic>? ?? [];

        allReports.value = reports.map((report) {
          if (report is Map<String, dynamic>) {
            return report;
          } else {
            return <String, dynamic>{};
          }
        }).toList();

        hasData.value = allReports.isNotEmpty;

        print("✅ Successfully loaded ${allReports.length} reports");
      } else {
        errorMessage.value = response['message'] ?? 'Failed to load reports';
        allReports.clear();
        hasData.value = false;

        print("❌ Failed to load reports: ${errorMessage.value}");
      }
    } catch (e) {
      print("❌ Error loading all reports: $e");
      errorMessage.value = 'Error loading reports: $e';
      allReports.clear();
      hasData.value = false;
    } finally {
      isLoading.value = false;
    }
  }

  // Refresh reports
  Future<void> refreshReports() async {
    await loadAllReports();
  }

  // Get reports by type/category if available
  List<Map<String, dynamic>> getReportsByType(String type) {
    return allReports.where((report) {
      final reportType = report['type']?.toString().toLowerCase() ?? '';
      return reportType == type.toLowerCase();
    }).toList();
  }

  // Get recent reports (last 10)
  List<Map<String, dynamic>> getRecentReports({int limit = 10}) {
    if (allReports.isEmpty) return [];

    // Sort by date if available, otherwise return as is
    final sortedReports = List<Map<String, dynamic>>.from(allReports);

    try {
      sortedReports.sort((a, b) {
        final dateA = a['created_at']?.toString() ?? a['date']?.toString() ?? '';
        final dateB = b['created_at']?.toString() ?? b['date']?.toString() ?? '';

        if (dateA.isEmpty || dateB.isEmpty) return 0;

        final parsedDateA = DateTime.tryParse(dateA);
        final parsedDateB = DateTime.tryParse(dateB);

        if (parsedDateA == null || parsedDateB == null) return 0;

        return parsedDateB.compareTo(parsedDateA); // Most recent first
      });
    } catch (e) {
      print("⚠️ Error sorting reports by date: $e");
    }

    return sortedReports.take(limit).toList();
  }

  // Get report by ID
  Map<String, dynamic>? getReportById(String reportId) {
    try {
      return allReports.firstWhere(
            (report) => report['id']?.toString() == reportId ||
            report['report_id']?.toString() == reportId,
      );
    } catch (e) {
      print("⚠️ Report with ID $reportId not found");
      return null;
    }
  }

  // Get summary statistics
  Map<String, dynamic> getReportsSummary() {
    if (allReports.isEmpty) {
      return {
        'total_reports': 0,
        'recent_reports': 0,
        'oldest_date': '',
        'latest_date': '',
      };
    }

    final dates = allReports
        .map((report) => report['created_at']?.toString() ?? report['date']?.toString() ?? '')
        .where((date) => date.isNotEmpty)
        .map((dateStr) => DateTime.tryParse(dateStr))
        .where((date) => date != null)
        .cast<DateTime>()
        .toList();

    dates.sort();

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(Duration(days: 30));
    final recentReports = dates.where((date) => date.isAfter(thirtyDaysAgo)).length;

    return {
      'total_reports': allReports.length,
      'recent_reports': recentReports,
      'oldest_date': dates.isNotEmpty ? dates.first.toIso8601String() : '',
      'latest_date': dates.isNotEmpty ? dates.last.toIso8601String() : '',
    };
  }

  // Search reports by keyword
  List<Map<String, dynamic>> searchReports(String keyword) {
    if (keyword.isEmpty) return allReports;

    final lowercaseKeyword = keyword.toLowerCase();

    return allReports.where((report) {
      final title = report['title']?.toString().toLowerCase() ?? '';
      final description = report['description']?.toString().toLowerCase() ?? '';
      final type = report['type']?.toString().toLowerCase() ?? '';
      final symptoms = report['symptoms']?.toString().toLowerCase() ?? '';
      final triggers = report['triggers']?.toString().toLowerCase() ?? '';

      return title.contains(lowercaseKeyword) ||
          description.contains(lowercaseKeyword) ||
          type.contains(lowercaseKeyword) ||
          symptoms.contains(lowercaseKeyword) ||
          triggers.contains(lowercaseKeyword);
    }).toList();
  }

  // Format date for display
  String formatReportDate(Map<String, dynamic> report) {
    final dateStr = report['created_at']?.toString() ??
        report['date']?.toString() ??
        report['log_date']?.toString() ?? '';

    if (dateStr.isEmpty) return 'No date';

    try {
      final date = DateTime.parse(dateStr);
      final day = date.day;
      final monthNames = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final month = monthNames[date.month];
      final year = date.year;

      return '$day $month $year';
    } catch (e) {
      return dateStr; // Return original if parsing fails
    }
  }

  // Navigate back or handle errors
  void goBack() {
    Get.back();
  }

  // Clear error message
  void clearError() {
    errorMessage.value = '';
  }
}