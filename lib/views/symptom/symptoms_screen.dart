import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/icons.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/symptom/symptoms_controller.dart';

class SymptomScreen extends StatelessWidget {
  final controller = Get.put(SymptomsController());
  String todayDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Symptoms & Trigger',
          style: mediumStyle.copyWith(fontSize: Dimensions.fontSizeOverLarge),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
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
                  "My Insights",
                  style: mediumStyle.copyWith(
                    fontSize: Dimensions.fontSizeExtraLarge,
                    color: CustomColors.blackColor,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Get.toNamed('/newLog')?.then((_) {
                      // Refresh logs when returning from Add New Log screen
                      controller.refreshLogs();
                    });
                  },
                  icon: Icon(Icons.add, size: 18, color: Colors.white),
                  label: Text(
                    "Add New Log",
                    style: mediumStyle.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CustomColors.purpleColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Log List with API data
            Expanded(
              child: Obx(() {
                // Show loading indicator
                if (controller.isLoading.value && controller.logs.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                // Show error message if there's an error and no data
                if (controller.errorMessage.value.isNotEmpty && controller.logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
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
                          onPressed: controller.refreshLogs,
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

                // Show empty state if no logs
                if (controller.logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_note,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No logs found",
                          style: mediumStyle.copyWith(
                            fontSize: Dimensions.fontSizeExtraLarge,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Start by adding your first symptom log",
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

                // Show logs with pull-to-refresh
                return RefreshIndicator(
                  onRefresh: controller.refreshLogs,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: controller.logs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final log = controller.logs[index];
                      return _buildLogItem(
                        date: controller.formatDate(log['date'] ?? ''),
                        time: controller.formatTime(log['time'] ?? ''),
                        symptoms: log['symptoms'] ?? 'No symptoms recorded',
                        triggers: log['triggers'] ?? 'No triggers recorded',
                        onTap: () {
                          // Navigate to log details if needed
                          // Get.toNamed('/logDetails', arguments: log);
                        },
                      );
                    },
                  ),
                );
              }),
            ),

            // Generate Report Button
            Container(
              margin: const EdgeInsets.only(top: 16),
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => showReportDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomColors.greenColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  "Generate Report",
                  style: semiBoldStyle.copyWith(
                    fontSize: Dimensions.fontSizeExtraLarge,
                    color: CustomColors.darkGreenColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogItem({
    required String date,
    required String time,
    required String symptoms,
    required String triggers,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CustomColors.lightPurpleColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(width: 2, color: CustomColors.lightPinkColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date & Time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SvgPicture.asset(CustomIcons.calenderIcon),
                    const SizedBox(width: 6),
                    Text(
                      date,
                      style: mediumStyle.copyWith(
                        fontSize: Dimensions.fontSizeLarge,
                      ),
                    ),
                  ],
                ),
                Text(
                  "Logged At $time",
                  style: mediumStyle.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                    color: CustomColors.greyTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Full width Divider
            Row(
              children: [
                Expanded(
                  child: Divider(
                    height: 2,
                    thickness: 1.5,
                    color: CustomColors.lightPinkColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Symptoms
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Logged Symptom : ",
                  style: mediumStyle.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    symptoms,
                    style: mediumStyle.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: CustomColors.purpleColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Triggers
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Triggers:",
                  style: mediumStyle.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    triggers,
                    style: mediumStyle.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: CustomColors.purpleColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void showReportDialog(BuildContext context) {
    final dateFormat = DateFormat('dd-MM-yyyy');
    DateTime? fromDate;
    DateTime? toDate;

    // Get the controller instance
    final SymptomsController controller = Get.find<SymptomsController>();

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing during loading
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Generate Insight Report",
                          style: mediumStyle.copyWith(
                            fontSize: Dimensions.fontSizeExtraLarge,
                            color: CustomColors.blackColor,
                          ),
                        ),
                        // FIXED: Only show close button when not generating
                        Obx(() => controller.isGeneratingReport.value
                            ? SizedBox(width: 24) // Placeholder to maintain layout
                            : GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Icon(Icons.close, color: CustomColors.blackColor),
                        )
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Full-width Divider
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: CustomColors.textBorderColor,
                    ),

                    const SizedBox(height: 8),

                    // FIXED: Show different text based on loading state
                    Obx(() => Text(
                      controller.isGeneratingReport.value
                          ? "Generating your personalized insight report..."
                          : "Pick a Date Range to Generate Your Report",
                      style: semiLightStyle.copyWith(fontSize: Dimensions.fontSizeExtraLarge),
                      textAlign: TextAlign.center,
                    )),

                    const SizedBox(height: 20),

                    // FIXED: Show loading indicator or date picker based on state
                    Obx(() => controller.isGeneratingReport.value
                        ? Column(
                      children: [
                        // Large loading indicator
                        Container(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            children: [
                              SizedBox(
                                width: 50,
                                height: 50,
                                child: CircularProgressIndicator(
                                  strokeWidth: 4,
                                  valueColor: AlwaysStoppedAnimation<Color>(CustomColors.purpleColor),
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                "Please wait while we analyze your data...",
                                style: regularStyle.copyWith(
                                  fontSize: Dimensions.fontSizeDefault,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                        :
                    // Date Picker Row (only show when not loading)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: CustomColors.textBorderColor),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          // From Date
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final selectedDate = await showDatePicker(
                                  context: context,
                                  initialDate: fromDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(), // Don't allow future dates
                                  builder: (context, child) {
                                    return Theme(
                                      data: ThemeData.light().copyWith(
                                        primaryColor: CustomColors.purpleColor,
                                        buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (selectedDate != null) {
                                  setState(() {
                                    fromDate = selectedDate;
                                    // Reset toDate if it's before fromDate
                                    if (toDate != null && toDate!.isBefore(selectedDate)) {
                                      toDate = null;
                                    }
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("From", style: semiLightStyle.copyWith(fontSize: Dimensions.fontSizeDefault, color: CustomColors.grey)),
                                        SvgPicture.asset(
                                          CustomIcons.calenderIcon,
                                          height: 16,
                                          width: 16,
                                          colorFilter: ColorFilter.mode(CustomColors.grey, BlendMode.srcIn),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      fromDate != null ? dateFormat.format(fromDate!) : 'Select Date',
                                      style: mediumStyle.copyWith(
                                        color: fromDate != null ? Colors.black : CustomColors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Container(
                            height: 48,
                            width: 1,
                            color: CustomColors.textBorderColor,
                          ),
                          // To Date
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final selectedDate = await showDatePicker(
                                  context: context,
                                  initialDate: toDate ?? (fromDate ?? DateTime.now()),
                                  firstDate: fromDate ?? DateTime(2020),
                                  lastDate: DateTime.now(), // Don't allow future dates
                                  builder: (context, child) {
                                    return Theme(
                                      data: ThemeData.light().copyWith(
                                        primaryColor: CustomColors.purpleColor,
                                        buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (selectedDate != null) {
                                  setState(() {
                                    toDate = selectedDate;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("To", style: semiLightStyle.copyWith(fontSize: Dimensions.fontSizeDefault, color: CustomColors.grey)),
                                        SvgPicture.asset(
                                          CustomIcons.calenderIcon,
                                          height: 16,
                                          width: 16,
                                          colorFilter: ColorFilter.mode(CustomColors.grey, BlendMode.srcIn),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      toDate != null ? dateFormat.format(toDate!) : 'Select Date',
                                      style: mediumStyle.copyWith(
                                        color: toDate != null ? Colors.black : CustomColors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ),

                    const SizedBox(height: 24),

                    // Full-width Divider
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: CustomColors.textBorderColor,
                    ),

                    const SizedBox(height: 16),

                    // FIXED: Action Buttons - Hide during loading
                    Obx(() => controller.isGeneratingReport.value
                        ? SizedBox.shrink() // Hide buttons during loading
                        : Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 51,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: CustomColors.buttonGrey,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(38)),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  "Cancel",
                                  style: semiBoldStyle.copyWith(
                                    fontSize: Dimensions.fontSizeLarge,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 51,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (fromDate != null && toDate != null)
                                    ? CustomColors.greenColor
                                    : CustomColors.buttonGrey,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(38)),
                              ),
                              onPressed: (fromDate != null && toDate != null)
                                  ? () async {
                                // Basic date validation first
                                if (fromDate == null || toDate == null) {
                                  Get.snackbar(
                                    'Missing Dates',
                                    'Please select both "From" and "To" dates to generate a report.',
                                    snackPosition: SnackPosition.TOP,
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                    duration: Duration(seconds: 3),
                                  );
                                  return;
                                }

                                await Future.delayed(Duration(milliseconds: 100));

                                Navigator.pop(context);




                                // Now use the NEW validation method that includes data existence checks
                                await controller.generateInsightReportWithValidation(
                                  fromDate: fromDate!,
                                  toDate: toDate!,
                                );
                              }
                                  : null,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  "Generate Report",
                                  style: semiBoldStyle.copyWith(
                                    fontSize: Dimensions.fontSizeLarge,
                                    color: (fromDate != null && toDate != null)
                                        ? CustomColors.darkGreenColor
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}