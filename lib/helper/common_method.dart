// import 'package:flutter/material.dart';
// // import 'package:fluttertoast/fluttertoast.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:get/get.dart';
// import 'package:lupus_care/style/colors.dart';
//
//
// class CommonMethods {
//   static void showToast(String msg) {
//     Fluttertoast.showToast(
//         msg: msg,
//         toastLength: Toast.LENGTH_LONG,
//         gravity: ToastGravity.CENTER,
//         timeInSecForIosWeb: 3,
//         backgroundColor: CustomColors.purpleColor,
//         textColor: Colors.white,
//         fontSize: 16.0);
//   }
//
//   static void openReviewScreen() {
//     if (GetPlatform.isAndroid || GetPlatform.isIOS) {
//       final appId = GetPlatform.isAndroid ? 'in.co.woco' : 'com.WoCo.com';
//       final url = Uri.parse(
//         GetPlatform.isAndroid
//             ? "market://details?id=$appId"
//             : "itms-apps://apps.apple.com/app/id=$appId",
//       );
//       launchUrl(
//         url,
//         mode: LaunchMode.externalApplication,
//       );
//     }
//   }
//
//   static String formateDuration(int? time, {bool withNextLine = true}) {
//     if (withNextLine) {
//       if (time != null) {
//         Duration duration = Duration(seconds: time);
//         // String twoDigits(int n) => n.toString().padLeft(2, "0");
//         String twoDigitMinutes =
//         duration.inMinutes.remainder(60).abs().toString();
//         if (duration.inHours == 0) {
//           return "$twoDigitMinutes mins\n";
//         } else {
//           return "${duration.inHours}hrs $twoDigitMinutes mins\n";
//         }
//       } else {
//         return "0 mins\n";
//       }
//     } else {
//       if (time != null) {
//         Duration duration = Duration(seconds: time);
//         // String twoDigits(int n) => n.toString().padLeft(2, "0");
//         String twoDigitMinutes =
//         duration.inMinutes.remainder(60).abs().toString();
//         if (duration.inHours == 0) {
//           return "$twoDigitMinutes mins";
//         } else {
//           return "${duration.inHours}hrs $twoDigitMinutes mins";
//         }
//       } else {
//         return "0 mins";
//       }
//     }
//   }
// }
