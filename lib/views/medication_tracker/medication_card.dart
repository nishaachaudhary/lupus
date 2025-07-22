// views/medication_tracker/medication_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/icons.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/medication_tracker/delete_medication_dialog.dart';
import 'package:lupus_care/views/medication_tracker/medication_tracker_controller.dart';

class MedicationCard extends StatelessWidget {
  final Medication medication;

  const MedicationCard({required this.medication});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MedicationController>();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CustomColors.purpleColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            medication.time,
            style: semiBoldStyle.copyWith(
              fontSize: Dimensions.fontSizeExtraLarge,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SvgPicture.asset(
                CustomIcons.drugIcon,
                color: Colors.white,
                width: 16,
                height: 16,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            medication.name,
                            style: mediumStyle.copyWith(
                              fontSize: Dimensions.fontSizeLarge,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // 3-dot menu button
                        GestureDetector(
                          onTapDown: (TapDownDetails details) => _showPopupMenu(
                            context,
                            details.globalPosition, // Position near the tap
                            medication,
                            controller,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.more_vert,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          "${medication.duration} •",
                          style: mediumStyle.copyWith(
                            fontSize: Dimensions.fontSizeDefault,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          medication.status,
                          style: mediumStyle.copyWith(
                            fontSize: Dimensions.fontSizeDefault,
                            color: CustomColors.greenAcent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  void _showPopupMenu(
      BuildContext context,
      Offset position,
      Medication medication,
      MedicationController controller,
      ) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(position, position),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      color: Colors.white,
      elevation: 3, // This will create a shadow effect
      items: [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              SvgPicture.asset(
                CustomIcons.edit,
                width: 16,
                height: 16,
              ),//
              SizedBox(width: 12),
              Text('Edit',
                  style: semiLightStyle.copyWith(fontSize: 14,color: Color(0xFF2F2F2F))),
               SizedBox(width: 30),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete', // Changed to lowercase to match your then() check
          child: Row(
            children: [
              SvgPicture.asset(
                CustomIcons.deleteMedEmpty,
                width: 16,
                height: 16,
              ),// Made size consistent with edit icon
              SizedBox(width: 12),
              Text('Delete',
                  style: semiLightStyle.copyWith(fontSize: 14,color: Color(0xFF2F2F2F))),
              SizedBox(width: 30),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'edit') {
        _editMedication(medication);
      } else if (value == 'delete') {
        showDialog(
          context: context,
          builder: (_) => DeleteMedicationDialog(
            onConfirm: () => controller.deleteMedication(medication.id),
            name: medication.name,
          ),
        );
      }
    });
  }
  void _editMedication(Medication medication) {
    Get.toNamed('/editMedication', arguments: medication)?.then((_) {
      // Refresh medications when returning from edit screen
      final controller = Get.find<MedicationController>();
      controller.refreshMedications();
    });
  }


}