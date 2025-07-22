// views/medication_tracker/medication_filter_chips.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/medication_tracker/medication_tracker_controller.dart';

class MedicationFilterChips extends StatelessWidget {
  final controller = Get.find<MedicationController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() => Row(
      children: controller.medicationTypes.map((medType) {
        final isSelected = controller.selectedMedication.value == medType;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(
              medType,
              style: semiLightStyle.copyWith(
                fontSize: Dimensions.fontSizeLarge,
                color: isSelected ? Colors.white : CustomColors.blackColor,
              ),
            ),
            selected: isSelected,
            onSelected: (selected) {
              controller.selectedMedication.value = selected ? medType : 'All Medications';
            },
            selectedColor: CustomColors.purpleColor,
            backgroundColor: Colors.white,
            labelPadding: const EdgeInsets.symmetric(horizontal: 8),
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                  color: isSelected ? CustomColors.purpleColor : CustomColors.textBorderColor
              ),
            ),
          ),
        );
      }).toList(),
    ));
  }
}