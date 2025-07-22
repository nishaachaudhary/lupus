// views/edit_medication/edit_medication_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/icons.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/views/edit_medication/edit_medication_controller.dart';

class EditMedicationScreen extends StatelessWidget {
  final controller = Get.put(EditMedicationController());

  final List<String> frequencyOptions = [
    'Once a Day',
    'Twice a Day',
    'Thrice a Day',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomColors.lightPurpleColor,
      appBar: AppBar(
        backgroundColor: CustomColors.lightPurpleColor,
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
          "Edit Medication",
          style: mediumStyle.copyWith(fontSize: 20),
        ),
      ),
      body: Obx(() {
        // Show loading overlay if necessary
        if (controller.isLoading.value) {
          return Stack(
            children: [
              _buildContent(context),
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ],
          );
        }
        return _buildContent(context);
      }),
    );
  }

  // Helper method to format time in 12-hour format
  String _formatTime12Hour(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return '${hour.toString().padLeft(2, '0')}:${minute} ${period}';
  }

  // Helper method to show 12-hour format time picker
  Future<void> _show12HourTimePicker(BuildContext context, int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: controller.reminderTimes[index],
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked != null) {
      controller.updateReminderTime(index, picked);
    }
  }

  Widget _buildContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel("Medication Name"),
          Obx(() => _buildTextField(
            controller.medicationName,
            "Enter medication name",
            icon: SvgPicture.asset(CustomIcons.drugsIcon),
            errorText: controller.medicationNameError.value.isEmpty
                ? null
                : controller.medicationNameError.value,
          )),

          _buildLabel("Number of days"),
          Obx(() => _buildTextField(
            controller.numberOfDays,
            "Enter number of days",
            icon: SvgPicture.asset(CustomIcons.calenderFillIcon),
            keyboardType: controller.daysKeyboardType,
            inputFormatters: controller.daysInputFormatters,
            errorText: controller.numberOfDaysError.value.isEmpty
                ? null
                : controller.numberOfDaysError.value,
          )),

          _buildLabel("Dosage Frequency?"),
          Obx(() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 56,
                child: DropdownButtonFormField<String>(
                  value: controller.dosageFrequency.value.isEmpty ? null : controller.dosageFrequency.value,
                  items: frequencyOptions.map((freq) {
                    return DropdownMenuItem<String>(
                      value: freq,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          freq,
                          style: mediumStyle.copyWith(color: CustomColors.blackColor),
                        ),
                      ),
                    );
                  }).toList(),
                  decoration: InputDecoration(
                    hintText: 'Please select dosage',
                    hintStyle: lightStyle.copyWith(color: CustomColors.greyTextColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: controller.dosageFrequencyError.value.isEmpty
                            ? CustomColors.textBorderColor
                            : Colors.red,
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: controller.dosageFrequencyError.value.isEmpty
                            ? CustomColors.textBorderColor
                            : Colors.red,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: CustomColors.purpleColor, width: 1),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  dropdownColor: Colors.white,
                  menuMaxHeight: 300,
                  borderRadius: BorderRadius.circular(14),
                  style: mediumStyle.copyWith(color: Colors.black),
                  onChanged: (value) {
                    if (value != null) {
                      controller.dosageFrequency.value = value;
                      controller.clearValidationErrors();
                    }
                  },
                ),
              ),
              if (controller.dosageFrequencyError.value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 16),
                  child: Text(
                    controller.dosageFrequencyError.value,
                    style: regularStyle.copyWith(
                      color: Colors.red,
                      fontSize: Dimensions.fontSizeSmall,
                    ),
                  ),
                ),
            ],
          )),

          _buildLabel("Reminder Time"),
          Obx(() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: List.generate(controller.reminderTimes.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _show12HourTimePicker(context, index),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.white,
                                border: Border.all(
                                  color: controller.reminderTimesError.value.isEmpty
                                      ? CustomColors.textBorderColor
                                      : Colors.red,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  SvgPicture.asset(CustomIcons.notificationIcon),
                                  const SizedBox(width: 12),
                                  Text(
                                    _formatTime12Hour(controller.reminderTimes[index]),
                                    style: mediumStyle.copyWith(
                                      color: CustomColors.greyColor,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        index == controller.reminderTimes.length - 1
                            ? _circleButton(Icons.add, controller.addReminderTime)
                            : _circleButton(Icons.remove, () => controller.removeReminderTime(index)),
                      ],
                    ),
                  );
                }),
              ),
              if (controller.reminderTimesError.value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 16),
                  child: Text(
                    controller.reminderTimesError.value,
                    style: regularStyle.copyWith(
                      color: Colors.red,
                      fontSize: Dimensions.fontSizeSmall,
                    ),
                  ),
                ),
            ],
          )),

          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: controller.updateMedication,
              style: ElevatedButton.styleFrom(
                backgroundColor: CustomColors.greenColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "Update Medication",
                style: semiBoldStyle.copyWith(
                  fontSize: Dimensions.fontSizeExtraLarge,
                  color: CustomColors.darkGreenColor,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String hint, {
        Widget? icon,
        TextInputType? keyboardType,
        List<TextInputFormatter>? inputFormatters,
        String? errorText,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 56,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType ?? TextInputType.text,
            inputFormatters: inputFormatters,
            onChanged: (value) {
              // Clear validation errors when user starts typing
              this.controller.clearValidationErrors();
            },
            decoration: _inputDecoration(
              hint: hint,
              icon: icon,
              hasError: errorText != null,
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16),
            child: Text(
              errorText,
              style: regularStyle.copyWith(
                color: Colors.red,
                fontSize: Dimensions.fontSizeSmall,
              ),
            ),
          ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    Widget? icon,
    bool hasError = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: lightStyle.copyWith(color: CustomColors.greyTextColor),
      prefixIcon: icon != null
          ? Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: SizedBox(
          width: 8,
          height: 8,
          child: icon,
        ),
      )
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: hasError ? Colors.red : CustomColors.textBorderColor,
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: hasError ? Colors.red : CustomColors.textBorderColor,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: CustomColors.purpleColor,
          width: 1,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildLabel(String text) {
    // Trim whitespace and validate
    final trimmedText = text.trim();

    // Return empty container if text is empty after trimming
    if (trimmedText.isEmpty) {
      return const SizedBox.shrink();
    }

    // Split into words and limit to maximum 5 words
    final words = trimmedText.split(RegExp(r'\s+'));
    const maxWords = 5;

    String displayText;
    if (words.length > maxWords) {
      // Take only the first maxWords and add ellipsis
      displayText = words.take(maxWords).join(' ') + '...';
    } else {
      displayText = words.join(' '); // Rejoin to normalize spacing
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 16),
      child: Text(
        displayText,
        style: mediumStyle.copyWith(fontSize: Dimensions.fontSizeDefault),
        maxLines: 2, // Limit to 2 lines
        overflow: TextOverflow.ellipsis, // Handle overflow gracefully
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: CustomColors.purpleColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(12),
        child: Icon(icon, color: CustomColors.purpleColor),
      ),
    );
  }
}