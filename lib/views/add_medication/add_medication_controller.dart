// controllers/add_medication_controller.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lupus_care/data/api/auth_service.dart';
import 'package:lupus_care/helper/storage_service.dart';

class AddMedicationController extends GetxController {
  final AuthService _authService = AuthService();

  // Form controllers
  final medicationName = TextEditingController();
  final numberOfDays = TextEditingController();
  final dosageFrequency = ''.obs;
  final reminderTimes = <TimeOfDay>[TimeOfDay.now()].obs;

  // Loading and error states
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  // Validation constants
  static const int maxMedicationNameLength = 50;
  static const int minMedicationNameLength = 2;
  static const int maxDays = 366;
  static const int minDays = 1;

  // Input formatters for number of days field (no decimals allowed)
  List<TextInputFormatter> get daysInputFormatters => [
    FilteringTextInputFormatter.digitsOnly, // Only allow digits (0-9)
    LengthLimitingTextInputFormatter(3), // Limit to 3 digits (max 366 days)
    TextInputFormatter.withFunction((oldValue, newValue) {
      // Prevent leading zeros
      if (newValue.text.length > 1 && newValue.text.startsWith('0')) {
        return oldValue;
      }
      return newValue;
    }),
  ];

  // Keyboard type for days field (numbers only, no decimal)
  TextInputType get daysKeyboardType => TextInputType.number;

  void addReminderTime() {
    if (reminderTimes.length < 5) {
      reminderTimes.add(TimeOfDay.now());
    }
  }

  void removeReminderTime(int index) {
    if (reminderTimes.length > 1) {
      reminderTimes.removeAt(index);
    }
  }



  // Convert dosage frequency text to number
  String getDosagePerDay() {
    switch (dosageFrequency.value) {
      case 'Once a Day':
        return '1';
      case 'Twice a Day':
        return '2';
      case 'Thrice a Day':
        return '3';
      default:
        return '1';
    }
  }

  // Convert TimeOfDay list to JSON string format
  String formatReminderTimes() {
    List<String> timeStrings = reminderTimes.map((time) {
      String hour = time.hour.toString().padLeft(2, '0');
      String minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }).toList();

    return jsonEncode(timeStrings);
  }

  // Helper method to show error snackbar
  void _showErrorSnackbar(String message) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: Duration(seconds: 3),
    );
  }

  // Helper method to show success snackbar
  void _showSuccessSnackbar(String message) {
    Get.snackbar(
      'Success',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: Duration(seconds: 2),
    );
  }

  // Enhanced validation with length checks
  bool validateForm() {
    final trimmedMedicationName = medicationName.text.trim();
    final trimmedDays = numberOfDays.text.trim();

    // Validate medication name - empty
    if (trimmedMedicationName.isEmpty) {
      _showErrorSnackbar('Please enter medication name');
      return false;
    }

    // Validate medication name - minimum length
    if (trimmedMedicationName.length < minMedicationNameLength) {
      _showErrorSnackbar('Medication name must be at least $minMedicationNameLength characters long');
      return false;
    }

    // Validate medication name - maximum length
    if (trimmedMedicationName.length > maxMedicationNameLength) {
      _showErrorSnackbar('Medication name cannot exceed $maxMedicationNameLength characters');
      return false;
    }

    // Validate medication name - not just whitespace or special characters
    if (!RegExp(r'^[a-zA-Z0-9\s\-\+\.]+$').hasMatch(trimmedMedicationName)) {
      _showErrorSnackbar('Medication name contains invalid characters');
      return false;
    }

    // Validate number of days - empty
    if (trimmedDays.isEmpty) {
      _showErrorSnackbar('Please enter number of days');
      return false;
    }

    // Validate number of days - valid integer
    int? days = int.tryParse(trimmedDays);
    if (days == null) {
      _showErrorSnackbar('Please enter a valid whole number for days');
      return false;
    }

    // Validate number of days - not zero
    if (days == 0) {
      _showErrorSnackbar('Number of days cannot be zero');
      return false;
    }

    // Validate number of days - minimum value
    if (days < minDays) {
      _showErrorSnackbar('Number of days must be at least $minDays');
      return false;
    }

    // Validate number of days - maximum value
    if (days > maxDays) {
      _showErrorSnackbar('Number of days cannot exceed $maxDays');
      return false;
    }

    // Validate dosage frequency
    if (dosageFrequency.value.isEmpty) {
      _showErrorSnackbar('Please select dosage frequency');
      return false;
    }

    // Validate reminder times
    if (reminderTimes.isEmpty) {
      _showErrorSnackbar('Please set at least one reminder time');
      return false;
    }

    return true;
  }

  Future<void> saveMedication() async {
    try {
      // Validate form
      if (!validateForm()) {
        return;
      }

      // Show loading
      isLoading.value = true;
      errorMessage.value = '';

      // Get user ID from storage
      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString();

      if (userId == null || userId.isEmpty) {
        errorMessage.value = 'User ID not found. Please log in again.';
        isLoading.value = false;
        _showErrorSnackbar(errorMessage.value);
        return;
      }

      // Prepare data with trimmed values
      String medName = medicationName.text.trim();
      String days = numberOfDays.text.trim();
      String dosagePerDay = getDosagePerDay();
      String reminderTimesJson = formatReminderTimes();

      print("Saving medication:");
      print("- Name: $medName");
      print("- Days: $days");
      print("- Dosage per day: $dosagePerDay");
      print("- Reminder times: $reminderTimesJson");

      // Call API
      final response = await _authService.addMedication(
        userId: userId,
        medicationName: medName,
        numberOfDays: days,
        dosagePerDay: dosagePerDay,
        reminderTimes: reminderTimesJson,
      );

      // Hide loading first
      isLoading.value = false;

      // Handle response
      if (response['status'] == 'success') {
        print("Medication saved successfully");

        // Clear form
        clearForm();

        // Navigate back immediately
        Get.back();

        // Show success message after navigation
        _showSuccessSnackbar('Medication added successfully!');

      } else {
        // Handle API error
        errorMessage.value = response['message'] ?? 'Failed to save medication';
        print("Error saving medication: $errorMessage");
        _showErrorSnackbar(errorMessage.value);
      }

    } catch (e) {
      // Handle exceptions
      errorMessage.value = 'Error saving medication: $e';
      print("Exception in saveMedication: $errorMessage");

      // Hide loading in catch block
      isLoading.value = false;

      _showErrorSnackbar('An unexpected error occurred. Please try again.');
    }
  }

  void clearForm() {
    medicationName.clear();
    numberOfDays.clear();
    dosageFrequency.value = '';
    reminderTimes.clear();
    reminderTimes.add(TimeOfDay.now());
  }



  void updateReminderTime(int index, TimeOfDay newTime) {
    if (index >= 0 && index < reminderTimes.length) {
      reminderTimes[index] = newTime;
      reminderTimes.refresh(); // Trigger UI update
    }
  }

// If you don't have the pickTime method, replace it with this:
  Future<void> pickTime(int index, BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: reminderTimes[index],
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked != null) {
      updateReminderTime(index, picked);
    }
  }

  @override
  void onClose() {
    medicationName.dispose();
    numberOfDays.dispose();
    super.onClose();
  }
}