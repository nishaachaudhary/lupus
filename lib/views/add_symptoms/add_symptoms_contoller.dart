import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:lupus_care/data/api/auth_service.dart';
import 'package:lupus_care/helper/storage_service.dart';
import 'package:lupus_care/views/add_symptoms/add_new_symptom.dart';

class AddSymptomsController extends GetxController {
  final AuthService _authService = AuthService();

  // Selected items
  final selectedSymptoms = <String>[].obs;
  final selectedTriggers = <String>[].obs;

  // Status trackers
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  // API Data storage
  final apiSymptoms = <Map<String, dynamic>>[].obs;
  final apiTriggers = <Map<String, dynamic>>[].obs;

  // Available options - ONLY from API, no static fallbacks
  final symptoms = <String>[].obs;
  final triggers = <String>[].obs;

  // Track which custom field is active


  // Loading states for individual sections
  final isSymptomsLoading = false.obs;
  final isTriggersLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    print("🔧 AddSymptomsController onInit - fetching API data only...");
    fetchSymptoms();
    fetchTriggers();
  }

  Future<void> fetchSymptoms() async {
    try {
      print("📋 Fetching symptoms from API only...");
      isSymptomsLoading.value = true;

      // Clear any existing symptoms first
      symptoms.clear();
      apiSymptoms.clear();

      // Get user ID
      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString();

      if (userId == null || userId.isEmpty) {
        errorMessage.value = 'User ID not found. Please log in again.';
        print("❌ No user ID found");
        isSymptomsLoading.value = false;
        return;
      }

      // Call API to get symptoms
      final response = await _authService.getSymptoms(userId: userId);
      print("📥 Symptoms API response: ${response['status']}");

      if (response['status'] == 'success' && response['data'] != null) {
        // Store the API response data
        apiSymptoms.value = List<Map<String, dynamic>>.from(response['data']);
        print("📊 API returned ${apiSymptoms.length} symptoms");

        // Add each symptom name from the API response ONLY
        for (var symptom in apiSymptoms) {
          symptoms.add(symptom['name']);
          print("✅ Added symptom from API: ${symptom['name']}");
        }

        // Always add the Custom Symptom option at the end
        symptoms.add('+ Custom Symptom');

        print("✅ Successfully loaded ${apiSymptoms.length} symptoms from API");
        print("📋 Total symptoms in list: ${symptoms.length}");

        // Force UI update
        symptoms.refresh();

      } else {
        // API failed - DO NOT use fallback, leave empty
        print("❌ API failed - leaving symptoms empty");
        print("❌ Error: ${response['message']}");
        errorMessage.value = response['message'] ?? 'Failed to load symptoms';

        // Only add the custom option if no API data
        symptoms.clear();
        symptoms.add('+ Custom Symptom');
        print("⚠️ Only showing custom symptom option");
      }

    } catch (e) {
      print("❌ Exception fetching symptoms: $e");
      errorMessage.value = 'Error fetching symptoms: $e';

      // Exception occurred - DO NOT use fallback, leave empty
      symptoms.clear();
      symptoms.add('+ Custom Symptom');
      print("⚠️ Exception - only showing custom symptom option");

    } finally {
      isSymptomsLoading.value = false;
      print("🔧 fetchSymptoms completed");
    }
  }

  Future<void> fetchTriggers() async {
    try {
      print("🎯 Fetching triggers from API only...");
      isTriggersLoading.value = true;

      // Clear any existing triggers first
      triggers.clear();
      apiTriggers.clear();

      // Get user ID
      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString();

      if (userId == null || userId.isEmpty) {
        errorMessage.value = 'User ID not found. Please log in again.';
        print("❌ No user ID found");
        isTriggersLoading.value = false;
        return;
      }

      // Call API to get triggers
      final response = await _authService.getTriggers(userId: userId);
      print("📥 Triggers API response: ${response['status']}");

      if (response['status'] == 'success' && response['data'] != null) {
        // Store the API response data
        apiTriggers.value = List<Map<String, dynamic>>.from(response['data']);
        print("📊 API returned ${apiTriggers.length} triggers");

        // Add each trigger name from the API response ONLY
        for (var trigger in apiTriggers) {
          triggers.add(trigger['name']);
          print("✅ Added trigger from API: ${trigger['name']}");
        }

        // Always add the Custom Trigger option at the end
        triggers.add('+ Custom Trigger');

        print("✅ Successfully loaded ${apiTriggers.length} triggers from API");
        print("📋 Total triggers in list: ${triggers.length}");
        print("📋 Final triggers from API: ${triggers.toList()}");

        // Force UI update
        triggers.refresh();

      } else {
        // API failed - DO NOT use fallback, leave empty
        print("❌ API failed - leaving triggers empty");
        print("❌ Error: ${response['message']}");
        errorMessage.value = response['message'] ?? 'Failed to load triggers';

        // Only add the custom option if no API data
        triggers.clear();
        triggers.add('+ Custom Trigger');
        print("⚠️ Only showing custom trigger option");
      }

    } catch (e) {
      print("❌ Exception fetching triggers: $e");
      errorMessage.value = 'Error fetching triggers: $e';

      // Exception occurred - DO NOT use fallback, leave empty
      triggers.clear();
      triggers.add('+ Custom Trigger');
      print("⚠️ Exception - only showing custom trigger option");

    } finally {
      isTriggersLoading.value = false;
      print("🔧 fetchTriggers completed");
    }
  }

  void toggleSymptom(String symptom) {
    print("🔘 Toggle symptom: $symptom");
    if (symptom == '+ Custom Symptom') {
      activeCustomField.value = CustomFieldType.symptom;
      if (!selectedSymptoms.contains(symptom)) {
        selectedSymptoms.add(symptom);
      }
    } else {
      if (selectedSymptoms.contains(symptom)) {
        selectedSymptoms.remove(symptom);
      } else {
        selectedSymptoms.add(symptom);
      }
    }
    print("📝 Selected symptoms: ${selectedSymptoms.toList()}");
  }

  void toggleTrigger(String trigger) {
    print("🎯 Toggle trigger: $trigger");
    if (trigger == '+ Custom Trigger') {
      activeCustomField.value = CustomFieldType.trigger;
      if (!selectedTriggers.contains(trigger)) {
        selectedTriggers.add(trigger);
      }
    } else {
      if (selectedTriggers.contains(trigger)) {
        selectedTriggers.remove(trigger);
      } else {
        selectedTriggers.add(trigger);
      }
    }
    print("📝 Selected triggers: ${selectedTriggers.toList()}");
  }



  Future<void> addCustomItem(String text) async {
    final trimmedText = text.trim();

    // Check if the trimmed text is empty
    if (trimmedText.isEmpty) {
      Get.snackbar(
        'Error',
        'Cannot add empty item',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // Check minimum length (at least 2 characters)
    if (trimmedText.length < 2) {
      Get.snackbar(
        'Error',
        'Item name must be at least 2 characters long',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // Check length limitation (max 50 characters)
    if (trimmedText.length > 50) {
      Get.snackbar(
        'Error',
        'Item name cannot exceed 50 characters',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // NEW VALIDATION: Check if text contains only special characters, dots, or numbers
    if (!RegExp(r'^.*[a-zA-Z].*$').hasMatch(trimmedText)) {
      Get.snackbar(
        'Error',
        'Item name must contain at least one letter',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // NEW VALIDATION: Check if text contains only dots, spaces, or special characters
    if (RegExp(r'^[^a-zA-Z0-9\s]+$').hasMatch(trimmedText)) {
      Get.snackbar(
        'Error',
        'Item name cannot contain only special characters',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // NEW VALIDATION: Check if text contains only dots and spaces
    if (RegExp(r'^[\.\s]+$').hasMatch(trimmedText)) {
      Get.snackbar(
        'Error',
        'Item name cannot contain only dots and spaces',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // NEW VALIDATION: Check if text contains excessive special characters (more than 30% of the text)
    final specialCharCount = RegExp(r'[^a-zA-Z0-9\s]').allMatches(trimmedText).length;
    final specialCharPercentage = (specialCharCount / trimmedText.length) * 100;
    if (specialCharPercentage > 30) {
      Get.snackbar(
        'Error',
        'Item name contains too many special characters',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // NEW VALIDATION: Check for inappropriate patterns (repeated characters)
    if (RegExp(r'(.)\1{4,}').hasMatch(trimmedText)) {
      Get.snackbar(
        'Error',
        'Item name cannot contain repeated characters',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (activeCustomField.value == CustomFieldType.symptom) {
      // Call the API to add the custom symptom with trimmed text
      final result = await _addSymptomToAPI(trimmedText);

      // Only update UI if API call was successful
      if (result) {
        // Update local UI
        final index = symptoms.indexOf('+ Custom Symptom');
        if (index != -1) {
          symptoms.insert(index, trimmedText);
        } else {
          symptoms.add(trimmedText);
        }
        selectedSymptoms.add(trimmedText);
        selectedSymptoms.remove('+ Custom Symptom');

        // Refresh the symptoms list from API to get the latest data
        await fetchSymptoms();
      }
    } else if (activeCustomField.value == CustomFieldType.trigger) {
      // Call the API to add the custom trigger with trimmed text
      final result = await _addTriggerToAPI(trimmedText);

      // Only update UI if API call was successful
      if (result) {
        // Update local UI
        final index = triggers.indexOf('+ Custom Trigger');
        if (index != -1) {
          triggers.insert(index, trimmedText);
        } else {
          triggers.add(trimmedText);
        }
        selectedTriggers.add(trimmedText);
        selectedTriggers.remove('+ Custom Trigger');

        // Refresh the triggers list from API to get the latest data
        await fetchTriggers();
      }
    }

    activeCustomField.value = CustomFieldType.none;
  }

  Future<bool> _addSymptomToAPI(String symptomName) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Get user ID from storage
      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString();

      if (userId == null || userId.isEmpty) {
        errorMessage.value = 'User ID not found. Please log in again.';
        print("Error: $errorMessage");
        Get.snackbar(
          'Error',
          errorMessage.value,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }

      // Call the API
      final response = await _authService.addSymptom(
          userId: userId,
          name: symptomName
      );

      // Check response
      if (response['status'] == 'success') {
        print("Successfully added symptom '$symptomName' to API");
        Get.snackbar(
          'Success',
          'Added symptom successfully',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        return true;
      } else {
        errorMessage.value = response['message'] ?? 'Failed to add symptom';
        print("Error: $errorMessage");
        Get.snackbar(
          'Error',
          errorMessage.value,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
    } catch (e) {
      errorMessage.value = 'Error adding symptom: $e';
      print("Exception: $errorMessage");
      Get.snackbar(
        'Error',
        errorMessage.value,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> _addTriggerToAPI(String triggerName) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Get user ID from storage
      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString();

      if (userId == null || userId.isEmpty) {
        errorMessage.value = 'User ID not found. Please log in again.';
        print("Error: $errorMessage");
        Get.snackbar(
          'Error',
          errorMessage.value,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }

      // Call the API
      final response = await _authService.addTrigger(
          userId: userId,
          name: triggerName
      );

      // Check response
      if (response['status'] == 'success') {
        print("Successfully added trigger '$triggerName' to API");
        Get.snackbar(
          'Success',
          'Added trigger successfully',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        return true;
      } else {
        errorMessage.value = response['message'] ?? 'Failed to add trigger';
        print("Error: $errorMessage");
        Get.snackbar(
          'Error',
          errorMessage.value,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
    } catch (e) {
      errorMessage.value = 'Error adding trigger: $e';
      print("Exception: $errorMessage");
      Get.snackbar(
        'Error',
        errorMessage.value,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Debug method to check API-only state
  void debugApiOnlyState() {
    print("🔍 === API-ONLY DEBUG INFO ===");
    print("API Symptoms count: ${apiSymptoms.length}");
    print("Symptoms list count: ${symptoms.length}");
    print("Symptoms from API: ${symptoms.where((s) => s != '+ Custom Symptom').toList()}");
    print("");
    print("API Triggers count: ${apiTriggers.length}");
    print("Triggers list count: ${triggers.length}");
    print("Triggers from API: ${triggers.where((t) => t != '+ Custom Trigger').toList()}");
    print("");
    print("Selected symptoms: ${selectedSymptoms.toList()}");
    print("Selected triggers: ${selectedTriggers.toList()}");
    print("Active custom field: ${activeCustomField.value}");
    print("Is loading: ${isLoading.value}");
    print("Symptoms loading: ${isSymptomsLoading.value}");
    print("Triggers loading: ${isTriggersLoading.value}");
    print("Error message: ${errorMessage.value}");
    print("🔍 === END API-ONLY DEBUG ===");
  }

  // Method to refresh data from API
  Future<void> refreshFromAPI() async {
    print("🔄 Refreshing data from API...");
    await Future.wait([
      fetchSymptoms(),
      fetchTriggers(),
    ]);
    print("✅ API refresh completed");
  }
  Rx<CustomFieldType> activeCustomField = CustomFieldType.none.obs;


  void toggleCustomField(CustomFieldType fieldType) {
    if (activeCustomField.value == fieldType) {
      // If already active, close it
      activeCustomField.value = CustomFieldType.none;
    } else {
      // If not active or different field is active, open this one
      activeCustomField.value = fieldType;
    }
  }

  void clearCustomField() {
    activeCustomField.value = CustomFieldType.none;
  }

  Future<void> saveDetails() async {
    try {
      // Show loader
      isLoading.value = true;
      errorMessage.value = '';

      // Get user ID from storage
      final userData = StorageService.to.getUser();
      final userId = userData?['id']?.toString();

      if (userId == null || userId.isEmpty) {
        errorMessage.value = 'User ID not found. Please log in again.';
        Get.snackbar(
          'Error',
          errorMessage.value,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Check if at least one symptom or trigger is selected
      if (selectedSymptoms.isEmpty && selectedTriggers.isEmpty) {
        Get.snackbar(
          'Error',
          'Please select at least one symptom or trigger',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Prepare symptoms string (excluding custom options)
      List<String> symptomsToSave = selectedSymptoms
          .where((symptom) => symptom != '+ Custom Symptom')
          .toList();
      String symptomsString = symptomsToSave.join(' and ');

      // Prepare triggers string (excluding custom options)
      List<String> triggersToSave = selectedTriggers
          .where((trigger) => trigger != '+ Custom Trigger')
          .toList();
      String triggersString = triggersToSave.join(' and ');

      // Get current date and time
      DateTime now = DateTime.now();
      String logDate = DateFormat('yyyy-MM-dd').format(now);
      String logTime = DateFormat('HH:mm:ss').format(now);

      print("Saving log with:");
      print("User ID: $userId");
      print("Symptoms: $symptomsString");
      print("Triggers: $triggersString");
      print("Date: $logDate");
      print("Time: $logTime");

      // Call the create_log API
      final response = await _authService.createLog(
        userId: userId,
        symptoms: symptomsString,
        triggers: triggersString,
        logTime: logTime,
        logDate: logDate,
      );

      // Handle response
      if (response['status'] == 'success') {
        print("Log created successfully");

        // Show success message
        Get.snackbar(
          'Success',
          'Log saved successfully!',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        // Clear selections
        selectedSymptoms.clear();
        selectedTriggers.clear();
        activeCustomField.value = CustomFieldType.none;

        // Navigate to home
        Get.offAllNamed('/home', arguments: 1);

      } else {
        // Handle API error
        errorMessage.value = response['message'] ?? 'Failed to save log';
        print("Error saving log: $errorMessage");

        Get.snackbar(
          'Error',
          errorMessage.value,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }

    } catch (e) {
      // Handle exceptions
      errorMessage.value = 'Error saving log: $e';
      print("Exception in saveDetails: $errorMessage");

      Get.snackbar(
        'Error',
        'An unexpected error occurred. Please try again.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      // Hide loader
      isLoading.value = false;
    }
  }
}