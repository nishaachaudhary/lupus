import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/style/styles.dart';

class CustomTextField extends StatelessWidget {
  final String title;
  final TextEditingController controller;
  final int? maxLines;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool isEnabled;
  final TextStyle? titleStyle;
  final TextStyle? hintStyle;
  final bool obscureText;
  final Function(String)? onChanged;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final double? fixedWidth;
  final double fixedHeight; // New parameter for fixed height

  const CustomTextField({
    this.maxLines = 1,
    this.onChanged,
    this.focusNode,
    this.isEnabled = true,
    this.titleStyle,
    required this.title,
    this.hintText,
    this.hintStyle,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.fixedWidth,
    this.fixedHeight = 56,
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: titleStyle ?? semiBoldStyle.copyWith(fontSize: Dimensions.fontSizeDefault),
        ),
        const SizedBox(height: Dimensions.paddingSizeSmaller),
        SizedBox(
          width: fixedWidth ?? double.infinity,
          height: fixedHeight, // Using the fixedHeight parameter
          child: TextField(
            focusNode: focusNode,
            onChanged: onChanged,
            onTapOutside: (_) {
              if (Platform.isIOS) {
                focusNode?.unfocus();
              }
            },
            obscureText: obscureText,
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            cursorColor: CustomColors.purpleColor,
            style: regularStyle.copyWith(color: Colors.black),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              enabled: isEnabled,
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
              contentPadding: const EdgeInsets.symmetric(
                vertical: Dimensions.paddingSizeExtraSmall,
                horizontal: Dimensions.paddingSizeSmall,
              ),
              hintText: hintText ?? "Enter $title",
              hintStyle: hintStyle ??
                  semiLightStyle.copyWith(
                    color: CustomColors.greyColor,
                    fontSize: Dimensions.fontSizeLarge,
                  ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: CustomColors.textBorderColor,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: CustomColors.textBorderColor,
                  width: 1,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: CustomColors.textBorderColor,
                  width: 1,
                ),
              ),
              constraints: BoxConstraints(
                minHeight: fixedHeight, // Ensures minimum height
              ),
            ),
          ),
        ),
      ],
    );
  }
}