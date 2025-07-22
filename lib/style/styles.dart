import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lupus_care/style/colors.dart';

/// Box Shadows
const BoxShadow defaultBoxShadow = BoxShadow(
  color: Colors.black12,
  offset: Offset(0, 10),
  blurRadius: 25,
);

final BoxShadow wideBoxShadow = BoxShadow(
  color: Colors.black.withOpacity(0.07),
  offset: const Offset(0, 5),
  blurRadius: 35,
);

final BoxShadow blueShadow = BoxShadow(
  color: Get.theme.primaryColor.withOpacity(0.15),
  offset: const Offset(0, 5),
  blurRadius: 35,
);

/// Font Family Constant
const String fontFamily = 'DMSans_18pt';

/// Text Styles
const TextStyle regularStyle = TextStyle(
  fontFamily: fontFamily,
  fontWeight: FontWeight.normal,
  color: CustomColors.textColor,
);

const TextStyle lightStyle = TextStyle(
  fontFamily: fontFamily,
  fontWeight: FontWeight.w300,
  color: CustomColors.textColor,
);

const TextStyle semiLightStyle = TextStyle(
  fontFamily: fontFamily,
  fontWeight: FontWeight.w500,
  color: CustomColors.textColor,
);

const TextStyle mediumStyle = TextStyle(
  fontFamily: fontFamily,
  fontWeight: FontWeight.w600,

  color: CustomColors.textColor,
);

const TextStyle semiBoldStyle = TextStyle(
  fontFamily: fontFamily,
  fontWeight: FontWeight.w700,
  color: CustomColors.textColor,
);

const TextStyle boldStyle = TextStyle(
  fontFamily: fontFamily,
  fontWeight: FontWeight.w800,
  color: CustomColors.textColor,
);

const TextStyle blackStyle = TextStyle(
  fontFamily: fontFamily,
  fontWeight: FontWeight.w900,
  color: CustomColors.textColor,
);

const TextStyle thinStyle = TextStyle(
  fontFamily: fontFamily,
  fontWeight: FontWeight.w100,
  color: CustomColors.textColor,
);

/// Optional: Custom size styles for headings, captions, etc.
const TextStyle headingStyle = TextStyle(
  fontFamily: fontFamily,
  fontWeight: FontWeight.w700,
  fontSize: 20,
  color: CustomColors.textColor,
);

const TextStyle captionStyle = TextStyle(
  fontFamily: fontFamily,
  fontWeight: FontWeight.w300,
  fontSize: 12,
  color: CustomColors.textColor,
);
