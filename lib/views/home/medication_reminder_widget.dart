import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/icons.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';

class MedicationReminderWidget extends StatelessWidget {
  final String medicationName;
  final String time;

  const MedicationReminderWidget({
    super.key,
    required this.medicationName,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(

      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD794CD), // hex color from your design
            offset: const Offset(0, 4.21), // x: 0px, y: 4.21px
            blurRadius: 26.32, // soft spread
            spreadRadius: 0, // no spread
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SvgPicture.asset(
            CustomIcons.drugIcon,
            width: 20,
            height: 20,
            color: CustomColors.homeColor,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(medicationName,
                style: mediumStyle.copyWith(
                  fontSize: 17,

                ),),
              Text(time,
                style: mediumStyle.copyWith(
                  fontSize: 13,

                ),),
            ],
          ),
          Spacer(),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CustomColors.homeLight, // Optional background color
            ),
            child: const Icon(
              Icons.notifications,
              size:24 ,
              color: CustomColors.homeColor,
            ),
          )
        ],
      ),
    );
  }
}
