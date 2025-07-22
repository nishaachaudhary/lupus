// Simple SearchBarWidget that actually works
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/icons.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/medication_tracker/medication_tracker_controller.dart';

class SearchBarWidget extends StatefulWidget {
  @override
  _SearchBarWidgetState createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final controller = Get.find<MedicationController>();
  late TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _textController.text = controller.searchQuery.value;

    // Listen for search query changes from controller
    controller.searchQuery.listen((query) {
      if (mounted && _textController.text != query) {
        _textController.text = query;
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _textController.clear();
    controller.searchQuery.value = '';
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: TextField(
        controller: _textController,
        focusNode: _focusNode,
        onChanged: (val) {
          controller.searchQuery.value = val;
        },
        decoration: InputDecoration(
          hintText: 'Search here',
          hintStyle: lightStyle.copyWith(
            fontSize: Dimensions.fontSizeLarge,
            color: CustomColors.greyColor,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12.0),
            child: SvgPicture.asset(
              CustomIcons.searchIcon,
              height: 20,
              width: 20,
              colorFilter: ColorFilter.mode(
                CustomColors.greyColor,
                BlendMode.srcIn,
              ),
            ),
          ),
          suffixIcon: _textController.text.isNotEmpty
              ? IconButton(
            icon: Icon(
              Icons.clear,
              color: CustomColors.greyColor,
              size: 20,
            ),
            onPressed: _clearSearch,
          )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: CustomColors.textBorderColor,
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: CustomColors.textBorderColor,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: CustomColors.textBorderColor,
              width: 1,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}