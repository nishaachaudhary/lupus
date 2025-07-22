import 'package:flutter/material.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';

class DeleteMedicationDialog extends StatelessWidget {


  final VoidCallback onConfirm;
  final String name;

  const DeleteMedicationDialog({
    super.key,

    required this.onConfirm,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child:Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Close icon
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Delete Medication",
                  style: mediumStyle.copyWith(
                    fontSize: Dimensions.fontSizeExtraLarge,
                    color: const Color(0xFF535353),

                  ),),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          Divider(
            height: 2,
            thickness: 0.89,
            color: Colors.grey.shade300,
          ),


          const SizedBox(height: 2),
          // Message
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: semiLightStyle.copyWith(
                  fontSize: 20,
                  color: const Color(0xff6B7280), // Default gray color
                ),
                children: [ // Moved outside of style parameter
                  const TextSpan(text: "Are you sure you want to Delete your Medication "),
                  TextSpan(
                    text: "“$name”",
                    style: semiLightStyle.copyWith(
                      fontSize: 20,
                      color: Colors.purple, // Or CustomColors.purpleColor
                    ),
                  ),
                  const TextSpan(text: "?"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),

          Divider(
            height: 2,
            thickness: 0.89,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 4),
          // Buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 51,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CustomColors.buttonGrey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(38),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel",
                          style: semiBoldStyle.copyWith(
                              fontSize: Dimensions.fontSizeExtraLarge,
                              color: Colors.white

                          )),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 51,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CustomColors.purpleColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(38),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        onConfirm();
                      },
                      child: Text("Delete",
                          style: semiBoldStyle.copyWith(
                              fontSize: Dimensions.fontSizeExtraLarge,
                              color: Colors.white

                          )),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
