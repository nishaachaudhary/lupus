import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/icons.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'dart:math' as math;

import 'insight_report_controller.dart';

class InsightReportScreen extends StatelessWidget {
  const InsightReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize controller
    final controller = Get.put(InsightReportController());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Container(
          width: 31,
          height: 51,
          margin: const EdgeInsets.only(left: Dimensions.fontSizeLarge, top: Dimensions.fontSizeExtraSmall),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(width: 1, color: Colors.grey.shade300),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
            onPressed: () => Get.back(),
            splashRadius: 20,
          ),
        ),
        centerTitle: true,
        title: Text(
          "Insight Report",
          style: mediumStyle.copyWith(fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          // Show loading state
          if (controller.isLoading.value) {
            return _buildLoadingState();
          }

          // Show error state
          if (controller.errorMessage.value.isNotEmpty) {
            return _buildErrorState(controller.errorMessage.value, controller);
          }

          // Show main content
          return _buildMainContent(controller);
        }),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: CustomColors.purpleColor,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String errorMessage, InsightReportController controller) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            SizedBox(height: 16),
            Text(
              'Error Loading Report',
              style: semiBoldStyle.copyWith(
                fontSize: Dimensions.fontSizeOverLarge,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 8),
            Text(
              errorMessage,
              style: regularStyle.copyWith(
                fontSize: Dimensions.fontSizeDefault,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => controller.goBack(),
              style: ElevatedButton.styleFrom(
                backgroundColor: CustomColors.purpleColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Go Back',
                style: mediumStyle.copyWith(
                  color: Colors.white,
                  fontSize: Dimensions.fontSizeDefault,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(InsightReportController controller) {
    return Column(
      children: [


        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Range
                _buildDateRange(controller),
                SizedBox(height: 16),

                _buildInsightReport(controller),
                SizedBox(height: 16),


                // Management Tips
                _buildManagementTips(controller),
                SizedBox(height: 16),


                // Logs Section
                _buildLogsSection(controller),
                SizedBox(height: 32),

                // Symptoms Visualization (Pie Chart)
                _buildSymptomsVisualization(controller),
                SizedBox(height: 16),

                // Triggers Visualization (Pie Chart)
                _buildTriggersVisualization(controller),
                SizedBox(height: 16),




              ],
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildDateRange(InsightReportController controller) {
    final reportSummary = controller.getReportSummary();

    return Text(
      reportSummary['dateRange'] ?? 'Date range not available',
      style: mediumStyle.copyWith(
        fontSize: Dimensions.fontSizeExtraLarge,
        color: CustomColors.blackColor,
      ),
    );
  }

  // NEW: Symptoms Visualization with Pie Chart
  Widget _buildSymptomsVisualization(InsightReportController controller) {
    final symptomsData = controller.getSymptomsVisualizationData();

    if (symptomsData.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            offset: Offset(0, 0),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Symptoms Visualization',
              style: mediumStyle.copyWith(
                fontSize: Dimensions.fontSizeOverLarge,
                color: CustomColors.insightPurple,
              ),
            ),
            SizedBox(height: 16),
            Container(

              child: Row(
                children: [
                  // Pie Chart
                  CustomPaint(
                    size: Size(120, 180),
                    painter: PieChartPainter(
                      data: symptomsData,
                      colors: _getSymptomsColors(),
                    ),
                  ),
                  SizedBox(width: 24),
                  // Legend
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: symptomsData.entries.map((entry) {
                        final index = symptomsData.keys.toList().indexOf(entry.key);
                        final color = _getSymptomsColors()[index % _getSymptomsColors().length];
                        final percentage = _calculatePercentage(entry.value, symptomsData.values.reduce((a, b) => a + b));

                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${_capitalizeFirst(entry.key)} (${percentage.toStringAsFixed(0)}%)',
                                  style: semiLightStyle.copyWith(
                                    fontSize: Dimensions.fontSizeDefault,
                                    color: CustomColors.blackColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Triggers Visualization with Pie Chart
  Widget _buildTriggersVisualization(InsightReportController controller) {
    final triggersData = controller.getTriggersVisualizationData();

    if (triggersData.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            offset: Offset(0, 0),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Triggers Visualization',
              style: mediumStyle.copyWith(
                fontSize: Dimensions.fontSizeOverLarge,
                color: CustomColors.insightPurple,
              ),
            ),
            SizedBox(height: 16),
            Container(

              child: Row(
                children: [
                  // Pie Chart
                  CustomPaint(
                    size: Size(120, 180),
                    painter: PieChartPainter(
                      data: triggersData,
                      colors: _getTriggersColors(),
                    ),
                  ),
                  SizedBox(width: 24),
                  // Legend
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: triggersData.entries.map((entry) {
                        final index = triggersData.keys.toList().indexOf(entry.key);
                        final color = _getTriggersColors()[index % _getTriggersColors().length];
                        final percentage = _calculatePercentage(entry.value, triggersData.values.reduce((a, b) => a + b));

                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${_capitalizeFirst(entry.key)} (${percentage.toStringAsFixed(0)}%)',
                                  style: semiLightStyle.copyWith(
                                    fontSize: Dimensions.fontSizeDefault,
                                    color: CustomColors.blackColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Logs Section
  Widget _buildLogsSection(InsightReportController controller) {
    final logs = controller.getLogsData();

    if (logs.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        ...logs.map((log) => _buildLogItem(log)).toList(),
      ],
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    final date = log['log_date'] ?? log['date'] ?? '';
    final symptoms = log['symptoms'] ?? '';
    final triggers = log['triggers'] ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            offset: Offset(0, 0),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [


          Row(
            children: [
              SvgPicture.asset(CustomIcons.calenderIcon),
              const SizedBox(width: 6),
              Text(
                _formatLogDate(date),
                style: mediumStyle.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                  color: CustomColors.greyTextColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Symptoms
          if (symptoms.isNotEmpty) ...[
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Logged Symptom(s): ',
                    style: mediumStyle.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                    ),
                  ),
                  TextSpan(
                    text: symptoms,
                    style: mediumStyle.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: CustomColors.insightPurple,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 14),
          ],

          // Triggers
          if (triggers.isNotEmpty) ...[
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Triggers: ',
                    style: mediumStyle.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: Colors.black,
                    ),
                  ),
                  TextSpan(
                    text: triggers,
                    style: mediumStyle.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: CustomColors.insightPurple,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightReport(InsightReportController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            offset: Offset(0, 0),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildFrequentSymptoms(controller),
            _buildCommonTriggers(controller),
            _buildOverallSeverity(controller),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequentSymptoms(InsightReportController controller) {
    final symptoms = controller.getFrequentSymptoms();

    return _buildReportSection(
      title: 'Frequent Symptoms',
      items: symptoms.isNotEmpty ? symptoms : ['No symptoms data available'],
      titleColor: CustomColors.purpleColor,
    );
  }

  Widget _buildCommonTriggers(InsightReportController controller) {
    final triggers = controller.getCommonTriggers();

    return _buildReportSection(
      title: 'Common Triggers',
      items: triggers.isNotEmpty ? triggers : ['No triggers data available'],
      titleColor: CustomColors.purpleColor,
    );
  }

  Widget _buildOverallSeverity(InsightReportController controller) {
    final severity = controller.getOverallSeverity();
    final severityColor = controller.getSeverityColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overall Severity',
          style: mediumStyle.copyWith(
            fontSize: Dimensions.fontSizeOverLarge,
            color: CustomColors.insightPurple,
          ),
        ),
        SizedBox(height: 6),
        Container(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: severityColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Text(
                severity,
                style: semiLightStyle.copyWith(
                  fontSize: Dimensions.fontSizeLarge,
                  color: severityColor,
                ),

              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManagementTips(InsightReportController controller) {
    final managementTips = controller.getManagementTips();

    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            offset: Offset(0, 0),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suggested Management Tips or Solutions',
              style: semiBoldStyle.copyWith(
                fontSize: Dimensions.fontSizeOverLarge,
                color: CustomColors.purpleColor,
              ),
            ),
            SizedBox(height: 16),

            ...managementTips.asMap().entries.map((entry) {
              final index = entry.key;
              final tip = entry.value;

              return _buildManagementTipSection(
                index + 1,
                tip['title'] ?? 'Management Tip',
                List<String>.from(tip['tips'] ?? []),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildReportSection({
    required String title,
    required List<String> items,
    required Color titleColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: mediumStyle.copyWith(
            fontSize: Dimensions.fontSizeOverLarge,
            color: CustomColors.insightPurple,
          ),
        ),
        SizedBox(height: 8),

        ...items.map((item) => Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: EdgeInsets.only(top: 8, right: 12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  item,
                  style: semiLightStyle.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                    color: CustomColors.blackColor,

                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildManagementTipSection(int number, String title, List<String> tips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number. $title',
          style: semiLightStyle.copyWith(
            fontSize: Dimensions.fontSizeLarge,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 12),

        ...tips.map((tip) => Padding(
          padding: EdgeInsets.only(bottom: 8, left: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 4,
                margin: EdgeInsets.only(top: 10, right: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  tip,
                  style: semiLightStyle.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                    color: CustomColors.blackColor,
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }

  // Helper methods for pie chart
  List<Color> _getSymptomsColors() {
    return [
      Color(0xFF8B5CF6), // Purple
      Color(0xFFFF9500), // Orange
      Color(0xFF10B981), // Green
      Color(0xFF3B82F6), // Blue
      Color(0xFFEF4444), // Red
      Color(0xFFF59E0B), // Amber
    ];
  }

  List<Color> _getTriggersColors() {
    return [
      Color(0xFF06B6D4), // Cyan
      Color(0xFFEC4899), // Pink
      Color(0xFF84CC16), // Lime
      Color(0xFF6366F1), // Indigo
      Color(0xFFF97316), // Orange
      Color(0xFF14B8A6), // Teal
    ];
  }

  double _calculatePercentage(int value, int total) {
    if (total == 0) return 0;
    return (value / total) * 100;
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  String _formatLogDate(String dateString) {
    try {
      if (dateString.isEmpty) return 'No date';

      // Try to parse the date string
      DateTime date = DateTime.parse(dateString);

      // Format as "25 March 2025"
      final day = date.day;
      final monthNames = [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      final month = monthNames[date.month];
      final year = date.year;

      return '$day $month $year';
    } catch (e) {
      // If parsing fails, return the original string
      return dateString;
    }
  }
}

class PieChartPainter extends CustomPainter {
  final Map<String, int> data;
  final List<Color> colors;

  PieChartPainter({required this.data, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final total = data.values.reduce((a, b) => a + b);

    final paint = Paint()
      ..style = PaintingStyle.fill;

    double startAngle = -math.pi / 2; // Start from top

    data.entries.toList().asMap().forEach((index, entry) {
      final sweepAngle = (entry.value / total) * 2 * math.pi;
      paint.color = colors[index % colors.length];

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    });

    // Draw center circle for donut effect (increased size for thinner width)
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.6, paint); // Changed from 0.4 to 0.6
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}