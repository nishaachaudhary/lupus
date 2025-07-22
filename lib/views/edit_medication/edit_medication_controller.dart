// views/edit_medication/edit_medication_controller.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lupus_care/data/api/auth_service.dart';
import 'package:lupus_care/helper/storage_service.dart';
import 'package:lupus_care/views/medication_tracker/medication_tracker_controller.dart';

class EditMedicationController extends GetxController {
  final AuthService _authService = AuthService();

  // Loading state
  final isLoading = false.obs;

  // Text controllers
  late TextEditingController medicationName;
  late TextEditingController numberOfDays;

  // Reactive variables
  final dosageFrequency = ''.obs;
  final reminderTimes = <TimeOfDay>[].obs;

  // Form validation
  final medicationNameError = ''.obs;
  final numberOfDaysError = ''.obs;
  final dosageFrequencyError = ''.obs;
  final reminderTimesError = ''.obs;

  // Input formatters and keyboard types
  final TextInputType daysKeyboardType = TextInputType.number;
  final List<TextInputFormatter> daysInputFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(3),
  ];

  // Medication being edited
  Medication? originalMedication;

  @override
  void onInit() {
    super.onInit();

    // Initialize text controllers
    medicationName = TextEditingController();
    numberOfDays = TextEditingController();

    // Get medication data from arguments
    if (Get.arguments != null && Get.arguments is Medication) {
      originalMedication = Get.arguments as Medication;
      _populateFields();
    } else {
      // Set default values if no medication provided
      _setDefaultValues();
    }
  }

  void _populateFields() {
    if (originalMedication != null) {
      print("📝 Populating fields with medication data: ${originalMedication!.name}");

      // Set text fields
      medicationName.text = originalMedication!.name;
      numberOfDays.text = originalMedication!.numberOfDays;

      // Set dosage frequency
      String frequency = _mapDosageToFrequency(originalMedication!.dosagePerDay);
      dosageFrequency.value = frequency;

      // Set reminder times
      List<TimeOfDay> times = _parseReminderTimes(originalMedication!.reminderTimes);
      reminderTimes.value = times;

      print("✅ Fields populated successfully");
      print("   - Name: ${medicationName.text}");
      print("   - Days: ${numberOfDays.text}");
      print("   - Frequency: ${dosageFrequency.value}");
      print("   - Reminder times: ${reminderTimes.length}");
    }
  }

  void _setDefaultValues() {
    print("📝 Setting default values");
    dosageFrequency.value = '';
    reminderTimes.value = [TimeOfDay(hour: 8, minute: 0)];
  }

  String _mapDosageToFrequency(String dosagePerDay) {
    switch (dosagePerDay) {
      case '1':
        return 'Once a Day';
      case '2':
        return 'Twice a Day';
      case '3':
        return 'Thrice a Day';
      default:
        return 'Once a Day';
    }
  }

  String _mapFrequencyToDosage(String frequency) {
    switch (frequency) {
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

  List<TimeOfDay> _parseReminderTimes(List<String> timeStrings) {
    List<TimeOfDay> times = [];

    for (String timeString in timeStrings) {
      try {
        // Parse time string (assuming format is HH:mm or HH:mm:ss)
        final timeParts = timeString.split(':');
        if (timeParts.length >= 2) {
          int hour = int.parse(timeParts[0]);
          int minute = int.parse(timeParts[1]);

          // Validate hour and minute ranges
          if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
            times.add(TimeOfDay(hour: hour, minute: minute));
          }
        }
      } catch (e) {
        print("Error parsing time string '$timeString': $e");
      }
    }

    // If no valid times parsed, add a default time
    if (times.isEmpty) {
      times.add(TimeOfDay(hour: 8, minute: 0));
    }

    return times;
  }

  void updateReminderTime(int index, TimeOfDay time) {
    if (index >= 0 && index < reminderTimes.length) {
      reminderTimes[index] = time;
      print("⏰ Updated reminder time $index to ${time.format(Get.context!)}");
      clearValidationErrors();
    }
  }

  void addReminderTime() {
    if (reminderTimes.length < 5) { // Limit to 5 reminders
      TimeOfDay newTime = TimeOfDay(hour: 8, minute: 0);

      // If there are existing times, add 1 hour to the last time
      if (reminderTimes.isNotEmpty) {
        TimeOfDay lastTime = reminderTimes.last;
        int newHour = (lastTime.hour + 1) % 24;
        newTime = TimeOfDay(hour: newHour, minute: lastTime.minute);
      }

      reminderTimes.add(newTime);
      print("➕ Added new reminder time: ${newTime.format(Get.context!)}");
      clearValidationErrors();
    } else {
      Get.snackbar(
        'Maximum Reminders',
        'You can only set up to 5 reminder times',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }
  }

  void removeReminderTime(int index) {
    if (index >= 0 && index < reminderTimes.length && reminderTimes.length > 1) {
      TimeOfDay removedTime = reminderTimes[index];
      reminderTimes.removeAt(index);
      print("➖ Removed reminder time: ${removedTime.format(Get.context!)}");
      clearValidationErrors();
    } else if (reminderTimes.length == 1) {
      Get.snackbar(
        'Minimum Required',
        'At least one reminder time is required',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }
  }

  bool _validateForm() {
    bool isValid = true;
    clearValidationErrors();

    // Validate medication name
    if (medicationName.text.trim().isEmpty) {
      medicationNameError.value = 'Medication name is required';
      isValid = false;
    } else if (medicationName.text.trim().length < 2) {
      medicationNameError.value = 'Medication name must be at least 2 characters';
      isValid = false;
    }

    // Validate number of days
    if (numberOfDays.text.trim().isEmpty) {
      numberOfDaysError.value = 'Number of days is required';
      isValid = false;
    } else {
      int? days = int.tryParse(numberOfDays.text.trim());
      if (days == null || days <= 0) {
        numberOfDaysError.value = 'Enter a valid number of days';
        isValid = false;
      } else if (days > 365) {
        numberOfDaysError.value = 'Number of days cannot exceed 365';
        isValid = false;
      }
    }

    // Validate dosage frequency
    if (dosageFrequency.value.isEmpty) {
      dosageFrequencyError.value = 'Please select dosage frequency';
      isValid = false;
    }

    // Validate reminder times
    if (reminderTimes.isEmpty) {
      reminderTimesError.value = 'At least one reminder time is required';
      isValid = false;
    }

    return isValid;
  }

  void clearValidationErrors() {
    medicationNameError.value = '';
    numberOfDaysError.value = '';
    dosageFrequencyError.value = '';
    reminderTimesError.value = '';
  }

  Future<void> updateMedication() async {
    if (!_validateForm()) {
      Get.snackbar(
        'Validation Error',
        'Please fix the errors and try again',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
      return;
    }

    if (originalMedication == null) {
      Get.snackbar(
        'Error',
        'Original medication data not found',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
      return;
    }

    try {
      isLoading.value = true;

      // Get user ID from storage
      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString();

      if (userId == null || userId.isEmpty) {
        throw Exception('User ID not found. Please log in again.');
      }

      // Convert reminder times to strings in 24-hour format
      List<String> reminderTimeStrings = reminderTimes.map((time) {
        return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
      }).toList();

      // Prepare update data exactly as per API specification
      final updateData = {
        'user_id': userId,
        'medication_id': originalMedication!.id.toString(),
        'medication_name': medicationName.text.trim(),
        'number_of_days': numberOfDays.text.trim(),
        'dosage_per_day': _mapFrequencyToDosage(dosageFrequency.value),
        'reminder_times': jsonEncode(reminderTimeStrings), // JSON array as string
      };

      print("📤 Updating medication with data: $updateData");

      // Call API to update medication
      final response = await _authService.updateMedication(updateData);

      print("📥 Update response: ${response['status']}");
      print("📥 Response message: ${response['message']}");

      if (response['status'] == 'success') {
        // Show success message first
        Get.snackbar(
          'Success',
          response['message'] ?? 'Medication updated successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 2),
          snackPosition: SnackPosition.TOP,
        );
        Get.back();
        // Small delay to show the success message
        await Future.delayed(Duration(milliseconds: 800));

        // Try to refresh the medication controller if it exists
        try {
          if (Get.isRegistered<MedicationController>()) {
            final medicationController = Get.find<MedicationController>();
            await medicationController.refreshMedications();
            print("✅ Medication list refreshed after update");
          }
        } catch (e) {
          print("⚠️ Could not refresh medication controller: $e");
        }

        // Navigate back with success result
        Get.back(result: {
          'success': true,
          'message': 'Medication updated successfully',
          'refreshed': true,
          'updated_medication': {
            'id': originalMedication!.id,
            'name': medicationName.text.trim(),
            'numberOfDays': numberOfDays.text.trim(),
            'dosagePerDay': _mapFrequencyToDosage(dosageFrequency.value),
            'reminderTimes': reminderTimeStrings,
          },
        });

      } else if (response['status'] == 'error') {
        // Handle error cases (same as before)
        String errorMessage = response['message'] ?? 'Failed to update medication';

        if (errorMessage.toLowerCase().contains('authentication') ||
            errorMessage.toLowerCase().contains('token')) {
          errorMessage = 'Session expired. Please log in again.';
        } else if (errorMessage.toLowerCase().contains('network') ||
            errorMessage.toLowerCase().contains('connection')) {
          errorMessage = 'Network error. Please check your connection and try again.';
        } else if (errorMessage.toLowerCase().contains('medication not found')) {
          errorMessage = 'Medication not found. It may have been deleted.';
        }

        Get.snackbar(
          'Update Failed',
          errorMessage,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 4),
          snackPosition: SnackPosition.TOP,
        );

        if (errorMessage.contains('Session expired')) {
          await Future.delayed(Duration(seconds: 2));
          Get.snackbar(
            'Tip',
            'Try logging out and logging back in',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: Duration(seconds: 3),
          );
        }

      } else {
        throw Exception(response['message'] ?? 'Unknown response from server');
      }

    } catch (e) {
      print("❌ Error updating medication: $e");

      String userFriendlyMessage;
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        userFriendlyMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('FormatException')) {
        userFriendlyMessage = 'Invalid server response. Please try again.';
      } else if (e.toString().contains('User ID not found')) {
        userFriendlyMessage = 'Session expired. Please log in again.';
      } else {
        userFriendlyMessage = 'Failed to update medication. Please try again.';
      }

      Get.snackbar(
        'Error',
        userFriendlyMessage,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 4),
        snackPosition: SnackPosition.TOP,
      );

    } finally {
      isLoading.value = false;
    }
  }


  @override
  void onClose() {
    medicationName.dispose();
    numberOfDays.dispose();
    super.onClose();
  }
}