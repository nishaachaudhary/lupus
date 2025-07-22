import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/icons.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/add_symptoms/add_symptoms_contoller.dart';
import 'package:lupus_care/widgets/customTextflied.dart';

enum CustomFieldType { none, symptom, trigger }

class AddNewLogScreen extends StatefulWidget {
  const AddNewLogScreen({super.key});

  @override
  State<AddNewLogScreen> createState() => _AddNewLogScreenState();
}

class _AddNewLogScreenState extends State<AddNewLogScreen> {
  late final AddSymptomsController controller;
  CustomFieldType currentCustomField = CustomFieldType.none;
  final TextEditingController triggerController = TextEditingController();
  final TextEditingController symptomsController = TextEditingController();

  String todayDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    controller = Get.put(AddSymptomsController());
  }

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
          "Add New Log",
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

// FIXED VERSION - Replace your _buildContent method with this

  // Replace your _buildContent method with this updated version

  Widget _buildContent(BuildContext context) {
    return RefreshIndicator(
        onRefresh: () async {
          await controller.refreshFromAPI();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Section
              Text("Date", style: mediumStyle.copyWith(fontSize: Dimensions.fontSizeLarge)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CustomColors.lightGrey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    // Date selection logic here
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      todayDate,
                      textAlign: TextAlign.left,
                      style: semiLightStyle.copyWith(
                        fontSize: Dimensions.fontSizeDefault,
                        color: CustomColors.greyColor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Symptoms Section
              Row(
                children: [
                  Expanded(
                    child: Text(
                        "What Symptoms Are You Experiencing?",
                        style: mediumStyle.copyWith(fontSize: Dimensions.fontSizeLarge)
                    ),
                  ),

                ],
              ),
              const SizedBox(height: 10),

              // Symptoms Grid with Loading State
              Obx(() {
                if (controller.isSymptomsLoading.value) {
                  return Container(
                    height: 100,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(CustomColors.purpleColor),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Loading symptoms...",
                            style: semiLightStyle.copyWith(
                              fontSize: 12,
                              color: CustomColors.greyColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (controller.symptoms.isEmpty) {
                  return Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.orange,
                          size: 32,
                        ),
                        SizedBox(height: 8),
                        Text(
                          "No symptoms available",
                          style: mediumStyle.copyWith(fontSize: 14),
                        ),
                        Text(
                          "Unable to load symptoms from server",
                          style: semiLightStyle.copyWith(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => controller.fetchSymptoms(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CustomColors.purpleColor,
                            minimumSize: Size(100, 32),
                          ),
                          child: Text(
                            "Retry",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return buildGrid(
                  controller.symptoms.toList(),
                  controller.selectedSymptoms.toList(),
                  controller.toggleSymptom,
                );
              }),

              // Custom Symptom Input Field
              Obx(() {
                if (controller.activeCustomField.value == CustomFieldType.symptom) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            titleStyle: mediumStyle.copyWith(fontSize: Dimensions.fontSizeDefault),
                            title: "Add Custom Symptom",
                            controller: symptomsController,
                            hintText: "Enter your symptom",
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            final trimmedText = symptomsController.text.trim();

                            // Check if empty
                            if (trimmedText.isEmpty) {
                              Get.snackbar(
                                'Error',
                                'Please enter a symptom name',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                              return;
                            }

                            // Check minimum length
                            if (trimmedText.length < 2) {
                              Get.snackbar(
                                'Error',
                                'Symptom name must be at least 2 characters long',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                              return;
                            }

                            // Check maximum length
                            if (trimmedText.length > 50) {
                              Get.snackbar(
                                'Error',
                                'Symptom name cannot exceed 50 characters',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                              return;
                            }

                            // NEW: Check if text contains at least one letter
                            if (!RegExp(r'^.*[a-zA-Z].*$').hasMatch(trimmedText)) {
                              Get.snackbar(
                                'Error',
                                'Symptom name must contain at least one letter',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                              return;
                            }

                            // NEW: Check if text contains only special characters
                            if (RegExp(r'^[^a-zA-Z0-9\s]+$').hasMatch(trimmedText)) {
                              Get.snackbar(
                                'Error',
                                'Symptom name cannot contain only special characters',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                              return;
                            }

                            // NEW: Check if text contains only dots and spaces
                            if (RegExp(r'^[\.\s]+$').hasMatch(trimmedText)) {
                              Get.snackbar(
                                'Error',
                                'Symptom name cannot contain only dots and spaces',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                              return;
                            }

                            // NEW: Check for excessive special characters
                            final specialCharCount = RegExp(r'[^a-zA-Z0-9\s]').allMatches(trimmedText).length;
                            final specialCharPercentage = (specialCharCount / trimmedText.length) * 100;
                            if (specialCharPercentage > 30) {
                              Get.snackbar(
                                'Error',
                                'Symptom name contains too many special characters',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                              return;
                            }

                            // NEW: Check for repeated characters
                            if (RegExp(r'(.)\1{4,}').hasMatch(trimmedText)) {
                              Get.snackbar(
                                'Error',
                                'Symptom name cannot contain repeated characters',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                              return;
                            }

                            // If all validations pass, add the symptom
                            await controller.addCustomItem(trimmedText);
                            symptomsController.clear();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(top: 18),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: CustomColors.purpleColor,
                            ),
                            child: Text(
                              "Add",
                              style: semiBoldStyle.copyWith(color: Colors.white, fontSize: 16),
                            ),
                          ),
                        ),

                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),

              const SizedBox(height: 24),

              // Triggers Section
              Row(
                children: [
                  Expanded(
                    child: Text(
                        "What Might Have Triggered It?",
                        style: mediumStyle.copyWith(fontSize: Dimensions.fontSizeLarge)
                    ),
                  ),

                ],
              ),
              const SizedBox(height: 10),

              // Triggers Grid with Loading State
              Obx(() {
                if (controller.isTriggersLoading.value) {
                  return Container(
                    height: 100,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(CustomColors.purpleColor),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Loading triggers...",
                            style: semiLightStyle.copyWith(
                              fontSize: 12,
                              color: CustomColors.greyColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (controller.triggers.isEmpty) {
                  return Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.orange,
                          size: 32,
                        ),
                        SizedBox(height: 8),
                        Text(
                          "No triggers available",
                          style: mediumStyle.copyWith(fontSize: 14),
                        ),
                        Text(
                          "Unable to load triggers from server",
                          style: semiLightStyle.copyWith(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => controller.fetchTriggers(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CustomColors.purpleColor,
                            minimumSize: Size(100, 32),
                          ),
                          child: Text(
                            "Retry",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return buildGrid(
                  controller.triggers.toList(),
                  controller.selectedTriggers.toList(),
                  controller.toggleTrigger,
                );
              }),

              // Custom Trigger Input Field
              Obx(() {
                if (controller.activeCustomField.value == CustomFieldType.trigger) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            titleStyle: mediumStyle.copyWith(fontSize: Dimensions.fontSizeDefault),
                            title: "Add Custom Trigger",
                            controller: triggerController,
                            hintText: "Enter your trigger",
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            final trimmedText = triggerController.text.trim();

                            // Check if empty
                            if (trimmedText.isEmpty) {
                              Get.snackbar(
                                'Error',
                                'Please enter a trigger name',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                              return;
                            }

                            // Check minimum length
                            if (trimmedText.length < 2) {
                              Get.snackbar(
                                'Error',
                                'Trigger name must be at least 2 characters long',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                              return;
                            }

                            // Check maximum length
                            if (trimmedText.length > 50) {
                              Get.snackbar(
                                'Error',
                                'Trigger name cannot exceed 50 characters',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                              return;
                            }

                            // NEW: Check if text contains at least one letter
                            if (!RegExp(r'^.*[a-zA-Z].*$').hasMatch(trimmedText)) {
                              Get.snackbar(
                                'Error',
                                'Trigger name must contain at least one letter',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                              return;
                            }

                            // NEW: Check if text contains only special characters
                            if (RegExp(r'^[^a-zA-Z0-9\s]+$').hasMatch(trimmedText)) {
                              Get.snackbar(
                                'Error',
                                'Trigger name cannot contain only special characters',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                              return;
                            }

                            // NEW: Check if text contains only dots and spaces
                            if (RegExp(r'^[\.\s]+$').hasMatch(trimmedText)) {
                              Get.snackbar(
                                'Error',
                                'Trigger name cannot contain only dots and spaces',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                              return;
                            }

                            // NEW: Check for excessive special characters
                            final specialCharCount = RegExp(r'[^a-zA-Z0-9\s]').allMatches(trimmedText).length;
                            final specialCharPercentage = (specialCharCount / trimmedText.length) * 100;
                            if (specialCharPercentage > 30) {
                              Get.snackbar(
                                'Error',
                                'Trigger name contains too many special characters',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                              return;
                            }

                            // NEW: Check for repeated characters
                            if (RegExp(r'(.)\1{4,}').hasMatch(trimmedText)) {
                              Get.snackbar(
                                'Error',
                                'Trigger name cannot contain repeated characters',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                              return;
                            }

                            // If all validations pass, add the trigger
                            await controller.addCustomItem(trimmedText);
                            triggerController.clear();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(top: 18),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: CustomColors.purpleColor,
                            ),
                            child: Text(
                              "Add",
                              style: semiBoldStyle.copyWith(color: Colors.white, fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),

              const SizedBox(height: 24),


              // Save Button
              SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CustomColors.greenColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      // Add custom symptom if entered (with trimming)
                      if (controller.activeCustomField.value == CustomFieldType.symptom &&
                          symptomsController.text.trim().isNotEmpty) {
                        controller.addCustomItem(symptomsController.text.trim());
                      }

                      // Add custom trigger if entered (with trimming)
                      if (controller.activeCustomField.value == CustomFieldType.trigger &&
                          triggerController.text.trim().isNotEmpty) {
                        controller.addCustomItem(triggerController.text.trim());
                      }

                      // Save and navigate
                      controller.saveDetails();
                    },
                    child: Text(
                        "Save Details",
                        style: semiBoldStyle.copyWith(
                            fontSize: Dimensions.fontSizeExtraLarge,
                            color: CustomColors.darkGreenColor
                        )
                    ),
                  )
              ),

              const SizedBox(height: 16),
            ],
          ),
        )
    );
  }

  Widget buildGrid(
      List<String> items,
      List<String> selectedList,
      Function(String) onTap,
      ) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        final isSelected = selectedList.contains(item);
        final isCustomSymptom = item == '+ Custom Symptom';
        final isCustomTrigger = item == '+ Custom Trigger';
        final isActiveCustom = (isCustomSymptom && controller.activeCustomField.value == CustomFieldType.symptom) ||
            (isCustomTrigger && controller.activeCustomField.value == CustomFieldType.trigger);

        return GestureDetector(
          onTap: () {
            if (isCustomSymptom) {
              controller.toggleCustomField(CustomFieldType.symptom);
            } else if (isCustomTrigger) {
              controller.toggleCustomField(CustomFieldType.trigger);
            } else {
              onTap(item);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected || isActiveCustom
                  ? CustomColors.purpleColor
                  : (isCustomSymptom || isCustomTrigger)
                  ? Colors.transparent
                  : Colors.white,
              border: Border.all(
                color: isSelected || isActiveCustom
                    ? CustomColors.purpleColor
                    : (isCustomSymptom || isCustomTrigger)
                    ? CustomColors.purpleColor
                    : CustomColors.textBorderColor,
              ),
              borderRadius: BorderRadius.circular(61),
            ),
            child: Text(
              item,
              textAlign: TextAlign.center,
              style: semiLightStyle.copyWith(
                fontSize: 14,
                color: isSelected || isActiveCustom
                    ? Colors.white
                    : (isCustomSymptom || isCustomTrigger)
                    ? CustomColors.purpleColor
                    : CustomColors.blackColor,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}