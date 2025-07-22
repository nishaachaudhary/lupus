// views/medication_tracker/medication_tracker_controller.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:lupus_care/data/api/auth_service.dart';
import 'package:lupus_care/helper/storage_service.dart';
import 'package:lupus_care/style/colors.dart';

class Medication {
  final String id;
  final String name;
  final String time;
  final String duration;
  final String status;
  final String dosagePerDay;
  final List<String> reminderTimes;
  final String numberOfDays;
  final String createdAt;

  Medication({
    required this.id,
    required this.name,
    required this.time,
    required this.duration,
    required this.status,
    required this.dosagePerDay,
    required this.reminderTimes,
    required this.numberOfDays,
    required this.createdAt,
  });

  factory Medication.fromJson(Map<String, dynamic> json) {
    // Parse reminder times
    List<String> times = [];
    try {
      if (json['reminder_times'] != null) {
        if (json['reminder_times'] is String) {
          // If it's a JSON string, decode it
          final decoded = json['reminder_times'];
          if (decoded.startsWith('[')) {
            times = List<String>.from(jsonDecode(decoded));
          } else {
            times = [decoded];
          }
        } else if (json['reminder_times'] is List) {
          times = List<String>.from(json['reminder_times']);
        }
      }
    } catch (e) {
      print("Error parsing reminder times: $e");
      times = [];
    }

    // Calculate duration string
    String durationString = "${json['number_of_days'] ?? '0'} days";

    // Get first reminder time for display
    String displayTime = times.isNotEmpty ? formatTime(times.first) : "No time set";

    // Determine status based on data (you can customize this logic)
    String status = "Ongoing"; // Default status
    if (json['status'] != null) {
      status = json['status'];
    }

    return Medication(
      id: json['medication_id']?.toString() ?? '',
      name: json['medication_name'] ?? 'Unknown Medication',
      time: displayTime,
      duration: durationString,
      status: status,
      dosagePerDay: json['dosage_per_day']?.toString() ?? '1',
      reminderTimes: times,
      numberOfDays: json['number_of_days']?.toString() ?? '0',
      createdAt: json['created_at'] ?? '',
    );
  }

