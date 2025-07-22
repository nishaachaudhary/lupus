// lib/views/chat_screen/search_bar_widget.dart
// Simple version that doesn't require ChatController changes
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/icons.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/chat_screen/chat_controller.dart';
import 'package:lupus_care/views/login/main_screen_controller.dart';

class SearchBarWidget extends StatefulWidget {
  const SearchBarWidget({super.key});

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _searchController = TextEditingController();
  final ChatController _chatController = Get.find<ChatController>();
  late MainScreenController _mainController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _mainController = Get.find<MainScreenController>();

    // Listen to tab changes to clear search when switching tabs
    _mainController.selectedIndex.listen((index) {
      if (index != 3 && mounted) { // If leaving chat tab (index 3)
        _clearSearch();
      } else if (index == 3 && mounted) { // If entering chat tab
        _clearSearch();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _chatController.updateSearch(_searchController.text);
  }

  void _clearSearch() {
    if (mounted) {
      _searchController.clear();
      _chatController.updateSearch('');
      _focusNode.unfocus();
      print("💬 Chat search cleared");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: 16, right: 16),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
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
          // Add clear button when there's text
          suffixIcon: _searchController.text.isNotEmpty
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
        style: regularStyle.copyWith(
          fontSize: Dimensions.fontSizeLarge,
        ),
      ),
    );
  }
}