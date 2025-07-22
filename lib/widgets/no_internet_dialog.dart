import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:remixicon/remixicon.dart';


class NoInternetDialog extends StatelessWidget {
  const NoInternetDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Dimensions.radiusSmall)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        contentPadding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        insetPadding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault),
        content: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Remix.wifi_off_fill,
                size: 58,
                color: Get.theme.primaryColor,
              ),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              Text(
                "No Internet Connection",
                style: regularStyle.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                  color: CustomColors.grey,
                ),
              ),
              const SizedBox(height: Dimensions.paddingSizeExtraSmall),
              Text(
                "Please turn on your internet and try again",
                textAlign: TextAlign.center,
                style: regularStyle.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                  color: CustomColors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