  static String formatTime(String timeString) {
    try {
      // Parse time string (assuming format is HH:mm or HH:mm:ss)
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
}

class MedicationController extends GetxController {
  final AuthService _authService = AuthService();

  // Loading and error states
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  // Search functionality
  final searchQuery = ''.obs;

  // Filter functionality
  final selectedMedication = 'All Medications'.obs;

  // Dynamic medication types based on API data
  List<String> get medicationTypes {
    List<String> types = ['All Medications'];

    // Get unique medication names from the current medications
    Set<String> uniqueNames = medications.map((med) => med.name).toSet();
    types.addAll(uniqueNames.toList()..sort());

    return types;
  }

  // Medications data from API
  final medications = <Medication>[].obs;

  @override
  void onInit() {
    super.onInit();
    print("MedicationController onInit called");

    // Ensure "All Medications" is selected when page opens
    resetToAllMedications();

    fetchMedications();
  }

  @override
  void onReady() {
    super.onReady();
    print("MedicationController onReady called - Auto refreshing medications");

    // Ensure "All Medications" is selected when page becomes active
    resetToAllMedications();

    // This will be called every time the page becomes active
    refreshMedications();
  }

  // Method to explicitly reset filter to "All Medications"
  void resetToAllMedications() {
    selectedMedication.value = 'All Medications';
    searchQuery.value = '';
    print("Filter reset to: All Medications");
  }


// Option 1: With Loading Dialog (Recommended)
  Future<void> deleteMedication(String medicationId) async {
    try {
      print("🗑️ Deleting medication with ID: $medicationId");

      // Get user ID from storage
      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString();

      if (userId == null || userId.isEmpty) {
        Get.snackbar(
          "Error",
          "User ID not found. Please log in again.",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Show loading dialog
      Get.dialog(
        WillPopScope(
          onWillPop: () async => false, // Prevent dismissing during delete
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: CustomColors.purpleColor),

              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // Show loading state (for other UI elements)
      isLoading.value = true;
      errorMessage.value = '';

      // Call delete API
      final response = await _authService.deleteMedication(
        userId: userId,
        medicationId: medicationId,
      );

      // Dismiss loading dialog
      if (Get.isDialogOpen == true) {
        Get.back(); // Close the loading dialog
      }

      if (response['status'] == 'success') {
        // Show success message
        Get.snackbar(
          "Success",
          "Medication deleted successfully",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 2),
        );

        // Refresh medications list to reflect changes
        await refreshMedications();

        print("✅ Medication deleted and list refreshed");
      } else {
        // Show error message
        final errorMsg = response['message'] ?? 'Failed to delete medication';
        Get.snackbar(
          "Error",
          errorMsg,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
          icon: Icon(Icons.error, color: Colors.white),
        );

        print("❌ Delete medication failed: $errorMsg");
      }
    } catch (e) {
      // Dismiss loading dialog if still open
      if (Get.isDialogOpen == true) {
        Get.back();
      }

      // Show error message for exceptions
      Get.snackbar(
        "Error",
        "An error occurred while deleting medication: $e",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
        icon: Icon(Icons.error, color: Colors.white),
      );

      print("❌ Exception deleting medication: $e");
    } finally {
      isLoading.value = false;
    }
  }

// Optional: Method to delete with confirmation and refresh
  Future<void> deleteMedicationWithConfirmation(String medicationId, String medicationName) async {
    // Show confirmation dialog
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Delete Medication',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$medicationName"? This action cannot be undone.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(
              'Delete',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      await deleteMedication(medicationId);
    }
  }

  // Fetch medications from API
  Future<void> fetchMedications() async {
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

      print("Fetching medications for user ID: $userId");

      // Call API to get medications
      final response = await _authService.getMedications(userId: userId);

      if (response['status'] == 'success' && response['medications'] != null) {
        // Clear existing medications
        medications.clear();

        // Add medications from API response
        final medicationsData = response['medications'] as List;
        for (var medicationItem in medicationsData) {
          medications.add(Medication.fromJson(medicationItem));
        }

        print("Loaded ${medications.length} medications from API");

        // Only reset filter if the currently selected medication no longer exists
        // but preserve "All Medications" selection
        if (selectedMedication.value != 'All Medications' &&
            !medicationTypes.contains(selectedMedication.value)) {
          selectedMedication.value = 'All Medications';
          print("Reset filter to All Medications - selected medication no longer exists");
        }
      } else {
        errorMessage.value = response['message'] ?? 'Failed to load medications';
        print("Error loading medications: $errorMessage");
      }
    } catch (e) {
      errorMessage.value = 'Error fetching medications: $e';
      print("Exception fetching medications: $errorMessage");
    } finally {
      isLoading.value = false;
    }
  }

  // Refresh medications (for pull-to-refresh and auto-refresh)
  Future<void> refreshMedications() async {
    print("Refreshing medications...");
    await fetchMedications();
  }

  // Get filtered medications based on search and selected type
  List<Medication> get filteredMedications {
    List<Medication> filtered = medications.toList();

    // Filter by search query (only if not empty after trimming)
    if (searchQuery.value.trim().isNotEmpty) {
      String searchTerm = searchQuery.value.trim().toLowerCase();
      filtered = filtered.where((med) =>
          med.name.toLowerCase().contains(searchTerm)
      ).toList();
    }

    // Filter by selected medication name
    if (selectedMedication.value != 'All Medications') {
      filtered = filtered.where((med) =>
      med.name == selectedMedication.value
      ).toList();
    }

    return filtered;
  }

  // Update search query with proper validation
  void updateSearchQuery(String query) {
    // Trim whitespace and validate
    String trimmedQuery = query.trim();

    // Only update if the trimmed query is different
    if (searchQuery.value != trimmedQuery) {
      searchQuery.value = trimmedQuery;
      print("Search query updated to: '$trimmedQuery'");
    }
  }

  // Clear search and reset query
  void clearSearch() {
    searchQuery.value = '';
    print("Search cleared");
  }

  // Method to update selected medication filter
  void updateSelectedMedication(String medication) {
    selectedMedication.value = medication;
    print("Selected medication updated to: $medication");
  }

  // Method to ensure proper initialization (can be called from UI)
  void ensureProperInitialization() {
    if (selectedMedication.value != 'All Medications') {
      resetToAllMedications();
    }
  }
}