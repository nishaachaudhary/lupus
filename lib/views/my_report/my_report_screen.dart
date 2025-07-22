import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/icons.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/my_report/my_report_controller.dart';

import 'package:lupus_care/views/report/insight_report_controller.dart';

import 'package:lupus_care/views/report/report_detail_screen.dart'; // Add this import

class MyReportsScreen extends StatelessWidget {
  final controller = Get.put(AllReportsController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Container(
          width: 31,
          height: 51,
          margin: const EdgeInsets.only(
            left: Dimensions.fontSizeLarge,
            top: Dimensions.fontSizeExtraSmall,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(width: 1, color: Colors.grey.shade300),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
            splashRadius: 20,
          ),
        ),
        centerTitle: true,
        title: Text(
          "My Reports",
          style: mediumStyle.copyWith(fontSize: 18),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Reports",
                  style: mediumStyle.copyWith(
                    fontSize: Dimensions.fontSizeExtraLarge,
                    color: CustomColors.blackColor,
                  ),
                ),
                // Summary badge

              ],
            ),
            const SizedBox(height: 24),

            // Reports List with API data
            Expanded(
              child: Obx(() {
                // Show loading indicator
                if (controller.isLoading.value && controller.allReports.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("Loading your reports..."),
                      ],
                    ),
                  );
                }

                // Show error message if there's an error and no data
                if (controller.errorMessage.value.isNotEmpty && controller.allReports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          controller.errorMessage.value,
                          style: semiLightStyle.copyWith(
                            fontSize: Dimensions.fontSizeLarge,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: controller.refreshReports,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CustomColors.purpleColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            "Retry",
                            style: mediumStyle.copyWith(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Show empty state if no reports
                if (controller.allReports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No reports found",
                          style: mediumStyle.copyWith(
                            fontSize: Dimensions.fontSizeExtraLarge,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Generate your first report to see insights",
                          style: semiLightStyle.copyWith(
                            fontSize: Dimensions.fontSizeLarge,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Show reports with pull-to-refresh
                return RefreshIndicator(
                  onRefresh: controller.refreshReports,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: controller.allReports.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final report = controller.allReports[index];
                      return _buildReportCard(report);
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    // Extract report data
    final dateRange = _getDateRange(report);
    final symptoms = _getSymptoms(report);
    final triggers = _getTriggers(report);
    final severity = _getSeverity(report);
    final severityColor = _getSeverityColor(severity);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CustomColors.lightPurpleColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(width: 2, color: CustomColors.lightPinkColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Range and View Report Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SvgPicture.asset(CustomIcons.calenderIcon),
                  const SizedBox(width: 8),
                  Text(
                    dateRange,
                    style: semiLightStyle.copyWith(
                      fontSize: Dimensions.fontSizeLarge,
                      color: CustomColors.blackColor,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => _viewReport(report),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomColors.purpleColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(38),
                  ),
                ),
                child: Text(
                  "View Report",
                  style: mediumStyle.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Full width Divider
          Divider(
            height: 2,
            thickness: 1.5,
            color: CustomColors.lightPinkColor,
          ),
          const SizedBox(height: 12),

          // Frequent Symptoms
          if (symptoms.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Frequent Symptom(s) : ",
                  style: mediumStyle.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                    color: CustomColors.blackColor,
                  ),
                ),
                Flexible(
                  child: Text(
                    symptoms,
                    style: mediumStyle.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: CustomColors.insightPurple,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Common Triggers
          if (triggers.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Common Triggers : ",
                  style: mediumStyle.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                    color: CustomColors.blackColor,
                  ),
                ),
                Flexible(
                  child: Text(
                    triggers,
                    style: mediumStyle.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: CustomColors.insightPurple,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Overall Severity
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Overall Severity : ",
                style: mediumStyle.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                  color: CustomColors.blackColor,
                ),
              ),
              Text(
                severity,
                style: mediumStyle.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                  color:  CustomColors.insightPurple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper methods to extract data from report
  String _getDateRange(Map<String, dynamic> report) {
    // Try different possible field names for dates
    final startDate = report['start_date']?.toString() ??
        report['from_date']?.toString() ??
        report['date_from']?.toString() ??
        report['created_at']?.toString() ?? '';

    final endDate = report['end_date']?.toString() ??
        report['to_date']?.toString() ??
        report['date_to']?.toString() ?? '';

    if (startDate.isNotEmpty && endDate.isNotEmpty) {
      try {
        final start = DateTime.parse(startDate);
        final end = DateTime.parse(endDate);

        final formatter = DateFormat('dd - dd MMMM yyyy');
        if (start.month == end.month && start.year == end.year) {
          return '${start.day} - ${end.day} ${DateFormat('MMMM yyyy').format(end)}';
        } else {
          return '${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}';
        }
      } catch (e) {
        print('Error parsing dates: $e');
      }
    }

    // Fallback to single date or default
    if (startDate.isNotEmpty) {
      try {
        final date = DateTime.parse(startDate);
        return DateFormat('dd MMMM yyyy').format(date);
      } catch (e) {
        return startDate;
      }
    }

    return 'No date available';
  }

  String _getSymptoms(Map<String, dynamic> report) {
    // Try different possible field names for symptoms
    final symptoms = report['symptoms']?.toString() ??
        report['frequent_symptoms']?.toString() ??
        report['common_symptoms']?.toString() ?? '';

    if (symptoms.isEmpty) {
      return 'No symptoms recorded';
    }

    return symptoms;
  }

  String _getTriggers(Map<String, dynamic> report) {
    // Try different possible field names for triggers
    final triggers = report['triggers']?.toString() ??
        report['common_triggers']?.toString() ??
        report['frequent_triggers']?.toString() ?? '';

    if (triggers.isEmpty) {
      return 'No triggers recorded';
    }

    return triggers;
  }

  String _getSeverity(Map<String, dynamic> report) {
    // Try different possible field names for severity
    final severity = report['severity']?.toString() ??
        report['overall_severity']?.toString() ??
        report['severity_level']?.toString() ?? '';

    if (severity.isEmpty) {
      return 'Not specified';
    }

    // Capitalize first letter
    return severity[0].toUpperCase() + severity.substring(1).toLowerCase();
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'low':
      case 'mild':
        return Colors.green;
      case 'moderate':
      case 'medium':
        return Colors.orange;
      case 'high':
      case 'severe':
        return Colors.red;
      default:
        return CustomColors.purpleColor;
    }
  }

  // Navigate to insight report with report's date range
  void _viewReport(Map<String, dynamic> report) async {
    try {
      // Extract dates from the report
      final startDateStr = report['start_date']?.toString() ??
          report['from_date']?.toString() ??
          report['date_from']?.toString() ??
          report['created_at']?.toString() ?? '';

      final endDateStr = report['end_date']?.toString() ??
          report['to_date']?.toString() ??
          report['date_to']?.toString() ?? '';

      DateTime? startDate;
      DateTime? endDate;

      // Parse start date
      if (startDateStr.isNotEmpty) {
        try {
          startDate = DateTime.parse(startDateStr);
        } catch (e) {
          print('Error parsing start date: $e');
        }
      }

      // Parse end date
      if (endDateStr.isNotEmpty) {
        try {
          endDate = DateTime.parse(endDateStr);
        } catch (e) {
          print('Error parsing end date: $e');
        }
      }

      // If we don't have both dates, use a default range
      if (startDate == null || endDate == null) {
        final now = DateTime.now();
        endDate = now;
        startDate = now.subtract(Duration(days: 7)); // Default to last 7 days

        print('Using default date range: ${startDate} to ${endDate}');
      }

      // Navigate directly to insight report screen with date parameters
      Get.to(
            () => InsightReportScreen(),
        arguments: {
          'startDate': startDate!,
          'endDate': endDate!,
          'autoGenerate': true, // Flag to auto-generate on screen load
        },
      );

    } catch (e) {
      print('Error viewing report: $e');
      Get.snackbar(
        'Error',
        'Failed to open report. Please try again.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}